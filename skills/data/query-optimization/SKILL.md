---
name: query-optimization
description: >-
  Make slow queries fast: read EXPLAIN ANALYZE plans, choose the right index
  (B-tree / GIN / partial / covering), eliminate N+1s, paginate with keyset,
  and triage slow-query logs. Use when an endpoint is slow, a query does a
  sequential scan, you see hundreds of queries per request, or you need to
  pick or add an index.
---

# Query Optimization

**Measure the plan, then fix the cause — never guess at an index**

## When to Use

Use this skill when:
- An endpoint or report is slow and the database is suspected
- You see a sequential scan on a large table in a plan
- One request fires dozens or hundreds of small queries (N+1)
- Offset pagination gets slower the deeper the page
- You need to choose between B-tree, GIN, partial, or covering indexes
- Triaging a slow-query log to find the worst offenders

The schema/indexes you are tuning → [schema-design](../schema-design/SKILL.md). ORM
loading that causes N+1 → [orm-patterns](../orm-patterns/SKILL.md). When the answer
is "cache it" → [caching-strategies](../caching-strategies/SKILL.md).

## Always Start with the Plan

Never add an index on a hunch. Read what the engine actually does.

```sql
-- PostgreSQL: ANALYZE runs the query; BUFFERS shows I/O; the others surface
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
SELECT * FROM orders WHERE user_id = 42 ORDER BY placed_at DESC LIMIT 20;
```

Read it for these signals:

| In the plan | Means | Usually fix with |
|-------------|-------|------------------|
| `Seq Scan` on a big table with a selective filter | no usable index | add an index on the filter column |
| `Rows Removed by Filter: <large>` | index/filter not selective enough | composite or partial index |
| estimated rows ≫ / ≪ actual rows | stale statistics | `ANALYZE table` (autovacuum may be behind) |
| `Sort` spilling to disk (`external merge`) | sort not served by an index | index matching `ORDER BY`, or raise `work_mem` |
| `Nested Loop` with high loop count | join driving N inner lookups | index the join column; reconsider the query |
| `Heap Fetches: <high>` on an index-only path | index not covering | add `INCLUDE` columns (covering index) |

MySQL: `EXPLAIN ANALYZE SELECT ...` (8.0.18+) for the executed plan; `EXPLAIN FORMAT=JSON`
for cost detail. Watch for `type: ALL` (full scan) and `Using filesort`/`Using temporary`.

## Index Selection

The right index depends on the predicate shape — match the index to the `WHERE` +
`ORDER BY`, in that column order.

```sql
-- Composite for equality + range/sort: equality cols first, then the sort/range col
CREATE INDEX orders_user_placed_idx ON orders (user_id, placed_at DESC);
-- serves: WHERE user_id = ? ORDER BY placed_at DESC LIMIT n  (no sort, no extra scan)

-- Partial: index only the rows you query, smaller + faster
CREATE INDEX orders_open_idx ON orders (user_id)
  WHERE status = 'open';

-- Covering: include non-key columns so the query never touches the heap (index-only scan)
CREATE INDEX orders_user_cover_idx ON orders (user_id) INCLUDE (total_cents, status);

-- GIN: full-text, jsonb containment, array membership
CREATE INDEX docs_body_fts ON docs USING gin (to_tsvector('english', body));
```

Rules:
- **Composite column order = equality columns first, then the range/sort column.**
  An index on `(a, b)` serves `WHERE a = ? AND b > ?` and `WHERE a = ?`, but not
  `WHERE b = ?` alone.
- **Selectivity first**: an index only helps if it eliminates most rows. A boolean
  column alone rarely warrants one (low cardinality).
- **Every index taxes writes** and storage. Drop unused indexes (`pg_stat_user_indexes`
  `idx_scan = 0`). More indexes is not better.
- Add indexes via migrations with `CREATE INDEX CONCURRENTLY` — see [migrations](../migrations/SKILL.md).

## N+1 Elimination

The most common back-end performance bug: load N parents, then one query per parent
for its children — N+1 round trips.

```ts
// ❌ N+1: one query for orders, then one per order for its user
const orders = await db.order.findMany();
for (const o of orders) {
  o.user = await db.user.findUnique({ where: { id: o.userId } }); // N queries
}

// ✅ batch: a single IN / join loads all children at once (Prisma include)
const orders = await db.order.findMany({ include: { user: true } });
```

- Fix by **eager-loading** the relation (`include`/`JOIN`/`Preload`/`fetch join`) or
  by batching IDs into one `WHERE id IN (...)` query (DataLoader pattern for GraphQL).
- Detect N+1 in tests by **counting queries** — assert a constant query count
  regardless of result-set size (see [be-testing](../../quality/be-testing/SKILL.md)).
- ORM-specific lazy-loading traps and the cure: [orm-patterns](../orm-patterns/SKILL.md) > loading strategies.

## Pagination

```sql
-- ❌ OFFSET pagination: the engine scans+discards OFFSET rows; page 10000 is slow
SELECT * FROM orders ORDER BY placed_at DESC LIMIT 20 OFFSET 200000;

-- ✅ keyset (seek) pagination: O(page size), uses the index, stable under inserts
SELECT * FROM orders
WHERE (placed_at, id) < (:last_placed_at, :last_id)   -- composite cursor
ORDER BY placed_at DESC, id DESC
LIMIT 20;
```

- **Keyset/seek pagination** for infinite scroll and APIs: carry the last row's sort
  key as the cursor. Constant cost at any depth; immune to row shifts mid-scroll.
- Keep `OFFSET` only for small, bounded, page-numbered UIs over small tables.
- The cursor columns must match an index (`(placed_at DESC, id DESC)`).

## Slow-Query Triage

```sql
-- PostgreSQL: top time-consuming statements (needs pg_stat_statements)
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;
```

- Enable `pg_stat_statements` (PG) / the slow query log (`long_query_time`, MySQL).
- Triage by **total** time (`calls × mean`), not mean alone — a 5ms query run a
  million times costs more than a 2s report run once.
- Then `EXPLAIN (ANALYZE, BUFFERS)` the top offenders and apply index/query fixes above.

## Version Markers & Fallbacks

| Feature | Needs | Fallback |
|---------|-------|----------|
| `EXPLAIN (ANALYZE, BUFFERS)` | PostgreSQL (any modern) | `EXPLAIN ANALYZE` without buffers |
| `INCLUDE` covering index | PostgreSQL 11+ | put the column in the key (wider index) |
| `EXPLAIN ANALYZE` (executed plan) | MySQL 8.0.18+ | `EXPLAIN FORMAT=JSON` (estimates only) |
| `INVISIBLE` index (test-drop safely) | MySQL 8.0 | drop on a replica and measure |
| `pg_stat_statements` | extension installed | slow query log + `auto_explain` |

Confirm against the [version-feature-matrix](../../_shared/version-feature-matrix.md).

## Diagnostics

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Seq Scan` on a filtered big table | no index, or filter not indexable | add a matching (composite/partial) index |
| Index exists but unused in the plan | wrong column order, type mismatch, function on column | reorder cols, cast in app, expression index |
| Deep pages slow (`OFFSET`) | scan-and-discard | keyset/seek pagination |
| Hundreds of queries per request | N+1 lazy loading | eager-load / batch IN / DataLoader |
| Sort spills to disk | `ORDER BY` not index-served | index matching the sort, or raise `work_mem` |
| Plan suddenly bad after data growth | stale statistics | `ANALYZE`; tune autovacuum |
| Index-only scan still hits heap | not covering / dead tuples | `INCLUDE` columns; `VACUUM` |

## Related Skills

- [schema-design](../schema-design/SKILL.md) — keys and JSON/GIN indexing the schema implies
- [orm-patterns](../orm-patterns/SKILL.md) — eager vs lazy, fixing ORM-generated N+1
- [migrations](../migrations/SKILL.md) — shipping indexes with `CREATE INDEX CONCURRENTLY`
- [caching-strategies](../caching-strategies/SKILL.md) — when the right answer is to not hit the DB
- [be-performance](../../quality/be-performance/SKILL.md) — load testing and end-to-end latency budgets
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — engine plan/index features
