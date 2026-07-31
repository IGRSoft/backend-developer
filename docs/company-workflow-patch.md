# Companion Patch — `company-workflow/agents/developer.md`

**Status (2026-07-22): applied upstream** — company-workflow's `agents/developer.md` now carries the backend-developer Task grants and routing (see company-workflow v4.0.0). This document is retained as the historical patch spec.

**Status:** REQUIRED, not yet applied. The company-workflow plugin is **not
installed in this repository**, so this patch is documented here rather than applied.
Apply it in the company-workflow repo when wiring backend-developer into the DV router,
then bump company-workflow's patch/minor version and note it under "What's new".

The DV router (`company-workflow:developer`) currently has no back-end specialist. Without this
patch, back-end service files at the DV stage fall through to the generic developer or to
system-developer's language agents, which do not own the web-framework, API-contract, or
persistence layer.

This mirrors the gap and remedy described in the front-end plan; the five edits below are
the back-end analog.

---

## 1. `tools:` frontmatter — add the qualified Task targets

Add to `company-workflow/agents/developer.md` frontmatter `tools:`:

```
Task(backend-developer:backend-developer),
Task(backend-developer:node-developer),
Task(backend-developer:go-developer),
Task(backend-developer:jvm-backend-developer),
Task(backend-developer:python-backend-developer),
Task(backend-developer:api-designer),
Task(backend-developer:database-engineer),
Task(backend-developer:be-code-fixer),
Task(backend-developer:be-test-generator)
```

(Ruby/PHP/.NET routing can go through the `backend-developer` router rather than declaring
each Tier-1 agent in the DV router's frontmatter.)

## 2. "Backend/Service Specialization" routing table

Add a section mapping language/framework markers to the owning agent:

| Marker | Stack | Route to |
|--------|-------|----------|
| `go.mod` / `*.go` | Go | `backend-developer:go-developer` |
| `pom.xml` / `build.gradle(.kts)` / `*.java` / `*.kt` | JVM | `backend-developer:jvm-backend-developer` |
| `package.json` **with a server dep** (express/nest/fastify/hono) | Node/TS | `backend-developer:node-developer` |
| `requirements.txt` / `pyproject.toml` **with fastapi/django/flask** | Python web | `backend-developer:python-backend-developer` |
| `Gemfile` | Ruby | `backend-developer:ruby-developer` (via router) |
| `composer.json` | PHP | `backend-developer:php-developer` (via router) |
| `*.csproj` | .NET | `backend-developer:dotnet-developer` (via router) |
| REST/GraphQL/gRPC contract work | API | `backend-developer:api-designer` |
| schema/migration/index/query/ORM work | Data | `backend-developer:database-engineer` |
| mixed / polyglot / cross-service | — | `backend-developer:backend-developer` (router) |

## 3. Detection Rules

Add the rows above to the router's Detection Rules, **with two precedence notes**:

- **Python language vs Python web.** Pure Python *language* depth (typing, asyncio
  internals, free-threading, packaging) → `system-developer:python-developer`. The Python
  *web* layer (FastAPI/Django/Flask + persistence) → `backend-developer:python-backend-developer`.
  The backend agent itself delegates language depth back to system-developer.
- **Front-end vs back-end `package.json`** (the one non-trivial rule): inspect
  dependencies, not just the extension. A UI framework (react/vue/svelte/angular) →
  `frontend-developer:*`; a server framework (express/nest/fastify/hono) → backend; **both
  present → ask** (per the router's Priority Order rule 4). This rule is documented in
  `skills/_shared/language-detection.md` of **both** the backend-developer and
  frontend-developer plugins — keep them in sync.

## 4. Direct Platform Specialist Routing + Routing Audit

Add back-end rows to the router's "Direct Platform Specialist Routing" table and to the
"Routing Audit" checklist so audits confirm back-end files reached a backend-developer
specialist (not the generic developer).

## 5. Evidence adapter — reuse the existing `cli_fallback_adapter`

No new adapter is needed. `developer.md` already carries `cli_fallback_adapter` for
`systems` / unknown work. backend-developer DV stages default to
`requires_screenshots: false` and, when a gate is armed, emit `source: cli-fallback`
rows (API request/response transcripts via curl/httpie, test output, k6 load reports,
migration logs). Point the back-end branch at the same adapter.

---

## Verification after applying

- `company-workflow/scripts/validate.sh` (or its equivalent) passes with the new Task targets.
- A polyglot fixture (e.g. a Go service + a Node BFF) routes each file to the correct
  backend-developer specialist at DV.
- A `package.json` carrying both a UI framework and a server framework triggers the
  "ask" path rather than silently routing to one side.
