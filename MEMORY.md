# backend-developer Plugin Memory

## Version Tracking

| Field | Value |
|-------|-------|
| Plugin version | 1.0.0 |
| igrsoft compatibility | v3.17.0 |
| Claude Code min required | 2.1.169 |
| Last updated | 2026-06-14 |

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

Born on the igrsoft v3.17.0 / CC 2.1.169 baseline; adopts the current capability
set from the start:

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

## Companion Patch (REQUIRED, external)

`company-workflow/agents/developer.md` needs a back-end specialist row in its DV
router (see `docs/company-workflow-patch.md` for the exact patch): `tools:`
additions, a Backend/Service Specialization table, detection rules
(`go.mod`→go; `pom.xml`/`build.gradle(.kts)`→jvm; `package.json` with a server
dep→backend node; `requirements.txt`/`pyproject.toml` with fastapi/django/flask→
backend python; `Gemfile`→ruby; `composer.json`→php; `*.csproj`→dotnet), and
reuse of the existing `cli_fallback_adapter`. The igrsoft plugin is not installed
in this repo, so the patch is documented rather than applied.
