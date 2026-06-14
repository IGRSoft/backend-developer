# Integration Testing with Testcontainers

Integration tests run your code against the **real** backing services — same engine and version as production — in throwaway containers. They catch the bugs unit tests with mocked DBs cannot: constraint violations, transaction semantics, ORM/SQL mistakes, migration drift, and N+1.

## Why not just mock the DB

A mocked repository returns what you told it to. It cannot fail a unique constraint, enforce a foreign key, roll back a transaction, or reproduce a serialization conflict. Those are exactly the back-end bugs that reach production. Run the data layer for real; mock only across network seams you don't own.

## Per-stack setup

### Node (vitest/jest)

```ts
import { PostgreSqlContainer } from "@testcontainers/postgresql";
import { RedisContainer } from "@testcontainers/redis";

let pg: StartedPostgreSqlContainer;
beforeAll(async () => {
  pg = await new PostgreSqlContainer("postgres:16").start();
  process.env.DATABASE_URL = pg.getConnectionUri();
  await runMigrations();          // real migrations, throwaway DB
}, 60_000);
afterAll(() => pg.stop());
```

### Go

```go
func setupPostgres(t *testing.T) string {
    ctx := context.Background()
    c, err := postgres.Run(ctx, "postgres:16",
        postgres.WithDatabase("app"), postgres.WithUsername("u"), postgres.WithPassword("p"),
        testcontainers.WithWaitStrategy(wait.ForListeningPort("5432/tcp")))
    require.NoError(t, err)
    t.Cleanup(func() { c.Terminate(ctx) })
    dsn, _ := c.ConnectionString(ctx, "sslmode=disable")
    return dsn
}
```

### Spring Boot (JUnit 5)

```java
@Testcontainers
@SpringBootTest
class OrderIT {
  @Container static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16");
  @DynamicPropertySource static void props(DynamicPropertyRegistry r) {
    r.add("spring.datasource.url", pg::getJdbcUrl);
    r.add("spring.datasource.username", pg::getUsername);
    r.add("spring.datasource.password", pg::getPassword);
  }
}
```

### Python (pytest)

```python
import pytest
from testcontainers.postgres import PostgresContainer

@pytest.fixture(scope="session")
def db_url():
    with PostgresContainer("postgres:16") as pg:
        url = pg.get_connection_url()
        run_migrations(url)
        yield url
```

`.NET` uses `Testcontainers.PostgreSql`; Ruby can use the `testcontainers` gem or a Dockerized service in CI. Pin the image tag to the production version so you test the engine you ship on.

## Isolation between tests

Tests must not see each other's data. Two reliable patterns:

| Pattern | How | Tradeoff |
|---------|-----|----------|
| **Transactional rollback** | begin a tx in setup, run the test, roll back in teardown | fast; but can't test code that commits or spans connections |
| **Truncate between tests** | `TRUNCATE table1, table2 RESTART IDENTITY CASCADE` after each | works with real commits; slightly slower |
| **Schema/DB per test class** | each suite gets its own schema | best for parallel runs; more setup |

Transactional rollback is fastest and the default for repository tests. Use truncate (or per-schema) when the code under test commits its own transactions or you test across connections.

## Parallel-safe runs

Containers are slow to start, so reuse one container per suite and isolate **inside** it:

- Give each parallel worker its own **schema** (`SET search_path`) or its own database in the shared container.
- Or run one container per test file with the framework's parallelism, accepting the startup cost.
- Use `wait` strategies (port/log/healthcheck) so tests don't race the container's readiness.

## Migrations in the loop

Run your real migration tool (Flyway, Liquibase, `prisma migrate deploy`, Alembic, `golang-migrate`, EF `Update-Database`) against the fresh container. This:

- Verifies migrations actually apply cleanly from zero.
- Catches schema drift between the migration and the ORM model.
- Lets you test **expand/contract** safety: apply the migration, then assert both old and new code paths work (no destructive change before the deploy that needs it).

## Stubbing the third-party boundary

You own the DB → run it. You don't own Stripe/SendGrid/a partner API → stub it at the HTTP layer:

```ts
import nock from "nock";
nock("https://api.partner.com").get("/v1/rate").reply(200, { rate: 1.1 });
```

Equivalents: WireMock (JVM), `respx`/`responses` (Python), `httptest.Server` (Go), MSW (Node). Better yet, replace ad-hoc stubs with a **contract test** so the stub can't drift from the real provider — see [contract-testing](contract-testing.md).

## Test data factories

```python
# factory-boy — defaults + override only what matters
class OrderFactory(factory.Factory):
    class Meta: model = Order
    customer_id = factory.Sequence(lambda n: f"c{n}")
    total = 1000
order = OrderFactory(total=50)   # everything else defaulted
```

Equivalents: `fishery` (Node), `FactoryBot` (Ruby), Test Data Builders (JVM/.NET). One test owns its data; never depend on rows another test created.

## Speed

- One container per suite, isolate inside it (don't start a container per test).
- Use `tmpfs` for the DB data dir in CI for a faster throwaway DB.
- Mark integration tests with a tag/profile so the fast unit suite can run on every save and integration runs on PR.
- **Reusable containers** (`withReuse()` / `testcontainers.reuse.enable=true`) keep a container alive across runs to skip startup — but the feature is still **experimental and explicitly not for CI** (it disables the Ryuk reaper, so containers leak between runs). Use it only for fast local iteration; CI should let Ryuk clean up per run.

Versions: skill [version-feature-matrix](../../../_shared/version-feature-matrix.md).

## Checklist

- [ ] Data layer tested against a real container, image pinned to the prod version.
- [ ] Test isolation via transactional rollback or truncate; no cross-test data sharing.
- [ ] Real migrations run against the container; expand/contract safety asserted.
- [ ] Third-party HTTP stubbed at the network seam (or a contract test).
- [ ] Factories with defaults; one test owns its data; deterministic clock/seed.
- [ ] Integration suite tagged separately from the fast unit suite.
