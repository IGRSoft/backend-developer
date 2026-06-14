---
name: cqrs-event-sourcing
description: >-
  CQRS and event sourcing — command/query separation, event store,
  projections/read models, snapshots, event versioning, eventual consistency,
  and replay. Use when read and write shapes diverge sharply, when you need a
  full audit trail and temporal queries, or when rebuilding read models from
  an event log.
---

# CQRS & Event Sourcing

**Split the write model from the read model; optionally make the event log the source of truth**

## When to Use

Use this skill when:
- The read shape and write shape diverge so much one model serves neither well
- You need a complete audit trail, temporal queries, or the ability to replay
- You want to scale reads independently of writes
- You are designing an event store, projections, or snapshots
- You need to version events without breaking existing consumers

CQRS and event sourcing are **separate** decisions: CQRS (split models) is common
and cheap; event sourcing (events as the source of truth) is powerful but costly.
Adopt CQRS first; add event sourcing only when audit/replay/temporal needs
justify it. For event delivery mechanics, see
[event-driven](../event-driven/SKILL.md); for multi-service writes,
[saga-orchestration](../saga-orchestration/SKILL.md).

## The Two Decisions

| Decision | Means | Reach for it when |
|----------|-------|-------------------|
| **CQRS** | Separate command model from query model | Read/write shapes diverge; reads need independent scaling |
| **Event sourcing** | State = a fold over an append-only event log | You need audit, replay, temporal queries, or a perfect history |
| CRUD (neither) | One model, read and write the current state | Default — most services never need either |

You can do CQRS without event sourcing (e.g. write to a normalized table, project
to a denormalized read table). You should rarely do event sourcing without CQRS.
Version-gate event-store tooling (EventStoreDB, Marten, Axon) against your
toolchain — see skill: version-feature-matrix.

## Command / Query Separation

Commands change state and return nothing meaningful (or just an id/ack); queries
return data and change nothing. Route them through distinct models.

```typescript
// NestJS — command and query handlers are separate; never one "service" doing both
@CommandHandler(PlaceOrderCommand)
export class PlaceOrderHandler {
  constructor(private readonly repo: OrderWriteRepository) {}
  async execute(cmd: PlaceOrderCommand): Promise<{ orderId: string }> {
    const order = Order.place(cmd.customerId, cmd.items); // enforces invariants
    await this.repo.save(order);                          // write model only
    return { orderId: order.id };
  }
}

@QueryHandler(GetOrderSummaryQuery)
export class GetOrderSummaryHandler {
  constructor(private readonly reads: OrderReadModel) {}
  execute(q: GetOrderSummaryQuery): Promise<OrderSummaryView> {
    return this.reads.summaryById(q.orderId); // denormalized read model, no domain logic
  }
}
```

The write model protects invariants (an aggregate); the read model is a dumb,
denormalized view optimized for one query.

## Event Store

In event sourcing, you persist **events**, not current state. State is rebuilt by
folding the event stream for an aggregate.

```csharp
// .NET — append events, never UPDATE; current state is a fold (left-reduce)
public sealed class Account
{
    public decimal Balance { get; private set; }
    public long Version { get; private set; }

    // Rebuild state by replaying the stream
    public static Account Rehydrate(IEnumerable<IEvent> stream)
    {
        var acc = new Account();
        foreach (var e in stream) acc.Apply(e);
        return acc;
    }

    public IEnumerable<IEvent> Withdraw(decimal amount)
    {
        if (amount > Balance) throw new InsufficientFundsException();
        var e = new MoneyWithdrawn(amount);
        Apply(e);                 // mutate in-memory
        return new[] { e };       // caller appends to the store
    }

    private void Apply(IEvent e)  // the only place state changes
    {
        switch (e)
        {
            case MoneyDeposited d: Balance += d.Amount; break;
            case MoneyWithdrawn w: Balance -= w.Amount; break;
        }
        Version++;
    }
}
```

Append with **optimistic concurrency**: include the expected stream version; the
store rejects the append if another writer advanced it (no lost updates). Events
are immutable facts — never edit or delete them.

## Projections (Read Models)

A projection subscribes to the event stream and maintains a denormalized read
model. Different projections serve different queries from the same events.

```sql
-- Projection updates a flat read table as events arrive (idempotent upsert by id)
INSERT INTO account_balances (account_id, balance, as_of_version)
VALUES ($1, $2, $3)
ON CONFLICT (account_id) DO UPDATE
SET balance = EXCLUDED.balance, as_of_version = EXCLUDED.as_of_version
WHERE account_balances.as_of_version < EXCLUDED.as_of_version; -- ignore stale/duplicate
```

Read models are **eventually consistent** — they lag the write model by the
projection's processing time. Design the UX for it (return the command's known
result, show "pending", or read-your-writes against the write model when freshness
is mandatory).

## Evolution

§ versioning — Events live forever, so they must evolve without breaking old
consumers or old stored events.

| Technique | Use for |
|-----------|---------|
| Additive change only | Add optional fields; never remove/rename in place |
| Versioned event type | `OrderPlaced.v2` alongside `v1`; consumers handle both |
| Upcasting | Transform old event shapes to new on read |
| Snapshots | Periodic state checkpoint so replay needn't fold from zero |

Snapshots bound replay cost: store the aggregate state every N events, then
rehydrate from the latest snapshot + the tail. Replay (rebuild a projection from
the full log) is the superpower — fix a projection bug, drop the read table,
replay. Keep projections idempotent so replay and live processing agree.

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Read returns stale data right after a write | Eventual consistency of the projection | Read-your-writes against write model, or show pending | this file, Projections |
| Lost update under concurrent writes | No optimistic concurrency on append | Append with expected stream version | this file, Event Store |
| Old consumer breaks on a new event field | Non-additive event change | Additive-only or version the event + upcast | this file, Evolution |
| Rehydration is slow for long-lived aggregates | Folding the whole stream every load | Add snapshots every N events | this file, Evolution |
| Projection diverged after a bug | Stateful, non-idempotent projection | Make idempotent (upsert by version), then replay | this file, Projections |
| Event sourcing everywhere, huge complexity | Adopted ES without an audit/replay need | Use plain CQRS or CRUD where ES isn't justified | this file, The Two Decisions |

## Related Skills

- [event-driven](../event-driven/SKILL.md) — delivering events to projections at-least-once
- [microservices-patterns](../microservices-patterns/SKILL.md) — per-service event stores and read models
- [saga-orchestration](../saga-orchestration/SKILL.md) — sagas driven by domain events
- [secure-coding](../../_shared/secure-coding/SKILL.md) — validate commands as untrusted input
- [api-security](../../quality/api-security/SKILL.md) — object-property authorization on command/query models (API3)
- [be-testing](../../quality/be-testing/SKILL.md) — given-events/when-command/then-events tests
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — event-store/runtime feature minimums
