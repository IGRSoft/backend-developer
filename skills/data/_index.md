# Data Index

Quick navigation for schema design, migrations, query optimization, ORM patterns, and caching.

## Skills

| Path | Description |
|------|-------------|
| `SKILL.md` | Entry router: skill selection, symptom router, engine version snapshot, decision tree |
| `schema-design/SKILL.md` | Normalization vs denormalization, keys/constraints, relational (PostgreSQL/MySQL) vs document (MongoDB) modeling, JSON columns |
| `schema-design/references/advanced-modeling.md` | JSON/JSONB indexing, partitioning, sharding boundaries, temporal/soft-delete patterns, multi-tenancy schemas |
| `migrations/SKILL.md` | Expand-contract / zero-downtime, reversibility, backfills, online DDL and locking pitfalls, admin processes run against the same release |
| `migrations/references/per-tool-recipes.md` | Prisma, Drizzle, golang-migrate, Flyway, Liquibase, Alembic, EF Core migration recipes |
| `query-optimization/SKILL.md` | EXPLAIN ANALYZE, index selection (B-tree/GIN/partial/covering), N+1 elimination, pagination, slow-query triage |
| `orm-patterns/SKILL.md` | Prisma/Drizzle/TypeORM/GORM/Hibernate/EF Core/SQLAlchemy — pooling, lazy vs eager, transactions/isolation, repository pattern |
| `caching-strategies/SKILL.md` | Redis cache-aside/write-through, invalidation, TTL/eviction, session and per-request state externalization, distributed locks, idempotency stores, rate-limit counters, hot keys |

## Quick Links by Problem

### "I need to..."

- **Design a new table or collection** → `schema-design/SKILL.md`
- **Add a column without downtime** → `migrations/SKILL.md` (expand-contract)
- **Backfill a billion rows safely** → `migrations/SKILL.md` (backfills)
- **Pick the right index** → `query-optimization/SKILL.md` (index selection)
- **Configure connection pooling** → `orm-patterns/SKILL.md` (pooling)
- **Add a Redis cache** → `caching-strategies/SKILL.md` (cache-aside)
- **Make a retry-safe endpoint** → `caching-strategies/SKILL.md` (idempotency stores)
- **Move sessions out of process memory** → `caching-strategies/SKILL.md` (session & per-request state)
- **Run a migration without migrating on boot** → `migrations/SKILL.md` (admin processes)

### "I'm seeing..."

- **Hundreds of queries per request** → `query-optimization/SKILL.md` (N+1 elimination)
- **`too many connections`** → `orm-patterns/SKILL.md` (connection pooling)
- **A migration that locked the table** → `migrations/SKILL.md` (online DDL & locking)
- **Stale reads after a write** → `caching-strategies/SKILL.md` (invalidation)
- **A seq scan on a big table** → `query-optimization/SKILL.md` (EXPLAIN ANALYZE)
- **Duplicate side effects on retry** → `caching-strategies/SKILL.md` (idempotency stores)
- **Users logged out after a deploy or scale-in** → `caching-strategies/SKILL.md` (session & per-request state)
- **Replicas racing the same DDL at start-up** → `migrations/SKILL.md` (admin processes)
