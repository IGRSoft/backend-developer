# Load Testing with k6

k6 (now **Grafana k6**, GA at v1.0 since May 2025 with a stable scripting API) is a scriptable HTTP load tester. Tests are JavaScript; thresholds turn a run into a pass/fail CI gate. Run as a single scoped command — no `cd`-chains.

```bash
k6 run --env BASE_URL=https://api.example.com load.js
k6 run --out json=results.json load.js   # machine-readable evidence for a gate
```

## Open vs Closed Models — pick the right executor

A **closed model** (fixed number of virtual users, each waiting for its previous response) self-throttles: when the system slows, the test slows with it, hiding the queueing real users would experience. An **open model** (arrival rate) sends requests at a fixed pace regardless of response time — this exposes saturation and is what you want for latency SLOs.

| Executor | Model | Use for |
|----------|-------|---------|
| `constant-arrival-rate` | open | steady-state latency at a target rps |
| `ramping-arrival-rate` | open | find the breaking point (ramp rps up) |
| `constant-vus` | closed | simple concurrency soak |
| `ramping-vus` | closed | gradual concurrency ramp |
| `per-vu-iterations` | closed | fixed work per VU (data-driven) |

> The legacy `externally-controlled` executor was **removed in k6 1.x** — scripts that still set it will not run. For distributed/large-scale runs use the Grafana **k6 Operator** (`TestRun` CRD, v1.0 GA) on Kubernetes or Grafana Cloud k6 instead of externally scaling VUs.

```js
export const options = {
  scenarios: {
    find_the_knee: {
      executor: "ramping-arrival-rate",
      startRate: 50, timeUnit: "1s",
      preAllocatedVUs: 200, maxVUs: 1000,
      stages: [
        { target: 200, duration: "1m" },
        { target: 600, duration: "2m" },
        { target: 1200, duration: "2m" },
      ],
    },
  },
};
```

## Thresholds as a CI gate

```js
export const options = {
  thresholds: {
    http_req_duration: ["p(95)<200", "p(99)<500"],
    http_req_failed: ["rate<0.001"],
    "http_req_duration{endpoint:checkout}": ["p(95)<400"], // per-tag budget
    checks: ["rate>0.99"],
  },
};
```

If any threshold is breached, `k6 run` exits non-zero — wire it directly into the pipeline. Tag requests to set per-endpoint budgets:

```js
http.get(`${__ENV.BASE_URL}/checkout`, { tags: { endpoint: "checkout" } });
```

## Realistic scenarios

- **Parameterize data** with `SharedArray` so VUs don't all hit the same row (which would be cache-warmed and unrepresentative).
- **Authenticate** in `setup()` once, pass the token to the default function.
- **Think time** with `sleep()` for closed models simulating human pacing; omit it for raw throughput tests.
- **Correlate** — extract an id from one response and use it in the next (realistic flows, not just one endpoint).

```js
import { SharedArray } from "k6/data";
const users = new SharedArray("users", () => JSON.parse(open("./users.json")));
export function setup() {
  const r = http.post(`${__ENV.BASE_URL}/login`, /* creds */);
  return { token: r.json("access_token") };
}
export default function (data) {
  const u = users[Math.floor(Math.random() * users.length)];
  http.get(`${__ENV.BASE_URL}/users/${u.id}`, {
    headers: { Authorization: `Bearer ${data.token}` },
  });
}
```

## Reading results (evidence)

The end-of-run summary is the cli-fallback evidence for a performance gate:

- `http_req_duration` — `avg`, `p(90)`, `p(95)`, `p(99)`, `max`. Compare to budget.
- `http_req_failed` — error rate.
- `iterations` / `http_reqs` — total work and achieved rps (confirm you actually hit the target rate; if `dropped_iterations` is high, the system couldn't keep up).
- `vus` / `vus_max` — VU allocation (raise `maxVUs` if capped).

Capture the JSON summary in CI artifacts so regressions are diffable run-to-run.

## When k6 isn't the right tool

| Need | Tool |
|------|------|
| Quick local throughput smoke | `autocannon` (Node), `wrk` |
| DB-level load baseline (no app) | `pgbench` against Postgres |
| Property-based API fuzzing from schema | Schemathesis (see [be-testing](../../be-testing/references/contract-testing.md)) |
| Browser/real-user timing | not a back-end load test — out of scope |

## Where load tests live in the pipeline

- **PR smoke** — a short k6 run (30–60s) at a modest rate to catch gross regressions fast.
- **Nightly / pre-release** — full ramping-arrival-rate run to the knee, longer soak for memory leaks.
- Run against a production-like environment with realistic data volume; a load test on an empty DB lies (no slow queries, everything cache-fits).

Tool versions: skill [version-feature-matrix](../../../_shared/version-feature-matrix.md).

## Checklist

- [ ] Latency budget stated as percentile **at a request rate** (p95<200ms @ 500rps).
- [ ] Open model (`*-arrival-rate`) for latency SLOs; closed only for soak.
- [ ] Thresholds set so the run fails the build on breach.
- [ ] Data parameterized; auth done in `setup`; flows correlated.
- [ ] Run against production-like data volume, not an empty DB.
- [ ] JSON summary captured as CI evidence.
