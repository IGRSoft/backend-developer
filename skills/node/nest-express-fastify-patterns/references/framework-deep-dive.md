# Node Framework Deep Dive

Per-framework internals that don't fit the entry skill. Verify behavior against
your pinned major (`express`, `@nestjs/*`, `fastify`, `hono`) — see
`../../../_shared/version-feature-matrix.md`.

## Express: async errors (Express 5 vs legacy Express 4)

### Express 5 (GA) — async rejections auto-forward

Express 5 is the current GA major (and the default Express integration in
NestJS 11). A promise returned from an `async` handler/middleware that rejects is
forwarded to the error handler automatically — `return` the promise (or `await`
inside the handler) and let your one 4-arg error middleware map it. The
`asyncHandler`/`wrap` helper is no longer required:

```ts
// Express 5 — a throw/rejection lands in the error middleware, no wrapper
app.get("/x", async (_req, res) => { res.json(await load()); });
```

Express 5 also tightens path-route matching (named wildcards instead of bare
`*`/regex strings), drops several long-deprecated methods, and raised its Node
floor (no pre-18 runtimes). When upgrading from 4, re-test routes using `*`
wildcards and regex paths, and audit removed methods (`app.del`, `res.json(status, obj)`, etc.).

### Legacy Express 4 — async errors do not auto-forward

On Express 4 a rejected promise in an `async` handler is *not* caught; it becomes
an unhandled rejection (process may crash, request hangs). Two safe patterns
until you can move to 5:

```ts
// 1. explicit forward
app.get("/x", async (req, res, next) => {
  try { res.json(await load()); } catch (e) { next(e); }
});

// 2. wrapper (apply to every async route)
const wrap = (fn: express.RequestHandler): express.RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

app.get("/x", wrap(async (req, res) => { res.json(await load()); }));
```

### Middleware order

Order is execution order. Body parsing and auth go before routes; the 4-arg error
handler goes **last**. A 4-arg function `(err, req, res, next)` is the *only*
error middleware signature — Express detects it by arity, so don't omit `next`.

## NestJS: request lifecycle

For an incoming request, NestJS runs components in this order:

```
middleware → guards → interceptors (pre) → pipes → handler
           → interceptors (post) → exception filters (on throw)
```

- **Guards** (`CanActivate`) — authorization yes/no. Throw or return false → 403.
  This is your function-level authz boundary (OWASP API5). Object-level (BOLA,
  API1) belongs in the service, checked against the authenticated principal.
- **Pipes** — transform/validate the bound argument (`ZodValidationPipe`,
  `ValidationPipe` with `class-validator`). Validate at the edge.
- **Interceptors** — wrap the handler (logging, caching, response shaping,
  timeouts via RxJS `timeout()`).
- **Exception filters** (`@Catch()`) — map thrown errors to HTTP responses
  app-wide. Register a global filter for domain errors so each handler stays
  status-agnostic.

```ts
@Catch(DomainError)
export class DomainExceptionFilter implements ExceptionFilter {
  catch(err: DomainError, host: ArgumentsHost) {
    const res = host.switchToHttp().getResponse();
    const status = { not_found: 404, conflict: 409 }[err.kind] ?? 400;
    res.status(status).json({ error: err.kind });   // no internals leaked (API8)
  }
}
```

DI scopes: providers are singletons by default; use `Scope.REQUEST` only when you
must (per-request state) — it disables singleton caching and costs throughput.

## Fastify: encapsulation, hooks, serialization

### Plugin encapsulation

Each plugin gets its own scope. Decorators (`app.decorate`), hooks, and routes
registered inside a plugin are visible only within that plugin and its children —
not to siblings or the parent. To share a decorator upward, wrap the plugin with
`fastify-plugin` (which breaks encapsulation deliberately):

```ts
import fp from "fastify-plugin";
export default fp(async (app) => { app.decorate("db", makeDb()); });  // db visible app-wide
```

This encapsulation is a feature: per-route-group auth, separate body limits, and
isolated error handlers fall out of registering plugins under a prefix.

### Hook order

`onRequest → preParsing → preValidation → preHandler → handler → preSerialization
→ onSend → onResponse`. Put authentication in `onRequest`/`preHandler`,
rate-limiting in `onRequest`. Errors route to `setErrorHandler` (nearest in
scope).

### Schema serialization

A `response` schema makes Fastify compile a fast serializer that emits **only the
declared properties** — extra fields on the object are dropped. This is both a
performance win and a built-in defense against accidentally returning sensitive
fields (OWASP API3, excessive data exposure). Always declare response schemas for
endpoints returning user/account data.

Keep one source of truth by generating JSON Schema from zod
(`fastify-type-provider-zod` or `zod-to-json-schema`) rather than hand-writing
both.

## Hono on edge runtimes

Hono targets the Web platform: handlers get a `Context` over Web `Request`/
`Response`, so the same router runs on Cloudflare Workers, Bun, Deno, Node
(`@hono/node-server`), and Lambda. Constraints on the edge:

- No `node:*` builtins unless the runtime polyfills them; no long-lived
  connection pools across invocations on Workers — use HTTP-based or Workers-native
  data bindings.
- Bodies are `ReadableStream`s; stream large responses with `c.body(stream)` and
  honor backpressure (see `../../node-async-streams/SKILL.md`).
- Validate with `@hono/zod-validator`; `c.req.valid("json")` returns the typed,
  validated value — never read `c.req.json()` unvalidated for trusted use.
