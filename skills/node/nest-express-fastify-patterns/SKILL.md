---
name: nest-express-fastify-patterns
description: >-
  Node HTTP framework patterns: Express middleware/error handlers, NestJS
  modules/DI/guards/pipes/interceptors, Fastify plugins/JSON-schema/hooks, and
  Hono for edge; routing, validation, centralized error handling, and choosing
  one. Use when starting a Node service, picking a framework, wiring
  middleware/guards, or centralizing validation and error handling.
---

# Node Framework Patterns (Express / NestJS / Fastify / Hono)

**Validate at the edge, handle errors in one place, pick the framework by team and shape — not hype**

## When to Use

Use this skill when:
- Standing up a new Node HTTP service and choosing a framework
- Wiring request validation, authentication, and error handling consistently
- Translating an Express middleware mindset to NestJS DI or Fastify plugins
- Targeting an edge/serverless runtime (Hono)
- Deciding where cross-cutting concerns (auth, logging, rate limit) live

Routing: per-framework lifecycle internals, schema serialization, plugin
encapsulation, and exception filters →
[references/framework-deep-dive.md](references/framework-deep-dive.md).

## Choosing a Framework

| Framework | Pick it when | Validation | Notable |
|-----------|--------------|------------|---------|
| **Express** | Smallest surface, max ecosystem, you'll assemble your own structure | bring your own (zod in middleware) | callback-era; async errors need wiring (Express 5 improves this) |
| **NestJS** | Large team/app, want opinionated DI + modules + decorators (Angular-like) | pipes (`ZodValidationPipe`, `class-validator`) | batteries included; heavier; great for microservices/GraphQL |
| **Fastify** | Throughput matters; you want schema-driven validation + fast serialization | JSON Schema per route (built-in) | plugin encapsulation, hooks, lowest overhead of the three |
| **Hono** | Edge/serverless (Cloudflare Workers, Bun, Deno, Lambda), tiny + Web-standard | `@hono/zod-validator` | runs on Web `Request`/`Response`; multi-runtime |

All four are actively maintained; pin the major in `package.json` and verify
features against your version — skill: version-feature-matrix
(`_shared/version-feature-matrix.md`). Defaults: **Fastify** for a fresh REST
service that values performance, **NestJS** for a large structured app,
**Express** for minimal/legacy interop, **Hono** for the edge.

## Express: Middleware + Centralized Errors

Express's model is an ordered middleware chain. Validate early, and route every
error to one error-handling middleware (the 4-arg signature) — never `try/catch`
in every route.

```ts
import express from "express";
import { z } from "zod";

const app = express();
app.use(express.json());

const Body = z.object({ email: z.string().email() });

// async route — forward errors to the error handler
app.post("/users", async (req, res, next) => {
  const parsed = Body.safeParse(req.body);
  if (!parsed.success) return next(new HttpError(400, "invalid_body", parsed.error.flatten()));
  res.status(201).json(await createUser(parsed.data));
});

// single error-handling middleware (4 args), registered LAST
app.use((err, _req, res, _next) => {
  const status = err instanceof HttpError ? err.status : 500;
  res.status(status).json({ error: err.code ?? "internal", detail: err.detail });
});
```

On Express 4, a thrown error inside an `async` handler is *not* caught
automatically — `await` and `next(err)`, or wrap with a helper. Express 5
forwards rejected promises to the error handler. See
[references/framework-deep-dive.md](references/framework-deep-dive.md).

## NestJS: Modules, DI, Pipes, Guards

NestJS organizes code into modules; providers are injected by type; pipes
validate, guards authorize, interceptors wrap, filters handle errors.

```ts
@Module({ controllers: [UsersController], providers: [UsersService] })
export class UsersModule {}

@Injectable()
export class JwtGuard implements CanActivate {       // authorization boundary
  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest();
    return verify(req.headers.authorization);          // OWASP API2/API5
  }
}

@Controller("users")
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Post()
  @UseGuards(JwtGuard)
  @UsePipes(new ZodValidationPipe(CreateUser))         // validate at the edge
  create(@Body() dto: CreateUser) {
    return this.users.create(dto);                     // throws -> exception filter
  }
}
```

A single `@Catch()` exception filter maps domain errors to HTTP status app-wide
— the NestJS analogue of the Express error middleware. Guards are the
function-level authorization boundary (OWASP API5); enforce object-level checks
(API1/BOLA) inside the service against the authenticated principal.

## Fastify: Schema-Driven Routes + Plugins

Fastify validates and serializes from JSON Schema attached to the route. The
schema is the contract: it validates input *and* fast-serializes output (only
declared fields leave — a built-in guard against over-exposure, OWASP API3).

```ts
import Fastify from "fastify";
const app = Fastify({ logger: true });

app.post("/users", {
  schema: {
    body: { type: "object", required: ["email"],
            properties: { email: { type: "string", format: "email" } } },
    response: { 201: { type: "object", properties: { id: { type: "string" } } } },
  },
  handler: async (req, reply) => {
    const user = await createUser(req.body as CreateUser);  // body is validated
    reply.code(201).send(user);                              // serialized to schema
  },
});

// centralized error handling
app.setErrorHandler((err, _req, reply) => {
  reply.code(err.statusCode ?? 500).send({ error: err.code ?? "internal" });
});
```

Plugins encapsulate scope: a plugin's decorators/hooks apply only within it
unless wrapped with `fastify-plugin`. Use `onRequest`/`preHandler` hooks for
auth and rate-limit, mirroring Express middleware. Pair JSON Schema with
`zod-to-json-schema` or `fastify-type-provider-zod` to keep one zod source of
truth. Details: [references/framework-deep-dive.md](references/framework-deep-dive.md).

## Hono: Edge + Web Standards

Hono handlers receive a Web-standard context; the same code runs on Workers, Bun,
Deno, and Node. Validate with the zod middleware.

```ts
import { Hono } from "hono";
import { zValidator } from "@hono/zod-validator";

const app = new Hono();
app.post("/users", zValidator("json", CreateUser), async (c) => {
  const dto = c.req.valid("json");           // typed + validated
  return c.json(await createUser(dto), 201);
});
app.onError((err, c) => c.json({ error: "internal" }, 500));
```

Because Hono is Web-standard, request bodies are `ReadableStream`s — see
[node-async-streams](../node-async-streams/SKILL.md) for streaming responses and
backpressure on the edge.

## Cross-Framework Rules

- **Validate every input at the edge** with a runtime schema (zod/valibot/JSON
  Schema); the static type is derived from it. See
  [modern-typescript-backend](../modern-typescript-backend/SKILL.md).
- **One error handler**, mapping domain errors → status once. No `try/catch` per
  route; no leaking stack traces or internals to clients (OWASP API8).
- **Auth as a boundary** (middleware/guard/hook), object-level checks in the
  service against the authenticated subject — [api-security](../../quality/api-security/SKILL.md).
- **No floating promises** in handlers — [node-async-streams](../node-async-streams/SKILL.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Express async error → hung request / crash | thrown in async handler, not forwarded (Express 4) | `await` + `next(err)` or async wrapper; upgrade to Express 5 | [framework-deep-dive.md](references/framework-deep-dive.md) § express |
| NestJS "can't resolve dependencies" | provider not in module / missing decorator metadata | add to `providers`; `emitDecoratorMetadata: true` | [modern-typescript-backend](../modern-typescript-backend/SKILL.md) |
| Fastify route validates but response leaks extra fields | no `response` schema | add response schema; serialization strips undeclared fields | this file, Fastify |
| Fastify decorator "not available" in a route | plugin encapsulation scoped it | wrap with `fastify-plugin` to expose upward | [framework-deep-dive.md](references/framework-deep-dive.md) § fastify |
| Same handler works on Node, fails on Workers | Node-only API on the edge | use Web-standard APIs (Hono); avoid `node:*` on edge | this file, Hono |
| Errors return 200 with body, or full stack trace | no centralized error handler | register one error handler; map status; redact internals | this file, Cross-Framework Rules |

## Deep-Dive References

- [references/framework-deep-dive.md](references/framework-deep-dive.md) —
  Express async-error wiring and Express 5 changes; NestJS request lifecycle
  (guards → interceptors → pipes → handler → filter) and exception filters;
  Fastify plugin encapsulation, hook order, and schema serialization; Hono on
  edge runtimes

## Related Skills

- [modern-typescript-backend](../modern-typescript-backend/SKILL.md) — strict types + zod the validators consume
- [node-async-streams](../node-async-streams/SKILL.md) — async-correct handlers, streaming responses
- [api-security](../../quality/api-security/SKILL.md) — auth boundaries, rate limiting, error-leak hygiene
- [be-testing](../../quality/be-testing/SKILL.md) — integration tests against the running app (supertest, Testcontainers)
- [secure-coding](../../_shared/secure-coding/SKILL.md) — injection-safe handlers, SSRF on outbound calls
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — framework/runtime version minimums
