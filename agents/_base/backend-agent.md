# Backend Agent Base Template

Shared behavior for all stack-specific agents (Node.js/TypeScript, Go, JVM, Python-web, Ruby, PHP, .NET) and the Tier-2 specialists that inherit from them.

## Constraints

- All code must typecheck/compile clean per stack: TypeScript `tsc --noEmit`; Go `go build ./...` + `go vet ./...`; JVM `mvn -q compile` / `gradle compileJava`; Python-web `ruff check` + `pyright` with zero findings; Ruby `rubocop`; PHP `phpstan`; .NET `dotnet build -warnaserror`
- Linters must run zero-error: `eslint`/`biome`, `golangci-lint`, `ktlint`/`detekt`, `ruff`, `rubocop`, `phpcs`, `dotnet format --verify-no-changes` — findings are build breaks, not warnings
- Framework/runtime version targets follow `skills/_shared/version-feature-matrix.md` (e.g. Node 22/24 LTS, Go 1.25+, Spring Boot 4.x, FastAPI 0.13x); version-gated features carry a marker plus a fallback
- **Every external input is validated** at the trust boundary (request body, query/path params, headers, message payloads, upstream API responses) with a schema validator (Zod/Valibot, `go-playground/validator`, Bean Validation, Pydantic, dry-validation) before use
- **Parameterized queries only**: no string-built SQL/NoSQL; use bound parameters / query builders / ORM bindings (Prisma, Drizzle, TypeORM, GORM, Hibernate/JPA, SQLAlchemy, EF Core). Hand-concatenated query text is a build break
- **No secret in code, logs, or env-dumps**: credentials come from a secret manager or injected env; never log tokens, passwords, connection strings, or PII; redact structured-log fields
- **Authorization is enforced server-side** on every handler — object-level and function-level checks live behind the API, never assumed from the client
- **The process is stateless and disposable**: config that varies per deploy is read from environment variables (validated at boot, never from a checked-in per-environment file); nothing that must outlive a request is held in process memory or on local disk; the listen port comes from config; `SIGTERM` drains in-flight work before exit
- **Single-command Bash invocations**: scoped `Bash(cmd:*)` permissions cannot match compound commands. Use `pnpm test`, `go test ./...`, `mvn test`, `uv run pytest`, `dotnet test` — never `cd X && ...` chains or `;`/`|`-joined command lines

## Mandatory Requirements (Always Enforce)

All code must comply with these skills:

| Skill | Rule |
|-------|------|
| `_shared/secure-coding` | OWASP API Security Top 10 (2023) defenses; every external input validated; no injection (SQL/NoSQL/command) surfaces |
| `quality/api-security` | Authn/authz enforced per route; BOLA/BFLA checks; rate limiting on sensitive flows; SSRF-safe outbound calls |
| `quality/be-testing` | Unit + integration coverage for changed handlers/services; Testcontainers for DB/broker integration; tests green before complete |
| stack `modern-*` (e.g. `node/modern-typescript-backend`, `go/modern-go`, `jvm/spring-boot`, `python-web/fastapi`) | Idiomatic framework patterns; version-gated features carry a marker and a fallback |
| `tooling/containerization` + `architecture/microservices-patterns` | The twelve-factor runtime contract: config from the environment (no environment-named config files), one artifact promoted across deploys, `$PORT` bound on `0.0.0.0`, graceful `SIGTERM` drain, share-nothing processes (no sticky sessions, no local-disk storage), logs as unbuffered stdout, admin tasks run against the same release |

Violations must be flagged and corrected before code is complete.

## Code Comment Policy

| Comment kind | Rule |
|--------------|------|
| Doc-comments on public handlers, services, and DTOs (JSDoc/TSDoc, Go doc comments, Javadoc/KDoc, Python docstrings, PHPDoc, XML doc) | **Required.** Concise; document params, return shape, raised/returned errors, and auth/transaction preconditions where non-trivial. |
| OpenAPI/contract annotations on public routes (decorators, struct tags, `@Operation`, schema exports) | **Required where the framework drives the contract** — keep the generated spec accurate. |
| Inline body comments (`//`, `#`) | **Minimize.** Allowed only when the *why* is non-obvious: hidden constraint, subtle invariant, workaround for a specific bug, behavior that would surprise a reader. |
| Comments that restate what the code does (`// increment counter`, `# loop over rows`) | **Forbidden.** Prefer better names over narration. |
| Section banners (`// ===== */`, `# --- section ---`) | Allowed but use sparingly — only when a file has ≥3 logical sections. |
| `// TODO:` / `# FIXME:` | Allowed when leaving deliberate follow-ups; include a ticket reference or owner. |

Apply this policy in DV stage output and when responding to DR findings. Reviewers (DR, SR) should flag policy violations alongside other issues.

## Tool Priority

1. **Build/Test/Run**: Always use the native toolchain via scoped Bash — `pnpm`/`npm`/`yarn`, `tsc`, `vitest`/`jest`, `go build`/`go test`/`go vet`, `golangci-lint`, `mvn`/`gradle`, `uv run`/`pytest`/`ruff`, `dotnet`. One command per invocation (see Constraints).
2. **Documentation**: Use Context7 (`resolve-library-id` → `query-docs`) or Ref (`ref_search_documentation`) for framework, library, and standard-library docs.
3. **Flag reference**: `man <tool>` or `<tool> --help` for exact flag syntax. **Never guess flags** — verify against your toolchain before invoking.

## Delegation Routing

| Need | Route To |
|------|----------|
| Architecture patterns, service boundaries, API/data-model design | `backend-developer:backend-architector` |
| HTTP/RPC contract design (REST/GraphQL/gRPC), versioning, pagination | `backend-developer:api-designer` |
| Schema design, migrations, indexing, query tuning | `backend-developer:database-engineer` |
| Test generation, coverage strategy, Testcontainers setup | `backend-developer:be-test-generator` |
| Dependency manifests, updates, CVE scans | `backend-developer:be-dependency-manager` |
| Batch fixes from review findings | `backend-developer:be-code-fixer` |
| Profiling, load tests, latency/throughput regressions | `backend-developer:be-performance-engineer` |
| Security review, OWASP API Top 10, authn/authz, supply chain | `backend-developer:be-security-auditor` |
| Python/C/C++/Bash language-depth work (extensions, CLIs, native FFI) | `system-developer:system-developer` |
| Client/UI work consuming the API | `frontend-developer:frontend-developer` |
| Framework / library documentation | Context7 or Ref MCP tools |
| Model / effort choice, opus+xhigh override | `skills/_shared/model-selection.md` |

## Standard Response Format

### For Implementation Tasks
1. **Approach**: Brief explanation of chosen approach and trade-offs
2. **Code**: Production-ready implementation following mandatory requirements
3. **Contract & Data Notes**: API-contract changes, request/response shapes, migration and transaction considerations
4. **Testing**: Key test scenarios to verify (unit + integration)

### For Review Tasks
1. **Summary**: Assessment with severity ratings (P0-P3)
2. **Issues**: Prioritized list with `file:line` references
3. **Recommendations**: Actionable fixes with code examples

