# Changelog

All notable changes to the backend-developer plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

igrsoft v3.36.0 compatibility port: CLI evidence-freshness rule, the
`state-patch.sh` pointer form, benchmark-driven output budgets on DV/AR/DR
agents, and a complexity-triage gate on `backend-architector`. Added the
`section-lint.sh` and `desc-lint.sh` repo-structure linters.

## [1.0.0] — 2026-06-15

Initial release: 16 agents, 10 commands, and the full skills tree across
`_shared`, `node`, `go`, `jvm`, `python-web`, `api`, `data`, `architecture`,
`tooling`, and `quality`, with plugin-scoped advisory hooks and
`scripts/validate.sh` as the release gate.
