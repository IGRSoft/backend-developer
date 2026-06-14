# GraphQL Security & Query-Cost Deep Dive

Depth/complexity limiting, persisted queries, introspection control, batching
defense, and resolver-level authorization — the controls that keep a flexible
schema from becoming a denial-of-service or data-exfiltration surface. Back to
[graphql-design](../SKILL.md).

## The Threat: Query Cost Is Client-Controlled

REST cost is roughly bounded per endpoint. GraphQL lets the client compose the
query, so a single request can demand unbounded work:

```graphql
# Pathological: each level multiplies the work
query {
  orders(first: 100) {
    edges { node {
      customer { orders(first: 100) {
        edges { node { items { product { reviews(first: 100) {
          edges { node { author { orders(first: 100) { edges { node { id } } } } } }
        } } } } }
      } }
    } }
  }
}
```

This maps to OWASP **API4 (unrestricted resource consumption)**. Defenses stack;
use more than one.

## Depth Limiting

Reject queries nested past a fixed depth. Cheap, coarse, catches the obvious case.

```ts
import depthLimit from "graphql-depth-limit";

const server = new ApolloServer({
  schema,
  validationRules: [depthLimit(8)], // reject anything deeper than 8 levels
});
```

Pick a depth that comfortably exceeds your deepest legitimate query and no more.

## Complexity / Cost Analysis

Assign each field a cost; multiply by pagination args; cap the total. Finer than
depth — a shallow-but-wide query still gets caught.

```ts
import { createComplexityLimitRule } from "graphql-validation-complexity";

const server = new ApolloServer({
  schema,
  validationRules: [
    createComplexityLimitRule(1000, {
      // list fields cost = childCost * (first|last)
      listFactor: 10,
      objectCost: 1,
      scalarCost: 0,
    }),
  ],
});
```

Or declarative per-field cost directives:

```graphql
type Query {
  orders(first: Int!): OrderConnection! @cost(complexity: 5, multipliers: ["first"])
}
```

Budget guidance: estimate cost of your heaviest sanctioned dashboard query, set
the cap ~2x above it, alert when requests approach the cap.

## Persisted Queries (Allow-Listing)

In production, register the exact set of queries your clients ship and accept
only those by hash. Arbitrary ad-hoc queries are rejected.

```ts
// Client sends only the hash; server resolves it from the registry
// { "extensions": { "persistedQuery": { "sha256Hash": "a1b2..." } } }
const server = new ApolloServer({
  schema,
  persistedQueries: { cache, ttl: null },           // APQ
  // For strict allow-listing, reject any query not in the manifest:
  plugins: [enforcePersistedManifest(manifest)],
});
```

- **APQ** (automatic persisted queries) reduces payload size but still accepts new queries on first sight — not an allow-list by itself.
- **Manifest allow-listing** (relay-compiler / persistgraphql output) is the real control for public endpoints: unknown hash → reject.

## Introspection Control

Introspection lets any client download the full schema — convenient in dev, a
reconnaissance gift in prod for non-public APIs.

```ts
const server = new ApolloServer({
  schema,
  introspection: process.env.NODE_ENV !== "production",
});
```

Disabling introspection is obfuscation, not security — pair it with the
authorization and cost controls below. Public APIs (intentionally documented)
can leave it on.

## Batching-Attack Defense

GraphQL supports array-batched operations and aliased field duplication, which
attackers use to amplify a single HTTP request:

```graphql
query {                          # one request, many expensive resolutions
  a: login(u: "x", p: "1") { token }
  b: login(u: "x", p: "2") { token }
  c: login(u: "x", p: "3") { token }
}
```

- Limit the number of operations per batch and aliased duplicates of sensitive fields.
- Apply rate limiting per **resolved field**, not just per HTTP request, for auth-adjacent mutations (login, password reset) — OWASP **API2/API6**.

## Resolver-Level Authorization

The schema does not enforce who can see what. **Every object-returning resolver
needs an authorization check** — DataLoader batching does not authorize.

```ts
const resolvers = {
  Query: {
    order: async (_p, { id }, ctx) => {
      const order = await ctx.loaders.order.load(id);
      if (!order) return null;
      // OWASP API1 — object-level authorization
      if (order.customerId !== ctx.user.customerId && !ctx.user.isAdmin) {
        throw new GraphQLError("Not authorized", {
          extensions: { code: "FORBIDDEN" },
        });
      }
      return order;
    },
  },
};
```

- Authorize in the resolver that **returns** the object, including nested field resolvers (`Order.customer` can leak a customer the viewer can't see).
- Field-level authorization for sensitive properties (SSN, internal flags) maps to OWASP **API3** — strip or deny per field, don't rely on the client not asking.

## Related

- [graphql-design](../SKILL.md) — the parent skill
- [api-security](../../../quality/api-security/SKILL.md) — full OWASP API Top 10 mapping
- [secure-coding](../../../_shared/secure-coding/SKILL.md) — error hygiene, secrets, injection
