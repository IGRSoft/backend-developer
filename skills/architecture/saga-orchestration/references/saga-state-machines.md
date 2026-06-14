# Saga State Machines (deep dive)

Durable-state mechanics behind [../SKILL.md](../SKILL.md) > State & Failure: a
hand-rolled state-machine schema, crash recovery, timers and retries, the
workflow-engine alternatives, and tactics for the isolation a saga does not give
you. Version-gate engine features (Temporal, Camunda 8, AWS Step Functions)
against your toolchain — see skill: version-feature-matrix.

## Hand-Rolled State Schema

Persist one row per saga instance so a crashed orchestrator resumes from the last
committed state rather than restarting (which would re-run committed steps).

```sql
CREATE TABLE saga_instances (
  id            uuid PRIMARY KEY,
  type          text        NOT NULL,         -- e.g. 'create-order'
  state         text        NOT NULL,         -- CHARGING | RESERVING | SHIPPING | COMPENSATING | COMPLETED | FAILED
  payload       jsonb       NOT NULL,         -- command + accumulated step results
  step_deadline timestamptz,                  -- when the current step times out
  attempts      int         NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Each forward step and each compensation is logged for idempotency + audit
CREATE TABLE saga_steps (
  saga_id   uuid    NOT NULL REFERENCES saga_instances(id),
  step      text    NOT NULL,                 -- 'charge' | 'reserve' | 'refund' | ...
  status    text    NOT NULL,                 -- DONE | COMPENSATED
  PRIMARY KEY (saga_id, step)                 -- dedup: a step runs at most once
);
```

The `(saga_id, step)` primary key makes every step idempotent at the storage
layer: re-running a delivered step is a no-op insert.

## Crash Recovery

A reaper/worker scans for sagas that are not terminal and advances them. Because
state is committed after each transition, a crash mid-step resumes at the last
durable state.

```go
// Resume non-terminal sagas; SKIP LOCKED lets many workers run safely
func (w *Worker) recover(ctx context.Context) error {
    rows, err := w.db.QueryContext(ctx,
        `SELECT id, type, state, payload FROM saga_instances
         WHERE state NOT IN ('COMPLETED','FAILED')
         ORDER BY updated_at LIMIT 50 FOR UPDATE SKIP LOCKED`)
    if err != nil {
        return err
    }
    for rows.Next() {
        var s SagaInstance
        _ = rows.Scan(&s.ID, &s.Type, &s.State, &s.Payload)
        w.advance(ctx, &s) // idempotent: re-running a DONE step is a no-op
    }
    return rows.Err()
}
```

## Timers & Retries

| Concern | Mechanism |
|---------|-----------|
| Step timeout | `step_deadline` column; reaper finds expired rows → transition to COMPENSATING |
| Transient step failure | Increment `attempts`, retry with backoff up to a cap |
| Exhausted retries | Move to COMPENSATING (forward step) or alert (compensation) |
| Stuck compensation | Bounded retry, then page on-call; never silently abandon |

```python
# Expired-step sweep: a step that blew its deadline is treated as a failure
async def sweep_timeouts(store) -> None:
    for saga in await store.expired_steps():        # step_deadline < now()
        if saga.attempts < MAX_ATTEMPTS:
            await store.bump_attempts(saga.id)      # retry the current step
        else:
            await store.transition(saga.id, "COMPENSATING")
```

## Workflow-Engine Alternative

Once a saga grows past a few steps, a durable workflow engine removes the
hand-rolled schema, reaper, and timer plumbing.

| Engine | Model | Notes |
|--------|-------|-------|
| Temporal | Code-as-workflow (durable execution) | Replays event history to resume; activities are your steps/compensations |
| Camunda 8 (Zeebe) | BPMN diagrams | Visual flow; good for business-analyst-readable processes |
| AWS Step Functions | State machine JSON (ASL) | Serverless on AWS; native retries/catch/timeouts |

All three give durable state, timers, retries, and visibility for free. Your
steps must still be **idempotent** (the engine retries them) and you still author
**compensations** explicitly. Prefer an engine for non-trivial, long-running
workflows; keep the hand-rolled approach only for short, simple sagas where a
dependency is unwarranted.

```typescript
// Temporal workflow — durable; a crash replays history and resumes exactly here
export async function createOrderWorkflow(cmd: CreateOrderCommand): Promise<void> {
  const { charge, refund, reserve, release, ship } = proxyActivities<Activities>({
    startToCloseTimeout: '30s',
    retry: { maximumAttempts: 3 }, // engine handles retry/backoff per activity
  });
  const undo: Array<() => Promise<void>> = [];
  try {
    const p = await charge(cmd);   undo.push(() => refund(p));
    const r = await reserve(cmd);  undo.push(() => release(r));
    await ship(cmd);
  } catch (err) {
    for (const c of undo.reverse()) await c(); // compensate in reverse
    throw err;
  }
}
```

## Isolation Tactics (the missing ACID 'I')

A saga has no isolation: intermediate states are visible to concurrent
transactions, risking dirty reads and lost updates. Mitigate without a global
lock:

| Tactic | What it does |
|--------|--------------|
| Semantic lock | Mark a record `PENDING` until the saga finishes; readers handle the pending state |
| Commutative updates | Use increments/decrements (reorderable) instead of absolute writes |
| Pessimistic view | Reorder steps so the riskiest/least-reversible runs last |
| Re-read value | Re-read and re-validate at the point of the irreversible step |
| Version / by-value | Detect concurrent modification (optimistic version) and abort/compensate |

Semantic locks are the workhorse: a row in a `PENDING` state signals an in-flight
saga so other transactions don't act on half-committed data, and the saga clears
or finalizes the flag on completion or compensation.

## Testing Sagas

Force the failure paths — that is where the bugs live:
- Inject a failure at each step and assert the correct compensations run in
  reverse order.
- Deliver a step twice and assert idempotency (no double refund).
- Kill the worker mid-saga and assert recovery resumes, not restarts.

See [../../../quality/be-testing/SKILL.md](../../../quality/be-testing/SKILL.md)
for the failure-injection integration harness (Testcontainers + fault injection).
