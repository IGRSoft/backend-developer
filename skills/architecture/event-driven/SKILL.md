---
name: event-driven
description: >-
  Event-driven architecture — pub/sub, message brokers (Kafka/RabbitMQ/SQS),
  the transactional outbox, idempotent consumers, ordering, dead-letter queues,
  and at-least-once delivery. Use when decoupling producers from consumers,
  publishing events atomically with a DB write, or making consumers safe under
  retries and duplicates.
---

# Event-Driven Architecture

**Decouple in time with a broker — but assume at-least-once delivery, duplicates, and reordering**

## When to Use

Use this skill when:
- Decoupling a producer from consumers so they scale and deploy independently
- Choosing a broker (Kafka, RabbitMQ, SQS) for the workload
- Publishing an event atomically with the database write that produced it
- Making a consumer idempotent so retries and duplicates are safe
- Guaranteeing ordering for a key, or accepting reordering
- Quarantining poison messages with a dead-letter queue

Routing: broker comparison, exactly-once vs at-least-once, partitioning, and DLQ
redrive mechanics → [references/delivery-semantics.md](references/delivery-semantics.md).
For coordinating multi-service writes, see [saga-orchestration](../saga-orchestration/SKILL.md);
for read models fed by events, see [cqrs-event-sourcing](../cqrs-event-sourcing/SKILL.md).

## The Core Assumptions

| Assumption | Default | Do not assume |
|------------|---------|---------------|
| Delivery | **At-least-once** (duplicates happen) | Exactly-once (it is bounded and costly) |
| Ordering | Per-partition / per-key only | Global total order across topics |
| Publish + DB write | Not atomic by default | The broker commits with your DB |
| Consumer failure | Will reprocess the message | A message is processed once |

Brokers give you at-least-once delivery; building reliability means designing for
duplicates and reordering, not wishing them away. Version-gate broker features
(Kafka transactions/EOS, RabbitMQ quorum queues, SQS FIFO + dedup) against your
actual versions — see skill: version-feature-matrix.

## Pub/Sub Basics

A producer publishes an event (a fact that happened) to a topic; consumers
subscribe independently. Events are **past-tense facts** (`OrderPlaced`), not
commands (`PlaceOrder`).

```typescript
// Node.js — publishing a domain event (Kafka via kafkajs)
await producer.send({
  topic: 'orders.v1',
  messages: [{
    key: order.id,                       // partition key → per-order ordering
    value: JSON.stringify({
      type: 'OrderPlaced',               // event type, versioned via topic suffix
      orderId: order.id,
      customerId: order.customerId,
      totalCents: order.totalCents,
      occurredAt: new Date().toISOString(),
    }),
    headers: { 'event-id': crypto.randomUUID() }, // dedup key for consumers
  }],
});
```

Use the **key** to route related events to the same partition (ordering); use a
unique **event-id** header so consumers can deduplicate.

## Transactional Outbox

§ outbox — The publish and the DB write are two systems; a crash between them
loses the event (or emits a phantom). The **transactional outbox** makes them
atomic: write the event to an `outbox` table *in the same transaction* as the
business change, then a relay polls the table and publishes.

```sql
-- Same transaction as the business write
BEGIN;
  UPDATE orders SET status = 'PLACED' WHERE id = $1;
  INSERT INTO outbox (id, aggregate_id, type, payload, created_at)
  VALUES (gen_random_uuid(), $1, 'OrderPlaced', $2, now());
COMMIT;
-- A separate relay process reads unpublished outbox rows, publishes to the
-- broker, then marks them published (or deletes). At-least-once by design.
```

```go
// Outbox relay loop (poll → publish → mark) — idempotent on the consumer side
func (r *Relay) tick(ctx context.Context) error {
    rows, err := r.db.QueryContext(ctx,
        `SELECT id, type, payload FROM outbox
         WHERE published_at IS NULL ORDER BY created_at LIMIT 100 FOR UPDATE SKIP LOCKED`)
    if err != nil {
        return err
    }
    for rows.Next() {
        var ev OutboxRow
        _ = rows.Scan(&ev.ID, &ev.Type, &ev.Payload)
        if err := r.broker.Publish(ctx, ev.Type, ev.ID, ev.Payload); err != nil {
            return err // leave unpublished; retried next tick (duplicates OK downstream)
        }
        _, _ = r.db.ExecContext(ctx,
            `UPDATE outbox SET published_at = now() WHERE id = $1`, ev.ID)
    }
    return rows.Err()
}
```

`FOR UPDATE SKIP LOCKED` lets multiple relay instances run safely. The relay is
at-least-once (a crash after publish, before mark, republishes) — which is
exactly why consumers must be idempotent. Change-data-capture (Debezium) is the
log-based alternative to polling; see
[references/delivery-semantics.md](references/delivery-semantics.md).

## Idempotent Consumers

§ idempotency — Because delivery is at-least-once, a consumer **will** see the
same event twice. Make processing idempotent: dedup on the event-id, or design
the side effect to be naturally idempotent (upsert by natural key).

```java
// Spring — dedup table guards the side effect, all in one transaction
@KafkaListener(topics = "orders.v1")
@Transactional
public void onOrderPlaced(ConsumerRecord<String, String> rec,
                          @Header("event-id") String eventId) {
    // INSERT ... ON CONFLICT DO NOTHING returns 0 rows if already processed
    int inserted = processedEvents.markIfNew(eventId);
    if (inserted == 0) {
        return; // duplicate — already handled, ack and move on
    }
    OrderPlaced ev = mapper.read(rec.value());
    inventory.reserve(ev.orderId(), ev.items()); // safe: runs at most once per event-id
}
```

The dedup insert and the side effect must commit in the **same transaction** as
the consumer's own DB; otherwise a crash between them reintroduces the
double-processing you were preventing. Keep the dedup table bounded (TTL/partition
by day).

## Delivery Semantics

| Guarantee | What it means | Cost |
|-----------|---------------|------|
| At-most-once | May lose messages, never duplicates | Cheap; only for tolerable loss |
| **At-least-once** | Never lose, may duplicate | Default; requires idempotent consumers |
| Exactly-once (EOS) | No loss, no duplicate | Bounded, broker-specific, costly |

Build for **at-least-once + idempotent consumers** — it is simpler and more
portable than chasing exactly-once. Ordering is guaranteed only within a
partition/key; if you need per-entity order, key by entity id. Poison messages
(repeatedly failing) go to a **dead-letter queue** after N attempts, then redrive
after a fix. Full broker comparison, partitioning strategy, and DLQ mechanics:
[references/delivery-semantics.md](references/delivery-semantics.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Event lost on producer crash | Publish not atomic with DB write | Transactional outbox | this file, Transactional Outbox |
| Side effect applied twice | Consumer not idempotent | Dedup on event-id in the same tx | this file, Idempotent Consumers |
| Events processed out of order | Wrong/absent partition key | Key by entity id; one consumer per partition | [delivery-semantics.md](references/delivery-semantics.md) § ordering |
| A bad message blocks the partition | No DLQ / infinite retry | Route to DLQ after N attempts, then redrive | [delivery-semantics.md](references/delivery-semantics.md) § dlq |
| Consumer lag grows unbounded | Too few partitions/consumers | Scale partitions + consumer group | [delivery-semantics.md](references/delivery-semantics.md) § scaling |
| Duplicate charges after a retry | Idempotency key not enforced server-side | Persist + check the key before the effect | this file, Idempotent Consumers |
| Outbox grows forever | Relay never prunes published rows | Delete/TTL published rows after publish | this file, Transactional Outbox |

## Deep-Dive References

- [references/delivery-semantics.md](references/delivery-semantics.md) —
  at-least-once vs exactly-once trade-offs, Kafka/RabbitMQ/SQS comparison,
  partitioning and ordering keys, consumer-group scaling, dead-letter queues and
  redrive, change-data-capture (Debezium) as an outbox alternative

## Related Skills

- [microservices-patterns](../microservices-patterns/SKILL.md) — async messaging vs synchronous coupling
- [saga-orchestration](../saga-orchestration/SKILL.md) — events as saga steps and triggers
- [cqrs-event-sourcing](../cqrs-event-sourcing/SKILL.md) — projections built from event streams
- [secure-coding](../../_shared/secure-coding/SKILL.md) — validate event payloads as untrusted input
- [api-security](../../quality/api-security/SKILL.md) — unsafe consumption of upstream APIs/events (API10)
- [be-testing](../../quality/be-testing/SKILL.md) — broker integration tests with Testcontainers
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — broker/runtime feature minimums
