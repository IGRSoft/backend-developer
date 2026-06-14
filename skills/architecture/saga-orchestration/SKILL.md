---
name: saga-orchestration
description: >-
  Sagas — orchestration vs choreography, compensating transactions, distributed
  consistency without two-phase commit, state machines, and timeout/failure
  handling. Use when a single business transaction spans multiple services or
  resources and you need rollback semantics without a distributed lock.
---

# Saga Orchestration

**Coordinate a multi-service transaction with local commits and compensating undo — never a distributed lock**

## When to Use

Use this skill when:
- One business transaction must update state across multiple services
- You need rollback semantics but cannot (and should not) use two-phase commit
- A workflow is long-running, with steps that can fail or time out independently
- You are choosing between orchestration and choreography for that workflow
- You need to model the workflow as an explicit state machine with compensation

A saga replaces the impossible distributed ACID transaction with a sequence of
**local** transactions, each with a **compensating** action that semantically
undoes it. It provides atomicity (all-or-nothing-ish) and durability, but **not**
isolation — intermediate states are visible. For the events that drive sagas, see
[event-driven](../event-driven/SKILL.md).

## Why Not 2PC

| Approach | Problem |
|----------|---------|
| Two-phase commit (2PC) | Coordinator is a single point of failure; locks held across services kill availability; many stores/brokers don't support it |
| Distributed lock across services | Deadlocks, lease expiry under partition, terrible tail latency |
| **Saga** | Local commit per step + compensating undo; available and partition-tolerant, but no isolation |

Sagas trade isolation for availability — exactly the right trade for most
business workflows, which can tolerate "reserved then released" intermediate
states. Version-gate workflow-engine tooling (Temporal, Camunda, AWS Step
Functions) against your toolchain — see skill: version-feature-matrix.

## Orchestration vs Choreography

| Style | How it coordinates | Use when |
|-------|--------------------|----------|
| **Orchestration** | A central orchestrator commands each step and decides next/compensate | Complex flows, branching, visible state, easier debugging |
| **Choreography** | Each service reacts to events and emits the next; no central brain | Simple linear flows, maximal decoupling |

Start with **orchestration** for anything non-trivial: the flow lives in one
place, state is queryable, and failure handling is explicit. Choreography is more
decoupled but the workflow becomes emergent — hard to see, hard to debug, easy to
create cycles.

```typescript
// Orchestration — the saga drives each step and compensates on failure
class CreateOrderSaga {
  async run(cmd: CreateOrderCommand): Promise<void> {
    const completed: Array<() => Promise<void>> = [];
    try {
      const payment = await this.payments.charge(cmd.orderId, cmd.amountCents);
      completed.push(() => this.payments.refund(payment.id)); // compensation

      const stock = await this.inventory.reserve(cmd.orderId, cmd.items);
      completed.push(() => this.inventory.release(stock.id)); // compensation

      await this.shipping.schedule(cmd.orderId);              // last step: no compensation needed
    } catch (err) {
      // Compensate in reverse order; each compensator must be idempotent
      for (const undo of completed.reverse()) {
        await undo();
      }
      throw new SagaFailedError(cmd.orderId, { cause: err });
    }
  }
}
```

```
// Choreography — the same flow as reactive events (no central orchestrator)
OrderCreated ─▶ payments: PaymentCharged ─▶ inventory: StockReserved ─▶ shipping: Shipped
       ▲ on PaymentFailed          ▲ on StockFailed → PaymentRefunded (compensate)
```

## Compensation

§ compensation — Every step that commits needs a compensating action that
*semantically* undoes it. You cannot "roll back" a committed local transaction —
you issue a new one that reverses its effect.

| Forward step | Compensation |
|--------------|--------------|
| Charge payment | Refund payment |
| Reserve stock | Release stock |
| Allocate booking | Cancel booking |
| Send confirmation email | Send correction email (you can't un-send) |

- Compensations run in **reverse** order of completed steps.
- Compensations must be **idempotent** (they may be retried) and should not
  themselves fail un-compensably — design them to always succeed or to be safely
  retryable.
- Some effects are irreversible (an email sent, money paid to a third party);
  push irreversible steps as late as possible, or model them as a forward-only
  finalization that cannot be compensated.

## State & Failure

§ state — Model the saga as an explicit **state machine** with a persisted
current state, so a crashed orchestrator resumes instead of restarting.

```
            ┌──────────┐  charge ok  ┌──────────┐  reserve ok  ┌──────────┐
START ─────▶│ CHARGING │────────────▶│ RESERVING│─────────────▶│ SHIPPING │──▶ COMPLETED
            └────┬─────┘             └────┬─────┘              └────┬─────┘
        charge fail              reserve fail               ship fail
            ▼                         ▼                          ▼
        FAILED ◀──────────── COMPENSATING ◀───────────── COMPENSATING
```

| Concern | Handling |
|---------|----------|
| Crash mid-saga | Persist state per step; on restart, resume from last committed state |
| Step timeout | Each step has a deadline; on expiry, treat as failure → compensate |
| Stuck compensation | Retry with backoff; after a cap, alert for manual intervention |
| Duplicate step delivery | Steps and compensations idempotent (keyed by saga id + step) |

```python
# FastAPI worker — persist saga state so a crash resumes, not restarts
async def advance(saga: SagaState) -> None:
    if saga.state == "CHARGING":
        await payments.charge(saga.order_id, saga.amount)  # idempotent by saga_id
        await store.transition(saga.id, "RESERVING")
    elif saga.state == "RESERVING":
        try:
            await inventory.reserve(saga.order_id, saga.items)
            await store.transition(saga.id, "SHIPPING")
        except StockUnavailable:
            await store.transition(saga.id, "COMPENSATING")  # triggers refund
```

A workflow engine (Temporal, Camunda, Step Functions) gives you durable state,
timers, and retries for free — prefer it over a hand-rolled state table once the
workflow grows beyond a few steps. Engine comparison and a full hand-rolled
state-machine schema: [references/saga-state-machines.md](references/saga-state-machines.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Money charged but order not created | No compensation on a later failure | Add reverse-order compensators | this file, Compensation |
| Saga stuck forever after a crash | State not persisted per step | Persist state machine; resume on restart | this file, State & Failure |
| Compensation ran twice, double refund | Compensator not idempotent | Key by saga id + step; dedup | this file, Compensation |
| A failed downstream never unwinds | Choreography hid the missing handler | Move to orchestration; make the flow explicit | this file, Orchestration vs Choreography |
| Step waits indefinitely on a dead service | No per-step timeout | Add a deadline; on expiry, compensate | this file, State & Failure |
| Tried to use 2PC across services, lock storms | Wrong consistency tool | Replace with a saga | this file, Why Not 2PC |

## Deep-Dive References

- [references/saga-state-machines.md](references/saga-state-machines.md) —
  hand-rolled state-machine schema, durable resume on crash, per-step timers and
  retries, workflow-engine comparison (Temporal / Camunda / Step Functions), and
  semantic-lock / commutative-update isolation tactics

## Related Skills

- [event-driven](../event-driven/SKILL.md) — events as saga triggers and steps; at-least-once + idempotency
- [microservices-patterns](../microservices-patterns/SKILL.md) — sagas span service/data boundaries
- [cqrs-event-sourcing](../cqrs-event-sourcing/SKILL.md) — saga state as an event-sourced aggregate
- [secure-coding](../../_shared/secure-coding/SKILL.md) — validate each step's inputs; protect compensators
- [api-security](../../quality/api-security/SKILL.md) — function-level authorization on saga steps (API5)
- [be-testing](../../quality/be-testing/SKILL.md) — failure-injection tests that force compensation paths
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — workflow-engine/runtime minimums
