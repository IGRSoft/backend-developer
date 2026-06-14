---
name: db-migrate
description: Generate, apply, and verify database migrations with a safe forward + rollback plan
argument-hint: "<generate|apply|verify|rollback> [--name NAME] [--dry-run]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
estimated-cost:
  min-tokens: 1500
  max-tokens: 14000
  model-distribution:
    haiku: 25%
    sonnet: 65%
    opus: 10%
---

# Database Migrate
<!-- Updated: June 2026 -->

Detect a project's migration tool, then generate, apply, verify, or roll back schema migrations with a single command. The happy path is pure Bash — no agent delegation. Agents are only engaged when a migration is unsafe, fails, or needs schema design, and only the agent that owns the failing concern is consulted, with the relevant migration log excerpt.

[Extended thinking: This command is the schema-change workhorse other backend-developer commands reuse. It resolves exactly one migration tool per invocation via a strict priority order, runs the canonical generate/apply/verify/rollback sequence for that tool, and tees everything to a timestamped migration log. Because a forward migration that locks a hot table or drops a column in production has sharply different consequences than a clean additive change, `verify` lints the pending SQL for unsafe operations and checks reversibility BEFORE anything touches the database. Keep the happy path deterministic and shell-only so it stays cheap and scriptable; the captured migration log is the cli-fallback evidence artifact, not a screenshot.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve exactly one migration tool.** Walk the detection priority order top-down and stop at the first match. Do NOT drive two migration tools in one invocation. If the user disagrees with the auto-detected tool, they re-run scoped to the subdirectory that holds the right config.
2. **Happy path is shell-only.** When the requested subcommand succeeds and `verify` reports no unsafe operations, do NOT delegate to any agent. Report the result and stop.
3. **`verify` runs before `apply` against production-like targets.** Never apply a generated migration to a shared/staging/prod database without first running `verify` (dry-run SQL + reversibility + unsafe-op lint). On `apply`, run the `verify` lint inline and refuse to proceed on a P0 unsafe op unless the user passed an explicit override in the migration body comment.
4. **Single-command Bash invocations.** Use each tool's own flags (`prisma migrate dev`, `drizzle-kit generate`, `migrate -path ... -database ... up`, `flyway migrate`, `alembic upgrade head`, `bin/rails db:migrate`, `dotnet ef migrations add`). Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands. Use the tool's `--project` / `-C` / working-dir flags instead.
5. **Tee every phase to the migration log.** Each generate/apply/verify/rollback command pipes through `tee -a` to `.context/logs/migrate-<timestamp>.log`. The log (SQL emitted + tool output + applied versions) is the single source of truth and the cli-fallback evidence artifact; do not rely on terminal scrollback.
6. **`--dry-run` never mutates the database.** For `apply`/`rollback`, `--dry-run` prints the SQL the tool would execute (or runs inside a transaction that is rolled back) and stops. Default (no `--dry-run`) executes.
7. **On failure or unsafe lint, classify before delegating.** Parse the first error or the flagged unsafe operation from the log, classify it as design / generate / apply / reversibility, then delegate ONLY to the matching agent with the excerpt — never the whole log, never a second agent "just in case."
8. **Tool-missing never hard-fails.** If the required migration binary is absent, print the install hint, skip that tool, and continue to the next eligible one in the priority order. Report what was skipped.
9. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Generate a migration from the current schema/model diff
/backend-developer:db-migrate generate --name add_orders_table

# Apply all pending migrations forward
/backend-developer:db-migrate apply

# Preview the SQL apply would run, without touching the DB
/backend-developer:db-migrate apply --dry-run

# Lint pending migrations for unsafe ops + reversibility, no mutation
/backend-developer:db-migrate verify

# Roll back the most recent migration
/backend-developer:db-migrate rollback
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `<subcommand>` | required | One of `generate`, `apply`, `verify`, `rollback`. See Subcommands. |
| `--name NAME` | tool-generated | For `generate`: the human-readable migration name/slug (`add_orders_table`). Ignored by `apply`/`verify`; for `rollback` it names the target to roll back *to* where the tool supports it. |
| `--dry-run` | off | For `apply`/`rollback`: print the SQL that would run (or run-and-rollback inside a transaction) without committing. `verify` is always dry by definition; `generate` writes the migration file but never applies it. |

`--name` and `--dry-run` are independent: `generate --name X` writes a named migration file; `apply --dry-run` previews without naming anything.

## Detection: Migration-Tool Priority

Scan the project and apply the **first** match top-down. This is the canonical priority for this plugin; the marker → ecosystem → agent map lives in `skill: migration-detection` — keep this list in sync with it, do not fork the routing logic.

| Priority | Marker | Migration tool | Owning agent (on failure) |
|----------|--------|----------------|---------------------------|
| 1 | `prisma/schema.prisma` | Prisma Migrate | `node-developer` |
| 2 | `drizzle.config.{ts,js}` | Drizzle Kit | `node-developer` |
| 3 | `ormconfig` / TypeORM `DataSource` + `migrations/` | TypeORM migrations | `node-developer` |
| 4 | `migrate`/`goose`/`atlas.hcl` + `migrations/*.sql` | golang-migrate / goose / Atlas | `go-developer` |
| 5 | `db/migration/V*.sql` or `changelog.xml`/`db.changelog*.yaml` | Flyway / Liquibase | `jvm-backend-developer` |
| 6 | `alembic.ini` + `alembic/versions/` | Alembic | `python-backend-developer` |
| 7 | `db/migrate/*.rb` + `config/database.yml` | Rails `db:migrate` | `ruby-developer` |
| 8 | `Migrations/` + `*.csproj` with EF Core | EF Core migrations | `dotnet-developer` |
| 9 | `migrations/Version*.php` + `doctrine` config | Doctrine Migrations | `php-developer` |

**Tie-break notes:**

- A repo can carry both a Prisma schema and a Drizzle config (mid-migration between ORMs). Prisma wins for *this* command's primary action; mention the Drizzle layer in the summary and suggest a second run scoped to the Drizzle config if its migrations matter.
- A `migrations/` directory that holds only raw seed `.sql` data files (no schema DDL and no tool runner) is data seeding, not a migration tool — if no tool config sits beside it, prefer the next real marker.
- Auxiliary `scripts/*.sql` ad-hoc query files never make a project a raw golang-migrate project.
- Schema *design* (new tables, index strategy, normalization, partitioning) is always routed to `database-engineer` regardless of which tool runs the migration — the owning language agent only handles tool/code failures.

## Canonical Command Table

Run these verbatim (substituting the migration `name`, project path, and database URL from the project's env). Every command is single-invocation and tees to the log.

| Tool | Generate | Apply | Verify (dry/lint) | Rollback |
|------|----------|-------|-------------------|----------|
| Prisma Migrate | `prisma migrate dev --create-only --name <NAME>` | `prisma migrate deploy` | `prisma migrate diff --from-... --to-... --script` (review emitted SQL) | `prisma migrate resolve --rolled-back <MIG>` + down SQL |
| Drizzle Kit | `drizzle-kit generate --name <NAME>` | `drizzle-kit migrate` | `drizzle-kit generate --name probe` then inspect SQL; `drizzle-kit check` | restore from prior snapshot / hand-written down |
| TypeORM | `typeorm migration:generate -n <NAME>` | `typeorm migration:run` | `typeorm migration:show` + read pending up SQL | `typeorm migration:revert` |
| golang-migrate | `migrate create -ext sql -dir migrations -seq <NAME>` | `migrate -path migrations -database "$DATABASE_URL" up` | `migrate ... up 1 --dry-run`-equivalent: read `*.up.sql` | `migrate -path migrations -database "$DATABASE_URL" down 1` |
| goose | `goose -dir migrations create <NAME> sql` | `goose -dir migrations postgres "$DSN" up` | `goose -dir migrations status` + read pending | `goose -dir migrations postgres "$DSN" down` |
| Atlas | `atlas migrate diff <NAME> --env local` | `atlas migrate apply --env local` | `atlas migrate lint --env local --latest 1` | `atlas migrate down --env local 1` |
| Flyway | (author `V<n>__<NAME>.sql`) | `flyway migrate` | `flyway info` + `flyway validate` (and review `U<n>__` undo if present) | `flyway undo` (paid edition) or apply `U<n>__` undo script |
| Liquibase | `liquibase diffChangeLog` | `liquibase update` | `liquibase updateSQL` (prints SQL, no apply) | `liquibase rollbackCount 1` |
| Alembic | `alembic revision --autogenerate -m "<NAME>"` | `alembic upgrade head` | `alembic upgrade head --sql` (offline SQL, no apply) | `alembic downgrade -1` |
| Rails | `bin/rails generate migration <NAME>` | `bin/rails db:migrate` | `bin/rails db:migrate:status` + `db:migrate VERSION=...` dry inspection | `bin/rails db:rollback STEP=1` |
| EF Core | `dotnet ef migrations add <NAME>` | `dotnet ef database update` | `dotnet ef migrations script --idempotent` (emits SQL, no apply) | `dotnet ef database update <PreviousMigration>` |
| Doctrine | `php bin/console doctrine:migrations:generate` | `php bin/console doctrine:migrations:migrate` | `... migrate --dry-run` (prints SQL) | `... migrations:execute --down <VERSION>` |

Notes:
- Always read the `DATABASE_URL`/`DSN` from the project's `.env`/config rather than hard-coding it; never echo the full connection string (with credentials) into the log — redact the password.
- For tools without a first-class down/undo (Drizzle, Flyway free edition, Prisma), `verify` MUST flag the migration as **irreversible** and require a hand-written down script or a forward-only fix plan before `apply`.
- `--create-only` / `--autogenerate` variants generate the file WITHOUT applying — that is the intended `generate` behavior here.

## Workflow

### Phase 1: Detect (Bash)

1. Confirm the project root and that a database config/env is present. If no DB target is resolvable for `apply`/`rollback`, emit the Error Handling "no database target" message and stop.
2. Create `.context/logs/` if absent. Compute `TS="$(date +%Y%m%d-%H%M%S)"` and `LOG=".context/logs/migrate-${TS}.log"`.
3. Walk the detection priority table top-down; record the first matching marker and its migration tool. If nothing matches, emit "no recognized migration tool" and stop.
4. Pre-resolve the owning language agent (used only if a later phase fails on tool/code grounds). Schema *design* questions route to `database-engineer` regardless.
5. Verify the required tool is installed (`command -v prisma`/`drizzle-kit`/`migrate`/`goose`/`atlas`/`flyway`/`liquibase`/`alembic`/`dotnet`/`php`). If missing, print the install hint (see Tool Availability), skip to the next eligible marker, and note the skip in the summary.

### Phase 2: Dispatch on subcommand (Bash)

Run the matching column from the Canonical Command Table, teeing to the log. Capture `${PIPESTATUS[0]}` (not `tee`'s exit). On non-zero, go to Failure Triage with the stage matching the subcommand.

- **`generate`** — Run the generate command with `--name`. The migration file is written but NOT applied. Then immediately run the `verify` lint (Phase 3) over the freshly generated SQL so the author sees unsafe ops before committing.
- **`apply`** — First run the `verify` lint inline (Phase 3). If a P0 unsafe op is flagged and no override comment is present, STOP and report (do not apply). If `--dry-run`, print the SQL the tool would run and stop. Otherwise run the apply command, then record the new applied version(s) in the log.
- **`verify`** — Run Phase 3 only; never mutate the database.
- **`rollback`** — If `--dry-run`, print the down SQL and stop. Otherwise run the rollback command for one step (or to the `--name` target where supported), then record the reverted version in the log. If the tool has no down support, refuse and point to the hand-written down script.

### Phase 3: Verify lint (Bash + read)

Run the tool's dry-run SQL emitter from the Verify column, tee to the log, then scan the emitted SQL for unsafe operations and reversibility:

| Signal in emitted SQL | Severity | Why |
|-----------------------|----------|-----|
| `DROP COLUMN`, `DROP TABLE`, `DROP CONSTRAINT` | P0 | Destructive; data loss. Needs expand-contract: stop writing first, deploy, drop later. |
| `ALTER TABLE ... ALTER COLUMN ... TYPE`, `ADD COLUMN ... NOT NULL` without default on a large table | P0 | Full-table rewrite / blocking lock on hot tables. |
| `CREATE INDEX` without `CONCURRENTLY` (Postgres) on a populated table | P1 | Holds a write lock for the duration of the build. |
| `RENAME COLUMN`/`RENAME TABLE` | P1 | Breaks deployed readers until they redeploy; needs expand-contract. |
| No down/undo for the tool, or empty `down`/`U__` script | P1 | Irreversible — blocks safe rollback. Require a hand-written down or forward-fix plan. |
| Backfill `UPDATE` inside the schema migration | P1 | Long-running write lock; should be a separate batched/idempotent job. |

A P0 finding blocks `apply` unless the migration body carries an explicit `-- unsafe-op-ack: <reason>` comment. Record all findings in the log; this lint output is the evidence artifact.

### Phase 4: Report (Bash)

Emit the Output Format summary. On clean success, stop — no delegation.

## Failure Triage

Triggered when a phase exits non-zero OR the verify lint flags an unblocked P0. Steps:

1. **Parse the first error / flagged op** from the log. Search top-down for the first line matching the active tool's error format (e.g. `Error: P3009`/`P3018` for Prisma, `error: migration failed` for golang-migrate, `FlywayException`/`ValidateOutput` for Flyway, `alembic.util.exc.CommandError` for Alembic, `Npgsql.PostgresException` for EF Core) or the first P0/P1 from the verify table.
2. **Classify the concern:**

   | Symptom in log | Concern |
   |----------------|---------|
   | Unsafe DDL (drop/rewrite/blocking lock), expand-contract needed, irreversibility, index strategy, normalization, partitioning, N+1-inducing schema | `design` |
   | Autogenerate produced wrong/empty diff, schema-vs-model drift, generator could not introspect, ambiguous rename | `generate` |
   | `apply` failed mid-run: constraint violation, lock timeout, dirty migration state, connection/auth error, type mismatch on existing data | `apply` |
   | No down script, down script errors, partial rollback, schema left dirty after a failed apply | `reversibility` |

3. **Extract a tight excerpt** — the first error or flagged op plus the relevant emitted SQL (the offending `ALTER`/`DROP` statement and ~10 surrounding lines), not the whole log. Include the log path so the agent can read more if needed.
4. **Delegate to the matching agent** with the excerpt:

   - `design` / unsafe DDL / reversibility strategy →
     **Use Task tool with subagent_type="backend-developer:database-engineer"**
     Prompt: "A database migration was flagged at the **{concern}** concern for the {tool} project. Emitted SQL and lint findings from `{LOG}`:\n```\n{excerpt}\n```\nPropose a zero-downtime, expand-contract plan: the safe ordering of additive forward steps, the backfill strategy (batched + idempotent), the contract step, and a working down/rollback path. Return the revised migration plan; do not apply anything."
   - `generate` (autogenerate diff / drift / generator failure) → route to the **owning language agent** resolved in Phase 1:
     - Prisma/Drizzle/TypeORM → **subagent_type="backend-developer:node-developer"**
     - golang-migrate/goose/Atlas → **subagent_type="backend-developer:go-developer"**
     - Flyway/Liquibase → **subagent_type="backend-developer:jvm-backend-developer"**
     - Alembic → **subagent_type="backend-developer:python-backend-developer"**
     - Rails → **subagent_type="backend-developer:ruby-developer"**
     - EF Core → **subagent_type="backend-developer:dotnet-developer"**
     - Doctrine → **subagent_type="backend-developer:php-developer"**

     Prompt: "Migration generation failed at the **{concern}** stage for the {tool} project. First error and context from `{LOG}`:\n```\n{excerpt}\n```\nDiagnose the schema-vs-model drift or generator failure and propose the minimal fix (corrected model, explicit rename mapping, or regeneration flags). Return analysis and patch; do not apply the migration."
   - `apply` failure that is purely a tool/connection/state issue → owning language agent (same routing) with the apply error excerpt; if the root cause is the schema shape itself, route to `database-engineer` instead.
   - Ambiguous tool/ecosystem → **subagent_type="backend-developer:backend-developer"** (router) with the excerpt and detected markers.

5. After the agent returns a fix, re-run from the failing phase (re-`generate` if the fix touched the model, otherwise re-`verify` then `apply`). Do NOT auto-apply across multiple iterations silently — report each cycle.

## Tool Availability

Before running each tool, confirm its binary exists. If missing, print the hint, skip the tool, continue down the priority list, and note the skip.

| Missing tool | Install hint |
|--------------|--------------|
| `prisma` / `drizzle-kit` / `typeorm` | `npm i -D prisma drizzle-kit typeorm` (run via `npx`/`pnpm exec`) |
| `migrate` (golang-migrate) | `brew install golang-migrate` (or `go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest`) |
| `goose` | `go install github.com/pressly/goose/v3/cmd/goose@latest` |
| `atlas` | `curl -sSf https://atlasgo.sh \| sh` (verify against your toolchain) |
| `flyway` | `brew install flyway` |
| `liquibase` | `brew install liquibase` |
| `alembic` | `uv add alembic` (run via `uv run alembic`) |
| `dotnet ef` | `dotnet tool install --global dotnet-ef` |
| `php` / Doctrine | `composer require doctrine/migrations` |

Never hard-fail on a missing tool — skip and report.

## Output Format

```markdown
## Database Migration Report

**Subcommand:** {generate | apply | verify | rollback}{ --dry-run}
**Migration tool:** {tool} ({marker})
**Owning ecosystem:** {Node | Go | JVM | Python | Ruby | PHP | .NET}
**Migration:** {name or version applied/reverted}
**Log (evidence):** .context/logs/migrate-{timestamp}.log

| Phase | Result | Notes |
|-------|--------|-------|
| Detect | ✅ / ⏭ skipped | {tool, marker, or skip reason} |
| Generate | ✅ / ❌ / ⏭ | {migration file path, or N/A} |
| Verify (lint) | ✅ / ⚠ / ❌ / ⏭ | {P0/P1 unsafe-op count, reversible? yes/no} |
| Apply | ✅ / ❌ / ⏭ | {versions applied, or "--dry-run" / "blocked by P0"} |
| Rollback | ✅ / ❌ / ⏭ | {version reverted, or N/A} |

**Result:** PASS / BLOCKED ({unsafe op}) / FAIL ({failing concern})

<!-- Always include for verify/apply: -->
### Safety
- **Reversible:** yes / no (down path: {present | hand-written needed})
- **Unsafe ops:** {none, or list with severity}
- **Zero-downtime note:** {expand-contract / backfill guidance if any P0/P1}

<!-- On failure or blocked only: -->
### Triage
- **Concern:** {design | generate | apply | reversibility}
- **First issue:** {one-line summary}
- **Delegated to:** backend-developer:{agent}
- **Proposed fix:** {summary from agent, or "see agent output"}

<!-- On skipped tools only: -->
### Skipped
- {tool}: {missing binary} — install hint printed above.
```

## Error Handling

### No database target
```
Error: No database connection resolvable for {subcommand}.
Looked for: DATABASE_URL / DSN in .env, config/database.yml, or tool config.
Suggestion: Set DATABASE_URL in your environment, or run `verify` (which needs no live DB).
```

### No recognized migration tool
```
Error: No migration tool detected.
Looked for: prisma/schema.prisma, drizzle.config.*, TypeORM migrations/, golang-migrate/
goose/atlas.hcl, Flyway db/migration/V*.sql, Liquibase changelog, alembic.ini,
Rails db/migrate/, EF Core Migrations/, Doctrine migrations/.
Suggestion: Run from the directory that holds the migration config, or initialize one.
```

### Irreversible migration (no down script)
Not a hard error for `generate`/`verify` — report it: "Migration is irreversible (tool has no down support / empty down script). A hand-written down script or forward-fix plan is required before `apply`." Block `apply` on it unless an `-- unsafe-op-ack:` comment is present.

### Dirty migration state after a failed apply
```
Warning: Migration history is in a dirty/failed state ({version}).
The database may be partially migrated. Do NOT re-run apply blindly.
Suggestion: Inspect the log, resolve the failed version (e.g. `prisma migrate resolve`,
`migrate force <V>`, `flyway repair`), then re-verify before applying.
```
Route the dirty-state recovery to `database-engineer` with the apply excerpt.

### `--dry-run` on `generate`
```
Note: --dry-run is implied for generate (it writes the migration file but never applies it).
Proceeding to write + lint the migration without touching the database.
```

### Toolchain missing
Print the install hint from Tool Availability, skip the tool, continue. Only when *every* eligible tool is skipped does the command report FAIL with the aggregated install hints.

## See Also

- `skill: migration-detection` — canonical marker → ecosystem → agent routing (keep the priority table in sync).
- `skill: zero-downtime-migrations` — expand-contract pattern, batched idempotent backfills, `CREATE INDEX CONCURRENTLY`, lock-timeout guards, online schema-change tools (gh-ost, pt-online-schema-change).
- `/backend-developer:db-migrate verify` — always run before `apply` against a shared database.
- `/backend-developer:api-test` — re-run the API request/response suite after a migration to confirm contracts still hold.
- `/backend-developer:deps-audit` — when a migration tool itself is outdated or carries a CVE.
- Route schema *design* (new tables, indexes, partitioning, normalization) to `database-engineer` via the Task tool before generating the migration.
