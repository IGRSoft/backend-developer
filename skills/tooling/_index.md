# Tooling Index

Quick navigation for containerization, runtime diagnostics, and observability.

## Skills

| Path | Description |
|------|-------------|
| `SKILL.md` | Entry router: skill selection, symptom router, tool version snapshot, decision tree |
| `containerization/SKILL.md` | Multi-stage Dockerfiles, distroless/small images, layer caching, non-root users, Compose for local deps, healthchecks, build args/secrets, and the twelve-factor runtime contract |
| `containerization/references/dockerfile-patterns.md` | Per-runtime multi-stage Dockerfiles (Node/Go/JVM/Python/.NET), distroless targets, BuildKit cache + secret mounts, image hardening |
| `containerization/references/compose-local-deps.md` | Docker Compose for Postgres/MySQL/Mongo/Redis/Kafka/RabbitMQ, healthcheck gating, seeding, parity with Testcontainers |
| `containerization/references/runtime-contract.md` | Config from env vars validated at boot, build/release/run promotion, `$PORT` binding, per-stack `SIGTERM` shutdown (Spring Boot/uvicorn/Puma/ASP.NET/PHP-FPM), fast startup |
| `be-diagnostics/SKILL.md` | Symptom → tool routing across logs, traces, metrics, profilers, and EXPLAIN |
| `be-diagnostics/references/profilers.md` | CPU/heap profilers per runtime: pprof, py-spy/tracemalloc, JFR/async-profiler, clinic/--prof, dotnet-trace; continuous profiling (Pyroscope/Parca/eBPF) |
| `be-diagnostics/references/db-diagnosis.md` | EXPLAIN ANALYZE, N+1 detection, connection-pool exhaustion, slow-query logs, lock waits |
| `observability/SKILL.md` | Structured logging, OpenTelemetry traces, RED/USE metrics, log/trace/metric correlation |
| `observability/references/logging-tracing.md` | Structured loggers per runtime, correlation/trace IDs, OTel spans, context propagation across HTTP/gRPC/queues |
| `observability/references/metrics-red-use.md` | RED/USE method, stable semconv naming, histograms (explicit + native) + exemplars, Prometheus/OTLP export (incl. Prometheus 3.x native OTLP) |

## Quick Links by Problem

### "I need to..."

- **Shrink a Docker image** → `containerization/references/dockerfile-patterns.md`
- **Run Postgres + Redis locally** → `containerization/references/compose-local-deps.md`
- **Add a healthcheck** → `containerization/SKILL.md`
- **Decide where config and secrets come from** → `containerization/references/runtime-contract.md`
- **Promote one artifact across environments** → `containerization/references/runtime-contract.md`
- **Drain in-flight requests on `SIGTERM`** → `containerization/references/runtime-contract.md`
- **Profile a slow endpoint** → `be-diagnostics/references/profilers.md`
- **Diagnose a slow query** → `be-diagnostics/references/db-diagnosis.md`
- **Add correlation IDs across services** → `observability/references/logging-tracing.md`
- **Build a RED/USE dashboard** → `observability/references/metrics-red-use.md`

### "I'm getting..."

- **A `500` / unhandled exception** → `be-diagnostics/SKILL.md` (Logs)
- **A p99 latency spike** → `be-diagnostics/SKILL.md` (Traces & Profiling)
- **`pool timeout` / connection-pool exhaustion** → `be-diagnostics/references/db-diagnosis.md`
- **OOMKilled / growing heap** → `be-diagnostics/references/profilers.md`
- **A huge image / leaked secret in a layer** → `containerization/references/dockerfile-patterns.md`
- **A container restart loop** → `containerization/SKILL.md` (Healthchecks)
- **Dropped requests or lost jobs on every deploy** → `containerization/references/runtime-contract.md` (Graceful Shutdown)
- **Random logouts / files missing from other replicas** → `containerization/references/runtime-contract.md` (state must not live in the process)
- **A service unreachable in-cluster though it is running** → `containerization/references/runtime-contract.md` (Port Binding)
