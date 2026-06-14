# Tooling Index

Quick navigation for containerization, runtime diagnostics, and observability.

## Skills

| Path | Description |
|------|-------------|
| `SKILL.md` | Entry router: skill selection, symptom router, tool version snapshot, decision tree |
| `containerization/SKILL.md` | Multi-stage Dockerfiles, distroless/small images, layer caching, non-root users, Compose for local deps, healthchecks, build args/secrets |
| `containerization/references/dockerfile-patterns.md` | Per-runtime multi-stage Dockerfiles (Node/Go/JVM/Python/.NET), distroless targets, BuildKit cache + secret mounts, image hardening |
| `containerization/references/compose-local-deps.md` | Docker Compose for Postgres/MySQL/Mongo/Redis/Kafka/RabbitMQ, healthcheck gating, seeding, parity with Testcontainers |
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
