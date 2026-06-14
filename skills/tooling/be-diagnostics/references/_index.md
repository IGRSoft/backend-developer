# Back-end Diagnostics References Index

Deep-dive references for the [be-diagnostics](../SKILL.md) skill. Start at the
SKILL.md symptom router; come here for full flag tables, per-runtime commands,
and worked walkthroughs.

## References

| File | Covers | Read when |
|------|--------|-----------|
| `profilers.md` | Per-runtime CPU/heap/thread profilers (pprof, py-spy/memray/tracemalloc, JFR/async-profiler, clinic/`--cpu-prof`, dotnet-trace/gcdump), continuous profiling (Pyroscope/Parca/eBPF, OTel profiles signal), flamegraphs, heap-snapshot diffing, the measure→fix→re-measure loop, k6/wrk load generation | A service is slow or leaking and you need to find *where* |
| `db-diagnosis.md` | `EXPLAIN (ANALYZE, BUFFERS)` reading, index decisions, N+1 detection per ORM, connection-pool sizing and exhaustion, slow-query logs (`pg_stat_statements`/`log_min_duration_statement`), lock chains and deadlocks | A query is slow, the pool times out, or the DB is the bottleneck |

## Quick Links by Problem

- **Find the CPU hot path in Node/Go/JVM/Python/.NET** → `profilers.md` (per-runtime)
- **Find what retains memory** → `profilers.md` (heap snapshot diff)
- **Diagnose a blocked event loop / goroutine pileup** → `profilers.md` (threads/concurrency)
- **Read an EXPLAIN ANALYZE plan** → `db-diagnosis.md` (reading plans)
- **Kill an N+1 query** → `db-diagnosis.md` (N+1 per ORM)
- **Fix `pool timeout` / `too many connections`** → `db-diagnosis.md` (pool sizing)
- **Untangle a lock wait / deadlock** → `db-diagnosis.md` (lock chains)
- **Prove an optimization helped** → `profilers.md` (k6/wrk baseline)
