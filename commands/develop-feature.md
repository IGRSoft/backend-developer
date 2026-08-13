---
description: Build a back-end feature end to end — design, implementation, tests, and an OWASP API security pass
argument-hint: [feature name or issue reference] [--stack node|go|jvm|python|ruby|php|dotnet] [--methodology traditional|tdd|bdd|ddd] [--complexity simple|medium|complex|epic] [--resume]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: opus
estimated-cost:
  min-tokens: 12000
  max-tokens: 60000
  model-distribution:
    haiku: 10%
    sonnet: 55%
    opus: 35%
---

# Feature Development
<!-- Updated: June 2026 -->

Take a back-end feature from a one-line request to reviewed, tested, security-checked code through four gated phases: **design** (`backend-developer:backend-architector`, pulling in `backend-developer:api-designer` and `backend-developer:database-engineer` when the feature touches a contract or a schema) → **implementation** (the stack developer for the detected runtime) → **tests** (`backend-developer:be-test-generator` — unit, integration, contract) → **security** (`backend-developer:be-security-auditor`, OWASP API Top 10 over the new surface). Each phase ends at an explicit PHASE CHECKPOINT that reports what changed and waits for approval, and each hand-off is gated on a green `/backend-developer:build-test`.

[Extended thinking: The failure mode this command exists to prevent is the one-shot feature — a single agent that designs, writes, and self-certifies in one pass, producing plausible code with an invented endpoint shape, an index nobody chose, no integration test, and an authorization check that reads correctly but scopes nothing. Splitting the work by role fixes the first half: the architect commits to service placement, data model, and contract shape *before* a line is written, so the implementer executes a decision rather than improvising one; a separate test generator writes tests against the contract instead of against the implementation it just produced; a separate auditor reviews a surface it has no authorship stake in. Phase checkpoints fix the second half: they are where a human catches "this should be a background job, not a synchronous endpoint" while it still costs one paragraph to change. The build gate between phases keeps the checkpoints honest — a checkpoint that reports progress on code that does not compile is worse than no checkpoint. Write each phase's output to disk; later phases read the files, not the context window, because the design decision that matters at the security pass was made three phases and many tokens ago.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Execute phases in order.** Do NOT skip ahead, reorder, or merge phases. Design before implementation, implementation before tests, tests before the security pass.
2. **Write output files.** Each step MUST produce its artifact under `.context/.feature-dev/` before the next step begins. Later phases read those files — do NOT rely on context-window memory for a decision made in an earlier phase.
3. **Stop at checkpoints.** At every `PHASE CHECKPOINT` you MUST stop and wait for explicit approval before continuing. Use AskUserQuestion with clear options (approve / revise / stop). A subagent returning is NOT approval.
4. **Gate every phase transition on a green build.** Run `/backend-developer:build-test` before each checkpoint from Phase 2 onward (with `--integration` from Phase 3 onward). A red gate blocks the checkpoint: report the failure and ask how to proceed. Never present a checkpoint over a broken build.
5. **Halt on failure.** If any step fails (agent error, red gate, missing dependency, unresolvable contract conflict), STOP immediately, present the error, and ask how to proceed. Do NOT silently continue or paper over it.
6. **The architect decides; the developer implements.** Service placement, data model, contract shape, and transaction boundaries are settled in Phase 1. If Phase 2 finds a design decision unworkable, it reports back for a design amendment — it does not redesign mid-implementation.
7. **Use designated agents only.** Every `subagent_type` comes from `backend-developer`, `corpflow`, `security-scanning`, or `general-purpose`. No other cross-plugin dependencies.
8. **One stack per run.** Detect (or accept `--stack`) exactly one runtime. A feature spanning two back-end services is two runs, or a run per service — do NOT interleave stacks in one implementation phase.
9. **Never enter plan mode autonomously.** Do NOT use EnterPlanMode. This command IS the plan — execute it.

## Usage

```bash
# Full pipeline from a feature description
/backend-developer:develop-feature "order webhooks with retry and idempotency"

# From a tracker reference
/backend-developer:develop-feature ENG-1421

# Force the stack in a polyglot monorepo
/backend-developer:develop-feature "tenant-scoped audit log" --stack go

# Test-driven: tests are authored against the contract before implementation
/backend-developer:develop-feature "refund endpoint" --methodology tdd

# Size the pipeline explicitly (drives depth, not phase count)
/backend-developer:develop-feature "bulk import pipeline" --complexity complex

# Resume an interrupted run from its last completed step
/backend-developer:develop-feature --resume
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `feature` | — | Feature name, description, or issue/tracker reference. Required unless `--resume`. |
| `--stack node\|go\|jvm\|python\|ruby\|php\|dotnet` | auto | Force the implementation stack instead of detecting it. Required when the repo is polyglot and detection is ambiguous. |
| `--methodology traditional\|tdd\|bdd\|ddd` | `traditional` | Shapes Phase 2/3 ordering and vocabulary. See Configuration Options. |
| `--complexity simple\|medium\|complex\|epic` | inferred | Sizing signal for Phase 1: how far the architect explores alternatives, plus the effort band in the summary. It does NOT remove phases, change the test tiers (Phase 3 always produces all three), or deepen the security pass. |
| `--resume` | off | Read `.context/.feature-dev/state.json` and continue from the last completed step instead of starting fresh. |

## Configuration Options

### Development Methodology

- **traditional** — implement, then generate tests against the contract and the implementation.
- **tdd** — Phase 3's unit + contract tests are authored *first*, against the Phase 1 contract, and Phase 2 implements until they pass. The phase order on disk is unchanged; the gate ordering inverts (tests red → implement → tests green).
- **bdd** — acceptance scenarios (Given/When/Then) are derived in Phase 1 and drive the integration tier in Phase 3.
- **ddd** — Phase 1 produces bounded contexts, aggregates, and an ubiquitous-language glossary; the domain model, not the transport layer, leads the design.

### Feature Complexity

- **simple** — one service, no schema change, one or two endpoints (1–2 days).
- **medium** — one service, schema change and/or several endpoints, one upstream integration (3–5 days).
- **complex** — cross-service, messaging or async workflow, migration with a rollout plan (1–2 weeks).
- **epic** — new service or bounded context, contract versioning, multi-team coordination (2+ weeks).

### Contract & Data Triggers

Phase 1 pulls in specialists based on what the feature touches — the architect makes the call and states it in the design doc:

| Feature touches | Specialist engaged in Phase 1 |
|-----------------|-------------------------------|
| A new or changed HTTP/GraphQL/gRPC endpoint, event schema, or webhook payload | `backend-developer:api-designer` |
| A new table/collection, a column/index change, or any migration | `backend-developer:database-engineer` |
| Neither (pure internal refactor-adjacent logic) | Architect alone |

## Pre-flight Checks

### 1. Check for an existing session

Check whether `.context/.feature-dev/state.json` exists:

- `status: "in_progress"` → read it, display the current phase/step, and ask whether to resume (`--resume` semantics) or start fresh.
- `status: "complete"` → ask whether to archive it (`.context/.feature-dev/archive/<timestamp>/`) and start fresh.

### 2. Detect the stack

Resolve exactly one runtime using the canonical `skill: language-detection` table — do not fork its routing logic:

| Markers | Stack | Phase 2 developer |
|---------|-------|-------------------|
| `package.json` with a server dep (express/fastify/nestjs/hono/koa) | Node.js / TypeScript | `backend-developer:node-developer` |
| `go.mod` | Go | `backend-developer:go-developer` |
| `pom.xml` / `build.gradle` / `build.gradle.kts` | JVM (Spring Boot) | `backend-developer:jvm-backend-developer` |
| `pyproject.toml` / `requirements.txt` / `uv.lock` (FastAPI/Django/Flask) | Python web | `backend-developer:python-backend-developer` |
| `Gemfile` | Ruby (Rails) | `backend-developer:ruby-developer` |
| `composer.json` | PHP (Laravel/Symfony) | `backend-developer:php-developer` |
| `*.csproj` / `*.sln` | .NET (ASP.NET Core) | `backend-developer:dotnet-developer` |

`--stack` overrides detection. If detection is ambiguous and `--stack` is absent, STOP and ask — do not guess (Rule 8).

### 3. Capture the baseline

Run `/backend-developer:build-test .` once before Phase 1. A red baseline is not fatal here (the feature has not started), but it MUST be recorded in `state.json` and reported at the first checkpoint so a later red gate is not misread as caused by this feature.

### 4. Initialize state

Create `.context/.feature-dev/` and `state.json`:

```json
{
  "command": "$ARGUMENTS",
  "feature": "{feature name}",
  "stack": "{detected or --stack}",
  "methodology": "{traditional|tdd|bdd|ddd}",
  "complexity": "{simple|medium|complex|epic}",
  "status": "in_progress",
  "current_phase": 1,
  "current_step": 1,
  "completed_steps": [],
  "files_created": [],
  "baseline_build": "{green|red}",
  "started_at": "ISO_TIMESTAMP",
  "last_updated": "ISO_TIMESTAMP"
}
```

Update `state.json` after every step. It is the resume point.

## Phase 1: Design

1. **Service placement, data model, and contract shape**
   - **Use Task tool with subagent_type="backend-developer:backend-architector" model="opus"**
   - Prompt: "Design the back-end feature: $ARGUMENTS. Stack: {stack}. Methodology: {methodology}. Complexity: {complexity}. Load `skill: microservices-patterns` for service boundaries, dependency direction, and hexagonal layering; load `skill: event-driven` if the feature involves messaging, async workflows, the outbox pattern, or consumer idempotency. Decide and justify: (1) **service placement** — which existing service owns this, or why a new module/service is warranted, and the dependency direction; (2) **data model** — entities, ownership, and the transaction boundary (which use case owns the unit of work, and what must NOT be inside it); (3) **contract shape** — the endpoints/events this exposes, at the level of resources, verbs, and payload semantics; (4) **idempotency and retry semantics** for every mutating path; (5) **failure modes** — what happens on partial failure, upstream timeout, and replay. State explicitly whether the feature touches an API contract (→ api-designer) and/or a schema (→ database-engineer). Do NOT write implementation code. Write the design to `.context/.feature-dev/01-design.md` with an explicit `Open Questions` section. {If ddd: 'Lead with bounded contexts, aggregates, and an ubiquitous-language glossary.'} {If bdd: 'Include Given/When/Then acceptance scenarios for each behaviour.'}"
   - Expected output: `.context/.feature-dev/01-design.md`
   - Context: feature request, existing service layout, baseline build state

2. **API contract** *(only when step 1 says the feature touches a contract)*
   - **Use Task tool with subagent_type="backend-developer:api-designer" model="sonnet"**
   - Prompt: "Specify the API contract for the feature designed in `.context/.feature-dev/01-design.md`. Load `skill: rest-design` for resource modeling, status codes, pagination, and idempotency keys; load `skill: openapi-contracts` for the spec artifact and `skill: api-versioning` if this changes an existing contract. Produce: resource/operation definitions, request and response schemas, the full status-code table including error envelopes, pagination and filtering conventions consistent with the existing surface, idempotency-key handling for mutating verbs, and auth/scope requirements per operation. Explicitly flag any breaking change to an existing contract and give the versioning or expand/contract path that avoids it. Check the new operations against the committed OpenAPI/GraphQL/proto spec for drift and inventory gaps (OWASP API9). Write to `.context/.feature-dev/02-contract.md` (and update the spec file in place if the repo commits one). Do NOT write handler implementation code."
   - Expected output: `.context/.feature-dev/02-contract.md` (+ spec file update)
   - Context: `01-design.md`, the repo's existing API surface and spec

3. **Schema and migration** *(only when step 1 says the feature touches a schema)*
   - **Use Task tool with subagent_type="backend-developer:database-engineer" model="sonnet"**
   - Prompt: "Design the schema change for the feature in `.context/.feature-dev/01-design.md`. Load `skill: schema-design` for normalization, constraints, and indexing, and `skill: migrations` for a safe rollout. Produce: table/collection definitions with column types and nullability, primary/foreign keys and the constraints that enforce the invariants from the design, an indexing plan justified by the actual query patterns this feature introduces (state the queries), and the migration as an expand/contract sequence that is safe against a running deployment — with an explicit backward-compatible window and a rollback. Call out any lock-taking DDL, any backfill and its batching strategy, and any query in the design that would be an N+1 or a full scan under the proposed indexes. Write to `.context/.feature-dev/03-schema.md` plus the migration files in the repo's migration directory. Do NOT run the migration."
   - Expected output: `.context/.feature-dev/03-schema.md` + migration files
   - Context: `01-design.md`, `02-contract.md` (if present), existing schema and migration history

4. **Design consolidation**
   - Merge the design, contract, and schema outputs into `.context/.feature-dev/04-design-final.md`: the decisions, the file-level implementation plan (what to create, what to modify), the invariants the implementation must uphold, and any remaining Open Questions. Resolve contradictions between the specialists now — a contract that assumes a field the schema does not provide is a Phase 1 defect, not a Phase 2 surprise.

---

### PHASE CHECKPOINT 1

**Completed:** Phase 1 — Design (service placement, data model, transaction boundary{, API contract}{, schema and migration plan}).

**Artifacts:** `.context/.feature-dev/01-design.md`{, `02-contract.md`}{, `03-schema.md`}, `04-design-final.md`

**Decisions to confirm:** service placement · transaction boundary · contract shape and breaking-change status · index plan and migration safety · idempotency semantics

**Open questions:** {list, or "none"}

**Next:** Phase 2 — Implementation with `backend-developer:{stack developer}`.

Stop here. Use AskUserQuestion to present the design decisions and open questions, and ask for approval to proceed, a revision, or a stop. Do NOT write implementation code before approval.

---

## Phase 2: Implementation

5. **Stack implementation**
   - **Use Task tool with subagent_type="backend-developer:node-developer"** — substitute the detected stack's developer: `backend-developer:go-developer`, `backend-developer:jvm-backend-developer`, `backend-developer:python-backend-developer`, `backend-developer:ruby-developer`, `backend-developer:php-developer`, or `backend-developer:dotnet-developer`.
   - Prompt: "Implement the feature specified in `.context/.feature-dev/04-design-final.md` (with `01-design.md`, `02-contract.md`, `03-schema.md` as the authoritative detail). Stack: {stack}. Methodology: {methodology}.

     Implement exactly the approved design. The service placement, data model, transaction boundary, and contract shape are settled — if any of them proves unworkable, STOP and report it as a design amendment request rather than redesigning here (Rule 6).

     Requirements for every path you write: validate untrusted input at the boundary; enforce object-level authorization on every fetch and mutation (ownership/tenant scoping — never trust an id from the request); honour the approved transaction boundary and keep remote calls outside it; make mutating paths idempotent per the design's key strategy; propagate cancellation/deadline context; return the contract's exact status codes and error envelope without leaking internals; emit structured logs and metrics with correlation ids; avoid N+1 queries against the approved index plan.

     Load the stack skill for idiomatic patterns and `skill: secure-coding` for the non-negotiable rules. Do NOT write tests (Phase 3 owns them) and do NOT change the API contract or schema. Report `{files_created[], files_modified[], design_deviations[], amendment_requests[]}`."
   - Expected output: working implementation; `.context/.feature-dev/05-implementation.md` summarizing files and any amendment requests
   - Context: `04-design-final.md` and its inputs

6. **Build gate**
   - Run `/backend-developer:build-test .`
   - **Green** → record it and continue. **Red** → halt per Rule 5: report the failing stage and the first error, and ask whether to route the fix back to the stack developer or to stop. Do NOT present Checkpoint 2 over a red build.

---

### PHASE CHECKPOINT 2

**Completed:** Phase 2 — Implementation ({n} files created, {m} modified) · `/backend-developer:build-test` ✅ green

**Changed:** {file list, grouped by layer — transport / application / domain / persistence}

**Design deviations:** {list, or "none"} · **Amendment requests:** {list, or "none"}

**Next:** Phase 3 — Tests (unit + integration + contract) with `backend-developer:be-test-generator`.

Stop here. Use AskUserQuestion to present the diff summary, the deviations, and the gate result, and ask for approval to proceed, a revision, or a stop.

---

## Phase 3: Tests

7. **Test generation**
   - **Use Task tool with subagent_type="backend-developer:be-test-generator" model="sonnet"**
   - Prompt: "Generate tests for the feature implemented in Phase 2. Design: `.context/.feature-dev/04-design-final.md`. Contract: `.context/.feature-dev/02-contract.md`. Implementation summary: `.context/.feature-dev/05-implementation.md`. Stack: {stack}. Load `skill: be-testing` for the pyramid, framework choice, and integration patterns, and `skills/_shared/testing-principles.md` for the quality gates and anti-patterns.

     Reuse the repo's existing framework, fixtures, and directory layout — do NOT introduce a second test framework. Produce three tiers:
     (1) **Unit** — domain and application logic in isolation: the business rules, the error taxonomy, boundary and edge cases, and the failure modes named in the design. No database, no network.
     (2) **Integration** — the real persistence and messaging path via Testcontainers (or the repo's existing equivalent): the transaction boundary actually rolls back, the migration applies, the queries hit the approved indexes without N+1, and idempotent paths produce exactly one effect when replayed.
     (3) **Contract** — every operation in `02-contract.md`: status codes, error envelope shape, request/response schema conformance, pagination, auth/scope enforcement, and idempotency-key behaviour. These test the contract, not the implementation's current shape.

     Cover authorization explicitly: for each protected operation, assert that a non-owner / other-tenant principal is denied — a passing happy path is not coverage. Write tests that fail for the right reason: assert on behaviour and contract, never on internal call order or log text. Report `{tests_added[], tiers_covered[], coverage_before, coverage_after, uncovered_paths[]}`. {If tdd: 'These tests were authored before the implementation; verify they now pass and report any that still fail as implementation gaps.'}"
   - Expected output: test files; `.context/.feature-dev/06-tests.md`
   - Context: `04-design-final.md`, `02-contract.md`, `05-implementation.md`

8. **Build gate (with integration)**
   - Run `/backend-developer:build-test . --integration`
   - **Green** → record pass counts and coverage delta. **Red** → halt per Rule 5. Distinguish the two cases before asking how to proceed: a failing test that reveals an implementation defect routes back to the stack developer; a failing test that encodes a wrong expectation routes back to `be-test-generator`. State which you believe it is and why.
   - If the Docker daemon is unavailable, the integration tier is *skipped, not failed* — record it as a known gap and say so at the checkpoint. Do NOT report full coverage you did not run.

---

### PHASE CHECKPOINT 3

**Completed:** Phase 3 — Tests ({u} unit, {i} integration, {c} contract) · `/backend-developer:build-test --integration` ✅ green

**Coverage:** {before}% → {after}% · **Skipped tiers:** {e.g. "integration — no Docker daemon", or "none"}

**Uncovered paths:** {list, or "none"}

**Next:** Phase 4 — Security pass (OWASP API Top 10) with `backend-developer:be-security-auditor`.

Stop here. Use AskUserQuestion to present the test summary, the coverage delta, and any skipped tier, and ask for approval to proceed, a revision, or a stop.

---

## Phase 4: Security

9. **OWASP API Top 10 pass over the new surface**
   - **Use Task tool with subagent_type="backend-developer:be-security-auditor" model="opus"**
   - Prompt: "Read-only security review of the feature surface added in Phases 2–3. Files: {files_created + files_modified from 05-implementation.md}. Contract: `.context/.feature-dev/02-contract.md`. Schema: `.context/.feature-dev/03-schema.md`. Load `skill: secure-coding` for the non-negotiable rules and `skill: api-security` for the API-specific checks.

     Cover the OWASP API Security Top 10 (2023) against **this feature's new surface**, not the whole repo: API1 broken object-level authorization (BOLA — is every fetch and mutation ownership/tenant-scoped?), API2 broken authentication, API3 broken object property-level authorization (mass assignment, over-exposure in responses), API4 unrestricted resource consumption (missing rate limits, unbounded queries, unbounded payloads/pagination), API5 broken function-level authorization, API6 unrestricted access to sensitive business flows (can this endpoint be automated to abuse the flow?), API7 SSRF (any URL taken from a request), API8 security misconfiguration, API9 improper inventory management (undocumented or drifted endpoints), API10 unsafe consumption of upstream APIs. Also cover injection (SQL/NoSQL/command), secrets in code or config, PII exposure in logs and error responses, and CVEs in any dependency this feature added.

     For each finding return `{file, line, category (API#/CWE), severity (P0-P3), why, fix, confidence}` and say whether Phase 3 has a test that would catch a regression of it. Do NOT edit any file. If the surface is clean, say so directly — do not manufacture findings."
   - Expected output: `.context/.feature-dev/07-security.md`
   - Context: implementation files, contract, schema, dependency changes

10. **Remediation** *(only when P0/P1 findings exist)*
    - **Use Task tool with subagent_type="backend-developer:be-code-fixer" model="sonnet"**
    - Prompt: "Apply minimal, targeted fixes for these P0/P1 security findings: {p0_p1_findings}. Minimal-diff gate: change only what each finding requires; do not refactor, reformat untouched code, or address P2/P3. Preserve behaviour outside the stated defect. If a finding needs a contract change, a schema migration, or a design decision, do NOT improvise — report it back for a design amendment. Report `{file, line, finding, change}` per fix and list anything you could not safely auto-fix."
    - Then add a regression test for each fixed finding via `backend-developer:be-test-generator`, and re-run `/backend-developer:build-test . --integration`.
    - P2/P3 findings are reported, not auto-fixed.

---

### PHASE CHECKPOINT 4 — Delivery

**Completed:** Phase 4 — Security ({P0} P0, {P1} P1, {P2} P2, {P3} P3){; {n} P0/P1 remediated and regression-tested}

**Final gate:** `/backend-developer:build-test . --integration` ✅ green

**Next:** hand off for review and merge — `/backend-developer:review-code` over the branch, then `/backend-developer:gen-docs` for the API docs if the contract changed.

Stop here. Use AskUserQuestion to present the security summary and the delivery report, and ask whether to finish, remediate further, or continue with follow-up work. On approval, set `state.json` `status: "complete"`.

---

## Output Format

```markdown
## Feature Delivery Report

**Feature:** {name / issue ref}
**Stack:** {stack} · **Methodology:** {methodology} · **Complexity:** {complexity}
**Status:** COMPLETE / STOPPED AT PHASE {n}
**Artifacts:** .context/.feature-dev/

| Phase | Agent(s) | Result | Gate |
|-------|----------|--------|------|
| 1 Design | backend-architector{, api-designer}{, database-engineer} | ✅ | — (baseline {green/red}) |
| 2 Implementation | {stack developer} | ✅ {n} files | build-test ✅ |
| 3 Tests | be-test-generator | ✅ {u}u/{i}i/{c}c | build-test --integration ✅ |
| 4 Security | be-security-auditor{, be-code-fixer} | ✅ {P0}/{P1}/{P2}/{P3} | build-test --integration ✅ |

### Design Decisions
- **Service placement:** {which service/module owns this, and why}
- **Data model:** {entities, ownership} · **Transaction boundary:** {which use case owns the unit of work}
- **Contract:** {operations added/changed} · **Breaking change:** {yes + versioning path | no}
- **Schema:** {tables/indexes} · **Migration:** {expand/contract steps, rollback} | none
- **Idempotency:** {key strategy per mutating path}

### Changes
| Layer | Files |
|-------|-------|
| Transport (handlers/controllers/resolvers) | {files} |
| Application (use cases/services) | {files} |
| Domain | {files} |
| Persistence (repositories/migrations) | {files} |
| Tests | {files} |

### Tests
| Tier | Count | Notes |
|------|-------|-------|
| Unit | {u} | {rules and edge cases covered} |
| Integration | {i} | {Testcontainers services; transaction/replay assertions} |
| Contract | {c} | {operations covered; authz-denial cases} |

**Coverage:** {before}% → {after}% · **Uncovered:** {paths, or "none"} · **Skipped tiers:** {reason, or "none"}

### Security (OWASP API Top 10, new surface)
| Severity | Category | File:Line | Finding | Status |
|----------|----------|-----------|---------|--------|
| P0 | {API#/CWE} | {file}:{line} | {why} | fixed + regression test / open |

**Clean areas:** {checks that found nothing — state them, do not pad the table.}

### Open Items
- **Design amendments requested:** {list, or "none"}
- **Deferred / follow-up:** {list, or "none"} → route to `{/backend-developer:command}`
```

## Error Handling

### Ambiguous stack
```
Error: More than one back-end stack detected and no --stack given.
Detected: {markers → stacks}
Suggestion: Re-run with --stack, e.g. /backend-developer:develop-feature "{feature}" --stack go
```

### Red baseline (pre-flight)
Not fatal. Record `baseline_build: "red"` in `state.json`, report the failing stage at Checkpoint 1, and note that Phase 2's gate must be judged against this baseline — the feature is not the cause. Offer to fix the build first via `/backend-developer:build-test` / `/backend-developer:fix-quick`.

### Red gate at a phase transition
```
Halted: /backend-developer:build-test failed after Phase {n}.
Failing stage: {install | build | unit-test | integration-test}
First error: {one line}   Log: .context/logs/build-{timestamp}.log
Likely owner: {stack developer | be-test-generator} — {why}
Next: choose — route the fix to that agent, or stop here.
```
Never present the checkpoint until the gate is green (Rule 4).

### Design amendment requested mid-implementation
Phase 2 stops and reports; the run returns to Phase 1 for the architect (and, if the contract or schema is affected, the relevant specialist) to amend `04-design-final.md`. The amended design re-enters Checkpoint 1. The stack developer never redesigns in place (Rule 6).

### Contract conflicts with schema
A Phase 1 defect, caught at consolidation (step 4). Return both artifacts to their authors with the specific contradiction. Do NOT proceed to Checkpoint 1 with a contract that assumes a field the schema does not provide.

### Docker daemon unavailable (Phase 3)
```
Warning: Integration tier requires a running Docker daemon, which is unreachable.
Unit and contract tiers ran; integration is SKIPPED, not failed.
This is a coverage gap in the delivery report — start Docker and re-run
/backend-developer:build-test . --integration before merging.
```

### Toolchain missing
`/backend-developer:build-test` prints its own install hints and never hard-fails on a missing toolchain. But a phase transition with no runnable gate cannot be certified: report the missing tool at the checkpoint, mark that transition as `ungated`, and ask whether to continue at reduced confidence or stop.

### Interrupted session
`state.json` is the resume point. `--resume` reads it, reports the last completed step and its artifacts, and continues from there — it does NOT re-run completed phases. If the artifacts referenced by `completed_steps` are missing, report the inconsistency and offer a fresh start instead of silently redoing work.

### Nothing to build
If the feature description resolves to no back-end work (pure front-end, docs-only, or config-only), say so and stop rather than manufacturing a service change.

## Success Criteria

- Design decisions (service placement, data model, transaction boundary, contract, idempotency) are recorded and were approved at Checkpoint 1 before any code was written.
- The implementation matches the approved design; every deviation is recorded and was approved.
- `/backend-developer:build-test . --integration` is green at the final gate.
- Unit, integration, and contract tiers all present; every protected operation has an authorization-denial test.
- No open P0/P1 security findings; each remediated finding has a regression test.
- Any breaking contract change has an explicit versioning or expand/contract path.
- Any migration is expand/contract-safe with a stated rollback.
- All four checkpoints were presented and explicitly approved.

## See Also

Skills the phases load:

- `skill: microservices-patterns` — service boundaries, dependency direction, hexagonal layering (Phase 1).
- `skill: event-driven` — outbox, sagas, consumer idempotency for async features (Phase 1).
- `skill: rest-design`, `skill: openapi-contracts`, `skill: api-versioning` — contract shape, spec artifact, and non-breaking evolution (Phase 1).
- `skill: schema-design`, `skill: migrations` — constraints, indexing, and expand/contract rollout (Phase 1).
- `skill: be-testing` and `skills/_shared/testing-principles.md` — pyramid, framework matrix, quality gates (Phase 3).
- `skill: secure-coding` and `skill: api-security` — OWASP API Top 10 and the non-negotiable rules (Phases 2 and 4).
- `skill: language-detection` — canonical marker → runtime → agent routing (keep the detection table in sync).

Related commands:

- `/backend-developer:build-test` — the gate run between every phase.
- `/backend-developer:review-code` — full multi-dimensional review of the resulting branch before merge.
- `/backend-developer:gen-api` — scaffold the endpoint layer from the Phase 1 contract when the feature is contract-first.
- `/backend-developer:db-migrate` — run and verify the migration Phase 1 designed.
- `/backend-developer:gen-tests` — add tiers after delivery, or backfill an area Phase 3 left uncovered.
- `/backend-developer:analyze-security` — a deeper standalone security pass when Phase 4 surfaces systemic issues.
- `/backend-developer:fix-refactor` — restructure existing code the design depends on, before Phase 2 rather than during it.
- `/backend-developer:gen-docs` — publish the API documentation once the contract is final.
- `/backend-developer:debug` — triage a red gate whose root cause is not in the first error.

Feature description: $ARGUMENTS
