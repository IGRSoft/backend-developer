# Backend Developer Plugin

Claude Code plugin for **web/service back-end** development in **Node.js/TypeScript**, **Go**, **JVM (Spring Boot / Kotlin)**, and **Python web (FastAPI/Django/Flask)** — plus **Ruby/PHP/.NET** — with cross-cutting **API design (REST/GraphQL/gRPC)**, **databases/ORM/migrations**, and **event-driven / CQRS / event-sourcing** architecture. Collaborates with the igrsoft (company-workflow) plugin v3.36.0 for full 11-stage workflow orchestration (PL→AR→TL→DV→**DR**→SR→QA→DC→RE→FN→ST) including the handoff-protocol (planning-N.md, state.json ledger, frontmatter schema). Service and API work defaults to `requires_screenshots: false`; when an evidence gate demands proof, agents attach `cli-fallback` terminal transcripts (curl/httpie request/response, test output, k6 load reports, migration logs) instead of screenshots.

**Version**: 1.2.0 | **igrsoft Compatibility**: v3.36.0 | **claude-code min version**: "2.1.169"

## Boundaries

backend-developer owns HTTP/RPC services, their API contracts, and their data layer. It **delegates language depth** to keep one owner per language:

| Concern | Route to |
|---------|----------|
| Python *language* layer (typing, asyncio, free-threading, packaging) | `system-developer:python-developer` (`python-backend-developer` owns the web-framework + persistence layer) |
| C / C++ native services or extensions | `system-developer:c-developer` / `cpp-developer` |
| Shell / CI scripts | `system-developer:bash-developer` |
| Browser UI consuming the API | `frontend-developer:*` |
| Native mobile clients | `apple-developer:*` |

## What's in 1.0.0

- **16 agents** — a `backend-developer` router; four core stack developers (`node-developer`, `go-developer`, `jvm-backend-developer`, `python-backend-developer`); three optional runtimes (`ruby-developer`, `php-developer`, `dotnet-developer`); `backend-architector`, `api-designer`, `database-engineer`; and five Tier-2 specialists (`be-test-generator`, `be-performance-engineer`, `be-security-auditor`, `be-code-fixer`, `be-dependency-manager`). All inherit `agents/_base/backend-agent.md`.
- **10 commands** — language-aware review, build/test, test generation, API scaffolding, DB migrations, lint/format, profiling/load testing, framework modernization, dependency auditing, and OWASP API security scanning, each with restrictive `allowed-tools` and an `estimated-cost` band.
- **Complete skills tree** — entry + leaf `SKILL.md` skills across `_shared`, `node`, `go`, `jvm`, `python-web`, `api`, `data`, `architecture`, `tooling`, and `quality`, with deep reference files. Every framework/runtime feature carries a version marker and a fallback; the canonical runtime/framework table lives in `skills/_shared/version-feature-matrix.md`.
- **Plugin-scoped advisory hooks** — `audit-tooluse`, `audit-subagent`, `precompact-checkpoint`, wired in `plugin.json` with igrsoft-compatible dedupe keys. Advisory only: never merges `state.json` (orchestrator-owned). See [`hooks/README.md`](hooks/README.md).
- **CC capabilities adopted** — tiered `maxTurns` runaway-loop backstops, `disallowed-tools: Write, Edit` on the two review-only auditors, fully-qualified `Task(backend-developer:<agent>)` delegations, and scoped `Bash(cmd:*)` allowlists per toolchain.

## Agents (16)

| Agent | Model / Effort | Purpose |
|-------|----------------|---------|
| `backend-developer` | sonnet / medium | Index + router. Routes by language/framework markers to stack developers and specialists; handles cross-service and polyglot repos directly. |
| `node-developer` | sonnet / high | Node.js/TypeScript — Express/NestJS/Fastify/Hono, async, streams. |
| `go-developer` | sonnet / high | Go — goroutines/channels, stdlib-first, Gin/Echo/chi, error wrapping. |
| `jvm-backend-developer` | sonnet / high | Java/Kotlin — Spring Boot, JPA, reactive. |
| `python-backend-developer` | sonnet / high | FastAPI/Django/Flask; delegates language layer to `system-developer:python-developer`. |
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
| `be-dependency-manager` | haiku / low | Per-ecosystem manifests + lockfiles (npm/go.mod/Maven/Gradle/Cargo/Composer/NuGet), CVE/license audit, one-at-a-time upgrades with a build+test gate. |

> `be-performance-engineer` and `be-security-auditor` are review-only by default; callers may override them to `opus` + `xhigh` for the hardest analyses (Opus 4.8 honors `xhigh`; Sonnet falls back to `high`, so the model must be raised too).

## Commands (10)

| Command | Description |
|---------|-------------|
| `/backend-developer:code-review` | Language-aware review — per-language reviewers + API-contract pass + security pass → P0-P3. Supports `--quick` and `--fix`. |
| `/backend-developer:build-test` | Detect the stack, build, and run unit + integration tests (Testcontainers where present). |
| `/backend-developer:generate-tests` | Unit/integration/contract tests via the project's framework. Supports `--coverage-gaps`. |
| `/backend-developer:api-scaffold` | Scaffold endpoint/service/handler from an OpenAPI/GraphQL schema. |
| `/backend-developer:db-migrate` | Generate/apply/verify migrations; safe forward + rollback plan. |
| `/backend-developer:lint-fix` | Per-ecosystem linters/formatters (eslint/biome, gofmt/golangci-lint, ktlint, rubocop, php-cs-fixer, dotnet format) — `--check`/`--fix`. |
| `/backend-developer:profile-performance` | Load test (k6), profile hot paths, analyze slow queries; route to `be-performance-engineer`. |
| `/backend-developer:code-modernize` | Framework/runtime upgrades one class at a time, gated on green build+test. Supports `--dry-run`. |
| `/backend-developer:deps-audit` | CVE/license/outdated across ecosystems + safe upgrades with a build+test gate. |
| `/backend-developer:security-scan` | OWASP API Top 10 checks, authz boundary review, secret scan, dependency CVEs. |

All commands degrade gracefully when a tool is missing: they print an install hint, skip that stack, and never hard-fail.

## Skills

Entry + leaf `SKILL.md` skills across ten domains, plus shared references. Version-specificity is the product: every runtime/framework feature carries a version marker and a fallback, with `skills/_shared/version-feature-matrix.md` as the canonical lookup.

| Domain | Entry | Leaves |
|--------|-------|--------|
| `_shared` | `_index.md` | secure-coding (OWASP API Top 10), workflow-integration, version-feature-matrix, language-detection, model-selection, severity-matrix, testing-principles |
| `node` | `node-skills` | modern-typescript-backend, nest-express-fastify-patterns, node-async-streams |
| `go` | `go-skills` | modern-go, go-concurrency |
| `jvm` | `jvm-skills` | spring-boot, kotlin-backend |
| `python-web` | `python-web-skills` | fastapi, django, flask (language depth → `system-developer:python/*`) |
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

## Workflow Integration (igrsoft v3.36.0)

This plugin collaborates with the **igrsoft** (company-workflow) plugin v3.36.0 for 11-stage workflow orchestration. igrsoft owns orchestration, worktree isolation, and `state.json` merge; backend-developer agents stay invoked specialists and follow the handoff-protocol. During the DV stage, `igrsoft:developer` routes to the appropriate backend-developer specialist based on file/marker detection.

| Stage | backend-developer Role | Contribution |
|-------|------------------------|--------------|
| AR | Consult | `backend-architector` + `api-designer`: service boundaries, API contracts, data model. |
| **DV** | Primary | Endpoints/services/migrations; emits `development-N.md` with a Build Evidence section. |
| **DR** | Support | `be-code-fixer` applies findings (minimal-diff gate); `backend-architector` for pattern concerns. |
| SR | Context Provider | `be-security-auditor`: OWASP API Top 10, authn/authz, injection, secrets, supply chain, rate limiting. |
| QA | Support | `be-test-generator`; QA gate = unit+integration pass **and** security-scan clean. |
| RE | Context Provider | `be-dependency-manager`: lockfile freeze, container image, DB migration plan, semver. |

**Evidence norm**: service and API work defaults to `requires_screenshots: false`. When a gate demands evidence, agents attach `cli-fallback` terminal transcripts (curl/httpie request/response, test output, k6 load reports, migration logs) rather than screenshots.

## Quick Start

```bash
# Detect the stack, build, and run unit + integration tests
/backend-developer:build-test .

# Language-aware review, then auto-apply minimal-diff fixes
/backend-developer:code-review src/ --fix

# Scaffold a service from an OpenAPI contract
/backend-developer:api-scaffold openapi.yaml

# OWASP API Top 10 security scan
/backend-developer:security-scan .

# Use an agent directly, outside the workflow
Use the backend-developer agent to design an event-driven order service with a saga for checkout
```

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
