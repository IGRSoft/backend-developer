# Changelog

All notable changes to the backend-developer plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] — 2026-08-31

The plugin taught every stack how to build a container and how to secure a handler, but not what contract the running process owes its platform. Config doctrine, build/release/run separation, port binding, and statelessness had no home at all; graceful shutdown existed for Go and Node and for no other stack. A service could pass review and still lose every session on a scale-in, drop in-flight requests on each deploy, or ship an artifact that was rebuilt rather than promoted. This release encodes the twelve-factor manifesto's 33 normative principles as checkable rules and wires them into the paths that actually gate work.

### Added

- **`skills/tooling/containerization/references/runtime-contract.md`** — the four factors that had no home. Config from environment variables validated at boot (with the open-source litmus test and the ban on environment-grouped config); build/release/run as three stages with immutable, append-only releases promoted as one artifact; `$PORT` read from config and bound on `0.0.0.0`; and **per-stack `SIGTERM` shutdown for Spring Boot, FastAPI/uvicorn, Puma, ASP.NET Core, and PHP-FPM** — the five stacks that previously had no shutdown guidance anywhere in the plugin.
- **Twelve-factor rules distributed to the skills that already own each factor.** `microservices-patterns` gained codebase-to-app 1:1, backing services as attached resources, and a Stateless Processes section (sticky sessions and local-disk storage named as violations, with five new Diagnostics rows); `caching-strategies` gained session and per-request state externalization; `migrations` gained Admin Processes Run Against the Release, including the rule against migrating on application boot; `observability` completed factor XI with the "the app never manages logfiles" half; `secure-coding` gained the config-in-the-environment litmus test; `containerization` gained a sixth doctrine rule, declare-and-isolate dependency guidance, and dev/prod parity promoted from an aside to a stated rule.
- **Enforcement in `agents/_base/backend-agent.md`** — a Constraints bullet and a Mandatory Requirements row, so all seven stack agents inherit the contract rather than relying on a skill being consulted.
- **`/backend-developer:arch-review`** — a sixth check family (Runtime contract), a `--focus runtime` value, five new Pattern Checklist rows, and P1 severity assigned to request-surviving in-process state and sticky sessions, which pass every single-instance test and break on the first scale-out.
- **`/backend-developer:analyze-tech-debt`** — the Operational debt taxonomy grows from 3 rows to 10, and the operational probe now loads the containerization skill alongside observability.
- **`/backend-developer:review-code`** — a runtime-contract clause stated once in the Phase 1 preamble and applied by all seven stack reviewers, rather than duplicated into seven per-language focus lists.

### Fixed

- **`skills/_index.md` was entirely stale.** Every path in it pointed at a skill tree that no longer exists (`node/node-service-patterns`, `go/go-testing`, `jvm/spring-boot-patterns`, `data/migrations-queries`, `architecture/service-architecture`, `quality/testing-strategy`, `quality/review-gates`), and it claimed 21 SKILL.md. Root `skills/SKILL.md` links to it as the "full navigation index", so every reader who followed that link landed on dead paths. Rewritten against the real 41-skill tree; all 90 links verified to resolve.
- **`skills/SKILL.md` claimed "Total: 42 SKILL.md"** — the actual count is 41.
- **`CORPFLOW.md` repeated its `Size budget` row three times** with conflicting values (≤260, ≤280, ≤280). Reduced to one row at ≤280, the only value the 273-line file satisfies. Note that no sibling plugin and not the corpflow template carries this row at all.
- **Version strings had drifted apart** across the five sites MEMORY.md requires to move together: `plugin.json` said 1.4.3, `marketplace.json` said 1.4.1, and the README header said 1.4.0. All five now read 1.5.0.

## [1.4.3] — 2026-08-15

### Fixed

- **`CORPFLOW.md` now states the build/test contract, and no longer contradicts it.** The seam
  file said nothing about how to build or test, so a sibling agent denied by corpflow's
  test-execution gate had no sanctioned next step. In a measured four-platform run two streams
  were denied, both invented `--build-only` (not a real flag on any plugin's command, so it
  classifies as a full test run and is denied again), and both then fell back to invoking the
  toolchain directly — which `agents/developer.md` forbids. The file now says: build and test
  only through this plugin's `build-test` command, pass `--no-test` when you only need to
  compile, and if the gate still denies you, record `requests_test_evidence` or return
  `verdict: blocked` — never reach for the toolchain.

- **Added a worktree-isolation section.** A sibling dispatched for DV runs in an isolated
  worktree, and the file previously said only "Write to `.context/`. Nothing else in the
  repository is yours to create" — which is wrong for DV, and silent on the tree check. Two
  agents in identical situations resolved it differently: one blocked correctly, one entered a
  different worktree and relocated its tree. The file now states that a resolved-vs-assigned
  mismatch means stop and report, that agents neither create nor move worktrees, and that the
  pin must be re-confirmed before each write batch rather than only at entry.

- **Named the authoritative screenshot manifest.** `state.json facts.screenshots` is capped and
  merged last-writer-wins, so in a multi-stream run it reflects one stream and drops the rest.
  A stream discovered this alone and invented its own ledger key to avoid erasing a sibling's
  rows. The file now directs captures to the run's `screenshots.md` manifest and says not to
  read or write the ledger key.

- **Stated that returning is what settles a stage.** The completion patch keys on the return
  summary; reporting out of band does not mark a stage complete. A stage that finished its work
  and reported by message left its artifact on disk while the ledger still read `in_progress`.

- **Corrected the `## Artifacts` scope line** so it no longer tells a DV agent that nothing
  outside `.context/` is its to create.

## [1.4.2] — 2026-08-15

### Fixed

- **Audit rows are no longer duplicated across installed plugins.** Every installed dev
  plugin registers its own copy of `hooks/audit-tooluse.sh` and `hooks/audit-subagent.sh`,
  and all of them fire on the same event, so one tool call was recorded six times — twelve
  for subagent-stop, which fires twice per stop. A measured five-hour run produced 2,837
  audit rows of which 2,265 (80%) were advisory duplicates, and every reader of
  `audit.jsonl` paid to parse them.

  `metadata.dedupe_key` was already present and already identical across all copies, and
  nothing consulted it at write time. A reconciler does exist — corpflow's
  `skills/agent-coordination/scripts/audit-dedup.sh`, which keeps the `hook:*` row and drops
  agent rows for the same key — but it is a **read-time filter invoked only by
  `/cost-report`**, not the automatic "audit-dedup hook" these headers name. So the rows still
  accumulate on disk in full, and every other reader of the trail pays for them.

  Both hooks now reconcile at the point of writing: if the key is already present in the tail
  of `audit.jsonl`, the advisory row is dropped. This is consistent with `audit-dedup.sh` —
  the canonical `hook:*` row is never suppressed, so a later read-time dedup still resolves
  every group the same way.

  The canonical orchestrator row is never suppressed — it is written by a different hook
  that carries no advisory flag and performs no such check. Distinct events are unaffected;
  only exact `dedupe_key` repeats are dropped.

## [1.4.1] — 2026-08-15

### Changed

- corpflow contract: the worktask state ledger moved from `stages.<CODE>` to `tasks.<ID>`
  (`state.json` `version: 2`), so `CORPFLOW.md` names the new path. corpflow retired Claude Code's
  Task System after CC 2.1.233 removed those tools on every model it dispatches.
- `hooks/README.md`: corpflow's audit hook now matches `Write|Edit|Bash`, recording Bash rows only
  for ledger patches.

## [1.4.0] — 2026-07-29

Polyglot-consistency audit. Hunts one defect class: a rule true for *some* of the
seven advertised stacks, stated as though it held for all of them. Nothing here
adds a stack — the fixes either extend a claim to the ecosystems it already
promised, or narrow the claim to what is actually implemented.

### Fixed

- **`be-code-fixer` could not execute its own Ruby, PHP, or .NET playbooks.** Its
  description and playbook tables covered all seven stacks, but the `tools:` grant
  stopped at Node/Go/JVM/Python — so `rubocop -A` and `php-cs-fixer fix`, both
  prescribed verbatim in the playbooks, were ungranted, and .NET had no build,
  format, or test binary at all. A fix on those three stacks silently degraded to
  hand-editing with no verification gate. Added `bundle`, `rubocop`, `rspec`,
  `php`, `composer`, `php-cs-fixer`, `phpunit`, and `dotnet`, plus the matching
  per-stack verify and narrowest-covering-test commands (which also stopped at
  Python) and a .NET formatting row.
- **`be-dependency-manager` claimed Ruby and implemented none of it.** Ruby was
  named in the description and opening line, then absent from every content path:
  no Bundler row in the ecosystem table, no `Gemfile.lock` in the CVE scan list,
  the hand-edit ban, or the release-freeze lock modes, no `bundler` in either
  enum, and no `bundle` grant. Added the Bundler row, guidance bullet,
  `bundle-audit` scan path, and grant throughout.
- **`deps --upgrade` silently did the opposite of what it advertised.** The
  Options table documented it as an alias for the `upgrade` subcommand, but the
  dispatch rule routes any flag first-token to read-only `audit` — so
  `deps --upgrade lodash` reported an audit while the caller believed a pinned
  upgrade had run. Removed the dead alias; a flag-form subcommand now stops with
  an explicit error rather than falling through to `audit`.
- **`analyze-accessibility`'s four category flags did nothing.** `--html`,
  `--emails`, `--errors`, and `--metadata` appeared only in the Options table and
  Usage examples; the workflow derived its categories purely from content
  detection, so a restricted run reported every category anyway. The flags now
  resolve `{active_categories}` and override detection, and are named in
  `argument-hint`.
- **`fix-refactor --max-steps` was a report label, not a cap.** The value reached
  the architect prompt but was bound nowhere and unenforced in the apply loop, so
  a longer plan applied every step. Bound the placeholder to the flag and made the
  loop stop at the cap, deferring the remainder.
- **`debug --stack` was advertised as an override and never honored.** Stack
  Detection delegated unconditionally. It now short-circuits detection in both
  configure and triage mode.
- **`develop-feature --complexity` promised two effects it does not have.**
  Narrowed the Options text: Phase 3 always produces all three test tiers and the
  security pass has no complexity branch. Claim now matches behavior.
- **README credited `be-dependency-manager` with Cargo/Rust**, an ecosystem the
  plugin does not support anywhere — no agent, no detection marker, no grant.
  Replaced with the ecosystems it actually handles.
- **26 references pointed at skills and commands that do not exist.** Most were
  load-bearing: eleven `skill: stack-detection` pointers (real name:
  `language-detection`) sat next to instructions to "keep this list in sync with
  it, do not fork the routing logic" — unfollowable, and the forking they forbid
  was the likely outcome. Also `testing-strategy` → `testing-principles` (5),
  `migration-detection`/`zero-downtime-migrations` → `migrations` (3),
  `api-contracts` → `openapi-contracts`, `rest-contracts` → `rest-design`,
  `api` → `api-skills`, and path-style `skill: <dir>/<name>` refs normalized to
  bare names. `ruby-developer` pointed at three Ruby skills that were never
  written (`ruby-testing`, `rails-concurrency`, `activerecord-patterns`) and
  `gen-tests` at system-developer's `build-systems`; these were narrowed to the
  real cross-stack homes rather than fabricating single-stack skills. Dangling
  command refs `api-test`, `security-review`, `db-schema`, and `fix` retargeted.

### Verified clean

`skills/_shared/testing-principles.md`, `skills/_shared/language-detection.md`,
and `skills/_shared/secure-coding/` each carry genuine per-stack rows for all
seven languages — the neutral-named shared files are not single-stack.
`commands/db-migrate.md` resolves twelve migration tools across all seven
ecosystems, and `commands/gen-api.md` explicitly narrows its `--stack` list and
documents the hand-roll path for the three stacks without first-party codegen.

## [1.3.0] — 2026-07-29

Cross-plugin command unification. The command surface now uses the same verb
families as apple-developer (`arch-*`, `analyze-*`, `review-*`, `gen-*`,
`fix-*`), so a command learned in one platform plugin is findable in the other.

### Added

- **`arch-select`** — choose a back-end architecture pattern: service
  decomposition (modular monolith vs microservices), data architecture and
  ownership, consistency model, layered vs hexagonal, event-driven/CQRS, saga
  orchestration. Routes to `backend-architector`, and to `api-designer` when the
  question is about API shape. Read-only.
- **`arch-review`** — review an existing codebase against its pattern: boundary
  violations, dependency direction, transaction scope, coupling, consistency
  drift.
- **`analyze-tech-debt`** — quantify and prioritize technical debt (service
  boundary erosion, God services, missing transaction boundaries, N+1 and
  unindexed hot queries, ORM leakage, dead endpoints, unversioned contracts)
  into a P0-P3 remediation ledger. Read-only.
- **`analyze-accessibility`** — review the accessibility of what a service
  actually emits: server-rendered templates, transactional emails and generated
  documents, error and validation payloads, and WCAG-relevant response metadata.
  Deliberately narrow, with a first-class "Out of scope" section pointing at the
  client-side plugins — a back-end plugin never sees the rendered page and does
  not claim to audit it. Read-only, haiku-weighted, small token band.
- **`gen-docs`** — generate or refresh OpenAPI/GraphQL/proto reference docs,
  per-language doc comments (JSDoc/TSDoc, godoc, Javadoc/KDoc, docstrings,
  PHPDoc, YARD, XML docs), and service READMEs. Spec/code mismatches are
  reported as drift findings rather than silently overwritten.
- **`debug`** — two modes: configure the debugging apparatus (structured logging
  and correlation IDs, per-stack debugger attach, container-attached debugging,
  OpenTelemetry traces, slow-query logging), or triage a specific failure across
  the back-end symptom families (5xx, pool exhaustion, deadlocks, N+1, memory
  growth, retry storms, consumer lag, TLS/CORS/auth).
- **`fix-refactor`** — `backend-architector` plans the refactor and
  `be-code-fixer` applies it, with the role split enforced and every step gated
  on a green `build-test`.
- **`develop-feature`** — end-to-end pipeline: architect (with `api-designer`
  and `database-engineer` pulled in on contract or schema changes) → stack
  developer → `be-test-generator` → `be-security-auditor`, each phase closing at
  an explicit checkpoint.
- **`deps add`** — introduce a new dependency: justify it against the standard
  library and the existing graph, vet its supply-chain posture, pin it exactly,
  and gate on a green build.
- **`fix-performance --apply`** — optional apply phase that routes
  `be-performance-engineer` findings to `be-code-fixer` and re-measures.

### Changed

- **Eight commands renamed** onto the shared naming families. The old names are
  removed, not aliased:

  | Old | New |
  |-----|-----|
  | `code-review` | `review-code` |
  | `lint-fix` | `fix-quick` |
  | `code-modernize` | `fix-modernize` |
  | `profile-performance` | `fix-performance` |
  | `generate-tests` | `gen-tests` |
  | `deps-audit` | `deps audit` |
  | `security-scan` | `analyze-security` |
  | `api-scaffold` | `gen-api` |

  `build-test` and `db-migrate` keep their names.

- **`deps` dispatches on a subcommand** — `audit` (default, read-only),
  `upgrade`, or `add`, parsed from the first argument, replacing the `--upgrade`
  flag. A bare `--upgrade` is still accepted as a back-compat alias, and an
  unrecognized first token falls back to `audit` so an ambiguous invocation can
  never land in a mutating mode.
- **`fix-performance` stays measure-only by default.** The command absorbed the
  read-only `profile-performance` behavior unchanged; nothing is written or
  edited before the `--apply` PHASE CHECKPOINT, and `--apply` opts into being
  asked rather than into being edited.
- **Command frontmatter normalized** across all 18 files: the `name:` key is
  removed (the command name comes from the filename, so a stale `name:` silently
  shadows a rename), `argument-hint` values are unquoted to match peer style,
  descriptions are verb-first and under 120 characters, and H1s are functional
  titles without a platform suffix or the old command name.
- **`analyze-*` commands are read-only by tool grant** — none of them carry
  `Write` or `Edit` in `allowed-tools`, so the contract is enforced by the
  permission surface rather than by prose alone.
- `marketplace.json` `commands[]` rewritten to the 18-command set, grouped by
  verb family.
- References to the old command names updated across `agents/`, `skills/`,
  `README.md`, and the command bodies themselves.

## [1.2.0] — 2026-07-22

company-workflow v3.36.0 compatibility port: CLI evidence-freshness rule, the
`state-patch.sh` pointer form, benchmark-driven output budgets on DV/AR/DR
agents, and a complexity-triage gate on `backend-architector`. Added the
`section-lint.sh` and `desc-lint.sh` repo-structure linters.

## [1.0.0] — 2026-06-15

Initial release: 16 agents, 10 commands, and the full skills tree across
`_shared`, `node`, `go`, `jvm`, `python-web`, `api`, `data`, `architecture`,
`tooling`, and `quality`, with plugin-scoped advisory hooks and
`scripts/validate.sh` as the release gate.
