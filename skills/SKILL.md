---
name: skills
description: >-
  Comprehensive back-end and web-service development skills across Node.js/TypeScript,
  Go, JVM (Spring Boot/Kotlin), Python web (FastAPI/Django/Flask), Ruby (Rails),
  PHP (Laravel/Symfony), .NET, REST/GraphQL/gRPC API design, database engineering,
  distributed architecture, and cross-cutting quality/security/observability disciplines.
  Use when writing or reviewing HTTP/RPC services, designing API contracts, modeling
  database schemas, applying event-driven/CQRS architecture, containerizing services,
  or hardening an API against the OWASP API Security Top 10.
---

# Skills Index

## Overview

This collection provides guidance for building production web and service
back-ends across seven primary runtimes — Node.js/TypeScript, Go, the JVM
(Spring Boot + Kotlin), Python web (FastAPI/Django/Flask), Ruby (Rails),
PHP (Laravel/Symfony), and .NET — plus the cross-cutting disciplines that
design APIs, model data, shape architecture, and ship/observe services.
The emphasis is on **version specificity**: every framework and runtime
feature carries a version marker and a fallback path, so guidance stays
correct whether you target Node 20 LTS or 22, Go 1.22 or 1.23, Spring Boot
3.2 or 3.4, FastAPI 0.110+ or Django 5.x. When a version claim matters, verify
it against your runtime and the canonical
[`_shared/version-feature-matrix.md`](_shared/version-feature-matrix.md) rather
than trusting memory.

## Quick Navigation

| Domain | Entry | Skills | Focus |
|--------|-------|--------|-------|
| [Node/TS](#nodets) | [`node/SKILL.md`](node/SKILL.md) | 1 + 3 leaves | Modern TS, NestJS/Fastify/Hono, async streams, vitest/jest, tsc strict |
| [Go](#go) | [`go/SKILL.md`](go/SKILL.md) | 1 + 2 leaves | net/http, Gin/Echo/chi, contexts, goroutines, table tests, govet/golangci-lint |
| [JVM](#jvm) | [`jvm/SKILL.md`](jvm/SKILL.md) | 1 + 2 leaves | Spring Boot, JPA/Hibernate, reactive WebFlux, Kotlin coroutines, JUnit 5, Testcontainers |
| [Python Web](#python-web) | [`python-web/SKILL.md`](python-web/SKILL.md) | 1 + 3 leaves | FastAPI/Django/Flask, async, pydantic, SQLAlchemy, pytest |
| [API](#api) | [`api/SKILL.md`](api/SKILL.md) | 1 + 5 leaves | REST/GraphQL/gRPC/WebSockets, OpenAPI contracts, versioning, pagination |
| [Data](#data) | [`data/SKILL.md`](data/SKILL.md) | 1 + 5 leaves | Schema design, migrations, indexing, N+1, transactions, Postgres/MySQL/Mongo/Redis |
| [Architecture](#architecture) | [`architecture/SKILL.md`](architecture/SKILL.md) | 1 + 4 leaves | Microservices, event-driven/CQRS, saga, idempotency, caching |
| [Tooling](#tooling) | [`tooling/SKILL.md`](tooling/SKILL.md) | 1 + 3 leaves | Docker/Compose, structured logs, OpenTelemetry traces/metrics, CI, diagnostics |
| [Quality](#quality) | [`quality/SKILL.md`](quality/SKILL.md) | 1 + 3 leaves | Test pyramid, integration tests, load testing, API security, review gates |
| [Shared](#shared) | [`_shared/_index.md`](_shared/_index.md) | 2 SKILL.md + references | Workflow integration, secure coding, versions, routing, severity |

**Total: 42 SKILL.md across 10 domains, plus shared reference files.**

## I need help with...

| Task | Go to |
|------|-------|
| Choosing NestJS vs Express vs Fastify vs Hono baseline | [node/nest-express-fastify-patterns/SKILL.md](node/nest-express-fastify-patterns/SKILL.md) |
| TypeScript-strict patterns, async/await, generics, branded types | [node/modern-typescript-backend/SKILL.md](node/modern-typescript-backend/SKILL.md) |
| Node.js streams, event-loop, Worker threads, backpressure | [node/node-async-streams/SKILL.md](node/node-async-streams/SKILL.md) |
| Writing or triaging vitest/jest/pytest/JUnit tests for a service | [quality/be-testing/SKILL.md](quality/be-testing/SKILL.md) |
| Structuring a Go HTTP service, contexts, graceful shutdown | [go/modern-go/SKILL.md](go/modern-go/SKILL.md) |
| Go goroutines, channels, select, race detector | [go/go-concurrency/SKILL.md](go/go-concurrency/SKILL.md) |
| Spring Boot controllers, JPA mapping, transactions, WebFlux | [jvm/spring-boot/SKILL.md](jvm/spring-boot/SKILL.md) |
| Kotlin coroutines, suspend functions, Flow, structured concurrency | [jvm/kotlin-backend/SKILL.md](jvm/kotlin-backend/SKILL.md) |
| FastAPI routing, Pydantic v2, dependency injection, async | [python-web/fastapi/SKILL.md](python-web/fastapi/SKILL.md) |
| Django ORM, class-based views, DRF, async views | [python-web/django/SKILL.md](python-web/django/SKILL.md) |
| Flask blueprints, app factory, SQLAlchemy, async Flask | [python-web/flask/SKILL.md](python-web/flask/SKILL.md) |
| Designing a REST resource model, versioning, pagination | [api/rest-design/SKILL.md](api/rest-design/SKILL.md) |
| GraphQL schemas, N+1, DataLoader, persisted queries | [api/graphql-design/SKILL.md](api/graphql-design/SKILL.md) |
| gRPC/protobuf, streaming, deadlines, status codes | [api/grpc-design/SKILL.md](api/grpc-design/SKILL.md) |
| OpenAPI specs, schema-first codegen, linting contracts | [api/openapi-contracts/SKILL.md](api/openapi-contracts/SKILL.md) |
| API versioning strategies and deprecation lifecycle | [api/api-versioning/SKILL.md](api/api-versioning/SKILL.md) |
| Modeling a schema, indexes, choosing a database | [data/schema-design/SKILL.md](data/schema-design/SKILL.md) |
| Writing a safe migration, expand/contract, Flyway/Liquibase/Alembic | [data/migrations/SKILL.md](data/migrations/SKILL.md) |
| Fixing an N+1, reading EXPLAIN, choosing indexes | [data/query-optimization/SKILL.md](data/query-optimization/SKILL.md) |
| Prisma/Drizzle/GORM/JPA/SQLAlchemy ORM patterns | [data/orm-patterns/SKILL.md](data/orm-patterns/SKILL.md) |
| Redis cache-aside, TTL, stampede prevention, invalidation | [data/caching-strategies/SKILL.md](data/caching-strategies/SKILL.md) |
| Microservice/modular-monolith layout, dependency boundaries | [architecture/microservices-patterns/SKILL.md](architecture/microservices-patterns/SKILL.md) |
| Event-driven/CQRS, Kafka/RabbitMQ/SQS, transactional outbox | [architecture/event-driven/SKILL.md](architecture/event-driven/SKILL.md) |
| CQRS + event sourcing, projected read models | [architecture/cqrs-event-sourcing/SKILL.md](architecture/cqrs-event-sourcing/SKILL.md) |
| Saga pattern (orchestration or choreography), compensations | [architecture/saga-orchestration/SKILL.md](architecture/saga-orchestration/SKILL.md) |
| Dockerfile, Compose, multi-stage builds, image hygiene | [tooling/containerization/SKILL.md](tooling/containerization/SKILL.md) |
| Structured logging, OpenTelemetry traces and metrics | [tooling/observability/SKILL.md](tooling/observability/SKILL.md) |
| Debugging a live service, profiling, slow-query triage | [tooling/be-diagnostics/SKILL.md](tooling/be-diagnostics/SKILL.md) |
| Building a test pyramid, integration and load tests | [quality/be-testing/SKILL.md](quality/be-testing/SKILL.md) |
| API security — OWASP API Top 10 checklist and remediations | [quality/api-security/SKILL.md](quality/api-security/SKILL.md) |
| Performance budgets, load testing with k6, DR perf gate | [quality/be-performance/SKILL.md](quality/be-performance/SKILL.md) |
| Reviewing auth, untrusted input, secrets, or SSRF | [_shared/secure-coding/SKILL.md](_shared/secure-coding/SKILL.md) |
| Participating in an igrsoft workflow stage | [_shared/workflow-integration/SKILL.md](_shared/workflow-integration/SKILL.md) |
| Confirming a feature is available on a runtime/framework | [_shared/version-feature-matrix.md](_shared/version-feature-matrix.md) |
| Routing a file or repo to the right agent | [_shared/language-detection.md](_shared/language-detection.md) |

---

## Node/TS

Modern TypeScript, NestJS/Express/Fastify/Hono service patterns, async streams,
and vitest/jest testing.

**Start here:** [node/SKILL.md](node/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **modern-typescript-backend** | [node/modern-typescript-backend/SKILL.md](node/modern-typescript-backend/SKILL.md) | TypeScript-strict config, generics, discriminated unions, branded types, `satisfies`, `@tsconfig/strictest` baseline |
| **nest-express-fastify-patterns** | [node/nest-express-fastify-patterns/SKILL.md](node/nest-express-fastify-patterns/SKILL.md) | Framework selection, NestJS modules/interceptors, Fastify plugins, Express middleware, Hono routing, error handling, graceful shutdown |
| **node-async-streams** | [node/node-async-streams/SKILL.md](node/node-async-streams/SKILL.md) | Event loop model, `async_hooks`, Worker threads, Node streams v2, backpressure, `stream.pipeline`, `AbortSignal` propagation |

---

## Go

net/http and Gin/Echo/chi service patterns, context propagation, goroutine
discipline, and table-driven testing.

**Start here:** [go/SKILL.md](go/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **modern-go** | [go/modern-go/SKILL.md](go/modern-go/SKILL.md) | Idiomatic handlers, context and cancellation, error wrapping (`%w`), graceful shutdown, structured config, iterator ranges (1.22+) |
| **go-concurrency** | [go/go-concurrency/SKILL.md](go/go-concurrency/SKILL.md) | Goroutines, channels, `select`, `sync.WaitGroup`/`errgroup`, context propagation, race detector, `govulncheck`, table-driven tests with `httptest` |

---

## JVM

Spring Boot service patterns, JPA/Hibernate persistence, reactive WebFlux, Kotlin
coroutines, and JUnit 5 + Testcontainers testing.

**Start here:** [jvm/SKILL.md](jvm/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **spring-boot** | [jvm/spring-boot/SKILL.md](jvm/spring-boot/SKILL.md) | Controllers/services/repositories, JPA mapping, `@Transactional` boundaries, validation, reactive WebFlux, GraalVM native images, virtual threads (JDK 21) |
| **kotlin-backend** | [jvm/kotlin-backend/SKILL.md](jvm/kotlin-backend/SKILL.md) | Kotlin coroutines, `suspend` functions, `Flow`, structured concurrency, coroutine context, idiomatic Kotlin Spring Boot patterns |

---

## Python Web

FastAPI/Django/Flask service patterns, async request handling, pydantic
validation, SQLAlchemy, and pytest testing.

**Start here:** [python-web/SKILL.md](python-web/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **fastapi** | [python-web/fastapi/SKILL.md](python-web/fastapi/SKILL.md) | Pydantic v2 models, dependency injection, async endpoints, lifespan, background tasks, OpenAPI generation |
| **django** | [python-web/django/SKILL.md](python-web/django/SKILL.md) | ORM, migrations, class-based views, DRF serializers/viewsets, async views (5.x), signals, custom managers |
| **flask** | [python-web/flask/SKILL.md](python-web/flask/SKILL.md) | App factory, blueprints, SQLAlchemy integration, Marshmallow, async Flask (`flask[async]`), testing with `pytest-flask` |

---

## API

REST/GraphQL/gRPC/WebSocket contract design, versioning, pagination, and
error-model conventions.

**Start here:** [api/SKILL.md](api/SKILL.md) — holds the canonical protocol-selection table.

| Skill | Path | Description |
|-------|------|-------------|
| **rest-design** | [api/rest-design/SKILL.md](api/rest-design/SKILL.md) | Resource modeling, HTTP status codes, OpenAPI contracts, versioning, cursor/offset pagination, idempotency keys |
| **graphql-design** | [api/graphql-design/SKILL.md](api/graphql-design/SKILL.md) | Schema-first SDL, Relay-style connections, DataLoader batching, query cost/depth limits, persisted queries (OWASP API4) |
| **grpc-design** | [api/grpc-design/SKILL.md](api/grpc-design/SKILL.md) | proto3 field numbering, `reserved` ranges, deadlines on every call, `google.rpc.Status` errors, streaming semantics and backpressure |
| **openapi-contracts** | [api/openapi-contracts/SKILL.md](api/openapi-contracts/SKILL.md) | OpenAPI 3.1 schema authoring, schema-first codegen (oapi-codegen, openapi-typescript, springdoc), contract linting with Spectral |
| **api-versioning** | [api/api-versioning/SKILL.md](api/api-versioning/SKILL.md) | URI vs header vs content-type versioning trade-offs, deprecation timeline, sunset headers, migration guide generation |

---

## Data

Database schema design, safe migrations, query performance, and storage-engine
selection across PostgreSQL/MySQL/MongoDB/Redis.

**Start here:** [data/SKILL.md](data/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **schema-design** | [data/schema-design/SKILL.md](data/schema-design/SKILL.md) | Normalization, indexing strategy, constraints, relational vs document vs cache trade-offs, polymorphism patterns |
| **migrations** | [data/migrations/SKILL.md](data/migrations/SKILL.md) | Expand/contract migrations, zero-downtime adds/drops, Flyway/Liquibase/Alembic/golang-migrate recipes, rollback safety |
| **query-optimization** | [data/query-optimization/SKILL.md](data/query-optimization/SKILL.md) | N+1 elimination, `EXPLAIN`/`EXPLAIN ANALYZE` reading, index type selection (B-tree/GIN/GiST/covering), slow-query triage |
| **orm-patterns** | [data/orm-patterns/SKILL.md](data/orm-patterns/SKILL.md) | Prisma, Drizzle, TypeORM, GORM, Hibernate/JPA, SQLAlchemy 2.0, EF Core — entity design, eager loading, transaction scope, escaping to raw SQL |
| **caching-strategies** | [data/caching-strategies/SKILL.md](data/caching-strategies/SKILL.md) | Cache-aside, read-through, write-behind, Redis data structures, TTL selection, stampede prevention, cache invalidation triggers |

---

## Architecture

Service layout, transaction boundaries, idempotency, event-driven/CQRS, messaging,
and caching strategy.

**Start here:** [architecture/SKILL.md](architecture/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **microservices-patterns** | [architecture/microservices-patterns/SKILL.md](architecture/microservices-patterns/SKILL.md) | Modular monolith vs microservices trade-offs, layered/hexagonal dependency boundaries, idempotency, transaction scope, service decomposition |
| **event-driven** | [architecture/event-driven/SKILL.md](architecture/event-driven/SKILL.md) | Pub/sub, Kafka/RabbitMQ/SQS patterns, transactional outbox, at-least-once delivery, idempotent consumers, cache invalidation via events |
| **cqrs-event-sourcing** | [architecture/cqrs-event-sourcing/SKILL.md](architecture/cqrs-event-sourcing/SKILL.md) | Write/read model separation, event store design, projected read models, snapshot strategy, eventual-consistency handling |
| **saga-orchestration** | [architecture/saga-orchestration/SKILL.md](architecture/saga-orchestration/SKILL.md) | Orchestration (central coordinator) vs choreography (reactive events), compensation transactions, failure/retry handling |

---

## Tooling

Containerization and observability for all runtimes, plus runtime diagnostics.

**Start here:** [tooling/SKILL.md](tooling/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **containerization** | [tooling/containerization/SKILL.md](tooling/containerization/SKILL.md) | Multi-stage Dockerfiles, Compose for local stacks, image size/security hygiene, healthchecks, distroless/scratch bases |
| **observability** | [tooling/observability/SKILL.md](tooling/observability/SKILL.md) | Structured JSON logging, OpenTelemetry traces and metrics, correlation IDs, RED/USE signals, alerting thresholds |
| **be-diagnostics** | [tooling/be-diagnostics/SKILL.md](tooling/be-diagnostics/SKILL.md) | Live service debugging, pprof/py-spy/async-profiler/dotnet-trace profiling, slow-query tracing, heap dumps, CPU flame graphs |

---

## Quality

Testing strategy, load testing, API security, and code-review gates across the stack.

**Start here:** [quality/SKILL.md](quality/SKILL.md)

| Skill | Path | Description |
|-------|------|-------------|
| **be-testing** | [quality/be-testing/SKILL.md](quality/be-testing/SKILL.md) | Test pyramid for services (unit/integration/contract/e2e), Testcontainers for real DBs/brokers, k6 load tests, coverage targets |
| **be-performance** | [quality/be-performance/SKILL.md](quality/be-performance/SKILL.md) | Performance review gate, k6 load budgets, p95/p99 latency targets, DR perf criteria, profiling workflow |
| **api-security** | [quality/api-security/SKILL.md](quality/api-security/SKILL.md) | OWASP API Security Top 10 (2023) checklist, auth/authz review patterns, injection and SSRF scanning, security-scan gate for DR/QA |

---

## Shared

Cross-cutting patterns used by every agent, command, and skill.

**Start here:** [_shared/_index.md](_shared/_index.md)

| Skill | Path | Description |
|-------|------|-------------|
| **secure-coding** | [_shared/secure-coding/SKILL.md](_shared/secure-coding/SKILL.md) | Non-negotiable security rules mapped to the OWASP API Security Top 10, injection prevention, secrets hygiene, supply-chain |
| **workflow-integration** | [_shared/workflow-integration/SKILL.md](_shared/workflow-integration/SKILL.md) | Integrating with the igrsoft 11-stage workflow system (v3.17.0) — DV/DR/QA artifact format and evidence gate |
| version-feature-matrix | [_shared/version-feature-matrix.md](_shared/version-feature-matrix.md) | Runtimes/frameworks → minimum versions + headline features (canonical) |
| language-detection | [_shared/language-detection.md](_shared/language-detection.md) | Marker → runtime → agent routing table, front-end vs back-end tie-break |
| model-selection | [_shared/model-selection.md](_shared/model-selection.md) | Per-agent model/effort/maxTurns assignments |
| severity-matrix | [_shared/severity-matrix.md](_shared/severity-matrix.md) | Severity levels, P0-P3 priorities, coverage requirements |
| testing-principles | [_shared/testing-principles.md](_shared/testing-principles.md) | Test pyramid, per-runtime framework matrix, quality gates |

---

## Cross-Stack Version Snapshot

A summary only — the canonical lookup with minimum versions and fallback rows is
[`_shared/version-feature-matrix.md`](_shared/version-feature-matrix.md).
Framework-support tables shift between minor releases; verify against your
runtime before relying on a feature.

| Runtime / Framework | Baseline | Newest | Headline of the newest |
|---------------------|----------|--------|------------------------|
| Node.js | 20 LTS | 22 LTS | Stable native `fetch`/`WebSocket`, built-in `node:test` runner, `--watch`, permission model (verify against your version) |
| Go | 1.22 | 1.23 | Ranging over functions (iterators), `for` loop per-iteration scoping, enhanced routing patterns in `net/http` |
| Spring Boot (JVM) | 3.2 (Java 17) | 3.4 (Java 21) | Virtual threads, GraalVM AOT/native images, observability via Micrometer, RestClient |
| Python web | FastAPI 0.110 / Django 4.2 LTS | FastAPI 0.115+ / Django 5.1 | ASGI maturity, pydantic v2, async ORM (Django), per-request lifespan/deps (verify against your version) |

> **Database/driver caveat:** ORM and driver feature support (e.g. Prisma
> relation modes, Hibernate 6 query rewriting, SQLAlchemy 2.0 async) varies by
> minor version and database engine — verify against your driver and engine. See
> [data/migrations/SKILL.md](data/migrations/SKILL.md).

## Conventions

- **Version markers everywhere.** Every version-specific claim names a runtime or
  framework version and links to the matrix; volatile minutiae are hedged with
  "verify against your runtime" instead of asserting an uncertain minor version.
- **Secure by default (OWASP API).** Every endpoint enforces authentication and
  object/function-level authorization (API1/API3/API5), rate limits and bounds
  resource consumption (API4), and never trusts client-supplied identity — see
  [_shared/secure-coding/SKILL.md](_shared/secure-coding/SKILL.md).
- **Parameterized queries only.** All database access uses parameterized
  statements or ORM bindings; string-built SQL/NoSQL is treated as a defect — see
  [data/orm-patterns/SKILL.md](data/orm-patterns/SKILL.md).

## Related Documentation

- [`_shared/version-feature-matrix.md`](_shared/version-feature-matrix.md) — canonical version/runtime lookup
- [`_shared/language-detection.md`](_shared/language-detection.md) — file/repo → agent routing
- [`_shared/workflow-integration/SKILL.md`](_shared/workflow-integration/SKILL.md) — igrsoft 11-stage integration
- [`_index.md`](_index.md) — full navigation index of every skill directory
