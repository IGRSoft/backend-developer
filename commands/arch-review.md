---
description: Review a back-end codebase against its architecture pattern — boundaries, transactions, coupling, consistency, twelve-factor runtime contract
argument-hint: <file path, directory, PR number, or branch> [--pattern <name>] [--focus boundaries|transactions|consistency|coupling|runtime] [--scope module|service|platform]
allowed-tools: Read, Glob, Grep, Bash
model: opus
estimated-cost:
  min-tokens: 4000
  max-tokens: 24000
  model-distribution:
    haiku: 10%
    sonnet: 60%
    opus: 30%
---

# Architecture Review
<!-- Updated: June 2026 -->

Review an existing back-end codebase against the architecture it claims to follow. Detects the pattern actually in the code, then checks it for boundary violations, wrong-direction dependencies, transaction scope that spans owners, coupling that defeats the decomposition, and drift between the declared consistency model and what the code really guarantees. Findings are severity-rated P0-P3 with a concrete fix per finding. Read-only: it reports, it does not edit.

[Extended thinking: Architecture rots at the seams, not in the middle. The failure modes that matter in a back-end are structural and invisible to a linter — a repository imported straight into an HTTP handler, a domain module importing an adapter, a `@Transactional`/`BEGIN` block held open across a network call, two services writing the same table, an event consumer that is not idempotent while the delivery guarantee is at-least-once, a "microservice" that cannot deploy without three others. Each of those is a code-level fact you can find by reading imports, transaction scopes, and datastore access, and each is invisible if you only review diffs line by line. This command resolves the review scope once, detects the real pattern from evidence rather than from the README, evaluates the code against that pattern's specific anti-patterns, and ranks what it finds. The bias is toward the smallest fix that restores the boundary — an architecture review that ends in "rewrite it as microservices" has failed. A wholesale pattern change is recommended only when the mismatch is severe, and then always as a phased migration with named risk points.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve the scope once.** Apply the scope precedence (explicit target > working diff > branch/PR diff) exactly once, print the concrete file list, and pass that same list to the reviewer. Do NOT let the reviewer re-scope. Exclude vendored, generated, and build artifacts (`node_modules/`, `dist/`, `build/`, `target/`, `bin/`, `obj/`, `vendor/`, `.venv/`, generated clients, migration snapshots).
2. **Read-only.** This command and every agent it launches analyze only. They may write analysis artifacts under `.context/`, and nothing else. No source file is created or edited. Fixes are handed to `/backend-developer:fix-refactor` or `/backend-developer:review-code --fix` as a separate, explicitly-requested step.
3. **Detect from evidence, not from documentation.** The pattern reported is the one the imports, transaction scopes, and datastore access actually implement. A README, an ADR, or a `--pattern` flag is a *claim* to check the code against — when the claim and the evidence disagree, that disagreement IS a finding.
4. **Every finding cites `file:line`.** No finding without a concrete location and the evidence that establishes it. Speculative or vibes-based findings are dropped, not downgraded.
5. **Smallest fix that restores the boundary.** Each finding's fix is the minimal structural change that resolves the violation. Do NOT recommend a wholesale architecture switch unless the mismatch is severe, and when you do, scope it as a phased migration with explicit risk points — never as a single step.
6. **Severity comes from the matrix.** Rank every finding P0-P3 using `skill: severity-matrix`. Do NOT invent a scale.
7. **No manufactured findings.** If the codebase matches its pattern, say so plainly and report the clean result. Do NOT backfill P2/P3 nits to make the report look substantial.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Review the working tree changes against the codebase's architecture
/backend-developer:arch-review

# Review a whole service directory
/backend-developer:arch-review services/orders-api

# Review a single module
/backend-developer:arch-review src/billing/

# Review a PR or a branch against the base
/backend-developer:arch-review 142
/backend-developer:arch-review feature/split-checkout

# Assert the pattern the code is supposed to follow and check drift against it
/backend-developer:arch-review services/orders-api --pattern hexagonal

# Narrow the review to one concern
/backend-developer:arch-review src/ --focus transactions

# Platform-wide: check service boundaries across the repo
/backend-developer:arch-review . --scope platform
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `target` | working changes | File, directory, PR number, or branch to review. See Scope Resolution. |
| `--pattern <name>` | detected | Assert the intended pattern (`modular-monolith`, `microservices`, `hexagonal`, `layered`, `event-driven`, `cqrs`, `event-sourcing`, `saga-orchestration`, `saga-choreography`). Drift between the assertion and the evidence is reported as a finding. |
| `--focus boundaries\|transactions\|consistency\|coupling\|runtime` | all | Run one check family instead of all six. `boundaries` = module/layer/service boundaries and dependency direction; `transactions` = transaction scope and idempotency; `consistency` = declared vs actual consistency guarantees; `coupling` = shared state, cyclic deps, deploy coupling; `runtime` = the twelve-factor runtime contract (config, release promotion, statelessness, port binding, disposability). |
| `--scope module\|service\|platform` | inferred | Review altitude. `module` = inside one deployable; `service` = one deployable end to end; `platform` = cross-service boundaries, data ownership, and deploy coupling across the repo. |

## Pre-flight

1. Check session state: does `.context/.arch-review/arch-state.json` exist? If yes, resume from the last completed step.
2. Otherwise create `.context/.arch-review/` and initialize `arch-state.json` with the target, flags, and an empty step log.

## Step 1: Scope Resolution

Resolve the file set **once**, top-down — the first applicable rule wins.

1. **Explicit target** — a file, directory, PR number, or branch named on the command line.
   - File or directory → review those paths, plus their sibling module files needed to establish dependency direction.
   - PR number (bare integer) → `gh pr diff <N> --name-only` for the file list. If `gh` is unavailable, print the install hint and fall back to rule 3 against the PR's base branch.
   - Branch name → `git diff --name-only $(git merge-base HEAD <branch>)..<branch>`.
2. **Working changes** (no target) — `git diff --name-only HEAD` plus `git diff --cached --name-only`. This is the default.
3. **Branch/PR diff** (fallback) — diff the current branch against the default branch's merge-base.

For `--scope platform`, widen beyond the diff: also collect the structural surface — manifests, `Dockerfile`s, `docker-compose.yml`, k8s manifests, migration directories, and module/service index files — because deploy coupling and data ownership are not visible in a code diff.

Detect the runtime mix from the resolved list using `skill: language-detection`. Print the concrete file list, the detected stacks, and the review altitude before launching the reviewer.

Write: `.context/.arch-review/arch-input.json` — target paths, file count, stacks, scope altitude.

## Step 2: Pattern Detection

**Use Task tool with subagent_type="backend-developer:backend-architector"**

Prompt: "Detect the back-end architecture actually implemented in these files: {file_list}. Stacks present: {stacks}. Altitude: {module|service|platform}. Use your Architecture Detection signal table. Look for: one deployable with in-process module boundaries and a single transactional store (modular monolith); many deployables with per-service stores and network calls between owners (microservices); port/adapter interfaces (`interface`, `Protocol`, `trait`, abstract repository) wrapping DB/queue/external-API I/O (hexagonal); controllers → services → repositories with no datastore access in handlers (layered/clean); an `outbox` table, broker topics, consumer handlers (event-driven pub/sub); a separate write model plus projected read models, an append-only event store, replay logic (CQRS / event sourcing); a central coordinator issuing steps and compensations (saga orchestration); reactive event chains with no coordinator (saga choreography); an edge service aggregating downstreams and terminating auth (gateway/BFF). Also report, separately: the consistency model the code actually implements (single-store transactions and row locks → strong; idempotency keys, dedup tables, reconciliation jobs → eventual), the DI/wiring style, and the datastore ownership map (which module or service writes which tables/collections). Report: detected pattern, confidence (high/medium/low), and evidence as `file:line` references for each signal. {If --pattern given: 'The team asserts the pattern is {pattern} — report agreement or drift against the evidence.'} Do NOT edit any file."

Write: `.context/.arch-review/arch-detection.json` — pattern, confidence, evidence, consistency model, DI style, datastore ownership map, asserted-vs-actual drift.

## Step 3: Playbook Evaluation

Load the playbook matching the detected pattern and evaluate the code against it. Anchors: `skill: microservices-patterns` (monolith/microservices/hexagonal/layered), `skill: event-driven` (pub/sub, outbox, delivery semantics, choreography), `skill: cqrs-event-sourcing` (write/read split, event store, projections), `skill: saga-orchestration` (coordinator, compensations, saga state machines), `skill: schema-design` and `skill: orm-patterns` (ownership, transactions, N+1 by design), `skill: api-skills` and `skill: rest-design` (contract boundaries, versioning, idempotency), `skill: containerization` (the twelve-factor runtime contract — config, build/release/run, port binding, disposability).

Run these six check families (all by default; one when `--focus` is set):

### 1. Boundary violations

- A layer reaching past its neighbor: repository/ORM entity used directly in an HTTP handler or controller; SQL in a transport layer.
- The domain importing an adapter, a framework, or a driver — dependency direction pointing inward-out instead of outward-in.
- Internal models leaking across a published boundary: ORM entities serialized as the API response or the event payload instead of an explicit DTO/schema.
- Module or service internals imported across an owner boundary (deep imports past a package's public surface).
- Auth/authorization enforced below the boundary that owns it, or duplicated inconsistently across entry points.

### 2. Dependency direction and coupling

- Cyclic dependencies between modules, packages, or services.
- Shared mutable schema: two owners writing the same table, collection, or key space — the strongest structural defect a decomposed system can carry.
- Deploy coupling: services that cannot be released independently (lockstep versioning, a shared library carrying domain logic, a shared migration).
- A "shared kernel" package that has accumulated business logic instead of pure types.
- Chatty synchronous call chains: a request fanning out across several services in sequence, multiplying latency and failure surface.

### 3. Transaction scope

- A transaction held open across a network call, an HTTP request, a broker publish, or an external-API call.
- A write spanning two owners or two datastores without a saga or an outbox — the classic dual-write.
- A framework transaction that does not actually apply: Spring `@Transactional` defeated by self-invocation, a Django `atomic()` block that commits before the side effect, a Go `defer tx.Rollback()` that is missing or unreachable, an EF Core `SaveChangesAsync` outside the intended unit of work.
- Business invariants enforced in application code where the store offers no constraint, with no lock or uniqueness backing them.
- Read-modify-write races: a check-then-act on data with no row lock, optimistic version column, or unique constraint.

### 4. Consistency-model drift

- At-least-once delivery consumed by a handler that is not idempotent (no dedup key, no idempotency table, no natural upsert).
- Code that assumes exactly-once delivery, or a read-your-writes guarantee, that the chosen infrastructure does not provide.
- Producers writing to the store and the broker in the same logical step without an outbox — the event is lost or phantom when one half fails.
- Missing compensation for a saga step, or a compensation that is not itself idempotent and retryable.
- Projections and caches with no rebuild, no invalidation, and no reconciliation path.
- Mutating endpoints with no idempotency key on a network that will retry them.

### 5. Testability and operability seams

- No seam to substitute the datastore, broker, or external API — the boundary cannot be tested in isolation.
- No contract test for a published API, event payload, or proto that other owners consume.
- Structural N+1: an association or per-item fetch that the design guarantees will loop, independent of any single query.
- No correlation/trace ID crossing an async boundary, so a failed flow cannot be reconstructed (`skill: observability`).
- Health/readiness and graceful shutdown missing where the pattern requires them (a consumer that drops in-flight messages on deploy).

### 6. Runtime contract (twelve-factor)

The platform contract the service must satisfy to be deployable, scalable, and recoverable. Anchor: `skill: containerization`.

- State that outlives a request held in process memory or on local disk — an in-memory session map, sticky sessions, uploads or generated files written to the container filesystem, a per-process counter or cache treated as authoritative.
- Config read from a checked-in per-environment file, or code branching on an environment *name* (`NODE_ENV`, `SPRING_PROFILES_ACTIVE`, `RAILS_ENV`) to choose a datastore, credential, or endpoint — rather than each value arriving as its own env var.
- A backing service reached through a hardcoded host, or code that distinguishes a locally-run dependency from a managed one; swapping either must be a config change alone.
- A build that differs per environment, a release mutated in place, or a deploy identified by a moving tag (`:latest`) so the running version cannot be named or rolled back.
- Migrations, backfills, or other admin tasks run on application boot, or from an artifact built differently from the app's own release.
- A process that daemonizes, writes a PID file, or expects a webserver to be injected by the environment rather than binding a port itself; a listen port hardcoded rather than read from config, or bound to loopback only.
- Secrets or credentials sourced from the repository rather than injected at deploy time.

For `--focus`, run only the matching family and say so in the report.

## Step 4: Findings

Rank every finding with `skill: severity-matrix`:

| Severity | Meaning in an architecture review |
|----------|-----------------------------------|
| **P0 - Critical** | The boundary is broken in a way that loses or corrupts data, or defeats an authorization boundary — dual-write with no outbox, two owners writing one table, transaction spanning a network call, unenforced invariant on a money/stock path. |
| **P1 - High** | The pattern is defeated where it matters — cyclic dependency, domain importing an adapter, non-idempotent consumer under at-least-once delivery, ORM entity on a published contract, deploy coupling between nominally independent services. Also here: request-surviving state in process memory or on local disk, and sticky sessions — both pass every test on one instance and silently break the moment the service scales out or rolls. |
| **P2 - Medium** | Convention violation or missing seam — layering skipped, no contract test on a published boundary, structural N+1, missing correlation ID across an async hop. |
| **P3 - Low** | Naming, placement, or organization drift that does not yet threaten a boundary. |

### Finding format

```
[P{n}] {title}
  File: {path}:{line}
  Pattern: {detected pattern} — {violated rule from the playbook}
  Evidence: {the import, transaction scope, or access that proves it}
  Impact: {what breaks in production, concretely}
  Fix: {smallest structural change that restores the boundary}
```

## Step 5: Report

Write the final report to `.context/.arch-review/arch-review.md` and present the summary.

```markdown
## Architecture Review: {scope}

**Scope:** {resolved target — paths / PR# / branch}
**Files reviewed:** {N} ({stacks present})
**Altitude:** {module | service | platform}
**Checks run:** {all six families | --focus <family>}

### Detected Architecture
- **Structure:** {pattern} (confidence: {high/medium/low})
- **Consistency model (as implemented):** {strong | eventual | mixed}
- **Integration model:** {in-process | RPC | pub-sub+outbox | saga}
- **Evidence:** {file:line references}
- **Asserted vs actual:** {agreement, or the drift when --pattern was given or an ADR/README claims otherwise}

### Data Ownership Map
| Store / table group | Written by | Read by | Verdict |
|---------------------|-----------|---------|---------|
| {store} | {owner} | {readers} | {single-owner ✅ / shared ⚠️} |

### Verdict
**{PASS | WARN | FAIL}** — {FAIL on any P0; WARN on any P1; otherwise PASS}

| Priority | Count |
|----------|-------|
| P0 (boundary broken) | {n} |
| P1 (pattern defeated) | {n} |
| P2 (convention / seam) | {n} |
| P3 (drift) | {n} |

### P0 — Boundary Broken
{findings in the finding format}

### P1 — Pattern Defeated
{same}

### P2 — Convention / Missing Seam
{same}

### P3 — Drift
{same}

### Pattern Checklist
| Check | Result |
|-------|--------|
| Dependency direction points inward-out | ✅ / ❌ {file:line} |
| No module/service cycles | ✅ / ❌ |
| One writer per store/table group | ✅ / ❌ |
| No transaction spans a network call | ✅ / ❌ |
| Cross-owner writes use an outbox or a saga | ✅ / ❌ / N/A |
| Consumers are idempotent under at-least-once | ✅ / ❌ / N/A |
| Published contracts use explicit DTOs, not ORM entities | ✅ / ❌ |
| Each boundary has a substitution seam for tests | ✅ / ❌ |
| Services deploy independently | ✅ / ❌ / N/A |
| Config comes from the environment, not per-environment files | ✅ / ❌ |
| Processes are share-nothing (no local state, no sticky sessions) | ✅ / ❌ |
| One artifact promoted across deploys; releases are immutable | ✅ / ❌ |
| Port bound from config; `SIGTERM` drains in-flight work | ✅ / ❌ |
| Admin tasks run against the same release, not on boot | ✅ / ❌ / N/A |

### Top 3 Recommendations
1. {highest-leverage fix, with the finding it closes}
2. {…}
3. {…}

<!-- Only when the mismatch is severe: -->
### Migration Note
Current → target: {pattern → pattern}. Phases: {ordered, each independently deployable and testable}.
Risk points: {contract/back-compat, data migration and dual-write consistency, transaction and idempotency invariants, cross-service cycles}.
```

If the codebase matches its pattern, report that plainly — a clean review with the checklist filled in is a complete result.

## Error Handling

### No target and no changes
```
Note: No staged or unstaged changes to review.
Suggestion: Name a path, branch, or PR number, e.g. /backend-developer:arch-review services/orders-api
```

### No back-end sources in scope
```
Note: No back-end sources found in the resolved scope.
Resolved scope: {scope}
Suggestion: Pass an explicit path to the service or module you want reviewed.
```

### `gh` unavailable for a PR target
```
Warning: `gh` CLI not found; cannot fetch the PR diff directly.
Install: brew install gh   (then `gh auth login`)
Falling back to a branch diff against the default branch.
```

### Not a git repository
Not fatal. Scope resolution rules 2 and 3 need git; if it is unavailable, require an explicit path target and say so:
```
Note: Not a git repository — working-tree and branch scopes are unavailable.
Suggestion: Pass an explicit file or directory, e.g. /backend-developer:arch-review src/
```

### Pattern detection is low-confidence
Not an error, and often the most useful finding: an unclassifiable structure usually *is* the defect. Report the detected candidates with their evidence, state why the signals conflict, and run the checks that do not depend on the pattern (cycles, shared-store writers, transaction scope, idempotency). Say plainly that the codebase does not follow a coherent pattern rather than forcing a label onto it.

### Scope too narrow for the finding
Boundary and ownership defects need both sides visible. When a suspected violation's counterpart is outside the resolved scope, mark the finding `needs-wider-scope`, name the file that would confirm it, and suggest re-running at `--scope service` or `--scope platform`. Do NOT report an unconfirmed violation as confirmed.

### Ambiguous stack (polyglot monorepo)
Apply the `skill: language-detection` tie-break rules. Genuinely cross-boundary files route to `backend-developer:backend-developer` for classification; note the routing in the report.

## Related Commands

- `/backend-developer:arch-select` — choose the target pattern before, or after, this review says the current one does not fit.
- `/backend-developer:fix-refactor` — apply the structural fixes this review identifies.
- `/backend-developer:review-code` — line-level correctness and security review; use it alongside this structural pass.
- `/backend-developer:analyze-tech-debt` — quantify and prioritize the debt this review surfaces.
- `/backend-developer:analyze-security` — escalate a broken authorization boundary to a full OWASP API pass.
- `/backend-developer:db-migrate` — plan the safe migration when a finding requires a schema or ownership change.
- `/backend-developer:gen-tests` — add the contract and integration tests for boundaries that have no coverage.
- `/backend-developer:build-test` — the build gate; confirm the codebase still builds and tests green after any fix.
- `skill: severity-matrix` — the P0-P3 definitions used for ranking (`skills/_shared/severity-matrix.md`).
- `skill: architecture-skills` — architecture navigation entry point (`skills/architecture/SKILL.md`).
- `skill: microservices-patterns`, `skill: event-driven`, `skill: cqrs-event-sourcing`, `skill: saga-orchestration` — the playbooks driving Step 3.
- `skill: schema-design`, `skill: orm-patterns` — data ownership, transaction, and query-design checks.
- `skill: api-skills`, `skill: rest-design` — contract-boundary and idempotency checks.
- `skill: observability` — correlation and trace propagation across async boundaries.
- `skill: language-detection` — canonical marker → runtime → agent routing.
