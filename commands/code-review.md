---
name: code-review
description: Language-aware back-end code review — per-stack reviewers + API-contract pass + security pass, synthesized into a P0-P3 report
argument-hint: "[scope: file/dir/PR#/branch — default: working changes] [--quick] [--fix] [--lang node|go|jvm|python|ruby|php|dotnet] [--security-focus]"
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 4000
  max-tokens: 28000
  model-distribution:
    haiku: 15%
    sonnet: 75%
    opus: 10%
---

# Language-Aware Back-End Code Review
<!-- Updated: June 2026 -->

Review back-end changes with the right stack specialist per runtime, plus a dedicated API-contract pass and a cross-cutting security pass, then synthesize one deduplicated, prioritized P0-P3 report. Scope defaults to your working changes; reviewers run read-only and in parallel; `--fix` hands the blocking findings to the code fixer under a minimal-diff gate.

[Extended thinking: A missing tenant filter on a Prisma query (BOLA), a Go goroutine leaking a request-scoped context, a Spring `@Transactional` swallowed by a self-invocation, and an N+1 across a JPA association are four different review skills — one generalist pass misses most of them. This command resolves the scope once, detects which runtimes are actually present, fans out one read-only reviewer per detected stack (each loaded with the right back-end review focus) alongside an API-contract pass and a cross-cutting security pass, then merges and ranks the findings. The reviewers never edit; only the explicit `--fix` step does, and only for P0/P1. Keep the synthesis honest — if there are no material issues, say so rather than padding the report.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve the scope before reviewing.** Apply the scope precedence (explicit args > working diff > branch/PR diff) exactly once, list the concrete files under review, and pass that same file list to every reviewer. Do NOT let reviewers re-scope independently.
2. **Reviewers are read-only.** Phase 1 agents MUST NOT write or edit. They return structured findings only. The single place edits happen is the `--fix` step, after synthesis, and only for P0/P1 findings.
3. **One reviewer per detected stack.** Launch a reviewer only for a runtime that is actually present in the scope (or forced by `--lang`). Do NOT spawn a Go reviewer for a pure-Node change. Run the eligible reviewers in parallel — they have no dependencies on each other.
4. **API-contract and security passes always run** (unless `--quick`). The `backend-developer:api-designer` contract pass and the `backend-developer:be-security-auditor` security pass are cross-cutting and run alongside the stack reviewers, not after them.
5. **Synthesize, deduplicate, normalize.** In Phase 2 you merge all reviewer outputs, drop duplicates and speculative claims, and normalize every surviving finding to `{file, line, category, severity, why, fix, confidence}` before ranking into P0-P3.
6. **Tool-missing never hard-fails.** If a reviewer's underlying linter/analyzer is unavailable, print the install hint, note the reduced depth for that stack, and continue. Never abort the whole review over one missing tool.
7. **No manufactured feedback.** If a reviewer or the synthesis finds no material issue, report that plainly. Do NOT invent P2/P3 nits to fill the report.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Review your current working changes (staged + unstaged)
/backend-developer:code-review

# Review a specific directory
/backend-developer:code-review src/api/

# Review a single file
/backend-developer:code-review src/routes/orders.ts

# Review a branch or PR against the base
/backend-developer:code-review feature/order-webhooks
/backend-developer:code-review 142            # PR number

# Fast single-agent pass for quick feedback
/backend-developer:code-review src/ --quick

# Review, then auto-fix the P0/P1 findings
/backend-developer:code-review src/ --fix

# Force a stack when detection is ambiguous (e.g. polyglot monorepo)
/backend-developer:code-review services/ --lang go

# Raise the security pass priority for an auth/permissions change
/backend-developer:code-review src/auth/ --security-focus
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working changes | File, directory, PR number, or branch to review. See Scope Resolution. |
| `--quick` | off | Single combined reviewer pass for rapid feedback. Skips parallel fan-out and the dedicated API-contract/security passes; folds lightweight contract and security checks into the one pass. |
| `--fix` | off | After synthesis, delegate P0/P1 findings to `backend-developer:be-code-fixer` under a minimal-diff gate. P2/P3 are never auto-fixed. |
| `--lang node\|go\|jvm\|python\|ruby\|php\|dotnet` | auto | Force the reviewer set instead of detecting. Repeatable conceptually (`--lang node --lang go`); use for polyglot monorepos or to narrow a mixed repo. |
| `--security-focus` | off | Raise the security pass priority: instruct `be-security-auditor` to go deeper (OWASP API Top 10 — BOLA, broken auth, injection, SSRF, rate-limiting gaps, secrets, supply chain) and rank its findings first in ties. |

## Scope Resolution

Resolve the set of files under review **once**, top-down — the first applicable rule wins:

1. **Explicit args** — a file, directory, PR number, or branch named on the command line.
   - File or directory → review those paths directly.
   - PR number (bare integer) → `gh pr diff <N> --name-only` for the file list (and `gh pr diff <N>` for the patch). If `gh` is unavailable, print the install hint and fall back to rule 3 against the PR's base branch.
   - Branch name → diff against the merge-base with the default branch: `git diff --name-only $(git merge-base HEAD <branch>)..<branch>`.
2. **Working changes** (no args) — staged and unstaged tracked changes:
   `git diff --name-only HEAD` (plus `git diff --cached --name-only`). This is the default.
3. **Branch/PR diff** (fallback) — when neither explicit paths nor working changes apply, diff the current branch against the default branch's merge-base.

After resolving, **print the concrete file list** and the line ranges (where a diff is involved) before launching any reviewer. Reviewers receive this exact list — they do not re-derive scope. Exclude vendored/build/generated artifacts (`node_modules/`, `dist/`, `build/`, `target/`, `bin/`, `obj/`, `vendor/`, `.venv/`, generated client SDKs, and committed migration snapshots) from the list.

## Language Detection

Detect which runtimes appear in the resolved file list using the canonical `skill: language-detection` table — do not fork its routing logic. Summary for this command:

| Files in scope | Reviewer to launch |
|----------------|--------------------|
| `.ts`, `.tsx`, `.js`, `.mjs` (+ `package.json`, `tsconfig.json`) | `backend-developer:node-developer` |
| `.go` (+ `go.mod`) | `backend-developer:go-developer` |
| `.java`, `.kt` (+ `pom.xml`, `build.gradle`) | `backend-developer:jvm-backend-developer` |
| `.py` (+ `pyproject.toml` with FastAPI/Django/Flask) | `backend-developer:python-backend-developer` |
| `.rb` (+ `Gemfile`, Rails app layout) | `backend-developer:ruby-developer` |
| `.php` (+ `composer.json`, Laravel/Symfony layout) | `backend-developer:php-developer` |
| `.cs` (+ `.csproj`, ASP.NET Core) | `backend-developer:dotnet-developer` |

- A `--lang` flag overrides detection for that stack (use it for polyglot monorepos or to scope a mixed repo).
- A change spanning several runtimes launches **one reviewer per stack present** — they run in parallel.
- Ambiguous files (e.g. `.ts` that is front-end-only, or a shared schema) follow `skill: language-detection` tie-break rules; genuinely cross-boundary files route to the router `backend-developer:backend-developer`.
- If nothing recognized is in scope, report "no reviewable back-end sources in scope" and stop.

## Workflow

### `--quick` path (single pass)

When `--quick` is set, skip the fan-out entirely:

1. Resolve scope and detect the dominant runtime.
2. **Use Task tool with subagent_type="backend-developer:<dominant-stack-agent>"** (e.g. `backend-developer:node-developer`).
   Prompt: "Quick read-only review of these files: {file_list}. Focus on correctness and security for {stack}: {focus_bullets_for_stack}. Include a lightweight API-contract and OWASP-API check. Do NOT edit. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."
3. Normalize and print the report (Output Format). Skip the dedicated API-contract and security passes — the single reviewer folds in lightweight contract and security checks.

`--quick` is for fast feedback on a single-stack change; for polyglot repos or pre-merge gates, use the full path.

### Phase 1: Parallel Read-Only Review

Launch every eligible reviewer **simultaneously** (one per detected stack) plus the API-contract pass and the security pass. All are read-only and receive the same resolved file list. Each stack reviewer gets a back-end review focus:

**Node.js/TypeScript — Use Task tool with subagent_type="backend-developer:node-developer"**
- Focus: input validation at the boundary (zod/class-validator, untrusted body/query/params), authorization boundaries (BOLA — object ownership checks on every fetch/update), N+1 across ORM relations (Prisma/Drizzle/TypeORM), transaction correctness (interactive `$transaction`, isolation, leaked connections), idempotency of mutating handlers, error handling (unhandled rejections, swallowed errors, leaking internals in responses), async correctness (missing `await`, floating promises, fire-and-forget without supervision).
- Prompt: "Read-only review of the Node/TypeScript files: {file_list}. Review for: boundary input validation, authorization boundaries (BOLA/object-ownership checks), N+1 ORM queries (Prisma/Drizzle/TypeORM), transaction correctness and connection leaks, idempotency of mutating handlers, error handling (unhandled rejections, internals leaked in responses), and async correctness (missing await, floating promises). Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Go — Use Task tool with subagent_type="backend-developer:go-developer"**
- Focus: input validation and binding (gin/echo/chi handlers, untrusted JSON), authorization boundaries (BOLA — ownership/tenant checks), `context.Context` propagation and cancellation/deadline plumbing, goroutine and resource leaks (unclosed `rows`/`Body`, leaked goroutines on request paths), N+1 via GORM/sqlx, transaction correctness (`Begin`/`Commit`/`Rollback`, deferred rollback, `sql.ErrNoRows`), idempotency, error wrapping (`%w`, sentinel errors, unchecked errors), data races.
- Prompt: "Read-only review of the Go files: {file_list}. Review for: handler input validation/binding, authorization boundaries (ownership/tenant checks), context propagation and cancellation, goroutine and resource leaks (unclosed rows/Body), N+1 via GORM/sqlx, transaction correctness (Begin/Commit/Rollback, deferred rollback), idempotency, error wrapping and unchecked errors, and data races. Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**JVM (Java/Kotlin, Spring Boot) — Use Task tool with subagent_type="backend-developer:jvm-backend-developer"**
- Focus: input validation (`@Valid`/Bean Validation on DTOs), authorization boundaries (method/object security, BOLA on repository fetches), `@Transactional` correctness (self-invocation that bypasses the proxy, propagation, `readOnly`, exception-rollback rules), N+1 across JPA/Hibernate associations (missing fetch joins, `LAZY` triggered in serialization), idempotency, error handling (`@ControllerAdvice`, leaked stack traces), reactive/blocking misuse (blocking calls on a reactive thread, `block()` in WebFlux).
- Prompt: "Read-only review of the JVM files: {file_list}. Review for: Bean Validation on DTOs, authorization boundaries (method/object security, BOLA on repository fetches), @Transactional correctness (self-invocation proxy bypass, propagation, exception-rollback rules), N+1 across JPA/Hibernate associations, idempotency, error handling (@ControllerAdvice, leaked stack traces), and reactive/blocking misuse (block() on reactive threads). Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Python (FastAPI/Django/Flask) — Use Task tool with subagent_type="backend-developer:python-backend-developer"**
- Focus: input validation (Pydantic models, DRF serializers, untrusted request data), authorization boundaries (BOLA — object-level permission checks, Django queryset scoping), async correctness (blocking calls in async views, unawaited coroutines, sync DB driver in async path), N+1 via the ORM (SQLAlchemy/Django — missing `selectinload`/`select_related`/`prefetch_related`), transaction correctness (`atomic()`, session scope, leaked sessions), idempotency, error handling (broad `except`, internals leaked in responses).
- Prompt: "Read-only review of the Python web files: {file_list}. Review for: input validation (Pydantic/DRF serializers), authorization boundaries (BOLA, object-level permissions, queryset scoping), async correctness (blocking calls in async views, sync DB driver in async path), N+1 via SQLAlchemy/Django ORM, transaction correctness (atomic/session scope), idempotency, and error handling (broad except, internals leaked in responses). Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Ruby (Rails) — Use Task tool with subagent_type="backend-developer:ruby-developer"**
- Focus: strong parameters and input validation, authorization boundaries (BOLA — Pundit/CanCanCan policies, tenant scoping vs raw `find`), N+1 across ActiveRecord associations (missing `includes`/`preload`, Bullet findings), transaction correctness (`transaction` blocks, `after_commit` semantics), idempotency, mass-assignment exposure, error handling (rescued exceptions, internals in responses), callback-driven side effects.
- Prompt: "Read-only review of the Ruby/Rails files: {file_list}. Review for: strong parameters and input validation, authorization boundaries (BOLA, Pundit/CanCanCan policies, tenant scoping vs raw find), N+1 across ActiveRecord associations (missing includes/preload), transaction correctness and after_commit semantics, idempotency, mass-assignment exposure, and error handling. Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**PHP (Laravel/Symfony) — Use Task tool with subagent_type="backend-developer:php-developer"**
- Focus: input validation (Form Requests / Validator constraints), authorization boundaries (BOLA — Policies/Gates/Voters, tenant scoping vs raw `find`), N+1 across Eloquent/Doctrine relations (missing eager loading `with()`/fetch joins), transaction correctness (`DB::transaction`, nested transactions), idempotency, mass-assignment (`$fillable`/`$guarded`), error handling (leaked stack traces, internals in responses).
- Prompt: "Read-only review of the PHP files: {file_list}. Review for: input validation (Form Requests/Validator), authorization boundaries (BOLA, Policies/Gates/Voters, tenant scoping), N+1 across Eloquent/Doctrine relations (missing eager loading), transaction correctness (DB::transaction, nesting), idempotency, mass-assignment exposure, and error handling. Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**.NET (ASP.NET Core, EF Core) — Use Task tool with subagent_type="backend-developer:dotnet-developer"**
- Focus: model validation (DataAnnotations / FluentValidation), authorization boundaries (BOLA — resource-based authorization, tenant filters vs raw `FindAsync`), N+1 across EF Core navigations (missing `Include`/projection, lazy-loading proxies), transaction correctness and `SaveChangesAsync` scope, idempotency, async correctness (`async void`, sync-over-async `.Result`/`.Wait()`, missing `CancellationToken` plumbing), error handling (exception middleware, internals leaked in `ProblemDetails`).
- Prompt: "Read-only review of the .NET files: {file_list}. Review for: model validation (DataAnnotations/FluentValidation), authorization boundaries (BOLA, resource-based authorization, tenant filters), N+1 across EF Core navigations (missing Include/projection, lazy proxies), transaction and SaveChangesAsync scope, idempotency, async correctness (async void, sync-over-async, CancellationToken plumbing), and error handling. Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**API-contract pass (always, unless `--quick`) — Use Task tool with subagent_type="backend-developer:api-designer"**
- Prompt: "Read-only API-contract review of: {file_list} (stacks present: {stacks}). Check the changed endpoints against contract discipline: REST/GraphQL/gRPC shape consistency, correct status codes and error envelopes, request/response schema drift vs the committed OpenAPI/GraphQL/proto spec, breaking changes to existing fields, pagination/filtering/versioning conventions, idempotency of mutating verbs, and content-negotiation correctness. Flag any undocumented or inventory-drifted endpoints (OWASP API9). Do NOT edit any file. Return findings as a list of `{file, line, category, severity (P0-P3), why, fix, confidence}`. If there are no material issues, say so directly."

**Security pass (always, unless `--quick`) — Use Task tool with subagent_type="backend-developer:be-security-auditor"**
- Prompt: "Read-only cross-cutting security review of: {file_list} (stacks present: {stacks}). Cover the OWASP API Security Top 10 (2023): API1 broken object-level authorization (BOLA), API2 broken authentication, API3 broken object property-level authorization (mass assignment / over-exposure), API4 unrestricted resource consumption (missing rate limits, unbounded queries), API5 broken function-level authorization, API6 unrestricted access to sensitive business flows, API7 SSRF, API8 security misconfiguration, API9 improper inventory management, API10 unsafe consumption of upstream APIs. Also cover injection (SQL/NoSQL/command), secrets in code/history, and supply-chain CVEs in changed dependencies. Map each finding to the relevant API# (and CWE where applicable). Do NOT edit any file. Return findings as a list of `{file, line, category (API#/CWE), severity (P0-P3), why, fix, confidence}`. {If --security-focus: 'Go deep — include rate-limiting, authz-boundary, and supply-chain (npm audit / osv-scanner / govulncheck / trivy) observations.'} If there are no material issues, say so directly."

[SYNC POINT: Wait for all Phase 1 reviewers before synthesis.]

### Phase 2: Synthesis

1. **Collect** every reviewer's findings (stack reviewers + API-contract pass + security pass).
2. **Deduplicate** — the security pass and a stack reviewer will overlap (e.g. both flag a missing ownership check as BOLA). Merge duplicates at the same `{file, line}`, keeping the higher severity and the clearer fix; credit both lenses in `why`.
3. **Filter** — drop speculative claims with no concrete evidence and drop pure style nits unless they hide a real defect. Per Rule 7, do not backfill.
4. **Normalize** every survivor to `{file, line, category, severity, why, fix, confidence}` (severity from `skill: severity-matrix` P0-P3; confidence = high/medium/low).
5. **Rank** into P0-P3. With `--security-focus`, security findings win severity ties.
6. **Emit** the Output Format report.

### Optional: `--fix` (P0/P1 only)

If `--fix` is set, after synthesis:

**Use Task tool with subagent_type="backend-developer:be-code-fixer"**
Prompt: "Apply minimal, targeted fixes for these P0/P1 findings from code review: {p0_p1_findings as `{file, line, category, fix}`}. Minimal-diff gate: change only what each finding requires; do not refactor, reformat untouched code, or fix P2/P3 items. Preserve behavior outside the stated defect. After fixing, report each change as `{file, line, finding, change}` and list any finding you could NOT safely auto-fix (needs human judgment, API redesign, schema migration, or broader change)."

- Only P0/P1 with a concrete, localized fix are eligible. Anything needing design judgment, a migration, or an API-contract change is returned for manual handling.
- Re-run a focused review on the touched files to confirm the fix introduced no regression (a single `--quick` pass over the changed files is sufficient).

## Output Format

```markdown
## Code Review Report

**Scope:** {resolved scope — paths / PR# / branch}
**Files reviewed:** {N} ({stacks present})
**Reviewers:** {list of agents run} {+ API-contract pass} {+ security pass}
**Mode:** {full | --quick}

### Summary
{One or two sentences. If clean: "No material issues found — the changes look correct, authorized, and contract-faithful." Otherwise: counts by priority.}

| Priority | Count |
|----------|-------|
| P0 (block merge) | {n} |
| P1 (fix in this change) | {n} |
| P2 (should fix) | {n} |
| P3 (nice to have) | {n} |

### P0 — Must Fix Before Merge
| File:Line | Category | Why | Fix | Confidence |
|-----------|----------|-----|-----|------------|
| {file}:{line} | {category/API#/CWE} | {why it's broken} | {minimal fix} | {high/med/low} |

### P1 — Fix In This Change
{same table shape}

### P2 — Should Fix
{same table shape}

### P3 — Nice To Have
{same table shape}

<!-- When --fix ran: -->
### Fixes Applied
| File:Line | Finding | Change |
|-----------|---------|--------|
| {file}:{line} | {finding} | {what changed} |

**Not auto-fixed (manual):** {findings needing human judgment, migration, or contract change, or "none"}

<!-- When a tool was unavailable: -->
### Reduced-Depth Notes
- {stack}: {missing tool} unavailable — review ran without {analyzer}. Install: {hint}.
```

## Error Handling

### No reviewable sources in scope
```
Note: No back-end sources found in the resolved scope.
Resolved scope: {scope}
Suggestion: Pass an explicit path, or check that your changes include reviewable server-side sources.
```

### No changes detected (default scope)
```
Note: No staged or unstaged changes to review.
Suggestion: Name a path, branch, or PR number, e.g. /backend-developer:code-review src/api/
```

### `gh` unavailable for a PR scope
```
Warning: `gh` CLI not found; cannot fetch PR diff directly.
Install: brew install gh   (then `gh auth login`)
Falling back to a branch diff against the default branch.
```

### Reviewer tool missing (reduced depth)
Print the relevant install hint, note reduced depth for that stack in the report, and continue — never hard-fail:

| Missing tool | Install hint |
|--------------|--------------|
| `tsc` / `eslint` (Node/TypeScript) | `npm i -g typescript eslint` (or use the repo's local devDependencies) |
| `golangci-lint` / `go vet` (Go) | `brew install golangci-lint` (`go vet` ships with the toolchain) |
| `mvn` / `gradle` (JVM) | `brew install maven gradle` |
| `ruff` (Python) | `uv tool install ruff` |
| `rubocop` / `brakeman` (Ruby) | `gem install rubocop brakeman` |
| `phpstan` / `psalm` (PHP) | `composer global require phpstan/phpstan` |
| `dotnet` SDK / analyzers (.NET) | install the .NET SDK from `dotnet.microsoft.com` |
| `osv-scanner` / `trivy` / `govulncheck` (supply chain) | `brew install osv-scanner trivy` ; `go install golang.org/x/vuln/cmd/govulncheck@latest` |

### Ambiguous stack
If detection cannot classify a file (e.g. a shared schema, or `.ts` that may be front-end-only), apply `skill: language-detection` tie-break rules; if still ambiguous, route it to `backend-developer:backend-developer` and note the routing in the report.

## See Also

- `skill: language-detection` — canonical marker → runtime → agent routing (keep this command's detection in sync).
- `skill: severity-matrix` — P0-P3 definitions used by the synthesis ranking.
- `skill: secure-coding` — OWASP API Top 10, injection, and authz-boundary patterns the security pass draws on.
- `skills/_shared/version-feature-matrix.md` — canonical framework/runtime version → feature lookup.
- `/backend-developer:lint-fix` — run formatters/linters first to clear P3 noise before review.
- `/backend-developer:build-test` — confirm the change builds and tests green (unit + integration) before or after review.
- `/backend-developer:deps-audit` — escalate a supply-chain CVE finding to a full dependency audit.

If there are no material issues, say that directly instead of manufacturing feedback.
