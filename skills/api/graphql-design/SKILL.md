---
name: graphql-design
description: >-
  GraphQL API design: schema-first SDL, query/mutation/subscription modeling,
  killing N+1 with DataLoader batching, Relay-style connection pagination,
  typed error handling, persisted queries, and depth/complexity limits. Use
  when authoring a GraphQL schema, fixing resolver N+1 fan-out, paginating with
  connections, shaping errors, or hardening a public GraphQL endpoint.
---

# GraphQL Design

**Schema-first contracts, batched resolvers, and the limits that keep a flexible API from being a DoS surface**

## When to Use

Use this skill when:
- Authoring or reviewing a GraphQL schema (types, queries, mutations, subscriptions)
- A GraphQL request fans out into hundreds/thousands of DB calls (N+1)
- Paginating a list with Relay connections (`edges`/`pageInfo`/cursors)
- Deciding how to surface errors (typed result unions vs the `errors` array)
- Hardening a public endpoint: persisted queries, depth/complexity limits, introspection

Routing: query-cost defense, persisted queries, introspection control, and
resolver-level authorization → [references/graphql-security.md](references/graphql-security.md);
OWASP API Top 10 → [api-security](../../quality/api-security/SKILL.md).

## Schema-First SDL

Design the **schema** as the contract; generate or bind resolvers to it. SDL is reviewed and merged before resolver code.

```graphql
type Query {
  order(id: ID!): Order
  orders(first: Int!, after: String): OrderConnection!
}

type Mutation {
  cancelOrder(input: CancelOrderInput!): CancelOrderPayload!
}

type Subscription {
  orderStatusChanged(orderId: ID!): Order!
}

type Order {
  id: ID!
  status: OrderStatus!
  total: Money!
  items: [OrderItem!]!        # resolved via DataLoader, not a loop of queries
  customer: Customer!         # ditto
}

enum OrderStatus { PENDING PAID CANCELLED }
```

Conventions:
- **Mutations take a single `input` object and return a `payload` object** — both extensible without breaking the field signature.
- Non-null (`!`) liberally on outputs you guarantee; sparingly on inputs (nullable = optional).
- Enums for closed sets; never raw strings the client must match.

## N+1 and DataLoader

The default trap: a list resolver returns N orders, then a field resolver fires
one query **per order** for `customer`/`items`. DataLoader batches the per-item
calls in a tick into one query and caches within the request.

```ts
// Per-request loader: collects ids in a tick, does ONE query
const customerLoader = new DataLoader(async (ids: readonly string[]) => {
  const rows = await db.customer.findMany({ where: { id: { in: [...ids] } } });
  const byId = new Map(rows.map((r) => [r.id, r]));
  return ids.map((id) => byId.get(id) ?? null); // MUST return in input order
});

const resolvers = {
  Order: {
    customer: (order, _args, ctx) => ctx.loaders.customer.load(order.customerId),
  },
};
```

```python
# Strawberry / Ariadne — same idea via aiodataloader
from aiodataloader import DataLoader

class CustomerLoader(DataLoader):
    async def batch_load_fn(self, ids):
        rows = await fetch_customers(ids)          # ONE query
        by_id = {r.id: r for r in rows}
        return [by_id.get(i) for i in ids]         # ordered to match ids
```

Rules:
- **One loader instance per request** (caching must not bleed across users).
- The batch function **must return results in the same order as the input keys**, padding misses with `null`.
- Loaders solve N+1; they do not replace authorization — each loaded object still needs an object-level check (OWASP API1).

## Pagination: Relay Connections

```graphql
type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
}
type OrderEdge { node: Order!  cursor: String! }
type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

```graphql
query { orders(first: 20, after: "eyJpZCI6MTI4M30=") {
  edges { node { id status } cursor }
  pageInfo { hasNextPage endCursor }
} }
```

- Cursors are **opaque** (base64 of a keyset position) — same keyset principle as REST cursor pagination ([rest-design](../rest-design/SKILL.md) > pagination).
- `first`/`after` (forward) and `last`/`before` (backward); reject requests with neither a sane `first`/`last` bound (unbounded fetch = OWASP API4).

## Error Handling

Two complementary mechanisms:

1. **Top-level `errors[]`** for protocol/unexpected failures (auth, validation, server faults). Attach a stable `extensions.code`:

```json
{
  "data": null,
  "errors": [{
    "message": "Not authorized to view this order",
    "path": ["order"],
    "extensions": { "code": "FORBIDDEN" }
  }]
}
```

2. **Typed result unions** for expected domain outcomes — make failure part of the schema so clients handle it exhaustively:

```graphql
union CancelOrderResult = CancelOrderPayload | OrderAlreadyShipped | OrderNotFound

type CancelOrderPayload { order: Order! }
type OrderAlreadyShipped { shippedAt: DateTime! }
```

- Don't leak internals in `message` (OWASP API8) — map exceptions to safe codes; gate verbose errors behind a dev flag. See [secure-coding](../../_shared/secure-coding/SKILL.md).

## Hardening: Limits & Persisted Queries

GraphQL's flexibility is a DoS surface — an attacker can craft one deeply nested
query that explodes into millions of resolutions:

- **Depth limiting** — reject queries past a max nesting depth.
- **Complexity/cost analysis** — assign field costs, cap total per request.
- **Persisted queries** — clients send a hash of a pre-registered query; the server rejects anything not on the allow-list. Public production endpoints should run persisted-only.
- **Disable introspection in production** (or gate it) for non-public schemas.

Full implementation, cost-rule examples, and resolver-level authorization:
[references/graphql-security.md](references/graphql-security.md).

## Version Markers & Fallbacks

| Capability | Floor | Fallback when unavailable |
|------------|-------|---------------------------|
| `@defer` / `@stream` incremental delivery | draft spec; Apollo Server 4+, some clients | return the full response; no incremental delivery |
| `@oneOf` input objects | draft spec | validate "exactly one" in the resolver |
| Subscriptions over WebSocket | `graphql-ws` protocol (current) | poll a query, or SSE |
| Persisted queries | Apollo APQ, relay-compiler, manual registry | accept arbitrary queries only behind auth + cost limits |

GraphQL has no API version number — evolution is additive (see
[api-versioning](../api-versioning/SKILL.md) > GraphQL). Confirm server/client
support against the [version-feature-matrix](../../_shared/version-feature-matrix.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| One query → thousands of DB calls | resolver N+1, no batching | Per-request DataLoader | this file, DataLoader |
| DataLoader returns wrong object per key | batch fn not ordered to input ids | Map results back in key order | this file, DataLoader |
| Cached user A data shown to user B | loader shared across requests | New loader instance per request | this file, DataLoader |
| Single request pins CPU/memory | deep/expensive query, no cap | Depth + complexity limits | [references/graphql-security.md](references/graphql-security.md) |
| Attacker enumerates schema | introspection on in prod | Disable/gate introspection | [references/graphql-security.md](references/graphql-security.md) |
| Client can't distinguish error kinds | everything in `errors[]` | Typed result unions + `extensions.code` | this file, errors |
| User reads others' records via `node(id:)` | no object-level authz in resolver | Per-object check (OWASP API1) | [api-security](../../quality/api-security/SKILL.md) |

## Deep-Dive References

- [references/graphql-security.md](references/graphql-security.md) — query
  depth/complexity limiting with cost rules, persisted-query allow-listing,
  introspection control, batching-attack defense, resolver-level authorization

## Related Skills

- [rest-design](../rest-design/SKILL.md) — when fixed resources beat client-shaped queries
- [grpc-design](../grpc-design/SKILL.md) — internal service-to-service alternative
- [api-versioning](../api-versioning/SKILL.md) — additive schema evolution, deprecation `@deprecated`
- [openapi-contracts](../openapi-contracts/SKILL.md) — SDL as the reviewable, codegen'd source of truth
- [api-security](../../quality/api-security/SKILL.md) — OWASP API4 (resource consumption) on GraphQL
- [be-testing](../../quality/be-testing/SKILL.md) — schema + resolver integration tests
- [query-optimization](../../data/query-optimization/SKILL.md) — the queries DataLoader batches
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — spec/server floors
