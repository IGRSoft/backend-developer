# Skills Index

Root index for all backend-developer skills (Node/TS, Go, JVM/Spring, Python web,
plus API, data, architecture, tooling, quality, and shared cross-cutting
patterns). **21 SKILL.md across 10 domains, plus shared references.** Start at
[`SKILL.md`](SKILL.md) for the routing entry point.

## Domains

| Directory | Index | Skills | Description |
|-----------|-------|--------|-------------|
| [_shared/](_shared/_index.md) | [`_index.md`](_shared/_index.md) | 2 + refs | Cross-cutting patterns: workflow integration, secure coding (OWASP API), versions, routing, severity, testing principles |
| [node/](node/SKILL.md) | [`_index.md`](node/_index.md) | 1 + 2 leaves | Express/NestJS/Fastify/Hono service patterns, TypeScript-strict async, vitest/jest testing |
| [go/](go/SKILL.md) | [`_index.md`](go/_index.md) | 1 + 2 leaves | net/http and Gin/Echo/chi patterns, contexts, goroutines, table-driven testing, govulncheck |
| [jvm/](jvm/SKILL.md) | [`_index.md`](jvm/_index.md) | 1 + 2 leaves | Spring Boot, JPA/Hibernate, reactive WebFlux, JUnit 5 + Testcontainers |
| [python-web/](python-web/SKILL.md) | [`_index.md`](python-web/_index.md) | 1 + 2 leaves | FastAPI/Django/Flask patterns, pydantic, SQLAlchemy, pytest testing |
| [api/](api/SKILL.md) | [`_index.md`](api/_index.md) | 1 + 2 leaves | REST/GraphQL/gRPC/WebSocket contract design, versioning, pagination |
| [data/](data/SKILL.md) | [`_index.md`](data/_index.md) | 1 + 2 leaves | Schema design, safe migrations, query performance, Postgres/MySQL/Mongo/Redis |
| [architecture/](architecture/SKILL.md) | [`_index.md`](architecture/_index.md) | 1 + 2 leaves | Layered/hexagonal, event-driven/CQRS, idempotency, messaging, caching |
| [tooling/](tooling/SKILL.md) | [`_index.md`](tooling/_index.md) | 1 + 2 leaves | Containerization with Docker/Compose, observability with OpenTelemetry |
| [quality/](quality/SKILL.md) | [`_index.md`](quality/_index.md) | 1 + 2 leaves | Test pyramid, integration and load testing, code-review gates |

## All Skills

### _shared

| Skill | Path | Description |
|-------|------|-------------|
| **secure-coding** | [`_shared/secure-coding/SKILL.md`](_shared/secure-coding/SKILL.md) | Non-negotiable security rules mapped to the OWASP API Security Top 10 (2023) — BOLA/auth/property-level/rate-limiting/SSRF, injection (SQL/NoSQL/command), secrets hygiene, supply-chain CVEs |
| **workflow-integration** | [`_shared/workflow-integration/SKILL.md`](_shared/workflow-integration/SKILL.md) | Guide for integrating with the igrsoft 11-stage workflow system (v3.17.0) |
| version-feature-matrix | [`_shared/version-feature-matrix.md`](_shared/version-feature-matrix.md) | Runtimes/frameworks → minimum versions and headline features (canonical lookup) |
| language-detection | [`_shared/language-detection.md`](_shared/language-detection.md) | Marker → runtime → agent routing table, detection priority, tie-breaking |
| model-selection | [`_shared/model-selection.md`](_shared/model-selection.md) | Per-agent model/effort/maxTurns assignments and opus+xhigh override paths |
| severity-matrix | [`_shared/severity-matrix.md`](_shared/severity-matrix.md) | Severity levels, P0-P3 review priorities, effort/impact quadrant, coverage requirements |
| testing-principles | [`_shared/testing-principles.md`](_shared/testing-principles.md) | Test pyramid, per-runtime framework matrix, quality gates, anti-patterns |

### node

| Skill | Path | Description |
|-------|------|-------------|
| **node** (entry) | [`node/SKILL.md`](node/SKILL.md) | Node.js/TypeScript skills navigation: framework selection, async patterns, testing |
| **node-service-patterns** | [`node/node-service-patterns/SKILL.md`](node/node-service-patterns/SKILL.md) | Express/NestJS/Fastify/Hono selection, middleware, error handling, config, graceful shutdown, async/await correctness |
| **node-testing** | [`node/node-testing/SKILL.md`](node/node-testing/SKILL.md) | vitest/jest, supertest for HTTP, Testcontainers, mocking, coverage |

### go

| Skill | Path | Description |
|-------|------|-------------|
| **go** (entry) | [`go/SKILL.md`](go/SKILL.md) | Go skills navigation: idiomatic HTTP services, contexts, concurrency, testing |
| **go-service-patterns** | [`go/go-service-patterns/SKILL.md`](go/go-service-patterns/SKILL.md) | Idiomatic handlers, context and cancellation, error wrapping, graceful shutdown, structured config |
| **go-testing** | [`go/go-testing/SKILL.md`](go/go-testing/SKILL.md) | Table-driven tests, httptest, golangci-lint, govulncheck, race detector |

### jvm

| Skill | Path | Description |
|-------|------|-------------|
| **jvm** (entry) | [`jvm/SKILL.md`](jvm/SKILL.md) | JVM/Spring Boot skills navigation: controllers, persistence, reactive, testing |
| **spring-boot-patterns** | [`jvm/spring-boot-patterns/SKILL.md`](jvm/spring-boot-patterns/SKILL.md) | Controllers/services/repositories, JPA mapping, `@Transactional` boundaries, validation, reactive WebFlux |
| **jvm-testing** | [`jvm/jvm-testing/SKILL.md`](jvm/jvm-testing/SKILL.md) | JUnit 5, `@SpringBootTest` slices, MockMvc/WebTestClient, Testcontainers |

### python-web

| Skill | Path | Description |
|-------|------|-------------|
| **python-web** (entry) | [`python-web/SKILL.md`](python-web/SKILL.md) | Python web skills navigation for FastAPI/Django/Flask: routing, validation, ORM, testing |
| **python-web-patterns** | [`python-web/python-web-patterns/SKILL.md`](python-web/python-web-patterns/SKILL.md) | Routing and dependency injection, pydantic models, async vs sync, SQLAlchemy sessions, settings |
| **python-web-testing** | [`python-web/python-web-testing/SKILL.md`](python-web/python-web-testing/SKILL.md) | pytest, httpx/TestClient, fixtures, Testcontainers, coverage |

### api

| Skill | Path | Description |
|-------|------|-------------|
| **api** (entry) | [`api/SKILL.md`](api/SKILL.md) | API skills navigation and the canonical protocol-selection table for REST/GraphQL/gRPC/WebSockets |
| **rest-design** | [`api/rest-design/SKILL.md`](api/rest-design/SKILL.md) | Resource modeling, status codes, OpenAPI contracts, versioning, pagination, idempotency keys |
| **graphql-grpc** | [`api/graphql-grpc/SKILL.md`](api/graphql-grpc/SKILL.md) | GraphQL schemas and N+1 batching, gRPC/protobuf, WebSockets, protocol trade-offs |

### data

| Skill | Path | Description |
|-------|------|-------------|
| **data** (entry) | [`data/SKILL.md`](data/SKILL.md) | Data skills navigation: schema design, migrations, query performance, store selection |
| **schema-design** | [`data/schema-design/SKILL.md`](data/schema-design/SKILL.md) | Normalization, indexing strategy, constraints, choosing relational vs document vs cache stores |
| **migrations-queries** | [`data/migrations-queries/SKILL.md`](data/migrations-queries/SKILL.md) | Expand/contract migrations, N+1 elimination, query plans, transactions, ORM escape hatches |

### architecture

| Skill | Path | Description |
|-------|------|-------------|
| **architecture** (entry) | [`architecture/SKILL.md`](architecture/SKILL.md) | Architecture skills navigation: service layout, transaction boundaries, event-driven, messaging, caching |
| **service-architecture** | [`architecture/service-architecture/SKILL.md`](architecture/service-architecture/SKILL.md) | Layered vs hexagonal, dependency boundaries, idempotency, transaction scope, monolith vs services |
| **event-driven** | [`architecture/event-driven/SKILL.md`](architecture/event-driven/SKILL.md) | CQRS, event sourcing, Kafka/RabbitMQ/SQS patterns, outbox, sagas, cache invalidation |

### tooling

| Skill | Path | Description |
|-------|------|-------------|
| **tooling** (entry) | [`tooling/SKILL.md`](tooling/SKILL.md) | Build, container, and observability tooling navigation; routes "won't start", "image too big", "no traces" symptoms |
| **containerization** | [`tooling/containerization/SKILL.md`](tooling/containerization/SKILL.md) | Multi-stage Dockerfiles, Compose for local stacks, image size/security hygiene, healthchecks |
| **observability** | [`tooling/observability/SKILL.md`](tooling/observability/SKILL.md) | Structured JSON logging, OpenTelemetry traces and metrics, correlation IDs, RED/USE signals |

### quality

| Skill | Path | Description |
|-------|------|-------------|
| **quality** (entry) | [`quality/SKILL.md`](quality/SKILL.md) | Quality skills navigation: testing strategy, load testing, review gates |
| **testing-strategy** | [`quality/testing-strategy/SKILL.md`](quality/testing-strategy/SKILL.md) | Test pyramid for services, integration with Testcontainers, contract tests, k6 load tests |
| **review-gates** | [`quality/review-gates/SKILL.md`](quality/review-gates/SKILL.md) | DR criteria, P0-P3 severity, coverage and load/perf budgets, security-scan gate |

## Child Indexes

| Index Path | Contents |
|------------|----------|
| [`_shared/_index.md`](_shared/_index.md) | Shared skills: workflow, secure coding, versions, routing, severity, testing |
| [`node/_index.md`](node/_index.md) | Node entry + node-service-patterns + node-testing |
| [`go/_index.md`](go/_index.md) | Go entry + go-service-patterns + go-testing |
| [`jvm/_index.md`](jvm/_index.md) | JVM entry + spring-boot-patterns + jvm-testing |
| [`python-web/_index.md`](python-web/_index.md) | Python web entry + python-web-patterns + python-web-testing |
| [`api/_index.md`](api/_index.md) | API entry + rest-design + graphql-grpc |
| [`data/_index.md`](data/_index.md) | Data entry + schema-design + migrations-queries |
| [`architecture/_index.md`](architecture/_index.md) | Architecture entry + service-architecture + event-driven |
| [`tooling/_index.md`](tooling/_index.md) | Tooling entry + containerization + observability |
| [`quality/_index.md`](quality/_index.md) | Quality entry + testing-strategy + review-gates |
