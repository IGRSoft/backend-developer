---
name: code-modernize
description: Upgrade frameworks/runtimes one migration class at a time, gated on a green build + test run
argument-hint: "[path (default .)] [--target <framework@version>] [--dry-run]"
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 2000
  max-tokens: 20000
  model-distribution:
    haiku: 15%
    sonnet: 70%
    opus: 15%
---

# Code Modernize
<!-- Updated: June 2026 -->

Move a web/service back-end to a newer framework or runtime incrementally and safely. Modernization is sequenced as a ledger of discrete *migration classes* (e.g. "CommonJS -> ESM", "javax -> jakarta", "Express -> Fastify route adapters", "Django settings sweep"), and every class is verified by a full build + test run before its commit and before the next class begins. Mechanical rewrites are delegated to `backend-developer:be-code-fixer`; semantic migrations that need judgment go to the owning language developer (`backend-developer:node-developer`, `backend-developer:jvm-backend-developer`, `backend-developer:python-backend-developer`, `backend-developer:go-developer`, `backend-developer:dotnet-developer`, ...).

[Extended thinking: A framework or runtime upgrade is dozens of independent transforms with sharply different risk. Doing them all at once produces an un-reviewable diff and a service that is either green or broken with no way to bisect which transform broke it. This command instead builds an ordered ledger at `.context/.modernize/plan.md`, then walks it class by class — mechanical (codemods, `npx @next/codemod`, `ruff --select UP`, OpenRewrite recipes) first, then semantic (router adapters, transaction-boundary rewrites, deprecated-API sweeps) — running `/backend-developer:build-test` after each class and committing one class per commit. Crucially, for major-version jumps it never skips a major: Spring Boot 2 modernizes to 3 (javax -> jakarta) as one ordered jump, not interleaved with a later 3.x feature pass; Node 18 -> 20 -> 22 walks one LTS at a time. `--dry-run` produces the ledger and stops, so you can review the plan before any edit. Mechanical-vs-semantic routing keeps cheap deterministic codemods on haiku via the code-fixer and reserves the language developer for the rewrites that change shape, not just spelling. Evidence is API request/response transcripts, test output, and migration logs — never build-warning noise.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **One major jump at a time.** `--target spring-boot@3.4` on a Spring Boot 2.7 project means **2.7 -> 3.0 (javax -> jakarta, the breaking jump), then 3.0 -> 3.4** — ordered passes, each fully verified and committed before the next. Never skip a breaking major (never 2.7 -> 3.4 directly). Detect the current framework/runtime version first (see Inventory) and refuse to jump across a breaking major without first completing the intermediate landing.
2. **One migration class per commit.** Each ledger row is applied, verified, and committed on its own. Never batch unrelated classes into one diff. The commit subject names the class (e.g. `refactor: migrate javax.* imports to jakarta.* (Spring Boot 3)`).
3. **Verify after every class.** After applying a class, run `/backend-developer:build-test` (build + unit + integration tests). If it is not green, the class is NOT committed — revert or fix before moving on. A red run halts the migration; report it and stop.
4. **`--dry-run` produces the ledger only.** In `--dry-run`, write `.context/.modernize/plan.md` and stop. Make ZERO source edits and ZERO commits. This is the review-the-plan mode.
5. **Mechanical vs semantic routing.** Pure mechanical rewrites (framework codemods, `npx @next/codemod`, `ruff check --select UP --fix`, OpenRewrite recipe runs, automated `jakarta` import rewrites, `gofmt`/`go fix`) delegate to `backend-developer:be-code-fixer`. Rewrites needing judgment (CommonJS `require`/`module.exports` -> ESM `import`/`export` where module boundaries must be re-cut, Express middleware -> Fastify plugin lifecycle, Django middleware/settings re-shaping, callback -> async/await, transaction-boundary or repository rewrites under an ORM major) delegate to the owning language developer. Never hand a semantic migration to the code-fixer.
6. **Gate features on the runtime, not the calendar.** Before adopting a framework/runtime feature, confirm the project's runtime/SDK supports it (see `skill: version-feature-matrix`). Prefer capability checks (engine pins in `package.json` `engines`, `<java.version>`, `requires-python`, `<TargetFramework>`) over guesswork. If the runtime cannot guarantee the target, report the gap and stop — do not write code the runtime cannot execute.
7. **Single-command Bash invocations.** Use each tool's own path/recursion flags. Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands.
8. **Tool-missing never hard-fails.** If a required tool is absent, print the install hint, skip that class (or language), and continue. Report what was skipped.
9. **Never enter plan mode.** This command IS the procedure — execute it (or, with `--dry-run`, produce the ledger and stop).

## Usage

```bash
# Preview the Spring Boot 3 migration ledger without touching any source
/backend-developer:code-modernize . --target spring-boot@3.4 --dry-run

# Migrate a Spring Boot 2.7 service to 3.0 (the javax -> jakarta jump)
/backend-developer:code-modernize src/main/java --target spring-boot@3.0

# Move a Node service from CommonJS to ESM on the Node 22 runtime
/backend-developer:code-modernize . --target node@22

# Bump a FastAPI / Django project to a newer Python + framework line
/backend-developer:code-modernize . --target django@5.2

# Roll a .NET service to the current LTS
/backend-developer:code-modernize src/ --target dotnet@10.0
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path` | `.` | Directory or file to modernize. Inventory and detection are rooted here. |
| `--target <framework@version>` | required | The destination framework/runtime and version (e.g. `spring-boot@4.0`, `node@22`, `nestjs@11`, `fastify@5`, `django@5.2`, `fastapi@0.136`, `rails@8`, `laravel@11`, `dotnet@10.0`, `go@1.26`). For a breaking major, the command auto-inserts the intermediate landing if the source is more than one major below the target. Pin services to an LTS line (e.g. .NET `10.0`, not the `9.0` STS). |
| `--dry-run` | off | Produce `.context/.modernize/plan.md` (the migration ledger) and stop. No edits, no commits. |

`--target` is required — there is no default, because the right destination depends on the deployment runtime and the rest of the platform (managed runtime version, base image, hosting tier). The destination is named as `framework@version` (or `runtime@version` for a pure runtime bump like `node@22` / `go@1.23`).

## Inventory

Before building the ledger, establish the *current* framework/runtime version so the jump count is correct.

| Stack | Where the current version lives | Read |
|-------|----------------------------------|------|
| Node / TypeScript | `dependencies`/`devDependencies` + `engines.node` in `package.json`; `"type"` field (`commonjs` vs `module`); `tsconfig.json` `module`/`target`/`moduleResolution`; framework pin (`express`, `@nestjs/core`, `fastify`, `hono`) | the pinned framework version + module system |
| Java / Kotlin | `spring-boot-starter-parent` `<version>` or the Spring Boot plugin version in `pom.xml`/`build.gradle`; `<java.version>` / `sourceCompatibility`; `javax.*` vs `jakarta.*` imports | the Spring Boot line + JDK + namespace |
| Python | `requires-python` in `pyproject.toml`; pinned `django`/`fastapi`/`flask` version; `from __future__` usage | the framework version + Python floor |
| Go | `go` directive + module requires in `go.mod`; router pin (`gin`, `echo`, `chi`) | the Go toolchain line + framework version |
| Ruby | `ruby` directive in `Gemfile`/`.ruby-version`; `rails` pin in `Gemfile.lock` | the Rails line + Ruby version |
| PHP | `require.php` + `laravel/framework` / `symfony/*` in `composer.json` | the framework line + PHP floor |
| .NET | `<TargetFramework>` in the `.csproj`; ASP.NET Core / EF Core package versions | the TFM + framework versions |

The marker -> stack map is canonical in `skill: language-detection` — detect **per service/subtree** for monorepos, do not fork the routing logic. Use `skill: version-feature-matrix` to translate the detected current version and `--target` into the required runtime/SDK floor and the per-jump migration set.

**One-major enforcement (e.g. Spring Boot):** if current is 2.7 and `--target spring-boot@3.4`, the ledger contains two sections — *Jump 1: 2.7 -> 3.0 (javax -> jakarta)* and *Jump 2: 3.0 -> 3.4* — and the workflow completes Jump 1 (all classes built, tested, committed) before opening Jump 2. The same applies to Node LTS hops (18 -> 20 -> 22) and ORM majors. If current already meets or exceeds `--target`, report "already at or above target" and stop.

## The Migration Ledger

The inventory's output is `.context/.modernize/plan.md`: an ordered checklist of migration classes, mechanical-first within each jump. Template:

```markdown
# Modernization Ledger
Target: {framework@version} | Current: {detected} | Path: {path}
Runtime gate: {runtime/SDK + min version from version-feature-matrix} — {PASS | GAP: ...}

## Jump 1: {from} -> {to}
| # | Migration class | Kind | Owner | Status |
|---|-----------------|------|-------|--------|
| 1 | javax.* -> jakarta.* import rewrite | mechanical | be-code-fixer | pending |
| 2 | deprecated WebSecurityConfigurerAdapter -> SecurityFilterChain bean | semantic | jvm-backend-developer | pending |
| 3 | Hibernate 5 -> 6 query/dialect sweep | semantic | jvm-backend-developer | pending |
| ... | ... | ... | ... | ... |

## Jump 2: {from} -> {to}   <!-- only when target is >1 major above current -->
| # | Migration class | Kind | Owner | Status |
| ... |
```

Status transitions per row: `pending -> applied -> verified -> committed` (or `reverted` on a red run). The ledger is the source of truth across resumes — read it, do not rely on context-window memory.

## Per-Target Playbooks

Each playbook is an ordered list of migration classes. Mechanical classes lead (cheap, deterministic, low-risk); semantic classes follow. Every feature/behavior claim carries a version marker and a fallback row from `skill: version-feature-matrix`.

### `--target node@22` / CommonJS -> ESM (Node / TypeScript)

Runtime gate: confirm `engines.node` allows 22 and the hosting tier ships Node 22 (verify against your platform) per `skill: version-feature-matrix`. Gate ESM-only deps and `node:` import prefixes on the resolved runtime.

| Order | Class | Kind | Notes |
|-------|-------|------|-------|
| 1 | bump `engines.node` + `@types/node` + lockfile refresh | mechanical | `npm i -D @types/node@22`, set `engines.node: ">=22"`. Delegate to `be-code-fixer`. |
| 2 | `tsc` / lint mechanical autofixes for the new target | mechanical | `tsc --noEmit` baseline, ESLint `--fix`. Delegate to `be-code-fixer`. |
| 3 | `require`/`module.exports` -> **ESM `import`/`export`** | semantic | Set `"type": "module"` + `tsconfig` `module: nodenext`; re-cut barrel files, fix `__dirname`/`__filename` (`import.meta.url`), add explicit extensions. Route to `node-developer`. |
| 4 | callbacks / `util.promisify` -> **async/await** | semantic | Convert leftover callback APIs and `.then` chains; ensure error propagation through `await`. Route to `node-developer`. |
| 5 | deprecated-API sweep (`url.parse`, legacy `Buffer()`, `domain`) | semantic | Replace per the Node 22 deprecation list (verify against your toolchain). Route to `node-developer`. |

### `--target fastify@5` (from Express)

Runtime gate: Fastify 5 needs Node 20+ (verify) per `skill: version-feature-matrix`. Plan a parallel-run window — the router rewrite is the high-risk class.

| Order | Class | Kind | Notes |
|-------|-------|------|-------|
| 1 | add Fastify + plugin deps; lockfile refresh | mechanical | `npm i fastify @fastify/cors @fastify/helmet`. Delegate to `be-code-fixer`. |
| 2 | Express middleware -> **Fastify plugin lifecycle** | semantic | `app.use` -> `register`; rework `req`/`res` -> `request`/`reply`; map `next(err)` to thrown errors + error handler. Preserve route paths and status codes; verify with curl transcripts. Route to `node-developer`. |
| 3 | body parsing / validation -> **schema-based** | semantic | Replace `body-parser` + ad-hoc checks with JSON Schema route validation; keep response contracts identical. Route to `node-developer`. |
| 4 | error handler + 404 -> **`setErrorHandler`/`setNotFoundHandler`** | semantic | Centralize; ensure the error envelope shape is unchanged. Route to `node-developer`. |

### `--target spring-boot@3.x` / `spring-boot@4.x` (from Spring Boot 2 or 3)

Runtime gate: Spring Boot 3 requires **JDK 17+** and the **jakarta.\*** namespace; Spring Boot 4 (current line, on Spring Framework 7 / Jakarta EE 11) also baselines JDK 17 but is first-class on a newer LTS (verify GA versions and the JDK floor against your toolchain) per `skill: version-feature-matrix`. The 2.x -> 3.0 jump is the breaking one (`javax` -> `jakarta`); the 3.x -> 4.x jump is a separate Jump driven by default-shifts (Jackson 2 -> 3, JSpecify null-safety, modularized starters). Walk one major at a time — a Boot 2.7 -> 4.x target lands on 3.x first, then 4.x.

**Jump A — Boot 2.x -> 3.0 (the `javax` -> `jakarta` breaking landing):**

| Order | Class | Kind | Notes |
|-------|-------|------|-------|
| 1 | bump `<java.version>` to 17+; Boot parent -> 3.0; OpenRewrite `UpgradeSpringBoot_3_0` dry pass | mechanical | Run the recipe, refresh the dependency BOM. Delegate to `be-code-fixer`. |
| 2 | `javax.*` -> **`jakarta.*`** imports (persistence, validation, servlet) | mechanical | Bulk import rewrite via OpenRewrite / codemod. Delegate to `be-code-fixer`. |
| 3 | `WebSecurityConfigurerAdapter` -> **`SecurityFilterChain` bean** | semantic | The adapter is removed; re-express the security config as component beans. Verify auth boundaries with request transcripts (401/403 paths). Route to `jvm-backend-developer`. |
| 4 | Hibernate 5 -> **6** dialect/query sweep | semantic | Single auto-detected dialect, removed legacy types, `@GeneratedValue` defaults; watch N+1 and transaction boundaries. Route to `jvm-backend-developer`. |
| 5 | `spring.factories` -> **`AutoConfiguration.imports`** | mechanical-ish | Move auto-config registration to the new file. Delegate to `be-code-fixer`. |

**Jump B — Boot 3.x -> 4.x (current line, only when `--target` is `spring-boot@4.x`; a separate Jump after Jump A is `committed`):**

| Order | Class | Kind | Notes |
|-------|-------|------|-------|
| 1 | bump Boot parent -> 4.0; OpenRewrite `UpgradeSpringBoot_4_0` dry pass; refresh modularized-starter coordinates | mechanical | The starter jars were split/renamed; let the recipe remap coordinates + the BOM. Delegate to `be-code-fixer`. |
| 2 | Jackson 2 -> **3** default mapper sweep | semantic | Boot 4 ships Jackson 3 as the default; a Jackson 2 module remains for un-migrated libs. Re-check custom `ObjectMapper` config, serializers, and the JSON envelope shape with request/response transcripts. Route to `jvm-backend-developer`. |
| 3 | Hibernate 6 -> **7** sweep (Jakarta Persistence 3.2) | semantic | Boot 4 ships Hibernate 7 (JPA 3.2 / Jakarta EE 11): removed deprecated APIs, Entity Graph API changes; re-check N+1, fetch strategies, and transaction boundaries. Keep the Hibernate floor aligned with `skill: version-feature-matrix`. Route to `jvm-backend-developer`. |
| 4 | JSpecify null-safety + API-versioning / HTTP Service Client adoption | semantic | Adopt where it adds value (not blocking) — annotate nullability, optionally move to first-class API versioning / `@ImportHttpServices`. Keep the public contract identical. Route to `jvm-backend-developer`. |

### `--target django@5.x` / `fastapi@0.1xx` (Python web)

Runtime gate: `requires-python` must allow the target's Python floor (Django 5.x needs Python 3.10+; current FastAPI requires Pydantic v2, verify) — otherwise raise the floor first. Per `skill: version-feature-matrix`.

| Order | Class | Kind | Notes |
|-------|-------|------|-------|
| 1 | `ruff check --select UP --fix` + dependency bump | mechanical | `pyupgrade` idioms + pin Django/FastAPI to target. Delegate to `be-code-fixer`. |
| 2 | settings / `urls.py` deprecation sweep | semantic | Remove `USE_L10N`, update `STORAGES`, `url()` -> `re_path()`/`path()`, async-view readiness. Verify against the target "Release notes". Route to `python-backend-developer`. |
| 3 | ORM / migration sweep | semantic | Regenerate and review migrations; check `on_delete`, index changes, and N+1 under the new ORM defaults. Verify migration logs are clean. Route to `python-backend-developer`. |
| 4 | FastAPI: Pydantic v1 -> **v2** models | semantic | **Mandatory for a current FastAPI bump** — FastAPI dropped Pydantic v1 (the `pydantic.v1` shim is a temporary stopgap, not a destination), so this class gates the FastAPI upgrade, not an optional polish. `BaseSettings` -> `pydantic-settings`, validators -> `field_validator`/`model_validator`, `Config` -> `model_config`. Keep response schemas identical. Route to `python-backend-developer`. |

### `--target dotnet@10.0` / `go@1.26` (runtime bumps)

Runtime gate: confirm the SDK / toolchain and base image ship the target (`<TargetFramework>net10.0`, `go 1.26` in `go.mod`) per `skill: version-feature-matrix`. Pin .NET service code to the current LTS (.NET 10) — an STS line (.NET 9) is not a service-code baseline; the matrix holds the live LTS/STS floors.

| Order | Class | Kind | Notes |
|-------|-------|------|-------|
| 1 (.NET) | bump `<TargetFramework>` + package versions; `dotnet format` | mechanical | Refresh ASP.NET Core / EF Core pins. Delegate to `be-code-fixer`. |
| 2 (.NET) | minimal-API / nullable-reference / removed-API sweep | semantic | Address breaking changes in the target's migration guide; keep endpoint contracts stable. Route to `dotnet-developer`. |
| 1 (Go) | bump `go` directive; `go fix` + `gofmt -w`; golangci-lint v1->v2 config migration | mechanical | Update `go.mod`, run `go mod tidy`; if a v1 `.golangci.yml` is present, run `golangci-lint migrate` (v2 renamed `enable-all`/`disable-all` -> `linters.default`, moved exclusions, split `golangci-lint fmt`). Delegate to `be-code-fixer`. |
| 2 (Go) | remove obsolete loopvar capture shims / deprecated stdlib sweep | semantic | Remove now-obsolete `x := x` per-iteration loop captures — loopvar is baseline on every supported toolchain (Go 1.22+), so the shims are dead code, not a migration target; replace deprecated stdlib calls. Verify with `go vet`. Route to `go-developer`. |

> Ruby (Rails) and PHP (Laravel/Symfony) follow the same shape: bump the framework pin + run the official upgrade codemod (mechanical), then sweep deprecated APIs / config and rework breaking framework hooks (semantic), routing to `backend-developer:ruby-developer` / `backend-developer:php-developer`. See `skill: version-feature-matrix` for each line's floor and fallback rows.

## Workflow

### Phase 1: Inventory & Ledger (Bash + Read)

1. Confirm `path` exists; if not, emit the Error Handling "path not found" message and stop.
2. Validate `--target` parses as `framework@version` (or `runtime@version`); if missing/invalid, emit the "missing target" message and stop.
3. Detect the current framework/runtime version per the Inventory table (read `package.json`/`engines`, `pom.xml`/`build.gradle`, `pyproject.toml`, `go.mod`, `Gemfile`, `composer.json`, `.csproj`). Resolve the runtime gate via `skill: version-feature-matrix`. If the gate is a GAP (runtime/SDK cannot reach `--target`), report it and stop (Rule 6).
4. If current already meets/exceeds `--target`, report "already at or above target" and stop.
5. If `--target` is more than one breaking major above current, split the ledger into ordered Jumps (Rule 1).
6. Write `.context/.modernize/plan.md` from the matching playbook(s), all rows `pending`.
7. **If `--dry-run`: stop here.** Report the ledger path and the planned classes. Make no edits, no commits.

### Phase 2: Apply Classes In Order (delegated)

Walk the ledger top-down, one row at a time. For each `pending` row:

1. **Mark `applied`** in the ledger as you start it.
2. **Delegate by kind:**
   - **mechanical** ->
     **Use Task tool with subagent_type="backend-developer:be-code-fixer"**
     Prompt: "Apply ONLY the migration class **{class}** for `{path}` (target {framework@version}, jump {from}->{to}). Run the exact mechanical transform: {e.g. OpenRewrite `UpgradeSpringBoot_3_0` recipe / javax->jakarta import rewrite / `ruff check --select UP --fix {path}` / `npx @next/codemod {recipe} {path}` / `go fix ./... && gofmt -w {path}`}. Do NOT apply any other class. Make minimal, deterministic edits. Report every file and rule/recipe touched. Do not run the test suite."
   - **semantic** ->
     **Use Task tool with subagent_type="backend-developer:<owning-language-developer>"** (`node-developer` / `jvm-backend-developer` / `python-backend-developer` / `go-developer` / `dotnet-developer` / `ruby-developer` / `php-developer`)
     Prompt: "Perform ONLY the migration class **{class}** for `{path}` ({from}->{to}). {e.g. Re-express WebSecurityConfigurerAdapter as a SecurityFilterChain bean / convert Express middleware to Fastify plugin lifecycle preserving routes and status codes / migrate Pydantic v1 models to v2 keeping response schemas identical}. Preserve the public API contract (paths, status codes, response envelopes), transaction boundaries, idempotency, and auth boundaries. Gate any adopted feature on the project runtime/SDK; if a feature is unavailable, keep the fallback and report it. Do not touch other classes. Return the diff and a short contract-impact note (with curl request/response transcripts where behavior could drift)."
3. **Mark `verified`** only after the build+test gate (Phase 3) is green for this class.

### Phase 3: Verify After Every Class (per class)

After each applied class, run the build + test gate by invoking the project's canonical sequence (the same one `/backend-developer:build-test` resolves):

1. Run `/backend-developer:build-test {path}` (or equivalently its detected install/build/test commands — `npm ci && npm test`, `mvn -q verify`, `uv run pytest`, `go test ./...`, `dotnet test`, including Testcontainers-backed integration tests). Tee output to `.context/logs/`.
2. **Green** -> mark the row `verified`, proceed to commit (Phase 4).
3. **Red** -> the class did NOT pass:
   - For a mechanical class, revert it (the fix-agent's diff) and report — mechanical codemods should never break a green build; a red one is a real signal.
   - For a semantic class, hand the failing build/test excerpt (and any failing API transcript) back to the same language agent for a corrective pass (bounded — one corrective cycle, then stop and report).
   - If still red, **halt the run**, mark the row `reverted`, and report (Rule 3). Do not proceed to later classes on a broken build.

### Phase 4: Commit One Class Per Migration (per class)

After a class is `verified`:

1. Stage only the files that class touched.
2. Commit with a conventional subject naming the class, e.g.:
   - `refactor: migrate javax.* imports to jakarta.* (Spring Boot 3)`
   - `refactor: replace WebSecurityConfigurerAdapter with SecurityFilterChain (Spring Boot 3)`
   - `refactor: convert CommonJS modules to ESM (Node 22)`
   - `refactor: migrate Pydantic v1 models to v2 (FastAPI)`
3. Mark the row `committed` in the ledger.
4. Move to the next `pending` row. When a Jump's rows are all `committed`, open the next Jump (multi-major upgrades only).

> Per the user's git conventions: no `--no-verify`, no AI-attribution footers, and follow the repo's commit format. If the repo is mid-feature on a protected branch, branch first.

### Phase 5: Report

Emit the Output Format. Summarize classes applied/verified/committed/skipped per Jump, and the ledger path for the audit trail.

## Tool Availability

Confirm each class's tool before delegating. Missing -> print the hint, skip that class, continue, and note the skip in the ledger and report.

| Missing tool | Install hint |
|--------------|--------------|
| `node` / `npm` / `pnpm` (Node build+test gate, codemods) | install Node LTS via your version manager (`nvm install 22`) or `brew install node` |
| `tsc` (TypeScript baseline) | `npm i -D typescript` (project-local) |
| Java + Maven/Gradle (JVM build+test gate, OpenRewrite) | `brew install openjdk maven gradle` |
| `uv` / `ruff` (Python build+test gate + UP pass) | `curl -LsSf https://astral.sh/uv/install.sh \| sh` then `uv tool install ruff` (verify against your toolchain) |
| `go` (Go build+test+vet gate) | `brew install go` |
| `dotnet` SDK (.NET build+test gate) | install the .NET SDK from your platform package or `brew install dotnet-sdk` |
| `docker` (Testcontainers integration tests) | install Docker Desktop / Colima and ensure the daemon is running |

Exact flag spellings and recipe ids vary across tool releases — verify against your toolchain when a flag or recipe is rejected. Never hard-fail on a missing tool: print the hint, skip the class/language, continue, and report the skip.

## Output Format

```markdown
## Code Modernization Report

**Target:** {framework@version}
**Current version:** {detected}
**Path:** {path}
**Mode:** dry-run | apply
**Ledger:** .context/.modernize/plan.md
**Runtime gate:** {runtime/SDK + min version} — {PASS | GAP}

<!-- dry-run: stop after the ledger -->
### Planned Migration Classes ({count})
{rendered ledger table(s), all rows pending}

<!-- apply mode -->
### Jump 1: {from} -> {to}
| # | Class | Kind | Owner | Status | Commit |
|---|-------|------|-------|--------|--------|
| 1 | javax.* -> jakarta.* | mechanical | be-code-fixer | committed | {sha/subject} |
| 2 | SecurityFilterChain bean | semantic | jvm-backend-developer | committed | {sha/subject} |
| 3 | Hibernate 5 -> 6 sweep | semantic | jvm-backend-developer | reverted | (tests red) |

<!-- Jump 2 only when target > 1 major above current -->
### Jump 2: {from} -> {to}
| ... |

**Result:** COMPLETE / PARTIAL / HALTED ({reason})
- Classes committed: {n} | verified-not-committed: {n} | reverted: {n} | skipped (tool missing): {n}

<!-- on a halt -->
### Halt
- **Class:** {class} ({jump})
- **Build/test:** RED — {one-line first failure; full log + any failing API transcript in .context/logs/...}
- **Action:** row marked reverted; later classes not attempted.

<!-- on skipped classes/tools -->
### Skipped
- {class}: {missing tool} — install hint printed above.
```

## Error Handling

### Path not found
```
Error: Path not found: {path}
Suggestion: Pass a directory or file that exists, e.g. /backend-developer:code-modernize . --target spring-boot@3.0 --dry-run
```

### Missing or invalid --target
```
Error: --target is required and must be <framework@version> (or <runtime@version>),
e.g. spring-boot@4.0, node@22, fastify@5, django@5.2, dotnet@10.0, go@1.26.
Suggestion: /backend-developer:code-modernize . --target spring-boot@3.4 --dry-run
```

### More than one breaking major requested
Not an error — the command auto-inserts the intermediate landing (Spring Boot 2.7 + `--target spring-boot@3.4` -> two ordered Jumps: 2.7 -> 3.0, then 3.0 -> 3.4). It will complete Jump 1 (built, tested, committed) before opening Jump 2 (Rule 1).

### Already at or above target
```
Note: {path} is already at or above {target} (detected: {current}).
Nothing to modernize. Suggestion: target a higher version or a different path.
```

### Runtime gate failure
```
Error: Runtime/SDK cannot guarantee {target}.
{runtime/SDK} {detected version} < required {min version}
(see skill: version-feature-matrix).
Suggestion: upgrade the runtime / base image / hosting tier, or modernize to the
highest supported version.
```
Stop — do not write code the runtime cannot execute (Rule 6).

### Build/tests red after a class
Halt the run (Rule 3). Mark the row `reverted`, report the first failure, the log path, and any failing API request/response transcript, and do NOT attempt later classes. For a semantic class, one bounded corrective cycle with the owning agent is allowed before the halt.

### Tool missing
Print the install hint from Tool Availability, skip the class (or language), continue, and note the skip. Only when no class can run does the command report HALTED with aggregated hints.

## See Also

- `skill: version-feature-matrix` — canonical framework/runtime -> minimum-floor + feature/fallback tables (gate every adopted feature here).
- `skill: language-detection` — marker -> stack -> agent routing (keep per-service detection in sync).
- `/backend-developer:build-test` — the build + test gate (unit + Testcontainers integration) run after every migration class.
- `/backend-developer:lint-fix` — the shallow mechanical pass (codemods, `ruff --select UP`, formatters) for a single stack; this command sequences those plus semantic migrations across version jumps.
- `/backend-developer:code-review` — review the modernized diff for contract drift, transaction correctness, N+1 regressions, and auth-boundary changes once the ledger is complete.
- `/backend-developer:deps-audit` — the dependency side of an upgrade (outdated report, CVE lookup, one-at-a-time bumps); pair it with this command when a major framework jump pulls transitive majors.
