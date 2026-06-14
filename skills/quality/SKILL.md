---
name: quality-skills
description: >-
  Back-end quality skills navigation — API security (OWASP API Top 10),
  performance, and testing. Use when hardening API security, tuning
  performance, or building a test strategy.
---

# Quality Skills

**API security, performance, and testing for web/service back-ends**

Thin router. Pick a sub-skill from the tables below; the leaf skills teach.

## Skill Selection

| I need to... | Use this skill |
|--------------|----------------|
| Harden an API against OWASP API Top 10 (BOLA/BFLA, injection, SSRF), wire authn/authz, validate input | [api-security/SKILL.md](api-security/SKILL.md) |
| Hit a latency budget (p95/p99), kill N+1 and slow queries, size pools/caches, load-test | [be-performance/SKILL.md](be-performance/SKILL.md) |
| Build a test pyramid (unit/integration/contract/load), use Testcontainers, set coverage gates | [be-testing/SKILL.md](be-testing/SKILL.md) |
| Profile a slow endpoint or set a throughput baseline | [be-performance/SKILL.md](be-performance/SKILL.md) > Profiling |
| Write a contract test against a published schema (Pact/OpenAPI) | [be-testing/SKILL.md](be-testing/SKILL.md) > Contract testing |

## Symptom Router

Start here when you have a behavior, not a tool name.

| Symptom | Likely cause | Go to |
|---------|--------------|-------|
| User A can read user B's records by changing an `id` | BOLA / missing object-level authz (API1) | [api-security](api-security/SKILL.md) > BOLA & BFLA |
| Non-admin hits an admin route and it works | BFLA / missing function-level authz (API5) | [api-security](api-security/SKILL.md) > BOLA & BFLA |
| Outbound fetch reaches `169.254.169.254` / internal hosts | SSRF (API7) on a URL/webhook field | [api-security](api-security/SKILL.md) > SSRF |
| Endpoint falls over under a burst of requests | no rate limiting / resource caps (API4) | [api-security](api-security/SKILL.md) > Rate limiting |
| `' OR 1=1 --` or `$where` payload changes results | SQL/NoSQL/command injection | [api-security](api-security/SKILL.md) > Injection |
| One request fans out into hundreds of queries | N+1 / lazy-loaded relation | [be-performance](be-performance/SKILL.md) > N+1 & slow queries |
| Latency spikes under load, CPU low, requests queue | exhausted connection pool / backpressure | [be-performance](be-performance/SKILL.md) > Pools & backpressure |
| p99 far above p50; tail latency | cold cache, lock contention, GC pauses | [be-performance](be-performance/SKILL.md) > Latency budgets |
| Tests green locally, break against the real DB | mocked the boundary that should be integration-tested | [be-testing](be-testing/SKILL.md) > Mocking the boundary |
| Consumer breaks after a "non-breaking" API change | no contract test on the schema | [be-testing](be-testing/SKILL.md) > Contract testing |

## Tool Version Snapshot (verify against your stack)

Floors this plugin assumes. Library and runtime support shift between minor releases — confirm with `--version` and the [version-feature-matrix](../_shared/version-feature-matrix.md) before pinning in CI.

| Tool | Assumed floor | Why |
|------|---------------|-----|
| k6 | current stable | scriptable HTTP load tests; thresholds gate p95/p99 |
| OpenTelemetry SDK | 1.x (lang-specific) | traces/metrics/logs; OTLP export *(verify per lang)* |
| Testcontainers | current stable per lang | real Postgres/Redis/Kafka in integration tests |
| Pact | 4.x (spec v4) | consumer-driven contract testing |
| OWASP ZAP | current stable | DAST against a running API |
| osv-scanner / govulncheck / npm audit / trivy | current stable | dependency + image CVE scanning |
| pgbench / EXPLAIN (ANALYZE) | ships with Postgres 14+ | query plans + DB-level load baseline *(verify)* |
| autocannon / wrk | current stable | quick HTTP throughput smoke benchmarks |
| Schemathesis | current stable | property-based fuzzing from an OpenAPI schema |

## Decision Tree

```
Quality task?
├── "Is this endpoint exploitable / who can call it?" → api-security/SKILL.md
│   ├── Object/function authz (BOLA/BFLA, API1/3/5) → api-security/references/authz-bola-bfla.md
│   ├── Authentication (OAuth2/OIDC, JWT, sessions, API2) → api-security/references/authn-tokens.md
│   └── Injection · SSRF · rate limits · misconfig (API4/7/8) → api-security/references/injection-ssrf-ratelimit.md
├── "It's slow / won't scale" → be-performance/SKILL.md
│   ├── Load tests & latency budgets (k6, p95/p99) → be-performance/references/load-testing-k6.md
│   └── DB hot paths, N+1, pooling, caching tiers → be-performance/references/db-and-caching.md
└── "How do I test this?" → be-testing/SKILL.md
    ├── Integration with Testcontainers → be-testing/references/integration-testcontainers.md
    └── Contract testing (Pact / schema) → be-testing/references/contract-testing.md
```

## Conventions Across Quality Work

- **Evidence is API-shaped, not screenshots.** Non-UI back-end work defaults to `requires_screenshots: false`. When a gate is armed, cli-fallback evidence = request/response transcripts (`curl`/`httpie`), test output, k6 summaries, and migration logs.
- **Single-command Bash invocations.** Use `npm test`, `go test ./...`, `mvn verify`, `uv run pytest`, `k6 run script.js` — never `cd`-chains. Scoped Bash allowlists do not match compound commands.
- **Test against real backing services.** Prefer Testcontainers (real Postgres/Redis/Kafka) over hand-rolled mocks of the data boundary; mock only across network seams you do not own.
- **Authz is server-side and per-object.** Never trust client-supplied identity or scope. Every object access re-checks ownership; every privileged route re-checks role.

## Related Skills

- [api-security](api-security/SKILL.md) — OWASP API Top 10, authn/authz, injection, SSRF, rate limiting, secrets
- [be-performance](be-performance/SKILL.md) — load testing, latency budgets, N+1, pooling, caching, profiling
- [be-testing](be-testing/SKILL.md) — unit/integration/contract/load pyramid, Testcontainers, coverage gates
- [version-feature-matrix](../_shared/version-feature-matrix.md) — framework/runtime floors per stack
- [secure-coding](../_shared/secure-coding/SKILL.md) — input validation and injection defense belong in the code, not bolted on
- [workflow-integration](../_shared/workflow-integration/SKILL.md) — QA gate, DR review criteria, and the cli-fallback evidence norm
