---
name: node-async-streams
description: >-
  Async correctness and streams in Node: promises/async-await without floating
  promises, AbortController/AbortSignal cancellation and timeouts, stream
  backpressure, Web Streams vs node:stream, and worker_threads for CPU-bound
  work. Use when handling concurrency, cancellation, timeouts, large payloads,
  or offloading CPU-bound work off the event loop.
---

# Node Async Correctness and Streams

**Await every promise, propagate cancellation, respect backpressure, keep the event loop free**

## When to Use

Use this skill when:
- A handler does concurrent I/O and you need it correct (no floating/unhandled rejections)
- You must cancel in-flight work (client disconnect, timeout, shutdown)
- You're moving large payloads (uploads, exports, proxying) and must not buffer them whole
- Choosing between `node:stream` and Web Streams, or bridging the two
- CPU-bound work (hashing, image/PDF, parsing) is blocking the event loop

Routing: stream plumbing (`pipeline`, Web↔Node interop, HTTP stream bodies) and
`worker_threads` pools → [references/streams-and-workers.md](references/streams-and-workers.md).

## No Floating Promises

An un-awaited promise is the #1 async footgun: its rejection becomes an unhandled
rejection, and its completion is unordered relative to the response. Treating
errors as values starts with *seeing* every async edge.

```ts
// bad — error lost, response may flush before the write lands
function handler(req, res) {
  audit.write(req.user.id);      // floating
  res.json(ok);
}
// good — awaited, errors propagate to the error handler
async function handler(req, res) {
  await audit.write(req.user.id);
  res.json(ok);
}
// deliberate background work: mark void AND attach a catch
void audit.write(id).catch((e) => logger.error({ err: e }));
```

Enforce with `@typescript-eslint/no-floating-promises` and `no-misused-promises`
(catches `async` fns passed where a sync `void` callback is expected, e.g. an
Express middleware). See [modern-typescript-backend/references/typescript-anti-patterns.md](../modern-typescript-backend/references/typescript-anti-patterns.md).

## Concurrency Primitives

| Goal | Use | Not |
|------|-----|-----|
| Run independent I/O in parallel, fail if any fails | `await Promise.all([...])` | sequential `await` in a loop |
| Run all, collect successes and failures | `await Promise.allSettled([...])` | `Promise.all` (short-circuits) |
| First to finish wins (with a timeout racer) | `await Promise.race([...])` | manual flags |
| Bounded parallelism over a large list | a pool (`p-limit`, or a worker pool) | `Promise.all(hugeArray.map(...))` |

```ts
// bad — N+1 hammering, unbounded concurrency
const users = await Promise.all(ids.map((id) => repo.byId(id)));   // fixes the loop...
// ...but for thousands of ids, bound it:
import pLimit from "p-limit";
const limit = pLimit(20);
const users = await Promise.all(ids.map((id) => limit(() => repo.byId(id))));
```

Sequential `await` inside a `for` loop is correct but serial — use `Promise.all`
for independent work, a bounded pool when the fan-out is large enough to exhaust
connections or memory.

## Cancellation: AbortController / AbortSignal

Propagate an `AbortSignal` through the call chain so a client disconnect, a
timeout, or shutdown stops in-flight work instead of leaking it.

```ts
async function handler(req, res) {
  const ac = new AbortController();
  res.on("close", () => ac.abort());                 // client gone -> cancel

  // built-in timeout signal, combined with the request signal
  const signal = AbortSignal.any([ac.signal, AbortSignal.timeout(5_000)]);

  try {
    const r = await fetch(upstream, { signal });     // fetch honors the signal
    res.json(await r.json());
  } catch (e) {
    if (e.name === "AbortError") return;             // expected on cancel/timeout
    throw e;
  }
}
```

`AbortSignal.timeout(ms)` (Node 17.3+) and `AbortSignal.any([...])` (Node 20+)
remove most hand-rolled timer code. Pass the signal to `fetch`, `pg`/driver
queries that support it, `fs` promises, and your own loops
(`signal.throwIfAborted()`). Version gates: skill: version-feature-matrix.

## Streams: Respect Backpressure

Never buffer a large body into memory. Stream it, and let backpressure throttle
the producer to the consumer's pace. Use `pipeline` — it wires backpressure
*and* propagates errors/cleanup across every stage (a bare `.pipe()` leaks on
error).

```ts
import { pipeline } from "node:stream/promises";
import { createReadStream, createWriteStream } from "node:fs";
import { createGzip } from "node:zlib";

// stream file -> gzip -> response; backpressure end-to-end, cleanup on error
await pipeline(
  createReadStream(path),
  createGzip(),
  res,                                  // HTTP response is a Writable
  { signal },                           // cancellable
);
```

The danger sign is collecting chunks into an array/string and sending at the end:
that turns a constant-memory stream into an O(payload) buffer and invites OOM
under load (an OWASP API4 unrestricted-resource-consumption risk — also cap body
size at the edge).

## Web Streams vs node:stream

| | `node:stream` | Web Streams (`ReadableStream`) |
|--|--------------|-------------------------------|
| Origin | Node-native, mature, fastest in Node | Web standard; what `fetch`/`Request`/`Response` use |
| Use when | files, sockets, zlib, most Node I/O | edge runtimes, `fetch` bodies, cross-runtime code |
| Bridge | `Readable.fromWeb()` / `Readable.toWeb()` | same, in reverse |

```ts
import { Readable } from "node:stream";
// consume a fetch (Web) body with Node stream tooling
const webBody = (await fetch(url)).body!;             // ReadableStream
await pipeline(Readable.fromWeb(webBody), createWriteStream("out.bin"));
```

Prefer `node:stream` for Node-only services (faster, richer); use Web Streams when
the code must also run on Workers/Deno/Bun, or when consuming `fetch` bodies.
Bridge with `Readable.fromWeb`/`toWeb`. Details:
[references/streams-and-workers.md](references/streams-and-workers.md).

## CPU-Bound Work: worker_threads

The event loop is single-threaded; a synchronous CPU burst (hashing many items,
image/PDF processing, big JSON, sync crypto) blocks *every* request. Offload to a
worker thread (or a pool), keeping the main thread responsive.

```ts
import { Worker } from "node:worker_threads";

function hashInWorker(data: Buffer): Promise<string> {
  return new Promise((resolve, reject) => {
    const w = new Worker("./hash-worker.js", { workerData: data });
    w.once("message", resolve);
    w.once("error", reject);
    w.once("exit", (code) => code !== 0 && reject(new Error(`exit ${code}`)));
  });
}
```

Spawning a worker per request is expensive — use a fixed pool (e.g. `piscina`)
sized near CPU count. For naturally-async crypto (`crypto.scrypt`,
`crypto.pbkdf2`), the async variants already run on the libuv threadpool — don't
add workers there. Pool patterns and `MessageChannel` transfer:
[references/streams-and-workers.md](references/streams-and-workers.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| `UnhandledPromiseRejection` crashes process | floating promise | `await` it or `.catch`; enable `no-floating-promises` | this file, No Floating Promises |
| Response sends before a write completes | un-awaited async side effect | `await` before responding | this file, No Floating Promises |
| Memory climbs / OOM under large requests | buffering a stream into memory | `pipeline` the stream; cap body size | this file, Backpressure |
| Slow stage never slows the fast one; data lost on error | bare `.pipe()` chain | use `pipeline` (backpressure + error/cleanup) | this file, Backpressure |
| Timeouts don't actually stop upstream work | signal not propagated | thread `AbortSignal` into `fetch`/queries/loops | this file, Cancellation |
| Latency spikes for all routes during one request | CPU-bound work on event loop | move to `worker_threads`/pool | this file, CPU-Bound Work |
| Unbounded fan-out exhausts DB connections | `Promise.all` over a huge array | bound with `p-limit`/a pool | this file, Concurrency Primitives |
| `ReadableStream is not iterable` mixing APIs | Web vs node:stream mismatch | bridge with `Readable.fromWeb`/`toWeb` | this file, Web Streams vs node:stream |

## Deep-Dive References

- [references/streams-and-workers.md](references/streams-and-workers.md) —
  `pipeline`/`finished` semantics, custom `Transform`/object-mode streams,
  Web↔Node interop and HTTP `ReadableStream` bodies, `worker_threads` pools,
  `MessageChannel`/`transferList` zero-copy transfer, graceful shutdown draining

## Related Skills

- [modern-typescript-backend](../modern-typescript-backend/SKILL.md) — typing promises, Result types, `using` for async resources
- [nest-express-fastify-patterns](../nest-express-fastify-patterns/SKILL.md) — streaming responses + cancellation per framework
- [api-security](../../quality/api-security/SKILL.md) — body-size limits and rate limiting (OWASP API4)
- [be-performance](../../quality/be-performance/SKILL.md) — event-loop lag, profiling CPU/I/O hot paths
- [be-testing](../../quality/be-testing/SKILL.md) — testing async, cancellation, and stream code
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — Node version minimums for `AbortSignal.any`, `timeout`, Web Streams
