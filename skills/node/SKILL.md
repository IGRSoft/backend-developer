---
name: node-skills
description: >-
  Node.js/TypeScript back-end skills navigation — modern TypeScript,
  NestJS/Express/Fastify/Hono patterns, async and streams. Use when writing
  or reviewing Node/TS services, choosing a framework, or handling
  async/streams.
---

# Node.js / TypeScript Skills

**Navigation and version snapshot for Node.js LTS + TypeScript 5.x back-end development**

## Version Snapshot

| Version | Headline (one line) |
|---------|---------------------|
| Node 20 (LTS) | Stable `fetch`/`Web Streams`/`AbortController`, `--test` runner, `node:test`; permission model experimental |
| Node 22 (LTS) | `require(esm)` for sync ESM graphs, stable WebSocket client, `--run` script shortcut, V8 12.4 |
| Node 24 (LTS, "Krypton") | npm 11, V8 13.6 (`Float16Array`, explicit resource management `using`), `URLPattern` global, permission model approaching stable |
| TypeScript 5.x | `using`/`await using` (5.2), `const` type params (5.0), decorators stage-3 (5.0), `satisfies` (4.9), `--isolatedDeclarations` (5.5), inferred type predicates (5.5) |

Runtime/transpiler minutiae shift between minor releases — for anything you pin
in CI, verify against your runtime (`node -v`, `tsc -v`) and link the canonical
skill: version-feature-matrix (`_shared/version-feature-matrix.md`).

**Toolchain in one line:** a package manager (`pnpm`/`npm`/`yarn` — one, with a
committed lockfile) - `tsc` (type gate) - `eslint` + `prettier` (lint + format) -
`vitest`/`jest` + Testcontainers (tests). Pin tool and runtime versions in
`package.json` (`engines`, `packageManager`) and the lockfile, never in prose.

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Write strict modern TS (tsconfig, ESM, discriminated unions, zod, Result types) | [modern-typescript-backend/SKILL.md](modern-typescript-backend/SKILL.md) |
| Pick Express vs NestJS vs Fastify vs Hono, structure routes/validation/errors | [nest-express-fastify-patterns/SKILL.md](nest-express-fastify-patterns/SKILL.md) |
| Get async right (no floating promises), cancel work, handle stream backpressure | [node-async-streams/SKILL.md](node-async-streams/SKILL.md) |
| Validate untrusted input, avoid injection/SSRF, handle secrets | [secure-coding](../_shared/secure-coding/SKILL.md) |
| Defend the API surface (BOLA, authn/z, rate limits) | [api-security](../quality/api-security/SKILL.md) |
| Write unit + integration tests for a service | [be-testing](../quality/be-testing/SKILL.md) |

## Decision Tree

```
Node/TS back-end task?
├── Which Node/TS version has feature X? → version-feature-matrix (canonical)
├── Writing/reviewing modern TS → modern-typescript-backend/SKILL.md
│   ├── Runtime validation (zod/valibot) → modern-typescript-backend (Validation)
│   └── Anti-pattern + eslint rule → references/typescript-anti-patterns.md
├── Framework choice / routing / DI / middleware → nest-express-fastify-patterns/SKILL.md
│   ├── NestJS modules/guards/pipes → that skill (NestJS)
│   └── Fastify schemas/plugins/hooks → that skill (Fastify)
├── Promises / cancellation / streams / worker_threads → node-async-streams/SKILL.md
├── Auth boundaries, rate limits, SSRF → quality/api-security/SKILL.md
├── Unit + integration tests → quality/be-testing/SKILL.md
└── Input validation / secrets / injection → _shared/secure-coding/SKILL.md
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the node/ subtree |
| [modern-typescript-backend/SKILL.md](modern-typescript-backend/SKILL.md) | strict tsconfig, ESM, discriminated unions, zod/valibot, Result types, TS 5.x gates |
| [nest-express-fastify-patterns/SKILL.md](nest-express-fastify-patterns/SKILL.md) | Express/NestJS/Fastify/Hono patterns; when to pick which |
| [node-async-streams/SKILL.md](node-async-streams/SKILL.md) | async correctness, AbortController, backpressure, Web Streams vs node:stream, worker_threads |

## Related Skills

- [go-skills](../go/SKILL.md) / [jvm-skills](../jvm/SKILL.md) — sibling runtime back-ends for cross-service work
- [api-security](../quality/api-security/SKILL.md) — OWASP API Security Top 10 defenses
- [be-testing](../quality/be-testing/SKILL.md) — unit + Testcontainers integration tests
- [secure-coding](../_shared/secure-coding/SKILL.md) — input validation, injection, SSRF, secrets hygiene
- [version-feature-matrix](../_shared/version-feature-matrix.md) — canonical Node/TS version minimums
