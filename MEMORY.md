# backend-developer Plugin Memory

## Version Tracking

| Field | Value |
|-------|-------|
| Plugin version | 1.2.0 |
| igrsoft compatibility | v3.36.0 |
| Claude Code min required | 2.1.169 |
| Last updated | 2026-07-22 |

Version strings move together (plugin.json, marketplace.json metadata, README
header, this table) per the igrsoft `/cc-update` convention.

## Template Lineage

backend-developer mirrors **system-developer** structurally: directory layout,
`_base/` inheritance, manifests, hooks, `scripts/validate.sh`, and — critically —
the **evidence model** (no UI surface → `requires_screenshots: false` /
cli-fallback). The difference is the domain: web/service back-ends (Node/TS, Go,
JVM, Python web, Ruby/PHP/.NET) and the cross-cutting API/data/architecture
layers, rather than the C/C++/Python/Bash *languages* system-developer owns.

## CC Features Adopted at 1.0.0

Born on the igrsoft v3.17.0 / CC 2.1.169 baseline (current compatibility: igrsoft
v3.36.0); adopts the current capability set from the start:

- **Tiered `maxTurns`** — haiku/low 20 (`be-dependency-manager`), haiku/medium 30
  (`be-code-fixer`), sonnet/medium 40 (`backend-developer` router), sonnet/high 50
  (the stack developers, `api-designer`, `database-engineer`, `be-test-generator`,
  `be-performance-engineer`, `be-security-auditor`), opus/xhigh 60
  (`backend-architector`).
- **`disallowed-tools: Write, Edit`** — on the two review-only agents
  (`be-performance-engineer`, `be-security-auditor`); fixes route to `be-code-fixer`.
- **Fully-qualified `Task(plugin:agent)` references** — all delegations use the
  `Task(backend-developer:<agent>)` form; cross-plugin targets keep their own
  prefix (`system-developer:*`, `igrsoft:*`, …).
- **Scoped `Bash(cmd:*)` allowlists** — each agent's `tools:` enumerates only the
  ecosystem binaries it needs (e.g. `node-developer`: node, npm, pnpm, yarn, npx,
  tsc, eslint, vitest, jest). Single-command invocations only (no `cd`-chains).
- **Plugin-scoped advisory hooks** — `hooks/{audit-tooluse,audit-subagent,
  precompact-checkpoint}.sh`, wired in `plugin.json`. Advisory
  (`actor: "backend-developer:hook:*"`, `metadata.advisory: true`), sharing
  igrsoft's `dedupe_key` / `dedupe_key_extended` shape. Each script has `--self-test`.

## Not Adopted (igrsoft-owned infrastructure)

backend-developer agents are invoked specialists; igrsoft owns orchestration.
Deliberately **not** implemented here:

- **`audit-dedup.sh`** — igrsoft-owned. backend-developer emits advisory rows with
  matching dedupe keys for igrsoft to reconcile.
- **`state-merge.sh` / SubagentStop `state.json` merge** — orchestrator-owned. The
  hooks here read and checkpoint state but never merge it. Frontmatter emission is
  unconditional (it is the input igrsoft's merge layer consumes).
- **Screenshot-gate ownership** — igrsoft owns the evidence gate. backend-developer
  work defaults to `requires_screenshots: false` and, when a gate demands proof,
  supplies `cli-fallback` terminal transcripts (curl/httpie transcripts, test
  output, k6 load reports, migration logs). It does not own or override the gate.

## Decisions Log

- **Single owner per language** — system-developer remains canonical for the
  Python/C/C++/Bash *language* layer; `python-backend-developer` owns the
  **web-framework + persistence** layer (FastAPI/Django/Flask) and delegates pure
  language depth (typing, asyncio, free-threading, packaging) to
  `system-developer:python-developer` — exactly as system's `python-developer`
  delegates FFI to its router. No Python/C/C++/Bash *language* skills are forked
  here — they are linked.
- **`be-` prefix on the five colliding Tier-2 names** — `be-test-generator`,
  `be-performance-engineer`, `be-security-auditor`, `be-code-fixer`,
  `be-dependency-manager` are prefixed because the bare names collide with
  apple-developer / system-developer Tier-2 agents. Non-colliding names stay plain
  (`node-developer`, `go-developer`, `api-designer`, `database-engineer`,
  `backend-architector`, …).
- **Optional runtimes shipped in v1** — `ruby-developer`, `php-developer`,
  `dotnet-developer` are included (the 16-agent count) rather than deferred to a
  "phase 2" flag, so polyglot shops are covered out of the box.
- **Review-only auditors** — `be-performance-engineer` and `be-security-auditor`
  carry `disallowed-tools: Write, Edit` and route all remediation to `be-code-fixer`.
- **Plain command names** — commands use bare filenames (invoked as
  `/backend-developer:<name>`), mirroring system-developer / apple-developer.
- **`package.json` front-end vs back-end disambiguation** — the one non-trivial
  detection rule: inspect dependencies (UI framework → frontend; server framework
  express/nest/fastify/hono → backend; both → ask). Documented in
  `skills/_shared/language-detection.md`.
- **OWASP API Top 10 as the security spine** — `secure-coding` and
  `be-security-auditor` are organized around the OWASP API Security Top 10 (broken
  object/function-level authorization, injection, SSRF, secrets, rate limiting)
  rather than the memory-safety CWE Top 25 that anchors system-developer.

## Version History

### 1.2.0 — 2026-07-22 igrsoft v3.36.0 Port

Compatibility ported v3.17.0 → v3.36.0 (~20 refs across README, this file, the agent
stage-participation headers, the skill catalog, and the `workflow-integration` skill). The
Dynamic Worktask Sizing table was already current (DR0 at every tier); the PL0 stamp note
now also names `metadata.test_mode` (`build-only`/`scoped`/`full`) and `metadata.ui_visual_check`
(N/A for backend/API work — left `false`), citing igrsoft `estimation-methodology § PL0
Stage-Set` as the source of truth. The v3.17.0 / CC 2.1.169 birth record is preserved as history.

Three workflow-contract learnings ported from igrsoft v3.36.0: (1) a **CLI evidence-freshness
rule** — every `cli-fallback` transcript (curl/httpie request/response, test output, k6 report,
migration dry-run/log) must be produced *this run* from the actual invocation, never reused;
the systems analog of igrsoft's ov151 evidence-integrity gate (QA direct-reads evidence and
cross-checks the `### build-evidence` log paths, re-opening DV on a stale/duplicated transcript).
(2) The **state-patch pointer form** — the manual `read → merge → temp → fsync → rename`
atomic-write prose is replaced by the two-mode `state-patch.sh --stage <CODE> --prev <PREV>`
contract (run when its path is supplied, else silently skip; Layers 2/3 repair from the
unconditional `handoff:` frontmatter). (3) Benchmark-driven **Output Budgets** on DV (`_base`,
with the five Build-Evidence lines exempt), AR, DV-support, and DR-support agents, plus a
**Complexity Triage** gate on `backend-architector` that self-limits scope at Low complexity.

Repo-structure linters added: `section-lint.sh` (≤1000-char section cap, warn-only — baseline
405 sections over cap across 118 files, burn-down tracked separately) and `desc-lint.sh`
(three-tier frontmatter `description` brake: agents 450 / commands 250 / skills 750). The
companion patch `docs/company-workflow-patch.md` is marked **applied upstream** (company-workflow's
`agents/developer.md` now carries the backend-developer Task grants and routing).

Follow-ups: the agent-description diet toward the ≤250 sibling-plugin ideal is eval-gated — ten
agents currently exceed 250 (the `backend-developer` router at 420; brake set at 450) — and waits
on evidence that shorter descriptions still route reliably. Skill descriptions' worst is ~695
against the 750 brake. There is no CI in this repo yet, so the linters run manually via
`scripts/run-checks.sh` until a workflow lands.

### 1.1.0 — 2026-06 Best-Practices Refresh

Runtime and framework floor bumps: Node.js 24 LTS, Go 1.26 (1.25 floor), Java 25
LTS (Spring Boot 4.x GA / Spring Framework 7), .NET 10 LTS, FastAPI 0.136 / Django
5.2 LTS / Flask 3.1, Rails 8.1, PHP 8.2+ / Laravel 12 / Symfony 7.4 LTS.

Matrix expanded with new rows: Ruby/Rails, PHP/Laravel/Symfony, .NET Runtime &
ASP.NET Core, MongoDB 8.0, Redis/Valkey divergence note. Total: 21 rows refreshed
(A) + 22 added (+R) = 43 version-bearing surface rows.

Notable shifts captured: OTel Logs API stable; Kafka 4.0 KRaft-only + native queue
semantics; RabbitMQ 4.x quorum-only; GraphQL `@oneOf` ratified; OpenAPI 3.2 GA;
RFC 9745 Deprecation header; ZAP→Checkmarx security tooling rebrand; DPoP/RFC
9449 sender-constrained tokens; continuous profiling (Pyroscope/Parca). Pre-existing
broken matrix link fixed (secure-coding/references/input-validation-and-parsing.md
relative paths). Three un-owned domain SKILL.md files (jvm, node, quality) refreshed
post-fan-out.

Carried forward: OOS-1 advisory (skills/data/SKILL.md 8KB split follow-up);
JavaScript framework matrix section (Express/NestJS/Fastify/Hono rows, follow-up);
OWASP API Top 10 2023 edition re-anchor (structural, separate worktask).

## Companion Patch (REQUIRED, external)

`company-workflow/agents/developer.md` needs a back-end specialist row in its DV
router (see `docs/company-workflow-patch.md` for the exact patch): `tools:`
additions, a Backend/Service Specialization table, detection rules
(`go.mod`→go; `pom.xml`/`build.gradle(.kts)`→jvm; `package.json` with a server
dep→backend node; `requirements.txt`/`pyproject.toml` with fastapi/django/flask→
backend python; `Gemfile`→ruby; `composer.json`→php; `*.csproj`→dotnet), and
reuse of the existing `cli_fallback_adapter`. The igrsoft plugin is not installed
in this repo, so the patch is documented rather than applied.
