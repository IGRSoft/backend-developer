---
description: Plan a back-end refactor with the architect, apply it with the code fixer, gate every step on a green build
argument-hint: [scope: file/dir/service — default: working changes] [--target extract-service|split-god-service|repository-port|transactions|orm-leakage|dedupe|typed-client|idempotency|break-cycle] [--dry-run] [--max-steps N] [--lang node|go|jvm|python|ruby|php|dotnet]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: opus
estimated-cost:
  min-tokens: 6000
  max-tokens: 34000
  model-distribution:
    haiku: 10%
    sonnet: 55%
    opus: 35%
---

# Refactor Under a Green-Build Gate
<!-- Updated: June 2026 -->

Restructure back-end code without changing its observable behaviour, using a strict two-role split: **`backend-developer:backend-architector` plans the refactor and never edits a file; `backend-developer:be-code-fixer` applies the plan step by step and never re-decides scope.** Every step is gated on a green `/backend-developer:build-test` run, and the command closes with a before/after ledger of what actually moved.

[Extended thinking: Back-end refactors fail in two distinct ways, and they need two distinct defences. They fail *structurally* when the person holding the editor also holds the design decisions — the boundary drifts mid-edit, "while I'm here" changes pile up, and the diff stops being reviewable. And they fail *behaviourally* when a service extraction quietly changes a transaction boundary, an added repository port swallows a `SELECT ... FOR UPDATE`, or de-duplicating two nearly-identical handlers erases a deliberate difference one caller depended on. This command answers the first failure with a hard role split: the architect produces an ordered, file-scoped step list and stops; the fixer executes exactly those steps and refuses anything not on the list. It answers the second with a build gate between every step — a baseline capture before the first edit, then `/backend-developer:build-test` after each step, and an immediate revert-and-report when a step goes red. The ledger at the end is the honest record: what moved, what the build said, and what was left alone. A refactor that cannot state its before/after in those terms is not finished.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **The architect never edits.** `backend-developer:backend-architector` runs read-only. It produces the plan — the ordered step list, the boundary decisions, the invariants — and nothing else. If the architect's output contains an applied edit, discard it and re-request the plan.
2. **The fixer never re-decides scope.** `backend-developer:be-code-fixer` executes the approved step list verbatim. It does not add steps, merge steps, rename beyond the step's stated renames, reformat untouched code, or "improve" adjacent code it happens to read. Anything the fixer believes is missing goes back to the architect as a plan amendment — it is never applied on the fixer's own authority.
3. **Capture a green baseline before the first edit.** Run `/backend-developer:build-test` before Phase 3. If the baseline is red, STOP and report — you cannot prove behaviour preservation against a broken build. Do not "fix the build first" as part of the refactor.
4. **One step, one build gate.** After each applied step, run `/backend-developer:build-test` (with `--integration` when the step touches persistence, transactions, or messaging). A red gate halts the run immediately: revert that step, record it in the ledger as `reverted`, and report. Do NOT batch steps to save a build.
5. **Behaviour is preserved, not improved.** A refactor step changes structure only. No new features, no bug fixes, no dependency upgrades, no API-contract changes, no schema changes. If a step cannot be done without altering behaviour or the wire contract, it is out of scope — the architect records it as a follow-up and the command reports it.
6. **The plan gate is explicit.** After Phase 2 you STOP and present the plan for approval before any edit. `--dry-run` ends the command there permanently.
7. **Report the ledger, always.** Even on an early halt, emit the before/after ledger covering the steps attempted, their build results, and the untouched remainder. A silent stop is a failure.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Refactor your current working changes (architect plans, fixer applies)
/backend-developer:fix-refactor

# Refactor a specific service directory
/backend-developer:fix-refactor services/orders-api/

# Refactor one oversized file
/backend-developer:fix-refactor src/services/OrderService.ts

# Plan only — print the step list and stop, no edits
/backend-developer:fix-refactor src/services/ --dry-run

# Named target: split a God service into cohesive collaborators
/backend-developer:fix-refactor src/services/OrderService.ts --target split-god-service

# Named target: push persistence behind a repository port (hexagonal)
/backend-developer:fix-refactor internal/order/ --target repository-port

# Named target: correct transaction boundaries that leak across the service edge
/backend-developer:fix-refactor src/main/java/com/acme/billing/ --target transactions

# Named target: remove ORM types from the domain layer
/backend-developer:fix-refactor app/domain/ --target orm-leakage

# Named target: replace ad-hoc HTTP calls with a typed client
/backend-developer:fix-refactor src/integrations/ --target typed-client

# Cap the blast radius of a large refactor
/backend-developer:fix-refactor services/ --target dedupe --max-steps 4

# Force the stack in a polyglot monorepo
/backend-developer:fix-refactor services/ --lang go
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working changes | File, directory, or service path to refactor. See Scope Resolution. |
| `--target <name>` | auto | Constrain the architect to one refactor target from the catalog below. Without it, the architect surveys the scope and proposes the highest-value targets it finds. |
| `--dry-run` | off | Run Phases 0–2 only: baseline, survey, plan. Print the step list and the projected ledger, then stop. No file is edited and the fixer is never invoked. |
| `--max-steps N` | 6 | Hard cap on applied steps in one run. The architect ranks the plan; steps beyond the cap are reported as deferred, not silently dropped. |
| `--lang node\|go\|jvm\|python\|ruby\|php\|dotnet` | auto | Force stack detection instead of inferring it. Use for polyglot monorepos or a mixed scope. |

`--dry-run` overrides `--max-steps` (nothing is applied). `--target` narrows the survey but never bypasses the plan gate.

## Refactor Targets

The architect selects from this catalog. Each target names the symptom that justifies it, the structural move, and what the build gate must prove.

| Target | Symptom in the scope | Structural move | Gate must prove |
|--------|---------------------|-----------------|-----------------|
| `extract-service` | One module owns two unrelated business capabilities; changes to one keep forcing redeploys of the other | Extract the cohesive capability into its own service/module with an explicit interface; callers move to that interface | Callers compile against the new interface; unit + integration suites green with no contract change |
| `split-god-service` | A single service/controller class exceeds coherent responsibility — dozens of public methods, mixed transport/domain/persistence concerns | Split by responsibility into collaborators (command handlers, query services, mappers); the original becomes a thin façade or disappears | Every method retains an identical call path and signature at the boundary; no behavioural branch dropped |
| `repository-port` | Domain/service code calls the ORM, query builder, or driver directly | Define a repository port (interface) owned by the domain; move the query implementation into an adapter behind it; inject the port | Same queries issued (verify N+1 profile unchanged); transaction scope unchanged; integration tests green |
| `transactions` | Transaction begins in the wrong layer — per-repository transactions where one unit-of-work is needed, or a transaction spanning an outbound HTTP call | Move the boundary to the use-case/application layer; make the unit of work explicit; pull remote calls outside the transaction | Integration tests green under `--integration`; rollback paths still roll back; no new lock-hold across I/O |
| `orm-leakage` | Entity/model types (JPA entities, Prisma models, ActiveRecord objects, EF entities) cross into the domain layer or out through the API | Introduce domain types and mapping at the adapter edge; strip ORM annotations/lazy proxies from domain code | Serialized responses byte-identical for the same inputs; no lazy-load triggered outside the adapter |
| `dedupe` | The same business rule is implemented in two or more services/handlers, drifting apart | Extract the shared rule into one owned module; both call sites delegate — after confirming the two copies were genuinely identical in behaviour | Both call sites' tests green; any behavioural difference found is reported, NOT unified |
| `typed-client` | Ad-hoc `fetch`/`http.Client`/`RestTemplate`/`requests` calls scattered across handlers, with hand-rolled URL building and error handling | Introduce one typed client per upstream: typed request/response models, centralized base URL/auth/timeout/retry, one error mapping | Same requests on the wire (method, path, headers, body); timeouts and retries at least as strict as before |
| `idempotency` | A mutating endpoint or message consumer can be safely retried in principle but is not idempotent in practice | Introduce an idempotency key (request header or message id), a dedupe store, and a replay-safe write path | Replayed request/message produces one effect and the original response; integration tests cover the replay |
| `break-cycle` | Module A imports B and B imports A (directly or transitively); build/test graph is tangled | Break the cycle by dependency inversion (extract the shared abstraction), by moving the misplaced member, or by introducing an event | Cycle detector clean; both modules build independently; no runtime init-order change |

Targets compose: extracting a service usually needs `break-cycle` first, and `repository-port` frequently precedes `transactions`. The architect orders them; the fixer does not reorder.

## Scope Resolution

Resolve the file set **once**, top-down — first applicable rule wins:

1. **Explicit args** — a file, directory, or service path named on the command line. Directories are walked; vendored/build artifacts are excluded (`node_modules/`, `dist/`, `build/`, `target/`, `bin/`, `obj/`, `vendor/`, `.venv/`, generated clients, committed migration snapshots).
2. **Working changes** (no args) — staged + unstaged tracked changes: `git diff --name-only HEAD` plus `git diff --cached --name-only`. This is the default and keeps the refactor tied to what you are already touching.
3. **Fallback** — if neither yields files, emit the "no refactorable sources" message and stop.

Print the concrete file list before Phase 1. The architect receives exactly this list; it does not re-scope. If the architect determines a step must touch a file outside the list (a caller that must be updated for the refactor to compile), it declares that file explicitly in the step's `touches` set and states why — the fixer may then edit it, and only it.

## Stack Detection

Detect the runtime from the resolved file list using the canonical `skill: language-detection` table — do not fork its routing logic.

| Markers in scope | Stack | Idiom notes the architect applies |
|------------------|-------|-----------------------------------|
| `.ts` / `.js` + `package.json` (server dep) | Node.js / TypeScript | Ports as interfaces + DI container or factory; Prisma/Drizzle/TypeORM confined to adapters; `$transaction` scope at the use-case layer |
| `.go` + `go.mod` | Go | Interfaces defined by the consumer package; adapters in `internal/`; `context.Context` threaded through the port; `sql.Tx` passed explicitly, not stashed in context |
| `.java` / `.kt` + `pom.xml` / `build.gradle` | JVM (Spring Boot) | Port interfaces in the domain package, `@Repository` adapters outside it; `@Transactional` on the application service (beware self-invocation bypassing the proxy) |
| `.py` + `pyproject.toml` (FastAPI/Django/Flask) | Python web | Protocol/ABC ports; SQLAlchemy session scope owned by the use case; Django querysets confined to a repository module |
| `.rb` + `Gemfile` | Ruby (Rails) | Repository/query objects over fat models; `ActiveRecord::Base.transaction` at the service object; callbacks are behaviour — moving them changes behaviour |
| `.php` + `composer.json` | PHP (Laravel/Symfony) | Interface + container binding; Eloquent/Doctrine behind the repository; `DB::transaction` at the action/handler |
| `.cs` + `.csproj` | .NET (ASP.NET Core) | Interfaces registered in DI; EF Core `DbContext` behind the repository; `SaveChangesAsync` scope owned by the use case |

`--lang` overrides detection. A scope spanning several runtimes is refactored one stack at a time — the architect plans per stack, and the fixer applies each stack's steps in sequence with its own build gates.

## Role Separation (enforced)

This is the core of the command. Both roles receive the same scope and the same target; only one of them can write.

| | `backend-developer:backend-architector` | `backend-developer:be-code-fixer` |
|---|---|---|
| Model | opus | sonnet |
| Writes files | **Never** | Only files listed in the current step's `touches` |
| Decides boundaries | Yes — module/service edges, port shape, transaction scope | **Never** |
| Decides step order | Yes | **Never** — executes the given order |
| Adds a step | Yes (as a plan amendment, before the gate) | **Never** |
| Handles a surprise (unexpected coupling, hidden caller) | Amends the plan and re-presents it | Stops, reports the surprise, returns control |
| Runs the build gate | No | No — the command runs `/backend-developer:build-test` between steps |

When the fixer reports a surprise, the run returns to the architect for an amendment, and the amended plan re-enters the gate. Never let the fixer improvise past a surprise; that is exactly how a "behaviour-preserving" refactor stops preserving behaviour.

## Workflow

### Phase 0: Baseline (Bash)

1. Resolve scope (see Scope Resolution) and print the file list.
2. Detect the stack (or honour `--lang`).
3. Record the baseline commit/dirty-state: `git rev-parse HEAD` and `git status --short`. A dirty tree is allowed (the default scope is your working changes) but is recorded so the ledger can distinguish pre-existing edits from refactor edits.
4. **Run the baseline gate:** `/backend-developer:build-test <scope-root>` — add `--integration` when the scope touches persistence, transactions, or messaging.
5. If the baseline is **red**, STOP (Rule 3) and emit the "red baseline" error. Do not proceed and do not fix the build as part of this command.
6. Record baseline metrics for the ledger where cheaply available: file/line counts of the scope, public surface (exported symbols) of the affected modules, test count and pass count, and the module dependency edges among the scope's files.

### Phase 1: Survey and Plan (architect, read-only)

**Use Task tool with subagent_type="backend-developer:backend-architector" model="opus"**

Prompt: "Read-only refactor plan for the {stack} sources: {file_list}. Target: {--target or 'survey and propose'}. Load `skill: microservices-patterns` for module/service boundary and dependency-direction rules, `skill: schema-design` when the scope touches persistence shape, and `skill: event-driven` when it touches messaging, the outbox, or idempotency. Baseline build is green; the baseline metrics are: {baseline_metrics}.

Produce an ordered, behaviour-preserving refactor plan. For each step emit exactly this contract:
- `id` — `S1`, `S2`, ... in execution order
- `target` — one of extract-service | split-god-service | repository-port | transactions | orm-leakage | dedupe | typed-client | idempotency | break-cycle
- `intent` — one sentence: the structural change
- `touches` — the exact file paths this step may edit, including callers outside the original scope (justify each such file)
- `mechanics` — the concrete moves (symbols extracted, interfaces introduced, call sites rewired), specific enough that a fixer needs no design judgment
- `invariants` — what MUST NOT change: wire contract, status codes, query count/shape, transaction scope, lock ordering, error taxonomy, log/metric names
- `gate` — `build-test` or `build-test --integration` (use `--integration` whenever the step touches persistence, transactions, or messaging)
- `risk` — low | medium | high, with the specific failure mode
- `rollback` — how to undo this step alone

Rules: do NOT edit any file. Do NOT propose feature changes, bug fixes, dependency upgrades, API-contract changes, or schema changes — those are out of scope and belong in `follow_ups`. Order steps so each leaves the tree buildable on its own (break cycles before extracting; introduce the port before moving the transaction boundary). Cap the plan at {max_steps} applied steps — the value of `--max-steps`, default 6 — and list the remainder as `deferred`. For `dedupe`, first prove the duplicates are behaviourally identical; if they differ, do NOT propose unifying them — report the difference. Return: `{steps[], deferred[], follow_ups[], projected_ledger}`."

The architect's output is the plan. Nothing has been edited.

### Phase 2: PLAN GATE

---

**Completed:** Phase 0–1 — green baseline captured, refactor plan produced ({N} steps, {M} deferred).

**Next:** Phase 3 — apply steps one at a time, each gated on `/backend-developer:build-test`.

Present the step table (id, target, intent, touches, gate, risk) plus `follow_ups`, then **stop and wait for explicit approval**. Use AskUserQuestion with options to approve the full plan, approve a subset of step ids, or cancel.

If `--dry-run` is set, the command ends here — print the plan and the projected ledger and stop.

---

### Phase 3: Apply (fixer, one step at a time)

For each approved step `Sn`, in order:

1. **Delegate exactly one step.**

   **Use Task tool with subagent_type="backend-developer:be-code-fixer" model="sonnet"**

   Prompt: "Apply refactor step {id} and nothing else. Intent: {intent}. Mechanics: {mechanics}. You may edit ONLY these files: {touches}. Invariants that MUST hold after your change: {invariants}.

   Minimal-diff gate: make only the moves the mechanics describe. Do NOT reformat untouched code, rename beyond the stated renames, add or remove tests, change dependencies, alter the wire contract or DB schema, or apply any other step from the plan. This is a behaviour-preserving structural change — no feature work, no bug fixes, even if you spot one.

   If the step cannot be completed as written (a hidden caller, an unexpected cycle, a transaction that cannot move without changing scope, or an invariant you cannot uphold), STOP, revert your partial edits, and report the obstacle. Do not improvise a different design — that decision belongs to the architect.

   Return: `{files_changed[], symbols_moved[], call_sites_rewired[], invariants_upheld[], obstacle_or_null}`."

2. **Run the gate:** `/backend-developer:build-test <scope-root>` (append `--integration` when the step's `gate` says so).

3. **Green** → record the step in the ledger as `applied`, capture the post-step metrics, then continue to the next step **only while fewer than `{max_steps}` steps have been applied in this run**. On reaching the cap, stop the loop and record every remaining step as `deferred (over --max-steps)` — the cap is a hard stop, not a suggestion.

4. **Red** → halt immediately (Rule 4):
   - Revert this step's files to their pre-step state (`git checkout -- <touches>` when the baseline was clean, otherwise restore from the recorded pre-step copies).
   - Re-run the gate to confirm the tree is green again.
   - Record the step as `reverted` with the first build/test error.
   - Do NOT attempt the next step: a failed step usually invalidates the ones ordered after it. Return the failure to the architect for a plan amendment and re-enter Phase 2.

5. **Fixer reports an obstacle** (no edits landed) → record the step as `blocked`, return to the architect for an amendment, and re-enter the plan gate with the amended step. Never let the fixer resolve it.

### Phase 4: Ledger

Emit the Output Format report: every step with its result, the before/after metrics, the invariants verified by the gate, and everything deliberately left alone (deferred steps and follow-ups).

## Output Format

```markdown
## Refactor Ledger

**Scope:** {resolved scope} — {N} files ({stack})
**Target(s):** {targets planned}
**Baseline:** {commit} — build-test {✅ green} {(+integration)}
**Plan:** {N} steps approved, {M} deferred, {K} follow-ups
**Result:** COMPLETE / PARTIAL ({n} applied, {r} reverted, {b} blocked) / PLAN ONLY (--dry-run)

### Steps

| Step | Target | Intent | Files touched | Gate | Result |
|------|--------|--------|---------------|------|--------|
| S1 | {target} | {one line} | {n files} | build-test{ --integration} | ✅ applied |
| S2 | {target} | {one line} | {n files} | build-test | ❌ reverted — {first error} |
| S3 | {target} | {one line} | — | — | ⛔ blocked — {obstacle} |

### Before / After

| Metric | Before | After | Δ |
|--------|--------|-------|---|
| Files in scope | {n} | {n} | {±} |
| Largest module (lines) | {n} | {n} | {±} |
| Public surface of affected modules (exported symbols) | {n} | {n} | {±} |
| Direct ORM/driver references in domain code | {n} | {n} | {±} |
| Transaction boundaries below the use-case layer | {n} | {n} | {±} |
| Duplicated implementations of the shared rule | {n} | {n} | {±} |
| Module dependency cycles | {n} | {n} | {±} |
| Tests (passing / total) | {p}/{t} | {p}/{t} | {±} |

### Invariants Verified

- Wire contract unchanged: {how confirmed — contract tests / unchanged handler signatures / unchanged OpenAPI}
- Transaction scope: {unchanged, or moved deliberately by step Sn as planned}
- Query profile: {unchanged — no new N+1; or the specific change and why it is equivalent}
- Error taxonomy / status codes: {unchanged}

### Deferred (over --max-steps or ordered after a halt)
- {id}: {intent} — {why deferred}

### Follow-Ups (out of scope for a refactor)
- {finding — a bug, a contract change, a migration, a dependency upgrade} → route to `{/backend-developer:command}`

### Untouched
{Files in scope the plan deliberately did not change, and why.}
```

## Error Handling

### Red baseline
```
Error: Baseline build-test is RED — cannot prove a refactor preserves behaviour.
Failing stage: {install | build | unit-test | integration-test}
First error: {one line}
Suggestion: Get the build green first (/backend-developer:build-test, or /backend-developer:fix-quick
for mechanical failures), then re-run /backend-developer:fix-refactor.
```

### No refactorable sources in scope
```
Note: No back-end sources found in the resolved scope.
Resolved scope: {scope}
Suggestion: Pass an explicit path, e.g. /backend-developer:fix-refactor services/orders-api/
```

### Nothing worth refactoring
Not an error. If the architect's survey finds no target that justifies its risk, report that plainly and stop — do not manufacture a refactor to fill the plan. Say which targets were considered and why each was rejected.

### Step reverted by the build gate
Halt per Rule 4, then report:
```
Halted: step {id} turned the build RED and was reverted.
Failing stage: {stage} — {first error}
Tree restored to: {pre-step state}, gate re-run: {✅ green}
Remaining steps ({ids}) were NOT attempted — a failed step invalidates the order after it.
Next: returning the failure to backend-architector for a plan amendment.
```

### Fixer reports an obstacle
```
Blocked: step {id} could not be applied as written.
Obstacle: {hidden caller | unexpected cycle | transaction scope cannot move | invariant unupholdable}
No edits landed. Returning to backend-architector for a plan amendment (Rule 2 — the fixer does
not redesign).
```

### `--target dedupe` finds a behavioural difference
Not an error, and not something to unify. Report both implementations, the exact difference, and the callers affected; leave the code alone. A "duplicate" that behaves differently is two features wearing one name.

### Scope spans several stacks
Plan and apply one stack at a time, each with its own gates. Report per-stack ledgers under one summary. Do not interleave edits across stacks in a single step.

### Build tooling missing
`/backend-developer:build-test` prints its own install hints and never hard-fails on a missing toolchain — but a refactor **cannot proceed without a gate**. If no gate can run for the detected stack, stop after Phase 2 and report the plan as `--dry-run` output with the missing-tool reason.

## See Also

Skills the phases load:

- `skill: microservices-patterns` — module/service boundaries, dependency direction, hexagonal ports and adapters; the architect's primary reference.
- `skill: event-driven` — outbox, sagas, and consumer idempotency for the `idempotency` and messaging-adjacent targets.
- `skill: schema-design` — constraints and indexing implications when a refactor moves persistence behind a port.
- `skill: be-testing` — what the gate must cover; contract and integration tests as the behaviour-preservation proof.
- `skill: language-detection` — canonical marker → runtime → agent routing (keep Stack Detection in sync).
- `skills/_shared/severity-matrix.md` — P0–P3 and the effort/impact quadrant used to rank the plan.

Related commands:

- `/backend-developer:build-test` — the gate this command runs before the first edit and after every step.
- `/backend-developer:review-code` — review the resulting diff before merging; run it after the ledger, not instead of it.
- `/backend-developer:analyze-tech-debt` — quantify and prioritize debt first when you do not yet know which target is worth the risk.
- `/backend-developer:arch-review` — when the survey concludes the problem is the architecture itself, not the code shape.
- `/backend-developer:arch-select` — choosing the target architecture before an `extract-service` refactor.
- `/backend-developer:fix-quick` — mechanical formatting/lint fixes; run those first so they do not pollute the refactor diff.
- `/backend-developer:fix-performance` — when the real goal is latency or throughput, not structure.
- `/backend-developer:db-migrate` — any schema change a follow-up identifies; never inside a refactor step.
- `/backend-developer:gen-tests` — add characterization tests before refactoring a module the suite barely covers.

If the survey finds nothing worth the risk, say so directly instead of manufacturing a refactor.
