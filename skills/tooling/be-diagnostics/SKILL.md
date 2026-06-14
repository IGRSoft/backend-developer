---
name: be-diagnostics
description: >-
  Route a back-end runtime symptom (5xx, latency spike, memory growth,
  deadlock, connection-pool exhaustion, slow query) to logs, traces,
  metrics, a profiler, or EXPLAIN. Use when a service errors, slows down,
  leaks, hangs, or a query is slow and you need to pick a tool and the
  exact steps to run it.
---

# Back-end Diagnostics

**Pick a tool from the symptom, then run it with the steps below.**

## When to Use

Use this skill when you have a *behavior*, not a tool name:

- It returns `5xx` / throws unhandled exceptions in the logs.
- p99 latency spikes, an endpoint is slow, or throughput drops.
- RSS/heap grows without bound until the container is OOMKilled.
- Requests hang, the event loop is blocked, or you see `pool timeout`.
- A query is slow, scans the whole table, or locks block each other.

Skip if the problem is at build/image time — that is [containerization](../containerization/SKILL.md). For instrumenting the signals you'll read here, see [observability](../observability/SKILL.md).

## Symptom -> Tool Routing

| Symptom | First tool | Notes |
|---------|-----------|-------|
| `500` / unhandled exception / stack trace | **structured logs** filtered by correlation ID | Find the failing request, then the throwing frame. Wire IDs first via [observability](../observability/SKILL.md). |
| p99 latency spike on one endpoint | **distributed trace** for that route | Span waterfall shows which hop (DB, downstream API, lock) dominates. |
| Slow under load, single request fine | **profiler** (pprof/py-spy/JFR/clinic) | Profile under reproduced load (k6/wrk), not one curl. See [profilers.md](references/profilers.md). |
| RSS/heap grows without bound | **heap snapshot / dump** + allocation profiler | Compare two snapshots; the retained set is your leak. See [profilers.md](references/profilers.md). |
| Event loop blocked / goroutine pileup / thread starvation | **runtime profiler** (`--prof`, `pprof goroutine`, JFR thread dump) | Blocking I/O or CPU on the hot path; offload or batch. |
| Requests hang, `pool timeout`, `too many connections` | **pool metrics + DB sessions view** | Pool too small, leaked connections, or long-running txns. See [db-diagnosis.md](references/db-diagnosis.md). |
| Query slow / full table scan | **`EXPLAIN (ANALYZE, BUFFERS)`** | Read the plan, add the index, re-EXPLAIN. See [db-diagnosis.md](references/db-diagnosis.md). |
| N+1 queries (one request fires hundreds) | **query log / ORM statement count** | Eager-load or batch. See [db-diagnosis.md](references/db-diagnosis.md). |
| Wall-clock A/B of an endpoint | **k6 / wrk** | Reproducible load report as cli-fallback evidence. |

## Ground Rules

- **Reproduce before you measure.** A representative load (k6/wrk script, fixed request set) makes the hot path real; a single curl hides queueing and contention.
- **Profile a release-shaped build**, not a dev server with hot-reload/source-maps — the hot path differs. Disable the debugger inspector when profiling Node.
- **One variable at a time.** Change one thing, re-measure against a recorded baseline (commit the k6 JSON), keep the win or revert.
- **Correlate, don't guess.** A trace ID ties a log line to a span to a metric exemplar; without it you are searching three haystacks separately ([observability](../observability/SKILL.md)).
- **Overhead budget** *(order-of-magnitude; verify against your stack)*: sampling profilers (py-spy, pprof CPU, async-profiler) ~2-5%; tracing/allocation profilers heavier; full heap dumps pause the process — take them off the hot instance.

## Copy-Paste Diagnosis Steps

```bash
# 1) Reproduce load against a release-shaped instance
k6 run --vus 50 --duration 60s load.js          # writes a summary report (cli-fallback evidence)
wrk -t4 -c100 -d30s http://localhost:8080/api/orders

# 2) CPU profile per runtime (under that load)
go tool pprof -http=:0 http://localhost:6060/debug/pprof/profile?seconds=30   # Go
py-spy record -o profile.svg --pid $(pgrep -f gunicorn) -- --duration 30      # Python
node --cpu-prof --cpu-prof-dir=./prof server.js                                # Node
# JVM: attach async-profiler -> jfr/flamegraph (see references/profilers.md)

# 3) Slow query (PostgreSQL)
psql -c "EXPLAIN (ANALYZE, BUFFERS) SELECT ... ;"
```

### Find the failing request from logs

```bash
# Structured JSON logs: pull every line for one correlation ID, newest first
grep '"correlation_id":"3f9c..."' app.log | jq -c '{ts,level,msg,err}'
# Then the error frame and the route that threw it.
```

## Per-Runtime Profiler Quickstart

| Runtime | CPU | Heap / allocations | Threads / concurrency |
|---------|-----|--------------------|-----------------------|
| Node.js | `--cpu-prof` / `clinic flame` / inspector | `--heap-prof`, heap snapshot via inspector | `clinic bubbleprof`, `--prof` event-loop |
| Go | `pprof profile` | `pprof heap` (in-use vs alloc) | `pprof goroutine`, `runtime/trace` |
| JVM | async-profiler `-e cpu` / JFR | JFR `ObjectAllocation`, heap dump `jmap` | JFR thread dump, `jstack` |
| Python | py-spy `record` | `tracemalloc`, `memray` | py-spy `dump` (stacks), GIL contention |
| .NET | `dotnet-trace` / `dotnet-counters` | `dotnet-gcdump` | `dotnet-stack` |

Full flags, flamegraphs, and snapshot diffing: [profilers.md](references/profilers.md).

## Connection Pool & Slow Query Quickstart

```sql
-- PostgreSQL: who is holding connections / blocking whom?
SELECT pid, state, wait_event_type, query_start, left(query,60)
FROM pg_stat_activity WHERE state <> 'idle' ORDER BY query_start;

-- Lock waits (blocking tree)
SELECT blocked.pid AS blocked_pid, blocking.pid AS blocking_pid
FROM pg_locks blocked JOIN pg_locks blocking
  ON blocked.locktype = blocking.locktype AND NOT blocked.granted AND blocking.granted;

-- Top time-consuming statements (requires pg_stat_statements)
SELECT mean_exec_time, calls, left(query,80) FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;
```

`pool timeout` almost always means: pool too small for concurrency, connections leaked (not released on error path), or a long-running transaction holding a slot. Full workflow — sizing, N+1 detection, EXPLAIN reading, lock chains: [db-diagnosis.md](references/db-diagnosis.md).

## Memory Growth Quickstart

```bash
# Node: take two heap snapshots under steady load, diff the retained set
node --inspect server.js   # then Chrome DevTools > Memory > Heap snapshot x2, "Comparison"
# Go: in-use heap, sorted by retained bytes
go tool pprof -inuse_space http://localhost:6060/debug/pprof/heap
# Python: top allocators
python -X tracemalloc=25 -c 'import app; app.run()'   # then tracemalloc.take_snapshot()
# JVM: dump on OOM, open in Eclipse MAT / VisualVM
java -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/heap.hprof -jar app.jar
```

A leak shows as a retained set that grows between two snapshots taken at the same load. Common culprits: unbounded in-memory caches, request-scoped data attached to a long-lived object, event listeners never removed, connections/streams not closed.

## Symptom Headline -> Diagnosis

| Observed | Signal | Likely cause | Fix direction | Reference |
|----------|--------|--------------|---------------|-----------|
| Burst of `500`s after deploy | logs | unhandled rejection / bad migration | guard the handler; verify migration ran | [db-diagnosis.md](references/db-diagnosis.md) |
| One endpoint's p99 climbs, others fine | trace | N+1 or downstream timeout on that route | eager-load / add timeout+retry budget | [db-diagnosis.md](references/db-diagnosis.md) |
| All endpoints slow, CPU pinned | CPU profile | hot serialization/regex/JSON loop | optimize the top frame, cache | [profilers.md](references/profilers.md) |
| RSS climbs each hour, OOMKilled | heap diff | unbounded cache / retained closure | bound the cache (LRU+TTL); release refs | [profilers.md](references/profilers.md) |
| `pool timeout` under load | pool metrics | pool too small / leaked conns / long txn | size pool; release on error; shorten txn | [db-diagnosis.md](references/db-diagnosis.md) |
| Query 50ms→5s as table grew | `EXPLAIN ANALYZE` | seq scan, missing index | add index on filter/join column | [db-diagnosis.md](references/db-diagnosis.md) |
| Requests hang, no CPU | thread/goroutine dump | deadlock / blocking I/O on event loop | offload blocking work; fix lock order | [profilers.md](references/profilers.md) |

## Version & Fallbacks

Profiler and DB tooling availability shifts across runtime/engine versions — confirm with `--version` and the version-feature-matrix (skill: version-feature-matrix). Notable floors: Go `net/http/pprof` stdlib (any modern Go); JFR open-source since JDK 11 (async-profiler 4.x can also consume the JDK 25 `CPUTimeSample` event); `pg_stat_statements` is an extension you must enable; py-spy needs `ptrace` (or `--cap-add SYS_PTRACE` in containers). When you can't attach a profiler to the live prod instance, fall back to RED metrics + trace sampling ([observability](../observability/SKILL.md)) — or run **continuous profiling** (Pyroscope/Parca, eBPF) so the flamegraph for the bad window is already recorded; see [profilers.md](references/profilers.md).

## Related Skills

- [profilers.md](references/profilers.md) — per-runtime CPU/heap/thread profilers, flamegraphs, snapshot diffing, the measure→fix→re-measure loop
- [db-diagnosis.md](references/db-diagnosis.md) — EXPLAIN ANALYZE, N+1, pool sizing/exhaustion, slow-query logs, lock chains
- [observability](../observability/SKILL.md) — the logs, traces, and metrics this skill reads; wire correlation IDs first
- [containerization](../containerization/SKILL.md) — `--cap-add SYS_PTRACE`, debug images, and exposing pprof/JFR ports safely
- [be-performance](../../quality/be-performance/SKILL.md) — turning a profile into an optimization plan
- [be-testing](../../quality/be-testing/SKILL.md) — Testcontainers integration tests that reproduce the slow path
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — runtime/engine floors for these tools
