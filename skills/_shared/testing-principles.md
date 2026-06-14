---
name: testing-principles
description: Test pyramid, per-stack framework matrix, contract testing, coverage thresholds, and testing best practices for Node.js, Go, JVM, Python, Ruby, PHP, and .NET back-ends
---

# Testing Principles Reference

Shared testing patterns, framework selection, coverage requirements, and quality gates for backend work.

## Test Pyramid

```
         /\
        /  \      Load Tests (k6, Gatling) — capacity & tail latency
       /────\     E2E Tests (5-10%) — full service over HTTP, critical flows
      /      \
     /────────\   Contract Tests — provider/consumer schema agreement
    /          \  Integration Tests (20-30%) — DB, cache, broker via Testcontainers
   /────────────\ Unit Tests (60-70%) — handlers, services, repositories in isolation
  /              \
```

Contract tests sit between integration and E2E: they pin the request/response
schema both sides depend on without standing up the whole topology.

## Framework Matrix

Detect the existing framework first — never introduce a second framework into a project that already has one.

| Stack | Unit framework | HTTP / API test | Integration (real deps) | Coverage tool | Focused run |
|-------|----------------|-----------------|-------------------------|---------------|-------------|
| Node.js / TS | Vitest, Jest | supertest | Testcontainers | c8 / `--coverage` | `vitest -t <name>` / `jest -t <name>` |
| Go | `testing` + testify | `httptest` | dockertest / testcontainers-go | `go test -cover` | `go test -run <regex>` |
| JVM (Spring) | JUnit 5 | RestAssured / MockMvc / WebTestClient | Testcontainers | JaCoCo | `mvn test -Dtest=<name>` |
| Python (FastAPI/Django) | pytest | httpx / `TestClient` | testcontainers-python | coverage.py (`pytest --cov`) | `pytest -k <expr>` |
| Ruby (Rails) | RSpec / Minitest | `rack-test` / request specs | database_cleaner + real PG | SimpleCov | `rspec -e <expr>` |
| PHP (Laravel/Symfony) | PHPUnit / Pest | `TestCase` HTTP helpers | Testcontainers / docker | Xdebug / PCOV | `phpunit --filter <name>` |
| .NET (ASP.NET Core) | xUnit / NUnit | `WebApplicationFactory` | Testcontainers .NET | coverlet | `dotnet test --filter <name>` |

Registration is part of test generation: file discovery (Vitest/Jest globs, `*_test.go`,
`@Test`, pytest `test_*`, `*_spec.rb`, `*Test.php`, `[Fact]`). A test that the runner
does not discover does not exist.

## Contract Testing

| Approach | Use when | Tooling |
|----------|----------|---------|
| Consumer-driven contracts | Multiple consumers of an internal service | Pact (broker-mediated provider verification) |
| Schema/snapshot contracts | Public REST/GraphQL surface | OpenAPI / JSON Schema validation, GraphQL schema diff |
| gRPC contract | Proto-defined services | buf breaking-change detection against the registry |

Run provider verification in CI against the latest published consumer contracts;
a breaking change to a published schema is a P0 (see `severity-matrix.md`).

## Coverage Targets

| Scope | Minimum | Target | Notes |
|-------|---------|--------|-------|
| Critical logic | 90% | 95%+ | Auth, payments, repositories, data integrity |
| Core application code | 75% | 80%+ | Services, use-cases, domain rules |
| Utilities and helpers | 60% | 70%+ | Shared functions |
| HTTP handlers / glue / config | 50% | 60%+ | Routing, serialization, env wiring |
| Generated/config code | N/A | N/A | Excluded from coverage |

## Test Types

| Type | Purpose | Scope | Speed |
|------|---------|-------|-------|
| Unit | Verify isolated logic | Single function/service/repository | <100ms |
| Integration | Verify interactions with real deps | DB, cache, broker via Testcontainers | <2s |
| Contract | Pin provider/consumer schema | API boundary | <1s |
| E2E | Verify user journeys | Full service over HTTP | <30s |
| Load | Verify throughput / tail latency | Critical endpoints (k6, Gatling) | Varies |

Integration tests against ephemeral containers (Postgres, Redis, Kafka) are
first-class for backend work — prefer them over mocking the database.

## Testing Best Practices

### Naming Convention

```
test_[unit]_[scenario]_[expected]
test_create_order_insufficient_stock_returns_409
test_get_user_other_tenant_id_returns_404
```

### AAA Pattern

```python
def test_create_order_insufficient_stock_returns_409(client):
    # Arrange: seed product with zero stock
    seed_product(sku="X1", stock=0)

    # Act
    resp = client.post("/orders", json={"sku": "X1", "qty": 1})

    # Assert
    assert resp.status_code == 409
```

```go
func TestGetUser_OtherTenant_Returns404(t *testing.T) {
    srv := newTestServer(t)                              // Arrange
    resp := srv.GET("/users/42", withTenant("other"))    // Act
    require.Equal(t, http.StatusNotFound, resp.Code)     // Assert
}
```

### Test Independence

- Each test runs in isolation — no shared mutable state, no ordering assumptions
- Per-test setup/teardown; wrap DB work in a transaction rollback or truncate between tests
- Hermetic by default: ephemeral containers, no shared staging DB, no real network egress
- Deterministic: inject a fixed clock and seeded IDs; no `sleep` as synchronization — poll/await instead

## Quality Gates

| Gate | Threshold | Action on Failure |
|------|-----------|-------------------|
| Coverage | >80% new code | Block merge |
| Unit + integration tests | All pass | Block merge |
| Security scan (npm audit / osv-scanner / govulncheck / trivy) | 0 high/critical | Block merge (QA gate) |
| Contract verification | No breaking schema change unversioned | Block merge |
| Flaky tests | <1% flakiness | Investigation |
| Test duration | <10 min total | Optimization |

## Anti-Patterns to Avoid

- Testing implementation details instead of observable behavior (assert the response/DB state, not internal calls)
- Excessive mocking (mock the boundary — third-party HTTP, clock, message broker — not your own repositories; use Testcontainers for the DB)
- Flaky tests (real time, shared staging DB, network egress, ordering dependence)
- Tests that assert nothing or merely re-encode the handler logic
- Copy-paste cases instead of table-driven / parameterized tests (`t.Run` rows, `@pytest.mark.parametrize`, `[Theory]`)
- Missing edge cases: empty body, oversized payload, duplicate idempotency key, expired token, concurrent writes, pagination boundaries
- Testing third-party libraries or the framework

## Related Skills

- `severity-matrix.md` — coverage requirements and finding priorities
- `workflow-integration/SKILL.md` — QA gate definition for worktask runs
- per-stack testing deep dives in each language developer's skill set
