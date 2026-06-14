---
name: api-security
description: >-
  API security for web/service back-ends built on the OWASP API Security Top 10
  (2023): broken object/function-level authorization (BOLA/BFLA), broken
  authentication, injection, SSRF, rate limiting, and security misconfiguration,
  plus secrets hygiene and input validation. Use when hardening an endpoint,
  reviewing authn/authz, adding rate limits, defending against SSRF or
  injection, or auditing a service against the OWASP API Top 10.
---

# API Security (OWASP API Top 10)

**Authorization is the #1 API bug class — check it server-side, per object, on every request**

## When to Use

Use this skill when:
- Designing or reviewing an endpoint that returns or mutates a resource a user owns
- Wiring authentication (OAuth2/OIDC, JWT, sessions, API keys) or authorization (RBAC/ABAC)
- Adding rate limiting, quotas, or resource caps to a public API
- Defending a URL/webhook field against SSRF, or a query against injection
- Auditing a service against the OWASP API Security Top 10 (2023)

Routing: object/function authz depth → [references/authz-bola-bfla.md](references/authz-bola-bfla.md);
authentication and token validation → [references/authn-tokens.md](references/authn-tokens.md);
injection, SSRF, rate limiting, and misconfiguration →
[references/injection-ssrf-ratelimit.md](references/injection-ssrf-ratelimit.md).

## The OWASP API Security Top 10 (2023)

> **Edition note (verified 2026):** the **API** Security Top 10 is a distinct project from the general OWASP Top 10 and its current edition is still **2023** — the general web-app OWASP Top 10:2025 (finalized early 2026) is a *different* list and does **not** supersede this one. This skill stays anchored on the API Security Top 10 (2023). Re-anchor only when OWASP ships a new *API* Security edition.

| ID | Risk | One-line defense | Reference |
|----|------|------------------|-----------|
| API1 | Broken Object Level Authorization (BOLA) | Re-check ownership of every object by its id, per request | [authz-bola-bfla](references/authz-bola-bfla.md) |
| API2 | Broken Authentication | Validate tokens fully (sig, `iss`, `aud`, `exp`); no weak/credential-stuffing-prone flows | [authn-tokens](references/authn-tokens.md) |
| API3 | Broken Object Property Level Authorization | Allow-list input fields and output fields; no mass-assignment | [authz-bola-bfla](references/authz-bola-bfla.md) |
| API4 | Unrestricted Resource Consumption | Rate limit, paginate, cap payload/page size, set timeouts | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| API5 | Broken Function Level Authorization (BFLA) | Re-check role/scope on every privileged route | [authz-bola-bfla](references/authz-bola-bfla.md) |
| API6 | Unrestricted Access to Sensitive Business Flows | Throttle/verify high-value flows (checkout, signup) | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| API7 | Server Side Request Forgery (SSRF) | Allow-list egress hosts; block link-local/metadata IPs | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| API8 | Security Misconfiguration | Least-privilege defaults, CORS allow-lists, security headers | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| API9 | Improper Inventory Management | Document & retire endpoints; no stray `/v1` debug routes | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| API10 | Unsafe Consumption of APIs | Validate upstream responses; treat third-party data as hostile | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |

Versions for the security tooling (ZAP, Schemathesis, scanners): skill [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md).

## API1/API5 — Authorization (the top bug class)

Authentication answers *who are you*; authorization answers *may you touch this*. BOLA (API1) is the single most exploited API flaw: the request is authenticated, but the handler trusts the `id` in the path and never re-checks ownership.

```ts
// BAD — BOLA: any logged-in user can read any order
app.get("/orders/:id", authd, async (req, res) => {
  const order = await db.order.findUnique({ where: { id: req.params.id } });
  res.json(order);
});

// GOOD — ownership is part of the query, not an afterthought
app.get("/orders/:id", authd, async (req, res) => {
  const order = await db.order.findFirst({
    where: { id: req.params.id, userId: req.user.id }, // scope to caller
  });
  if (!order) return res.sendStatus(404); // 404, not 403 — don't leak existence
  res.json(order);
});
```

```go
// GOOD — BFLA (API5): re-check role on the privileged route, not just at the gateway
func deleteUser(w http.ResponseWriter, r *http.Request) {
    claims := auth.FromContext(r.Context())
    if !claims.HasRole("admin") { // server-side, every time
        http.Error(w, "forbidden", http.StatusForbidden)
        return
    }
    // ...
}
```

Rule: **the authorization predicate lives in the data access, and roles/scopes are re-checked on the server for every privileged action.** Never rely on a client hiding a button or a gateway alone. Full ownership/RBAC/ABAC patterns and the API3 mass-assignment defense: [references/authz-bola-bfla.md](references/authz-bola-bfla.md).

## API2 — Authentication & Tokens

Validate a JWT fully or not at all. The classic failures: accepting `alg: none`, not verifying the signature, or ignoring `iss`/`aud`/`exp`.

```ts
import { jwtVerify, createRemoteJWKSet } from "jose";
const JWKS = createRemoteJWKSet(new URL(`${ISSUER}/.well-known/jwks.json`));

const { payload } = await jwtVerify(token, JWKS, {
  issuer: ISSUER,                  // pin iss
  audience: API_AUDIENCE,          // pin aud
  algorithms: ["EdDSA", "ES256"],  // pin to your IdP's algs; never "none" or HS/RS confusion
  clockTolerance: "30s",
});
```

Pin `algorithms` to exactly what your issuer signs with. Per RFC 8725 (JWT Best Current Practices), prefer `EdDSA` or `ES256`; `RS256` remains fine — the rule is to *name an explicit allow-list*, never let the token's `alg` header choose. For public clients (SPAs, mobile, CLIs, AI agents), sender-constrain the token with **DPoP (RFC 9449)** so a stolen bearer token can't be replayed.

Sessions, OAuth2/OIDC flows, DPoP, refresh-token rotation, and API-key handling: [references/authn-tokens.md](references/authn-tokens.md).

## Injection, SSRF, and resource limits

- **Injection** — always parameterize. Never build SQL/NoSQL/shell strings from user input.

```python
# GOOD — parameterized; the driver, not string formatting, binds values
cur.execute("SELECT * FROM users WHERE email = %s", (email,))
# BAD — f-string SQL is SQL injection
cur.execute(f"SELECT * FROM users WHERE email = '{email}'")
```

- **SSRF (API7)** — resolve the host, reject private/link-local/metadata ranges (`127.0.0.0/8`, `169.254.0.0/16`, `10/8`, `::1`), allow-list schemes and destinations, and disable redirects to new hosts.
- **Rate limiting (API4/API6)** — token-bucket per principal + per IP; cap page size and payload bytes; set per-request timeouts.

Full SSRF allow-listing, NoSQL/command-injection cases, rate-limit middleware per stack, CORS, and security headers: [references/injection-ssrf-ratelimit.md](references/injection-ssrf-ratelimit.md).

## Input validation & output shaping (API3)

Validate at the edge with a schema; allow-list fields in *and* out. This kills mass-assignment and over-exposure in one move.

```ts
import { z } from "zod";
const CreateUser = z.object({ email: z.string().email(), name: z.string().max(100) });
// role/isAdmin are NOT in the schema → cannot be set by the client (no mass-assignment)
const data = CreateUser.parse(req.body);
```

Equivalents: Go `go-playground/validator`, Java Bean Validation (`@Valid`), Pydantic in FastAPI, Rails strong parameters. Pair edge validation with injection-safe data access from [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md).

## Secrets hygiene & supply chain

- Secrets come from the environment or a secrets manager (Vault, AWS Secrets Manager) — never in source, config committed to git, or logs.
- Scan dependencies and images every CI run: `npm audit` / `osv-scanner` / `govulncheck` / `trivy`. Route findings through [be-dependency-manager](${CLAUDE_SKILL_DIR}/../) and the [be-security-auditor](${CLAUDE_SKILL_DIR}/../) review agent.

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| User reads another user's record by changing `id` | BOLA (API1): no ownership check | Scope the query to the caller; return 404 on miss | [authz-bola-bfla](references/authz-bola-bfla.md) |
| Non-admin succeeds on an admin route | BFLA (API5): authz only at gateway | Re-check role/scope in the handler | [authz-bola-bfla](references/authz-bola-bfla.md) |
| Client sets `isAdmin: true` on create/update | Mass-assignment (API3) | Allow-list input fields via schema/DTO | [authz-bola-bfla](references/authz-bola-bfla.md) |
| Forged JWT accepted | `alg: none` or unverified signature | Pin `algorithms`, verify sig + `iss`/`aud`/`exp` | [authn-tokens](references/authn-tokens.md) |
| Server fetches `169.254.169.254` | SSRF (API7): unvalidated URL field | Allow-list hosts; block private/metadata IPs | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| `' OR 1=1 --` changes query results | String-built SQL | Parameterize; use the ORM/driver binding | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| One client exhausts the service | No rate limit / resource cap (API4) | Token-bucket limiter + payload/page caps | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |
| Browser CORS error or wide-open `*` | Misconfigured CORS (API8) | Allow-list origins; no `*` with credentials | [injection-ssrf-ratelimit](references/injection-ssrf-ratelimit.md) |

## Deep-Dive References

- [references/authz-bola-bfla.md](references/authz-bola-bfla.md) — object- and function-level authorization (API1/3/5): ownership predicates, RBAC/ABAC, scopes, mass-assignment, the 404-vs-403 rule
- [references/authn-tokens.md](references/authn-tokens.md) — OAuth2/OIDC flows, JWT validation pitfalls, sessions, API keys, refresh-token rotation, token storage
- [references/injection-ssrf-ratelimit.md](references/injection-ssrf-ratelimit.md) — SQL/NoSQL/command injection, SSRF allow-listing, rate limiting & resource caps, CORS, security headers, misconfiguration

## Related Skills

- [be-testing](${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md) — write authz regression tests; fuzz the schema with Schemathesis
- [be-performance](${CLAUDE_SKILL_DIR}/quality/be-performance/SKILL.md) — rate limiting and resource caps overlap with backpressure
- [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md) — injection-safe data access, input validation, error-message hygiene
- [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md) — security tool and framework version minimums
