---
name: profile-performance
description: Load-test (k6), profile hot paths, and analyze slow queries, routing findings to be-performance-engineer
argument-hint: "[target: url|service|path] [--load] [--profile] [--queries] [--vus N] [--duration 30s]"
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 2000
  max-tokens: 18000
  model-distribution:
    haiku: 15%
    sonnet: 70%
    opus: 15%
---

# Profile Performance
<!-- Updated: June 2026 -->

Load-test an HTTP endpoint with `k6`, attach a CPU/heap profiler to a hot service, and capture slow-query / EXPLAIN ANALYZE evidence — then hand the raw artifacts to `be-performance-engineer` for interpretation. Data collection is pure Bash; the agent is engaged only to read the reports and rank hot paths, slow queries, and saturation points. The command never guesses at bottlenecks itself.

[Extended thinking: Backend performance is a measure-first discipline, so this command's job is to produce *trustworthy* measurements and then defer judgment. It is runtime-aware — Go gets `pprof`, Node gets `clinic`/`0x`, the JVM gets `async-profiler`, Python web gets `py-spy`, and any HTTP surface gets `k6` load — because the same intent maps to different tools per stack. The single most common way backend profiling lies is the wrong environment: profiling a `NODE_ENV=development` server, an unoptimized JIT that never warmed up, or a database with cold caches and no representative data relocates the hot path entirely. The prerequisite check refuses a dev-mode/non-warmed target and tells the user how to run a production-like build (release binary, `NODE_ENV=production`, JIT-warmed, seeded DB) rather than profiling garbage. Every artifact lands under `.context/logs/profile-<timestamp>/` so the engineer (and the user) can re-open the k6 summary, the flame graph, and the EXPLAIN plans. `--queries` is the database path: EXPLAIN (ANALYZE, BUFFERS) on the slow statements plus an N+1 scan of the ORM logs, so the root cause is the plan, not a guess. Interpretation — top-N hotspots with `file:line`, p95/p99 versus threshold, the offending query and its plan, a fix plan ranked by effort/impact — is the agent's deliverable, not this command's.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Profile a production-like target, never dev-mode, never cold.** Before collecting any profile or load test, verify the service runs in a production-like configuration (release/optimized build, `NODE_ENV=production`, JIT warmed, representative seeded data, caches primed) — see the Environment Prerequisite Check. If it is in dev/debug mode or unwarmed, STOP and emit the run-correctly instruction — do NOT profile it. A wrong environment produces wrong hot paths; reporting them is worse than not profiling.
2. **Collection is Bash-only; interpretation is the agent's.** This command runs k6/profiler/EXPLAIN and saves artifacts. It does NOT eyeball the summary and declare a winner. Hand the artifacts to `be-performance-engineer` and let it produce the ranked findings.
3. **Save every artifact under `.context/logs/profile-<timestamp>/`.** Create the directory once per run; write the k6 JSON summary, the profile/flame graph, the EXPLAIN output, slow-query logs, and a `meta.txt` (target, modes, runtime, framework, tool, env config) there. The directory is the single source of truth for interpretation — do not rely on terminal scrollback.
4. **Single-command Bash invocations.** Use each tool's own flags for output paths and target selection. Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands.
5. **Pick the runtime tool, do not invent flags.** Resolve the runtime once (package manifest / binary), then run the matching tool from the Runtime / Tool Matrix exactly as written. If a flag is rejected, consult `--help` or `skill: observability` — never guess flag spellings.
6. **`--load` measures, never auto-edits.** Load mode runs k6 with `--vus`/`--duration` and p95/p99 thresholds. It does not change code. The optimization itself is the agent's plan plus a follow-up `code-review` run.
7. **Tool-missing never hard-fails.** If k6 or the runtime profiler is absent, print the install hint, skip that collection, and report what was skipped. If no tool is available for the requested mode, report the aggregated hints and stop without erroring out the session.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Load-test an HTTP endpoint at default VUs/duration
/backend-developer:profile-performance http://localhost:3000/api/orders --load

# Load-test with explicit virtual users and duration
/backend-developer:profile-performance http://localhost:8080/health --load --vus 100 --duration 60s

# CPU profile a running Node service while it takes traffic
/backend-developer:profile-performance services/orders --profile

# Analyze slow queries against the project's database
/backend-developer:profile-performance . --queries

# Full pass: load, profile, and slow-query analysis together
/backend-developer:profile-performance http://localhost:3000/api/orders --load --profile --queries
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `target` | `.` | A URL (load test / trace the route), a service directory or process to attach a profiler to, or `.` to detect the primary service / database config. |
| `--load` | off | Run a `k6` load test against the URL with p95/p99 latency and error-rate thresholds; export the JSON summary. |
| `--profile` | off | Attach a CPU/heap profiler to the running service (Go pprof, Node clinic/0x, JVM async-profiler, Python py-spy) and capture a flame graph. |
| `--queries` | off | Capture slow-query logs and run `EXPLAIN (ANALYZE, BUFFERS)` on the offending statements; scan ORM logs for N+1 patterns. |
| `--vus N` | `10` | k6 virtual users (concurrency). Ignored unless `--load`. |
| `--duration 30s` | `30s` | k6 test duration (Go-style duration string). Ignored unless `--load`; for `--profile` attach, bounds the sampling window. |

If no mode flag is passed, default to `--load` when `target` is a URL, `--profile` when it is a service path, and `--queries` when only a database config is detected. `--vus`/`--duration` interact only with `--load` (and the `--profile` sampling window).

## Environment Prerequisite Check (profiled / load-tested targets)

Before any collection, confirm the target is measurable in a production-like state. Run this and STOP with the run-correctly hint if it fails:

| Check | How | Fail action |
|-------|-----|-------------|
| Production-like build/mode | `NODE_ENV=production` (Node); release binary (`go build` without race/debug, or `-ldflags`); Spring profile `prod`; `DEBUG=false` (Django/Flask); EF Core not in `Development` | Emit "run production-like" instruction; do not profile |
| JIT / runtime warmed | For JVM/V8 targets, the service has served warmup traffic before sampling (k6 `--warmup`-equivalent ramp, or a manual prime) | Emit warm-up hint |
| Representative data | DB seeded with production-scale row counts; caches primed (Redis warm, not empty) | Emit "seed representative data" hint |
| Reachable | `curl -fsS -o /dev/null -w '%{http_code}' <url>` returns 2xx/3xx (load/route modes); process/port resolves (profile mode); DB connection string valid (queries mode) | Emit Error Handling "target not reachable"; stop |

Run-correctly instruction to print on failure:

```bash
# Node: production mode, optimized
NODE_ENV=production node --max-old-space-size=512 dist/server.js
# Go: an optimized release binary (no -race), then warm it before profiling
go build -trimpath -o ./bin/svc ./cmd/svc && ./bin/svc
# Spring Boot: production profile, JIT warmed by a ramp before sampling
java -jar app.jar --spring.profiles.active=prod
# Seed representative data and prime caches before measuring.
```

Dev mode relocates the hot path (extra logging, unminified middleware, disabled caches); a cold JIT/cache makes the first requests dominate and lie. See `skill: observability` for production-like profiling setups. Static analysis of `--queries` against a config has no warm-up requirement — but the EXPLAIN must run against a representatively-sized dataset to be trustworthy.

## Runtime / Tool Matrix

Resolve the runtime once (package manifest, binary, or framework markers), then pick the row for the active mode. Run the command verbatim, substituting target, pid/url, duration, and output dir (`OUT=.context/logs/profile-<timestamp>`). The canonical flag reference is `skill: observability` (profiling-tools) — keep this matrix in sync with it, do not fork the flag spellings.

### Load test (`--load`, any HTTP runtime)

| Step | Command |
|------|---------|
| Run k6 | `k6 run --vus <vus> --duration <duration> --summary-export "$OUT/k6-summary.json" "$OUT/script.js"` (generate `script.js` hitting `<url>` with thresholds `http_req_duration: ['p(95)<300','p(99)<800']`, `http_req_failed: ['rate<0.01']`) |
| Quick smoke (no script) | `k6 run --vus <vus> --duration <duration> --summary-export "$OUT/k6-summary.json" - <<'EOF'` … inline default GET against `<url>` |
| Capture full output | tee k6's stdout to `"$OUT/k6-stdout.txt"` alongside the JSON summary so the p95/p99 thresholds and pass/fail are recorded |

### CPU / heap profile (`--profile`)

| Runtime | Command |
|---------|---------|
| Go | `go tool pprof -proto -output "$OUT/cpu.pprof" "http://<host>/debug/pprof/profile?seconds=<duration_secs>"` (heap: `.../debug/pprof/heap`); render: `go tool pprof -svg -output "$OUT/cpu.svg" "$OUT/cpu.pprof"` |
| Node (TS/JS) | `clinic flame --dest "$OUT/clinic" -- node dist/server.js` (or `0x -o --output-dir "$OUT/0x" -- node dist/server.js`); attach to a running pid: `node --inspect` + capture `--cpu-prof --cpu-prof-dir "$OUT"` |
| JVM (Spring) | `asprof -d <duration_secs> -f "$OUT/jvm-flame.html" -e cpu <pid>` (async-profiler; alloc: `-e alloc`) |
| Python (FastAPI/Django) | `py-spy record --format speedscope -o "$OUT/pyspy.speedscope.json" --pid <pid> --duration <duration_secs>` |
| .NET (ASP.NET Core) | `dotnet-trace collect -p <pid> --duration 00:00:<duration_secs> -o "$OUT/trace.nettrace"` then `dotnet-trace report "$OUT/trace.nettrace" topN > "$OUT/trace-topn.txt"` |

### Slow-query / EXPLAIN analysis (`--queries`)

| Engine | Command |
|--------|---------|
| PostgreSQL | enable `auto_explain` / `log_min_duration_statement`, collect to `"$OUT/slow.log"`; per statement: `psql "$DATABASE_URL" -c 'EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <stmt>' > "$OUT/explain-<n>.txt"` |
| MySQL | `pt-query-digest "$OUT/slow.log" > "$OUT/digest.txt"` (slow log enabled); `mysql -e 'EXPLAIN ANALYZE <stmt>' > "$OUT/explain-<n>.txt"` |
| MongoDB | `mongosh --eval 'db.<coll>.find(<q>).explain("executionStats")' > "$OUT/explain-<n>.json"`; profiler: `db.setProfilingLevel(1, { slowms: 100 })` then dump `system.profile` |
| ORM N+1 scan | enable query logging (Prisma `log: ['query']`, Hibernate `show_sql`, SQLAlchemy `echo`, EF Core `LogTo`), drive the endpoint once, and grep the log for repeated near-identical SELECTs into `"$OUT/n-plus-one.txt"` |

Microbenchmarks (single function/handler in isolation) are out of scope for this command's collection — they belong in the test suite (`skill: observability`).

## Workflow

### Phase 1: Resolve target, modes & runtime (Bash)

1. Confirm `target` resolves: a URL must return a reachable status (`curl -fsS`), a service path must exist, a `.`/config must yield a service or `DATABASE_URL`. If not, emit the Error Handling "target not reachable" message and stop.
2. Determine the requested modes from `--load`/`--profile`/`--queries`; if none passed, default by target type (URL→load, service path→profile, db-only→queries).
3. Detect runtime via `skill: language-detection` (package.json/tsconfig → Node; go.mod → Go; pom.xml/build.gradle → JVM; pyproject/requirements → Python; *.csproj → .NET) and the DB engine from the connection string / ORM config.
4. Create the artifact dir once: `TS="$(date +%Y%m%d-%H%M%S)"; OUT=".context/logs/profile-${TS}"; mkdir -p "$OUT"`.
5. Write `"$OUT/meta.txt"` with target, modes, runtime, framework, DB engine, chosen tools, `--vus`/`--duration`, and the detected environment config.

### Phase 2: Environment prerequisite check (Bash)

1. Run the Environment Prerequisite Check for the active modes. If the service is in dev/debug mode, unwarmed, or unreachable (load/profile), print the run-correctly instruction and STOP — do not profile.
2. For `--queries`, confirm the dataset is representatively sized; note row counts in `meta.txt`. Record warm-up / seed state for every mode.

### Phase 3: Collect (Bash)

1. Verify the tool for each active mode exists (`command -v k6`/`go`/`clinic`/`0x`/`asprof`/`py-spy`/`dotnet-trace`/`psql`/`mongosh`). If missing, print the install hint (Tool Availability), skip that collection, note the skip, and continue (do not silently substitute a different tool/mode).
2. **`--load`:** generate the k6 script (with p95/p99 + error-rate thresholds), run with `--vus`/`--duration`, export `k6-summary.json`, tee stdout.
3. **`--profile`:** attach the runtime profiler for `<duration>` while the service takes traffic (run a light k6 ramp concurrently if the service is otherwise idle), and write the flame graph / pprof / speedscope into `"$OUT"`.
4. **`--queries`:** collect the slow-query log, run `EXPLAIN (ANALYZE, BUFFERS)` on each offender, and capture the ORM N+1 scan.
5. Capture exit status (`${PIPESTATUS[0]}` where piped through `tee`). If a tool errors (k6 threshold breach is a *result*, not an error; pprof endpoint 404, profiler attach denied, psql auth failure are environment issues), record the message in `meta.txt` and surface it under Error Handling — these are environment issues, not target bugs.

### Phase 4: Interpret (delegate)

After artifacts are written, hand them to the performance engineer for the ranked analysis. This is the only delegation in the command.

- **Use Task tool with subagent_type="backend-developer:be-performance-engineer"**
  Prompt: "Interpret the performance artifacts for `{target}` ({runtime}/{framework}, modes: {modes}). Artifacts are in `{OUT}` (environment config and tools recorded in `{OUT}/meta.txt`). Read the k6 summary / flame graph / EXPLAIN plans and produce: (1) for `--load`, **p95/p99 and error rate versus the thresholds**, the throughput ceiling, and where latency degrades as VUs climb; (2) for `--profile`, the **top-N hotspots** as `file:line` (or symbol) with their share of CPU/allocations; (3) for `--queries`, the **slowest statements** with their plan diagnosis (seq scan, missing index, N+1) and a proposed index/query rewrite; (4) a **fix plan ranked by effort/impact** (algorithmic + query/index wins before micro-optimizations), each item naming the language agent (`backend-developer:{node|go|jvm-backend|python-backend|ruby|php|dotnet}-developer`) or `backend-developer:database-engineer` that would implement it. Do NOT edit code — return the ranked analysis."
- Expected output: p95/p99 vs threshold (load), ranked hotspot list with `file:line` (profile), slow-query + plan diagnosis (queries), effort/impact-ranked fix plan.
- Context: reads only the artifacts in `{OUT}`; no code edits.
- Error handling: if the engineer cannot read an artifact, report the artifact path so the user can open it directly (speedscope/clinic/pprof viewers); do not fabricate an analysis.

Model note: `be-performance-engineer` defaults to sonnet/high; for a large or cross-service profile a caller may raise it to opus/xhigh — pass `model="opus"` on the Task call when the trace/plan set is complex enough to warrant it.

### Phase 5: Report (Bash)

Emit the Output Format summary, pointing at `{OUT}` and folding in the engineer's ranked findings (or the skip/error note when collection did not run).

## Tool Availability

Confirm the chosen tool exists before collecting. If missing, print the hint, skip the collection, and report the skip.

| Missing tool | Mode | Install hint |
|--------------|------|--------------|
| `k6` | load | `brew install k6` (Linux: distro package, or the Grafana k6 apt/yum repo) |
| `clinic` / `0x` | profile (Node) | `npm i -g clinic 0x` (or `pnpm add -g`) |
| `go` (`pprof`) | profile (Go) | ships with the Go toolchain; expose `net/http/pprof` in the service |
| `asprof` (async-profiler) | profile (JVM) | download async-profiler release; needs `-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints` |
| `py-spy` | profile (Python) | `uv tool install py-spy` (or `pipx install py-spy`) |
| `dotnet-trace` | profile (.NET) | `dotnet tool install -g dotnet-trace` |
| `psql` / `mysql` / `mongosh` | queries | install the engine's client (`postgresql-client`, `mysql-client`, MongoDB shell) |
| `pt-query-digest` | queries (MySQL) | install Percona Toolkit |

Exact flag spellings vary across tool releases — verify against your toolchain when a flag is rejected. Never hard-fail on a missing tool: print the hint, skip the collection, continue, and report the skip.

## Output Format

```markdown
## Performance Profile Report

**Target:** {target}
**Modes:** load | profile | queries
**Runtime:** Node | Go | JVM | Python | Ruby | PHP | .NET
**Framework:** {Express | NestJS | Gin | Spring Boot | FastAPI | Rails | Laravel | ASP.NET Core}
**Tools:** {k6 | pprof | clinic/0x | async-profiler | py-spy | dotnet-trace | EXPLAIN ANALYZE}
**Environment:** production-like ✅ | (dev/cold: ❌ — stopped)
**Artifacts:** .context/logs/profile-{timestamp}/

| Step | Result | Notes |
|------|--------|-------|
| Environment prerequisite | ✅ / ❌ run-correctly / ⏭ N/A | {prod mode, warmed, seeded — or hint} |
| Collection | ✅ / ❌ / ⏭ skipped | {tools, vus/duration, or skip reason} |
| Interpretation | ✅ / ⏭ | {delegated to be-performance-engineer} |

### Load Test Summary
<!-- from be-performance-engineer; --load -->
| Metric | Value | Threshold | Pass? |
|--------|------:|----------:|:-----:|
| p95 latency | 412 ms | < 300 ms | ❌ |
| p99 latency | 980 ms | < 800 ms | ❌ |
| error rate | 0.4% | < 1% | ✅ |
| throughput | 1,840 req/s | — | — |

### Top Hotspots
<!-- from be-performance-engineer; --profile -->
| Rank | Location (file:line) | Share | Note |
|-----:|----------------------|------:|------|
| 1 | order.service.ts:142 | 38% | JSON serialize on every row |
| 2 | auth.middleware.ts:77 | 19% | bcrypt cost too high on hot path |

### Slow Queries
<!-- from be-performance-engineer; --queries -->
| Statement | Mean | Plan diagnosis | Fix |
|-----------|-----:|----------------|-----|
| SELECT … FROM orders WHERE user_id=$1 | 210 ms | Seq Scan, no index | add index on orders(user_id) |
| N+1 on order.items | 1.2 s total | 1 + N selects | eager-load via join / dataloader |

### Ranked Fix Plan
<!-- from be-performance-engineer; effort/impact order -->
1. {high-impact / low-effort fix} — implement via backend-developer:{agent}
2. {next} — ...

<!-- on skip/error only -->
### Skipped / Environment
- {tool}: {missing — install hint above} | {pprof endpoint not exposed} | {py-spy attach denied — run as process owner} | {psql auth failed}
```

## Error Handling

### Target not reachable
```
Error: Target not reachable: {target}
Suggestion: Pass a reachable URL, a running service path, a directory to detect,
or a valid DATABASE_URL, e.g.
/backend-developer:profile-performance http://localhost:3000/api/orders --load
```

### Dev-mode / cold target (load or profile)
```
Error: {target} is running in dev/debug mode or is not warmed — profiling it yields wrong hot paths.
Run a production-like instance (optimized build, prod mode, warmed JIT, seeded data):
  NODE_ENV=production node dist/server.js   # or: go build -trimpath ... && ./bin/svc
Then re-run: /backend-developer:profile-performance {target} --{mode}
```
This is a STOP, not a skip — do not profile a dev-mode/cold target.

### pprof endpoint not exposed (Go)
```
Warning: pprof could not collect (http://<host>/debug/pprof returned 404).
Register net/http/pprof (import _ "net/http/pprof") behind an internal listener,
then re-run. Artifacts (if any) are under {OUT}.
```

### Profiler attach denied (py-spy / async-profiler)
```
Warning: the profiler could not attach to pid {pid} (OS attach restriction).
Run as the target process's owner / with privilege (and for async-profiler enable
DebugNonSafepoints), then re-run.
```

### k6 thresholds breached
```
Note: k6 thresholds failed (p95/p99 or error rate over budget). This is a RESULT,
not an error — the JSON summary is in {OUT}/k6-summary.json and is handed to
be-performance-engineer for analysis.
```

### Tool missing
Print the install hint from Tool Availability, skip the collection, continue. Only when *every* eligible tool for the requested modes is absent does the command report "no profiling tool available" with the aggregated hints (no hard failure).

### Ambiguous target in a directory
```
Error: Could not resolve a single profilable service or database under {path}.
Suggestion: Pass the explicit URL, service path, or DATABASE_URL, e.g.
/backend-developer:profile-performance http://localhost:8080/health --load
```

## See Also

- `skill: observability` — canonical profiling-tools flag reference (k6/pprof/clinic/0x/async-profiler/py-spy/dotnet-trace/EXPLAIN), the measure→fix→re-measure loop, and the symptom→tool table. Keep the Runtime / Tool Matrix in sync with it.
- `skill: _shared/version-feature-matrix.md` — runtime/framework version markers and fallbacks for the profilers above.
- `skill: language-detection` — runtime and DB-engine resolution for the matrix.
- `/backend-developer:build-test` — produce a production-like build first before profiling.
- `/backend-developer:code-review` — apply the ranked algorithmic / query / index fixes the engineer recommends (DR criteria include N+1 queries and transaction correctness).
- `/backend-developer:deps-audit` — when the bottleneck is a dependency, not your code — audit/upgrade before micro-optimizing.
