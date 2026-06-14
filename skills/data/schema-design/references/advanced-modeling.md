# Advanced Schema Modeling

Deep dive on JSON indexing, partitioning, sharding boundaries, temporal/soft-delete
patterns, and multi-tenancy. Read after [schema-design/SKILL.md](../SKILL.md).

## JSON / JSONB Indexing (PostgreSQL)

`jsonb` supports three indexing strategies; pick by query shape.

```sql
-- 1. Expression index: a single hot scalar key, equality/range
CREATE INDEX products_brand_idx ON products ((attributes ->> 'brand'));
SELECT * FROM products WHERE attributes ->> 'brand' = 'Acme';

-- 2. GIN with default jsonb_ops: containment (@>) and key-existence (?)
CREATE INDEX products_attr_gin ON products USING gin (attributes);
SELECT * FROM products WHERE attributes @> '{"color":"red"}';

-- 3. GIN with jsonb_path_ops: smaller/faster, containment ONLY (no key-existence)
CREATE INDEX products_attr_path_gin ON products USING gin (attributes jsonb_path_ops);
```

- `jsonb_path_ops` is ~half the size and faster for `@>` but drops `?`/`?|`/`?&`.
- Expression indexes win when you always filter one key; GIN wins for arbitrary
  containment over many keys.
- MySQL 8: index JSON via a **generated column** (`ALTER TABLE t ADD c VARCHAR(64)
  GENERATED ALWAYS AS (attributes->>'$.brand') STORED`, then index `c`); MySQL has
  no GIN equivalent.

## Declarative Partitioning (PostgreSQL)

Partition a table once it is too large to vacuum/index/archive as one unit
(rule of thumb: 100M+ rows, or time-based retention). Partition by the column you
filter and prune by — usually time or tenant.

```sql
CREATE TABLE events (
  id         bigint GENERATED ALWAYS AS IDENTITY,
  tenant_id  bigint NOT NULL,
  created_at timestamptz NOT NULL,
  payload    jsonb NOT NULL,
  PRIMARY KEY (id, created_at)          -- partition key must be in the PK
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2026_06 PARTITION OF events
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
```

- The partition key **must be part of every unique constraint** (including the PK).
  This is why partitioned tables often use composite keys.
- Use `pg_partman` to automate monthly/daily partition creation and retention.
- Range partition by time for retention/archival; list/hash by tenant for isolation.
- Queries that include the partition key get **partition pruning** (the planner
  skips irrelevant partitions); queries that omit it scan all partitions — worse
  than an unpartitioned table.

MySQL has `PARTITION BY RANGE/HASH` too, but with more limitations (no foreign keys
into or out of partitioned tables) — partition only when the win is measured.

## Sharding Boundaries

Sharding (horizontal split across physical databases) is a last resort after
vertical scaling, read replicas, and partitioning. Before sharding, decide:

- **Shard key** chosen so the hot access path is single-shard (e.g. `tenant_id`,
  `user_id`). Cross-shard queries become scatter-gather — slow and hard.
- **No cross-shard transactions.** Aggregates that must be atomic must live on one
  shard. This forces aggregate boundaries — design them before sharding, not after.
- **Globally unique IDs** without a central sequence: UUIDv7 or a Snowflake-style
  ID (timestamp + shard + counter).
- Prefer a managed sharded engine (Citus for Postgres, Vitess for MySQL, Mongo
  sharded clusters) over hand-rolled application sharding.

## Temporal & Soft-Delete Patterns

```sql
-- Soft delete: keep the row, mark it gone
ALTER TABLE users ADD COLUMN deleted_at timestamptz;
-- partial index so live-row queries stay fast and uniqueness ignores deleted rows
CREATE UNIQUE INDEX users_email_live_uniq
  ON users (email) WHERE deleted_at IS NULL;
```

- Soft delete complicates **every** query (you must filter `deleted_at IS NULL`)
  and breaks naive unique constraints — use partial unique indexes. Only adopt it
  when retention/audit genuinely requires the row.
- **Audit/history**: a separate `*_history` append-only table written by a trigger
  or the application, or system-versioned temporal tables (MySQL has none native;
  Postgres via extensions / explicit pattern).
- **Effective-dated rows** (`valid_from`/`valid_to`) model "what was true when";
  enforce non-overlap with an exclusion constraint (`EXCLUDE USING gist`).

## Multi-Tenancy Schema Layouts

| Model | Isolation | Cost | Use when |
|-------|-----------|------|----------|
| Shared schema, `tenant_id` column | Lowest (row-level) | Lowest | Many small tenants; enforce with Row-Level Security |
| Schema-per-tenant (same DB) | Medium | Medium | Tens–hundreds of tenants; per-tenant migration cost |
| Database-per-tenant | Highest | Highest | Few large/regulated tenants; noisy-neighbor or compliance isolation |

Shared-schema is the default. Enforce the boundary at the database with PostgreSQL
**Row-Level Security**, not only in application code — a missing `WHERE tenant_id = ?`
is then a denied query, not a cross-tenant data leak (this is OWASP API1 BOLA at the
storage layer; see [api-security](../../../quality/api-security/SKILL.md)).

```sql
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON invoices
  USING (tenant_id = current_setting('app.tenant_id')::bigint);
```

## Related

- [schema-design/SKILL.md](../SKILL.md) — core modeling decisions
- [query-optimization](../../query-optimization/SKILL.md) — reading plans on partitioned/JSON-indexed tables
- [migrations](../../migrations/SKILL.md) — adding partitions/indexes without downtime
- [api-security](../../../quality/api-security/SKILL.md) — tenant isolation as a BOLA control
