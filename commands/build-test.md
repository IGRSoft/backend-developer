---
description: Detect the back-end stack, build, and run unit + integration tests (Testcontainers where present)
argument-hint: [path (default .)] [--clean] [--no-test] [--integration]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 1500
  max-tokens: 12000
  model-distribution:
    haiku: 40%
    sonnet: 55%
    opus: 5%
---

# Build & Test
<!-- Updated: June 2026 -->

Detect a back-end project's stack, install/build it, and run its tests with a single command. The happy path is pure Bash — no agent delegation. Agents are only engaged when the build or tests fail, and only the stack developer that owns the failing layer is consulted, with the relevant log excerpt.

[Extended thinking: This command is the detection-and-execution workhorse other backend-developer commands reuse. It resolves exactly one stack per invocation via a strict priority order, runs the canonical install/build/test sequence for that stack, and tees everything to a timestamped log. Because dependency-resolution, type-check/compile, and test failures have sharply different fixes, on failure it parses the first error, classifies the stage, and hands the matching stack developer a tight excerpt instead of the whole log. Integration suites (Testcontainers, ephemeral Postgres/Redis) are opt-in via `--integration` because they need a running Docker daemon and are slower. Keep the green path deterministic and shell-only so it stays cheap and scriptable.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve exactly one stack.** Walk the detection priority order top-down and stop at the first match. Do NOT run two stacks in one invocation. If the user disagrees with the auto-detected stack, they re-run with an explicit path to the subdirectory that holds the right manifest.
2. **Happy path is shell-only.** When install, build, and test all succeed, do NOT delegate to any agent. Report the result and stop.
3. **Single-command Bash invocations.** Use each toolchain's own working-directory flags (`npm --prefix <path>`, `go -C <path>`, `mvn -f <path>/pom.xml`, `gradle -p <path>`, `uv run --project <path>`, `bundle exec --gemfile`, `composer --working-dir`, `dotnet <path>/x.csproj`). Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands.
4. **Tee every phase to the log.** Each install/build/test command pipes through `tee -a` to `.context/logs/build-<timestamp>.log`. The log is the single source of truth for triage; do not rely on terminal scrollback.
5. **On failure, classify before delegating.** Parse the first error from the log, classify it as install / build / unit-test / integration-test, then delegate ONLY to the matching stack developer with the excerpt — never the whole log, never a second agent "just in case."
6. **Tool-missing never hard-fails.** If the required toolchain binary (or the Docker daemon for `--integration`) is absent, print the install hint, skip that phase or stack, and continue to the next eligible one in the priority order. Report what was skipped.
7. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Detect, build, and test the current directory
/backend-developer:build-test .

# Build a specific service in a monorepo
/backend-developer:build-test services/orders-api

# Fresh install (drop node_modules / caches), build, unit tests only
/backend-developer:build-test . --clean --no-test

# Run unit AND Testcontainers-backed integration suites
/backend-developer:build-test . --integration
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path` | `.` | Directory to detect and operate on. The detection scan is rooted here. |
| `--clean` | off | Remove the dependency/build cache before installing, forcing a fresh resolve. Node: `node_modules` + lockfile-respecting reinstall; Go: `go clean -cache`; Maven/Gradle: `clean` lifecycle; Python: recreate the `uv` venv; .NET: `dotnet clean`. |
| `--no-test` | off | Install and build only; skip the test phase entirely (both unit and integration). |
| `--integration` | off | After unit tests pass, also run Testcontainers-backed / DB-dependent integration suites. Requires a running Docker daemon; if absent, the integration phase is skipped (not failed). |

`--no-test` and `--integration` are mutually exclusive in effect: `--no-test` wins and skips all testing with a warning.

## Detection: Stack Priority

Scan `path` and apply the **first** match top-down. This is the canonical priority for this plugin; the marker → runtime → agent map lives in `skill: stack-detection` — keep this list in sync with it, do not fork the routing logic.

| Priority | Marker | Stack | Owning agent (on failure) |
|----------|--------|-------|---------------------------|
| 1 | `package.json` with a server dep (express/fastify/nestjs/hono/koa) | Node.js / TypeScript (npm / pnpm / yarn) | `node-developer` |
| 2 | `go.mod` | Go | `go-developer` |
| 3 | `pom.xml` / `build.gradle` / `build.gradle.kts` | JVM (Maven / Gradle, Spring Boot) | `jvm-backend-developer` |
| 4 | `pyproject.toml` / `requirements.txt` / `uv.lock` | Python web (uv / pip — FastAPI/Django/Flask) | `python-backend-developer` |
| 5 | `Gemfile` | Ruby (Bundler, Rails) | `ruby-developer` |
| 6 | `composer.json` | PHP (Composer — Laravel/Symfony) | `php-developer` |
| 7 | `*.csproj` / `*.sln` | C# / .NET (ASP.NET Core) | `dotnet-developer` |

**Package-manager tie-break for Node** (per `skill: stack-detection`): `pnpm-lock.yaml` → pnpm; `yarn.lock` → yarn; `package-lock.json` (or none) → npm. The server-dep check distinguishes a back-end service from a front-end-only `package.json`; a bare front-end manifest is not in scope for this command.

**Tie-break notes:**

- A repo can carry several manifests (e.g. a Go service with a `package.json` for tooling, or a Python service with a thin `package.json` for lint hooks). The marker highest in the priority table that has a real server/build target wins for *this* command's primary build; mention secondary layers in the summary and suggest a second run scoped to that subdir if its tests matter. Polyglot routing itself is the router's job (`skill: stack-detection`).
- A `package.json` whose only scripts wrap shell/lint tooling (no server dependency, no build/start) is repo tooling, not a back-end build — prefer the next real marker.
- Auxiliary `scripts/*.sh` or `Dockerfile`/`docker-compose.yml` alone never determine the stack; they inform the integration phase, not detection.

## Canonical Command Table

Run these verbatim (substituting `path` and the resolved package manager). Every command is single-invocation and tees to the log. Pin runtime/framework versions per `skills/_shared/version-feature-matrix.md` when behaviour differs by version.

| Stack | Install | Build | Unit Test | Integration Test (`--integration`) |
|-------|---------|-------|-----------|-------------------------------------|
| Node (npm) | `npm --prefix <path> ci` (fallback `install`) | `npm --prefix <path> run build` (skip if no `build` script) | `npm --prefix <path> test` (vitest/jest) | `npm --prefix <path> run test:integration` (Testcontainers) |
| Node (pnpm) | `pnpm -C <path> install --frozen-lockfile` | `pnpm -C <path> run build` | `pnpm -C <path> test` | `pnpm -C <path> run test:integration` |
| Node (yarn) | `yarn --cwd <path> install --immutable` | `yarn --cwd <path> build` | `yarn --cwd <path> test` | `yarn --cwd <path> test:integration` |
| Go | `go -C <path> mod download` | `go -C <path> build ./...` | `go -C <path> test ./...` | `go -C <path> test -tags=integration ./...` (Testcontainers-go) |
| JVM (Maven) | `mvn -f <path>/pom.xml -q dependency:go-offline` | `mvn -f <path>/pom.xml -q -DskipTests package` | `mvn -f <path>/pom.xml -q test` | `mvn -f <path>/pom.xml -q verify -Pintegration` (failsafe + Testcontainers) |
| JVM (Gradle) | `gradle -p <path> dependencies --refresh-dependencies` | `gradle -p <path> assemble` | `gradle -p <path> test` | `gradle -p <path> integrationTest` |
| Python (uv) | `uv sync --project <path>` | (no separate build; `uv sync` resolves the env) | `uv run --project <path> pytest -x -q -m "not integration"` | `uv run --project <path> pytest -m integration` (Testcontainers-python) |
| Ruby | `bundle install --gemfile <path>/Gemfile` | (no separate build) | `bundle exec --gemfile <path>/Gemfile rspec` (fallback `rails test`) | `bundle exec --gemfile <path>/Gemfile rspec spec/integration` |
| PHP | `composer --working-dir <path> install` | (no separate build) | `composer --working-dir <path> test` (fallback `phpunit`) | `composer --working-dir <path> test:integration` |
| .NET | `dotnet restore <path>` | `dotnet build <path> --no-restore` | `dotnet test <path> --filter Category!=Integration` | `dotnet test <path> --filter Category=Integration` |

Notes:
- The `build` phase is a no-op for interpreted stacks without a build step (Python/Ruby/PHP, and Node packages with no `build` script); record it as N/A, not a failure.
- For Go, integration suites conventionally gate behind a `//go:build integration` tag; if the project uses a different convention, fall back to running the full `./...` suite and note it.
- For Maven/Gradle, the integration variant runs the failsafe/`integrationTest` task that spins up Testcontainers; if no such task exists, report "no integration suite" rather than failing.
- Prefer the lockfile-respecting install (`ci` / `--frozen-lockfile` / `--immutable` / `go.sum` / `--locked`) so the run is reproducible; fall back to a plain install only when the lockfile is missing, and note the fallback.

## Workflow

### Phase 1: Detect (Bash)

1. Confirm `path` exists. If not, emit the Error Handling "path not found" message and stop.
2. Create `.context/logs/` if absent. Compute `TS="$(date +%Y%m%d-%H%M%S)"` and `LOG=".context/logs/build-${TS}.log"`.
3. Walk the detection priority table top-down; record the first matching marker and its stack. If nothing matches, emit "no recognized back-end stack" and stop.
4. For Node, apply the package-manager tie-break to pick npm/pnpm/yarn. Pre-resolve the owning agent for every stack (used only if a later phase fails).
5. Verify the required tool is installed (`command -v node`/`go`/`mvn`/`gradle`/`uv`/`bundle`/`composer`/`dotnet`). If missing, print the install hint (see Tool Availability), skip to the next eligible marker, and note the skip in the summary.
6. If `--integration`: verify the Docker daemon is reachable (`docker info`). If not, mark the integration phase as skippable and note it; do not fail.

### Phase 2: Install (Bash)

1. If `--clean`: remove the dependency/build cache for the stack (see the `--clean` option) before installing.
2. Run the install command from the table, teeing to the log:
   ```bash
   npm --prefix "$path" ci 2>&1 | tee -a "$LOG"
   ```
3. Capture the exit status (`${PIPESTATUS[0]}`, not `tee`'s). On non-zero, go to Failure Triage with stage `install`.

### Phase 3: Build (Bash)

1. If the stack has no build step (interpreted, no `build` script), record "build N/A" and skip to Phase 4.
2. Run the build command from the table, teeing to the log.
3. Capture `${PIPESTATUS[0]}`. On non-zero, classify (TypeScript `tsc` errors, Go compile errors, Java/Kotlin compilation, .NET build) and go to Failure Triage with stage `build`.

### Phase 4: Unit Test (Bash)

1. If `--no-test`: skip this phase; record "tests skipped (--no-test)" in the summary.
2. Run the unit-test command from the table, teeing to the log.
3. Capture `${PIPESTATUS[0]}`. On non-zero, go to Failure Triage with stage `unit-test`.

### Phase 5: Integration Test (Bash)

1. Only run when `--integration` is set and `--no-test` is not.
2. If the Docker daemon was unreachable in Phase 1, record "integration skipped (no Docker daemon)" and treat as N/A.
3. Run the integration command from the table, teeing to the log. If the stack has no integration suite/task, record "no integration suite" (N/A, not failure).
4. Capture `${PIPESTATUS[0]}`. On non-zero, go to Failure Triage with stage `integration-test`.

### Phase 6: Report (Bash)

Emit the Output Format summary. On full success, stop — no delegation.

## Failure Triage

Triggered only when a phase exits non-zero. Steps:

1. **Parse the first error** from the log. Search top-down for the first line matching the active toolchain's error format (e.g. `npm ERR!` / `ERESOLVE` for npm, `error TS####` for `tsc`, `cannot find package` / `undefined:` for Go, `BUILD FAILURE` / `[ERROR]` for Maven, `error CS####` for .NET, `FAIL` / `AssertionError` / `expected ... to ...` for tests, `Testcontainers` / `Could not pull image` / `connection refused` for container setup).
2. **Classify the stage:**

   | Symptom in log | Stage |
   |----------------|-------|
   | `ERESOLVE`, `npm ERR!`, `could not resolve dependency`, `go: cannot find module`, `Could not resolve dependencies` (Maven), `package not found`, lockfile mismatch, registry/auth `401`/`403` | `install` |
   | `tsc` `error TS####`, Go compile `undefined:`/`cannot use`, Java/Kotlin compilation error, `error CS####`, `Build FAILED` with no test phase reached | `build` |
   | `pytest` `FAILED`/`ERROR`, `vitest`/`jest` `✗`/`FAIL`, Go `--- FAIL`, JUnit `Tests run: ... Failures:`, RSpec failures, assertion/expectation mismatches with no container involved | `unit-test` |
   | `Testcontainers` startup errors, `Could not pull image`, `connection refused`/`timeout` to a DB/broker, migration failure inside a test container, integration-suite assertion failures | `integration-test` |

3. **Extract a tight excerpt** — the first error plus ~10 surrounding lines of context (the stack trace / failing assertion / dependency tree), not the whole log. Include the log path so the agent can read more if needed.
4. **Delegate to the matching stack developer** with the excerpt. Use the agent resolved in Phase 1.

   - Node failure (any stage):
     **Use Task tool with subagent_type="backend-developer:node-developer"**
     Prompt: "Build-test failed at the **{stage}** stage for the Node/TypeScript service at `{path}` (package manager: {pm}). First error and context from `{LOG}`:\n```\n{excerpt}\n```\nDiagnose the root cause and propose the minimal fix. If the fix touches dependencies, the build config (tsconfig/bundler), or a Testcontainers setup, say so explicitly. Do not re-run the full suite yourself; return the analysis and patch."
   - Go → **subagent_type="backend-developer:go-developer"** (same prompt shape).
   - JVM (Maven/Gradle) → **subagent_type="backend-developer:jvm-backend-developer"** (same prompt shape).
   - Python (`pyproject.toml`/`requirements.txt`/`uv.lock`) → **subagent_type="backend-developer:python-backend-developer"**
     Prompt: "Build-test failed at the **{stage}** stage for the Python service at `{path}` (uv). First error and context from `{LOG}`:\n```\n{excerpt}\n```\nDiagnose and propose the minimal fix (dependency resolution, import error, failing test, or Testcontainers setup). Return analysis and patch; do not re-run the suite."
   - Ruby (`Gemfile`) → **subagent_type="backend-developer:ruby-developer"** (same prompt shape).
   - PHP (`composer.json`) → **subagent_type="backend-developer:php-developer"** (same prompt shape).
   - .NET (`*.csproj`/`*.sln`) → **subagent_type="backend-developer:dotnet-developer"** (same prompt shape).
   - Ambiguous stack → **subagent_type="backend-developer:backend-developer"** (router) with the excerpt and detected markers.

5. After the agent returns a fix, re-run from the failing phase (re-install if the fix touched dependency manifests, otherwise rebuild/retest). Do NOT auto-apply across multiple iterations silently — report each cycle.

## Tool Availability

Before running each stack, confirm its tool exists. If missing, print the hint, skip the stack, continue down the priority list, and note the skip.

| Missing tool | Install hint |
|--------------|--------------|
| `node` / `npm` | `brew install node` (or use `fnm`/`nvm` to match the project's `.nvmrc`) |
| `pnpm` | `corepack enable pnpm` (or `npm i -g pnpm`) |
| `yarn` | `corepack enable` (Yarn Berry ships via Corepack) |
| `go` | `brew install go` (match the `go.mod` `go` directive) |
| `mvn` / `gradle` | `brew install maven gradle` (or use the project's `./mvnw`/`./gradlew` wrapper) |
| `uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` (verify against your toolchain) |
| `bundle` (Ruby) | `gem install bundler` (match `.ruby-version`) |
| `composer` (PHP) | `brew install composer` |
| `dotnet` | `brew install --cask dotnet-sdk` (match `global.json`) |
| `docker` (for `--integration`) | `brew install --cask docker` and start the daemon; integration phase is skipped if unreachable |

Never hard-fail on a missing tool — skip and report.

## Output Format

```markdown
## Build & Test Report

**Target:** {path}
**Stack:** {stack} ({marker}, {package manager if applicable})
**Owning agent:** {node | go | jvm-backend | python-backend | ruby | php | dotnet}
**Log:** .context/logs/build-{timestamp}.log

| Phase | Result | Notes |
|-------|--------|-------|
| Install | ✅ / ❌ / ⏭ skipped | {lockfile path used, or fallback reason} |
| Build | ✅ / ❌ / N/A | {no build step / errors} |
| Unit Test | ✅ / ❌ / ⏭ | {N passed, M failed, or "--no-test"} |
| Integration Test | ✅ / ❌ / N/A / ⏭ | {Testcontainers result, "no Docker daemon", or "not requested"} |

**Result:** PASS / FAIL ({failing stage})

<!-- On failure only: -->
### Failure Triage
- **Stage:** {install | build | unit-test | integration-test}
- **First error:** {one-line summary}
- **Delegated to:** backend-developer:{agent}
- **Proposed fix:** {summary from agent, or "see agent output"}

<!-- On skipped systems only: -->
### Skipped
- {stack / phase}: {missing tool or no Docker daemon} — install hint printed above.
```

## Error Handling

### Path not found
```
Error: Path not found: {path}
Suggestion: Pass a directory that exists, e.g. /backend-developer:build-test .
```

### No recognized back-end stack
```
Error: No back-end stack detected under {path}.
Looked for: package.json (with a server dep), go.mod, pom.xml/build.gradle,
pyproject.toml/requirements.txt/uv.lock, Gemfile, composer.json, *.csproj/*.sln.
Suggestion: Run from the directory that holds the manifest, or scaffold one.
```

### No test target
Not an error. Report "no test script/target found — build succeeded, tests skipped" and treat the run as PASS for build, N/A for test.

### No integration suite (when `--integration` given)
```
Note: --integration requested but no integration suite/task found for {stack}.
Ran unit tests only. Add a test:integration script / integrationTest task / -m integration
suite to enable Testcontainers-backed runs.
```

### Docker daemon unreachable (when `--integration` given)
```
Warning: --integration requires a running Docker daemon, which is unreachable.
Ran unit tests only; integration phase skipped (N/A, not failed).
Start Docker and re-run with --integration.
```

### --no-test with --integration
```
Warning: --no-test overrides --integration; skipping all tests.
```

### Toolchain missing
Print the install hint from Tool Availability, skip the stack, continue. Only when *every* eligible stack is skipped does the command report FAIL with the aggregated install hints.

## See Also

- `skill: stack-detection` — canonical marker → runtime → agent routing (keep the priority table in sync).
- `skills/_shared/version-feature-matrix.md` — canonical runtime/framework version lookup for behaviour that differs by version.
- `/backend-developer:fix-quick` — run linters/formatters/type-checks before building to cut noise.
- `/backend-developer:gen-tests` — add a test suite (unit or Testcontainers integration) when detection finds no test target.
- `/backend-developer:deps` — when an `install`-stage failure is a missing, outdated, or vulnerable dependency.
- `/backend-developer:security-review` — once the build is green, run the OWASP API Security Top 10 pass over it.
