---
name: api-scaffold
description: Scaffold endpoints/services/handlers from an OpenAPI, GraphQL SDL, or gRPC proto contract
argument-hint: "<schema: openapi.yaml|schema.graphql|service.proto> [--stack node|go|jvm|python] [--dry-run]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
estimated-cost:
  min-tokens: 2000
  max-tokens: 18000
  model-distribution:
    haiku: 10%
    sonnet: 75%
    opus: 15%
---

# API Scaffold
<!-- Updated: June 2026 -->

Turn an API contract — OpenAPI, GraphQL SDL, or a gRPC `.proto` — into runnable server-side scaffolding: handler stubs, typed request/response DTOs with validation, route/resolver/service wiring, and a matching test skeleton. The contract is the source of truth; the generated code conforms to it, never the reverse. Detection picks the target stack from the repository (or `--stack`), then the owning stack developer fills in the bodies.

[Extended thinking: This command is contract-first. The schema defines operations, types, and constraints; scaffolding mechanically derives shapes from it so hand-written logic only fills behavior, not structure. It resolves exactly one schema kind and one target stack per invocation, prefers the ecosystem's standard codegen tool when present (openapi-generator, oapi-codegen, buf, gqlgen, NSwag, datamodel-code-generator), and degrades to a hand-rolled scaffold via the stack developer when no codegen binary is installed. Because a contract change must propagate to handlers, DTOs, and tests together, the command emits all three layers in one pass and routes ambiguities or contract design questions to the api-designer rather than guessing. Keep the dry-run plan deterministic so it can be reviewed before any file is written.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve exactly one schema kind and one stack.** Detect the schema type from the file (OpenAPI / GraphQL SDL / proto), then resolve a single target stack via repository detection or `--stack`. Do NOT scaffold for two stacks in one invocation. If detection is ambiguous, ask for `--stack` rather than guessing.
2. **Contract is the source of truth.** Generated DTOs, routes, and validation derive from the schema. Never edit the schema to fit generated code. If the schema is under-specified (missing types, no response shape, no operationId), stop and route the gap to the api-designer.
3. **Single-command Bash invocations.** Run codegen with the tool's own path/output flags (`openapi-generator generate -i <schema> -o <out>`, `oapi-codegen -package api <schema>`, `buf generate`, `gqlgen generate`). Never `cd`-chain or `&&`-chain — scoped Bash patterns do not match compound commands.
4. **Emit all three layers together.** A scaffold pass produces handler stubs, request/response DTOs with validation, route/resolver wiring, AND a test skeleton. Do NOT emit handlers without DTOs, or code without a test skeleton.
5. **Never overwrite hand-written logic.** If a target handler/DTO file already exists, write generated code to a sibling (`*.gen.ts`, `*_gen.go`, `*Generated.java`) or report the conflict — never clobber existing bodies. Generated, owned-by-tool files are regenerable; hand-edited files are not.
6. **`--dry-run` writes nothing.** It prints the resolved schema kind, stack, file plan, and chosen codegen tool (or hand-roll fallback), then stops. No files, no delegation.
7. **Tool-missing never hard-fails.** If the ecosystem's codegen binary is absent, print the install hint and hand off to the owning stack developer to scaffold by hand from the schema. Report what was skipped.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Scaffold from an OpenAPI contract, auto-detecting the stack
/backend-developer:api-scaffold api/openapi.yaml

# Force the Go stack
/backend-developer:api-scaffold api/openapi.yaml --stack go

# Scaffold a GraphQL resolver layer
/backend-developer:api-scaffold graph/schema.graphql --stack node

# Scaffold gRPC service stubs from a proto, JVM target
/backend-developer:api-scaffold proto/order.proto --stack jvm

# Preview the file plan without writing anything
/backend-developer:api-scaffold api/openapi.yaml --dry-run
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `schema` | (required) | Path to the contract: `*.yaml`/`*.yml`/`*.json` (OpenAPI), `*.graphql`/`*.gql` (GraphQL SDL), or `*.proto` (gRPC). Schema kind is detected from extension + content. |
| `--stack node\|go\|jvm\|python` | auto-detect | Target server stack. Auto-detection scans the repo manifest (see Stack Detection). Pass explicitly to override or when detection is ambiguous. |
| `--dry-run` | off | Print the resolved schema kind, stack, codegen tool, and file plan, then stop. Writes nothing and delegates to no agent. |

`ruby`, `php`, and `dotnet` projects are detected for routing purposes but scaffold via the stack developer directly (no first-party codegen step in this command's table); the plan reports the hand-roll path for them.

## Schema Detection

Inspect `schema` and resolve the **first** match. Extension is the primary signal; content confirms it.

| Marker | Schema kind | Contract semantics |
|--------|-------------|--------------------|
| `openapi:` / `swagger:` key in a `.yaml`/`.yml`/`.json` | OpenAPI 3.x | paths → handlers, `components.schemas` → DTOs, `operationId` → handler name |
| `type Query`/`type Mutation`/`schema {` in a `.graphql`/`.gql` | GraphQL SDL | root fields → resolvers, object/input types → DTOs |
| `syntax = "proto3"` + `service ... { rpc ... }` in a `.proto` | gRPC (proto3) | `service` → server interface, `rpc` → handler methods, `message` → DTOs |

If the file matches no marker (e.g. a JSON Schema fragment, a Postman collection), emit the Error Handling "unrecognized schema" message and stop.

## Stack Detection

Scan the repository root (and `schema`'s directory upward) and apply the **first** match top-down. This map mirrors the router's `skill: stack-detection` — keep it in sync, do not fork the routing logic.

| Priority | Marker | Stack | Owning agent |
|----------|--------|-------|--------------|
| 1 | `package.json` (with `typescript`/`@types/node`, or a server dep like `express`/`fastify`/`@nestjs/core`/`hono`) | Node.js / TypeScript | `node-developer` |
| 2 | `go.mod` | Go | `go-developer` |
| 3 | `pom.xml` / `build.gradle` / `build.gradle.kts` | JVM (Java/Kotlin, Spring Boot) | `jvm-backend-developer` |
| 4 | `pyproject.toml` / `requirements.txt` (with `fastapi`/`django`/`flask`) | Python | `python-backend-developer` |
| 5 | `Gemfile` (Rails) | Ruby | `ruby-developer` |
| 6 | `composer.json` (Laravel/Symfony) | PHP | `php-developer` |
| 7 | `*.csproj` / `*.sln` (ASP.NET Core) | .NET | `dotnet-developer` |

**Tie-break notes:**

- A polyglot monorepo can carry several manifests. The manifest **nearest** `schema` (walking up from the schema's directory) wins; if still ambiguous, require `--stack`.
- A `package.json` that only holds repo tooling (lint/format scripts, no server framework dep) is not a Node service — prefer the next real server manifest, or require `--stack`.
- When the contract is a `.proto` and multiple stacks are present, `--stack` is recommended because proto codegen is plugin-per-language; report the ambiguity rather than guessing.

## Codegen Command Table

Prefer the ecosystem's standard generator when its binary is present. Each command is single-invocation. `<out>` is the scaffold output dir resolved in Phase 1.

| Stack | OpenAPI | GraphQL SDL | gRPC (proto) |
|-------|---------|-------------|--------------|
| Node / TS | `openapi-generator generate -i <schema> -g typescript-axios -o <out>` (server: `-g typescript-node`) | `graphql-codegen --config <cfg>` (typed resolvers) | `buf generate` (with `protoc-gen-ts`/`@grpc/grpc-js` plugins) |
| Go | `oapi-codegen -package api -generate types,server,spec <schema>` | `gqlgen generate` (config-driven) | `buf generate` (with `protoc-gen-go` + `protoc-gen-go-grpc`) |
| JVM | `openapi-generator generate -i <schema> -g spring -o <out>` | (hand-roll via stack dev; no first-party step) | `buf generate` (with `protoc-gen-grpc-java`) or Gradle protobuf plugin |
| Python | `datamodel-code-generator --input <schema> --output <out>/models.py` (+ FastAPI route stubs) | (hand-roll via stack dev) | `buf generate` (with `protoc-gen-python` + `grpcio-tools`) |

Notes:
- The codegen output is the **starting** scaffold — DTOs and route signatures. The owning stack developer then writes the handler bodies, validation wiring, and test skeleton to match the project's conventions.
- Validation: OpenAPI `format`/`pattern`/`required`/`enum` and proto field rules map to the stack's validator (Zod/class-validator for Node, `go-playground/validator` for Go, Bean Validation for JVM, Pydantic for Python). Generated DTOs carry these constraints.
- When no codegen binary is present, the table column is skipped and the stack developer hand-rolls the scaffold from the parsed schema (see Tool Availability).

## Workflow

### Phase 1: Detect & Plan (Bash + Read)

1. Confirm `schema` exists. If not, emit the Error Handling "schema not found" message and stop.
2. Detect the schema kind from extension + content (Schema Detection table). If none matches, emit "unrecognized schema" and stop.
3. Resolve the target stack: honor `--stack` if given, else walk the Stack Detection table from `schema`'s directory upward. If ambiguous, emit the Error Handling "ambiguous stack" message and stop.
4. Resolve `<out>` — the conventional API dir for the stack (`src/api/`, `internal/api/`, `src/main/java/.../api/`, `app/api/`). Create it only in a non-dry-run.
5. Parse the schema to enumerate operations, types, and validation constraints. Build the file plan (one entry per handler, DTO group, route module, test file).
6. Verify the codegen binary exists (`command -v openapi-generator`/`oapi-codegen`/`buf`/`gqlgen`/`datamodel-codegen`). If missing, mark the plan as hand-roll (see Tool Availability).
7. If `--dry-run`: emit the Plan section of the Output Format and stop. No writes, no delegation.

### Phase 2: Generate Scaffold (Bash or hand-roll)

1. If a codegen binary is available, run its command from the table, teeing to `.context/logs/scaffold-<timestamp>.log`. Capture `${PIPESTATUS[0]}`; on non-zero, go to Failure Triage with stage `codegen`.
2. Generated DTOs/types land in `<out>` (or sibling `*.gen.*` files where hand-written code exists — never clobber, per Rule 5).
3. If no codegen binary, skip this phase and mark all three layers for hand-roll by the stack developer.

### Phase 3: Wire & Fill (delegate to stack developer)

Hand the owning stack developer the schema, the generated scaffold (or the parsed contract for hand-roll), and the file plan. It writes handler stubs, request/response DTOs with validation, route/resolver/service wiring, and the test skeleton — conforming to the contract and the project's conventions.

- Node / TS → **Use Task tool with subagent_type="backend-developer:node-developer"**
  Prompt: "Scaffold a {schema-kind} API for the contract at `{schema}` into `{out}`. {Generated DTOs are in `{out}` / No codegen tool present — parse the contract and hand-roll}. Produce: handler stubs (one per operation), request/response DTOs with validation (Zod or class-validator per the project), route/resolver wiring, and a test skeleton (vitest/jest) with one pending test per operation. The contract is the source of truth — match operationIds, types, and required/format/enum constraints exactly. Do not implement business logic; leave typed `// TODO: implement` bodies."
- Go → **subagent_type="backend-developer:go-developer"** (same shape; validation via `go-playground/validator`, test skeleton via `testing` + Testcontainers stub).
- JVM → **subagent_type="backend-developer:jvm-backend-developer"** (Spring Boot controllers/services, Bean Validation DTOs, JUnit skeleton).
- Python → **subagent_type="backend-developer:python-backend-developer"** (FastAPI routers / Django views, Pydantic models, pytest skeleton).
- Ruby / PHP / .NET → the matching `backend-developer:{ruby-developer|php-developer|dotnet-developer}` (hand-roll path).

### Phase 4: Contract Questions (delegate to api-designer)

If Phase 1 parsing surfaced a contract gap — missing `operationId`, undefined `$ref`, no error response shape, version/inventory concerns, or an unclear resource model — do NOT guess. Route the question to the api-designer with the offending fragment.

- **Use Task tool with subagent_type="backend-developer:api-designer"**
  Prompt: "The contract `{schema}` has a gap blocking scaffolding: {describe gap, include the fragment}. Propose the contract-level fix (the schema, not the code), keeping it consistent with the rest of the document and REST/GraphQL/gRPC conventions. Return the corrected schema fragment."

After the api-designer returns a corrected fragment, re-run Phase 1 parsing against the updated schema. Do NOT auto-apply schema edits silently — report the change.

### Phase 5: Report

Emit the Output Format summary. On a clean scaffold, list the written files and the next step (implement handler bodies, run the test skeleton).

## Failure Triage

Triggered only when codegen exits non-zero. Steps:

1. **Parse the first error** from the log (`openapi-generator` validation errors, `buf` lint/breaking errors, `oapi-codegen` parse errors, `gqlgen` config errors).
2. **Classify the stage:**

   | Symptom in log | Stage | Route to |
   |----------------|-------|----------|
   | Schema fails the generator's own validation (`Spec has 2 errors`, unresolved `$ref`, `buf lint` failures), invalid contract | `contract` | `api-designer` |
   | Generator config/template/plugin error (`unknown generator`, missing `protoc-gen-*` plugin, bad `gqlgen.yml`) | `codegen` | owning stack developer |
   | Generated code does not compile / fails to wire into the project | `wiring` | owning stack developer |

3. **Extract a tight excerpt** — the first error plus ~10 surrounding lines, not the whole log. Include the log path.
4. **Delegate** to `api-designer` for `contract`-stage failures, otherwise to the owning stack developer with the excerpt and the file plan.
5. After the fix returns, re-run from the failing phase (re-parse if the contract changed, otherwise re-run codegen). Report each cycle — do not iterate silently.

## Tool Availability

Before running codegen, confirm its binary exists. If missing, print the hint, mark the plan as hand-roll, and hand off to the stack developer — never hard-fail.

| Missing tool | Install hint |
|--------------|--------------|
| `openapi-generator` | `brew install openapi-generator` (or `npm i -g @openapitools/openapi-generator-cli`) |
| `oapi-codegen` | `go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@latest` |
| `buf` | `brew install bufbuild/buf/buf` (plus the per-language `protoc-gen-*` plugins) |
| `gqlgen` | `go install github.com/99designs/gqlgen@latest` |
| `graphql-codegen` | `npm i -D @graphql-codegen/cli` |
| `datamodel-code-generator` | `uv tool install datamodel-code-generator` (or `pipx install datamodel-code-generator`) |

When the codegen tool is missing, the stack developer parses the contract and writes the scaffold by hand — the output is the same three layers, just without the generator step.

## Output Format

```markdown
## API Scaffold Report

**Contract:** {schema} ({OpenAPI 3.x | GraphQL SDL | gRPC proto3})
**Stack:** {Node/TS | Go | JVM | Python | Ruby | PHP | .NET} ({manifest marker})
**Codegen:** {tool name | hand-roll (tool missing)}
**Output dir:** {out}
**Log:** .context/logs/scaffold-{timestamp}.log

### Plan
| Operation | Handler | DTOs | Test |
|-----------|---------|------|------|
| {operationId / rpc / field} | {file} | {request/response types} | {test file} |

<!-- Non-dry-run only: -->
### Generated
| File | Layer | Status |
|------|-------|--------|
| {path} | handler / DTO / route / test | ✅ written / ↪ *.gen sibling (existing file) |

**Delegated to:** backend-developer:{stack-developer}{, backend-developer:api-designer if contract gap}

**Next step:** implement the `// TODO` handler bodies, then run the test skeleton ({npm test | go test ./... | mvn test | pytest}).

<!-- On failure only: -->
### Failure Triage
- **Stage:** {contract | codegen | wiring}
- **First error:** {one-line summary}
- **Delegated to:** backend-developer:{agent}
- **Proposed fix:** {summary, or "see agent output"}
```

## Error Handling

### Schema not found
```
Error: Schema not found: {schema}
Suggestion: Pass a contract file that exists, e.g. /backend-developer:api-scaffold api/openapi.yaml
```

### Unrecognized schema
```
Error: Could not recognize {schema} as OpenAPI, GraphQL SDL, or a gRPC proto.
Looked for: openapi:/swagger: (OpenAPI), type Query/schema { (GraphQL),
syntax = "proto3" + service (gRPC).
Suggestion: Confirm the file is a supported API contract, not a JSON Schema fragment or collection export.
```

### Ambiguous stack
```
Error: Could not resolve a single target stack under {repo root}.
Found manifests: {list}.
Suggestion: Re-run with --stack node|go|jvm|python (or run from the service subdir nearest the schema).
```

### Contract gap (under-specified schema)
Not a hard error. Route the gap to `backend-developer:api-designer` (Phase 4), report the proposed contract fix, and re-parse. Scaffolding resumes once the contract is complete.

### Codegen tool missing
Print the install hint from Tool Availability, mark the plan as hand-roll, and hand off to the stack developer. The command still produces a scaffold — only the generator step is skipped. Report what was skipped.

## See Also

- `skill: stack-detection` — canonical manifest → stack → agent routing (keep the priority table in sync).
- `skill: api-contracts` — OpenAPI 3.x, GraphQL SDL, and proto3 conventions; operationId/resource modeling; error-response shapes.
- `skill: _shared/version-feature-matrix` — framework/runtime version markers and fallbacks (Express/NestJS/Fastify/Hono, Gin/Echo/chi, Spring Boot, FastAPI/Django) used to pick generator targets.
- `/backend-developer:db-schema` — when the contract implies persistence; generate migrations and ORM models to back the DTOs.
- `/backend-developer:api-test` — once handlers exist, expand the test skeleton into contract + integration tests (Testcontainers, request/response transcripts).
- `/backend-developer:security-review` — audit the scaffolded endpoints against the OWASP API Security Top 10 (BOLA, broken auth, missing function-level authz).
