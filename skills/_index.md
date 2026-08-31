# Skills Index

Root index for all backend-developer skills (Node/TS, Go, JVM/Spring, Python web,
plus API, data, architecture, tooling, quality, and shared cross-cutting
patterns). **41 SKILL.md across 10 domains, plus shared and per-skill reference
files.** Start at [`SKILL.md`](SKILL.md) for the routing entry point.

## Domains

| Directory | Index | Skills | Description |
|-----------|-------|--------|-------------|
| [_shared/](_shared/_index.md) | [`_index.md`](_shared/_index.md) | 1 + 5 refs | Cross-cutting: secure coding (OWASP API), version floors, language routing, model selection, severity, testing principles |
| [node/](node/SKILL.md) | [`_index.md`](node/_index.md) | 1 entry + 3 leaves | Modern TypeScript back-ends, Nest/Express/Fastify patterns, async and streams |
| [go/](go/SKILL.md) | [`_index.md`](go/_index.md) | 1 entry + 2 leaves | Idiomatic modern Go services, context, concurrency patterns |
| [jvm/](jvm/SKILL.md) | [`_index.md`](jvm/_index.md) | 1 entry + 2 leaves | Spring Boot, JPA/Hibernate performance, Kotlin back-ends |
| [python-web/](python-web/SKILL.md) | [`_index.md`](python-web/_index.md) | 1 entry + 3 leaves | FastAPI, Django, Flask |
| [api/](api/SKILL.md) | [`_index.md`](api/_index.md) | 1 entry + 5 leaves | REST, GraphQL, gRPC contract design, OpenAPI, versioning |
| [data/](data/SKILL.md) | [`_index.md`](data/_index.md) | 1 entry + 5 leaves | Schema design, migrations, query optimization, ORM patterns, caching |
| [architecture/](architecture/SKILL.md) | [`_index.md`](architecture/_index.md) | 1 entry + 4 leaves | Microservices vs monolith, event-driven, CQRS/event sourcing, sagas |
| [tooling/](tooling/SKILL.md) | [`_index.md`](tooling/_index.md) | 1 entry + 3 leaves | Containerization and the runtime contract, diagnostics, observability |
| [quality/](quality/SKILL.md) | [`_index.md`](quality/_index.md) | 1 entry + 3 leaves | OWASP API security, performance and load testing, test strategy |

## All Skills

### _shared

| Skill | Path | Description |
|-------|------|-------------|
| **secure-coding** | [`_shared/secure-coding/SKILL.md`](_shared/secure-coding/SKILL.md) | Non-negotiable rules mapped to the OWASP API Security Top 10 (2023) — BOLA/BFLA, authn, rate limiting, SSRF, injection, secrets hygiene and the config-in-the-environment litmus test |
| language-detection | [`_shared/language-detection.md`](_shared/language-detection.md) | Marker → runtime → agent routing table, detection priority, tie-breaking |
| model-selection | [`_shared/model-selection.md`](_shared/model-selection.md) | Per-agent model/effort/maxTurns assignments and the opus+xhigh override path |
| severity-matrix | [`_shared/severity-matrix.md`](_shared/severity-matrix.md) | P0-P3 severity definitions shared by every review command |
| testing-principles | [`_shared/testing-principles.md`](_shared/testing-principles.md) | Test pyramid, per-runtime framework matrix, quality gates, anti-patterns |
| version-feature-matrix | [`_shared/version-feature-matrix.md`](_shared/version-feature-matrix.md) | Runtimes/frameworks → minimum versions and headline features (canonical lookup) |

References: [`command-execution-and-injection.md`](_shared/secure-coding/references/command-execution-and-injection.md), [`input-validation-and-parsing.md`](_shared/secure-coding/references/input-validation-and-parsing.md).

### node

| Skill | Path | Description |
|-------|------|-------------|
| **node-skills** (entry) | [`node/SKILL.md`](node/SKILL.md) | Node/TypeScript navigation: framework selection, typing, async |
| **modern-typescript-backend** | [`node/modern-typescript-backend/SKILL.md`](node/modern-typescript-backend/SKILL.md) | Strict TypeScript for services, module and config shape, type-level API boundaries |
| **nest-express-fastify-patterns** | [`node/nest-express-fastify-patterns/SKILL.md`](node/nest-express-fastify-patterns/SKILL.md) | Framework selection and idioms across NestJS, Express, Fastify, Hono |
| **node-async-streams** | [`node/node-async-streams/SKILL.md`](node/node-async-streams/SKILL.md) | Promises and backpressure, streams, worker threads, graceful shutdown |

References: [`typescript-anti-patterns.md`](node/modern-typescript-backend/references/typescript-anti-patterns.md), [`framework-deep-dive.md`](node/nest-express-fastify-patterns/references/framework-deep-dive.md), [`streams-and-workers.md`](node/node-async-streams/references/streams-and-workers.md).

### go

| Skill | Path | Description |
|-------|------|-------------|
| **go-skills** (entry) | [`go/SKILL.md`](go/SKILL.md) | Go navigation: idiomatic HTTP services, concurrency |
| **modern-go** | [`go/modern-go/SKILL.md`](go/modern-go/SKILL.md) | net/http and Gin/Echo/chi, error wrapping, config, structured logging |
| **go-concurrency** | [`go/go-concurrency/SKILL.md`](go/go-concurrency/SKILL.md) | Goroutines, `context` propagation and cancellation, graceful shutdown, leak avoidance |

References: [`concurrency-patterns.md`](go/go-concurrency/references/concurrency-patterns.md).

### jvm

| Skill | Path | Description |
|-------|------|-------------|
| **jvm-skills** (entry) | [`jvm/SKILL.md`](jvm/SKILL.md) | JVM navigation: Spring Boot, persistence, Kotlin |
| **spring-boot** | [`jvm/spring-boot/SKILL.md`](jvm/spring-boot/SKILL.md) | Controllers/services/repositories, `@Transactional` boundaries, validation, WebFlux, security config |
| **kotlin-backend** | [`jvm/kotlin-backend/SKILL.md`](jvm/kotlin-backend/SKILL.md) | Kotlin idioms for services, coroutines, null-safety at the boundary |

References: [`jpa-performance.md`](jvm/spring-boot/references/jpa-performance.md).

### python-web

| Skill | Path | Description |
|-------|------|-------------|
| **python-web-skills** (entry) | [`python-web/SKILL.md`](python-web/SKILL.md) | Python web navigation across FastAPI, Django, Flask |
| **fastapi** | [`python-web/fastapi/SKILL.md`](python-web/fastapi/SKILL.md) | Routing, dependency injection, Pydantic models, async correctness, settings |
| **django** | [`python-web/django/SKILL.md`](python-web/django/SKILL.md) | Views, DRF serializers, ORM and queryset scoping, migrations |
| **flask** | [`python-web/flask/SKILL.md`](python-web/flask/SKILL.md) | Blueprints, app factory, extensions, request lifecycle |

References: [`fastapi-advanced.md`](python-web/fastapi/references/fastapi-advanced.md), [`django-advanced.md`](python-web/django/references/django-advanced.md), [`flask-advanced.md`](python-web/flask/references/flask-advanced.md).

### api

| Skill | Path | Description |
|-------|------|-------------|
| **api-skills** (entry) | [`api/SKILL.md`](api/SKILL.md) | Canonical protocol-selection table for REST/GraphQL/gRPC |
| **rest-design** | [`api/rest-design/SKILL.md`](api/rest-design/SKILL.md) | Resource modeling, status codes, pagination, idempotency keys, error envelopes |
| **graphql-design** | [`api/graphql-design/SKILL.md`](api/graphql-design/SKILL.md) | Schema design, N+1 batching with DataLoader, depth/complexity limits |
| **grpc-design** | [`api/grpc-design/SKILL.md`](api/grpc-design/SKILL.md) | Protobuf contracts, streaming modes, deadlines, status codes |
| **openapi-contracts** | [`api/openapi-contracts/SKILL.md`](api/openapi-contracts/SKILL.md) | Spec-first vs code-first, generation, drift detection |
| **api-versioning** | [`api/api-versioning/SKILL.md`](api/api-versioning/SKILL.md) | Version placement, breaking-change policy, deprecation and sunset |

References: [`rest-semantics.md`](api/rest-design/references/rest-semantics.md), [`graphql-security.md`](api/graphql-design/references/graphql-security.md).

### data

| Skill | Path | Description |
|-------|------|-------------|
| **data-skills** (entry) | [`data/SKILL.md`](data/SKILL.md) | Data navigation: schema, migrations, queries, ORM, caching |
| **schema-design** | [`data/schema-design/SKILL.md`](data/schema-design/SKILL.md) | Normalization vs denormalization, keys and constraints, relational vs document modeling |
| **migrations** | [`data/migrations/SKILL.md`](data/migrations/SKILL.md) | Expand-contract zero-downtime, online DDL and locking, backfills, reversibility, admin processes against the release |
| **query-optimization** | [`data/query-optimization/SKILL.md`](data/query-optimization/SKILL.md) | EXPLAIN ANALYZE, index selection, N+1 elimination, pagination, slow-query triage |
| **orm-patterns** | [`data/orm-patterns/SKILL.md`](data/orm-patterns/SKILL.md) | Prisma/Drizzle/TypeORM/GORM/Hibernate/EF Core/SQLAlchemy — pooling, lazy vs eager, transactions |
| **caching-strategies** | [`data/caching-strategies/SKILL.md`](data/caching-strategies/SKILL.md) | Cache-aside/write-through, invalidation, TTL/eviction, session and per-request state, distributed locks, idempotency stores |

References: [`advanced-modeling.md`](data/schema-design/references/advanced-modeling.md), [`per-tool-recipes.md`](data/migrations/references/per-tool-recipes.md).

### architecture

| Skill | Path | Description |
|-------|------|-------------|
| **architecture-skills** (entry) | [`architecture/SKILL.md`](architecture/SKILL.md) | Canonical pattern-selection table (need → pattern → simpler fallback) |
| **microservices-patterns** | [`architecture/microservices-patterns/SKILL.md`](architecture/microservices-patterns/SKILL.md) | Boundaries from bounded contexts, gateway/BFF, resilience, data per service, backing services as attached resources, stateless processes |
| **event-driven** | [`architecture/event-driven/SKILL.md`](architecture/event-driven/SKILL.md) | Pub/sub, brokers, transactional outbox, idempotent consumers, ordering, DLQs |
| **cqrs-event-sourcing** | [`architecture/cqrs-event-sourcing/SKILL.md`](architecture/cqrs-event-sourcing/SKILL.md) | Command/query split, event store, projections, snapshots, replay, event versioning |
| **saga-orchestration** | [`architecture/saga-orchestration/SKILL.md`](architecture/saga-orchestration/SKILL.md) | Orchestration vs choreography, compensating transactions, state machines |

References: [`resilience-patterns.md`](architecture/microservices-patterns/references/resilience-patterns.md), [`delivery-semantics.md`](architecture/event-driven/references/delivery-semantics.md), [`saga-state-machines.md`](architecture/saga-orchestration/references/saga-state-machines.md).

### tooling

| Skill | Path | Description |
|-------|------|-------------|
| **tooling-skills** (entry) | [`tooling/SKILL.md`](tooling/SKILL.md) | Symptom router across images, runtime failures, and signals |
| **containerization** | [`tooling/containerization/SKILL.md`](tooling/containerization/SKILL.md) | Multi-stage Dockerfiles, distroless, layer caching, non-root, Compose, healthchecks, and the twelve-factor runtime contract |
| **be-diagnostics** | [`tooling/be-diagnostics/SKILL.md`](tooling/be-diagnostics/SKILL.md) | Symptom → logs/traces/metrics/profiler/EXPLAIN routing for 5xx, latency, leaks, deadlocks |
| **observability** | [`tooling/observability/SKILL.md`](tooling/observability/SKILL.md) | Structured logging, OpenTelemetry traces, RED/USE metrics, correlation across the three signals |

References: [`dockerfile-patterns.md`](tooling/containerization/references/dockerfile-patterns.md), [`compose-local-deps.md`](tooling/containerization/references/compose-local-deps.md), [`runtime-contract.md`](tooling/containerization/references/runtime-contract.md), [`profilers.md`](tooling/be-diagnostics/references/profilers.md), [`db-diagnosis.md`](tooling/be-diagnostics/references/db-diagnosis.md), [`logging-tracing.md`](tooling/observability/references/logging-tracing.md), [`metrics-red-use.md`](tooling/observability/references/metrics-red-use.md).

### quality

| Skill | Path | Description |
|-------|------|-------------|
| **quality-skills** (entry) | [`quality/SKILL.md`](quality/SKILL.md) | Quality navigation: security, performance, testing |
| **api-security** | [`quality/api-security/SKILL.md`](quality/api-security/SKILL.md) | OWASP API Security Top 10 (2023) controls per route |
| **be-performance** | [`quality/be-performance/SKILL.md`](quality/be-performance/SKILL.md) | Latency/throughput budgets, DB and caching cost, k6 load testing |
| **be-testing** | [`quality/be-testing/SKILL.md`](quality/be-testing/SKILL.md) | Back-end test pyramid, Testcontainers integration, contract tests, coverage gates |

References: [`authn-tokens.md`](quality/api-security/references/authn-tokens.md), [`authz-bola-bfla.md`](quality/api-security/references/authz-bola-bfla.md), [`injection-ssrf-ratelimit.md`](quality/api-security/references/injection-ssrf-ratelimit.md), [`db-and-caching.md`](quality/be-performance/references/db-and-caching.md), [`load-testing-k6.md`](quality/be-performance/references/load-testing-k6.md), [`contract-testing.md`](quality/be-testing/references/contract-testing.md), [`integration-testcontainers.md`](quality/be-testing/references/integration-testcontainers.md).

## Child Indexes

| Index Path | Contents |
|------------|----------|
| [`_shared/_index.md`](_shared/_index.md) | secure-coding plus the five shared reference tables |
| [`node/_index.md`](node/_index.md) | node entry + modern-typescript-backend, nest-express-fastify-patterns, node-async-streams |
| [`go/_index.md`](go/_index.md) | go entry + modern-go, go-concurrency |
| [`jvm/_index.md`](jvm/_index.md) | jvm entry + spring-boot, kotlin-backend |
| [`python-web/_index.md`](python-web/_index.md) | python-web entry + fastapi, django, flask |
| [`api/_index.md`](api/_index.md) | api entry + rest-design, graphql-design, grpc-design, openapi-contracts, api-versioning |
| [`data/_index.md`](data/_index.md) | data entry + schema-design, migrations, query-optimization, orm-patterns, caching-strategies |
| [`architecture/_index.md`](architecture/_index.md) | architecture entry + microservices-patterns, event-driven, cqrs-event-sourcing, saga-orchestration |
| [`tooling/_index.md`](tooling/_index.md) | tooling entry + containerization, be-diagnostics, observability |
| [`quality/_index.md`](quality/_index.md) | quality entry + api-security, be-performance, be-testing |
| [`tooling/containerization/references/_index.md`](tooling/containerization/references/_index.md) | Dockerfile patterns, Compose local deps, runtime contract |
| [`tooling/be-diagnostics/references/_index.md`](tooling/be-diagnostics/references/_index.md) | Profilers, DB diagnosis |
| [`tooling/observability/references/_index.md`](tooling/observability/references/_index.md) | Logging/tracing, RED/USE metrics |
