---
name: tooling-skills
description: >-
  Back-end tooling skills navigation — containerization, diagnostics, and
  observability. Use when containerizing a service, debugging a runtime
  symptom, or instrumenting logs/traces/metrics.
---

# Tooling Skills

**Containerization, runtime diagnostics, and observability for web/service back-ends**

Thin router. Pick a sub-skill from the tables below; the leaf skills teach.

## Skill Selection

| I need to... | Use this skill |
|--------------|----------------|
| Build a small, secure image; wire up Compose for local deps | [containerization/SKILL.md](containerization/SKILL.md) |
| Decide where config/secrets come from, or stop hardcoding a port | [containerization/SKILL.md](containerization/SKILL.md) > Config, Release, and Port |
| Make a deploy stop dropping in-flight requests | [containerization/SKILL.md](containerization/SKILL.md) > Graceful Shutdown |
| Find/fix a 5xx, latency spike, leak, deadlock, or slow query | [be-diagnostics/SKILL.md](be-diagnostics/SKILL.md) |
| Profile a slow endpoint or set a performance baseline | [be-diagnostics/SKILL.md](be-diagnostics/SKILL.md) > Profiling |
| Add structured logs, traces, or RED/USE metrics | [observability/SKILL.md](observability/SKILL.md) |

## Symptom Router

Start here when you have a behavior, not a tool name.

| Symptom | Likely cause | Go to |
|---------|--------------|-------|
| `500` / unhandled exception / stack trace in logs | thrown error, missing handler, bad input | [be-diagnostics](be-diagnostics/SKILL.md) > Logs |
| p99 latency spike, slow endpoint | N+1 query, lock contention, cold cache | [be-diagnostics](be-diagnostics/SKILL.md) > Traces & Profiling |
| RSS/heap grows without bound, eventual OOMKill | leak, unbounded cache, retained closures | [be-diagnostics](be-diagnostics/SKILL.md) > Memory |
| Requests hang, event loop blocked, `pool timeout` | deadlock, connection-pool exhaustion | [be-diagnostics](be-diagnostics/SKILL.md) > Concurrency & Pools |
| Query is slow / full table scan | missing index, bad plan | [be-diagnostics](be-diagnostics/SKILL.md) > EXPLAIN |
| Image is huge / build is slow / leaks secrets | no multi-stage, bad layer order, COPY of `.env` | [containerization](containerization/SKILL.md) |
| Container is unhealthy / restarts in a loop | missing/incorrect healthcheck, wrong port/PID 1 | [containerization](containerization/SKILL.md) > Healthchecks |
| Deploys drop requests; workers lose in-flight jobs | no `SIGTERM` drain, or a deadline above the grace period | [containerization](containerization/SKILL.md) > Graceful Shutdown |
| Users log out at random; a file uploaded to one replica 404s | state in process memory or on local disk | [containerization](containerization/references/runtime-contract.md) |
| "Works in staging, fails in prod" on identical code | rebuilt per environment, or config grouped by environment name | [containerization](containerization/references/runtime-contract.md) |
| Service is unreachable inside the cluster despite being up | bound to `127.0.0.1`, or the port is hardcoded | [containerization](containerization/references/runtime-contract.md) > Port Binding |
| "I can't tell which service caused the error" | no correlation/trace ID across hops | [observability](observability/SKILL.md) > Correlation |
| Dashboards exist but don't explain the outage | wrong signals (no RED/USE), no exemplars | [observability](observability/SKILL.md) > RED/USE |

## Tool Version Snapshot (verify against your stack)

Floors this plugin assumes. Runtime and library support shift between minor releases — confirm with `--version` and the [version-feature-matrix](../_shared/version-feature-matrix.md) before pinning in CI.

| Tool | Assumed floor | Why |
|------|---------------|-----|
| Docker Engine / BuildKit | current stable (BuildKit is the default builder) | `--mount=type=cache`, `--mount=type=secret`, multi-stage |
| Docker Compose | v2 only (`docker compose`) | Compose Spec, `depends_on: condition: service_healthy`; the Python v1 `docker-compose` is EOL/removed — see [version-feature-matrix](../_shared/version-feature-matrix.md) |
| OpenTelemetry SDK | current stable per language | traces, metrics, **and logs** APIs/SDKs are now stable in the spec (logs Bridge API + SDK + OTLP graduated) — confirm per-language status |
| OTel Collector | current stable | OTLP receive/export, batch, tail sampling; component stability is still mixed (per-component, not one v1) — pin tested components |
| Node.js | 20 LTS / 22 LTS | `--prof`, `node:diagnostics_channel`, heap snapshots |
| Go | 1.22+ | `pprof`, `runtime/trace`, `GODEBUG` knobs *(verify)* |
| JVM (Java/Kotlin) | 17 / 21 LTS | JFR, async-profiler, `jcmd`, `-XX:+HeapDumpOnOutOfMemoryError` |
| Python | 3.11+ | `py-spy`, `tracemalloc`, faster CPython traces |
| PostgreSQL | 14+ | `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_statements` |
| k6 / wrk | current stable | reproducible load reports as cli-fallback evidence |

## Decision Tree

```
Tooling task?
├── "How do I package / ship / run this service?" → containerization/SKILL.md
│   ├── Multi-stage + distroless image → containerization/references/dockerfile-patterns.md
│   ├── Compose for Postgres/Redis/Kafka locally → containerization/references/compose-local-deps.md
│   ├── Build args, BuildKit secrets, caching → containerization/references/dockerfile-patterns.md
│   └── Config from env, release promotion, $PORT, SIGTERM → containerization/references/runtime-contract.md
├── "It 5xxes / is slow / leaks / deadlocks / slow query" → be-diagnostics/SKILL.md
│   ├── Profilers per runtime (pprof/py-spy/JFR/clinic) → be-diagnostics/references/profilers.md
│   ├── DB query diagnosis (EXPLAIN, pool, N+1) → be-diagnostics/references/db-diagnosis.md
│   └── Memory & heap dumps → be-diagnostics/references/profilers.md
└── "I can't see what's happening in prod" → observability/SKILL.md
    ├── Structured logging + correlation IDs → observability/references/logging-tracing.md
    ├── OpenTelemetry traces & context propagation → observability/references/logging-tracing.md
    └── Metrics: RED/USE, exemplars → observability/references/metrics-red-use.md
```

## Conventions Across Containerization & Diagnostics

- **Multi-stage builds always.** A build stage compiles/installs dev deps; the final stage carries only the runtime artifact and runs as a non-root user.
- **Profile/diagnose against a release-shaped build**, not a dev server with hot-reload — the hot path differs. Reproduce load with k6/wrk, not a single curl.
- **Single-command Bash invocations.** Use `docker build .`, `docker compose up -d`, `go test ./...`, `npm test` — never `cd`-chains. Scoped Bash allowlists do not match compound commands.
- **Evidence is API/test/load output**, not screenshots — non-UI work defaults to `requires_screenshots: false`. When a gate is armed, attach curl/httpie request-response transcripts, test output, k6 reports, and migration logs.

## Related Skills

- [containerization](containerization/SKILL.md) — multi-stage Dockerfiles, distroless, layer caching, non-root, Compose, healthchecks, BuildKit secrets, and the twelve-factor runtime contract (config, release promotion, port binding, graceful shutdown)
- [be-diagnostics](be-diagnostics/SKILL.md) — symptom → logs/traces/metrics/profiler/EXPLAIN routing
- [observability](observability/SKILL.md) — structured logging, OpenTelemetry traces, RED/USE metrics, exemplars
- [version-feature-matrix](../_shared/version-feature-matrix.md) — runtime/framework floors per feature
- [secure-coding](../_shared/secure-coding/SKILL.md) — hardening belongs in the image and the handler, not as an afterthought
- [api-security](../quality/api-security/SKILL.md) — OWASP API Security Top 10 the diagnostics and image hardening defend
- [be-testing](../quality/be-testing/SKILL.md) — integration tests (Testcontainers) reuse the same images and Compose stacks
- [CORPFLOW.md](../../CORPFLOW.md) — Build Evidence and the cli-fallback evidence norm
