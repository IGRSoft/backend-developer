---
name: data-skills
description: >-
  Data-layer skills navigation — schema design, migrations, query optimization,
  ORM patterns, caching. Use when designing schemas, writing migrations, tuning
  queries, or caching.
---

# Data Skills

**Schema design, migrations, query optimization, ORM usage, and caching for service back-ends**

Thin router. Pick a sub-skill from the tables below; the leaf skills teach.

## Skill Selection

| I need to... | Use this skill |
|--------------|----------------|
| Design tables/collections, choose keys, normalize vs denormalize, model JSON | [schema-design/SKILL.md](schema-design/SKILL.md) |
| Write a safe migration, backfill, or zero-downtime schema change | [migrations/SKILL.md](migrations/SKILL.md) |
| Speed up a slow query, pick an index, kill an N+1, paginate | [query-optimization/SKILL.md](query-optimization/SKILL.md) |
| Configure an ORM — pooling, transactions, lazy/eager, repositories | [orm-patterns/SKILL.md](orm-patterns/SKILL.md) |
| Add a cache, invalidate it, store idempotency keys or rate-limit counters | [caching-strategies/SKILL.md](caching-strategies/SKILL.md) |

## Symptom Router

Start here when you have a behavior, not a topic name.

| Symptom | Likely cause | Go to |
|---------|--------------|-------|
| One endpoint fires hundreds of `SELECT`s per request | N+1 from lazy loading / loop queries | [query-optimization](query-optimization/SKILL.md) > N+1 elimination |
| Query fast on dev, slow in prod | missing/unused index, stale stats, seq scan on hot table | [query-optimization](query-optimization/SKILL.md) > EXPLAIN ANALYZE |
| Migration locked the table; requests timed out | blocking DDL / full table rewrite | [migrations](migrations/SKILL.md) > online DDL & locking |
| Adding a `NOT NULL` column broke prod deploy | non-expand-contract change; old code can't write | [migrations](migrations/SKILL.md) > expand-contract |
| `too many connections` under load | pool > DB max, or no pooler | [orm-patterns](orm-patterns/SKILL.md) > connection pooling |
| Reads return stale data after a write | cache not invalidated, wrong TTL | [caching-strategies](caching-strategies/SKILL.md) > invalidation |
| Duplicate side effects on retry (double charge) | no idempotency store | [caching-strategies](caching-strategies/SKILL.md) > idempotency stores |
| Schema can't represent a 1:many cleanly / JSON blob bloat | wrong normalization or document/relational mismatch | [schema-design](schema-design/SKILL.md) > normalization |

## Engine / Tool Version Snapshot (verify against your stack)

Floors this plugin assumes. Engine behavior and driver defaults shift between releases — confirm with `SELECT version();` / the driver changelog and the canonical [version-feature-matrix](../_shared/version-feature-matrix.md) (the single home for engine + ORM floors) before pinning in CI. The notes below are the *why*; the floors live in the matrix.

| Tool | Assumed floor | Why |
|------|---------------|-----|
| PostgreSQL | matrix floor (16+ baseline; 18 the modern target) | `CREATE INDEX CONCURRENTLY`, generated columns, `MERGE` (15+), skip scan + async I/O + `uuidv7()` (18) *(verify)* |
| MySQL | matrix floor (8.4 LTS; 8.0 EOL'd) | online DDL (`ALGORITHM=INPLACE`), CTEs, window functions, `INVISIBLE` indexes |
| MongoDB | matrix floor (8.0 LTS target) | multi-document transactions, `$lookup`, change streams, time-series + queryable-encryption maturity |
| Redis / Valkey | matrix floor (Redis 8 / Valkey 8.1+) | functions, `CLIENT NO-EVICT`, ACLs; **license fork** — Redis 8 is AGPLv3, Valkey is BSD-3 (drop-in Redis-OSS replacement) — see Caching note |
| Prisma | matrix floor (6.x; 7.x Rust-free default) | interactive transactions, driver adapters (GA), Rust-free TS query compiler (7) |
| Drizzle | matrix floor (current 0.4x stable; v1 in beta) | relational queries, prepared statements, no codegen |
| TypeORM | matrix floor (0.3.x; 1.0 GA'd) | `DataSource` API (0.2 `Connection` removed); 1.0 modernizes the platform floor |
| GORM | matrix floor (v2, `gorm.io/gorm`) | context-aware API, `Preload`, prepared-stmt cache |
| Hibernate | matrix floor (7.x; 6.x prior) | Jakarta Persistence 3.2 (7.0), Jakarta Data, type-safe queries; 6.x is Jakarta 3.1 |
| EF Core | matrix floor (10 LTS; 8 prior LTS) | bulk `ExecuteUpdate`/`ExecuteDelete`, JSON columns, compiled models, `LeftJoin`/`RightJoin` (10) |
| SQLAlchemy | matrix floor (2.0) | unified ORM/Core API, `select()` style, async engine |

## Decision Tree

```
Data-layer task?
├── "How do I shape the data?" → schema-design/SKILL.md
│   ├── relational keys/constraints/normalization → schema-design/SKILL.md > Relational modeling
│   ├── document modeling (MongoDB), embed vs reference → schema-design/SKILL.md > Document modeling
│   └── JSON columns, partitioning at scale → schema-design/references/advanced-modeling.md
├── "How do I change the schema safely?" → migrations/SKILL.md
│   ├── expand-contract / zero-downtime → migrations/SKILL.md > Expand-contract
│   ├── backfills + reversibility → migrations/SKILL.md > Backfills
│   └── per-tool recipes (Prisma/Drizzle/Flyway/Alembic/EF…) → migrations/references/per-tool-recipes.md
├── "This query / endpoint is slow" → query-optimization/SKILL.md
│   ├── read the plan → query-optimization/SKILL.md > EXPLAIN ANALYZE
│   ├── pick the right index → query-optimization/SKILL.md > Index selection
│   └── N+1 and pagination → query-optimization/SKILL.md > N+1 / pagination
├── "How should the ORM behave?" → orm-patterns/SKILL.md
│   ├── pooling + transactions/isolation → orm-patterns/SKILL.md > Pooling & transactions
│   └── lazy vs eager, repository pattern → orm-patterns/SKILL.md > Loading strategies
└── "Cache / counter / idempotency" → caching-strategies/SKILL.md
    ├── cache-aside vs write-through → caching-strategies/SKILL.md > Patterns
    └── invalidation, hot keys, locks → caching-strategies/SKILL.md > Invalidation & hot keys
```

## Conventions Across Data Work

- **Migrations are forward-only in spirit, reversible in form.** Every migration ships a tested `down`; production rolls forward, but a reversible migration is a code-reviewable contract. See [migrations](migrations/SKILL.md).
- **Every write path is a transaction boundary.** Wrap multi-statement mutations; pick the isolation level deliberately, never default-by-accident. See [orm-patterns](orm-patterns/SKILL.md) > transactions.
- **Indexes are part of the schema, not an afterthought.** A query change that needs an index ships with the migration that adds it (`CONCURRENTLY` in Postgres). See [query-optimization](query-optimization/SKILL.md).
- **Single-command Bash invocations.** Use `psql -f mig.sql`, `prisma migrate deploy`, `go test ./...` — never `cd`-chains. Scoped Bash allowlists do not match compound commands.
- **Untrusted input never concatenates into SQL.** Parameterize everything; the ORM's query builder or prepared statements are the boundary. See [secure-coding](../_shared/secure-coding/SKILL.md).
- **Redis vs Valkey is now a license decision, not just a version one.** Redis 8+ ships under AGPLv3 (plus the source-available RSALv2/SSPLv1); Valkey is the BSD-3 Linux-Foundation fork (AWS/Google/Oracle-backed) and a drop-in Redis-OSS replacement tracking the same command surface. Pick per your license posture; the cache patterns in [caching-strategies](caching-strategies/SKILL.md) apply to both. Confirm the engine + floor in the [version-feature-matrix](../_shared/version-feature-matrix.md).

## Related Skills

- [schema-design](schema-design/SKILL.md) — normalization, keys/constraints, relational vs document, JSON, partitioning
- [migrations](migrations/SKILL.md) — expand-contract, backfills, online DDL, per-tool recipes
- [query-optimization](query-optimization/SKILL.md) — EXPLAIN ANALYZE, index selection, N+1, pagination
- [orm-patterns](orm-patterns/SKILL.md) — pooling, transactions, loading strategies, repositories
- [caching-strategies](caching-strategies/SKILL.md) — Redis patterns, invalidation, idempotency, rate limits
- [version-feature-matrix](../_shared/version-feature-matrix.md) — engine/ORM version floors per feature
- [secure-coding](../_shared/secure-coding/SKILL.md) — injection-safe data access, secrets hygiene
- [api-security](../quality/api-security/SKILL.md) — BOLA and object-property authorization at the data boundary
- [be-testing](../quality/be-testing/SKILL.md) — integration tests against real engines (Testcontainers)
