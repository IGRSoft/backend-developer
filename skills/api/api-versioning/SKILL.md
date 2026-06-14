---
name: api-versioning
description: >-
  API versioning strategy: URL vs header vs media-type schemes, semantic
  versioning applied to APIs, deprecation and sunset policy, backward/forward
  compatibility rules, and disciplined contract evolution. Use when picking a
  versioning scheme, shipping a breaking change without breaking callers,
  writing a deprecation policy, or deciding whether a change is additive or
  breaking.
---

# API Versioning

**Evolve a live contract without breaking deployed clients**

## When to Use

Use this skill when:
- Choosing how to version a new API (URL / header / media-type)
- Deciding whether a proposed change is backward-compatible or breaking
- Shipping a breaking change with a migration path for existing callers
- Writing a deprecation + sunset policy (timelines, headers, comms)
- Reasoning about forward compatibility (old client, new server)

Versioning is a cross-protocol concern: it layers onto
[rest-design](../rest-design/SKILL.md), [graphql-design](../graphql-design/SKILL.md),
and [grpc-design](../grpc-design/SKILL.md), and is encoded in the
[openapi-contracts](../openapi-contracts/SKILL.md) you publish.

## The Cardinal Rule: Prefer Not To Version

Every version you add is a surface you maintain forever. Before minting `v2`,
ask whether the change can be **additive** instead. Most changes can:

| Additive (no new version) | Breaking (needs a version/migration) |
|---------------------------|--------------------------------------|
| Add a new optional field to a response | Remove or rename a field |
| Add a new endpoint / RPC / type | Change a field's type or units |
| Add a new optional request param (safe default) | Make an optional param required |
| Add a new enum value (clients tolerate unknowns) | Change validation to reject previously-valid input |
| Relax a constraint | Change default behavior / response shape |
| Loosen a rate limit | Change auth/permission semantics |

Design clients to **ignore unknown fields** and **tolerate new enum values** so
the server can grow additively. That tolerance is what makes "don't version" possible.

## Versioning Schemes

| Scheme | Example | Pros | Cons |
|--------|---------|------|------|
| **URL path** | `GET /v1/orders` | Visible, trivial routing, cache-friendly | Couples version to resource identity; "URLs should be permanent" purists object |
| **Header** | `X-API-Version: 2024-10-01` | Clean URLs, resource identity stable | Invisible in logs/browsers; easy to forget; cache `Vary` |
| **Media type** | `Accept: application/vnd.acme.order.v2+json` | RESTful, per-representation | Verbose; tooling/cache friction |
| **Date-based** | `OpenAI-Version: 2024-11-01` | Each client pins a snapshot; server pins behavior per date | Need a behavior-routing layer |

Pragmatic default: **URL-path major versions** (`/v1`, `/v2`) for public REST
APIs — most visible, simplest to route and cache, easiest for client teams to
reason about. Use **date-based header pinning** when you have many small behavior
changes and want each client frozen to a snapshot without minting many path
versions. gRPC versions via the proto **package** (`orders.v2`); GraphQL doesn't
version — it evolves additively with `@deprecated`.

```http
# URL-path (recommended default for public REST)
GET /v2/orders/42

# Date-based header pinning (many incremental changes)
GET /orders/42
Acme-Version: 2024-10-01
```

## SemVer for APIs

Map semantic versioning onto the contract:

- **MAJOR** — a breaking change. New URL major (`/v2`) or new proto package. Old major stays live during the deprecation window.
- **MINOR** — additive, backward-compatible (new fields/endpoints). No new URL; advertise via changelog and (optionally) a minor header.
- **PATCH** — bug fixes that don't change the contract shape.

Only **MAJOR** forces clients to act. Keep minors/patches truly non-breaking so
they ship continuously without coordination.

## Backward vs Forward Compatibility

- **Backward compatible** = a new server still serves old clients. Achieved by additive-only changes.
- **Forward compatible** = an old server (or proxy) tolerates new-client requests. Achieved by clients sending only what old servers understand, and servers ignoring unknown inputs.

Both rest on the same discipline: **add, don't mutate**; **ignore the unknown**.
For gRPC, field numbers and `reserved` tombstones enforce this at the wire level
([grpc-design](../grpc-design/SKILL.md) > evolution).

## Deprecation & Sunset Policy

Breaking changes need a humane, signposted retirement — never a silent removal.

```http
# Responses from a deprecated version advertise their fate
Deprecation: true
Sunset: Wed, 01 Oct 2025 00:00:00 GMT
Link: <https://docs.acme.com/migrate/v1-to-v2>; rel="deprecation"
Warning: 299 - "v1 is deprecated; migrate to v2 by 2025-10-01"
```

Policy checklist:
1. **Announce** before deprecating — changelog, email, dashboard banner.
2. **Window**: publish a minimum support window (e.g., 6–12 months for public APIs) and stick to it.
3. **Signal in-band**: `Deprecation` + `Sunset` headers (RFC 8594) plus a migration `Link`.
4. **Measure** usage of the old version; chase the long-tail callers before sunset.
5. **Sunset**: after the window, old version returns `410 Gone` (REST) — not a silent `404`.

For GraphQL, mark fields `@deprecated(reason: "use totalCents")` and track field
usage before removal in the next breaking schema cut.

## Version Markers & Fallbacks

| Capability | Floor | Fallback when unavailable |
|------------|-------|---------------------------|
| `Deprecation`/`Sunset` headers | RFC 8594 (Sunset), Deprecation draft | `Warning` header + docs link |
| Breaking-change CI gate | `buf breaking` (proto), `oasdiff` (OpenAPI) | manual diff review of the merged contract |
| GraphQL field deprecation | `@deprecated` (spec) + usage analytics | changelog-only, riskier removal |
| Date-pinned routing | API gateway / app version router | URL-path majors |

Confirm tool support against the
[version-feature-matrix](../../_shared/version-feature-matrix.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Mobile app pinned to v1 breaks on deploy | breaking change shipped without a version | Revert; ship additively or mint `/v2` | this file, additive table |
| Clients break when a new enum value appears | clients reject unknown values | Make clients tolerate unknown enums | this file, compatibility |
| Old version vanished overnight, callers 404 | silent removal, no sunset | Restore; run deprecation window → `410` | this file, sunset policy |
| Proliferating `/v3`, `/v4`, ... | versioning instead of evolving | Audit which changes were truly breaking | this file, cardinal rule |
| `oasdiff`/`buf breaking` fails in CI | contract change is wire-breaking | New major or make it additive | this file, compatibility |

## Related Skills

- [rest-design](../rest-design/SKILL.md) — the resources being versioned
- [graphql-design](../graphql-design/SKILL.md) — additive evolution + `@deprecated`
- [grpc-design](../grpc-design/SKILL.md) — package versioning + wire compatibility
- [openapi-contracts](../openapi-contracts/SKILL.md) — `oasdiff`/`buf breaking` gates in CI
- [be-testing](../../quality/be-testing/SKILL.md) — contract tests that catch breakage early
- [api-security](../../quality/api-security/SKILL.md) — OWASP API9 (improper inventory of versions)
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — tool/spec floors
