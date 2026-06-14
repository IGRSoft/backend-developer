---
name: observability
description: >-
  Instrument a back-end so you can explain its behavior: structured logging
  with correlation IDs, OpenTelemetry traces (spans, context propagation),
  metrics (RED/USE), exemplars, and log/trace/metric correlation. Use when
  adding logs, traces, or metrics, or when an outage is invisible because
  the three signals don't tie together.
---

# Observability

**Emit three correlated signals — logs, traces, metrics — that share IDs so one incident is one investigation.**

## When to Use

Use this skill when you need to:

- Replace `console.log`/`printf` debugging with structured, queryable logs.
- Tie a log line to the request, the trace span, and the metric that spiked.
- Trace a request across services (HTTP, gRPC, queues) to find the slow hop.
- Pick *which* metrics to emit (RED for services, USE for resources).
- Make dashboards that explain an outage instead of just showing it broke.

Skip if you already have the signals and just need to *read* them to fix something — that is [be-diagnostics](../be-diagnostics/SKILL.md).

## The Three Signals (and what each answers)

| Signal | Answers | Cardinality | Primary tool |
|--------|---------|-------------|--------------|
| **Logs** | "What exactly happened in *this* request?" | high (per event) | structured logger → log backend |
| **Traces** | "Where did the time go across services?" | high (per request) | OpenTelemetry → Jaeger/Tempo |
| **Metrics** | "Is the system healthy in aggregate, over time?" | low (aggregated) | OpenTelemetry/Prometheus |

The win is **correlation**: every log line, span, and metric exemplar carries the same `trace_id`, so from a spiking p99 you jump to an exemplar trace, then to its logs — one investigation, not three.

## Correlation IDs (do this first)

```ts
// Express middleware: accept or mint a correlation/trace id, attach to every log
import { randomUUID } from 'crypto';
app.use((req, res, next) => {
  req.id = req.header('x-request-id') ?? randomUUID();
  res.setHeader('x-request-id', req.id);
  req.log = logger.child({ correlation_id: req.id, route: req.path });
  next();
});
```

Rules:

- **Accept an inbound ID** (`x-request-id` / W3C `traceparent`) if present; otherwise mint one. Propagate it to every downstream call and log line.
- Use a **context-local** mechanism so you don't thread the ID through every function: AsyncLocalStorage (Node), `context.Context` (Go), MDC (JVM/SLF4J), `contextvars` (Python), `AsyncLocal` (.NET).
- When you adopt OpenTelemetry, prefer the **W3C `trace_id`/`span_id`** as the correlation key so logs and traces join automatically.

## Structured Logging Quickstart

```ts
// Node — pino: JSON logs to stdout, child logger carries request context
import pino from 'pino';
const logger = pino({ level: 'info' });
req.log.info({ user_id, order_id, latency_ms }, 'order created');
```

```go
// Go — slog: structured key/value logging to stdout
slog.InfoContext(ctx, "order created",
    "user_id", userID, "order_id", orderID, "latency_ms", ms)
```

```python
# Python — structlog: bind context once, log JSON
log = structlog.get_logger().bind(correlation_id=cid, route=route)
log.info("order_created", user_id=uid, order_id=oid, latency_ms=ms)
```

Doctrine:

- **JSON to stdout.** Let the platform collect it (12-factor). Don't write log files inside the container.
- **One event per line, key/value fields** — never string-concatenate values into the message; you can't query that.
- **Levels mean something:** `error` = needs attention, `warn` = degraded but handled, `info` = business events, `debug` = off in prod.
- **Never log secrets or PII** — tokens, passwords, full card/PII numbers. Redact at the logger. This is an **API8 / secrets-hygiene** boundary ([api-security](../../quality/api-security/SKILL.md)).

Per-runtime loggers and context propagation in depth: [logging-tracing.md](references/logging-tracing.md).

## Tracing Quickstart (OpenTelemetry)

```ts
// Node — auto-instrument HTTP/DB, then add a manual span for business logic
import { trace } from '@opentelemetry/api';
const tracer = trace.getTracer('orders');
await tracer.startActiveSpan('charge-card', async (span) => {
  span.setAttribute('order.id', orderId);
  try { await payments.charge(orderId); }
  catch (e) { span.recordException(e); span.setStatus({ code: 2 }); throw e; }
  finally { span.end(); }
});
```

- **Auto-instrumentation first** (HTTP server/client, DB drivers, gRPC, queues) gives you the request waterfall for free; add **manual spans** only for meaningful business steps.
- **Context propagation** across services uses the W3C `traceparent` header (HTTP) / metadata (gRPC) / message headers (Kafka/RabbitMQ) — the OTel SDK injects/extracts it; don't hand-roll it.
- Export via **OTLP to the OpenTelemetry Collector**, which fans out to Jaeger/Tempo/your vendor. Sample at the Collector (tail sampling keeps slow/error traces).

## Metrics Quickstart (RED / USE)

- **RED — for every request-serving service:** **R**ate (requests/sec), **E**rrors (failed/sec or %), **D**uration (latency histogram). This is what you alert on.
- **USE — for every resource (DB pool, CPU, queue):** **U**tilization, **S**aturation, **E**rrors. This is what explains *why* RED went bad.

```go
// Go — a latency histogram + an error counter (OTel metrics)
hist, _ := meter.Float64Histogram("http.server.duration", metric.WithUnit("ms"))
errs, _ := meter.Int64Counter("http.server.errors")
hist.Record(ctx, ms, metric.WithAttributes(attribute.String("route", route)))
if failed { errs.Add(ctx, 1, metric.WithAttributes(attribute.String("route", route))) }
```

- Use a **histogram** for duration (so you get p50/p95/p99), not a gauge of the last value.
- **Keep label cardinality low** — never put user IDs, request IDs, or raw URLs in metric labels; that explodes the time-series database. High-cardinality identity belongs in logs/traces.
- **Exemplars** attach a sample `trace_id` to a histogram bucket — click the p99 spike, jump to a representative slow trace. This is the metric→trace bridge.

Instrument naming, histogram buckets, exemplars, and Prometheus/OTLP export: [metrics-red-use.md](references/metrics-red-use.md).

## Putting It Together (one incident, one path)

1. A **RED** alert fires: p99 on `POST /orders` crossed the SLO.
2. The dashboard panel has **exemplars** → click the spike → open the slow **trace**.
3. The trace waterfall shows the slow span (e.g. a DB call) and carries `trace_id`.
4. Filter **logs** by that `trace_id` → see the exact query, params, and error.
5. From there it's a diagnosis: [be-diagnostics](../be-diagnostics/SKILL.md) (EXPLAIN, profiler).

If any link is missing (no exemplar, no shared `trace_id`, unstructured logs), you fall back to searching three systems separately. Fixing those links *is* the observability work.

## Version & Fallbacks

OpenTelemetry signal stability differs per language and version — traces and metrics are stable in most SDKs; the **logs** SDK/bridge is newer, so confirm with the version-feature-matrix (skill: version-feature-matrix) and each SDK's status page. Fallbacks: if the OTel logs bridge isn't stable in your runtime, emit JSON logs with the `trace_id`/`span_id` fields manually (correlation still works); if you can't run a Collector, export OTLP straight to a backend and sample in-process.

## Related Skills

- [logging-tracing.md](references/logging-tracing.md) — per-runtime structured loggers, correlation/trace IDs, OTel spans, context propagation across HTTP/gRPC/queues
- [metrics-red-use.md](references/metrics-red-use.md) — RED/USE method, instrument naming, histograms + exemplars, Prometheus/OTLP export, alerting
- [be-diagnostics](../be-diagnostics/SKILL.md) — reading these signals to find and fix a symptom
- [containerization](../containerization/SKILL.md) — log to stdout, expose/export OTLP from the container
- [api-security](../../quality/api-security/SKILL.md) — never log secrets/PII; audit-log auth decisions safely
- [be-testing](../../quality/be-testing/SKILL.md) — assert on emitted spans/metrics in tests
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — OTel SDK signal stability per language
