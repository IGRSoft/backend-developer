---
description: Generate or update API reference docs, per-language doc comments, and service READMEs from the code
argument-hint: [path/scope (default: working changes)] [--api] [--comments] [--readme] [--check] [--stack node|go|jvm|python|ruby|php|dotnet]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
estimated-cost:
  min-tokens: 2500
  max-tokens: 20000
  model-distribution:
    haiku: 20%
    sonnet: 70%
    opus: 10%
---

# Documentation Generator
<!-- Updated: July 2026 -->

Generate or refresh a back-end service's documentation from the code that actually runs: the API reference (OpenAPI / GraphQL SDL / proto comments), per-language doc comments on public symbols, and the service README (endpoint table, config reference, local-run and Docker Compose instructions, migration commands). The implementation is the source of truth; documentation is derived from it, and every mismatch between an existing spec and the code is reported as **drift**, never quietly overwritten.

[Extended thinking: Documentation rots because it is written once, by hand, next to code that keeps moving. This command inverts that: it reads annotated routes, handler signatures, DTO/validation schemas, config loaders, and migration scripts, then emits docs that are mechanically traceable back to those symbols. That traceability is exactly why the drift rule matters — when `openapi.yaml` says an endpoint returns `200 {order}` and the handler returns `202` with a job id, one of them is wrong, and the command has no authority to decide which. Silently regenerating the spec would erase a deliberate contract that consumers already depend on; silently trusting the spec would document behavior nobody implemented. So the command emits a drift report and stops at that endpoint. The three doc layers are also deliberately separable: doc comments are cheap and local, the API reference is a published contract with consumers, and the README is the human on-ramp — a caller who only wants JSDoc on a refactored module should not pay for a spec regeneration. Generation itself is delegated to the stack developer that owns the annotation dialect, because springdoc, FastAPI's auto-schema, NestJS Swagger decorators, huma, Scribe, Rswag, and Swashbuckle each derive schemas differently, and a doc comment that does not match the language's tooling conventions is noise the compiler and IDE ignore.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Never invent behavior the code does not implement.** Every documented endpoint, parameter, status code, error shape, env var, and CLI command MUST trace to a symbol you read — a route registration, handler, DTO/validation schema, config loader, or migration file. If you cannot find the source, write nothing for it and list it under "Undocumentable" in the report. A plausible-sounding endpoint description is a defect, not a placeholder.
2. **Drift is REPORTED, not overwritten.** When an existing `openapi.yaml`/`openapi.json`, SDL, or README contradicts the code, do NOT regenerate over it. Emit a drift finding (spec side, code side, file:line for each) and leave the file untouched at that point. Only additive, non-conflicting updates (a newly added endpoint, a missing description on an otherwise-matching operation) may be written without confirmation.
3. **Derive, never transcribe from memory.** Read the annotated routes and the framework's own generator output where one exists (`springdoc` `/v3/api-docs`, FastAPI `app.openapi()`, NestJS `SwaggerModule`, `go-swagger`/`huma`, Laravel Scribe, Rswag, Swashbuckle). A hand-written guess is only acceptable when no generator exists for the stack, and it MUST be marked `<!-- hand-derived -->` in the output.
4. **Match the repo's existing doc dialect.** Python docstrings follow whichever style the repo already uses (Google or NumPy — detect, do not switch). Node follows the repo's JSDoc/TSDoc convention. Never introduce a second style into a file or module that already has one; a mixed-style module is a failure.
5. **Delegate authoring to the owning stack developer.** You own detection, drift analysis, assembly, and verification. The stack developer owns the annotation dialect and the doc-comment bodies. When the stack is ambiguous (polyglot repo, no decisive manifest), route through the router agent `backend-developer:backend-developer` rather than guessing.
6. **Single-command Bash invocations.** Use each toolchain's own working-directory flags (`npm --prefix <path>`, `go -C <path>`, `mvn -f <path>/pom.xml`, `gradle -p <path>`, `uv run --project <path>`, `bundle exec --gemfile`, `composer --working-dir`, `dotnet <path>/x.csproj`). Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands.
7. **`--check` writes nothing.** It performs detection and the drift pass, prints the report, and stops. No files written, no doc-comment edits, no delegation to a writer.
8. **Tool-missing never hard-fails.** If a doc generator binary is absent, print the install hint, fall back to reading the annotations directly (marking the result hand-derived), and continue. Report what was skipped.
9. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Document the working changes: doc comments + any API surface they touch
/backend-developer:gen-docs

# Document one module or package
/backend-developer:gen-docs src/orders

# Refresh only the OpenAPI contract from annotated routes
/backend-developer:gen-docs src/api --api

# Add/refresh doc comments on public symbols only, no spec, no README
/backend-developer:gen-docs internal/billing --comments

# Regenerate the service README: endpoint table, env vars, run + migrate commands
/backend-developer:gen-docs . --readme

# Drift check only — report spec/code mismatches, write nothing (CI-friendly)
/backend-developer:gen-docs . --check

# Force the stack in a polyglot repo
/backend-developer:gen-docs services/orders --api --stack jvm
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path/scope` | working changes (`git diff` set, staged included) | File, module, package, or directory to document. Detection is rooted at its enclosing project. |
| `--api` | auto | Generate/refresh the API reference: `openapi.yaml`/`openapi.json` from annotated routes, GraphQL SDL docs (schema descriptions), and gRPC `.proto` leading comments. |
| `--comments` | auto | Generate/refresh per-language doc comments on public symbols (JSDoc/TSDoc, godoc, Javadoc/KDoc, Python docstrings, PHPDoc, YARD, XML doc comments). |
| `--readme` | auto | Generate/refresh `README.md` (or the service's existing doc file): endpoint table, env-var/config reference, local-run + Docker Compose instructions, migration commands. |
| `--check` | off | Drift/coverage report only. Writes nothing, edits nothing, delegates to no writer. Exit-shaped for CI. |
| `--stack node\|go\|jvm\|python\|ruby\|php\|dotnet` | auto-detect | Override stack detection. Use in polyglot repos or when detection reports ambiguity. |

**Default layer selection (no `--api`/`--comments`/`--readme` given):** infer from the scope. A scope containing route/controller registrations → API + comments. A scope of plain modules/services → comments only. A scope of `.` (repo or service root) → all three. State the inferred selection in the report before writing anything.

## Detection: Stack → Doc Toolchain

Resolve the stack first (this is the same priority order as `/backend-developer:build-test`; the canonical marker → runtime → agent map lives in `skills/_shared/language-detection.md` — keep in sync, do not fork it), then pick the doc toolchain.

| Stack | Marker | API reference source | Doc-comment dialect | Owning agent |
|-------|--------|----------------------|---------------------|--------------|
| Node.js / TypeScript | `package.json` + server dep (express/fastify/nestjs/hono/koa) | NestJS `@nestjs/swagger` decorators (`SwaggerModule`), `fastify-swagger`, `express` + `swagger-jsdoc`, `tsoa`, zod-to-openapi | TSDoc (TS) / JSDoc (JS) — `@param`, `@returns`, `@throws`, `@example` | `node-developer` |
| Go | `go.mod` | `huma` (schema from handler types), `go-swagger` (`swagger:route` annotations), `swaggo/swag` (`@Router`, `@Success`) | godoc — sentence starting with the symbol name, `// Package x ...` on the package | `go-developer` |
| JVM (Java/Kotlin) | `pom.xml` / `build.gradle(.kts)` | `springdoc-openapi` (`/v3/api-docs`, `@Operation`, `@ApiResponse`, `@Schema`) | Javadoc (`@param`, `@return`, `@throws`) / KDoc (`@property`, `@receiver`) | `jvm-backend-developer` |
| Python web | `pyproject.toml` / `requirements.txt` / `uv.lock` | FastAPI auto-schema (`app.openapi()`, `response_model`, `Field(description=)`), drf-spectacular (Django REST), APISpec/Flask-Smorest | Docstrings — **Google or NumPy, whichever the repo already uses** | `python-backend-developer` |
| Ruby | `Gemfile` | Rswag (RSpec request specs → swagger), `rswag-specs`, `apipie-rails` | YARD (`@param`, `@return`, `@raise`) | `ruby-developer` |
| PHP | `composer.json` | Laravel Scribe (`@group`, `@bodyParam`, `@response`), `zircote/swagger-php` attributes, API Platform (Symfony) | PHPDoc (`@param`, `@return`, `@throws`) | `php-developer` |
| C# / .NET | `*.csproj` / `*.sln` | Swashbuckle / NSwag (`[ProducesResponseType]`, minimal-API `.WithOpenApi()`, .NET built-in `Microsoft.AspNetCore.OpenApi`) | XML doc comments (`<summary>`, `<param>`, `<returns>`, `<exception>`) | `dotnet-developer` |
| GraphQL (any stack) | `*.graphql` / `*.gql` / code-first schema builder | SDL descriptions (`"""..."""` on types/fields/args), schema print (`graphql-inspector`, `gql.tada`, `graphql-java` `SchemaPrinter`) | per host stack (above) | host-stack agent + `api-designer` |
| gRPC (any stack) | `*.proto` | proto leading comments on `service`/`rpc`/`message`/`field`; `protoc-gen-doc` for rendered output | per host stack (above) | host-stack agent + `api-designer` |

**Ambiguity rule:** if two stacks both hold real server targets in scope, or no marker decides, delegate the routing decision:

**Use Task tool with subagent_type="backend-developer:backend-developer"**
Prompt: "Resolve the documentation target stack for `{path}`. Markers found: {markers}. Server entry points found: {entrypoints}. Return exactly one stack and the owning agent, or say the scope must be split into per-service runs. Do not write any documentation."

## Workflow

### Phase 1: Detect & Inventory (Bash + Read + Grep)

1. Resolve the scope. No `path` → working changes (`git diff --name-only HEAD` plus staged). If `path` is given and does not exist, emit the Error Handling "path not found" message and stop.
2. Resolve the stack (table above) or honor `--stack`. On ambiguity, run the router delegation.
3. Resolve the doc layers to produce (flags, or the default selection rule). Announce them.
4. Inventory the API surface **from code**, not from any existing spec:
   - Route/controller registrations (`app.get`/`@Controller`+`@Get`, `@RestController`+`@GetMapping`, `router.HandleFunc`/`huma.Register`, `@app.get`/`APIRouter`, Rails `routes.rb`, Laravel `routes/api.php`, `[HttpGet]`/`MapGet`).
   - Per operation: method, path, path/query params, request body schema, response shapes per status, auth requirement (guard/middleware/`@PreAuthorize`/`Depends`), and error responses.
   - GraphQL: types, fields, args, resolvers. gRPC: services, rpcs, messages, fields.
5. Inventory the config surface: env-var reads (`process.env.X`, `os.Getenv`, `@Value`/`@ConfigurationProperties`, `os.environ`/`BaseSettings`, `ENV[...]`, `env()`, `IConfiguration`), plus `.env.example`, `config/*`, Helm/Compose `environment:` blocks. Record name, type, default, required, and whether it is a secret (never print secret *values*).
6. Inventory the run surface: `package.json` scripts, `Makefile`/`Taskfile` targets, `Dockerfile` + `docker-compose.yml` services and exposed ports, migration tool + commands (`prisma migrate`, `golang-migrate`, Flyway/Liquibase, Alembic, `rails db:migrate`, `php artisan migrate`, `dotnet ef database update` — see `/backend-developer:db-migrate`).
7. Locate existing docs: `openapi.yaml`/`openapi.json`/`swagger.json`, `*.graphql`, `*.proto`, `README.md`, `docs/`. Record their paths for the drift pass.

### Phase 2: Drift Pass (Read + Grep) — always runs when an existing spec/README is found

Compare the Phase 1 inventory against each existing artifact. Classify every difference:

| Class | Meaning | Action |
|-------|---------|--------|
| **Missing in spec** | Code implements it; spec has no entry | Additive — safe to write |
| **Missing in code** | Spec documents it; no route/handler implements it | **DRIFT** — report, do not delete from the spec |
| **Shape mismatch** | Same operation, different params / body / status codes / error shape / auth requirement | **DRIFT** — report both sides with file:line, write nothing for that operation |
| **Description only** | Operation matches; description absent or thin | Additive — safe to write |
| **Stale config** | README documents an env var no loader reads, or omits one that is required | **DRIFT** — report |
| **Stale command** | README's run/migrate command does not exist in scripts/Makefile/Compose | **DRIFT** — report |

Under `--check`, stop here and emit the report. Otherwise carry the drift list into the report and skip those operations during writing.

### Phase 3: Generate the API Reference (`--api`) — delegate

Prefer the framework's own generator; fall back to deriving from annotations, marked hand-derived.

- Node/TS:
  **Use Task tool with subagent_type="backend-developer:node-developer"**
  Prompt: "Generate/refresh the OpenAPI contract for the Node/TS service at `{path}`. Routes and handlers inventoried from code:\n```\n{inventory}\n```\nUse the project's existing mechanism ({NestJS @nestjs/swagger decorators | fastify-swagger | swagger-jsdoc | tsoa | zod-to-openapi}) — do NOT introduce a second one. For every operation document: method, path, params, request body schema (from the validation schema/DTO, with constraints), responses per status including the error shape, and the auth requirement from the guard/middleware. Do NOT document any endpoint, parameter, or status code that is not present in the inventory above. These operations are in DRIFT and MUST be skipped: {drift_ops}. Return the spec fragment/edits plus any decorator/annotation additions needed on the handlers."
- Go → **subagent_type="backend-developer:go-developer"** (same shape; `huma` type-derived schemas, or `swaggo`/`go-swagger` annotations matching whichever the repo already uses).
- JVM → **subagent_type="backend-developer:jvm-backend-developer"** (same shape; springdoc `@Operation`/`@ApiResponse`/`@Schema` on controllers; prefer capturing `/v3/api-docs` from a running app when the project already boots in CI).
- Python → **subagent_type="backend-developer:python-backend-developer"** (same shape; FastAPI `response_model` + `Field(description=)` + `responses={}`; drf-spectacular `@extend_schema` for Django REST; Flask-Smorest for Flask).
- Ruby → **subagent_type="backend-developer:ruby-developer"** (Rswag request specs that emit the swagger doc; keep the specs runnable — they are tests as well as docs).
- PHP → **subagent_type="backend-developer:php-developer"** (Laravel Scribe `@group`/`@bodyParam`/`@response`, or swagger-php attributes).
- .NET → **subagent_type="backend-developer:dotnet-developer"** (Swashbuckle/NSwag `[ProducesResponseType]`, `.WithOpenApi()`, XML-doc-fed summaries).

**GraphQL and gRPC** ride the host stack, with contract review by the API owner:

**Use Task tool with subagent_type="backend-developer:api-designer"**
Prompt: "Review and write the schema-level documentation for the {GraphQL SDL | gRPC proto} at `{schema_path}`. Types/fields/rpcs inventoried from the resolvers/handlers:\n```\n{inventory}\n```\nWrite SDL `\"\"\"...\"\"\"` descriptions on every type, field, and argument (GraphQL) or leading comments on every `service`, `rpc`, `message`, and field (proto), including nullability/optionality semantics, pagination contract, deprecation reasons with the replacement, and error semantics. Do NOT describe behavior absent from the inventory. Flag any field whose resolver contradicts its documented shape as drift rather than rewording it."

### Phase 4: Generate Doc Comments (`--comments`) — delegate

Detect the in-use dialect first (for Python: sample existing docstrings to decide Google vs NumPy; for Node: TSDoc vs JSDoc tag style), then delegate per stack. Priority order for symbols: exported/public API → interfaces/protocols/DTOs → cross-module internal types → non-obvious algorithms. Comment the *contract and the WHY*, never restate the signature.

Use the owning agent resolved in Phase 1 — `subagent_type="backend-developer:node-developer"`, `"backend-developer:go-developer"`, `"backend-developer:jvm-backend-developer"`, `"backend-developer:python-backend-developer"`, `"backend-developer:ruby-developer"`, `"backend-developer:php-developer"`, or `"backend-developer:dotnet-developer"` — with this prompt shape:

Prompt: "Add or refresh {TSDoc | godoc | Javadoc | KDoc | Google-style docstrings | NumPy-style docstrings | PHPDoc | YARD | XML doc comments} on the public symbols in `{path}`: {symbols}. The repo's existing style is {detected_style} — match it exactly and do NOT introduce a second style. For each symbol document: one-line purpose; parameters with units/constraints/nullability; return value including the empty/absent case; errors or exceptions raised and when; concurrency or transaction requirements (must be called inside a transaction, safe for concurrent use, blocking); and side effects (writes, network calls, cache invalidation). Do NOT restate the signature in prose and do NOT document behavior you cannot see in the body. Leave a `TODO(doc):` marker instead of guessing when the contract is genuinely unclear. Return the edited files."

### Phase 5: Generate Service Docs (`--readme`)

Assemble from the Phase 1 inventory (you own this; it is assembly, not authoring). Keep the existing document structure when one exists — update sections in place, never reorder or drop hand-written prose.

Required sections:

1. **What this service does** — one paragraph; keep the existing wording if present.
2. **Endpoints** — table of `Method | Path | Auth | Purpose`, generated from the route inventory; link to the spec file for the full contract.
3. **Configuration** — table of `Env var | Type | Required | Default | Purpose`. Secrets are listed by name with the value shown as `<set in your secret store>`; never emit a real value, never copy one out of `.env`.
4. **Running locally** — install/build/run commands from the actual scripts/targets, plus the `docker compose up` invocation and the services it starts (DB, cache, broker) with their ports, taken from `docker-compose.yml`.
5. **Migrations** — the project's real migrate/rollback/status commands.
6. **Testing** — point at `/backend-developer:build-test` and the project's own test commands.

### Phase 6: Verify & Report

1. If a spec was written, validate it: `npx --prefix <path> @redocly/cli lint <spec>` or `spectral lint <spec>` when available; `buf lint` for proto; `graphql-inspector validate`/schema build for SDL. Missing linter → skip with a note, never fail.
2. If doc comments were written, confirm the project still builds/type-checks — doc comments can break builds (malformed Javadoc under `-Xdoclint`, unterminated block comments, `.NET` `CS1591`/doc-XML errors). Reuse `/backend-developer:build-test` for the gate.
3. Re-run the Phase 2 comparison over what you wrote to confirm no new drift was introduced.
4. Emit the Output Format report.

## Output Format

```markdown
## Documentation Report

**Target:** {path or working changes}
**Stack:** {Node/TS | Go | JVM | Python | Ruby | PHP | .NET} ({marker})
**Layers:** {api | comments | readme} ({flagged | inferred from scope})
**Mode:** {write | --check (read-only)}
**Owning agent:** backend-developer:{agent}

### API Reference
| Artifact | Action | Operations | Source |
|----------|--------|------------|--------|
| openapi.yaml | updated / created / unchanged | {N documented, M skipped for drift} | {springdoc | FastAPI schema | @nestjs/swagger | huma | Scribe | Rswag | Swashbuckle | hand-derived} |
| schema.graphql | ... | {N types, M fields described} | SDL descriptions |
| order.proto | ... | {N rpcs, M messages commented} | leading comments |

### Doc Comments
| File | Symbols documented | Dialect | Notes |
|------|--------------------|---------|-------|
| src/orders/order.service.ts | 12 public | TSDoc | 2 left as TODO(doc) — contract unclear |

### Service Docs
- README.md: {sections updated} — {N endpoints, M env vars, migrations: {tool}}

### Drift Findings ({count}) — REPORTED, NOT OVERWRITTEN
| # | Kind | Spec says | Code says | Files |
|---|------|-----------|-----------|-------|
| 1 | shape mismatch | `POST /orders` → `201 Order` | handler returns `202 {jobId}` | openapi.yaml:88, src/orders/order.controller.ts:41 |
| 2 | missing in code | `DELETE /orders/{id}` documented | no route registered | openapi.yaml:140 |
| 3 | stale config | README lists `REDIS_TTL` | no loader reads it | README.md:52 |

**Resolution required:** each finding is either a spec bug (fix the spec) or a code bug (fix the handler). This command does not choose — re-run after the contract owner decides.

### Undocumentable ({count})
- {symbol/endpoint} — {why: dynamic route table, reflection-built handler, generated code with no source annotations}

### Verification
| Check | Result | Notes |
|-------|--------|-------|
| Spec lint (redocly/spectral/buf) | ✅ / ❌ / ⏭ skipped | {linter missing → skipped} |
| Build / type-check after comments | ✅ / ❌ / N/A | {doclint or CS1591 errors} |
| Re-drift check | ✅ no new drift / ❌ | |

<!-- On skipped tooling only: -->
### Skipped
- {generator/linter}: {missing binary} — install hint printed above; fell back to hand-derived output (marked in the file).
```

## Tool Availability

| Missing tool | Install hint | Fallback |
|--------------|--------------|----------|
| `@redocly/cli` / `spectral` | `npm i -D @redocly/cli` or `npm i -D @stoplight/spectral-cli` | Skip spec lint; note it |
| `buf` (proto) | `brew install bufbuild/buf/buf` | Skip proto lint; comments still written |
| `swag` (Go) | `go install github.com/swaggo/swag/cmd/swag@latest` | Derive from `swagger:`/`@Router` annotations by hand, mark hand-derived |
| `protoc-gen-doc` | `go install github.com/pseudomuto/protoc-gen-doc/cmd/protoc-gen-doc@latest` | Proto leading comments only, no rendered HTML |
| Laravel Scribe | `composer require --dev knuckleswtf/scribe` | Derive from route + FormRequest, mark hand-derived |
| Rswag | add `rswag-specs` to the `Gemfile` test group | Derive from `routes.rb` + request specs, mark hand-derived |
| A running app for `/v3/api-docs` | start the service, or use the annotation-only path | Read `@Operation`/`@Schema` annotations statically |

Never hard-fail on a missing tool — print the hint, fall back, report the skip.

## Error Handling

### Path not found
```
Error: Path not found: {path}
Suggestion: Pass a file, package, or directory that exists, e.g. /backend-developer:gen-docs src/orders
```

### No stack detected
```
Error: No back-end stack detected under {path}.
Looked for: package.json (with a server dep), go.mod, pom.xml/build.gradle,
pyproject.toml/requirements.txt/uv.lock, Gemfile, composer.json, *.csproj/*.sln.
Suggestion: Run from the service directory that holds the manifest, or pass --stack.
```

### Ambiguous stack
```
Warning: Two server stacks found in scope ({a} at {pathA}, {b} at {pathB}).
Routed the decision to backend-developer:backend-developer.
Suggestion: Pass --stack, or scope the run to one service directory.
```

### No API surface found (with `--api`)
```
Note: --api requested but no route/controller/resolver/rpc registrations were found under {path}.
Wrote no spec. Point at the module that registers routes, or drop --api for a
comments-only pass.
```

### Drift found
Not silently resolved. The affected operations are skipped during writing, listed in the Drift Findings table with both sides and their `file:line`, and the run reports **PARTIAL** rather than success. Re-run after the contract owner fixes the spec or the handler.

### Existing spec is hand-maintained and marked
If a spec carries a `x-generated: false` / `<!-- hand-maintained -->` marker, treat the whole file as drift-report-only: never write to it, report additions as suggestions in the report body instead.

### Undetectable docstring style (Python)
```
Warning: Could not detect an existing docstring style (no documented symbols in scope).
Defaulted to Google style. Pass a scope that includes documented modules, or set the
style in the project's linter config (ruff `pydocstyle.convention`) to make it explicit.
```

### Build breaks after comments
Not ignored. Report the failure, identify the offending comment (malformed Javadoc tag, unterminated block, invalid XML doc), fix it or revert that file, and re-run the gate. Never leave a repo that does not build.

## Related commands

- `/backend-developer:gen-api` — the inverse direction: scaffold handlers/DTOs *from* a contract. Use it when the spec is authoritative and the code is missing; use `gen-docs` when the code is authoritative and the docs lag.
- `/backend-developer:build-test` — the build gate this command reuses in Phase 6 to prove doc comments did not break compilation.
- `/backend-developer:db-migrate` — canonical source for the migration commands documented in the README's Migrations section.
- `/backend-developer:review-code` — run before documenting; documenting code that is about to change wastes the pass.
- `/backend-developer:analyze-security` — auth requirements captured in the endpoint table pair with its BOLA/BFLA and authz-boundary checks.
- `skills/api/openapi-contracts/SKILL.md` — contract-first workflow, spectral linting, codegen, and spec ⇄ server contract testing.
- `skills/api/rest-design/SKILL.md` — resource modeling, status codes, pagination, and error-shape conventions the endpoint table should reflect.
- `skills/api/graphql-design/SKILL.md` and `skills/api/grpc-design/SKILL.md` — SDL description and proto comment conventions.
- `skills/api/api-versioning/SKILL.md` — how to document deprecations and version transitions without breaking consumers.
- `skills/tooling/containerization/SKILL.md` — Compose service/port facts behind the README's local-run section.
