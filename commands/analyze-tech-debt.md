---
description: Identify, quantify, and prioritize back-end technical debt into a P0-P3 remediation ledger
argument-hint: [path, service, or repo scope] [--focus arch|data|api|test|deps|ops] [--top N] [--ledger-only]
allowed-tools: Read, Glob, Grep, Bash(git log:*), Bash(git diff:*), Bash(git shortlog:*), WebSearch, WebFetch
estimated-cost:
  min-tokens: 6000
  max-tokens: 30000
  model-distribution:
    haiku: 15%
    sonnet: 55%
    opus: 30%
---

# Technical Debt Analysis and Remediation Ledger

Inventory the technical debt in a back-end codebase, quantify each item with a principal/interest model, and emit one prioritized remediation ledger (P0-P3) with a payback estimate per item. Covers service-boundary erosion, God services, transaction-boundary gaps, query and index debt, ORM leakage into the domain, untested critical paths, dead endpoints, unversioned or breaking API contracts, outdated runtimes and frameworks, duplicated cross-service logic, config sprawl, and observability gaps. This command is **read-only** — it reports and ranks; it never remediates.

[Extended thinking: "Technical debt" is only actionable when it carries a number. A God `OrderService` that four teams touch weekly costs something different from an unindexed report query that runs twice a month, and both are different from a Spring Boot version that leaves security support in nine weeks. So the analysis runs in two beats. First a fan-out of read-only probes — architecture, data, API contract, tests, dependencies — each returning concrete, located findings rather than adjectives. Then a single quantification pass that assigns every finding a *principal* (engineering days to repay) and an *interest* (recurring monthly cost in dropped velocity, incident exposure, on-call load, or infrastructure spend), computes payback and a compounding flag, and ranks by interest rate rather than by how loud the finding sounds. Two failure modes to avoid: padding the ledger with style nits so it looks thorough, and quoting confident dollar figures from thin evidence. Every number here is an estimate with a stated basis, and an item with no observable interest belongs in P3 or not in the ledger at all. Remediation is a separate, explicitly-invoked act — this command hands the ledger to `/backend-developer:fix-refactor` and `/backend-developer:fix-modernize`, it does not edit.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Never edit anything.** This command and every probe it launches are read-only. No file writes, no migrations, no dependency bumps, no "while I was there" fixes. Remediation is out of scope and escalates to `/backend-developer:fix-refactor` or `/backend-developer:fix-modernize`.
2. **Resolve the scope once.** Apply the scope precedence below exactly once, print the concrete service/directory/file list, and hand that same list to every probe. Probes do NOT re-scope independently.
3. **Every finding is located and evidenced.** A ledger row without `file:line` (or a concrete artifact — endpoint path, table name, migration id, manifest entry) is not a finding. Do NOT report "the service layer is coupled" without naming the coupling.
4. **Quantify before you rank.** Each surviving finding gets `principal` (eng-days to repay), `interest` (recurring monthly cost), `basis` (what the estimate is derived from), and a `compounding` flag. Rank by interest rate (`interest / principal`), not by category or by severity label alone.
5. **State the basis, never fake precision.** Estimates derived from git churn, endpoint traffic assumptions, or coverage numbers must say so. If you have no observable signal, write `basis: judgement — low confidence` and drop the item's confidence, do NOT invent a dollar figure.
6. **No manufactured debt.** If a category is clean, say so in one line. Do NOT backfill P2/P3 rows to make the ledger look substantial. A short honest ledger beats a padded one.
7. **Severity comes from the matrix.** P0-P3 assignment follows `skills/_shared/severity-matrix.md` — do not invent a parallel scale.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Full debt analysis of the repository
/backend-developer:analyze-tech-debt

# Scope to one service or directory
/backend-developer:analyze-tech-debt services/orders/
/backend-developer:analyze-tech-debt src/billing/invoice-service.ts

# Focus a single debt dimension
/backend-developer:analyze-tech-debt --focus arch      # boundaries, God services, duplication
/backend-developer:analyze-tech-debt --focus data      # N+1, indexes, transactions, ORM leakage
/backend-developer:analyze-tech-debt --focus api       # contract versioning, dead endpoints
/backend-developer:analyze-tech-debt --focus test      # untested critical paths
/backend-developer:analyze-tech-debt --focus deps      # outdated runtimes and frameworks
/backend-developer:analyze-tech-debt --focus ops       # config sprawl, observability gaps

# Only the top 10 items by interest rate
/backend-developer:analyze-tech-debt --top 10

# Skip the narrative sections; emit the ledger table alone
/backend-developer:analyze-tech-debt services/ --ledger-only

# Combine: the ten worst data-layer items in one service
/backend-developer:analyze-tech-debt services/orders/ --focus data --top 10
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | whole repo | File, directory, or service to analyze. See Scope Resolution. |
| `--focus arch\|data\|api\|test\|deps\|ops` | all | Run only the named probe instead of the full fan-out. Repeatable conceptually (`--focus arch --focus data`). Use to keep a large-repo run affordable. |
| `--top N` | all | Emit only the N highest-interest-rate items in the ledger. The category summary still reports full counts. |
| `--ledger-only` | off | Suppress the narrative sections (theme summary, prevention notes); print the header, category summary, and ledger table only. |

## Scope Resolution

Resolve the analyzed set **once**, top-down — the first applicable rule wins:

1. **Explicit args** — a file, directory, or service path named on the command line. Analyze those paths.
2. **Service roots** (no args) — detect service roots from manifests (`package.json`, `go.mod`, `pom.xml`/`build.gradle`, `pyproject.toml`, `Gemfile`, `composer.json`, `*.csproj`) and analyze each detected root.
3. **Repository root** (fallback) — when no manifest is found, analyze the tracked source tree from the repo root.

Exclude vendored, generated, and build output from the set: `node_modules/`, `dist/`, `build/`, `target/`, `bin/`, `obj/`, `vendor/`, `.venv/`, generated client SDKs, and generated protobuf/OpenAPI stubs. Debt in generated code is debt in its generator — attribute it there.

Print the resolved list, the detected stacks, and the excluded paths **before** launching any probe.

## Stack Detection

Detect which runtimes are present using the canonical `skills/_shared/language-detection.md` table — do not fork its routing logic. Summary:

| Markers in scope | Stack | Debt probe specialist |
|------------------|-------|-----------------------|
| `.ts`, `.js`, `package.json`, `tsconfig.json` | Node/TypeScript | `backend-developer:node-developer` |
| `.go`, `go.mod` | Go | `backend-developer:go-developer` |
| `.java`, `.kt`, `pom.xml`, `build.gradle` | JVM/Spring | `backend-developer:jvm-backend-developer` |
| `.py`, `pyproject.toml` with FastAPI/Django/Flask | Python web | `backend-developer:python-backend-developer` |
| `.rb`, `Gemfile`, Rails layout | Ruby/Rails | `backend-developer:ruby-developer` |
| `.php`, `composer.json`, Laravel/Symfony layout | PHP | `backend-developer:php-developer` |
| `.cs`, `.csproj`, ASP.NET Core | .NET | `backend-developer:dotnet-developer` |

Stack specialists are consulted only for runtime-specific debt (deprecated framework idioms, EOL language features). The architecture, data, API, test, and dependency probes are stack-agnostic and always run.

## Debt Taxonomy

The probes look for these, and only these. Anything outside the taxonomy is out of scope for this command.

**Architecture debt**

| Item | Signal | Typical interest |
|------|--------|------------------|
| Service-boundary erosion | Cross-service DB reads, shared tables, imports across service roots | Every change needs coordinated deploys |
| God service / God module | One module owning many unrelated aggregates; high fan-in and churn together | Merge conflicts, serialized team throughput |
| Duplicated cross-service logic | The same pricing/tax/auth rule implemented in 2+ services | Divergent behavior, double-fix bugs |
| Missing transaction boundaries | Multi-write handlers with no transaction, or a transaction spanning a network call | Partial writes, reconciliation toil |
| Leaked domain into transport | HTTP/DTO types reaching the domain layer, or entities serialized straight to responses | Contract breaks on every model change |

**Data debt**

| Item | Signal | Typical interest |
|------|--------|------------------|
| N+1 query patterns | Loop-driven ORM access, missing eager loading, lazy associations in serialization | Latency and DB CPU that scale with rows |
| Unindexed hot queries | Filter/sort/join columns with no supporting index on a frequently-hit path | Table scans, timeouts under growth |
| ORM leakage into the domain | Entities/`Model`s used as domain objects, ORM types in service signatures, query building in controllers | Untestable domain, migration coupling |
| Unsafe or irreversible migrations | Destructive column drops without expand/contract, long-lock DDL, no down path | Deploy-window risk, rollback impossible |
| Schema drift | Nullable-everything columns, missing FKs/constraints, orphan tables | Data-integrity bugs found in production |

**API-contract debt**

| Item | Signal | Typical interest |
|------|--------|------------------|
| Unversioned contracts | No version segment/header, no deprecation policy | Every change is a coordinated client migration |
| Breaking changes shipped in place | Field removal/retype/semantic change on a live version | Client incidents, emergency rollbacks |
| Dead endpoints | Routes with no caller in the repo, no traffic assumption, no spec entry | Attack surface, false maintenance load |
| Spec drift | Handler shape diverged from the committed OpenAPI/GraphQL/proto artifact | Generated clients are wrong |
| Inconsistent error/pagination conventions | Mixed error envelopes, ad-hoc paging per endpoint | Per-endpoint client special-casing |

**Test debt**

| Item | Signal | Typical interest |
|------|--------|------------------|
| Untested critical paths | Payment/auth/tenancy/data-writing paths with no covering test | Every change to them is a gamble |
| Integration-test gap | Unit-only coverage over DB, queue, and HTTP boundaries | Bugs escape to staging or prod |
| Flaky/quarantined tests | Skipped, retried, or time-dependent tests | Signal loss; the suite stops being a gate |

**Dependency and runtime debt**

| Item | Signal | Typical interest |
|------|--------|------------------|
| Outdated runtime | Language/runtime near or past EOL | Hard deadline; security support cliff |
| Outdated framework | Major versions behind; upgrade path lengthening | Upgrade cost compounds each release |
| Deprecated framework idioms | Sunset APIs still in use on the request path | Blocks the next major upgrade |
| Unpatched advisories | Known CVEs in the resolved lockfile | Direct security exposure |

**Operational debt**

| Item | Signal | Typical interest |
|------|--------|------------------|
| Config sprawl | Settings read in several places, defaults duplicated, env vars undocumented, secrets in config files | Environment-specific outages |
| Config not in the environment | Per-deploy values read from a committed config file rather than env vars; no validation at boot, so a missing value surfaces as a 500 | Credential leak risk; failures land at request time, not start-up |
| Environment-grouped config | `config/<env>.yml` blocks, or code branching on `NODE_ENV`/`SPRING_PROFILES_ACTIVE`/`RAILS_ENV` to pick a datastore or endpoint | Each new environment is a code change; combinatorial config growth |
| State in process memory or on local disk | In-memory session maps, sticky sessions, uploads or generated files written to the container filesystem, per-process counters treated as authoritative | Cannot scale out or roll safely; data lost on every restart |
| Build/release/run not separated | Rebuilt per environment rather than promoted; deploys identified by a moving tag (`:latest`); files edited inside running containers | The tested artifact is not the shipped one; rollback requires a rebuild |
| Migrations run on boot | Schema changes applied at application start rather than as a discrete admin process against the same release | Replicas race the same DDL; rolling deploys pile up locks |
| No graceful shutdown | No `SIGTERM` handler, or a drain deadline above the platform's grace period; workers that drop in-flight jobs | Dropped requests and lost jobs on every deploy |
| Missing observability | Handlers with no structured log/trace/metric, no correlation ID propagation | Long mean-time-to-diagnosis |
| Logs not an event stream | App writes logfiles, rotates them in-process, or ships to a log backend itself instead of unbuffered stdout | Logs die with the container; the app fails when the log backend does |
| No health/readiness discipline | Missing or lying health endpoints; liveness and readiness conflated | Bad deploys ship silently |

## Quantification Model

Every surviving finding is priced before it is ranked.

| Field | Definition | How to derive it |
|-------|-----------|------------------|
| `principal` | Engineering days to repay the item properly (including tests and rollout) | Size of the blast radius: files touched, call sites, migration steps, client coordination |
| `interest` | Recurring cost per month while unpaid | Velocity drag (hours lost per change × change frequency from `git log`), incident exposure, on-call toil, wasted infra spend |
| `rate` | `interest / principal` — the ranking key | Computed |
| `payback` | `principal / interest`, expressed in months | Computed |
| `compounding` | Does the cost grow if untouched? | Yes for EOL clocks, schema growth, contract sprawl, duplication that keeps being copied |
| `basis` | What the estimate rests on | e.g. "24 commits/90d touching this module", "coverage 0% on the payment path", "Node 18 EOL", "judgement — low confidence" |
| `confidence` | high / medium / low | High only with a direct measurement; low when the number is judgement |

Ranking: sort by `rate` descending, then break ties in this order — `compounding` before non-compounding, security exposure before non-security, then lower `principal` first (cheaper wins ship sooner).

Severity mapping (P0-P3) follows `skills/_shared/severity-matrix.md`:

| Priority | Assign when |
|----------|-------------|
| P0 | Active security exposure, data-integrity risk, or a hard EOL deadline inside one quarter |
| P1 | Compounding debt with high interest and a bounded principal — schedule this quarter |
| P2 | Real but stable interest; schedule opportunistically or alongside adjacent work |
| P3 | Low measurable interest; fix when the file is next touched, or accept and record |

## Workflow

### Phase 1: Read-Only Debt Probes (PARALLEL)

Launch every probe not excluded by `--focus` **simultaneously**. All are read-only, all receive the same resolved file list, all return located findings.

**Architecture debt — Use Task tool with subagent_type="backend-developer:backend-architector"**
- Prompt: "Read-only technical-debt inventory over these paths: {file_list} (stacks present: {stacks}). Load `skills/architecture/microservices-patterns/SKILL.md`. Inventory: service-boundary erosion (cross-service DB access, shared tables, imports across service roots), God services/modules (high fan-in plus high churn on one module owning unrelated aggregates), duplicated cross-service business logic (the same rule implemented more than once — name every copy), missing or misplaced transaction boundaries (multi-write handlers with no transaction; transactions spanning network calls), and domain/transport leakage (DTOs in the domain, entities serialized directly to responses). Use `git log --format=%h --since=90.days -- <path> | wc -l` for churn evidence where it helps. Do NOT edit any file. Return findings as `{file, line, item, evidence, blast_radius, why_it_costs}`. If a category is clean, say so in one line rather than inventing items."
- Error: Critical — the architecture probe must complete for the ledger to be meaningful.

**Data debt — Use Task tool with subagent_type="backend-developer:database-engineer"**
- Prompt: "Read-only data-layer debt inventory over these paths: {file_list}. Load `skills/data/query-optimization/SKILL.md`, `skills/data/orm-patterns/SKILL.md`, and `skills/data/migrations/SKILL.md`. Inventory: N+1 access patterns (loop-driven ORM calls, missing eager loading, lazy associations triggered during serialization), hot queries with no supporting index (name the table and the filter/sort/join columns), ORM leakage into the domain (entities used as domain objects, ORM types in service signatures, query construction in controllers/handlers), unsafe or irreversible migrations (destructive DDL without expand/contract, long-lock operations, missing down path), and schema drift (missing FKs/constraints, nullable-everything columns, orphan tables). Do NOT edit any file, do NOT run migrations. Return findings as `{file, line, item, evidence, table_or_query, why_it_costs}`. If a category is clean, say so in one line."
- Error: Non-critical — note the gap in the ledger header and continue.

**API-contract debt — Use Task tool with subagent_type="backend-developer:api-designer"**
- Prompt: "Read-only API-contract debt inventory over these paths: {file_list}. Load `skills/api/rest-design/SKILL.md`, `skills/api/api-versioning/SKILL.md`, and `skills/api/openapi-contracts/SKILL.md`. Inventory: unversioned contracts and missing deprecation policy, breaking changes applied in place on a live version (field removal, retype, semantic change), dead endpoints (routes with no caller in the repo and no spec entry — mark them 'candidate, needs traffic confirmation', never assert they are unused), drift between handlers and the committed OpenAPI/GraphQL/proto artifact, and inconsistent error-envelope or pagination conventions across endpoints. Do NOT edit any file. Return findings as `{file, line, item, endpoint, evidence, client_impact}`. If a category is clean, say so in one line."
- Error: Non-critical — note the gap and continue.

**Test debt — Use Task tool with subagent_type="backend-developer:be-test-generator"**
- Prompt: "INVENTORY ONLY — do NOT write, generate, or edit any test or source file. Read-only coverage-gap analysis over these paths: {file_list}. Load `skills/quality/be-testing/SKILL.md` and `skills/_shared/testing-principles.md`. Identify: critical paths with no covering test (prioritize payment, authentication, authorization/tenancy, and any handler that writes data), boundaries covered only by unit tests where an integration test is required (DB, queue, external HTTP), and flaky/skipped/quarantined tests. Read existing coverage reports if the repo has them; do not run the suite. Return findings as `{file, line, item, uncovered_path, evidence, risk_if_it_breaks}`. If coverage is adequate for a path, say so in one line."
- Error: Non-critical — note the gap and continue.

**Dependency and runtime debt — Use Task tool with subagent_type="backend-developer:be-dependency-manager"**
- Prompt: "Read-only dependency and runtime debt inventory for the manifests in scope: {manifest_list}. Do NOT upgrade, install, or edit any manifest or lockfile. Cross-check against `skills/_shared/version-feature-matrix.md`, and use WebSearch/WebFetch to confirm current EOL and security-support dates for the detected runtimes and major frameworks. Inventory: runtimes at or near end of life (give the date), frameworks more than one major version behind (give current vs installed), deprecated framework idioms still on the request path, and known advisories in the resolved lockfile. Return findings as `{manifest, dependency, installed, current, eol_date, item, upgrade_blast_radius}`. If everything is current, say so in one line."
- Error: Non-critical — if network lookups fail, report versions without EOL dates and flag reduced confidence.

**Operational debt — Use Task tool with subagent_type="backend-developer:backend-developer"**
- Prompt: "Read-only operational debt inventory over these paths: {file_list} (stacks present: {stacks}). Load `skills/tooling/observability/SKILL.md` and `skills/tooling/containerization/SKILL.md` (plus its `references/runtime-contract.md` for the twelve-factor runtime contract). Inventory: config sprawl (settings read from several places, duplicated defaults, undocumented env vars, secrets committed in config files — report the location, never the secret value); config not sourced from the environment (per-deploy values in committed config files, no validation at boot) and environment-grouped config (`config/<env>.yml`, or code branching on `NODE_ENV`/`SPRING_PROFILES_ACTIVE`/`RAILS_ENV` to select a datastore, credential, or endpoint); request-surviving state in process memory or on local disk (in-memory session maps, sticky sessions, uploads or generated files on the container filesystem, per-process counters treated as authoritative); build/release/run not separated (rebuilt per environment instead of promoted, deploys pinned to a moving tag like `:latest`, files edited inside running containers); migrations or backfills run on application boot rather than as a discrete admin process against the same release; observability gaps (request paths with no structured log, trace span, or metric; correlation IDs not propagated across service calls; errors swallowed without a signal); logs not treated as an event stream (writing logfiles, rotating in-process, or shipping to a log backend from inside the app rather than unbuffered stdout); and health/shutdown discipline (missing or non-representative readiness/liveness endpoints, liveness and readiness conflated, no `SIGTERM` handler, or a drain deadline above the platform's grace period). Do NOT edit any file. Return findings as `{file, line, item, evidence, operational_impact}`. If a category is clean, say so in one line."
- Error: Non-critical — note the gap and continue.

[SYNC POINT: Wait for all Phase 1 probes before quantification.]

### Phase 2: Quantification and Ledger Synthesis (SEQUENTIAL)

**Use Task tool with subagent_type="backend-developer:backend-architector"**
- Prompt: "Quantify and rank these technical-debt findings into a single remediation ledger: {phase1_findings}. Scope: {resolved_scope}. Steps: (1) Deduplicate — probes overlap (an N+1 inside a God service surfaces twice); merge at the same `{file, line}`, keep the clearer statement, credit both lenses. (2) Drop speculative items with no located evidence, and drop pure style preferences. Do NOT backfill to lengthen the ledger. (3) Price every survivor with `principal` (eng-days), `interest` (recurring monthly cost), `basis`, `compounding`, and `confidence` per the command's Quantification Model; derive change frequency from git history where it sharpens the estimate. (4) Compute `rate = interest / principal` and `payback = principal / interest`. (5) Assign P0-P3 per `skills/_shared/severity-matrix.md`. (6) Rank by rate, tie-break compounding > security > lower principal. (7) Group the ledger into 3-5 named themes so the reader sees the structural story, not just a list. Return the ledger rows plus the theme summary. Every estimate must carry its basis; write 'judgement — low confidence' where you have no measurement rather than inventing a number."

Then emit the Output Format report. With `--top N`, print the N highest-rate rows but keep the full counts in the category summary. With `--ledger-only`, print the header, category summary, and ledger table alone.

## Output Format

```markdown
## Technical Debt Ledger

**Scope:** {resolved paths / services}
**Stacks:** {detected stacks}
**Probes run:** {architecture, data, api, test, deps, ops — and any skipped}
**Files analyzed:** {N}

### Summary
{Two or three sentences: the structural story. If the codebase is healthy, say so plainly — "no material debt found outside {category}" is a valid result.}

| Priority | Items | Principal (eng-days) | Interest (eng-days/month) |
|----------|-------|----------------------|---------------------------|
| P0 | {n} | {d} | {d} |
| P1 | {n} | {d} | {d} |
| P2 | {n} | {d} | {d} |
| P3 | {n} | {d} | {d} |
| **Total** | {n} | {d} | {d} |

### Themes
1. **{Theme name}** — {what ties these items together, which ledger IDs belong to it}
2. **{Theme name}** — {...}

### Ledger

| ID | P | Category | Location | Item | Principal | Interest/mo | Rate | Payback | Compounds | Basis | Confidence |
|----|---|----------|----------|------|-----------|-------------|------|---------|-----------|-------|------------|
| D1 | P0 | {arch/data/api/test/deps/ops} | {file:line or artifact} | {what is wrong} | {d} | {d} | {r} | {months} | {yes/no} | {evidence} | {high/med/low} |

### P0 Detail
For each P0 item: what breaks, what it costs today, what repayment involves, and the command to escalate to.

### Remediation Routing

| ID | Escalate to |
|----|-------------|
| {id} | `/backend-developer:fix-refactor` — {what to restructure} |
| {id} | `/backend-developer:fix-modernize` — {which runtime/framework upgrade} |
| {id} | `/backend-developer:db-migrate` — {which schema/index change} |
| {id} | `/backend-developer:gen-tests` — {which uncovered path} |
| {id} | `/backend-developer:deps` — {which advisory or version lag} |

### Accepted Debt
{Items deliberately not scheduled, with the reason. An empty list is fine; an unexamined list is not.}

<!-- When a probe could not run: -->
### Coverage Gaps
- {probe}: {why it did not run} — this ledger does not cover {category}.
```

## Error Handling

### No back-end sources in scope
```
Note: No back-end sources found in the resolved scope.
Resolved scope: {scope}
Suggestion: Pass an explicit service path, e.g. /backend-developer:analyze-tech-debt services/orders/
```

### Scope too large to analyze in one pass
```
Note: {N} files across {M} service roots exceeds a single analysis pass.
Suggestion: Narrow the scope (a service path) or a dimension (--focus arch), then repeat.
The ledger composes across runs — the ID prefix keeps rows distinguishable.
```

### A probe fails
Only the architecture probe is critical. For any other probe: record the gap in the **Coverage Gaps** section, state which taxonomy categories are unrepresented, and continue. Never abort the whole analysis over one probe.

### Version/EOL lookup unavailable
```
Warning: could not reach upstream release/EOL data.
Dependency debt reported from manifests only — EOL dates omitted and confidence reduced to low.
Re-run with network access, or use /backend-developer:deps for an authoritative audit.
```

### No git history available
Churn-based interest estimates are unavailable outside a git repository. Fall back to structural signals (fan-in, module size, call-site count), mark the affected estimates `basis: structural — medium confidence`, and note the limitation in the report header.

## Related commands

- `/backend-developer:fix-refactor` — execute the structural repayment this ledger prioritizes (boundaries, God services, duplication, ORM leakage).
- `/backend-developer:fix-modernize` — execute runtime and framework upgrades for the dependency-debt rows.
- `/backend-developer:db-migrate` — apply the index and schema changes behind the data-debt rows, under expand/contract.
- `/backend-developer:gen-tests` — close the untested critical paths before refactoring anything that depends on them.
- `/backend-developer:deps` — authoritative dependency audit and gated upgrades when a row is advisory-driven.
- `/backend-developer:analyze-security` — a security-exposure row belongs in a full OWASP API audit, not in this ledger alone.
- `/backend-developer:review-code` — per-change quality gate that stops new debt from landing.
- `/backend-developer:arch-review` — evaluate the target architecture before committing to a large repayment.
- `/backend-developer:build-test` — the build gate to run after any repayment lands.
