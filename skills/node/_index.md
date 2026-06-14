# Node.js / TypeScript Skills Index

Quick navigation for the `skills/node/` subtree. Start at [SKILL.md](SKILL.md)
for the guided entry with version snapshot and decision tree.

## Skills

| Skill | Use it for |
|-------|------------|
| [modern-typescript-backend/SKILL.md](modern-typescript-backend/SKILL.md) | strict `tsconfig`, ESM + `package.json` `exports`, discriminated unions, exhaustiveness, `zod`/`valibot` boundary validation, Result/error types, NestJS decorators, TS 5.x gates (`using`, `satisfies`, inferred predicates, `isolatedDeclarations`) |
| [nest-express-fastify-patterns/SKILL.md](nest-express-fastify-patterns/SKILL.md) | Express middleware + error handlers, NestJS modules/DI/guards/pipes/interceptors, Fastify plugins/JSON-schema/hooks, Hono edge handlers; routing, validation, centralized error handling, framework choice |
| [node-async-streams/SKILL.md](node-async-streams/SKILL.md) | promises/async-await without floating promises, `AbortController`/`AbortSignal` cancellation and timeouts, stream backpressure, Web Streams vs `node:stream`, `worker_threads` for CPU-bound work |

## References

| File | Use it for |
|------|------------|
| [modern-typescript-backend/references/typescript-anti-patterns.md](modern-typescript-backend/references/typescript-anti-patterns.md) | Anti-pattern catalog with detecting `@typescript-eslint` rule IDs and fixes (`any`, non-null `!`, unsafe casts, floating promises, enums) |
| [nest-express-fastify-patterns/references/framework-deep-dive.md](nest-express-fastify-patterns/references/framework-deep-dive.md) | Per-framework deep dives: NestJS lifecycle + exception filters, Fastify schema serialization + plugin encapsulation, Express async-error wiring, Hono on edge runtimes |
| [node-async-streams/references/streams-and-workers.md](node-async-streams/references/streams-and-workers.md) | `pipeline`/`finished`, Web Streams interop, `ReadableStream` HTTP bodies, `worker_threads` pools, `MessageChannel` transfer |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Node/TS version minimums (canonical) | `../_shared/version-feature-matrix.md` |
| Input validation, injection (SQL/NoSQL/command), SSRF, secrets | `../_shared/secure-coding/SKILL.md` |
| OWASP API Security Top 10 defenses (BOLA, authn/z, rate limits) | `../quality/api-security/SKILL.md` |
| Unit + Testcontainers integration tests | `../quality/be-testing/SKILL.md` |
| Profiling (clinic.js, `--prof`, heap snapshots) | `../quality/be-performance/SKILL.md` |
| Workflow stage participation | `../_shared/workflow-integration/SKILL.md` |
