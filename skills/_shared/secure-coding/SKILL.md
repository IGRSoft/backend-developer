---
name: secure-coding
description: Non-negotiable security rules and risk-class defenses for web/service back-ends — OWASP API Security Top 10 (2023) mapping, parameterized-query injection defense, server-side authorization (BOLA/BFLA), SSRF egress control, rate limiting, and secrets hygiene across Node, Go, JVM, Python, Ruby, PHP, and .NET. Use when writing or reviewing back-end code that handles untrusted requests, builds queries, makes outbound calls, enforces authorization, or manages credentials.
---

# Secure Coding (Node / Go / JVM / Python / Ruby / PHP / .NET)

**Cross-stack security rules that gate every diff. Violations are P0 review findings, mapped to the OWASP API Security Top 10 (2023).**

## When to Use

Use this skill when:
- Code accepts untrusted input (request bodies, query/path params, headers, webhooks, upstream API responses, message-queue payloads).
- Code builds a SQL/NoSQL query, an ORM filter, or any data-driven command.
- Code authorizes access to an object or a function (route handler, RPC method, GraphQL resolver).
- Code makes an outbound HTTP/network call to a host derived from input (SSRF surface).
- Code handles secrets (DB credentials, API keys, signing keys, OAuth client secrets, session tokens).

## Non-Negotiable Rules

These mirror the global security rules and never have exceptions without a documented, reviewed justification:

1. **Validate every external input at the trust boundary** — assume every byte from a request, webhook, queue, or upstream API is hostile; check type, shape, length, and range against a schema before use. (OWASP **API8** misconfiguration, **API4** resource consumption.)
2. **Parameterized queries only** — never build SQL/NoSQL by string concatenation or template interpolation. Use bound parameters / prepared statements / ORM query builders exclusively. (Injection.)
3. **No secret in code, logs, or an env dump** — credentials come from a secret manager or scoped env at runtime, are redacted from every log line, and never appear in error responses or stack traces returned to clients. (**API8**.)
4. **Authorization is checked server-side on every object and function** — never trust a client-supplied role, tenant id, or "isAdmin" flag; re-derive the caller's identity and verify ownership/permission on each request. (**API1** BOLA, **API5** BFLA, **API3** property-level.)
5. **Control outbound egress (SSRF)** — a URL/host derived from input is fetched only through an allowlist with a resolved-IP check; block link-local, loopback, and cloud-metadata ranges. (**API7** SSRF.)
6. **Never disable a security control without documented justification** — TLS verification off, auth middleware bypassed, rate limiter removed, CSP relaxed, lint/audit suppressions: each needs an inline comment with the reason and a tracking reference.

> A change that breaks any of these does not pass DR/SR review. See [workflow-integration](../workflow-integration/SKILL.md) for stage gates.

## Injection-Safe Data Access (per stack)

Never interpolate untrusted data into a query string or hand it to a shell. Pass bound parameters to the driver/ORM, and an argument vector (never a shell string) to any subprocess.

| Stack | Banned | Required |
|-------|--------|----------|
| Node/TS | template-string SQL (`` `... ${id}` ``), `knex.raw` with interpolation, `child_process.exec(cmd)` / `spawn(..., {shell:true})`, `$where`/`$function` Mongo operators on input | `pg` parameterized (`$1`), Prisma/Drizzle/TypeORM query builders or tagged `sql\`\``, `execFile`/`spawn` with an argv array and `shell:false` |
| Go | `fmt.Sprintf` into `db.Query(...)`, `exec.Command("sh","-c",str)` | `database/sql` placeholders (`?` / `$1`) or GORM with bound args; `exec.Command(name, arg1, arg2)` arg vector — never a shell |
| JVM (Java/Kotlin) | `Statement` + string concat, JPQL/HQL string building, `Runtime.exec(String)` | `PreparedStatement` with `?`, JPA/Hibernate named/positional params, Spring Data derived queries; `ProcessBuilder(List<String>)` |
| Python | f-string/`%`/`+` into `cursor.execute(...)`, `sqlalchemy.text` with interpolation, `subprocess.run(..., shell=True)`, `os.system` | `cursor.execute(sql, params)` with `%s`/`:name` placeholders, SQLAlchemy bound params / ORM expressions; `subprocess.run([...], shell=False)` |
| Ruby | `where("name = '#{x}'")`, `find_by_sql` with interpolation, backticks/`system(str)` on input | `where("name = ?", x)` / hash conditions, `sanitize_sql_array`; `system([...])` argv form or `Open3` with an array |
| PHP | string-concatenated SQL, `mysqli_query` on built strings, `shell_exec`/`exec` on input | PDO prepared statements with bound params, Eloquent/Doctrine query builder; `proc_open` with an arg array, `escapeshellarg` only as a last resort |
| .NET (C#) | `SqlCommand` with `+` concat, `FromSqlRaw($"...")` interpolation, `Process.Start(string)` | parameterized `SqlCommand`/`DbParameter`, EF Core `FromSqlInterpolated` (auto-parameterizes) or LINQ; `ProcessStartInfo` with `ArgumentList` |

```ts
// DO — bound parameter, driver escapes nothing because it never sees SQL syntax
await pool.query("SELECT * FROM orders WHERE id = $1 AND tenant_id = $2", [id, tenantId]);
// DON'T — string-built SQL; `id` can inject
await pool.query(`SELECT * FROM orders WHERE id = ${id}`); // SQL injection
```

```go
// DO — placeholder; never Sprintf into the query
row := db.QueryRow("SELECT email FROM users WHERE id = $1", userID)
// DON'T
db.QueryRow(fmt.Sprintf("SELECT email FROM users WHERE id = %s", userID)) // injection
```

Bash/CI glue (deploy scripts, migration runners) follows the same argv-not-shell-string discipline — see system-developer's [bash-scripting](../../../../system-developer/skills/bash/bash-scripting/SKILL.md). Full doctrine, NoSQL operator-injection, SSRF egress allowlists, environment scrubbing, and the dynamic-code ban: [references/command-execution-and-injection.md](references/command-execution-and-injection.md).

## API Risk Classes → OWASP API Security Top 10 (2023)

| Risk class | What it is | OWASP ID | Defense |
|-----------|-----------|----------|---------|
| Broken object-level authz | Caller reads/writes an object they don't own by guessing its id | **API1 (BOLA)** | Re-derive caller identity from session/token; filter every query by owner/tenant; never trust a path/body id alone |
| Broken authentication | Weak/absent token validation, guessable sessions, no expiry | **API2** | Verify signature + `exp`/`aud`/`iss` on every request; rotate keys; short-lived tokens |
| Broken object property-level authz | Mass-assignment writes a privileged field; over-fetch leaks one | **API3** | Allowlist writable fields (DTO/serializer); allowlist response fields; never bind the raw body to the model |
| Unrestricted resource consumption | No pagination/size/rate limit → DoS or cost blowup | **API4** | Per-route rate limit, max body size, bounded page size, query timeouts, connection-pool caps |
| Broken function-level authz | A regular user reaches an admin/privileged route | **API5 (BFLA)** | Deny-by-default route guards; check role/scope server-side per function, not in the client |
| Unrestricted access to sensitive flows | Automation abuses checkout/signup/transfer flows | **API6** | Bot/abuse controls, idempotency keys, step-up auth on sensitive flows |
| Server-side request forgery | Server fetches an attacker-chosen URL (internal/metadata) | **API7 (SSRF)** | Egress allowlist + resolved-IP block of private/link-local/metadata ranges; no redirects to new hosts |
| Security misconfiguration | Verbose errors, default creds, permissive CORS, missing headers | **API8** | Hardened defaults, generic error bodies, strict CORS, security headers, no stack traces to clients |
| Improper inventory management | Forgotten/undocumented/old API versions still live | **API9** | API inventory + version sunset; remove debug/internal routes from prod |
| Unsafe consumption of upstream APIs | Trusting a third-party/upstream response blindly | **API10** | Validate upstream responses like any untrusted input; bound size; TLS-verify |

> Map each finding to its API ID in review notes so DR/SR can triage by impact. Injection (SQL/NoSQL/command) and supply-chain CVEs sit alongside this list and are equally P0.

## Authorization Boundaries (BOLA / BFLA)

| Risk | OWASP ID | Defense |
|------|----------|---------|
| Object id from path/body trusted as-is | **API1** | Load the object, then assert `obj.owner_id == caller.id` (or tenant scope) before returning/mutating; prefer queries already filtered by owner |
| Privileged route reachable without a role check | **API5** | Deny-by-default middleware/guard; require an explicit scope/role per handler; centralize the check, don't scatter it |
| Client-supplied role/tenant/`isAdmin` trusted | **API1/API5** | Derive identity and claims server-side from the verified session/token only; ignore any role field in the request body |
| GraphQL/gRPC method-level gaps | **API5** | Authorize per resolver/method, not just at the gateway; field-level authz for sensitive fields |

```ts
// DO — ownership re-checked server-side (defeats BOLA)
const order = await repo.findById(params.id);
if (!order || order.tenantId !== ctx.auth.tenantId) throw new NotFoundError();
// DON'T — trusts the path id; any authenticated user reads any order
return repo.findById(params.id);
```

Full authz patterns, JWT validation pitfalls, and session hardening: [references/command-execution-and-injection.md](references/command-execution-and-injection.md) (egress + auth) and [references/input-validation-and-parsing.md](references/input-validation-and-parsing.md) (property-level authz / mass-assignment).

## Rate Limiting & Resource Bounds (API4)

Unbounded work is a denial-of-service and a cost vector. Apply bounds at the boundary on every public route.

| Bound | Mechanism | Marker / fallback |
|-------|-----------|-------------------|
| Request rate | Token-bucket per identity/IP at the edge or middleware | Node `express-rate-limit`/`@fastify/rate-limit`; Go `golang.org/x/time/rate`; Spring `bucket4j`; ASP.NET `RateLimiter` middleware (**.NET 7+**); else reverse-proxy (NGINX/Envoy) limit |
| Body size | Reject oversized payloads before parsing | Express `express.json({limit})`, Fastify `bodyLimit`, Spring `spring.servlet.multipart.max-request-size`, ASP.NET `MaxRequestBodySize` |
| Page size | Cap `limit`/`pageSize`; default + hard max | Clamp server-side; cursor pagination for large sets — never `OFFSET` deep scans |
| Query/op timeout | Statement + request deadline | `statement_timeout` (Postgres), context deadline (Go), `@Transactional(timeout)` (Spring) |
| Concurrency | Connection-pool + worker caps | Tune pool max; bound fan-out to upstreams |

Version-specific limiter availability is in [version-feature-matrix.md](../version-feature-matrix.md).

## SSRF & Egress Control (API7)

| Risk | Defense |
|------|---------|
| Fetch of an attacker-supplied URL | Allowlist of permitted hosts; reject everything else (allow-list, not deny-list) |
| DNS rebinding / private-range pivot | Resolve the hostname, then block `127.0.0.0/8`, `10/8`, `172.16/12`, `192.168/16`, `169.254.0.0/16` (incl. `169.254.169.254` cloud metadata), `::1`, `fc00::/7` before connecting |
| Redirect to a new host | Disable or re-validate redirects; do not follow a 30x to an off-allowlist host |
| User-controlled webhook target | Sign+verify; restrict to a registered, validated destination |

```python
# Resolve, then verify the IP is public BEFORE connecting (defeats DNS-rebinding SSRF).
import ipaddress, socket
def assert_public(host: str) -> None:
    for _, _, _, _, sockaddr in socket.getaddrinfo(host, None):
        ip = ipaddress.ip_address(sockaddr[0])
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
            raise ValueError("egress to non-public address blocked")
```

Egress allowlist construction and redirect handling: [references/command-execution-and-injection.md](references/command-execution-and-injection.md).

## Secrets Hygiene

| Rule | Node/TS | Go | JVM | Python | Ruby/PHP/.NET |
|------|---------|-----|-----|--------|----------------|
| Source of truth | secret manager (Vault/SM/KMS) or scoped env; never in repo | same | same | same | same |
| Never log | redact in the logger (`pino` redact paths, `slog` `ReplaceAttr`) | `slog` attr filter | Logback/Log4j masking converter | logging filter / `structlog` processor | framework log scrubber |
| Never in errors to client | generic message; full detail server-side only | same | same | same | same |
| Never in argv | pass via env/file/secret-manager — argv is world-readable via `ps`/`/proc/PID/cmdline` | same | same | same | same |
| Rotate & scope | short-lived tokens, least-privilege DB roles | same | same | same | same |

A secret committed to git history is compromised even after deletion — rotate it, do not just `git rm`. CI must fail on a detected secret (gitleaks/trufflehog) and on a high-severity dependency CVE.

## Diagnostic Table

| Symptom / finding | Likely cause | OWASP | Fix | Reference |
|-------------------|-------------|-------|-----|-----------|
| String-built / template-interpolated SQL | SQL injection | Injection | bound params / prepared statement / ORM builder | [command-execution](references/command-execution-and-injection.md) |
| Mongo `$where`/`$function` or operator from body | NoSQL injection | Injection | strip operators, validate types, use typed queries | [input-validation](references/input-validation-and-parsing.md) |
| `exec`/`system`/`shell:true` with interpolated input | command injection | Injection | argv array, `shell:false`, no shell | [command-execution](references/command-execution-and-injection.md) |
| Handler returns object by id with no owner check | broken object-level authz | **API1** | filter query by owner/tenant; re-check ownership | this file, Authorization Boundaries |
| Admin route reachable by normal user | broken function-level authz | **API5** | deny-by-default guard + per-route role check | this file, Authorization Boundaries |
| Raw request body bound to model | mass-assignment | **API3** | allowlist writable fields (DTO/serializer) | [input-validation](references/input-validation-and-parsing.md) |
| No pagination/rate limit on a public route | resource exhaustion | **API4** | rate limit + max body + bounded page size | this file, Rate Limiting |
| Server fetches user-supplied URL unchecked | SSRF | **API7** | egress allowlist + resolved-IP block | [command-execution](references/command-execution-and-injection.md) |
| Stack trace / DB error in client response | misconfiguration / info leak | **API8** | generic error body; log detail server-side | [input-validation](references/input-validation-and-parsing.md) |
| Upstream API response trusted blindly | unsafe consumption | **API10** | validate+bound the response like any input | [input-validation](references/input-validation-and-parsing.md) |
| Secret in argv / log / error / repo | credential disclosure | **API8** | secret manager + redact + rotate | this file, Secrets Hygiene |
| `npm audit`/`govulncheck`/`trivy` high finding | vulnerable dependency | supply chain | upgrade/patch; pin; fail CI | [command-execution](references/command-execution-and-injection.md) |

## Related Skills

- [input-validation-and-parsing.md](references/input-validation-and-parsing.md) — schema validation at trust boundaries, pagination/size limits (API4), mass-assignment / property-level authz (API3), safe deserialization
- [command-execution-and-injection.md](references/command-execution-and-injection.md) — injection-safe execution, SSRF egress allowlists, secrets via secret-manager, supply-chain scanning
- [version-feature-matrix.md](../version-feature-matrix.md) — runtime/framework versions and feature/fallback lookup
- [workflow-integration/SKILL.md](../workflow-integration/SKILL.md) — SR/DR security gates and handoff contract
