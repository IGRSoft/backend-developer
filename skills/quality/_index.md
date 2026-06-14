# Quality Index

Quick navigation for API security, performance, and testing.

## Skills

| Path | Description |
|------|-------------|
| `SKILL.md` | Entry router: skill selection, symptom router, tool version snapshot, decision tree |
| `api-security/SKILL.md` | OWASP API Top 10 doctrine, authn/authz, injection/SSRF/rate-limiting, secrets, input validation |
| `api-security/references/authz-bola-bfla.md` | Object- and function-level authorization deep dive: BOLA (API1), BOPLA (API3), BFLA (API5), ownership checks, scopes/RBAC/ABAC |
| `api-security/references/authn-tokens.md` | OAuth2/OIDC flows, JWT validation pitfalls, session management, API keys, token storage and rotation |
| `api-security/references/injection-ssrf-ratelimit.md` | SQL/NoSQL/command injection, SSRF defense, rate limiting & resource caps, security misconfiguration, CORS |
| `be-performance/SKILL.md` | Latency budgets, load testing, N+1/slow queries, pooling, caching tiers, backpressure, per-stack profiling |
| `be-performance/references/load-testing-k6.md` | k6 scripts, thresholds, ramping/arrival-rate executors, p95/p99 gates, CI integration |
| `be-performance/references/db-and-caching.md` | EXPLAIN ANALYZE, indexing, N+1 fixes per ORM, pool sizing, cache-aside/write-through, stampede protection |
| `be-testing/SKILL.md` | Test pyramid, Testcontainers, contract testing, test data, mocking the boundary, coverage gates |
| `be-testing/references/integration-testcontainers.md` | Testcontainers per stack, transactional rollback, fixtures/factories, parallel-safe schemas |
| `be-testing/references/contract-testing.md` | Pact consumer-driven contracts, OpenAPI schema validation, Schemathesis fuzzing, provider verification |

## Quick Links by Problem

### "I need to..."

- **Stop BOLA / IDOR on an endpoint** → `api-security/SKILL.md`
- **Validate a JWT correctly** → `api-security/references/authn-tokens.md`
- **Add rate limiting** → `api-security/references/injection-ssrf-ratelimit.md`
- **Set a p95/p99 latency budget** → `be-performance/SKILL.md`
- **Fix an N+1 query** → `be-performance/references/db-and-caching.md`
- **Write an integration test with a real DB** → `be-testing/references/integration-testcontainers.md`
- **Add a consumer contract test** → `be-testing/references/contract-testing.md`

### "I'm seeing..."

- **User A reads user B's data by changing an `id`** → `api-security/references/authz-bola-bfla.md` (BOLA)
- **A non-admin reaching an admin route** → `api-security/references/authz-bola-bfla.md` (BFLA)
- **Outbound fetch hitting internal/metadata hosts** → `api-security/references/injection-ssrf-ratelimit.md` (SSRF)
- **One request firing hundreds of queries** → `be-performance/references/db-and-caching.md` (N+1)
- **Tail latency (p99) far above median** → `be-performance/SKILL.md` (latency budgets)
- **A consumer broken by a "safe" API change** → `be-testing/references/contract-testing.md`
