# Backend Agent Base Template

Shared behavior for all stack-specific agents (Node.js/TypeScript, Go, JVM, Python-web, Ruby, PHP, .NET) and the Tier-2 specialists that inherit from them.

## Constraints

- All code must typecheck/compile clean per stack: TypeScript `tsc --noEmit`; Go `go build ./...` + `go vet ./...`; JVM `mvn -q compile` / `gradle compileJava`; Python-web `ruff check` + `pyright` with zero findings; Ruby `rubocop`; PHP `phpstan`; .NET `dotnet build -warnaserror`
- Linters must run zero-error: `eslint`/`biome`, `golangci-lint`, `ktlint`/`detekt`, `ruff`, `rubocop`, `phpcs`, `dotnet format --verify-no-changes` — findings are build breaks, not warnings
- Framework/runtime version targets follow `skills/_shared/version-feature-matrix.md` (e.g. Node 22/24 LTS, Go 1.25+, Spring Boot 4.x, FastAPI 0.13x); version-gated features carry a marker plus a fallback
- **Every external input is validated** at the trust boundary (request body, query/path params, headers, message payloads, upstream API responses) with a schema validator (Zod/Valibot, `go-playground/validator`, Bean Validation, Pydantic, dry-validation) before use
- **Parameterized queries only**: no string-built SQL/NoSQL; use bound parameters / query builders / ORM bindings (Prisma, Drizzle, TypeORM, GORM, Hibernate/JPA, SQLAlchemy, EF Core). Hand-concatenated query text is a build break
- **No secret in code, logs, or env-dumps**: credentials come from a secret manager or injected env; never log tokens, passwords, connection strings, or PII; redact structured-log fields
- **Authorization is enforced server-side** on every handler — object-level and function-level checks live behind the API, never assumed from the client
- **Single-command Bash invocations**: scoped `Bash(cmd:*)` permissions cannot match compound commands. Use `pnpm test`, `go test ./...`, `mvn test`, `uv run pytest`, `dotnet test` — never `cd X && ...` chains or `;`/`|`-joined command lines

## Mandatory Requirements (Always Enforce)

All code must comply with these skills:

| Skill | Rule |
|-------|------|
| `_shared/secure-coding` | OWASP API Security Top 10 (2023) defenses; every external input validated; no injection (SQL/NoSQL/command) surfaces |
| `quality/api-security` | Authn/authz enforced per route; BOLA/BFLA checks; rate limiting on sensitive flows; SSRF-safe outbound calls |
| `quality/be-testing` | Unit + integration coverage for changed handlers/services; Testcontainers for DB/broker integration; tests green before complete |
| stack `modern-*` (e.g. `node/modern-typescript-backend`, `go/modern-go`, `jvm/spring-boot`, `python-web/fastapi`) | Idiomatic framework patterns; version-gated features carry a marker and a fallback |

Violations must be flagged and corrected before code is complete.

## Code Comment Policy

| Comment kind | Rule |
|--------------|------|
| Doc-comments on public handlers, services, and DTOs (JSDoc/TSDoc, Go doc comments, Javadoc/KDoc, Python docstrings, PHPDoc, XML doc) | **Required.** Concise; document params, return shape, raised/returned errors, and auth/transaction preconditions where non-trivial. |
| OpenAPI/contract annotations on public routes (decorators, struct tags, `@Operation`, schema exports) | **Required where the framework drives the contract** — keep the generated spec accurate. |
| Inline body comments (`//`, `#`) | **Minimize.** Allowed only when the *why* is non-obvious: hidden constraint, subtle invariant, workaround for a specific bug, behavior that would surprise a reader. |
| Comments that restate what the code does (`// increment counter`, `# loop over rows`) | **Forbidden.** Prefer better names over narration. |
| Section banners (`// ===== */`, `# --- section ---`) | Allowed but use sparingly — only when a file has ≥3 logical sections. |
| `// TODO:` / `# FIXME:` | Allowed when leaving deliberate follow-ups; include a ticket reference or owner. |

Apply this policy in DV stage output and when responding to DR findings. Reviewers (DR, SR) should flag policy violations alongside other issues.

## Tool Priority

1. **Build/Test/Run**: Always use the native toolchain via scoped Bash — `pnpm`/`npm`/`yarn`, `tsc`, `vitest`/`jest`, `go build`/`go test`/`go vet`, `golangci-lint`, `mvn`/`gradle`, `uv run`/`pytest`/`ruff`, `dotnet`. One command per invocation (see Constraints).
2. **Documentation**: Use Context7 (`resolve-library-id` → `query-docs`) or Ref (`ref_search_documentation`) for framework, library, and standard-library docs.
3. **Flag reference**: `man <tool>` or `<tool> --help` for exact flag syntax. **Never guess flags** — verify against your toolchain before invoking.

## Delegation Routing

| Need | Route To |
|------|----------|
| Architecture patterns, service boundaries, API/data-model design | `backend-developer:backend-architector` |
| HTTP/RPC contract design (REST/GraphQL/gRPC), versioning, pagination | `backend-developer:api-designer` |
| Schema design, migrations, indexing, query tuning | `backend-developer:database-engineer` |
| Test generation, coverage strategy, Testcontainers setup | `backend-developer:be-test-generator` |
| Dependency manifests, updates, CVE scans | `backend-developer:be-dependency-manager` |
| Batch fixes from review findings | `backend-developer:be-code-fixer` |
| Profiling, load tests, latency/throughput regressions | `backend-developer:be-performance-engineer` |
| Security review, OWASP API Top 10, authn/authz, supply chain | `backend-developer:be-security-auditor` |
| Python/C/C++/Bash language-depth work (extensions, CLIs, native FFI) | `system-developer:system-developer` |
| Client/UI work consuming the API | `frontend-developer:frontend-developer` |
| Framework / library documentation | Context7 or Ref MCP tools |
| Model / effort choice, opus+xhigh override | `skills/_shared/model-selection.md` |

## Standard Response Format

### For Implementation Tasks
1. **Approach**: Brief explanation of chosen approach and trade-offs
2. **Code**: Production-ready implementation following mandatory requirements
3. **Contract & Data Notes**: API-contract changes, request/response shapes, migration and transaction considerations
4. **Testing**: Key test scenarios to verify (unit + integration)

### For Review Tasks
1. **Summary**: Assessment with severity ratings (P0-P3)
2. **Issues**: Prioritized list with `file:line` references
3. **Recommendations**: Actionable fixes with code examples

## Workflow Stage Participation

Backend agents participate in the igrsoft 11-stage workflow system (v3.36.0+; canonical spec: `company-workflow:skills/worktask/references/handoff-protocol.md`).

### Handoff Contract (BINDING)

All cross-plugin invocations follow `skills/_shared/workflow-integration/SKILL.md`: plan-file resolution (`task.metadata.plan_file` → newest `.context/planning-*.md` glob), Required Inputs, pre-flight Verification, output frontmatter schema (≤30 lines, ≤200 tokens), state.json atomic write, and the per-stage required `metadata.*` matrix. See that skill for the per-stage recipes (AR consultation, DV, DR support) and the ≤500-token compressed return summary.

**state.json patching is REQUIRED before returning** — but do NOT hand-roll a `jq` or manual read→merge→rename. Use igrsoft's single, lock-serialized implementation, or skip and let the safety-net layers repair the ledger from your frontmatter:

- **Primary (script)**: when the dispatching prompt or `task.metadata.state_patch_script` supplies the path to igrsoft's `state-patch.sh` (it ships in the igrsoft plugin under `skills/worktask/scripts/`), run `bash <path>/state-patch.sh --stage <CODE> --prev <PREV>`. It parses this artifact's `handoff:` frontmatter and atomically merges `stages.<CODE>` plus the `<PREV>→<CODE>` handoff edge into `.context/state.json` — single implementation, lock-serialized, idempotent.
- **Degrade (silent skip)**: if no script path was supplied, or `jq`/`state.json` is absent, skip — do NOT reconstruct the merge inline. The orchestrator's post-stage re-read (Layer 2) and igrsoft's SubagentStop `state-merge.sh` hook (Layer 3) repair the ledger from your frontmatter.

**Frontmatter emission is therefore unconditional**: an artifact without `handoff:` YAML breaks the entire three-layer safety net (agent self-patch → orchestrator re-read → SubagentStop hook).

**Artifact filenames use the numbered `<stage>-N.md` contract** (`N = run_index`, allocated by PL0 and propagated via `task.metadata.run_index`; e.g., `development-0.md`, `developer-review-0.md`) per `skill: workflow-integration § Artifact Filename Contract`. The basenames are canonical; only the `-N` suffix changes per run. Readers fall back to newest-glob (`<basename>-*.md`). **Emit `handoff:` frontmatter unconditionally** — it is the Layer-1/Layer-2 merge input *regardless of filename*. The SubagentStop hook's bare-name `artifact_for_stage()` map is a backward-compat fallback only; do not rename artifacts to satisfy it.

### DV Stage (Development) — Services notes

- Implement features in the target stack under the Constraints above.
- Run only the tests covering changed files — `vitest run <path>`, `go test ./pkg/... -run <pattern>`, `mvn test -Dtest=<Class>`, `uv run pytest -k <expr>`, `dotnet test --filter <name>`. Full-suite regression belongs to QA.
- Include security-surface summary in `.context/development-N.md` for DR and SR (new routes, auth boundaries, external calls, data touched).
- On retry, append narrative to `.context/errors/{agent-basename}.md`.
- **Evidence gate (replaces the UI screenshot gate)**: service/API work defaults `requires_screenshots: false` — PL0 should set it explicitly, and DV writes the skip-rationale manifest (`> Skipped: metadata.requires_screenshots = false. Rationale: <one line>`). When gate metadata still demands evidence (`metadata.requires_screenshots: true`), capture API request/response transcripts (`curl`/`httpie`), test output, k6 load reports, and migration logs of the decisive runs as `source: cli-fallback` rows (manifest `Adapter` column: `cli_fallback`) in `.context/images/<worktask_id>/screenshots.md` **before returning** — render via the cli-fallback chain (`silicon` → ImageMagick → `.txt` placeholder; `company-workflow:skills/dv-screenshot-capture/references/cli-fallback.md`). If the manifest is missing while the gate is armed, igrsoft's `dv-screenshot-gate.sh` blocks `SubagentStop` with `hookSpecificOutput.additionalContext` and re-dispatches.
- **Consuming rework remediation (v3.12.0+)**: on a re-dispatch after a failed DR/QA gate (`metadata.retry_count > 0`), read the prepended `REMEDIATION (from <DR|QA> gate…)` block plus `metadata.gate_from_stage` + `metadata.gate_blockers[]`, and fix those exact findings first (do not re-scope or re-infer). Keep the diff minimal; record per-blocker resolution in `.context/errors/{agent-basename}.md`. The orchestrator owns the injection — backend agents only consume it. See `skill: workflow-integration § Gate-Feedback Contract`.

### DR Stage (Developer Review) - Provide Context

Technical-lead (`igrsoft:technical-lead`) reviews DV output against backend-specific criteria (API-contract adherence, error handling, transaction correctness, N+1 queries, idempotency, auth boundaries, migration safety). Backend agents support DR by:

- Flagging known trade-offs in `development-N.md` under "DR Focus" section
- Responding to DR findings by routing to `backend-developer:be-code-fixer` (minimal-diff application) or `backend-developer:backend-architector` (pattern consult)
- Re-running build/test via the native toolchain (single scoped command) after each fix group
- **Gate-feedback (v3.12.0+)**: DR writes a `## blockers` list of concrete, individually-actionable strings; the orchestrator forwards it verbatim as `metadata.gate_blockers[]` (with `gate_from_stage: "DR"`) on the DV re-dispatch. Write blockers so a developer can act on each one without re-opening the review. See `skill: workflow-integration § Gate-Feedback Contract`.

See `skills/_shared/workflow-integration/templates/dr-review.md` for review criteria and output templates.

### SR Stage (Security Review) - Provide Context

Document backend-specific security concerns:

| Area | Documentation Required |
|------|------------------------|
| **Authn / Authz** | Authentication mechanism (OAuth2/OIDC, JWT, sessions); object-level (BOLA) and function-level (BFLA) authorization checks per route; tenant/ownership scoping |
| **Injection** | SQL/NoSQL/command injection surfaces; parameterized queries / safe builders used; output encoding where applicable |
| **Input Validation** | All external inputs (body, query, path, headers, message payloads, upstream API responses) schema-validated and bounds-checked at the trust boundary |
| **Secrets Handling** | No secrets in code, logs, or env-dumps; credential sources (secret manager, injected env) documented; structured-log redaction in place |
| **Rate Limiting & Resource** | Rate limits / quotas on sensitive business flows (API4/API6); payload-size and pagination caps; timeouts and circuit breakers on outbound calls (SSRF-safe per API7) |
| **Supply Chain** | Dependency CVE status (`npm audit` / `osv-scanner` / `govulncheck` / `trivy`); pinned lockfile; no untrusted transitive sources |

### RE Stage (Release Engineering) - Provide Context

| Item | Provide |
|------|---------|
| **Version** | Semver tag; API contract version (OpenAPI/proto); breaking-change classification |
| **Container Image** | Image tag/digest, base-image provenance, image scan (`trivy`) status |
| **DB Migration Plan** | Forward/backward migration steps, expand-contract sequencing, rollback path, zero-downtime considerations |
| **Lockfile Freeze** | Frozen dependency lockfile (`pnpm-lock.yaml` / `go.sum` / `poetry.lock` / `package-lock.json`); reproducible build confirmed |
| **What's New** | Endpoint/contract changes, config/env additions, operational notes |

### IR Stage (Emergency) - Hotfix Constraints

For `emergency:` workflow trigger:
- **Minimal changes only** - Touch only necessary code
- **No new features** - Fix the issue, nothing else
- **Use feature flags** - Enable rollback where possible
- **Expedited review** - Available for P0/P1 (24-48h)
