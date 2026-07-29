---
name: workflow-integration
description: >-
  Binding contract for participating in the igrsoft 11-stage workflow (v3.36.0) as a
  back-end agent — the per-stage recipes (DV/DR/SR/QA/RE), the numbered artifact
  filenames (development-N.md, developer-review-N.md, testing-N.md), the handoff:
  frontmatter schema, the gate-feedback contract, and the cli-fallback evidence model
  (curl/httpie transcripts, test output, k6 reports, migration logs) for no-UI work.
  Use whenever .context/state.json is present, before writing any stage artifact,
  when emitting handoff frontmatter, when a screenshot/evidence gate is armed, or when
  consuming gate_blockers from an upstream review — load this FIRST so the orchestrator's
  merge layer can read your output.
---

# Workflow Integration Guide

When invoked from the igrsoft workflow system, follow these guidelines for seamless collaboration.

## 11-Stage Pipeline (Default)

```
PL → AR → TL → DV → DR → SR → QA → DC → RE → FN → ST
          ↑    ↓    ↑    ↑    ↑              ↑
   backend-developer agents contribute to AR, DV, DR, SR, QA, and RE
```

| Code | Stage | igrsoft Agent | backend-developer Contribution |
|------|-------|---------------|--------------------------------|
| PL | Planning | product-manager | — |
| AR | Architecture | software-architector | backend-architector (consultation: service boundaries, data model, API/contract design) |
| TL | Team Lead | team-lead | — |
| DV | Development | developer → **backend-developer** | **Primary**: backend-developer router, node-developer, go-developer, jvm-backend-developer, python-backend-developer, ruby-developer, php-developer, dotnet-developer |
| **DR** | **Developer Review** | **technical-lead** | **Support**: be-code-fixer (fix application), backend-architector (pattern consult), api-designer + database-engineer (contract/schema consult) |
| SR | Security Review | security-reviewer | Context: be-security-auditor (OWASP API Top 10, injection review, secrets scan, supply-chain audit) |
| QA | QA Testing | qa-engineer | Support: be-test-generator |
| DC | Documentation | technical-writer | — |
| RE | Release Engineering | release-engineer | Packaging: be-dependency-manager (lockfiles, pins), image/version preparation, migration ordering |
| FN | Finalization | project-manager | — |
| ST | Stakeholder | stakeholder | — |

## Worktask Triggers (v3.36.0)

| Trigger | Stages | Use Case |
|---------|--------|----------|
| `micro:` | Plan → approve → edit | Single-file fixes, typos |
| `quick:` | PL → DV → DR → QA | Small features, bug fixes |
| `worktask:` | Full 9-stage (PL→AR→TL→DV→DR→QA→DC→FN→ST) | Multi-file features |
| `fworktask:` | Full 9-stage, auto-continue | Trusted full runs |
| `--secure` / `--full` | 11-stage (adds SR, RE) | Security-critical work |
| `emergency:` | IR→DV→DR→QA→RE→FN | Hotfixes, incidents (DR enforces minimal-diff) |

## DV Contract for Backend Work

The DV agent writes `.context/development-N.md`. Mandatory H2 anchors are fixed by igrsoft's anchor allow-list (`handoff-protocol.md#anchor-allow-list`): `## files-changed`, `## tests-added`, `## deviations`, `## follow-ups`. Backend-specific sections nest as H3 under them:

| Section | Anchor level | Content |
|---------|--------------|---------|
| Files Changed | `## files-changed` | File / change / why table |
| Decisions | `### decisions` (under files-changed) | Non-obvious implementation choices with rationale |
| Tool Invocations | `### tool-invocations` (under files-changed) | Exact build/test commands run (`pnpm build`, `go test ./...`, `mvn verify`, `uv run pytest`, …) |
| Tests Added | `## tests-added` | Test files + what each covers |
| Build Evidence | `### build-evidence` (under tests-added) | Runtime + framework versions (e.g. `node 22 / NestJS 11`, `go 1.23 / chi v5` — verify against `_shared/version-feature-matrix.md`), build/typecheck status, lint status, integration-test transcript path in `.context/logs/`, migration dry-run output where schema changed |
| Deviations | `## deviations` | Departures from `analyzing-N.md` decisions |
| Follow-ups | `## follow-ups` | Deferred work, flagged risks |

Build Evidence is non-negotiable: a DV artifact without a runtime/framework-version line, a build/typecheck status, a lint status, and a test transcript path under `.context/logs/` is incomplete. Where a migration was added, include the dry-run output. Tee raw build/test output to `.context/logs/<tool>-<worktask_id>.log`.

Copy-paste template: [templates/dv-development.md](templates/dv-development.md).

## Screenshot Gate for API Work (HIGHEST INTEGRATION RISK — read this)

igrsoft's `dv-screenshot-gate.sh` blocks `SubagentStop` when `metadata.requires_screenshots != false` and no manifest exists at `.context/images/<worktask_id>/screenshots.md`. The igrsoft default is **TRUE** — but service/API work has no UI to screenshot. Handle it in this order:

1. **Preferred**: the dispatcher sets `metadata.requires_screenshots: false` for backend-developer DV stages (non-UI changes). Then no manifest is required and the gate is skipped. Plugin norm: `requires_screenshots: false` is the **default expectation** for backend work — flag it in your return summary if the metadata says otherwise.
2. **cli-fallback procedure** (when the flag is unset/true and you cannot change it): produce the manifest anyway using request/response and test transcripts —
   - Capture each meaningful API surface as text: a representative `curl`/`httpie` request with its real response, the test run output, a `k6` load report, and migration logs. Save as `.txt`/`.md` under `.context/images/<worktask_id>/`.
   - Write `.context/images/<worktask_id>/screenshots.md` with one row per capture, `source: cli-fallback`, and a `notes` cell explaining why (e.g. "HTTP API, no UI; request/response transcript capture").
   - Frontmatter `screenshot_count` MUST equal the number of table rows.
3. **Never** fabricate image files or return without either the `false` flag or a cli-fallback manifest — the gate re-dispatches DV until one exists.
4. **Evidence freshness**: every `cli-fallback` transcript row (curl/httpie request+response, test output, k6 report, migration dry-run/log) must be produced *this run* from the actual invocation — never reuse a transcript from a prior run or another workdir. igrsoft QA direct-reads the evidence files and cross-checks them against the `### build-evidence` log paths in the DV artifact; a stale or duplicated transcript is flagged and re-opens DV. This extends rule 3's integrity bar — the "never fabricate" rule applies to reused text transcripts as much as to invented image files.

Manifest row format mirrors igrsoft's `dv-screenshot-capture` output: `| name | path | source | design_ref | notes |` with `source` ∈ {`cli-fallback`} for backend work; `design_ref` stays blank (no mockups for APIs).

## Per-Agent Error Files

Parallel-safe retry narratives live in `.context/errors/<agent-basename>.md` — basename = last `:`-separated segment of the qualified name (`task-system.md § error_file derivation`):

| File | Purpose |
|------|---------|
| `.context/errors/node-developer.md` | Node.js/TypeScript DV retry narratives |
| `.context/errors/go-developer.md` | Go DV retry narratives |
| `.context/errors/jvm-backend-developer.md` | Java/Kotlin DV retry narratives |
| `.context/errors/python-backend-developer.md` | Python web DV retry narratives |
| `.context/errors/be-code-fixer.md` | DR fix-application retries |
| `.context/errors/<agent-basename>.md` | One file per agent — never overwrite a shared `error.md` |

Derive your own path from `task.metadata.error_file` or your frontmatter `name:`.

## DR Backend Review Criteria

technical-lead reads `development-N.md` + error files and produces `developer-review-N.md` (verdict `pass`/`fail`). backend-developer agents support DR and pre-check against these criteria before returning from DV:

| Area | What DR checks |
|------|----------------|
| API-contract adherence | Routes/payloads match the agreed OpenAPI/GraphQL/proto contract; status codes correct; versioning preserved; no breaking change to published shapes; pagination/filtering conventions honored |
| Error handling | Errors mapped to correct HTTP/gRPC status; no leaking of stack traces or internals to clients; structured error bodies; no swallowed exceptions; context cancellation/timeouts respected |
| Transaction correctness | Operations that must be atomic run in one transaction; correct isolation level; no partial writes on failure; outbox/saga used where cross-service consistency is needed |
| N+1 queries | No per-row queries in loops; eager-loading / batched joins / DataLoader used; query count bounded; indexes exist for new query predicates |
| Idempotency | Mutating endpoints that may be retried accept an idempotency key or are naturally idempotent; no duplicate side effects (double charge, duplicate send) on retry |
| Auth boundaries | Object-level (BOLA) and function-level (BFLA) authorization enforced server-side; no trust in client-supplied identity/role; tenant isolation checked on every data access |
| Migration safety | Migrations are reversible or forward-only by design; no destructive change without backfill plan; additive-then-backfill-then-switch for column changes; safe under concurrent old/new code (expand/contract) |

Template: [templates/dr-review.md](templates/dr-review.md).

## QA Gate for Backend Work

QA (`testing-N.md`, verdict `go`/`no-go`) passes only when **both** hold:

1. **All tests pass** — full suite, not just new tests, including integration tests against real dependencies (`vitest run` / `jest`, `go test ./...`, `mvn verify`, `uv run pytest`; Testcontainers spins up Postgres/Redis/Kafka where present).
2. **Security-scan clean (OWASP API Top 10) + integration tests green (Testcontainers where present)** — the dependency/vuln scan for the changed ecosystem is clean (`npm audit` / `osv-scanner` / `govulncheck` / `trivy`) and no OWASP API Top 10 regression is introduced (auth boundaries, rate limiting, injection, SSRF). For changes with no new dependency surface, the scan clause is satisfied by a clean scan of the unchanged lockfile; integration tests still must pass.

be-test-generator supports QA with framework-native generation (Vitest/Jest + supertest, Go `testing` + httptest, JUnit 5 + Testcontainers, pytest + httpx, RSpec). Template: [templates/qa-testing.md](templates/qa-testing.md).

## SR and RE Contributions

- **SR** — be-security-auditor provides platform context to igrsoft's security-reviewer: OWASP API Security Top 10 (2023) mapping (API1 BOLA, API2 broken auth, API3 BOPLA, API4 unrestricted resource consumption, API5 BFLA, API6 sensitive business flows, API7 SSRF, API8 misconfiguration, API9 inventory, API10 unsafe upstream consumption), injection review (SQL/NoSQL/command), secrets scan, supply-chain audit (`npm audit`, `osv-scanner`, `govulncheck`, `trivy`), and transport/config hardening (TLS, CORS, security headers, default-deny authz). Review-only: findings route to be-code-fixer for application.
- **RE** — release-engineer owns the stage; backend-developer contributes packaging: be-dependency-manager freezes lockfiles/pins (`package-lock.json`/`pnpm-lock.yaml`, `go.sum`, `gradle.lockfile`, `uv.lock`), and the language agents produce release artifacts (container images, version bumps, changelog entries) plus the migration ordering/rollback note recorded in `release-N.md`.

## Artifact Filename Contract (v3.36.0)

**Numbered `<stage>-N.md` names are canonical** per igrsoft's authoritative `handoff-protocol.md#stage-artifact-map`. N is allocated by PL0 (same value as `planning-N.md`), shared across all stages within a run, and propagated via `task.metadata.run_index`; it bumps on gate loop-back re-dispatch. Readers fall back to newest-glob (`<basename>-*.md`).

| Stage | Artifact | Owner |
|-------|----------|-------|
| PL | `planning-N.md` | product-manager |
| AR | `analyzing-N.md` | software-architector |
| TL | `coordination-N.md` | team-lead |
| DV | `development-N.md` | developer / backend-developer agents |
| DR | `developer-review-N.md` | technical-lead |
| SR | `security-review-N.md` | security-reviewer |
| QA | `testing-N.md` | qa-engineer |
| DC | `documentation-N.md` | technical-writer |
| RE | `release-N.md` | release-engineer |
| FN | `complete-summary-N.md` | project-manager |
| ST | `retrospective-N.md` | stakeholder |
| IR | `incident-N.md` | incident-responder |
| ET | `ethics-review-N.md` | ethics-reviewer |

**Emit `handoff:` frontmatter unconditionally — it is the merge input regardless of filename.** state.json reconciliation is three-layered: Layer 1 (agent runs `state-patch.sh --stage <CODE> --prev <PREV>` when its path is supplied, else skips — never a hand-rolled `jq`/manual merge), Layer 2 (orchestrator re-reads artifact frontmatter after `Task()` returns), Layer 3 (`SubagentStop` hook auto-merge). Attempt Layer 1; if the script or its path is absent, proceed — Layers 2 and 3 repair from frontmatter. An artifact without `handoff:` YAML breaks the safety net (degrades to F3 fallback: orchestrator derives a minimal handoff and logs WARN).

## Handoff Frontmatter (v3.36.0 schema)

Every stage artifact MUST start with a YAML block between `---` markers. Budgets: ≤200 tokens, ≤30 lines. Base required fields: `stage`, `verdict`, `summary` (≤200 chars), `refs`. Per-stage additions (from `handoff-protocol.md#frontmatter-schema`):

| Stage | Required beyond base | Verdict vocabulary |
|-------|----------------------|--------------------|
| DV | `files_touched`, `next_stage_focus` | ok / blocked / escalate |
| DR | `key_decisions` (= findings) | pass / fail |
| QA | `files_touched` (= tests added), `key_decisions` (= results) | go / no-go |

`key_decisions[].anchor` and `refs.*` MUST resolve to a real `## <kebab-case>` heading in the target file (anchor-lint enforces this at DR and via PostToolUse hook). Copy-paste blocks: `templates/` in this directory.

## Gate-Feedback Contract (v3.36.0)

When DR returns `verdict: fail` or QA returns `verdict: no-go`, the orchestrator re-dispatches DV (`run_index` bumped, `retry_count`++) and carries the upstream remediation **verbatim** into the retry prompt (igrsoft `worktask/SKILL.md` step 4.6). backend-developer agents **consume** this contract; the injection is orchestrator-owned.

| Surface | Mechanism | backend-developer action |
|---------|-----------|--------------------------|
| Orchestrator → DV prompt | On re-dispatch (`metadata.retry_count > 0`) the prompt is prepended with `REMEDIATION (from <DR\|QA> gate — fix these specific findings before re-stop:)`; `metadata.gate_from_stage` ∈ {DR, QA}; `metadata.gate_blockers[]` = DR `blockers[]` / QA `blocking_defects[]` strings. | Read both fields; fix those exact findings *first*; do not re-scope. |
| SubagentStop hook → next dispatch | A blocked gate emits `hookSpecificOutput.additionalContext` telling the next run what to fix. | Treat as additional remediation context; consume the same way. |

On a rework dispatch the DV/be-code-fixer agent MUST:

1. Read `metadata.gate_from_stage` + `metadata.gate_blockers[]` (and any `REMEDIATION` block in the prompt).
2. Address each listed blocker individually; record per-blocker resolution in `.context/errors/<agent-basename>.md`.
3. Keep the diff minimal — change only what the blockers require; do not re-implement passing code.

## Qualified Agent Names

All Task delegations MUST use the fully-qualified `plugin:agent` form:

| Form | Status |
|------|--------|
| `backend-developer:node-developer` | Required |
| `igrsoft:technical-lead` | Required |
| `node-developer` (bare) | Deprecated — back-compat shim prepends `igrsoft:` and logs a warning (would resolve to the wrong plugin) |

Task metadata carries qualified names:

```json
{
  "metadata": {
    "agent": "backend-developer:node-developer",
    "model": "sonnet",
    "error_file": ".context/errors/node-developer.md",
    "requires_screenshots": false,
    "plan_file": "planning-0.md",
    "run_index": 0
  }
}
```

## Token Budgets

- **Incoming compressed context** (from igrsoft): 300-500 tokens (planning summary 300, architecture summary 300, development handoff 500)
- **Full stage output**: write to `.context/<stage>-N.md` (no token cap)
- **Outgoing return summary**: 500 tokens max (for the orchestrator)
- **Inter-stage handoffs**: DV→DR 300, DR→QA 300 (`igrsoft:context-compression § Context Budget by Handoff`)

## Detecting Workflow Context

1. **Context folder**: `.context/` in project root, or `.worktrees/milestone-{N}/{issue#}/.context/` in worktree mode (resolve via `task.metadata.workspace_path` + `metadata.isolation`).
2. **Plan file**: (1) `task.metadata.plan_file`; (2) newest `.context/planning-*.md`.
3. **State ledger**: read `.context/state.json` for upstream `facts`/`handoffs`/`stages` (≤500-token canonical compressed view). Legacy fallback: `metadata.context_files`.
4. **Architecture document**: newest `.context/analyzing-*.md` — or the anchors named in upstream `next_stage_focus`.
5. **Task System**: TaskList/TaskGet; inspect `task.metadata.{plan_file, agent, model, run_index, error_file, gate_from_stage, gate_blockers, requires_screenshots, workspace_path}`.

## Dynamic Worktask Sizing (v3.36.0)

PL0 assesses complexity (0-50) and creates only the stages needed:

| Score | Complexity | PL0 Creates |
|-------|------------|-------------|
| 0-10 | Low | DV0, DR0, QA0 |
| 11-20 | Medium | AR0, DV0, DR0, QA0 |
| 21-30 | Moderate | AR0, TL0, DV0, DR0, QA0 |
| 31-40 | High | AR0, TL0, DV0, DR0, QA0, DC0, FN0, ST0 |
| 41-50 | Critical | AR0, TL0, DV0, DR0, SR0, QA0, DC0, RE0, FN0, ST0 |

Security-sensitive features (authentication, payment, PII, cryptography, secrets, file uploads, external API consumption) auto-include SR0 regardless of score.

PL0 stamps `metadata.skipped_stages = [{stage, reason}]` for every stage dropped from the full 9-stage pipeline (PL→AR→TL→DV→DR→QA→DC→FN→ST), so `state.json` self-documents the drops. It also stamps `metadata.test_mode` (`build-only` / `scoped` / `full` — defaulted by score and marker coverage) and `metadata.ui_visual_check` (the UI-capture provenance gate — **N/A for backend work**, left `false`; it gates live-driven UI capture on UI platforms only). The stage table above, the `test_mode` defaults, and these stamps are all defined by igrsoft `estimation-methodology § PL0 Stage-Set` (the source of truth) — keep them in lockstep with it so the next sync is a mechanical copy.

## MCP Dynamic Inheritance

Subagents inherit the parent session's MCP tools (Context7, Ref, etc.). Do not redeclare MCP tools in agent frontmatter when the parent session already provides them — redeclaration creates duplicates and bloats permission prompts.

## When Not in Workflow

If no workflow context is detected (no `.context/`, no task metadata), proceed with standard implementation: follow the language skills, run the same build/test/security discipline, and report results directly — no artifacts or frontmatter required.

## Related Skills (igrsoft plugin)

| Skill | Purpose |
|-------|---------|
| `igrsoft:worktask` | Complete worktask system documentation |
| `igrsoft:cross-plugin-handoff` | Handoff protocol between plugins |
| `igrsoft:agent-coordination` | Multi-agent coordination patterns |
| `igrsoft:context-compression` | Token budgets and compression techniques |
| `igrsoft:security-review-process` | SR stage OWASP checklists |
| `igrsoft:release-engineering` | RE stage versioning patterns |

## Related Skills (backend-developer plugin)

| Skill | Purpose |
|-------|---------|
| `_shared/model-selection.md` | Per-agent model/effort assignments and override paths |
| `_shared/severity-matrix.md` | P0-P3 finding priorities for DR/SR outputs |
| `_shared/testing-principles.md` | Test pyramid, framework matrix, QA coverage expectations |
| `_shared/language-detection.md` | Marker → runtime → agent routing for DV dispatch |
| `_shared/version-feature-matrix.md` | Canonical runtime/framework version + fallback lookup |
| `secure-coding` | Input validation and injection-safe patterns for SR readiness |
