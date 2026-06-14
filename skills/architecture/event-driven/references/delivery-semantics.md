# Delivery Semantics (deep dive)

Detailed trade-offs behind the [../SKILL.md](../SKILL.md) > Delivery Semantics
summary: broker choice, ordering and partitioning, consumer scaling, dead-letter
queues, and change-data-capture as an outbox alternative. Version-gate every
broker feature (Kafka transactions, RabbitMQ quorum queues, SQS FIFO) against
your actual versions — see skill: version-feature-matrix.

## At-Least-Once vs Exactly-Once

| Property | At-least-once | Exactly-once (EOS) |
|----------|---------------|--------------------|
| Loss | Never | Never |
| Duplicates | Possible | None (within the system boundary) |
| Consumer requirement | Must be idempotent | Read-process-write inside a broker transaction |
| Portability | Universal | Broker-specific, breaks at the edge to external systems |
| Cost | Low | Higher latency + coordination overhead |

"Exactly-once" only holds **inside** the broker's transactional boundary (e.g.
Kafka consume→produce→commit-offset in one transaction). The moment a side effect
touches an external system (a payment API, a different database), you are back to
at-least-once and need idempotency. Design for at-least-once + idempotent
consumers and reserve EOS for stream-processing topologies that stay inside one
broker.

## Broker Comparison

| Dimension | Kafka | RabbitMQ | SQS |
|-----------|-------|----------|-----|
| Model | Distributed log (replayable) | Queue / exchange routing | Managed queue |
| Ordering | Per-partition | Per-queue (single consumer) | FIFO queues: per message-group |
| Replay | Yes (offset rewind) | No (consume = remove) | No |
| Retention | Time/size based, re-readable | Until acked | Up to 14 days |
| Dedup | App-level (or EOS) | App-level | FIFO content/id dedup (5-min window) |
| Best for | Event streaming, sourcing, high throughput | Complex routing, RPC-ish work queues | Serverless, simple decoupling on AWS |

Pick the log (Kafka) when you need replay, event sourcing, or many independent
consumer groups over the same stream. Pick a queue (RabbitMQ/SQS) for work
distribution where a message is consumed once and routing flexibility or managed
ops matter more than replay.

## Ordering & Partitioning

§ ordering — Order is guaranteed only within a partition (Kafka), a single-active
queue (RabbitMQ), or a message group (SQS FIFO). To preserve per-entity order:

- Use a stable **partition key** = the entity id (`orderId`, `accountId`).
- Keep **one consumer per partition** within a group; more consumers than
  partitions leaves some idle.
- Never spread one entity's events across partitions expecting order.

```typescript
// Kafka: key by aggregate id so all of one order's events land on one partition
await producer.send({
  topic: 'orders.v1',
  messages: events.map((e) => ({ key: e.orderId, value: JSON.stringify(e) })),
});
```

Trade-off: ordering caps parallelism at the partition count. Pick a key with
enough cardinality (entity id) so partitions stay balanced, not a low-cardinality
key (region) that creates hot partitions.

§ scaling — Scale consumers by adding partitions and consumer-group members
together. Monitor **consumer lag** (committed offset vs log end) and alert when it
trends up; rising lag means you need more partitions, faster processing, or
batching.

## Dead-Letter Queues

§ dlq — A message that fails repeatedly (poison message) will block its partition
or be retried forever. After N delivery attempts, route it to a **dead-letter
queue** so the rest of the stream flows.

```
main topic ──(N failed attempts)──▶ DLQ ──(after fix)──▶ redrive ──▶ main topic
```

| Step | Action |
|------|--------|
| Detect | Count delivery attempts (header/redelivery count) |
| Quarantine | After threshold (e.g. 5), publish to `<topic>.dlq` with failure metadata |
| Alert | DLQ depth > 0 pages on-call; include the original error + offset |
| Redrive | After deploying a fix, replay DLQ messages back to the main topic |

Store the original payload, headers, error, and source offset in the DLQ record
so redrive is lossless. Never silently drop — a DLQ with alerting is the
difference between a contained bug and silent data loss.

```java
// Spring Kafka: DLQ after retries via DefaultErrorHandler + DeadLetterPublishingRecoverer
@Bean
DefaultErrorHandler errorHandler(KafkaTemplate<Object, Object> template) {
    var recoverer = new DeadLetterPublishingRecoverer(template); // -> <topic>.DLT
    var backoff = new ExponentialBackOffWithMaxRetries(4);       // 5 total attempts
    backoff.setInitialInterval(500L);
    return new DefaultErrorHandler(recoverer, backoff);
}
```

## Change-Data-Capture (Outbox Alternative)

Polling an outbox table adds query load and latency. **Log-based CDC** (Debezium
reading the database WAL/binlog) streams committed row changes straight to the
broker with no polling and near-real-time latency.

| Approach | Latency | DB load | Complexity |
|----------|---------|---------|------------|
| Outbox polling | Poll interval | Repeated queries | Low (just SQL + a loop) |
| CDC (Debezium) | Near real-time | Reads the log, not tables | Higher (connector + topic mapping) |

CDC still pairs with the outbox **table** (capture the curated outbox row, not raw
business tables) so consumers get clean domain events, not internal schema
changes. Both paths are at-least-once — idempotent consumers remain mandatory.

## Testing Delivery

Exercise duplicates, reordering, and broker outages before production:
- Spin up the real broker with Testcontainers (Kafka/RabbitMQ/LocalStack-SQS).
- Inject duplicates and assert the consumer's idempotency holds.
- Kill the broker mid-publish and assert the outbox relay recovers.

See [../../../quality/be-testing/SKILL.md](../../../quality/be-testing/SKILL.md)
for the integration-test harness.
