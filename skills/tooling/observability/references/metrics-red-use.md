# Metrics: RED & USE Reference

Use this when:

- You are deciding *which* metrics to emit for a service or resource.
- You need to name instruments and pick histogram buckets.
- You want to jump from a metric spike to a representative trace (exemplars).
- You are setting up alerts on an SLO.

Skip if:

- You are wiring logs or traces — that is [logging-tracing.md](logging-tracing.md).
- You only need the three-signal overview. See [observability SKILL.md](../SKILL.md).

Jump to:

- RED (for services)
- USE (for resources)
- Instrument Types & Naming
- Histograms & Buckets
- Label Cardinality Rules
- Exemplars (metric → trace)
- Export (OTLP / Prometheus)
- Alerting on SLOs

---

## RED (for services)

For anything that serves requests, emit three things per route:

| Metric | What | Instrument |
|--------|------|------------|
| **Rate** | requests per second | counter (`http.server.requests`) |
| **Errors** | failed requests per second (or %) | counter, labeled by outcome |
| **Duration** | request latency distribution | **histogram** (`http.server.duration`) |

RED is what you put on the top of the dashboard and what you alert on. Derive rate and error-rate from counters; derive p50/p95/p99 from the duration histogram.

## USE (for resources)

For every constrained resource (DB connection pool, thread pool, CPU, memory, queue), emit:

| Metric | What |
|--------|------|
| **Utilization** | % of the resource busy (pool in-use / pool size) |
| **Saturation** | queued/waiting work (requests waiting for a connection) |
| **Errors** | resource-level failures (pool timeouts, rejections) |

USE explains *why* RED went bad: a latency spike (RED Duration) with a saturated DB pool (USE Saturation) points straight at pool exhaustion ([be-diagnostics db-diagnosis.md](../../be-diagnostics/references/db-diagnosis.md)).

## Instrument Types & Naming

| Need | OTel instrument |
|------|-----------------|
| Monotonic count (requests, errors, bytes) | **Counter** |
| Value that goes up and down (pool in-use, queue depth) | **UpDownCounter** / Gauge |
| Distribution (latency, payload size) | **Histogram** |
| Expensive-to-read current value (RAM, open FDs) | **Observable Gauge** (callback) |

Naming (OTel semantic conventions): lowercase dotted names with a unit, e.g. `http.server.request.duration` (s), `db.client.connection.count`, `messaging.process.duration`. Prefer the standard semantic-convention names so backends and dashboards understand them out of the box. The **HTTP and database** conventions are now **stable** (semconv 1.x) — older instrumentations used different names (e.g. `http.server.duration` in ms), so a migrating library may expose `OTEL_SEMCONV_STABILITY_OPT_IN` (`http`/`database`, or `…/dup` for a phased dual-emit). Pin which convention version your dashboards target.

## Histograms & Buckets

Use a histogram for latency so you can compute any percentile server-side. Pick buckets that bracket your SLO:

```go
hist, _ := meter.Float64Histogram("http.server.duration",
    metric.WithUnit("ms"),
    metric.WithExplicitBucketBoundaries(5, 10, 25, 50, 100, 250, 500, 1000, 2500))
```

Place tighter buckets around the SLO threshold (e.g. around 250ms) so the percentile near your alert line is accurate. Too few buckets → imprecise p99; too many → cardinality cost.

## Label Cardinality Rules

Cardinality = number of distinct label-value combinations = number of time series. It is the #1 way to blow up a metrics backend (and your bill).

- **Good labels** (bounded): `route` (templated, `/orders/{id}` not `/orders/123`), `method`, `status_code`, `outcome`, region.
- **Never as labels**: user IDs, order IDs, request IDs, raw URLs, emails, full SQL. These are unbounded — put them in **logs/traces** instead.
- Template the route *before* it becomes a label, or one URL per ID becomes one series per ID.

## Exemplars (metric → trace)

An exemplar attaches a sample `trace_id` to a specific histogram bucket observation. On the dashboard, the p99 spike shows clickable dots that open a representative slow trace.

```python
# Most OTel SDKs attach exemplars automatically when a span is active during Record.
hist.record(latency_ms, attributes={"route": route})  # exemplar = current trace_id
```

This is the bridge that turns "p99 is bad" into "here is the exact slow request" — wire it and you skip the manual hunt.

## Export (OTLP / Prometheus)

- **OTLP → Collector** (push): app exports OTLP; the Collector relabels, batches, and forwards to Prometheus/Tempo/your vendor. Preferred for a uniform pipeline alongside traces.
- **Prometheus scrape** (pull): expose `/metrics`; Prometheus scrapes it. Common in Kubernetes; the OTel Prometheus exporter or a native client serves it.
- **OTLP → Prometheus directly** (push): Prometheus 3.x is a native OTLP receiver (`/api/v1/otlp/v1/metrics`), so you can push OTLP straight in without a Collector hop. Prometheus 3.x also enabled **UTF-8** metric/label names by default, so OTel dotted names (`http.server.duration`) survive without the old dot-to-underscore mangling — the two ecosystems finally line up.

Keep one export path per signal and let the Collector fan out — don't double-export. Prefer **native histograms** (a single, high-resolution, lower-cost histogram type — stable in recent Prometheus 3.x) over fixed explicit buckets where your backend supports them; fall back to explicit-bucket histograms otherwise.

## Alerting on SLOs

Alert on **symptoms users feel**, derived from RED:

- **Availability**: error rate over a window crosses budget (e.g. `errors / requests > 1%` for 5m).
- **Latency**: p99 from the duration histogram crosses the SLO (e.g. `p99 > 300ms` for 5m).
- Prefer **multi-window burn-rate** alerts (fast + slow window) over a single threshold to cut flapping.

Don't page on USE metrics directly (high CPU isn't always bad) — use them to *explain* a RED alert, not to fire one. From an alert, follow the exemplar to a trace, then to logs ([logging-tracing.md](logging-tracing.md)), then to a fix ([be-diagnostics](../../be-diagnostics/SKILL.md)).
