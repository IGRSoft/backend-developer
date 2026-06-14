# Resilience Patterns (deep dive)

Detailed tuning for the four resilience policies summarized in
[../SKILL.md](../SKILL.md) > Resilience. Every synchronous cross-service call
needs a timeout, a bounded retry, a circuit breaker, and a bulkhead.
Version-gate library-specific knobs (resilience4j, Polly, opossum, gobreaker)
against your toolchain — see skill: version-feature-matrix.

## Timeout & Deadline Hierarchy

A timeout that is larger than the caller's own budget is useless — the caller has
already given up. Build a **deadline hierarchy**: the inbound request carries an
overall budget, and each downstream hop gets a strictly smaller slice.

```
inbound request budget ............ 2000ms
├── auth check ...................... 150ms
├── inventory call ................. 600ms  (per-call timeout)
└── payments call ................. 800ms  (per-call timeout)
    └── payments → fraud call ...... 300ms  (must fit inside 800ms)
```

§ deadlines — **deadline propagation**: pass the remaining time on each hop so a
downstream service never starts work the caller will discard. In gRPC the
deadline propagates automatically; over HTTP, send it explicitly.

```go
// Compute remaining budget and pass it downstream as a header
func remaining(ctx context.Context) time.Duration {
    dl, ok := ctx.Deadline()
    if !ok {
        return 0
    }
    return time.Until(dl)
}

req.Header.Set("X-Request-Deadline-Ms",
    strconv.FormatInt(remaining(ctx).Milliseconds(), 10))
```

Downstream services should **shed** a request whose propagated deadline has
already elapsed (return 504 immediately) rather than starting doomed work.

## Retry Budget & Jitter

§ retry-budget — Per-call retry counts are not enough: under a partial outage,
every caller retrying independently produces a **retry storm** that amplifies the
failure. Cap retries as a *fraction of overall traffic* (e.g. ≤10% of requests
may be retries), not just per call.

| Knob | Bad | Good |
|------|-----|------|
| Backoff | Fixed delay | Exponential + full jitter |
| Attempts | Unlimited | 2–3 max |
| Scope | Every error | Only transient (timeout, 503, connection reset) |
| Idempotency | Retry any op | Retry idempotent ops, or pair with an idempotency key |
| Budget | Per call only | Per call **and** per-client traffic fraction |

```typescript
// Full-jitter exponential backoff (AWS architecture blog formula)
function backoffMs(attempt: number, baseMs = 100, capMs = 2000): number {
  const exp = Math.min(capMs, baseMs * 2 ** attempt);
  return Math.floor(Math.random() * exp); // full jitter: [0, exp)
}
```

Only retry idempotent operations. For a non-idempotent write, attach an
idempotency key and let the server dedup (see
[../../event-driven/SKILL.md](../../event-driven/SKILL.md) > Idempotent Consumers).

## Circuit Breaker State Machine

A breaker stops a caller from hammering a dependency that is already down,
letting it recover and failing fast in the meantime.

```
        error rate ≥ threshold
 CLOSED ───────────────────────────▶ OPEN
   ▲                                   │  cooldown elapsed
   │ probe succeeds                    ▼
   └──────────────── HALF-OPEN ◀───────┘
            probe fails
```

| State | Behavior |
|-------|----------|
| Closed | Calls pass; track rolling error rate over a sliding window |
| Open | Calls fail fast (no network); start a cooldown timer |
| Half-open | Allow a few probe calls; success → closed, failure → open |

Tune on a **rolling window** (count- or time-based), not lifetime totals: e.g.
open when ≥50% of the last 20 calls failed, cooldown 10s, half-open allows 3
probes. Surface breaker state as a metric and alert on sustained `OPEN`.

```java
// resilience4j circuit breaker config (Spring Boot)
CircuitBreakerConfig config = CircuitBreakerConfig.custom()
    .slidingWindowType(SlidingWindowType.COUNT_BASED)
    .slidingWindowSize(20)
    .failureRateThreshold(50.0f)          // open at 50% errors
    .waitDurationInOpenState(Duration.ofSeconds(10))
    .permittedNumberOfCallsInHalfOpenState(3)
    .build();
```

## Bulkhead Isolation

§ bulkhead — One slow dependency must not exhaust the resources the whole service
shares. Give each downstream its **own** connection pool / concurrency limit so a
stall is contained.

| Resource | Without bulkhead | With bulkhead |
|----------|------------------|---------------|
| HTTP client connections | One global pool drained by the slow dep | Per-downstream pool, capped concurrency |
| Worker threads | All blocked on the slow call | Bounded semaphore per dependency |
| DB connections | App and a background job share one pool | Separate pools, sized to each workload |

Size each bulkhead to that dependency's normal concurrency plus headroom; when it
saturates, **shed** (fail fast / queue with a bounded length) rather than block
indefinitely. Combine with the circuit breaker so a saturated bulkhead trips the
breaker rather than silently degrading.

## Load Shedding & Backpressure

When inbound load exceeds capacity, shed early at the edge (return 429/503 with
`Retry-After`) rather than accepting work that will time out. Bounded queues with
explicit rejection give you backpressure; unbounded queues just convert a latency
problem into a memory-exhaustion crash. Prioritize: shed low-value traffic
(retries, non-critical reads) before user-facing writes.

## Observability Hooks

Emit metrics for every policy so you can tune from data, not guesswork:
- Timeout rate and p99 latency per downstream
- Retry count and retry-success ratio
- Breaker state transitions and time-in-open
- Bulkhead saturation (queue depth / rejected count)

Propagate a trace context across hops (OpenTelemetry) so a shed or tripped call
is visible end-to-end. See [../../../quality/be-testing/SKILL.md](../../../quality/be-testing/SKILL.md)
for fault-injection integration tests (Testcontainers + toxiproxy) that exercise
these policies before production does.
