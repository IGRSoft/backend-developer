---
name: be-performance
description: >-
  Back-end performance for web/service APIs: latency budgets (p95/p99), load
  testing with k6, finding and fixing N+1 and slow queries, connection-pool
  sizing, caching tiers, backpressure, and per-stack profiling. Use when an
  endpoint is slow or won't scale, when setting a latency/throughput budget,
  load-testing a service, tuning a database query, sizing a pool, or adding a
  cache.
---

# Back-end Performance

**Measure with percentiles, fix the hot path, and put a limit on everything**

## When to Use

Use this skill when:
- An endpoint is slow, latency spikes under load, or a service won't scale
- Setting a latency budget (p95/p99) or a throughput SLO for an API
- Load-testing before a launch or capacity change (k6)
- Diagnosing N+1 queries, slow queries, or a saturated connection pool
- Adding or sizing a cache, or designing backpressure for a dependency
- Profiling a service to find the real hot path

Routing: load-test scripting, thresholds, and CI gating →
[references/load-testing-k6.md](references/load-testing-k6.md);
database tuning, N+1 fixes per ORM, pooling, and caching →
[references/db-and-caching.md](references/db-and-caching.md).

## Measure in Percentiles, Not Averages

Averages hide the tail. A p50 of 40ms with a p99 of 2s means 1% of requests are terrible — often the requests that matter (large accounts, cold caches). Set budgets on percentiles.

| Metric | Meaning | Typical budget shape |
|--------|---------|----------------------|
| p50 | median experience | the "feels fast" number |
| p95 | most slow requests | the SLO most teams commit to |
| p99 | tail; worst 1% | watch for cache misses, lock contention, GC |
| error rate | failed / total | budget alongside latency (e.g. <0.1%) |
| throughput | req/s sustained | what the load test must prove |

Always pair a latency budget with a load level: "p95 < 200ms **at 500 rps**." A budget without a concurrency figure is meaningless.

## Load Testing with k6

```js
import http from "k6/http";
import { check } from "k6";

export const options = {
  scenarios: {
    steady: { executor: "constant-arrival-rate", rate: 500, timeUnit: "1s",
              duration: "2m", preAllocatedVUs: 100, maxVUs: 400 },
  },
  thresholds: {
    http_req_duration: ["p(95)<200", "p(99)<500"], // fails the run if breached
    http_req_failed: ["rate<0.001"],
  },
};

export default function () {
  const res = http.get(`${__ENV.BASE_URL}/api/orders?limit=20`);
  check(res, { "200": (r) => r.status === 200 });
}
```

```bash
k6 run --env BASE_URL=http://localhost:8080 load.js   # single scoped command
```

Use `constant-arrival-rate` (open model) to measure latency under a fixed request rate — it exposes queueing that a fixed-VU (closed) model hides. Thresholds make k6 a pass/fail CI gate. Full executors, ramping, and CI wiring: [references/load-testing-k6.md](references/load-testing-k6.md).

## N+1 and Slow Queries

The #1 back-end performance bug is the N+1 query: a list endpoint runs one query for the list, then one per row for a relation.

```ts
// BAD — N+1: one query for posts, then one per post for its author
const posts = await db.post.findMany();
for (const p of posts) p.author = await db.user.findUnique({ where: { id: p.authorId } });

// GOOD — single query with the relation eager-loaded
const posts = await db.post.findMany({ include: { author: true } });
```

Per ORM: Prisma `include`/`select`; TypeORM `relations`/`leftJoinAndSelect`; Hibernate `JOIN FETCH` / `@EntityGraph`; SQLAlchemy `selectinload`/`joinedload`; GORM `Preload`; EF Core `.Include()`. Detect N+1 in tests by asserting query counts, and in prod via OpenTelemetry spans. Indexing, `EXPLAIN ANALYZE`, and the full per-ORM table: [references/db-and-caching.md](references/db-and-caching.md).

## Connection Pools & Backpressure

A web app talks to the DB through a small pool. Too small → requests queue and p99 explodes while CPU sits idle; too large → the DB thrashes on `max_connections`. Size the pool to the DB's capacity, not the app's concurrency, and put a serverless connection pooler (PgBouncer) in front when many instances share one DB.

```text
Postgres max_connections = 100, 4 app instances
→ per-instance pool ≈ (100 - reserved) / 4 ≈ 20, not 100
```

**Backpressure**: when a dependency is slow, shed or queue load instead of piling up unbounded work. Set per-call timeouts, use a circuit breaker on flaky upstreams, and bound queues — a full queue should reject fast (`429`/`503`) rather than grow until OOM. Rate limiting (see [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md)) is backpressure at the edge.

## Caching Tiers

Cache from cheapest to most expensive to miss:

| Tier | Example | Watch for |
|------|---------|-----------|
| In-process | LRU map, `lru-cache`, Caffeine | per-instance; not shared; bounded size |
| Distributed | Redis/Memcached | network hop; invalidation; stampede |
| HTTP/CDN | `Cache-Control`, ETag, CDN | only for cacheable GETs; vary on auth |
| DB-level | materialized views, query cache | refresh strategy |

Default pattern is **cache-aside**: read cache → on miss, read DB and populate → return. Always set a TTL, bound the size, and guard against **stampede** (a hot key expiring under load causing a thundering herd) with a short lock or `stale-while-revalidate`. Cache invalidation correctness beats hit rate — a wrong cached value is worse than a slow one. Details and write-through/write-behind: [references/db-and-caching.md](references/db-and-caching.md).

## Profiling per Stack

Profile the running service under representative load — don't guess.

| Stack | CPU / alloc profiler | Notes |
|-------|----------------------|-------|
| Node | `--prof` / `clinic` / `0x` flamegraphs | event-loop lag is the key signal |
| Go | `net/http/pprof` (`go tool pprof`) | built-in CPU, heap, block, mutex profiles |
| JVM | async-profiler, JFR | allocation + lock profiling; GC logs |
| Python | `py-spy` (sampling, no code change) | async: watch for blocking calls in the loop |
| .NET | `dotnet-trace` / `dotnet-counters` | EventPipe; GC and threadpool counters |
| Ruby | `stackprof`, `rbspy` | GVL contention |

Quick HTTP smoke benchmarks (`autocannon`, `wrk`) tell you throughput; profilers tell you *why*. For deep flamegraph and trace analysis, route to the [be-performance-engineer](${CLAUDE_SKILL_DIR}/../) review agent, or hand language-level profiling to system-developer for native extensions.

## Diagnostics

| Symptom | Likely cause | Fix | Reference |
|---------|--------------|-----|-----------|
| One request → hundreds of queries | N+1 / lazy relation | Eager-load (`include`/`JOIN FETCH`/`selectinload`) | [db-and-caching](references/db-and-caching.md) |
| Slow query, high DB CPU | missing index / seq scan | `EXPLAIN ANALYZE`; add the right index | [db-and-caching](references/db-and-caching.md) |
| Latency climbs under load, app CPU idle | pool exhausted; requests queue | Size pool to DB capacity; add PgBouncer | [db-and-caching](references/db-and-caching.md) |
| p99 ≫ p50 | cold cache / lock / GC pause | cache-aside + stampede guard; profile | [db-and-caching](references/db-and-caching.md) |
| Hot key expiry → traffic spike to DB | cache stampede | short lock or stale-while-revalidate | [db-and-caching](references/db-and-caching.md) |
| One slow upstream pins all workers | no timeout / backpressure | per-call timeout + circuit breaker + bounded queue | this file, Backpressure |
| Throughput plateaus below target | event-loop block / GVL / GC | profile the hot path under load | this file, Profiling |
| Load test shows great p50, terrible p99 | closed-model test hid queueing | re-run with `constant-arrival-rate` | [load-testing-k6](references/load-testing-k6.md) |

## Deep-Dive References

- [references/load-testing-k6.md](references/load-testing-k6.md) — k6 executors (constant/ramping arrival rate), thresholds as CI gates, parameterized scenarios, results analysis, when to use pgbench/autocannon
- [references/db-and-caching.md](references/db-and-caching.md) — `EXPLAIN ANALYZE` reading, indexing strategy, N+1 fixes per ORM, pool sizing math, PgBouncer, cache-aside/write-through, TTLs, stampede protection

## Related Skills

- [be-testing](${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md) — assert query counts to catch N+1 in CI; load tests as a test stage
- [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md) — rate limiting and resource caps are backpressure at the edge
- [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md) — timeouts and bounded resources are also a DoS defense
- [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md) — runtime/driver/pooler version minimums
