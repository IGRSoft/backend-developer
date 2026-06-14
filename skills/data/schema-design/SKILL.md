---
name: schema-design
description: >-
  Schema design for relational and document stores: normalization vs
  denormalization, keys and constraints, PostgreSQL/MySQL table modeling vs
  MongoDB embed-or-reference, JSON columns, and partitioning. Use when
  designing a new schema, choosing primary/foreign keys, deciding whether to
  embed or reference, modeling JSON, or planning for table growth.
---

# Schema Design

**Shape the data once, correctly — the schema is the hardest thing to change later**

## When to Use

Use this skill when:
- Designing tables/collections for a new service or feature
- Choosing primary keys (surrogate vs natural, UUID vs bigint) and foreign keys
- Deciding how far to normalize, and where denormalization pays off
- Modeling relational (PostgreSQL/MySQL) vs document (MongoDB) data
- Choosing JSON/JSONB columns vs separate tables
- Planning for a table that will grow into the hundreds of millions of rows

Routing: JSON indexing, partitioning, sharding boundaries, temporal and
multi-tenancy patterns → [references/advanced-modeling.md](references/advanced-modeling.md).
Changing an existing schema safely → [migrations](../migrations/SKILL.md).

## The Modeling Decision

| Question | Default | Reach for the alternative when |
|----------|---------|--------------------------------|
| Normalize or denormalize? | **Normalize (3NF)** | read amplification on a proven hot path; denormalize with a backfill + invariant |
| Relational or document? | **Relational** | data is genuinely hierarchical, read as one aggregate, rarely cross-queried |
| Surrogate or natural key? | **Surrogate** (`bigint`/UUID) | the natural key is stable, narrow, and never reused |
| `bigint` or UUID PK? | **`bigint identity`** for internal; **UUIDv7** when keys leak to clients or are generated client-side | random UUIDv4 PKs fragment B-tree indexes — avoid as clustered key |
| Embed or reference (Mongo)? | **Reference** across aggregates | the child has no life outside the parent and is bounded in size |

Normalize first; denormalize only with evidence (a slow query you measured) and
a mechanism to keep the copy consistent. An un-maintained denormalized column is
a future data-integrity incident.

## Relational Modeling (PostgreSQL / MySQL)

Constraints are not optional decoration — they are the database enforcing your
invariants so application bugs cannot corrupt data.

```sql
-- PostgreSQL 16
CREATE TABLE users (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email       citext NOT NULL,                       -- case-insensitive
  status      text   NOT NULL DEFAULT 'active'
              CHECK (status IN ('active','suspended','deleted')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT users_email_uniq UNIQUE (email)
);

CREATE TABLE orders (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     bigint NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  total_cents bigint NOT NULL CHECK (total_cents >= 0),
  placed_at   timestamptz NOT NULL DEFAULT now()
);

-- the foreign key you query by needs its own index (FKs are NOT auto-indexed in PG)
CREATE INDEX orders_user_id_idx ON orders (user_id);
```

Rules that prevent most data bugs:

- **Every foreign key is enforced** (`REFERENCES ... ON DELETE`), and the FK
  column is indexed (PostgreSQL does not auto-index FKs; MySQL/InnoDB does).
- **`NOT NULL` by default.** Nullable means "this can be unknown" — say so deliberately.
- **`CHECK` constraints** encode enums, ranges, and money-non-negative rules.
- **Money is integer minor units** (`bigint` cents) or `numeric`, never `float`.
- **Timestamps are `timestamptz`** (PG) / `TIMESTAMP` in UTC (MySQL), never naive local time.
- **Choose collation deliberately** — `citext`/`COLLATE` for case-insensitive uniqueness.

## Document Modeling (MongoDB)

The embed-or-reference choice is the whole game. Embed what is read together and
bounded; reference what is shared, large, or independently mutated.

```javascript
// Embed: order line items live and die with the order, read as one aggregate
{
  _id: ObjectId("..."),
  userId: ObjectId("..."),          // reference: users are shared, queried alone
  status: "placed",
  items: [                          // embed: bounded, always read with the order
    { sku: "ABC-1", qty: 2, priceCents: 1999 },
    { sku: "XYZ-9", qty: 1, priceCents: 4999 }
  ],
  totalCents: 8997,
  placedAt: ISODate("2026-06-14T10:00:00Z")
}
```

- **Unbounded arrays are a trap.** An array that grows without limit (comments,
  events) blows the 16MB document cap and rewrites the whole doc on each push —
  reference into a separate collection instead.
- **Schema validation belongs in the DB**, not only the app: attach a
  `$jsonSchema` validator so malformed writes are rejected at the engine.
- **Design for your reads.** Document stores reward aggregates that match an
  endpoint's response shape; they punish ad-hoc cross-collection joins (`$lookup`
  is available but is a relational pattern bolted on — if you `$lookup` constantly,
  you wanted a relational store).

## JSON Columns in Relational Stores

`jsonb` (PostgreSQL) / `JSON` (MySQL 8) is for genuinely schemaless or sparse
attributes — not as a default dumping ground for columns you were too lazy to model.

```sql
ALTER TABLE products ADD COLUMN attributes jsonb NOT NULL DEFAULT '{}';
-- index a hot path inside the JSON
CREATE INDEX products_attr_brand_idx
  ON products ((attributes ->> 'brand'));
-- or a GIN index for containment queries
CREATE INDEX products_attr_gin ON products USING gin (attributes);
```

Promote a JSON key to a real column the moment you filter, join, or constrain on
it regularly — JSON indexing helps, but a typed column with a `CHECK` is stronger.
Full JSON indexing and partitioning detail: [references/advanced-modeling.md](references/advanced-modeling.md).

## Version Markers & Fallbacks

| Feature | Needs | Fallback if older |
|---------|-------|-------------------|
| `GENERATED ALWAYS AS IDENTITY` | PostgreSQL 10+ | `bigserial` |
| UUIDv7 (time-ordered) generation | app-side lib or PG 18 `uuidv7()` *(verify)* | UUIDv4 + separate sort column, or `bigint` |
| `MERGE` (upsert) | PostgreSQL 15+ / MySQL 8 | `INSERT ... ON CONFLICT` (PG) / `ON DUPLICATE KEY` (MySQL) |
| `jsonb` subscripting `col['k']` | PostgreSQL 14+ | `col -> 'k'` operator form |
| MongoDB `$jsonSchema` validation | MongoDB 3.6+ (use 6.0+ features) | app-layer validation only |

Confirm engine features against the [version-feature-matrix](../../_shared/version-feature-matrix.md) before relying on them in a migration.

## Diagnostics

| Symptom | Cause | Fix |
|---------|-------|-----|
| Orphaned rows (child points to deleted parent) | FK constraint missing | Add `REFERENCES ... ON DELETE`; clean orphans first |
| `float` money drifts by a cent | floating-point representation | Migrate to `bigint` minor units or `numeric` |
| Mongo doc hits 16MB / slow writes | unbounded embedded array | Move array to a referenced collection |
| Filtering on a JSON key is slow | no expression/GIN index | Index `(col ->> 'k')` or promote to a column |
| Random UUIDv4 PK fragments index, slow inserts | non-sequential clustered key | Switch to `bigint` or UUIDv7 |
| Case-variant duplicate emails slip in | unique index on case-sensitive text | `citext` / functional unique index on `lower(email)` |

## Deep-Dive References

- [references/advanced-modeling.md](references/advanced-modeling.md) — JSON/JSONB
  indexing strategies, declarative partitioning, sharding boundaries, temporal and
  soft-delete patterns, multi-tenant schema layouts (shared vs schema-per-tenant)

## Related Skills

- [migrations](../migrations/SKILL.md) — evolving the schema once it is live
- [query-optimization](../query-optimization/SKILL.md) — the indexes a schema implies
- [orm-patterns](../orm-patterns/SKILL.md) — mapping these models in Prisma/GORM/Hibernate/EF
- [caching-strategies](../caching-strategies/SKILL.md) — when a read aggregate belongs in Redis
- [secure-coding](../../_shared/secure-coding/SKILL.md) — least-privilege schema grants, no PII in plaintext
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — engine feature floors
