---
name: microservices-patterns
description: >-
  Microservices vs modular monolith — service boundaries from DDD bounded
  contexts, API gateway/BFF, service discovery, resilience (circuit breaker,
  retry, bulkhead, timeout), and data ownership per service. Use when
  decomposing a system, drawing service boundaries, hardening cross-service
  calls, or deciding whether to split a monolith at all.
---

# Microservices Patterns

**Draw boundaries from the domain, isolate failure, own your data — or stay a modular monolith**

## When to Use

Use this skill when:
- Deciding microservices vs a modular monolith for a new or existing system
- Drawing service boundaries from DDD bounded contexts (not from technical layers)
- Placing an API gateway or building a BFF for a client
- Choosing service discovery (DNS, registry, mesh) and resilience policies
- Hardening cross-service calls against partial failure (breaker/retry/bulkhead/timeout)
- Splitting a shared database into a database-per-service

Routing: detailed resilience tuning (breaker thresholds, retry budgets, deadline
propagation) → [references/resilience-patterns.md](references/resilience-patterns.md).
For the message-driven alternative to synchronous calls, see the
[event-driven](../event-driven/SKILL.md) sibling.

## Monolith First

| Job | Default | Do not reach for |
|-----|---------|------------------|
| New product, unproven boundaries | **Modular monolith** (modules = future services) | Microservices on day one |
| Independent deploy/scale per capability | Microservices | Splitting by technical layer (ui/api/db) |
| Team autonomy at scale | One service per team boundary | One service per noun/table |
| Cross-cutting transaction | Keep inside one service | Distributed transaction across services |

A modular monolith with clean module boundaries gives you most of the design
benefit (clear ownership, testable seams) without the operational tax of the
network, distributed transactions, and eventual consistency. Split a module out
only when an independent deploy cadence, isolation, or scaling profile demands
it. Version-gate runtime features (e.g. NestJS module boundaries, Spring Modulith
verification) against your toolchain — see skill: version-feature-matrix.

## Service Boundaries

Boundaries follow **DDD bounded contexts**: a context owns its ubiquitous
language, its data, and its invariants. Two contexts that disagree on what
"Order" means must not share a model or a table.

- One aggregate root's invariants live entirely inside one service — never split
  a consistency boundary across the network.
- Communicate across contexts with explicit contracts (events or APIs), never by
  reaching into another service's database.
- Name services after capabilities (`payments`, `inventory`), not entities
  (`order-table-service`).

```typescript
// NestJS — a bounded context exposes a contract, hides its model
// payments/payments.controller.ts
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  // Public contract: stable DTO, not the internal Payment entity
  @Post()
  async charge(@Body() dto: ChargeRequestDto): Promise<ChargeResponseDto> {
    const result = await this.payments.charge(dto.orderId, dto.amountCents);
    return { paymentId: result.id, status: result.status }; // no internal fields leak
  }
}
```

## Edge & Discovery

| Concern | Pattern | Notes |
|---------|---------|-------|
| Single client entry point | API gateway | Routing, authn, rate limiting, TLS termination |
| Client-shaped aggregation | BFF (one per client type) | Mobile BFF differs from web BFF; avoid one god-gateway |
| Locating instances | DNS / registry / service mesh | Mesh (Istio/Linkerd) adds mTLS + retries out-of-process |
| North-south auth | Validate JWT/OIDC at the gateway | Propagate a trimmed identity claim inward |

Terminate cross-cutting concerns (authn, rate limiting, TLS) at the edge; keep
business logic out of the gateway. A BFF is a service you own, not config — it
composes downstream calls into one client-shaped response and is the natural
place to apply per-client backpressure.

## Resilience

Every synchronous cross-service call is a potential cascading failure. Combine
four policies; never ship a bare network call.

| Policy | Stops | Default starting point |
|--------|-------|------------------------|
| Timeout | Unbounded waits | Per-call deadline well under the caller's own |
| Retry (bounded, jittered) | Transient blips | Max 2–3 attempts, exponential backoff + jitter, only idempotent ops |
| Circuit breaker | Hammering a dead dependency | Open after error-rate threshold; half-open probe |
| Bulkhead | One slow dependency exhausting all threads/connections | Separate connection pool per downstream |

```go
// Go — bounded retry with context deadline + jitter, idempotent calls only
func callWithRetry(ctx context.Context, do func(context.Context) error) error {
    const maxAttempts = 3
    var err error
    for attempt := 0; attempt < maxAttempts; attempt++ {
        // Per-call deadline below the caller's overall budget
        callCtx, cancel := context.WithTimeout(ctx, 800*time.Millisecond)
        err = do(callCtx)
        cancel()
        if err == nil || !isRetryable(err) {
            return err
        }
        if ctx.Err() != nil { // overall deadline blown — stop retrying
            return ctx.Err()
        }
        backoff := time.Duration(1<<attempt) * 100 * time.Millisecond
        jitter := time.Duration(rand.Int63n(int64(backoff / 2)))
        time.Sleep(backoff + jitter)
    }
    return err
}
```

Retries must target **idempotent** operations only; pair non-idempotent calls
with an idempotency key (see [event-driven](../event-driven/SKILL.md) >
Idempotent Consumers). Full tuning — breaker state thresholds, retry budgets,
deadline propagation across hops, bulkhead sizing —
[references/resilience-patterns.md](references/resilience-patterns.md).

## Data Ownership

**Database per service.** A service owns its schema; no other service reads or
writes it directly.

- No shared tables, no cross-service joins, no foreign keys across boundaries.
- Need another service's data on the read path? Replicate via events into a local
  read model, or call its API — never query its DB.
- A write that spans services is a **saga**, not a distributed transaction — see
  [saga-orchestration](../saga-orchestration/SKILL.md).
- Atomic "update my state + tell the world" → transactional outbox in
  [event-driven](../event-driven/SKILL.md) > Transactional Outbox.

```sql
-- Anti-pattern: orders service reaching into payments' table
SELECT o.*, p.status            -- ❌ cross-service join couples schemas
FROM orders.orders o
JOIN payments.payments p ON p.order_id = o.id;

-- Pattern: orders keeps a local, event-fed copy of the payment status
SELECT o.*, o.payment_status    -- ✅ local read model, updated by PaymentSettled events
FROM orders.orders o;
```

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| One slow dependency stalls the whole service | Shared connection/thread pool | Bulkhead: per-downstream pool | [resilience-patterns.md](references/resilience-patterns.md) § bulkhead |
| Retry storm amplifies an outage | Unbounded/uncoordinated retries | Retry budget + jitter + circuit breaker | [resilience-patterns.md](references/resilience-patterns.md) § retry-budget |
| Deploys of service A break service B | Shared DB / shared model | Database per service, contract via API/events | this file, Data Ownership |
| Timeouts pile up downstream after the caller gave up | No deadline propagation | Pass remaining deadline on each hop | [resilience-patterns.md](references/resilience-patterns.md) § deadlines |
| "Microservices" but every change touches three repos | Boundaries split a single context | Re-draw on bounded contexts; consider merging | this file, Service Boundaries |
| Need a distributed transaction | Write spans services | Use a saga + compensation | [saga-orchestration](../saga-orchestration/SKILL.md) |
| Gateway became a business-logic monolith | Logic crept into the edge | Move logic to services; keep edge cross-cutting only | this file, Edge & Discovery |

## Deep-Dive References

- [references/resilience-patterns.md](references/resilience-patterns.md) —
  circuit-breaker state machine and thresholds, retry budgets and jitter
  strategies, bulkhead sizing, the timeout/deadline hierarchy and deadline
  propagation across hops, load-shedding and backpressure

## Related Skills

- [event-driven](../event-driven/SKILL.md) — async messaging as the alternative to synchronous coupling
- [saga-orchestration](../saga-orchestration/SKILL.md) — distributed transactions across service boundaries
- [cqrs-event-sourcing](../cqrs-event-sourcing/SKILL.md) — local read models fed from other services' events
- [secure-coding](../../_shared/secure-coding/SKILL.md) — auth boundaries and injection-safe handling at edges
- [api-security](../../quality/api-security/SKILL.md) — OWASP API Top 10 controls at gateway and service edges
- [be-testing](../../quality/be-testing/SKILL.md) — integration tests with Testcontainers across services
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — framework/runtime feature minimums
