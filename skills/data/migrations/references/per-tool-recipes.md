# Per-Tool Migration Recipes

Exact commands and the one gotcha that bites each tool. Read after
[migrations/SKILL.md](../SKILL.md) — the expand-contract / online-DDL doctrine there
applies to all of these.

Single-command Bash invocations throughout — no `cd`-chains.

## Prisma (Node/TypeScript)

```bash
prisma migrate dev --name add_currency   # dev: create + apply, regenerate client
prisma migrate deploy                     # CI/prod: apply pending, no prompts
prisma migrate diff --from-schema-datamodel ... --script   # generate raw SQL
prisma migrate resolve --applied <name>   # mark a manually-fixed migration done
```

- **Gotcha — `CONCURRENTLY`**: Prisma wraps each migration in a transaction. Put a
  `CREATE INDEX CONCURRENTLY` in its **own** migration file and Prisma runs it
  outside a transaction automatically only for that statement; safest is to edit the
  generated SQL and keep the file to a single concurrent statement.
- `prisma migrate deploy` is the only command to run in prod — never `migrate dev`.
- Edit the generated SQL for expand-contract; Prisma's schema-diff defaults to the
  unsafe one-step form (e.g. it will emit a destructive `RENAME`/`DROP`).

## Drizzle (Node/TypeScript)

```bash
drizzle-kit generate          # diff schema.ts → SQL migration files
drizzle-kit migrate           # apply pending migrations
drizzle-kit push              # dev-only: push schema directly (no migration file)
```

- **Gotcha**: `drizzle-kit push` skips the migration history — use it only for
  throwaway dev DBs, never prod. Prod uses `generate` + `migrate`.
- Generated SQL is editable; hand-write expand-contract steps and `CONCURRENTLY`.

## golang-migrate (Go)

```bash
migrate -path ./migrations -database "$DATABASE_URL" up
migrate -path ./migrations -database "$DATABASE_URL" down 1
migrate create -ext sql -dir ./migrations -seq add_currency   # NNNN_*.up.sql / .down.sql
migrate -path ./migrations -database "$DATABASE_URL" force 5   # clear dirty state
```

- **Gotcha — dirty state**: a failed migration leaves the schema-version table
  `dirty`; subsequent `up` refuses until you `force` to the last good version and
  fix forward. Make each migration small so this is rare.
- Add `?x-migrations-table=...&...` and use the `pgx`/`postgres` driver; for
  `CONCURRENTLY`, golang-migrate runs each file outside a transaction when the file
  contains no other statements (one statement per file).

## Flyway (JVM)

```bash
mvn flyway:migrate          # apply V*__*.sql in order
mvn flyway:info             # show applied/pending
mvn flyway:validate         # verify checksums match what ran
mvn flyway:repair           # fix checksum/failed-migration metadata
```

- Versioned `V1__desc.sql`, repeatable `R__desc.sql`, undo `U1__desc.sql` (Teams edition).
- **Gotcha — checksums**: never edit an applied `V` file; Flyway validates checksums
  and fails. Add a new version. Use `flyway:repair` only to fix metadata, not to
  excuse editing history.
- For `CREATE INDEX CONCURRENTLY` set `flyway.postgresql.transactional.lock=false`
  and `-- flyway no-transaction` so Flyway does not wrap that script in a txn.

## Liquibase (JVM)

```bash
liquibase update            # apply changesets
liquibase rollbackCount 1   # roll back the last changeset
liquibase updateSQL         # print SQL without applying (review)
```

- Changelog in XML/YAML/JSON/SQL; each `changeSet` has an `id`+`author` and a
  computed checksum.
- **Gotcha**: declare a `rollback` block per changeset — Liquibase cannot auto-roll-back
  arbitrary SQL. For `CONCURRENTLY`, set `runInTransaction="false"` on the changeSet.

## Alembic (Python)

```bash
uv run alembic revision --autogenerate -m "add currency"   # diff models → script
uv run alembic upgrade head        # apply to latest
uv run alembic downgrade -1        # one step back
uv run alembic upgrade head --sql  # offline: emit SQL only
```

- **Gotcha — autogenerate is a draft**: it detects added/removed columns and indexes
  but misses renames (sees drop+add), server defaults, and CHECK changes. Always read
  and edit the generated `upgrade()`/`downgrade()`.
- For `CONCURRENTLY`, run with `with op.get_context().autocommit_block():` so the
  statement executes outside Alembic's per-migration transaction.

## EF Core (.NET)

```bash
dotnet ef migrations add AddCurrency      # scaffold a migration from model diff
dotnet ef database update                 # apply to the database
dotnet ef migrations script --idempotent  # CI/prod: generate idempotent SQL to review+apply
dotnet ef migrations remove               # drop the last (unapplied) migration
```

- **Gotcha — prod applies SQL, not the CLI**: generate an `--idempotent` script and
  run it through your deploy pipeline; do not run `database update` against prod.
- EF emits the unsafe one-step form for renames/drops; edit `migrationBuilder` calls
  to express expand-contract. `migrationBuilder.Sql("CREATE INDEX CONCURRENTLY ...")`
  with `suppressTransaction: true` for the concurrent index.

## Cross-Tool Checklist

- One logical change per migration; small migrations fail and recover cleanly.
- Prod command is the non-interactive deploy verb (`migrate deploy`, `flyway:migrate`,
  `database update` via script) — never the dev/autogenerate verb.
- Concurrent index / online DDL needs the tool's "no transaction" escape; know it for
  your tool (above).
- Capture the apply log as gate evidence (see [migrations/SKILL.md](../SKILL.md) §
  Migration Evidence).

## Related

- [migrations/SKILL.md](../SKILL.md) — expand-contract, backfills, locking doctrine
- [orm-patterns](../../orm-patterns/SKILL.md) — model-first vs SQL-first migration flow
- [be-testing](../../../quality/be-testing/SKILL.md) — running migrations under Testcontainers in CI
