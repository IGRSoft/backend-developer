# Database Performance & Caching

Most back-end latency is database latency. Read the plan, fix N+1, index for the access pattern, size the pool, and cache deliberately.

## Read the query plan

`EXPLAIN (ANALYZE, BUFFERS)` shows what Postgres actually did (not estimated):

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = $1 ORDER BY created_at DESC LIMIT 20;
```

Red flags:

- **`Seq Scan`** on a large table for a selective predicate → missing index.
- **`Rows Removed by Filter`** large → the index isn't selective or doesn't cover the predicate.
- **Estimated rows ≫/≪ actual rows** → stale statistics; run `ANALYZE`.
- **`Sort`** spilling to disk (`external merge`) → raise `work_mem` or add an index matching the `ORDER BY`.
- **Nested loop with high loop count** → often the SQL face of an N+1.

## Indexing strategy

- Index the columns in `WHERE`, `JOIN`, and `ORDER BY`. A composite index's column order matters: leftmost prefix must match the predicate.
- A composite index on `(customer_id, created_at DESC)` serves the query above with no separate sort.
- **Covering index** (`INCLUDE` columns) lets an index-only scan skip the heap.
- Partial indexes for skewed predicates (`WHERE status = 'active'`).
- Don't over-index: every index slows writes and costs storage. Index for the read patterns you actually have.

## N+1 — fix per ORM

| ORM / stack | Eager-load mechanism |
|-------------|----------------------|
| Prisma | `findMany({ include: { author: true } })` or `select` |
| TypeORM | `relations: ["author"]` or `leftJoinAndSelect` |
| Drizzle | relational `with: { author: true }` |
| Hibernate/JPA | `JOIN FETCH`, `@EntityGraph`, `@BatchSize` |
| SQLAlchemy | `selectinload()` (separate IN query) / `joinedload()` (JOIN) |
| GORM | `Preload("Author")` / `Joins` |
| EF Core | `.Include(o => o.Author)`; `AsSplitQuery()` for fan-out |
| ActiveRecord | `includes(:author)` / `preload` / `eager_load` |

`selectinload`-style (a second `WHERE id IN (...)` query) is usually better than a JOIN when the relation is one-to-many, because a JOIN multiplies rows. Measure both.

**Catch N+1 in tests**: assert the query count for an endpoint. A regression that reintroduces a per-row query bumps the count and fails the test. See [be-testing](../../be-testing/SKILL.md).

## Connection pool sizing

The pool is the gate between your app's concurrency and the DB's `max_connections`. Latency climbing under load while app CPU is idle is the signature of an exhausted pool — requests wait for a free connection.

```text
total app connections must stay < Postgres max_connections (minus admin/replication reserve)

per_instance_pool ≈ (max_connections - reserved) / instance_count

Example: max_connections=100, reserve 10, 4 instances → ~22 per instance.
```

For many ephemeral instances (serverless, autoscaling) put **PgBouncer** in transaction-pooling mode in front of Postgres so thousands of client connections multiplex onto a small server pool. Set per-pool timeouts: connection acquire timeout (fail fast when saturated), statement timeout (kill runaway queries), idle timeout.

```text
acquire_timeout: small (e.g. 2s) → 503 fast instead of piling up
statement_timeout: cap query runtime at the DB
```

## Caching

### Cache-aside (the default)

```ts
async function getUser(id: string) {
  const key = `user:${id}`;
  const hit = await redis.get(key);
  if (hit) return JSON.parse(hit);
  const user = await db.user.findUnique({ where: { id } });
  if (user) await redis.set(key, JSON.stringify(user), "EX", 300); // TTL always
  return user;
}
```

Rules:

- **Always set a TTL** — an unbounded cache is a memory leak and a staleness bug.
- **Bound in-process caches** by entry count (LRU); they don't share across instances.
- **Invalidate on write** — update or delete the key when the source changes. Cache-aside + write-path invalidation is simpler to reason about than write-through for most CRUD.

### Other patterns

| Pattern | When |
|---------|------|
| Cache-aside | general read-heavy data |
| Write-through | cache and DB written together; read consistency matters |
| Write-behind | high write volume, async flush (durability tradeoff) |
| Read-through | cache library owns the DB read |

### Stampede (thundering herd)

A hot key expiring under load makes every concurrent request miss and hit the DB at once.

- **Lock/single-flight**: first miss takes a short lock, populates, others wait or serve stale.
- **Stale-while-revalidate**: serve the expired value while one request refreshes in the background.
- **Jittered TTLs**: avoid many keys expiring at the same instant.

### HTTP/CDN caching

For cacheable `GET`s, set `Cache-Control`/`ETag` and let a CDN absorb load. Never cache authenticated, user-specific responses at a shared CDN without `Vary`/`private`.

## Write-path performance

- **Batch inserts** (`COPY`/multi-row `INSERT`) instead of row-at-a-time.
- **Keep transactions short** — long transactions hold locks and bloat MVCC; never do network/HTTP calls inside a DB transaction.
- **Bulk updates** over loops of single updates.

## Verify, don't guess

- Reproduce slow endpoints under k6 ([load-testing-k6](load-testing-k6.md)) against production-like data volume.
- `pg_stat_statements` to find the queries that cost the most total time.
- OpenTelemetry DB spans to see query count and duration per request in prod.
- Hand deep query/plan tuning or profiling to the [be-performance-engineer](../../../_shared/../) review agent.

Versions: skill [version-feature-matrix](../../../_shared/version-feature-matrix.md).

## Checklist

- [ ] Slow queries inspected with `EXPLAIN (ANALYZE, BUFFERS)`; no unexpected seq scans.
- [ ] Indexes match `WHERE`/`JOIN`/`ORDER BY`; composite column order correct.
- [ ] N+1 eliminated via eager-loading; a query-count test guards against regression.
- [ ] Pool sized to DB capacity; PgBouncer for many instances; acquire/statement timeouts set.
- [ ] Caches have TTLs, bounded size, write-path invalidation, and stampede protection.
- [ ] Transactions short; no network calls inside them; bulk writes batched.
