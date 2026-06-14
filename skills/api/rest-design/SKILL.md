---
name: rest-design
description: >-
  REST API design: resource modeling, Richardson maturity, correct status
  codes, cursor vs offset pagination, RFC 9457 problem+json errors, idempotency
  keys, HATEOAS, and caching headers. Use when designing or reviewing an
  HTTP/JSON API, choosing status codes, deciding pagination strategy, returning
  structured errors, making writes safe to retry, or adding cache/conditional
  request semantics.
---

# REST Design

**Resources, verbs, status codes, and the contract semantics that make HTTP/JSON predictable**

## When to Use

Use this skill when:
- Modeling resources and URLs for a new HTTP/JSON API
- Choosing the right status code for a result (not just `200`/`500`)
- Picking a pagination strategy (cursor vs offset) for a list endpoint
- Returning machine-readable errors (`application/problem+json`, RFC 9457)
- Making non-idempotent writes safe under client retries
- Adding caching/conditional-request headers (`ETag`, `Cache-Control`)

Routing: deep HTTP semantics (conditional requests, idempotency-key storage,
HATEOAS link shapes, content negotiation) →
[references/rest-semantics.md](references/rest-semantics.md); OWASP API Top 10
controls → [api-security](../../quality/api-security/SKILL.md); making the spec
authoritative → [openapi-contracts](../openapi-contracts/SKILL.md).

## Resource Modeling

Model **nouns**, not actions. The HTTP method is the verb.

| Do | Don't |
|----|-------|
| `POST /orders` | `POST /createOrder` |
| `GET /orders/{id}` | `GET /getOrderById?id=` |
| `DELETE /orders/{id}` | `POST /orders/{id}/delete` |
| `GET /orders/{id}/items` (sub-collection) | `GET /orderItems?order=` |
| `POST /orders/{id}/cancel` (action that isn't CRUD) | `POST /cancelOrder` |

- Collections are plural (`/orders`), members are `/orders/{id}`.
- Use sub-resources for ownership (`/orders/{id}/items`); use query params for filtering/sorting (`?status=open&sort=-created_at`).
- Genuine state transitions that aren't a clean CRUD map get a **controller sub-resource** (`POST /orders/{id}/cancel`) — explicit and idempotency-friendly.

## Richardson Maturity (target: Level 2, consider Level 3)

| Level | Has | Reality |
|-------|-----|---------|
| 0 | One URI, one verb (RPC-over-HTTP) | Avoid for resource APIs |
| 1 | Many resources, one verb | Half-measure |
| 2 | Resources + HTTP verbs + status codes | **Baseline target** |
| 3 | Level 2 + hypermedia (HATEOAS) | Adopt when clients benefit from discoverable links |

Most APIs should land solidly at **Level 2**. HATEOAS (Level 3) pays off for workflow/state-machine resources where the next legal actions vary; otherwise it adds payload weight clients ignore — see [references/rest-semantics.md](references/rest-semantics.md) > HATEOAS.

## Status Codes That Carry Meaning

```http
201 Created            # POST that created a resource; include Location
202 Accepted           # async accepted, not yet done (return a status URL)
204 No Content         # successful DELETE / write with no body
400 Bad Request        # malformed syntax / unparseable body
401 Unauthorized       # missing/invalid authentication
403 Forbidden          # authenticated but not allowed (authorization)
404 Not Found          # resource absent — also use to hide existence (BOLA)
409 Conflict           # version/state conflict, duplicate idempotency replay
422 Unprocessable      # syntactically valid, semantically invalid
429 Too Many Requests  # rate limited; include Retry-After
503 Service Unavailable# overload/maintenance; include Retry-After
```

- **Never return `200` with an error body.** The status line is the first thing intermediaries and clients branch on.
- `401` = "who are you?"; `403` = "I know you, no." Don't swap them.
- Prefer `404` over `403` when leaking existence is itself a vulnerability (object-level authorization, OWASP API1) — see [api-security](../../quality/api-security/SKILL.md).

## Pagination: Cursor vs Offset

```http
# Offset (simple, fine for small/stable sets)
GET /orders?limit=50&offset=100

# Cursor (stable under inserts/deletes; the default for large/mutating sets)
GET /orders?limit=50&cursor=eyJpZCI6MTI4MywiYyI6Ii4uLiJ9
```

```json
{
  "data": [ /* ... */ ],
  "page": {
    "next_cursor": "eyJpZCI6MTMzMywiYyI6Ii4uLiJ9",
    "has_more": true
  }
}
```

| | Offset | Cursor (keyset) |
|---|--------|-----------------|
| Deep pages | `OFFSET 100000` scans + discards rows | seeks on indexed key — flat cost |
| Stability under inserts | rows shift, duplicates/skips | stable: anchored to a key |
| Random page jump | yes (`?page=37`) | no (sequential only) |
| Total count | cheap-ish | usually omitted (expensive) |

Default to **cursor (keyset)** pagination for anything that grows or mutates. Encode the cursor opaquely (e.g., base64 of `{last_id, last_sort_value}`); never expose raw offsets clients can tamper with. The deep-page `OFFSET` cost is a query-optimization problem too — see [query-optimization](../../data/query-optimization/SKILL.md).

## Errors: RFC 9457 problem+json

One error shape across the whole API. `Content-Type: application/problem+json`.

```json
{
  "type": "https://errors.example.com/insufficient-funds",
  "title": "Insufficient funds",
  "status": 422,
  "detail": "Account 8f3 balance 12.00 is below the 30.00 charge.",
  "instance": "/accounts/8f3/charges/01HV...",
  "errors": [
    { "field": "amount", "message": "exceeds available balance" }
  ]
}
```

- `type` is a stable URI clients switch on; `title` is human-readable and stable; `detail` is instance-specific.
- Extension members (`errors[]`, `trace_id`) are allowed and encouraged.
- **Never leak stack traces, SQL, or internal hostnames** in `detail` — that is OWASP API8 (security misconfiguration). See [secure-coding](../../_shared/secure-coding/SKILL.md).

Framework wiring:

```ts
// Fastify / Express — central error mapper
app.setErrorHandler((err, req, reply) => {
  const p = toProblem(err); // map domain errors → {type,title,status,detail}
  reply.code(p.status).type("application/problem+json").send(p);
});
```

```python
# FastAPI — RFC 9457 via exception handler
from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(DomainError)
async def domain_error(_: Request, exc: DomainError):
    return JSONResponse(
        status_code=exc.status,
        media_type="application/problem+json",
        content={"type": exc.type, "title": exc.title,
                 "status": exc.status, "detail": exc.detail},
    )
```

## Idempotency Keys (safe retries for writes)

`POST`/`PATCH` aren't idempotent by default — a retried request after a dropped response can double-charge or double-create. Accept a client-supplied `Idempotency-Key`:

```http
POST /charges
Idempotency-Key: 7c1f4e2a-...-9b
Content-Type: application/json

{ "amount": 3000, "currency": "usd" }
```

Server contract:
1. First request with a key → process, store `(key → response, status, request fingerprint)`.
2. Replay with the **same key + same body** → return the **stored** response, status `200`/`201` (or `409` if a different body reused a live key).
3. Keys expire (e.g., 24h). Store atomically (a unique constraint on the key, or `SET NX` in Redis) so concurrent retries don't both execute.

Storage and fingerprinting details: [references/rest-semantics.md](references/rest-semantics.md) > idempotency.

## Caching & Conditional Requests

```http
# Response
ETag: "9a2f-rev17"
Cache-Control: private, max-age=60
Last-Modified: Tue, 10 Jun 2025 12:00:00 GMT

# Conditional read — server returns 304 Not Modified (empty body) on match
GET /orders/42
If-None-Match: "9a2f-rev17"

# Optimistic concurrency on write — 412 Precondition Failed on stale ETag
PUT /orders/42
If-Match: "9a2f-rev17"
```

- `ETag` + `If-None-Match` saves bandwidth on reads; `If-Match` gives you optimistic concurrency control on writes (reject stale updates with `412`).
- `Cache-Control: private` for per-user data; `no-store` for secrets/tokens.
- Conditional-request mechanics and weak vs strong ETags: [references/rest-semantics.md](references/rest-semantics.md) > conditional requests.

## Version Markers & Fallbacks

| Capability | Floor | Fallback when unavailable |
|------------|-------|---------------------------|
| `application/problem+json` (RFC 9457) | RFC 9457 (supersedes 7807) | RFC 7807 media type is wire-compatible; keep the same fields |
| Native problem+json helper | Spring 6 `ProblemDetail`, ASP.NET Core `ProblemDetails`, NestJS filter | Hand-roll the JSON shape + `Content-Type` |
| Keyset pagination | any RDBMS with an indexed sort key | offset only for small/stable sets |
| `Idempotency-Key` middleware | Stripe-style libs, custom filter | Redis `SET NX` + unique constraint |

Confirm framework support against the [version-feature-matrix](../../_shared/version-feature-matrix.md) before relying on a built-in.

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Clients parse `200` then re-check body for errors | error overloaded onto success status | Return real `4xx`/`5xx` + problem+json | this file, status codes |
| Retried payment charged twice | non-idempotent `POST`, no key | Add `Idempotency-Key` + atomic store | this file, idempotency |
| Page 2000 times out; rows duplicate/skip | offset pagination on a mutating set | Switch to keyset/cursor pagination | this file, pagination |
| `403` returned where `401` belonged (or vice-versa) | auth vs authz conflated | `401` unauthenticated, `403` unauthorized | this file, status codes |
| Stack trace in error response | exception serialized to client | Central mapper; strip internals | [secure-coding](../../_shared/secure-coding/SKILL.md) |
| Stale update silently overwrites newer data | no optimistic concurrency | `If-Match`/`ETag` → `412` on conflict | [references/rest-semantics.md](references/rest-semantics.md) |
| Two clients enumerate others' records via `/orders/{id}` | missing object-level authz | Per-object check (OWASP API1) | [api-security](../../quality/api-security/SKILL.md) |

## Deep-Dive References

- [references/rest-semantics.md](references/rest-semantics.md) — conditional
  requests & ETag strength, idempotency-key storage and fingerprinting, HATEOAS
  link patterns and when they pay off, content negotiation, partial responses

## Related Skills

- [graphql-design](../graphql-design/SKILL.md) — when client-shaped views beat fixed resources
- [grpc-design](../grpc-design/SKILL.md) — when internal latency/streaming beats HTTP/JSON
- [api-versioning](../api-versioning/SKILL.md) — evolving these resources without breaking callers
- [openapi-contracts](../openapi-contracts/SKILL.md) — encoding this design as a reviewable spec
- [api-security](../../quality/api-security/SKILL.md) — OWASP API Top 10 controls on these endpoints
- [be-testing](../../quality/be-testing/SKILL.md) — contract + integration tests for the API
- [query-optimization](../../data/query-optimization/SKILL.md) — keyset pagination at the SQL layer
- [secure-coding](../../_shared/secure-coding/SKILL.md) — injection-safe handlers, error hygiene
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — spec/framework floors
