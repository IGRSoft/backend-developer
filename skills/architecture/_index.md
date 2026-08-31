# Architecture Skills Index

Quick navigation for distributed back-end architecture patterns.

## Core Skills

| File | Description |
|------|-------------|
| `SKILL.md` | Entry point: canonical pattern-selection table (need → pattern → simpler fallback), decision tree |
| `microservices-patterns/SKILL.md` | Service boundaries (DDD bounded contexts), API gateway/BFF, discovery, resilience (breaker/retry/bulkhead/timeout), data per service, backing services as attached resources, stateless processes and process-type scale-out |
| `event-driven/SKILL.md` | Pub/sub, brokers (Kafka/RabbitMQ/SQS), transactional outbox, idempotent consumers, ordering, dead-letter queues |
| `cqrs-event-sourcing/SKILL.md` | Command/query separation, event store, projections/read models, snapshots, event versioning, replay |
| `saga-orchestration/SKILL.md` | Orchestration vs choreography, compensating transactions, state machines, timeout/failure handling |

## Subdirectories

| Directory | Contents | Description |
|-----------|----------|-------------|
| `microservices-patterns/` | 1 skill + 1 ref | Decomposition, edge, discovery, resilience, data ownership |
| `event-driven/` | 1 skill + 1 ref | Message-driven integration, delivery semantics, outbox |
| `cqrs-event-sourcing/` | 1 skill | Read/write split, event store, projections, evolution |
| `saga-orchestration/` | 1 skill | Distributed transactions without 2PC, compensation |

## Reference Files

| File | Use it for |
|------|------------|
| `microservices-patterns/references/resilience-patterns.md` | Circuit breaker tuning, retry budgets/jitter, bulkhead isolation, timeout hierarchy, deadline propagation |
| `event-driven/references/delivery-semantics.md` | At-least-once vs exactly-once, ordering keys, partitioning, DLQ/redrive, broker comparison |

## Quick Links by Problem

### "I need to..."

- **Pick a pattern for requirement X** → `SKILL.md` > Pattern Selection Table
- **Decide microservices vs modular monolith** → `microservices-patterns/SKILL.md` > Monolith First
- **Draw boundaries from bounded contexts** → `microservices-patterns/SKILL.md` > Service Boundaries
- **Stop a cascading failure** → `microservices-patterns/SKILL.md` > Resilience
- **Decide whether two apps may share one codebase** → `microservices-patterns/SKILL.md` > Monolith First
- **Swap a local dependency for a managed one** → `microservices-patterns/SKILL.md` > Backing services are attached resources
- **Make a service safe to scale out** → `microservices-patterns/SKILL.md` > Stateless Processes
- **Get rid of sticky sessions** → `microservices-patterns/SKILL.md` > Stateless Processes
- **Publish an event atomically with a DB write** → `event-driven/SKILL.md` > Transactional Outbox
- **Make a consumer safe under retries** → `event-driven/SKILL.md` > Idempotent Consumers
- **Guarantee per-key ordering** → `event-driven/references/delivery-semantics.md`
- **Split a read-heavy model** → `cqrs-event-sourcing/SKILL.md`
- **Rebuild a read model after a bug** → `cqrs-event-sourcing/SKILL.md` > Replay
- **Version events without breaking consumers** → `cqrs-event-sourcing/SKILL.md` > Evolution
- **Roll back a distributed transaction** → `saga-orchestration/SKILL.md` > Compensation
- **Choose orchestration vs choreography** → `saga-orchestration/SKILL.md` > Orchestration vs Choreography
- **Add API-edge security controls** → `../quality/api-security/SKILL.md`
- **Integration-test a broker** → `../quality/be-testing/SKILL.md`
