# Database Diagnosis Reference

Use this when:

- A query is slow, scans the whole table, or got slower as data grew.
- One request fires hundreds of queries (N+1).
- The connection pool times out (`pool timeout`, `too many connections`).
- Transactions block each other or you hit a deadlock.

Skip if:

- The bottleneck is CPU/memory in app code — that is [profilers.md](profilers.md).
- You only need the tool-from-symptom decision. See [be-diagnostics SKILL.md](../SKILL.md).

Jump to:

- Reading EXPLAIN ANALYZE (PostgreSQL)
- Index Decisions
- N+1 Queries per ORM
- Connection-Pool Sizing & Exhaustion
- Slow-Query Logging
- Lock Chains & Deadlocks
- Diagnostic Table

---

## Reading EXPLAIN ANALYZE (PostgreSQL)

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders WHERE customer_id = 42 ORDER BY created_at DESC LIMIT 20;
```

Read it inside-out (deepest node first). What to look for:

- **`Seq Scan` on a large table with a selective filter** → missing index on the filter column.
- **`actual rows` ≫ `estimated rows`** → stale statistics; run `ANALYZE <table>;`. The planner chose a bad plan because its estimate was wrong.
- **`Rows Removed by Filter: <big>`** → reading far more than returned; the index (or a partial index) should do the filtering.
- **`Buffers: read=<big>`** → cold cache / lots of I/O; a covering index can cut buffer reads.
- **Nested Loop with high loop count** → often the SQL face of an N+1 or a join missing an index on the inner side.

Always compare *actual* time and rows, not just the cost estimate — `ANALYZE` runs the query.

> Other engines: MySQL `EXPLAIN ANALYZE` / `EXPLAIN FORMAT=JSON`; MongoDB `db.coll.explain("executionStats")`. The reasoning (selective filter → index, estimate vs actual) is the same.

## Index Decisions

| Pattern | Index |
|---------|-------|
| `WHERE col = ?` | B-tree on `col` |
| `WHERE a = ? AND b = ?` | composite `(a, b)` — leftmost-prefix rule |
| `WHERE a = ? ORDER BY b` | composite `(a, b)` so the sort is free |
| `WHERE col = ?` returning few rows from a huge table | partial index `... WHERE status = 'active'` |
| Read-heavy, want index-only scan | covering index (`INCLUDE (...)` in Postgres) |
| `WHERE lower(email) = ?` | expression index on `lower(email)` |

Build indexes without locking writes: `CREATE INDEX CONCURRENTLY` (Postgres). Every index costs write throughput and storage — add for measured queries, not speculatively. Drop unused ones (`pg_stat_user_indexes.idx_scan = 0`).

## N+1 Queries per ORM

The signature: one query for a list, then one more *per row* to load a relation. 200 rows → 201 queries.

```ts
// Prisma — eager-load the relation in one round trip
const orders = await prisma.order.findMany({ include: { customer: true, items: true } });
```

```ts
// TypeORM — relations / leftJoinAndSelect
repo.find({ relations: { customer: true } });
```

```go
// GORM — Preload avoids the per-row query
db.Preload("Customer").Preload("Items").Find(&orders)
```

```python
# SQLAlchemy — selectinload (one extra batched query, not N)
session.scalars(select(Order).options(selectinload(Order.items)))
# Django — select_related (FK join) / prefetch_related (reverse/M2M)
Order.objects.select_related("customer").prefetch_related("items")
```

```java
// JPA/Hibernate — JOIN FETCH or an entity graph; avoid LAZY-in-a-loop
@Query("select o from Order o join fetch o.items where o.customerId = :id")
```

Detect it: enable the ORM's SQL logging in a test, hit the endpoint once, and count statements. A Testcontainers integration test that asserts a query-count ceiling stops regressions ([be-testing](../../quality/be-testing/SKILL.md)).

## Connection-Pool Sizing & Exhaustion

A `pool timeout` means every pooled connection is checked out when a request asks for one. Three root causes:

1. **Pool too small for concurrency.** Start from `pool_size ≈ cores * 2` per instance and bound the *total* across instances below the DB's `max_connections`. More connections than the DB has CPUs usually *reduces* throughput — use PgBouncer (transaction pooling) in front for high fan-out.
2. **Leaked connections.** A handler that throws before releasing the connection, or holds one across an `await` to a slow downstream. Always release in `finally` / use the framework's scoped/auto-release helper.
3. **Long-running transaction.** A `BEGIN` that waits on app logic or a slow external call holds its slot. Keep transactions short; do I/O to other systems *outside* the txn.

```sql
-- How many connections, by state? idle-in-transaction is the smell.
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
-- Kill a stuck idle-in-transaction session (after confirming it is safe)
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE state = 'idle in transaction' AND now() - state_change > interval '5 min';
```

## Slow-Query Logging

```sql
-- PostgreSQL: log any statement slower than 200ms
ALTER SYSTEM SET log_min_duration_statement = 200;  SELECT pg_reload_conf();
-- Aggregate the worst offenders over time (enable the extension once)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SELECT mean_exec_time, calls, rows, left(query,80)
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;
```

`pg_stat_statements` normalizes parameters, so the same query with different values aggregates — that's how you find the query that is individually fast but called a million times.

## Lock Chains & Deadlocks

```sql
-- Who blocks whom right now (PostgreSQL 9.6+)
SELECT pid, pg_blocking_pids(pid) AS blocked_by, state, left(query,60)
FROM pg_stat_activity WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

Deadlocks (the DB aborts one transaction with a deadlock error) come from transactions taking the same locks in different orders. Fix by **acquiring locks in a consistent order** everywhere, keeping transactions short, and using the right isolation level. For "lost update" races prefer a single `UPDATE ... WHERE version = ?` (optimistic) over read-modify-write.

---

## Diagnostic Table

| Observation | Reading | Likely cause | Fix direction |
|-------------|---------|--------------|---------------|
| `Seq Scan` on big table | EXPLAIN | missing index on filter | add B-tree / composite / partial index |
| actual rows ≫ estimate | EXPLAIN | stale stats | `ANALYZE`; consider extended statistics |
| 201 queries for one request | ORM SQL log | N+1 | eager-load / batch the relation |
| `pool timeout` under load | `pg_stat_activity` | small pool / leak / long txn | size pool; release in `finally`; shorten txn |
| `idle in transaction` rows pile up | `pg_stat_activity` | txn open across app/IO wait | move external I/O out of the txn |
| deadlock detected | DB log | inconsistent lock order | order locks; shorten txns; optimistic update |
| same query slow, high `calls` | `pg_stat_statements` | hot query, no cache/index | index it or cache the result |

Add the index or fix, then **re-run EXPLAIN ANALYZE** under the same data to confirm the plan changed — the proof is the new plan, not the hope.
