# Logging & Tracing Reference

Use this when:

- You are wiring structured logging or tracing into a specific runtime.
- You need a correlation/trace ID available everywhere without threading it.
- You need a trace to follow a request across HTTP, gRPC, or a message queue.

Skip if:

- You are choosing/naming metrics — that is [metrics-red-use.md](metrics-red-use.md).
- You only need the three-signal overview. See [observability SKILL.md](../SKILL.md).

Jump to:

- Structured Loggers per Runtime
- Correlation IDs via Context-Locals
- OpenTelemetry Spans
- Context Propagation (HTTP / gRPC / Queues)
- The Collector & Sampling
- Log ↔ Trace Correlation

---

## Structured Loggers per Runtime

```ts
// Node — pino
import pino from 'pino';
export const logger = pino({ level: process.env.LOG_LEVEL ?? 'info',
  redact: ['req.headers.authorization', 'password', 'token'] });
```

```go
// Go — slog (stdlib), JSON handler to stdout
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
slog.SetDefault(logger)
```

```python
# Python — structlog, JSON renderer
structlog.configure(processors=[
    structlog.processors.add_log_level,
    structlog.contextvars.merge_contextvars,
    structlog.processors.TimeStamper(fmt="iso"),
    structlog.processors.JSONRenderer(),
])
```

```java
// JVM — SLF4J + Logback with a JSON encoder (logstash-logback-encoder); MDC for context
MDC.put("correlation_id", id);
log.info("order created", kv("order_id", orderId), kv("latency_ms", ms));
```

```csharp
// .NET — Serilog, structured properties to JSON
Log.Information("Order {OrderId} created in {LatencyMs}ms", orderId, ms);
```

Always log JSON to stdout, redact secrets/PII at the logger, and keep one event per line with typed fields (not interpolated strings).

## Correlation IDs via Context-Locals

The goal: set the ID once per request, read it in any function, without adding a parameter to every signature.

```ts
// Node — AsyncLocalStorage
import { AsyncLocalStorage } from 'async_hooks';
export const als = new AsyncLocalStorage<{ correlationId: string }>();
app.use((req, _res, next) => als.run({ correlationId: req.id }, next));
// anywhere downstream:
const cid = als.getStore()?.correlationId;
```

```go
// Go — context.Context carries it explicitly (idiomatic; pass ctx down)
ctx = context.WithValue(ctx, correlationKey{}, id)
slog.InfoContext(ctx, "...")   // a ContextHandler pulls the id into every line
```

```python
# Python — contextvars (works across async/await)
cid_var: ContextVar[str] = ContextVar("correlation_id")
cid_var.set(request_id)        # structlog merge_contextvars picks it up
```

JVM uses SLF4J **MDC** (thread-local; copy it across executor boundaries); .NET uses **`AsyncLocal<T>`** or logging scopes. Once you adopt OpenTelemetry, prefer the W3C `trace_id` as the correlation key so logs and traces join with no extra field.

## OpenTelemetry Spans

```python
# Python — auto-instrument the framework, add a manual span for business work
from opentelemetry import trace
tracer = trace.get_tracer("orders")
with tracer.start_as_current_span("reserve_inventory") as span:
    span.set_attribute("order.id", order_id)
    reserve(order_id)   # nested HTTP/DB calls become child spans automatically
```

```go
// Go
ctx, span := otel.Tracer("orders").Start(ctx, "reserve-inventory")
defer span.End()
span.SetAttributes(attribute.String("order.id", id))
```

Guidance: enable auto-instrumentation (HTTP, DB, gRPC, queue clients) for the free request waterfall; add manual spans only for meaningful steps. On error, `span.recordException(e)` and set the status to error so the trace is searchable by failure.

## Context Propagation (HTTP / gRPC / Queues)

The trace continues across process boundaries via the **W3C `traceparent`** header. The SDK injects it on outbound calls and extracts it on inbound — don't hand-roll it.

```ts
// HTTP: instrumented http/fetch clients inject `traceparent` automatically.
// Manual injection (rarely needed):
import { propagation, context } from '@opentelemetry/api';
const headers: Record<string,string> = {};
propagation.inject(context.active(), headers);   // adds traceparent
```

- **gRPC**: context travels in request metadata; the OTel gRPC instrumentation handles inject/extract.
- **Kafka / RabbitMQ / SQS**: the producer injects `traceparent` into **message headers**; the consumer extracts it to *link or continue* the trace. Without this, the async hop breaks the trace into two disconnected pieces.

```go
// Kafka producer — inject trace context into message headers
carrier := propagation.MapCarrier{}
otel.GetTextMapPropagator().Inject(ctx, carrier)
for k, v := range carrier { msg.Headers = append(msg.Headers, kafka.Header{Key: k, Value: []byte(v)}) }
```

## The Collector & Sampling

Export **OTLP → OpenTelemetry Collector**, which batches and fans out to Jaeger/Tempo/your vendor — so app code is backend-agnostic.

- **Head sampling** (decide at the start) is cheap but may drop the slow/error traces you want.
- **Tail sampling** (decide after the trace completes, in the Collector) keeps all errors and slow traces and samples the boring fast ones — the usual production choice.
- Always keep **100% of error traces**; sample successes.

## Log ↔ Trace Correlation

Put the active `trace_id`/`span_id` into every log line:

```ts
// Node — inject OTel ids into pino logs
import { trace } from '@opentelemetry/api';
const span = trace.getActiveSpan()?.spanContext();
req.log = logger.child({ trace_id: span?.traceId, span_id: span?.spanId });
```

Now: from a slow span in Jaeger you copy its `trace_id`, filter logs by it, and read the exact statements that ran. That join — span ↔ log via shared `trace_id` — is the entire payoff; everything above exists to make it reliable. Reading these signals to fix a symptom: [be-diagnostics](../SKILL.md). Never let secrets/PII into either signal ([api-security](../../quality/api-security/SKILL.md)).
