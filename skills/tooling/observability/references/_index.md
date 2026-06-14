# Observability References Index

Deep-dive references for the [observability](../SKILL.md) skill. Start at the
SKILL.md three-signals overview; come here for per-runtime instrumentation and
full method/export tables.

## References

| File | Covers | Read when |
|------|--------|-----------|
| `logging-tracing.md` | Structured loggers per runtime (pino/slog/structlog/Logback/Serilog), correlation/trace IDs via context-locals, OpenTelemetry spans, W3C context propagation across HTTP/gRPC/Kafka/RabbitMQ, the Collector, sampling, log↔trace correlation | You are wiring logs or traces into a specific runtime |
| `metrics-red-use.md` | RED and USE methods, OTel/Prometheus instrument types and naming, histogram buckets, label-cardinality rules, exemplars (metric→trace), OTLP/Prometheus export, alerting on SLOs | You are choosing which metrics to emit and how to name/export them |

## Quick Links by Problem

- **Add structured logging to Node/Go/JVM/Python/.NET** → `logging-tracing.md` (per-runtime)
- **Thread a correlation ID without passing it everywhere** → `logging-tracing.md` (context-locals)
- **Trace a request across two services** → `logging-tracing.md` (context propagation)
- **Trace through a Kafka/RabbitMQ message** → `logging-tracing.md` (queue propagation)
- **Decide which metrics to emit** → `metrics-red-use.md` (RED vs USE)
- **Stop a cardinality explosion** → `metrics-red-use.md` (label rules)
- **Jump from a p99 spike to a trace** → `metrics-red-use.md` (exemplars)
- **Alert on an SLO** → `metrics-red-use.md` (alerting)
