---
description: Configure back-end debugging, tracing, and log capture, or triage and root-cause a specific failure
argument-hint: [error, stack trace, symptom, service, or scope] [--attach] [--container] [--trace] [--stack node|go|jvm|python|ruby|php|dotnet]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
estimated-cost:
  min-tokens: 2000
  max-tokens: 22000
  model-distribution:
    haiku: 15%
    sonnet: 70%
    opus: 15%
---

# Debug & Triage
<!-- Updated: July 2026 -->

Stand up a back-end service's debugging apparatus — structured logging with correlation IDs, an attachable debugger (local or inside a container), OpenTelemetry traces, slow-query logging, and request/response capture — **or**, when a concrete failure is already in hand, triage it: read the logs, reproduce, isolate, test a hypothesis, and report the root cause with a minimal fix proposal.

[Extended thinking: Back-end failures are rarely visible at the crash site. A 500 surfaces in one process, is caused by a pool starved three layers down, and is triggered by a retry storm from a caller that timed out. That is why this command has two modes rather than one: without correlated signals you cannot triage anything, so configure mode's job is to make the next failure legible — one correlation ID that ties a log line to a span to the query that blocked. Triage mode assumes those signals exist (or bootstraps the minimum subset needed) and runs a disciplined loop instead of pattern-matching the stack trace: capture the evidence to a file, reproduce deterministically, isolate the smallest failing path, state one falsifiable hypothesis, and test it. Reproduction comes before hypothesis on purpose — a fix validated against a bug you cannot re-trigger is a coincidence. The command is advisory by default and stops at a proposed minimal fix, because the highest-frequency back-end debugging error is not misdiagnosis, it is a speculative "fix" (bumping the pool size, adding a retry, widening a timeout) that hides the symptom and moves the failure somewhere less observable. Every step tees to a log because a triage transcript is the artifact — the thing a reviewer, a post-mortem, or the next on-call reads.]

## Modes

- **Configure mode (default)** — invoked with a service/scope or no argument: set up the debugging apparatus for ongoing investigation. Logging levels + correlation IDs, per-stack debugger attach, container-attached debugging, OpenTelemetry traces, slow-query logging, request/response capture.
- **Triage mode** — invoked with a concrete error message, stack trace, log excerpt, or symptom description: root-cause a single failure and propose the minimal fix.

**Mode detection.** `$ARGUMENTS` selects the mode:

| `$ARGUMENTS` looks like | Mode |
|-------------------------|------|
| empty, a path, a service name, or a `--flag` only | Configure |
| an error message, exception class, stack trace, log line, HTTP status + endpoint, or a symptom sentence ("p99 spiked after deploy", "pool timeout under load", "consumer lag climbing") | Triage |
| ambiguous | Ask once, then default to Triage — a real failure outranks setup |

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Triage is advisory by default.** Diagnose and propose the **minimal** fix; do not mutate source, config, or infrastructure unless the user explicitly asks. `Write`/`Edit` exist for configure mode's instrumentation and for writing the log/transcript — not for silently patching production code mid-triage.
2. **Reproduce before hypothesizing.** State the reproduction (request, payload, load level, data state) and confirm the failure re-triggers before naming a cause. If it cannot be reproduced, say so explicitly and downgrade every conclusion to a ranked hypothesis with the evidence that would confirm it. Never present an unreproduced guess as a root cause.
3. **One hypothesis, one test, one variable.** Change or probe exactly one thing per cycle, against a recorded baseline. Do NOT bundle three "likely" fixes and declare victory when the symptom disappears.
4. **Never fix by widening.** Bumping pool size, adding a retry, raising a timeout, or catching-and-ignoring is symptom suppression, not a fix. If the real fix is genuinely a capacity change, prove it with pool/queue/latency numbers first and say so explicitly.
5. **Capture everything to `.context/logs/debug-<timestamp>.log`.** Every command, log excerpt, query plan, profile summary, and reproduction attempt tees into that file with `tee -a`. The log is the triage transcript and the single source of truth — do not rely on terminal scrollback.
6. **Never print or persist secrets.** Redact tokens, passwords, connection strings, API keys, PII, and full auth headers from every captured excerpt before it reaches the log. When a log line's payload is needed, capture the shape, not the values.
7. **Single-command Bash invocations.** Use each toolchain's own working-directory/target flags (`npm --prefix <path>`, `go -C <path>`, `mvn -f <path>/pom.xml`, `uv run --project <path>`, `docker compose -f <path>/docker-compose.yml`, `dotnet <path>/x.csproj`). Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands.
8. **Never debug production interactively.** Attaching a debugger to a live production process suspends it. Read-only signals (logs, traces, metrics, sampled profiles, `EXPLAIN` on a replica) are always allowed; breakpoints and stop-the-world dumps go on a local, staging, or drained instance. If only production reproduces it, say so and propose a capture-based path.
9. **Tool-missing never hard-fails.** If a debugger, profiler, or the Docker daemon is unavailable, print the install hint, fall back to the next-best signal, and continue. Report what was skipped.
10. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Configure mode: set up logging, correlation IDs, tracing, and debugger attach for a service
/backend-developer:debug services/orders-api

# Configure only the debugger attach path for the local process
/backend-developer:debug services/orders-api --attach

# Configure debugging into a running container (port publishing + attach recipe)
/backend-developer:debug services/orders-api --container

# Wire OpenTelemetry traces + slow-query logging so the next incident is legible
/backend-developer:debug services/orders-api --trace

# Triage mode: root-cause a specific failure
/backend-developer:debug "TypeError: Cannot read properties of undefined (reading 'id') at OrderService.finalize (order.service.ts:88)"
/backend-developer:debug "500s on POST /orders since 14:02, logs show 'sorry, too many clients already'"
/backend-developer:debug "p99 on GET /orders/{id} went 40ms -> 3.5s after the last deploy"
/backend-developer:debug "kafka consumer group orders-worker lag climbing, same offset retried forever"
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `$ARGUMENTS` | (empty → configure at repo root) | Error/stack trace/symptom → triage. Path or service name → configure. |
| `--attach` | off | Configure mode: emit the debugger attach recipe for the detected stack (launch flags, port, IDE/CLI attach command, source-map/symbol notes). |
| `--container` | off | Configure mode: emit the container-attached debugging recipe — debug port published in `docker-compose.yml`, bind mounts for sources, required capabilities, attach from the host. |
| `--trace` | off | Configure mode: wire OpenTelemetry traces (spans + context propagation), correlation-ID middleware, and slow-query logging. |
| `--stack node\|go\|jvm\|python\|ruby\|php\|dotnet` | auto-detect | Override stack detection. Use in polyglot repos or when detection is ambiguous. |

With no configure flags, configure mode does all four layers (logging, attach, container, tracing) and says so. Triage mode ignores the configure flags except `--stack`.

## Stack Detection

**`--stack` wins outright.** When `--stack` is passed, that is the stack — in both configure and triage mode — and no detection or routing delegation runs. Only without it do the rules below apply.

Resolve the stack the same way `/backend-developer:build-test` does (canonical marker → runtime → agent map: `skills/_shared/language-detection.md` — keep in sync, do not fork). If two server stacks are in scope and the failure does not name one, delegate the routing decision:

**Use Task tool with subagent_type="backend-developer:backend-developer"**
Prompt: "Resolve which back-end stack owns this {debug setup | failure}: {arguments}. Markers found: {markers}. Entry points: {entrypoints}. Evidence: {excerpt}. Return exactly one stack and the owning agent, or say the investigation must be split across services. Do not fix anything."

---

## Configure Mode

Goal: the next failure in this service should be explainable from artifacts alone. Four layers, in this order — instrumentation before debuggers, because an attachable process that emits nothing is still opaque.

### Layer 1: Structured Logging & Correlation IDs

1. Detect the logger in use (`pino`/`winston` (Node), `log/slog`/`zerolog`/`zap` (Go), Logback/`slf4j` (JVM), `structlog`/stdlib `logging` (Python), `lograge`/`semantic_logger` (Ruby), Monolog (PHP), `ILogger`/Serilog (.NET)). Never introduce a second logging framework.
2. Enforce **JSON output** in non-dev environments, with a stable field set: `ts`, `level`, `msg`, `service`, `env`, `correlation_id`, `trace_id`, `span_id`, `user_id` (or tenant), `route`, `status`, `duration_ms`, `err.type`, `err.msg`, `err.stack`.
3. Wire a **correlation ID** end to end: read the inbound `traceparent` / `X-Request-Id`; generate one when absent; store it in the request-scoped context (AsyncLocalStorage, `context.Context`, MDC, `contextvars`, `ActiveSupport::CurrentAttributes`, `AsyncLocalStorage`/`IHttpContextAccessor`); attach it to every log line; propagate it on outbound HTTP, gRPC, and message-broker calls (header/metadata); echo it in the response header and in the error body so a user-reported failure is greppable.
4. Set levels per environment (`debug` local, `info` staging, `info`/`warn` production) and expose a **runtime level switch** — env var re-read on SIGHUP, `/admin/log-level` behind auth, or the framework's own dynamic level endpoint — so raising verbosity during an incident does not require a redeploy.
5. Confirm redaction is configured for `authorization`, `cookie`, `set-cookie`, `password`, `token`, `secret`, card/PII fields, and connection strings (`pino.redact`, Logback masking converter, `structlog` processors, Serilog destructuring policies).

Full field conventions, propagation, and RED/USE signal design: `skills/tooling/observability/SKILL.md`.

### Layer 2: Debugger Attach (`--attach`)

| Stack | Start for debugging | Attach | Notes |
|-------|--------------------|--------|-------|
| Node.js / TS | `node --inspect=127.0.0.1:9229 dist/server.js`; break at first line: `--inspect-brk`; `ndb npm start`; TS via `tsx --inspect src/server.ts` | `chrome://inspect`, VS Code "attach to port 9229", or `node inspect -p <pid>` | Bind to `127.0.0.1` — an open inspector port is remote code execution. Source maps required for TS frames. Never `--inspect` in production. |
| Go | `dlv debug ./cmd/server` (build+run) or `dlv exec ./bin/server` | `dlv attach <pid>`; headless for IDEs: `dlv --headless --listen=127.0.0.1:2345 --api-version=2 attach <pid>` | Build with `-gcflags="all=-N -l"` to stop the optimizer from eliding frames/variables. |
| JVM (Java/Kotlin) | `java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=127.0.0.1:5005 -jar app.jar` (`suspend=y` to wait for the debugger) | IDE remote JVM debug on 5005; `jdb -attach 5005` | JDWP is unauthenticated — bind to loopback only, never expose it. Also useful without a debugger: `jcmd <pid> Thread.print`, `jcmd <pid> GC.heap_info`. |
| Python | `python -m debugpy --listen 127.0.0.1:5678 --wait-for-client -m uvicorn app:app`; or `import debugpy; debugpy.listen(5678)` in-process | VS Code "Python: Remote Attach"; `pdb`/`breakpoint()` for terminal sessions | With reloaders (`--reload`, Django `runserver`) the child process holds the port — disable reload while debugging. |
| Ruby | `rdbg --open --port 12345 -c -- bin/rails server`; legacy: `byebug`/`binding.pry` | `rdbg --attach 12345`, or the IDE's `debug` gem adapter | Rails: set `config.cache_classes = true` while stepping to avoid reload churn. |
| PHP | Xdebug 3: `XDEBUG_MODE=debug XDEBUG_SESSION=1` with `xdebug.client_host`/`client_port=9003` in `php.ini` | IDE listens on 9003 (Xdebug 3 default; 9000 was Xdebug 2) | Xdebug in `debug` mode is a large slowdown — keep it off by default and enable per request via the `XDEBUG_TRIGGER` cookie/env. |
| .NET | `dotnet run` then attach; or `vsdbg`/`netcoredbg` for headless/remote | VS/VS Code attach to process; `dotnet-dump collect -p <pid>` + `dotnet-dump analyze` for post-mortem | `dotnet-counters monitor -p <pid>` and `dotnet-trace collect -p <pid>` need no breakpoints and are production-safe. |

Write the attach recipe into the project's launch config when one exists (`.vscode/launch.json`, IDE run config, `Makefile` target) rather than leaving it in chat — but do NOT change the default start command.

### Layer 3: Container-Attached Debugging (`--container`)

1. **Publish the debug port** in the Compose override (not the base file) so production images never carry it:
   ```yaml
   # docker-compose.debug.yml — merged with `-f docker-compose.yml -f docker-compose.debug.yml`
   services:
     api:
       command: ["node", "--inspect=0.0.0.0:9229", "dist/server.js"]
       ports: ["127.0.0.1:9229:9229"]      # bind the HOST side to loopback
       environment: { NODE_OPTIONS: "--enable-source-maps", LOG_LEVEL: debug }
       volumes: ["./src:/app/src:ro"]       # source paths must match the build's paths
   ```
   Same shape per stack: Delve `--headless --listen=0.0.0.0:2345` + `2345`; JDWP `address=*:5005` + `5005`; `debugpy --listen 0.0.0.0:5678` + `5678`; `rdbg --open --host 0.0.0.0 --port 12345`; Xdebug `client_host=host.docker.internal` + `9003`.
2. **Inside-container listeners bind `0.0.0.0`; the host publish binds `127.0.0.1`.** Never publish a debug port on a routable interface.
3. **Capabilities:** Delve and profilers that use `ptrace` need `cap_add: [SYS_PTRACE]` and often `security_opt: ["seccomp:unconfined"]` in the debug override only.
4. **Path mapping:** the debugger maps host paths to container paths — mismatched roots produce "source not found" and silently unbound breakpoints. Record the mapping in the launch config.
5. **Attach without a debugger** for a wedged container: `docker compose exec api sh` then the stack's dump tool (`kill -QUIT` for a Go goroutine dump, `jcmd Thread.print`, `py-spy dump --pid 1`, `dotnet-stack report -p 1`). Slim images may lack a shell — use a debug sidecar image sharing the PID namespace.

Image, capability, and Compose specifics: `skills/tooling/containerization/SKILL.md`.

### Layer 4: Traces, Slow Queries, and Request Capture (`--trace`)

1. **OpenTelemetry:** install the SDK + auto-instrumentation for the stack (`@opentelemetry/auto-instrumentations-node`, `otelhttp`/`otelgrpc`, the OTel Java agent `-javaagent:opentelemetry-javaagent.jar`, `opentelemetry-instrumentation` + `opentelemetry-instrument`, `OpenTelemetry.Instrumentation.*`). Set `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT`, and a sampling ratio (tail-based or a low head ratio + always-sample-on-error). Confirm `trace_id` reaches the log lines from Layer 1 — uncorrelated traces are three haystacks, not one.
2. **Span the boundaries that fail:** inbound handler, each DB query, each outbound HTTP/gRPC call, cache reads, and message publish/consume. Record `db.statement` (parameterized — never with bound values), `http.route`, `messaging.destination`, and the retry/attempt number as attributes.
3. **Slow-query logging:**
   - PostgreSQL: `log_min_duration_statement = 200ms`, `log_lock_waits = on`, `log_temp_files = 0`; enable `pg_stat_statements`.
   - MySQL: `slow_query_log = ON`, `long_query_time = 0.2`, `log_queries_not_using_indexes = ON` (dev only — noisy).
   - MongoDB: profiler level 1 with `slowms`.
   - ORM-side: `LOG_LEVEL=debug` on the ORM logger, or a statement counter per request to surface N+1 (Prisma `$on('query')`, SQLAlchemy `echo`/event, Hibernate `show_sql` + `generate_statistics`, ActiveRecord `db` log, EF Core `LogTo`).
4. **Request/response capture:** log method, route template (never the raw path — it leaks ids into cardinality), status, duration, request/response **sizes and shapes**, and the correlation ID. Capture full bodies only behind an explicit debug flag, with redaction, sampled, and time-boxed. For third-party integrations, capture the outbound request/response pair to `.context/logs/` behind the same flag.
5. **Health/readiness + pool metrics:** expose pool in-use/idle/waiting, queue depth, consumer lag, and event-loop/GC pressure as metrics — these are the numbers triage mode reads first.

### Configure Mode Output

```markdown
## Debug Configuration

**Target:** {path or service}
**Stack:** {Node/TS | Go | JVM | Python | Ruby | PHP | .NET} ({marker})
**Layers configured:** logging+correlation / attach / container / trace

| Layer | Status | Artifact |
|-------|--------|----------|
| Structured logging + correlation ID | ✅ wired / ⚠ partial / ⏭ already present | {files touched, middleware name} |
| Debugger attach | ✅ / ⏭ | {launch config path, port, command} |
| Container attach | ✅ / ⏭ | docker-compose.debug.yml, port {n}, caps {SYS_PTRACE} |
| Traces + slow queries | ✅ / ⏭ | {OTel exporter, sampling, log_min_duration_statement} |

**Verify it works:**
1. {curl with X-Request-Id; grep the same id out of the logs}
2. {attach the debugger, hit a breakpoint on the health route}
3. {trigger a slow query; confirm the span and the slow-query log line share trace_id}

**Not configured:** {layer} — {reason: no OTel collector endpoint, no Compose file, missing tool}
```

---

## Triage Mode

Run when `$ARGUMENTS` carries a concrete failure. Advisory: end at a proposed minimal fix.

### Step 1: Capture

1. Create `.context/logs/` if absent. Compute `TS="$(date +%Y%m%d-%H%M%S)"` and `LOG=".context/logs/debug-${TS}.log"`. Every subsequent command tees to it.
2. Record the failure statement verbatim: message, exception type, stack frames, HTTP status + route, timestamp, environment, and the first-seen time.
3. Pull the surrounding evidence, redacting secrets:
   ```bash
   grep -n '"correlation_id":"<id>"' app.log | tail -50 2>&1 | tee -a "$LOG"
   docker compose -f docker-compose.yml logs --since 30m --no-color api 2>&1 | tee -a "$LOG"
   ```
   Include: the failing request's log lines, the lines immediately before it, pool/queue metrics at that moment, and the deploy/migration timeline (`git log --since` for the window).
4. Classify the symptom family (table below) and note which signal to read first.

### Step 2: Reproduce

1. Derive the smallest trigger: exact request (method, route, payload shape), auth context (which role/tenant), data state (which row, which queue depth), and load level (single request vs concurrent).
2. Re-trigger it locally or on staging and confirm the same failure — same message, same frame. Record the command and the result in the log.
3. If it will not reproduce: record what varies (concurrency, data volume, clock, cache warmth, a specific tenant's data, a specific broker partition), and continue in **evidence-only** mode where every conclusion stays a ranked hypothesis. Consider capture-based reproduction: replay the captured request, run the load profile with k6/wrk, or restore an anonymized data snapshot.

### Step 3: Isolate

Bisect along whichever axis the symptom family suggests, one at a time:

- **Layer:** does it fail at the handler, the service, the repository, or the driver? Add a probe (log line/span) at each boundary and find the first one that sees bad state.
- **Time:** did it start at a deploy, a migration, a config change, a dependency bump, or a traffic shift? Correlate against the deploy timeline.
- **Input:** which field/value flips it? Shrink the payload until the failure disappears.
- **Concurrency:** does one request succeed and N fail? That is contention, pooling, or shared mutable state — not logic.
- **Environment:** local vs staging vs prod difference — config, data volume, network policy, or a version skew (`skills/_shared/version-feature-matrix.md`).

### Step 4: Hypothesize & Test

State **one** falsifiable hypothesis: *"`finalize()` reads `order.customer` assuming the eager-load ran; the retry path calls it with a lazily-loaded entity outside the session, so the association is undefined."* Then name the single cheapest probe that would disprove it (a log of the loaded relations, a `pg_stat_activity` snapshot, an `EXPLAIN ANALYZE`, a heap-snapshot diff, a goroutine dump). Run it, record the result, and keep or discard. Repeat — never batch hypotheses.

Delegate the probe when it needs a specialist:

- Slow query, lock wait, deadlock, connection-pool exhaustion, N+1:
  **Use Task tool with subagent_type="backend-developer:database-engineer"**
  Prompt: "Diagnose this database-side symptom for the service at `{path}`. Symptom: {symptom}. Evidence from `{LOG}`:\n```\n{excerpt}\n```\nRun/interpret the read-only diagnostics: `EXPLAIN (ANALYZE, BUFFERS)` on the suspect query, `pg_stat_activity`/`pg_locks` (or the engine's equivalent) for blocking chains, `pg_stat_statements` for the top consumers, and pool in-use/waiting counts. Identify whether this is a missing index, a plan regression, an N+1, a long transaction holding a slot, a lock-order deadlock, or an undersized/leaking pool. Return the diagnosis with the plan/lock evidence and a minimal fix proposal. Advisory only — do not apply migrations or change the pool config."
- Latency/CPU/memory profile, event-loop or goroutine pileup, leak:
  **Use Task tool with subagent_type="backend-developer:be-performance-engineer"**
  Prompt: "Profile-diagnose this symptom for the service at `{path}`. Symptom: {symptom}. Evidence from `{LOG}`:\n```\n{excerpt}\n```\nUnder a reproduced load, take the appropriate sampled profile for the stack (pprof / py-spy / async-profiler or JFR / --cpu-prof / dotnet-trace), or two heap snapshots for a growth symptom, and diff the retained set. Return the top frames or the retained set with a measurement-backed cause and a minimal fix proposal. Do NOT attach to a production process; use a local, staging, or drained instance. Advisory only."
- TLS handshake failures, CORS rejections, auth/authz failures, token/JWT validation, suspected injection or SSRF:
  **Use Task tool with subagent_type="backend-developer:be-security-auditor"**
  Prompt: "Diagnose this security-boundary failure for the service at `{path}`. Symptom: {symptom}. Evidence from `{LOG}` (secrets redacted):\n```\n{excerpt}\n```\nDetermine whether this is a misconfiguration (cert chain/SAN/expiry, CORS origin+credentials mismatch, clock skew on token validation, wrong audience/issuer, missing key rotation) or a genuine boundary defect (missing authz check, tenant leakage). Return the cause and the minimal fix. Do NOT weaken a control to make the error go away, and do NOT include any secret material in the response."
- Stack-specific runtime semantics (async/await misuse, context cancellation, transaction/session scope, GC or thread-pool behavior): route to the owning stack developer — `subagent_type="backend-developer:node-developer"`, `"backend-developer:go-developer"`, `"backend-developer:jvm-backend-developer"`, `"backend-developer:python-backend-developer"`, `"backend-developer:ruby-developer"`, `"backend-developer:php-developer"`, or `"backend-developer:dotnet-developer"` — with the failure, the reproduction, the isolated boundary, and the log excerpt. Ask for the root cause plus the minimal fix; state explicitly that it is advisory.

### Step 5: Report

Root cause with evidence, minimal fix proposal, verification plan, and prevention (the regression test, the missing signal, the alert threshold). Never end at "probably".

## Symptom Families

| Family | Typical signals | First read | Usual causes | Do NOT |
|--------|-----------------|------------|--------------|--------|
| **5xx / unhandled rejection / panic** | error log burst, one route, starts at a deploy | logs by correlation ID; the throwing frame | missing null/undefined guard, unawaited promise rejecting, panic in a goroutine with no recover, bad migration, changed upstream contract | swallow it in a global handler and call it fixed |
| **Connection-pool exhaustion** | `pool timeout`, `too many clients already`, requests queue then time out | pool in-use/waiting metrics + `pg_stat_activity` | pool undersized for concurrency, connections leaked on the error path, long-running transaction holding a slot, sync work inside a transaction | raise `max_connections` before proving the leak |
| **Deadlock / lock wait** | `deadlock detected`, `Lock wait timeout exceeded`, latency cliff on writes | `pg_locks` blocking tree / `SHOW ENGINE INNODB STATUS` | inconsistent lock ordering across code paths, `SELECT ... FOR UPDATE` held across an external call, a hot row/counter | add a blanket retry loop around the transaction |
| **N+1 / slow query** | one route slow, statement count scales with result size, plan shows seq scan | ORM statement log; `EXPLAIN (ANALYZE, BUFFERS)` | lazy-loaded association in a loop, missing index on the filter/join column, plan regression after data growth, `SELECT *` over a wide table | add an index without reading the plan |
| **Memory growth / leaked handles** | RSS climbs monotonically, OOMKilled, FD/socket count grows | two heap snapshots under steady load, diffed; `lsof`/FD count | unbounded cache (no LRU/TTL), request-scoped data attached to a long-lived object, listeners never removed, streams/clients never closed | restart on a cron and move on |
| **Timeouts / retry storms** | upstream timeouts, then a self-inflicted traffic multiplier, cascading failure | trace waterfall + retry-attempt attribute | no timeout budget, retries at every layer multiplying, no jitter, no circuit breaker, retrying non-idempotent writes | increase every timeout |
| **Consumer lag / poison message** | group lag climbs, same offset reprocessed forever, DLQ empty | consumer offsets + the handler's error log for that offset | handler throws on one message and the offset never commits, no DLQ/parking, processing slower than production, rebalance thrash | skip the offset by hand in prod |
| **TLS / CORS / auth failures** | `certificate verify failed`, `SSLHandshakeException`, CORS preflight blocked, 401/403 on valid credentials | handshake/preflight log lines; token claims (never the token) | missing intermediate cert, expired cert, SAN/hostname mismatch, CORS origin+`credentials` mismatch, clock skew, wrong audience/issuer, key rotation not picked up | disable verification, or set `Access-Control-Allow-Origin: *` with credentials |

Symptom → tool routing, copy-paste diagnosis commands, profiler quickstarts, and the DB-diagnosis workflow: `skills/tooling/be-diagnostics/SKILL.md` (plus its `references/profilers.md` and `references/db-diagnosis.md`).

### Triage Mode Output

```markdown
## Triage Report

**Failure:** {message / status + route / symptom}
**Family:** {5xx | pool exhaustion | deadlock | N+1 / slow query | memory growth | timeout / retry storm | consumer lag | TLS / CORS / auth}
**Stack:** {Node/TS | Go | JVM | Python | Ruby | PHP | .NET}
**Environment:** {local | staging | production (read-only signals)}
**Transcript:** .context/logs/debug-{timestamp}.log

### Reproduction
- **Trigger:** {request / load / data state}
- **Reproduced:** yes ({command}) / no — evidence-only mode, conclusions are ranked hypotheses
- **Baseline:** {healthy behavior for comparison}

### Root Cause
{One paragraph. What breaks, where, and why — with file:line.}

**Evidence:**
| # | Signal | What it shows |
|---|--------|---------------|
| 1 | log excerpt / query plan / pool snapshot / profile / dump | {the specific line or number that proves it} |

**Ruled out:** {hypothesis} — {the probe that disproved it}

### Minimal Fix Proposal (advisory — not applied)
- **Change:** {file:line — the smallest change that removes the cause}
- **Why minimal:** {what it does NOT change}
- **Risk:** {blast radius, migration/restart needed, rollback path}
- **Rejected shortcuts:** {e.g. "raise pool size" — hides the leak; "add retry" — multiplies the storm}

### Verification Plan
1. {reproduction that must now pass}
2. {regression test to add — route to /backend-developer:gen-tests}
3. {metric/threshold that must return to baseline}

### Prevention
- **Missing signal:** {the log field, span, or metric whose absence made this slow to find}
- **Alert:** {threshold that would have caught it first}
- **Related risk:** {other call sites with the same pattern}
```

## Tool Availability

| Missing tool | Install hint | Fallback |
|--------------|--------------|----------|
| `dlv` (Go) | `go install github.com/go-delve/delve/cmd/dlv@latest` | `kill -QUIT <pid>` goroutine dump; `net/http/pprof` |
| `debugpy` (Python) | `uv add --dev debugpy` | `breakpoint()` / `pdb`; `py-spy dump --pid <pid>` |
| `py-spy` | `uv tool install py-spy` (needs `ptrace`; in containers `--cap-add SYS_PTRACE`) | `faulthandler.dump_traceback_later`, `tracemalloc` |
| `rdbg` (Ruby) | `gem install debug` | `binding.irb`; `rails console` reproduction |
| Xdebug (PHP) | `pecl install xdebug` + `php.ini` config | `error_log()` probes; `var_dump` on a scratch route |
| `dotnet-trace` / `dotnet-dump` / `dotnet-counters` | `dotnet tool install -g dotnet-trace` (etc.) | `ILogger` probes; `Environment.StackTrace` |
| JDK tools (`jcmd`, `jstack`, JFR) | ship with the JDK — use a JDK image, not a JRE image | thread dump via `kill -3 <pid>` to stdout |
| `docker` (for `--container`) | `brew install --cask docker` and start the daemon | local process attach only; note the skip |
| OTel collector endpoint | run `otel/opentelemetry-collector` in Compose | console span exporter (`OTEL_TRACES_EXPORTER=console`) into the log |

Never hard-fail on a missing tool — print the hint, fall back to the next-best signal, report the skip.

## Error Handling

### Cannot reproduce
```
Note: The failure did not re-trigger with the derived reproduction.
Continuing in evidence-only mode: every conclusion below is a ranked hypothesis,
not a confirmed root cause. Listed for each: the probe or capture that would confirm it.
Suggestion: capture the failing request (correlation ID {id}) with body logging enabled
and time-boxed, or reproduce the load profile with k6 before applying any fix.
```

### No logs / no correlation ID
```
Warning: No structured logs or correlation IDs found for {service}.
Triage is limited to the stack trace and static reading of the code path.
Suggestion: run /backend-developer:debug {service} --trace first to wire correlation IDs,
structured logging, and traces, then re-trigger and re-run triage.
```

### Production-only failure
```
Note: {symptom} reproduces only in production.
Interactive debugging is NOT performed against production (breakpoints suspend the process).
Proceeding with read-only signals: logs, traces, metrics, sampled profiles, and EXPLAIN on a replica.
Suggestion: mirror the production data volume/config into staging, or capture the failing
requests and replay them locally.
```

### Ambiguous mode
```
Note: "{arguments}" reads as both a scope and a symptom.
Assuming Triage mode (a live failure outranks setup).
Suggestion: re-run with a path only, e.g. /backend-developer:debug services/orders-api,
for the configure workflow.
```

### No stack detected
```
Error: No back-end stack detected under {path}.
Looked for: package.json (with a server dep), go.mod, pom.xml/build.gradle,
pyproject.toml/requirements.txt/uv.lock, Gemfile, composer.json, *.csproj/*.sln.
Suggestion: run from the service directory that holds the manifest, or pass --stack.
```

### Secrets present in captured evidence
Not written to the log. Redact the value, keep the field name and shape, and note `[redacted]` in the excerpt. If a secret was already committed to a log file or a ticket, say so plainly and recommend rotation — do not quietly move on.

### Debugger port already in use
```
Warning: Debug port {n} is already bound (another instance or a stale process).
Suggestion: stop the other process, or pick a free port and update the launch config /
Compose override to match — a mismatched port shows as "breakpoint not bound".
```

## Related commands

- `/backend-developer:fix-performance` — once triage names a hot path or slow query, run the load-test + profile + query-analysis loop and route the optimization.
- `/backend-developer:build-test` — reproduce the failure through the project's own test path; the build/test gate for any applied fix.
- `/backend-developer:gen-tests` — add the regression test named in the Prevention section, so the bug cannot return silently.
- `/backend-developer:db-migrate` — when triage traces the failure to a migration (missing column, un-applied change, lock taken by a migration).
- `/backend-developer:analyze-security` — when the failure is an auth/authz boundary rather than a bug; run the OWASP API Top 10 pass over the affected surface.
- `/backend-developer:review-code` — review the proposed minimal fix before it lands.
- `skills/tooling/be-diagnostics/SKILL.md` — symptom → tool routing, profiler quickstarts, pool/lock/slow-query diagnosis, memory-growth workflow.
- `skills/tooling/observability/SKILL.md` — structured logging fields, correlation-ID propagation, OpenTelemetry spans, RED/USE metrics.
- `skills/tooling/containerization/SKILL.md` — Compose overrides, debug ports, `SYS_PTRACE`, debug images and sidecars.
- `skills/data/query-optimization/SKILL.md` — reading `EXPLAIN ANALYZE`, N+1 elimination, index selection.
- `skills/_shared/version-feature-matrix.md` — runtime/engine floors for the debuggers, profilers, and DB features referenced above.
