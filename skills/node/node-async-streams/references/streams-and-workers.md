# Streams and Workers Deep Dive

Plumbing details for `node:stream`, Web Streams interop, and `worker_threads`.
Verify API availability against your Node LTS — see
`../../../_shared/version-feature-matrix.md`.

## pipeline and finished

`pipeline` connects streams, propagates backpressure, and — critically —
destroys every stream and surfaces the first error if any stage fails. Always
prefer it to chained `.pipe()`.

```ts
import { pipeline } from "node:stream/promises";

await pipeline(source, transform, destination, { signal });   // cancellable
```

`finished(stream)` resolves/rejects when a single stream ends or errors — use it
to await a stream you didn't build with `pipeline` (e.g. an incoming request you
piped elsewhere):

```ts
import { finished } from "node:stream/promises";
req.pipe(parser);
await finished(parser);
```

Error/cleanup rule: a bare `a.pipe(b)` does **not** destroy `a` when `b` errors,
leaking the source (and its fd/socket). `pipeline` fixes this. Never `.pipe()` in
production paths without your own error+destroy wiring.

## Custom Transform (object mode)

For per-record processing in a pipeline (e.g. CSV row → DB upsert), a
object-mode `Transform` keeps memory flat regardless of input size.

```ts
import { Transform } from "node:stream";

const toUpsert = new Transform({
  objectMode: true,
  transform(row, _enc, cb) {
    Promise.resolve(mapRow(row)).then((out) => cb(null, out), cb);   // forward errors
  },
});
```

Honor backpressure: return the value via `cb`/`push` and let the readable pace
you; do not buffer rows in an array inside the transform.

## Web Streams interop

`fetch`/`Request`/`Response` bodies are Web `ReadableStream`s. Bridge to Node
tooling and back:

```ts
import { Readable } from "node:stream";

// Web -> Node
const nodeReadable = Readable.fromWeb((await fetch(url)).body!);

// Node -> Web (e.g. return a Node stream from a Hono/edge handler)
const webReadable = Readable.toWeb(createReadStream(path));
return new Response(webReadable, { headers: { "content-type": "application/octet-stream" } });
```

Streaming an HTTP response by `ReadableStream` lets a proxy or export start
sending bytes immediately at constant memory — pair with an `AbortSignal` so a
client disconnect tears down the upstream read.

## worker_threads pools

Spawning a worker per task pays thread-startup cost each time. Use a fixed pool
sized near `os.availableParallelism()` and reuse workers. `piscina` is the common
choice; the shape:

```ts
import Piscina from "piscina";

const pool = new Piscina({
  filename: new URL("./hash-worker.js", import.meta.url).href,
  maxThreads: 4,                       // ~ CPU count
});

const digest: string = await pool.run(buffer, { signal });   // queued onto the pool
```

Guidelines:
- Size to CPU count, not request count — more threads than cores adds contention.
- Workers don't share JS heap; pass data via `workerData`/`postMessage`.
- Already-async native crypto (`scrypt`, `pbkdf2`, `randomBytes`) runs on the
  libuv threadpool — don't wrap it in a worker. Reach for workers when the work
  is *synchronous* CPU (parsing, hashing loops, image/PDF, compression of
  in-memory data).

## MessageChannel and zero-copy transfer

Copying large buffers between threads is expensive. `ArrayBuffer`/`MessagePort`
can be **transferred** (ownership moves, no copy) via the `transferList`:

```ts
const buf = new Uint8Array(10_000_000);
worker.postMessage(buf, [buf.buffer]);   // buffer transferred; sender's view is now detached
```

After transfer the sender's view is neutered — don't read it. Use
`MessageChannel` for a dedicated bidirectional channel between two threads
independent of the main worker message stream.

## Graceful shutdown (draining)

On `SIGTERM`, stop accepting new work, abort in-flight cancellable work past a
deadline, drain the worker pool, and close DB connections — so in-flight requests
finish and nothing is left half-written.

```ts
process.once("SIGTERM", async () => {
  server.close();                      // stop new connections
  shutdownController.abort();           // signal in-flight work (after a grace window)
  await pool.destroy();                 // drain workers
  await db.end();                       // close pool
  process.exit(0);
});
```

Combine with a body-size cap and request timeout at the edge so a single large or
slow request can't pin a worker forever (OWASP API4).
