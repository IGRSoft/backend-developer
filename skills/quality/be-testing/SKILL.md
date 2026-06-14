---
name: be-testing
description: >-
  Back-end testing strategy for web/service APIs: the unit/integration/contract/
  load test pyramid, Testcontainers for real backing services, contract testing
  (Pact / OpenAPI schema), test data and factories, mocking only at the boundary
  you don't own, and coverage gates. Use when designing a test strategy, writing
  integration tests against a real DB, adding contract tests, deciding what to
  mock, or setting coverage thresholds for a service.
---

# Back-end Testing

**Test against real backing services; mock only the seams you don't own**

## When to Use

Use this skill when:
- Designing a test strategy for a service or new feature
- Writing integration tests that hit a real database/queue/cache
- Adding contract tests so a "non-breaking" change can't break a consumer
- Deciding what to mock and what to run for real
- Setting coverage gates or a query-count assertion to catch N+1
- Wiring the test suite into CI as the QA gate

Routing: real-dependency integration tests →
[references/integration-testcontainers.md](references/integration-testcontainers.md);
consumer/provider contracts and schema fuzzing →
[references/contract-testing.md](references/contract-testing.md).
Shared principles (AAA, naming, flake): skill [testing-principles](${CLAUDE_SKILL_DIR}/_shared/testing-principles.md).

## The Back-end Test Pyramid

| Layer | Scope | Speed | Backing services | Run |
|-------|-------|-------|------------------|-----|
| **Unit** | pure logic, one function/class | ms | none (in-memory) | every save |
| **Integration** | handler ↔ DB/queue/cache | 100ms–s | **real**, via Testcontainers | every PR |
| **Contract** | your API ↔ each consumer/provider | fast | none (recorded) | every PR |
| **Load** | the service under traffic | minutes | prod-like | nightly/pre-release |
| **E2E** | full system, few critical paths | slow | full stack | sparingly |

Most tests are unit; a solid band of integration tests is where back-ends earn their confidence (the bugs live at the DB and transaction boundary). Keep E2E thin — it's slow and flaky. Load testing lives in [be-performance](${CLAUDE_SKILL_DIR}/quality/be-performance/SKILL.md).

## Mock the Boundary You Don't Own — Nothing Inside It

The default is **don't mock your own database.** A mocked DB asserts your assumptions, not the database's behavior — it misses constraint violations, transaction semantics, SQL/ORM bugs, and N+1.

| Dependency | Test approach |
|------------|---------------|
| Your DB / cache / queue | **real**, via Testcontainers — never a mock |
| Third-party HTTP API | mock/stub at the HTTP layer (`nock`, WireMock, `respx`, MSW) or a contract test |
| Time, randomness, UUIDs | inject a clock/seed — deterministic |
| Email/SMS/payment providers | stub the client; verify the call was made with the right args |

Mock at the network seam you don't control; run everything you do control for real. Details: [references/integration-testcontainers.md](references/integration-testcontainers.md).

## Integration Tests with Testcontainers

Spin up a real Postgres/Redis/Kafka in a container for the test run — same engine and version as production.

```ts
// vitest + Testcontainers (Node)
import { PostgreSqlContainer } from "@testcontainers/postgresql";

let url: string, container: StartedPostgreSqlContainer;
beforeAll(async () => {
  container = await new PostgreSqlContainer("postgres:16").start();
  url = container.getConnectionUri();
  await migrate(url); // run real migrations against the throwaway DB
}, 60_000);
afterAll(() => container.stop());

test("creates and reads back an order", async () => {
  const repo = new OrderRepo(url);
  const id = await repo.create({ customerId: "c1", total: 999 });
  expect(await repo.findById(id)).toMatchObject({ total: 999 });
});
```

```java
// JUnit 5 + Testcontainers (Spring Boot)
@Testcontainers
@SpringBootTest
class OrderRepositoryTest {
  @Container static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16");
  @DynamicPropertySource static void props(DynamicPropertyRegistry r) {
    r.add("spring.datasource.url", pg::getJdbcUrl);
    r.add("spring.datasource.username", pg::getUsername);
    r.add("spring.datasource.password", pg::getPassword);
  }
  // ...
}
```

Isolation between tests: wrap each test in a transaction and roll back, or `TRUNCATE` between tests. Run migrations against the container so schema drift is caught. Per-stack setup, parallel-safe schemas, and fixtures: [references/integration-testcontainers.md](references/integration-testcontainers.md).

## Test Data & Factories

- **Factories over fixtures** — build objects with sensible defaults and override only what the test cares about (`factory-boy`, `fishery`, Test Data Builders, `FactoryBot`).
- **One test owns its data** — don't share mutable rows across tests; that's the #1 cause of order-dependent flake.
- **Deterministic** — fixed seeds, injected clock; no `Date.now()`/`random()` leaking into assertions.

## Contract Testing

A unit test on each side can both pass while the API and its consumer disagree. Contract tests pin the shape of the wire.

- **Consumer-driven (Pact)** — the consumer records its expectations; the provider verifies it satisfies them in CI. Best for internal service-to-service.
- **Schema-based** — validate requests/responses against the OpenAPI spec; **Schemathesis** fuzzes from the spec to find 500s and contract violations. Best for public/REST APIs.

```ts
// Pact consumer expectation (Node)
provider.addInteraction({
  state: "order 42 exists",
  uponReceiving: "a request for order 42",
  withRequest: { method: "GET", path: "/orders/42" },
  willRespondWith: { status: 200, body: { id: 42, total: like(999) } },
});
```

Full Pact flow, provider verification, the broker, and Schemathesis: [references/contract-testing.md](references/contract-testing.md).

## Regression Tests for Security & Performance

The test suite is where security and performance findings become permanent guards:

- **Authz regressions** — User A cannot touch User B's object; non-admin can't hit admin routes (see [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md)).
- **N+1 guard** — assert the query count for a hot endpoint (see [be-performance](${CLAUDE_SKILL_DIR}/quality/be-performance/SKILL.md)).
- **Migration safety** — apply the migration against a seeded container; assert old + new code both work (expand/contract).

## Coverage & the QA Gate

Coverage is a floor, not a goal — 100% line coverage with no assertions proves nothing. Gate on **branch coverage** of business logic and require new code to be covered, not a global percentage that legacy code drags down.

```bash
# single scoped commands — no cd-chains
npm test                              # vitest/jest, with coverage thresholds in config
go test -race -cover ./...            # race detector + coverage
mvn verify                            # surefire/failsafe + jacoco gate
uv run pytest --cov --cov-fail-under=85
dotnet test --collect:"XPlat Code Coverage"
```

The backend **QA gate** = unit + integration pass **AND** the security scan is clean. Wire both as required CI checks. Evidence is cli-fallback: test output, coverage report, and (for integration) the container/migration logs — not screenshots (`requires_screenshots: false`).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Green unit tests, breaks against real DB | mocked the DB; missed constraints/tx | Use Testcontainers for the data layer | [integration-testcontainers](references/integration-testcontainers.md) |
| Tests pass alone, fail when run together | shared mutable data; ordering | Per-test data + transactional rollback | [integration-testcontainers](references/integration-testcontainers.md) |
| Flaky on time/UUID/order | nondeterminism | Inject clock/seed; sort before asserting | [testing-principles](${CLAUDE_SKILL_DIR}/_shared/testing-principles.md) |
| Consumer broke after a "safe" change | no contract test | Add Pact / validate against OpenAPI | [contract-testing](references/contract-testing.md) |
| N+1 slipped into a hot path | no query-count assertion | Assert query count in an integration test | [be-performance](${CLAUDE_SKILL_DIR}/quality/be-performance/SKILL.md) |
| Coverage high, bugs still ship | line not branch coverage; weak asserts | Gate branch coverage of logic; assert behavior | this file, Coverage |

## Deep-Dive References

- [references/integration-testcontainers.md](references/integration-testcontainers.md) — Testcontainers per stack, transactional rollback vs truncate, parallel-safe schemas, factories, stubbing third-party HTTP
- [references/contract-testing.md](references/contract-testing.md) — Pact consumer/provider flow, the broker, OpenAPI schema validation, Schemathesis property-based fuzzing

## Related Skills

- [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md) — turn authz findings into negative regression tests
- [be-performance](${CLAUDE_SKILL_DIR}/quality/be-performance/SKILL.md) — load testing as a stage; query-count assertions for N+1
- [testing-principles](${CLAUDE_SKILL_DIR}/_shared/testing-principles.md) — AAA, naming, determinism, flake hygiene
- [be-test-generator](${CLAUDE_SKILL_DIR}/../) — the agent that generates and registers runnable suites
- [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md) — test framework/Testcontainers/runtime minimums
