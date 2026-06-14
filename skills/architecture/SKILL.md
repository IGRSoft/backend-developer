---
name: architecture-skills
description: >-
  Back-end architecture skills navigation — microservices, event-driven,
  CQRS/event-sourcing, sagas. Use when decomposing services, designing
  event flows, or choosing consistency models.
---

# Architecture Skills

**Pattern selection and navigation for distributed back-end systems**

## Pattern Selection Table (canonical)

Every architecture decision starts here. Pick the simplest pattern that meets the consistency, coupling, and scaling requirement; if your team or platform is not ready for the distributed option, use the fallback column.

| Need | Pattern | Simpler fallback |
|------|---------|------------------|
| Independent deploy + scale per capability | Microservices (DDD bounded contexts) | Modular monolith (same boundaries, one deploy) |
| One entry point, client-shaped responses | API gateway / BFF | Direct calls + shared client library |
| Survive a downstream outage | Circuit breaker + timeout + retry budget | Plain timeout + fail-fast |
| Decouple producer from consumer in time | Pub/sub over a broker (Kafka/RabbitMQ/SQS) | Synchronous REST call + retry |
| Atomic "write state + publish event" | Transactional outbox + relay | Best-effort publish after commit (lossy) |
| Read-heavy, divergent read vs write shape | CQRS (split command/query models) | One model + read replicas |
| Full audit trail + temporal queries + replay | Event sourcing (event store + projections) | State table + append-only audit log |
| Distributed transaction without 2PC | Saga (orchestration or choreography) | Single-service local transaction |
| Long-running multi-step workflow with rollback | Saga + compensating actions + state machine | Synchronous call chain (no rollback) |
| Guaranteed processing despite duplicates | Idempotent consumer + dedup key | At-most-once delivery (accept loss) |
| Quarantine poison messages | Dead-letter queue + redrive | Drop-on-failure (lossy) |

**Distributed reality (2026):** every distributed pattern below trades the local ACID transaction for eventual consistency, partial failure, and at-least-once delivery. Reach for them only when a modular monolith genuinely cannot meet the scaling, isolation, or deploy-cadence requirement — most teams adopt distribution one boundary at a time. Gate broker/runtime feature use (Kafka exactly-once semantics, RabbitMQ quorum queues, SQS FIFO) on your actual versions rather than version tables from memory.

Per-runtime / broker feature minimums: see skill: version-feature-matrix (`../_shared/version-feature-matrix.md`).

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Split a system into services or a modular monolith | [microservices-patterns/SKILL.md](microservices-patterns/SKILL.md) |
| Draw service boundaries from DDD bounded contexts | [microservices-patterns/SKILL.md](microservices-patterns/SKILL.md) > Service Boundaries |
| Add circuit breaker / retry / bulkhead resilience | [microservices-patterns/SKILL.md](microservices-patterns/SKILL.md) > Resilience |
| Design pub/sub over Kafka/RabbitMQ/SQS | [event-driven/SKILL.md](event-driven/SKILL.md) |
| Publish events atomically with a DB write | [event-driven/SKILL.md](event-driven/SKILL.md) > Transactional Outbox |
| Make a consumer idempotent | [event-driven/SKILL.md](event-driven/SKILL.md) > Idempotent Consumers |
| Separate command and query models | [cqrs-event-sourcing/SKILL.md](cqrs-event-sourcing/SKILL.md) |
| Store events and rebuild read models | [cqrs-event-sourcing/SKILL.md](cqrs-event-sourcing/SKILL.md) > Event Store |
| Coordinate a distributed transaction | [saga-orchestration/SKILL.md](saga-orchestration/SKILL.md) |
| Choose orchestration vs choreography | [saga-orchestration/SKILL.md](saga-orchestration/SKILL.md) > Orchestration vs Choreography |

## Decision Tree

```
Architecture task?
├── Which pattern fits requirement X? → Pattern Selection Table (above)
├── Decomposing a system → microservices-patterns/SKILL.md
│   ├── Boundaries from bounded contexts → microservices-patterns/SKILL.md > Service Boundaries
│   ├── Gateway / BFF / discovery → microservices-patterns/SKILL.md > Edge & Discovery
│   ├── Resilience (breaker/retry/bulkhead/timeout) → microservices-patterns/SKILL.md > Resilience
│   └── Data per service → microservices-patterns/SKILL.md > Data Ownership
├── Decoupling via messages → event-driven/SKILL.md
│   ├── Atomic publish → event-driven/SKILL.md > Transactional Outbox
│   ├── Dedup / ordering / DLQ → event-driven/SKILL.md > Delivery Semantics
│   └── Idempotent processing → event-driven/SKILL.md > Idempotent Consumers
├── Split read/write or audit/replay → cqrs-event-sourcing/SKILL.md
│   ├── Projections & read models → cqrs-event-sourcing/SKILL.md > Projections
│   └── Event versioning & snapshots → cqrs-event-sourcing/SKILL.md > Evolution
├── Distributed transaction w/o 2PC → saga-orchestration/SKILL.md
│   ├── Compensating transactions → saga-orchestration/SKILL.md > Compensation
│   └── State machine & timeouts → saga-orchestration/SKILL.md > State & Failure
└── Reviewing an architecture proposal → Task(backend-developer:backend-architector)
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the architecture/ subtree |
| [microservices-patterns/SKILL.md](microservices-patterns/SKILL.md) | Boundaries, gateway/BFF, discovery, resilience, data-per-service |
| [event-driven/SKILL.md](event-driven/SKILL.md) | Pub/sub, brokers, outbox, idempotency, ordering, DLQ |
| [cqrs-event-sourcing/SKILL.md](cqrs-event-sourcing/SKILL.md) | Command/query split, event store, projections, snapshots, replay |
| [saga-orchestration/SKILL.md](saga-orchestration/SKILL.md) | Orchestration vs choreography, compensation, state machines |

## Related Skills

- [secure-coding](../_shared/secure-coding/SKILL.md) — auth boundaries and injection-safe handling across service edges
- [api-security](../quality/api-security/SKILL.md) — OWASP API Top 10 controls at every service boundary
- [be-testing](../quality/be-testing/SKILL.md) — integration tests with Testcontainers for brokers and stores
- [version-feature-matrix](../_shared/version-feature-matrix.md) — runtime/broker feature minimums per pattern
