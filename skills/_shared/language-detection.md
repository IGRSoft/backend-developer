---
name: language-detection
description: Shared marker-to-stack-to-agent routing table for backend-developer commands and the router agent. Reference when deciding which back-end language/framework agent owns a file, directory, or repository, and when to hand a Python/native language layer to system-developer.
---

# Language Detection & Agent Routing

Single source of truth for the marker → stack → agent mapping used by `backend-developer` (router) and every command that scopes work per stack. Keep command-local detection logic in sync with this file — do not fork the table.

## Detection Priority Order

Evaluate top-down; the first matching tier wins. Within a tier, apply the tie-breaking rules below.

| Priority | Signal | Why it ranks here |
|----------|--------|-------------------|
| 1 | Explicit user statement ("this is a Go service", `--stack` flag) | User intent overrides inference |
| 2 | Package/build manifests (`package.json`, `go.mod`, `pom.xml`, `build.gradle(.kts)`, `pyproject.toml`, `Gemfile`, `composer.json`, `*.csproj`) | Declares the toolchain authoritatively |
| 3 | Lockfiles (`package-lock.json`/`pnpm-lock.yaml`/`yarn.lock`, `go.sum`, `poetry.lock`/`uv.lock`, `Gemfile.lock`, `composer.lock`, `packages.lock.json`) | Pins the ecosystem |
| 4 | Server-framework dependency inside the manifest | Distinguishes a back-end service from a front-end or CLI package |
| 5 | Extension census of tracked source files | Reflects actual code volume |

## Marker → Stack → Agent Table

| Marker(s) | Stack | Agent |
|-----------|-------|-------|
| `go.mod` / `go.sum` | Go (Gin/Echo/chi, stdlib `net/http`) | `backend-developer:go-developer` |
| `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle(.kts)` | JVM (Spring Boot, JPA/Hibernate, Kotlin) | `backend-developer:jvm-backend-developer` |
| `package.json` **with a server dep** (`express`, `@nestjs/core`, `fastify`, `hono`, `koa`) | Node.js / TypeScript | `backend-developer:node-developer` |
| `requirements*.txt` / `pyproject.toml` **with** `fastapi` / `django` / `flask` | Python web layer (language depth → system-developer) | `backend-developer:python-backend-developer` |
| `Gemfile` (with `rails`/`sinatra`) | Ruby (Rails) | `backend-developer:ruby-developer` |
| `composer.json` (with `laravel/*` or `symfony/*`) | PHP (Laravel/Symfony) | `backend-developer:php-developer` |
| `*.csproj`, `*.sln` (with `Microsoft.AspNetCore.*`) | C# / .NET (ASP.NET Core, EF Core) | `backend-developer:dotnet-developer` |
| Mixed markers across stacks (e.g. `go.mod` + `package.json` server) | Polyglot / mixed | `backend-developer:backend-developer` (router; splits work, owns cross-service contracts) |

File-level extension map (for per-file routing inside a polyglot repo):

| Extension | Agent |
|-----------|-------|
| `.go` | `go-developer` |
| `.ts`, `.mts`, `.cts`, `.js` (server) | `node-developer` |
| `.java` | `jvm-backend-developer` |
| `.kt`, `.kts` | `jvm-backend-developer` |
| `.py` (web layer) | `python-backend-developer` — see handoff note |
| `.rb` | `ruby-developer` |
| `.php` | `php-developer` |
| `.cs` | `dotnet-developer` |

## Tie-Breaking Rules

1. **Front-end vs back-end `package.json` (the key tie-break).** A `package.json` alone is not a back-end signal. Inspect `dependencies`/`devDependencies`:
   - UI framework only (`react`, `vue`, `svelte`, `@angular/core`, `next` used purely for pages) → this is a front-end package; route to `frontend-developer` (out of scope here) — do **not** claim it.
   - Server framework (`express`, `@nestjs/core`, `fastify`, `hono`, `koa`) → `node-developer`.
   - **Both** (e.g. a Next.js app with API route handlers + a UI, or a monorepo workspace root) → **ask the user** which layer the task targets, or split: route API/route-handler/server files to `node-developer`, UI files out of scope.
2. **Python WEB layer → backend-developer; Python LANGUAGE depth → system-developer.** `pyproject.toml`/`requirements.txt` with `fastapi`/`django`/`flask` routes the *service/endpoint/ORM* work to `python-backend-developer`. Deep language concerns — typing internals, asyncio/free-threading semantics, C-extension/FFI, packaging — hand off to `system-developer:python-developer`. The web agent coordinates and delegates the language slice.
3. **Build wrappers do not flip the stack.** A `Dockerfile`, `Makefile`, or `*.sh` task runner in a Go/JVM/Node repo does not make it a "shell project" — route by the dominant package manifest; route edits *to those scripts* as repo tooling.
4. **Gradle/Maven with Kotlin sources → still `jvm-backend-developer`.** Kotlin and Java share the JVM agent; do not split a Spring Boot service by `.java` vs `.kt`.
5. **Lockfile beats stray files.** One `scripts/migrate.py` in a `go.mod` repo does not make it a Python project; `go.sum` outranks a vendored `*.py` helper.
6. **Monorepo → per-package routing.** In a workspace (`pnpm-workspace.yaml`, Nx, Turborepo, Gradle multi-module, Go workspace `go.work`), detect **per package/module** using this same table; the router fans work out to the owning agent per package.
7. **Still ambiguous → router.** When two stacks conflict irreconcilably (equal volume, no dominant manifest, or a true polyglot service mesh), dispatch `backend-developer:backend-developer` and let it split the work and own the cross-service API contracts.

## Census Snippet

When manifests are absent or you need volume confirmation, count tracked sources (never `node_modules`, `vendor/`, `target/`, `.venv/`, `dist/`, `build/`):

```bash
git ls-files | grep -E '\.(go|ts|mts|cts|js|java|kt|kts|py|rb|php|cs)$' | sed 's/.*\.//' | sort | uniq -c | sort -rn
```

Route to the dominant stack's agent if it holds >70% of source files; otherwise use the router.

## system-developer Handoff

| Concern | Owner |
|---------|-------|
| Python web service, endpoints, ORM, ASGI/WSGI deploy | `backend-developer:python-backend-developer` |
| Python language internals, typing, asyncio/free-threading, packaging | `system-developer:python-developer` |
| C/C++ native extension or shared library backing a service | `system-developer:c-developer` / `system-developer:cpp-developer` |
| Bash deploy/ops scripts surrounding a service | `system-developer:bash-developer` |
| The service's API design, transactions, auth, framework wiring | the owning `backend-developer:*` agent |

## Related Skills

- `model-selection.md` — model/effort to pass with the routed `Task()` call
- `version-feature-matrix.md` — runtime/framework/ORM floors once the stack is known
- system-developer's `language-detection.md` — when a non-web language layer is in play
