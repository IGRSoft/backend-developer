# Profilers Reference

Use this when:

- A service is too slow or uses too much memory and you need to find *where*.
- You want a reproducible before/after measurement of an optimization.
- You are choosing between pprof, py-spy, JFR, clinic, or a heap snapshot.

Skip if:

- The problem is a *slow query* or *pool exhaustion* — that is [db-diagnosis.md](db-diagnosis.md).
- You only need the tool-from-symptom decision. See [be-diagnostics SKILL.md](../SKILL.md).

Jump to:

- The Measure → Fix → Re-measure Loop
- Generating Load (k6 / wrk)
- Tool Selection
- Node.js
- Go
- JVM (Java / Kotlin)
- Python
- .NET
- Heap & Leak Diagnosis
- Continuous Profiling (prod, always-on)
- Diagnostic Table

---

## The Measure → Fix → Re-measure Loop

Optimization without measurement is guessing. The loop, every time:

1. **Reproduce** a representative, repeatable load (a k6/wrk script, fixed request set).
2. **Measure** to find the hot path — never optimize a handler you only *suspect*.
3. **Record a baseline** (commit the k6 summary JSON, the flamegraph SVG).
4. **Change one thing.**
5. **Re-measure** against the baseline. Keep the win or revert.
6. **Stop** when you hit the target or the next hot path is in a managed dependency.

Rules that save hours:

- Profile a **release-shaped build** (production config, no hot-reload, no inline source maps) — a dev server's hot path is not production's.
- Most time hides in a few percent of code — fix the top frame, then re-profile; the profile changes shape after each fix.
- **Algorithmic and I/O wins beat micro-optimization.** Killing an N+1 (one query instead of N) or adding a cache outweighs any CPU tweak — but confirm with [db-diagnosis.md](db-diagnosis.md) first whether the time is in CPU or in I/O wait.

---

## Generating Load (k6 / wrk)

A profile is only as honest as the load that produced it.

```js
// load.js — k6, ramps to 50 VUs and asserts a latency SLO
import http from 'k6/http';
import { check } from 'k6';
export const options = {
  stages: [{ duration: '15s', target: 50 }, { duration: '45s', target: 50 }],
  thresholds: { http_req_duration: ['p(99)<300'] },
};
export default function () {
  const res = http.get('http://localhost:8080/api/orders');
  check(res, { '200': (r) => r.status === 200 });
}
```

```bash
k6 run load.js                       # summary report = cli-fallback evidence
wrk -t4 -c100 -d30s --latency http://localhost:8080/api/orders
```

Attach the k6 summary (p50/p95/p99, RPS, error rate) to the PR as evidence — this is the back-end analogue of a screenshot.

---

## Tool Selection

| Goal | Runtime | Tool |
|------|---------|------|
| CPU hot path | Node | `--cpu-prof`, `clinic flame`, inspector profiler |
| CPU hot path | Go | `pprof profile` (`net/http/pprof`) |
| CPU hot path | JVM | async-profiler `-e cpu`, JFR |
| CPU hot path | Python | py-spy `record` |
| CPU hot path | .NET | `dotnet-trace collect` |
| Heap / leak | Node | heap snapshot diff, `--heap-prof` |
| Heap / leak | Go | `pprof heap` (`-inuse_space`) |
| Heap / leak | JVM | heap dump + Eclipse MAT, JFR allocation |
| Heap / leak | Python | `tracemalloc`, `memray` |
| Heap / leak | .NET | `dotnet-gcdump` |
| Blocked concurrency | Node | `clinic bubbleprof`, event-loop delay |
| Blocked concurrency | Go | `pprof goroutine`, `runtime/trace` |
| Blocked concurrency | JVM | `jstack` / JFR thread dump |

---

## Node.js

```bash
# CPU profile to a .cpuprofile (open in Chrome DevTools > Performance)
node --cpu-prof --cpu-prof-dir=./prof server.js

# clinic.js: flamegraph or async/event-loop view
npx clinic flame -- node server.js          # CPU
npx clinic bubbleprof -- node server.js      # async I/O / event loop
npx clinic doctor -- node server.js          # event-loop delay, GC, handles

# Live process: attach the inspector (do NOT leave open in prod)
node --inspect=0.0.0.0:9229 server.js
```

Event-loop blocking is the Node-specific killer: a synchronous JSON/crypto/regex call on the request path stalls *every* connection. `clinic doctor` flags high event-loop delay; move the work to a worker thread or stream it.

## Go

```go
import _ "net/http/pprof"   // registers /debug/pprof on your mux
// then run an internal mux on a non-public port, e.g. localhost:6060
```

```bash
go tool pprof -http=:0 http://localhost:6060/debug/pprof/profile?seconds=30   # CPU, web UI
go tool pprof -inuse_space http://localhost:6060/debug/pprof/heap             # in-use heap
go tool pprof http://localhost:6060/debug/pprof/goroutine                     # goroutine dump
curl -o trace.out http://localhost:6060/debug/pprof/trace?seconds=5          # execution trace
go tool trace trace.out
```

`-inuse_space` shows what is retained now (leaks); `-alloc_space` shows total churn (GC pressure). For a goroutine leak, diff `goroutine` counts over time.

## JVM (Java / Kotlin)

```bash
# async-profiler: low-overhead CPU flamegraph from a running PID
./asprof -e cpu -d 30 -f flame.html <pid>

# Java Flight Recorder: rich, always-on-able profile
jcmd <pid> JFR.start name=rec duration=60s filename=rec.jfr settings=profile
jcmd <pid> JFR.dump name=rec filename=rec.jfr      # then open in JDK Mission Control

# Heap dump (on demand or on OOM) -> Eclipse MAT
jcmd <pid> GC.heap_dump /tmp/heap.hprof
java -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp -jar app.jar
```

Prefer async-profiler over JFR's method profiler for accurate CPU attribution (no safepoint bias). For allocation hot paths, JFR's `ObjectAllocationOutsideTLAB` events point straight at the allocating call site.

## Python

```bash
# py-spy: sample a running process, no code change, sees C frames
py-spy record -o profile.svg --pid $(pgrep -f gunicorn) -- --duration 30
py-spy dump --pid <pid>          # one-shot stack of every thread (find a hang)
py-spy top --pid <pid>           # live, top-like view

# Allocation tracking
python -X tracemalloc=25 app.py  # then tracemalloc.take_snapshot().statistics('lineno')
memray run -o out.bin app.py && memray flamegraph out.bin
```

py-spy needs `ptrace`; in containers add `--cap-add SYS_PTRACE` (or run as the same user). For async apps, `py-spy dump` reveals which coroutine is parked vs running.

## .NET

```bash
dotnet-trace collect -p <pid> --duration 00:00:30   # CPU -> .nettrace (open in PerfView/speedscope)
dotnet-counters monitor -p <pid>                    # live GC, threadpool, request metrics
dotnet-gcdump collect -p <pid>                      # heap snapshot for leak analysis
dotnet-stack report -p <pid>                        # managed stacks of all threads
```

---

## Heap & Leak Diagnosis

The universal technique: **two snapshots, same load, diff the retained set.**

1. Warm the service to steady state under fixed load.
2. Snapshot A.
3. Run the suspected workload for N minutes at the same rate.
4. Snapshot B.
5. Diff — objects that grew and are still reachable are the leak.

Common back-end leak shapes:

- **Unbounded cache** — a `Map`/dict that only ever grows. Fix: LRU + TTL with a max size.
- **Request data on a long-lived object** — appending per-request state to a module-level list/array.
- **Listeners/timers never removed** — `emitter.on(...)` per request; `setInterval` never cleared.
- **Unclosed resources** — DB connections, file/socket handles, streams not released on the error path (also shows up as `pool timeout`, see [db-diagnosis.md](db-diagnosis.md)).

---

## Continuous Profiling (prod, always-on)

The ad-hoc tools above answer "profile *this* instance *now*". **Continuous profiling** runs a low-overhead sampler across the whole fleet all the time, so when an incident already happened you scrub back to the flamegraph from the bad window instead of trying to reproduce it.

- **Grafana Pyroscope** and **Parca** (Polar Signals) are the open-source platforms. Parca leans on **eBPF** for whole-host, zero-instrumentation CPU profiling; Pyroscope supports both SDK pushers and an eBPF agent and ships over **OTLP**.
- The **OpenTelemetry profiles signal** is the emerging fourth telemetry signal — its OTLP protocol is still at "development" stability, but the **OTel eBPF profiler** already collects host-wide CPU stacks and exports them (e.g. to Pyroscope) today. Treat continuous profiling as production-ready *tooling* riding a *pre-stable* wire format: adopt it, but pin the agent/collector versions and don't assume cross-vendor portability yet.
- Overhead is sampling-class (single-digit %); the win is that a regression is already recorded. This complements RED metrics + trace sampling ([observability](../../observability/SKILL.md)) — metrics tell you *that* p99 moved, the stored profile tells you *which frame*.

The same flamegraph-reading discipline from the per-runtime sections applies; continuous profiling just changes *when* you capture (always) and *where* you look (the incident window).

---

## Diagnostic Table

| Observation | Tool reading | Likely cause | Fix direction |
|-------------|--------------|--------------|---------------|
| CPU pinned, one frame dominates | flamegraph top frame | hot serialization/regex/crypto on path | optimize/cache that frame; move off hot path |
| High event-loop delay (Node) | `clinic doctor` | sync I/O / CPU on request path | worker thread; stream; async API |
| Goroutine count climbs forever (Go) | `pprof goroutine` diff | leaked goroutine (no ctx cancel) | propagate `context`; bound with `errgroup` |
| Heap grows between snapshots | snapshot diff | unbounded cache / retained refs | bound cache; release on all paths |
| GC time high, throughput low (JVM) | JFR GC view | allocation churn | reduce per-request allocations; reuse buffers |
| Thread/coroutine parked on lock/I/O | `py-spy dump` / `jstack` | blocking call / deadlock | async the call; fix lock order |

Re-measure after every change — the flamegraph reshapes once the top frame is gone.
