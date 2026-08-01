# Backend Developer Plugin

Claude Code plugin for **web/service back-end** development in **Node.js/TypeScript**, **Go**, **JVM (Spring Boot / Kotlin)**, and **Python web (FastAPI/Django/Flask)** — plus **Ruby/PHP/.NET** — with cross-cutting **API design (REST/GraphQL/gRPC)**, **databases/ORM/migrations**, and **event-driven / CQRS / event-sourcing** architecture. Collaborates with the company-workflow plugin v4.0.0 for full 11-stage workflow orchestration (PL→AR→TL→DV→**DR**→SR→QA→DC→RE→FN→ST) including the handoff-protocol (planning-N.md, state.json ledger, frontmatter schema). Service and API work defaults to `requires_screenshots: false`; when an evidence gate demands proof, agents attach `cli-fallback` terminal transcripts (curl/httpie request/response, test output, k6 load reports, migration logs) instead of screenshots.

**Version**: 1.4.0 | **company-workflow Compatibility**: v4.0.0 | **claude-code min version**: "2.1.169"

## Boundaries

backend-developer owns HTTP/RPC services, their API contracts, and their data layer. It **delegates language depth** to keep one owner per language:

| Concern | Route to |
|---------|----------|
| Python *language* layer (typing, asyncio, free-threading, packaging) | `/system-developer:python-developer` (`python-backend-developer` owns the web-framework + persistence layer) |
| C / C++ native services or extensions | `/system-developer:c-developer` / `cpp-developer` |
| Shell / CI scripts | `/system-developer:bash-developer` |
| Browser UI consuming the API | `/frontend-developer:*` |
| Native mobile clients | `/apple-developer:*` |

## What's in 1.4.0

- **Polyglot-consistency pass** — the ecosystem-agnostic specialists now execute on every stack they advertise. `be-code-fixer` gained the Ruby/PHP/.NET binaries its own playbooks already prescribed (`rubocop`, `php-cs-fixer`, `dotnet`, plus test runners); `be-dependency-manager` gained the Bundler row, scan path, and grant behind its Ruby claim. Four commands had flags with no implementation behind them (`deps --upgrade` silently ran a read-only audit instead); those are now wired or removed. 26 dangling `skill:`/command references retargeted. See [CHANGELOG](CHANGELOG.md).

## What's in 1.3.0

- **16 agents** — a `backend-developer` router; four core stack developers (`node-developer`, `go-developer`, `jvm-backend-developer`, `python-backend-developer`); three optional runtimes (`ruby-developer`, `php-developer`, `dotnet-developer`); `backend-architector`, `api-designer`, `database-engineer`; and five Tier-2 specialists (`be-test-generator`, `be-performance-engineer`, `be-security-auditor`, `be-code-fixer`, `be-dependency-manager`). All inherit `agents/_base/backend-agent.md`.
- **18 commands** — unified onto the cross-plugin `arch-*` / `analyze-*` / `review-*` / `gen-*` / `fix-*` naming families shared with apple-developer, so a command learned in one plugin is findable in the other. Each carries restrictive `allowed-tools` and an `estimated-cost` band; the `analyze-*` family is read-only by tool grant, not merely by convention.
- **Complete skills tree** — entry + leaf `SKILL.md` skills across `_shared`, `node`, `go`, `jvm`, `python-web`, `api`, `data`, `architecture`, `tooling`, and `quality`, with deep reference files. Every framework/runtime feature carries a version marker and a fallback; the canonical runtime/framework table lives in `skills/_shared/version-feature-matrix.md`.
- **Plugin-scoped advisory hooks** — `audit-tooluse`, `audit-subagent`, `precompact-checkpoint`, wired in `plugin.json` with company-workflow-compatible dedupe keys. Advisory only: never merges `state.json` (orchestrator-owned). See [`hooks/README.md`](hooks/README.md).
- **CC capabilities adopted** — tiered `maxTurns` runaway-loop backstops, `disallowed-tools: Write, Edit` on the two review-only auditors, fully-qualified `Task(backend-developer:<agent>)` delegations, and scoped `Bash(cmd:*)` allowlists per toolchain.

## Agents (16)

| Agent | Model / Effort | Purpose |
|-------|----------------|---------|
| `backend-developer` | sonnet / medium | Index + router. Routes by language/framework markers to stack developers and specialists; handles cross-service and polyglot repos directly. |
| `node-developer` | sonnet / high | Node.js/TypeScript — Express/NestJS/Fastify/Hono, async, streams. |
| `go-developer` | sonnet / high | Go — goroutines/channels, stdlib-first, Gin/Echo/chi, error wrapping. |
| `jvm-backend-developer` | sonnet / high | Java/Kotlin — Spring Boot, JPA, reactive. |
| `python-backend-developer` | sonnet / high | FastAPI/Django/Flask; delegates language layer to `/system-developer:python-developer`. |
| `ruby-developer` | sonnet / high | Ruby on Rails. |
| `php-developer` | sonnet / high | Laravel/Symfony. |
| `dotnet-developer` | sonnet / high | C#/.NET, ASP.NET Core, EF Core. |
| `backend-architector` | opus / xhigh | Service decomposition, microservices, event-driven, CQRS/event-sourcing/saga, scaling, consistency models. |
| `api-designer` | sonnet / high | REST/GraphQL/gRPC schema design, versioning, OpenAPI contracts. |
| `database-engineer` | sonnet / high | Schema design, migrations, indexing, query optimization, ORM patterns. |
| `be-test-generator` | sonnet / high | Unit + integration + contract tests; Testcontainers; the repo's existing framework. |
| `be-performance-engineer` | sonnet / high (review-only) | Profiling, load testing (k6), N+1/query perf, caching. `disallowed-tools: Write, Edit`; fixes route to `be-code-fixer`. |
| `be-security-auditor` | sonnet / high (review-only) | OWASP API Top 10, authn/authz, injection (SQL/NoSQL/cmd), secrets, supply chain, rate limiting. `disallowed-tools: Write, Edit`. |
| `be-code-fixer` | haiku / medium | Minimal-diff remediation of review/security/perf findings. |
| `be-dependency-manager` | haiku / low | Per-ecosystem manifests + lockfiles (npm/pnpm/yarn, go.mod, Maven/Gradle, Bundler, Composer, NuGet, uv), CVE/license audit, one-at-a-time upgrades with a build+test gate. |

> `be-performance-engineer` and `be-security-auditor` are review-only by default; callers may override them to `opus` + `xhigh` for the hardest analyses (Opus 4.8 honors `xhigh`; Sonnet falls back to `high`, so the model must be raised too).

## Commands (18)

Commands are grouped into the verb families shared with the other company-workflow platform plugins.

| Command | Description |
|---------|-------------|
| `/backend-developer:develop-feature` | End-to-end feature pipeline: architect → stack developer → tests → OWASP security pass, phase-gated. |
| `/backend-developer:arch-select` | Choose a back-end architecture pattern — service decomposition, data architecture, consistency model. |
| `/backend-developer:arch-review` | Review a codebase against its pattern: boundary violations, dependency direction, transaction scope. |
| `/backend-developer:analyze-security` | OWASP API Top 10 checks, authz boundary review, secret scan, dependency CVEs. Read-only. |
| `/backend-developer:analyze-tech-debt` | Quantify and prioritize technical debt into a P0-P3 remediation ledger. Read-only. |
| `/backend-developer:analyze-accessibility` | Review server-produced HTML, emails, error payloads, and response metadata. Read-only, deliberately narrow. |
| `/backend-developer:review-code` | Language-aware review — per-language reviewers + API-contract pass + security pass → P0-P3. Supports `--quick` and `--fix`. |
| `/backend-developer:gen-api` | Scaffold endpoint/service/handler from an OpenAPI/GraphQL/proto contract. |
| `/backend-developer:gen-tests` | Unit/integration/contract tests via the project's framework. Supports `--coverage-gaps`. |
| `/backend-developer:gen-docs` | OpenAPI reference, per-language doc comments, and service READMEs derived from the code. |
| `/backend-developer:fix-quick` | Per-ecosystem linters/formatters (eslint/biome, gofmt/golangci-lint, ktlint, rubocop, php-cs-fixer, dotnet format) — `--check`/`--fix`. |
| `/backend-developer:fix-refactor` | Architect plans the refactor, `be-code-fixer` applies it, every step gated on a green build. |
| `/backend-developer:fix-modernize` | Framework/runtime upgrades one class at a time, gated on green build+test. Supports `--dry-run`. |
| `/backend-developer:fix-performance` | Load test (k6), profile hot paths, analyze slow queries. Measure-only by default; `--apply` unlocks a checkpointed fix phase. |
| `/backend-developer:build-test` | Detect the stack, build, and run unit + integration tests (Testcontainers where present). |
| `/backend-developer:db-migrate` | Generate/apply/verify migrations; safe forward + rollback plan. |
| `/backend-developer:deps` | `audit` (default), `upgrade`, or `add` — CVE/license reporting and exact pins behind a build+test gate. |
| `/backend-developer:debug` | Configure debuggers, tracing, and log capture, or triage and root-cause a specific failure. |

### Migration: old → new names

Version 1.3.0 renamed eight commands. The old names are gone, not aliased — update scripts and muscle memory:

| Old (≤ 1.2.0) | New (1.3.0) |
|---------------|-------------|
| `/backend-developer:code-review` | `/backend-developer:review-code` |
| `/backend-developer:lint-fix` | `/backend-developer:fix-quick` |
| `/backend-developer:code-modernize` | `/backend-developer:fix-modernize` |
| `/backend-developer:profile-performance` | `/backend-developer:fix-performance` |
| `/backend-developer:generate-tests` | `/backend-developer:gen-tests` |
| `/backend-developer:deps-audit` | `/backend-developer:deps audit` |
| `/backend-developer:security-scan` | `/backend-developer:analyze-security` |
| `/backend-developer:api-scaffold` | `/backend-developer:gen-api` |

`build-test` and `db-migrate` keep their names.

Two renames also changed behavior:

- **`deps`** now dispatches on a subcommand (`audit` | `upgrade` | `add`) rather than an `--upgrade` flag. `deps` with no subcommand still runs the read-only audit, and a bare `--upgrade` flag is still accepted as a back-compat alias.
- **`fix-performance`** stays measure-only by default. The new `--apply` flag routes `be-performance-engineer` findings to `be-code-fixer`, but only after an explicit PHASE CHECKPOINT — nothing is mutated before that approval.

All commands degrade gracefully when a tool is missing: they print an install hint, skip that stack, and never hard-fail.

## Skills

Entry + leaf `SKILL.md` skills across ten domains, plus shared references. Version-specificity is the product: every runtime/framework feature carries a version marker and a fallback, with `skills/_shared/version-feature-matrix.md` as the canonical lookup.

| Domain | Entry | Leaves |
|--------|-------|--------|
| `_shared` | `_index.md` | secure-coding (OWASP API Top 10), workflow-integration, version-feature-matrix, language-detection, model-selection, severity-matrix, testing-principles |
| `node` | `node-skills` | modern-typescript-backend, nest-express-fastify-patterns, node-async-streams |
| `go` | `go-skills` | modern-go, go-concurrency |
| `jvm` | `jvm-skills` | spring-boot, kotlin-backend |
| `python-web` | `python-web-skills` | fastapi, django, flask (language depth → `/system-developer:python/*`) |
| `api` | `api-skills` | rest-design, graphql-design, grpc-design, api-versioning, openapi-contracts |
| `data` | `data-skills` | schema-design, migrations, query-optimization, orm-patterns, caching-strategies |
| `architecture` | `architecture-skills` | microservices-patterns, event-driven, cqrs-event-sourcing, saga-orchestration |
| `tooling` | `tooling-skills` | containerization, be-diagnostics, observability |
| `quality` | `quality-skills` | api-security, be-performance, be-testing |

## Installation & Registration

### From Marketplace

```bash
claude plugins install backend-developer@backend-developer
```

### Manual registration in `~/.claude/settings.json`

```jsonc
{
  "extraKnownMarketplaces": {
    "backend-developer": {
      "source": {
        "source": "directory",
        "path": "/path/to/igrsoft/backend-developer"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "backend-developer@backend-developer": true
  }
}
```

After editing `settings.json`, run `/plugins` (or restart the session) to load the plugin.

## Workflow Integration (company-workflow v4.0.0)

This plugin collaborates with the **company-workflow** plugin v4.0.0 for 11-stage workflow orchestration. company-workflow owns orchestration, worktree isolation, and `state.json` merge; backend-developer agents stay invoked specialists and follow the handoff-protocol. During the DV stage, `company-workflow:developer` routes to the appropriate backend-developer specialist based on file/marker detection.

| Stage | backend-developer Role | Contribution |
|-------|------------------------|--------------|
| AR | Consult | `backend-architector` + `api-designer`: service boundaries, API contracts, data model. |
| **DV** | Primary | Endpoints/services/migrations; emits `development-N.md` with a Build Evidence section. |
| **DR** | Support | `be-code-fixer` applies findings (minimal-diff gate); `backend-architector` for pattern concerns. |
| SR | Context Provider | `be-security-auditor`: OWASP API Top 10, authn/authz, injection, secrets, supply chain, rate limiting. |
| QA | Support | `be-test-generator`; QA gate = unit+integration pass **and** analyze-security clean. |
| RE | Context Provider | `be-dependency-manager`: lockfile freeze, container image, DB migration plan, semver. |

**Evidence norm**: service and API work defaults to `requires_screenshots: false`. When a gate demands evidence, agents attach `cli-fallback` terminal transcripts (curl/httpie request/response, test output, k6 load reports, migration logs) rather than screenshots.

## Quick Start

```bash
# Detect the stack, build, and run unit + integration tests
/backend-developer:build-test .

# Language-aware review, then auto-apply minimal-diff fixes
/backend-developer:review-code src/ --fix

# Scaffold a service from an OpenAPI contract
/backend-developer:gen-api openapi.yaml

# OWASP API Top 10 security scan
/backend-developer:analyze-security .

# Pick an architecture for a new service, then build the feature end to end
/backend-developer:arch-select "checkout service with async fulfilment"
/backend-developer:develop-feature "idempotent order webhooks"

# Use an agent directly, outside the workflow
Use the backend-developer agent to design an event-driven order service with a saga for checkout
```

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
