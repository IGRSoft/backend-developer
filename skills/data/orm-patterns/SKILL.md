---
name: orm-patterns
description: >-
  Use an ORM without footguns: connection pooling, lazy vs eager loading,
  transactions and isolation levels, the repository pattern, and avoiding
  ORM-generated N+1 across Prisma, Drizzle, TypeORM, GORM, Hibernate, EF Core,
  and SQLAlchemy. Use when configuring an ORM, getting `too many connections`,
  fixing N+1, choosing an isolation level, or structuring data access.
---

# ORM Patterns

**The ORM is a convenience over SQL — you still own the connections, the transactions, and the queries it emits**

## When to Use

Use this skill when:
- Configuring a new ORM (pool size, logging, transactions)
- Getting `too many connections` / pool-exhaustion errors under load
- An endpoint emits far more queries than expected (ORM N+1)
- Choosing a transaction isolation level or scoping a transaction
- Deciding whether to introduce a repository/service layer
- Picking loading strategy (lazy vs eager) for relations

The plans these queries produce → [query-optimization](../query-optimization/SKILL.md).
The schema being mapped → [schema-design](../schema-design/SKILL.md).

## Connection Pooling

The single most common production ORM failure is connection exhaustion. The
database has a hard `max_connections`; your pool must stay under it across **all**
app instances.

```ts
// Node: a pool PER PROCESS — multiply by instance count against the DB limit
// e.g. Postgres max_connections=100, 4 app instances → pool max ≤ ~20 each
```

Rules:
- **Pool size = (DB `max_connections` − reserve) ÷ instances**, not "as big as
  possible". A bigger pool does not mean more throughput past the core count;
  it means more idle connections starving everyone.
- **Serverless / autoscaling**: many short-lived instances each opening a pool
  blows past `max_connections` instantly. Put a **PgBouncer / RDS Proxy** in front
  (transaction pooling mode), and set the app pool to 1–2.
- **Set timeouts**: connection acquisition timeout, idle timeout, statement timeout —
  a leaked connection or runaway query must fail, not hang the pool forever.
- One pool per process, created at startup, reused — never per-request.

```sql
-- prove the ceiling and current usage (PostgreSQL)
SHOW max_connections;
SELECT count(*), state FROM pg_stat_activity GROUP BY state;
```

## Transactions & Isolation

Wrap every multi-statement mutation in a transaction; choose the isolation level
deliberately.

```ts
// Prisma interactive transaction — all-or-nothing, with chosen isolation
await prisma.$transaction(async (tx) => {
  const acct = await tx.account.update({
    where: { id }, data: { balance: { decrement: amount } },
  });
  if (acct.balance < 0) throw new Error("overdraft"); // rolls back the whole tx
  await tx.ledger.create({ data: { accountId: id, delta: -amount } });
}, { isolationLevel: "Serializable" });
```

```go
// GORM transaction
err := db.Transaction(func(tx *gorm.DB) error {
    if err := tx.Model(&acct).Update("balance", gorm.Expr("balance - ?", amt)).Error; err != nil {
        return err // returning an error triggers rollback
    }
    return tx.Create(&Ledger{AccountID: id, Delta: -amt}).Error
})
```

| Isolation | Guards against | Use for |
|-----------|----------------|---------|
| `Read Committed` (default) | dirty reads | most CRUD |
| `Repeatable Read` | non-repeatable reads | multi-read reports needing a stable snapshot |
| `Serializable` | write skew / phantom anomalies | money, inventory, anything with an invariant across rows |

- Higher isolation → more serialization failures; **retry on serialization errors**
  (`40001` / deadlock) with backoff. Keep transactions short — never do network I/O
  or call another service inside an open transaction (it holds locks).
- For "decrement only if available" invariants, prefer a single atomic statement
  (`UPDATE ... WHERE balance >= ?`) or `Serializable`, not read-then-write at `Read Committed`.

## Lazy vs Eager Loading (and ORM N+1)

Lazy loading is the N+1 factory: touch a relation in a loop and the ORM silently
fires one query per row.

```python
# SQLAlchemy 2.0 — ❌ lazy: each order.user access hits the DB (N+1)
for order in session.scalars(select(Order)).all():
    print(order.user.email)          # one SELECT per order

# ✅ eager: one JOIN / one IN-batch up front
orders = session.scalars(
    select(Order).options(selectinload(Order.user))
).all()
```

| ORM | Eager-load relation | N+1-safe batch |
|-----|--------------------|----------------|
| Prisma | `include` / `select` | automatic batched `IN` for `include` |
| Drizzle | `with: { user: true }` (relational query) | single query w/ joins |
| TypeORM | `relations: ['user']` / `leftJoinAndSelect` | `relationLoadStrategy: 'query'` |
| GORM | `Preload("User")` | `Preload` batches with `IN` |
| Hibernate | `JOIN FETCH` / `@EntityGraph` | avoid `FetchType.EAGER` globally; fetch per-query |
| EF Core | `.Include(o => o.User)` | split queries via `AsSplitQuery()` |
| SQLAlchemy | `selectinload` / `joinedload` | `selectinload` = one `IN` per relation |

- **Default relations to lazy in the mapping, eager-load per query** where you need
  them. Global `EAGER` (Hibernate) loads the world on every fetch.
- Beware `joinedload`/`leftJoinAndSelect` on one-to-many — it multiplies rows
  (cartesian); `selectinload`/split queries avoid the blowup.
- Verify with a **query count assertion** in tests; see [query-optimization](../query-optimization/SKILL.md) > N+1.

## Repository Pattern: When

- **Yes** when: domain logic must not depend on the ORM, you swap stores in tests,
  or queries are reused across many call sites. The repository exposes intent
  (`findActiveByTenant`) and hides the ORM.
- **No** (it's overhead) when: a thin CRUD service where the ORM *is* effectively
  your repository. Don't wrap `findUnique` in a one-line method for ceremony.
- Either way: **no raw ORM queries leaking into controllers/handlers** — that
  couples HTTP to persistence and scatters the N+1 / authorization logic.
- Authorization (OWASP API1 BOLA) belongs at this layer or below: scope every read
  to the caller's tenant/owner in the query, not after fetching. See
  [api-security](../../quality/api-security/SKILL.md).

## Version Markers & Fallbacks

| Capability | Needs | Fallback |
|------------|-------|----------|
| Prisma interactive transactions | Prisma 4.7+ (stable on current majors) | sequential `$transaction([...])` array |
| Prisma driver adapters (edge/serverless pools) | GA on current Prisma (Rust-free client is the default from v7) | direct driver + external pooler |
| Drizzle relational queries (`with`) | current stable | manual joins / `db.select()` |
| EF Core `AsSplitQuery()` | EF Core 5+ | accept cartesian or multiple manual queries |
| SQLAlchemy `selectinload` async | SQLAlchemy 2.0 async engine | sync session + `selectinload` |
| GORM prepared-stmt cache | GORM v2 (`PrepareStmt: true`) | per-query prepare |
| TypeORM `DataSource` API | TypeORM 0.3+ (1.0 is the modernized major) | legacy `Connection` API (0.2, removed) |

Confirm ORM/runtime versions against the canonical [version-feature-matrix](../../_shared/version-feature-matrix.md) (the single home for ORM floors).

## Diagnostics

| Symptom | Cause | Fix |
|---------|-------|-----|
| `too many connections` / pool timeout under load | pool × instances > DB max | size pool to DB limit ÷ instances; add PgBouncer |
| Serverless DB exhaustion | each lambda opens a pool | external pooler, app pool size 1–2 |
| Endpoint emits N queries | lazy loading in a loop | eager-load per query / batch |
| `joinedload` returns duplicated/multiplied rows | cartesian on one-to-many | `selectinload` / split query |
| Lost updates on concurrent writes | read-then-write at Read Committed | atomic `UPDATE ... WHERE`, or Serializable + retry |
| Deadlocks / `40001` errors | concurrent transactions, lock order | shorten tx, consistent lock order, retry with backoff |
| Connection leaks (pool slowly drains) | transaction/connection not released on error | always release in `finally`; use the framework's scoped tx helper |

## Related Skills

- [query-optimization](../query-optimization/SKILL.md) — reading the plans the ORM produces, fixing N+1
- [schema-design](../schema-design/SKILL.md) — the model the ORM maps
- [migrations](../migrations/SKILL.md) — generating migrations from ORM models
- [caching-strategies](../caching-strategies/SKILL.md) — caching read models above the ORM
- [api-security](../../quality/api-security/SKILL.md) — scoping queries to the caller (BOLA)
- [secure-coding](../../_shared/secure-coding/SKILL.md) — parameterized queries, no string-built SQL
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — ORM/runtime version floors
