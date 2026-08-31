---
name: migrations
description: >-
  Database migrations done safely: expand-contract / zero-downtime changes,
  reversibility, batched backfills, and online-DDL/locking pitfalls across
  PostgreSQL and MySQL. Use when adding/dropping/renaming columns, changing
  types or constraints, backfilling data, or shipping a schema change to a
  live system without taking it down.
---

# Migrations

**A migration runs against a live database while old and new code both run — design for that**

## When to Use

Use this skill when:
- Adding, dropping, renaming, or retyping a column or table
- Adding or tightening a constraint (`NOT NULL`, `UNIQUE`, `CHECK`, FK)
- Backfilling or transforming existing rows
- Shipping any schema change to a system that cannot take downtime
- Writing the `down` / reverse of a migration
- Choosing how a specific tool (Prisma, Flyway, Alembic…) should express the change

Routing: per-tool command recipes → [references/per-tool-recipes.md](references/per-tool-recipes.md).
The schema you are changing → [schema-design](../schema-design/SKILL.md). The indexes
a migration adds → [query-optimization](../query-optimization/SKILL.md).

## The Core Rule: Old Code Must Survive the Migration

During a rolling deploy, the migration applies while instances running the **old**
code are still serving traffic. A migration that the old code cannot tolerate
causes errors until every instance is replaced. This is why destructive,
in-place changes are unsafe and **expand-contract** exists.

## Expand-Contract (Zero-Downtime)

Split every breaking change into additive steps that are each safe with both code
versions, separated by deploys.

| Change | ❌ Unsafe (one step) | ✅ Expand-contract |
|--------|---------------------|--------------------|
| Rename `name` → `full_name` | `ALTER ... RENAME COLUMN` | 1. Add `full_name` 2. App writes both, reads `full_name` 3. Backfill 4. Drop `name` |
| Add `NOT NULL` column | `ADD COLUMN x text NOT NULL` | 1. Add nullable + default 2. Backfill 3. `SET NOT NULL` (validated) |
| Drop a column | `DROP COLUMN` while old code reads it | 1. Stop reading in code (deploy) 2. `DROP COLUMN` (next deploy) |
| Narrow a type / add `CHECK` | `ALTER ... TYPE` / `ADD CHECK` (full scan, lock) | 1. Add `CHECK ... NOT VALID` 2. `VALIDATE CONSTRAINT` (no lock) |

The pattern is always: **expand** (additive, both versions safe) → **migrate code +
backfill** → **contract** (remove the old thing, after all code stopped using it).

```sql
-- Add a NOT NULL column without a long lock or a failed deploy
-- step 1 (expand): nullable, with a default for new rows
ALTER TABLE orders ADD COLUMN currency text DEFAULT 'USD';
-- step 2 (backfill): set existing rows in batches (see Backfills)
-- step 3 (contract): enforce, validate without an exclusive lock
ALTER TABLE orders ALTER COLUMN currency SET NOT NULL;  -- PG validates existing rows
```

## Online DDL & Locking Pitfalls

The danger is not the change — it is the **lock** and the **table rewrite** it
triggers while holding it.

```sql
-- ❌ blocks ALL reads+writes on a big table for the duration of an index build
CREATE INDEX orders_user_idx ON orders (user_id);

-- ✅ builds without blocking writes (cannot run inside a transaction)
CREATE INDEX CONCURRENTLY orders_user_idx ON orders (user_id);

-- ✅ add a constraint without scanning the whole table under lock, then validate
ALTER TABLE orders ADD CONSTRAINT total_nonneg CHECK (total_cents >= 0) NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT total_nonneg;  -- takes only a SHARE lock
```

PostgreSQL specifics:
- `CREATE INDEX CONCURRENTLY` / `DROP INDEX CONCURRENTLY` — no write lock, but
  cannot be inside a transaction block (many migration tools wrap each migration
  in a txn — disable it for these).
- Adding a column with a **non-volatile default** is metadata-only since PG 11
  (no rewrite). A `volatile` default still rewrites.
- `lock_timeout` + retry: set `SET lock_timeout = '3s'` so a migration waiting on a
  lock fails fast instead of queueing behind it and blocking all traffic.

MySQL specifics:
- Prefer `ALGORITHM=INPLACE, LOCK=NONE`; verify the operation supports it (some
  type changes force `COPY`, which rewrites and locks). Use `gh-ost` / `pt-online-schema-change`
  for changes InnoDB cannot do online.

## Backfills

Never `UPDATE` a large table in one statement — it takes one giant lock/transaction,
bloats WAL/undo, and blocks vacuum/replication. Batch by primary key.

```sql
-- batched backfill loop (run from a script/job, NOT one statement)
UPDATE orders
SET    currency = 'USD'
WHERE  id BETWEEN :lo AND :hi
  AND  currency IS NULL;          -- idempotent: safe to re-run a batch
```

- Batch size 1k–10k rows; sleep briefly between batches to let replicas catch up.
- **Idempotent batches** (the `WHERE ... IS NULL` guard) so a crashed backfill resumes safely.
- Run backfills as a separate, resumable job — not inside the schema migration that
  must be fast. Schema change ships first (expand); backfill runs after; contract last.
- Watch replication lag; throttle if replicas fall behind.

## Reversibility

- Every migration ships a tested **`down`**. Production rolls *forward* (you fix
  forward with a new migration), but a reversible migration is a reviewable contract
  and your local/CI escape hatch.
- A data-destroying contract step (`DROP COLUMN`) is **not truly reversible** — its
  `down` re-adds an empty column. Note that; do not pretend the data comes back.
- Never edit a migration that has run in any shared environment. Add a new one.

## Version Markers & Fallbacks

| Capability | Needs | Fallback |
|------------|-------|----------|
| `CREATE INDEX CONCURRENTLY` | PostgreSQL (any modern) | accept the lock in a maintenance window |
| `ADD CONSTRAINT ... NOT VALID` + `VALIDATE` | PostgreSQL 9.4+ | add constraint in a window |
| Metadata-only `ADD COLUMN ... DEFAULT` | PostgreSQL 11+ | add nullable, backfill, set default |
| `ALGORITHM=INPLACE, LOCK=NONE` | MySQL 8.0 (op-dependent) | `gh-ost` / `pt-online-schema-change` |
| `MERGE` for upsert backfills | PostgreSQL 15+ / MySQL 8 | `INSERT ... ON CONFLICT` / `ON DUPLICATE KEY` |

Confirm against the [version-feature-matrix](../../_shared/version-feature-matrix.md).

## Admin Processes Run Against the Release

A migration is the canonical *admin process*: a one-off task run beside the
long-running processes, not inside them. The same is true of a REPL/console
session, a backfill script, and any one-time repair.

The rule is that an admin process runs **against the same release** as the app —
same code, same config, same dependency isolation. Drift there is how a
migration written for the new schema runs against yesterday's code, or a
console session connects to the wrong database.

```bash
# Same image, same env, one-off command — not a second, differently-built artifact
kubectl run migrate-$(date +%s) --rm -i --restart=Never \
  --image=registry.example.com/orders-api:${GIT_SHA} \
  --env-file=prod.env -- npx prisma migrate deploy

docker compose run --rm api npx prisma migrate deploy   # locally, same service definition
```

- **Do not migrate on application boot.** Every replica racing the same DDL turns
  a rolling deploy into a lock pile-up, and it makes startup slow and fallible.
  Run migrations as a discrete step that must succeed before the new release
  takes traffic.
- **Use the app's own dependency isolation** — `npx`/`bundle exec`/`uv run`, the
  same lockfile, the same image — never an ad-hoc client on someone's laptop.
- Expand-contract is what lets the migration step and the deploy step be
  ordered independently; see above.

## Migration Evidence

A migration is non-UI work — `requires_screenshots: false`. The cli-fallback
evidence for a migration gate is the **migration log + lock observations**, not a
screenshot:

```bash
# scoped, single-command — capture the apply log
prisma migrate deploy 2>&1 | tee migrate.log
# confirm no long-held lock during the change (PostgreSQL)
psql "$DATABASE_URL" -c "SELECT relation::regclass, mode, granted FROM pg_locks WHERE NOT granted;"
```

Attach the apply log, the `down` dry-run output, and (for big tables) lock/replication
observations. See [CORPFLOW.md](../../../CORPFLOW.md).

## Diagnostics

| Symptom | Cause | Fix |
|---------|-------|-----|
| Deploy errors right after migration | non-expand-contract change; old code broke | Split into expand → migrate → contract |
| Migration hangs / all queries time out | exclusive lock held during long DDL | `CREATE INDEX CONCURRENTLY`; `lock_timeout` + retry |
| `CREATE INDEX CONCURRENTLY ... cannot run inside a transaction` | tool wraps migrations in a txn | Disable transaction for that migration (per-tool flag) |
| Backfill `UPDATE` blocks writes / bloats WAL | single giant statement | Batch by PK with `IS NULL` guard, throttle |
| Replica lag spikes during backfill | batches too large/fast | Smaller batches, sleep between, watch lag |
| `down` "works" but data is gone | contract step dropped data | Treat destructive contracts as one-way; fix forward |

## Deep-Dive References

- [references/per-tool-recipes.md](references/per-tool-recipes.md) — exact commands
  and gotchas for Prisma, Drizzle, golang-migrate, Flyway, Liquibase, Alembic, and
  EF Core (including how each disables the wrapping transaction for `CONCURRENTLY`)

## Related Skills

- [schema-design](../schema-design/SKILL.md) — the target shape you migrate toward
- [query-optimization](../query-optimization/SKILL.md) — indexes shipped with the migration
- [orm-patterns](../orm-patterns/SKILL.md) — generating migrations from ORM models
- [be-testing](../../quality/be-testing/SKILL.md) — testing migrations on a real engine (Testcontainers)
- [secure-coding](../../_shared/secure-coding/SKILL.md) — migrations run with least privilege, no secrets in SQL
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — engine DDL capabilities
