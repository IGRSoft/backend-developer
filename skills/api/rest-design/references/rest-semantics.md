# REST Semantics Deep Dive

Conditional requests, idempotency-key storage, HATEOAS, content negotiation, and
partial responses — the HTTP details that turn a Level-2 API into a predictable
contract. Back to [rest-design](../SKILL.md).

## Conditional Requests & ETags

An `ETag` is an opaque validator for a representation. Two strengths:

| Strength | Syntax | Means | Use for |
|----------|--------|-------|---------|
| Strong | `ETag: "abc"` | byte-for-byte identical | `If-Match` write concurrency |
| Weak | `ETag: W/"abc"` | semantically equivalent | `If-None-Match` cache validation |

```http
# Read validation — bandwidth save
GET /documents/42
If-None-Match: W/"rev-17"
→ 304 Not Modified            # body omitted; client reuses its copy

# Write concurrency — optimistic locking
PUT /documents/42
If-Match: "rev-17"
→ 412 Precondition Failed     # someone else wrote rev-18 first; client refetches
```

Generation strategies (pick one, be consistent):
- **Version/revision column**: `ETag: "rev-17"` straight from a monotonically increasing row version. Cheapest; survives reformatting.
- **Content hash**: `ETag` = hash of the canonical serialized body. Robust but recomputed each response.
- **Updated-at + id**: weak ETag from `updated_at` precision. Beware sub-second updates colliding.

Never derive an ETag from a secret or from data the client shouldn't infer.

## Idempotency-Key Storage

The key turns at-least-once delivery into effectively-once processing. Store a
record keyed by `(idempotency_key, route)`:

```sql
CREATE TABLE idempotency_keys (
  key            text        NOT NULL,
  route          text        NOT NULL,
  request_hash   text        NOT NULL,   -- fingerprint of method+path+body
  status_code    int,
  response_body  jsonb,
  locked_at      timestamptz,            -- in-flight guard
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (key, route)
);
```

Flow:
1. `INSERT ... ON CONFLICT DO NOTHING`. If the insert wins, you own the request — process it, then write `status_code`/`response_body`.
2. If the insert loses (row exists):
   - same `request_hash` and a stored response → replay it verbatim.
   - same `request_hash` but still `locked_at` (no response yet) → `409 Conflict` or `425 Too Early`; client retries with backoff.
   - **different** `request_hash` → `422`/`409`: a key was reused for a different payload (client bug or attack).
3. Sweep rows past TTL (e.g., 24h).

Redis variant for high throughput: `SET key <fingerprint> NX EX 86400` as the lock, with the response cached under a sibling key. The atomic `NX` is what prevents two concurrent retries from both executing the side effect.

The `request_hash` matters: without it, a client could reuse a key across genuinely different requests and silently get the wrong cached answer.

## HATEOAS: Links and When They Pay Off

Level-3 hypermedia embeds the legal next transitions in the representation:

```json
{
  "id": "ord_8f3",
  "status": "pending_payment",
  "total": 3000,
  "_links": {
    "self":   { "href": "/orders/ord_8f3" },
    "pay":    { "href": "/orders/ord_8f3/payment", "method": "POST" },
    "cancel": { "href": "/orders/ord_8f3/cancel",  "method": "POST" }
  }
}
```

When a paid order is fetched, `pay` disappears and `refund` appears — the client
drives the workflow off links instead of hard-coding state rules.

Adopt HATEOAS when:
- The resource is a **state machine** and legal actions vary by state.
- You want to relocate endpoints without breaking clients (they follow links).

Skip it when clients are generated from an OpenAPI spec and already know every
route — the link payload is dead weight they ignore. Most CRUD APIs don't need
it; workflow/checkout/approval APIs often do.

## Content Negotiation

```http
GET /reports/42
Accept: application/json, text/csv;q=0.8
Accept-Language: de-DE, en;q=0.7
→ 200 ... Content-Type: application/json; charset=utf-8
          Vary: Accept, Accept-Language
```

- Honor `Accept` for genuinely different representations (JSON vs CSV vs PDF).
  Return `406 Not Acceptable` if you can't satisfy any listed type.
- Always set `Vary` on negotiated headers so caches key correctly.
- Don't use `Accept` for versioning unless you've committed to media-type
  versioning — see [api-versioning](../../api-versioning/SKILL.md).

## Partial Responses & Field Selection

For chatty clients on big resources, allow sparse fieldsets without reinventing
GraphQL:

```http
GET /users/42?fields=id,name,email
```

Keep it allow-listed (only expose selectable fields you intend to support) and
document it in the spec. If field selection demand grows broad and nested,
that's a signal to evaluate [graphql-design](../../graphql-design/SKILL.md).

## Related

- [rest-design](../SKILL.md) — the parent skill
- [api-versioning](../../api-versioning/SKILL.md) — media-type versioning vs content negotiation
- [api-security](../../../quality/api-security/SKILL.md) — idempotency-key abuse, ETag inference risks
