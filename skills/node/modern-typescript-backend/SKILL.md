---
name: modern-typescript-backend
description: >-
  Modern TypeScript for Node back-ends: strict tsconfig, ESM and package
  exports, discriminated unions with exhaustiveness, zod/valibot boundary
  validation, Result/error types, NestJS decorators, and TS 5.x features with
  fallbacks. Use when starting a TS service, tightening tsconfig, validating
  untrusted input, modeling domain errors, or adopting a TS 5.x feature.
---

# Modern TypeScript for Back-Ends

**Strict types at the boundary, discriminated unions in the domain, one tsconfig as the contract**

## When to Use

Use this skill when:
- Bootstrapping a new Node/TS service or tightening an existing `tsconfig.json`
- Choosing ESM vs CJS and wiring `package.json` `exports`/`type`
- Validating untrusted request bodies, query params, env, and upstream API responses
- Modeling domain results and errors (discriminated unions, Result types) instead of `throw` everywhere
- Adopting a TS 5.x feature and needing the version gate + fallback
- Catching `any`/unsafe-cast anti-patterns → [references/typescript-anti-patterns.md](references/typescript-anti-patterns.md)

## The Strict Baseline

`strict` alone is not enough for a back-end. Turn on the full safety set; treat
warnings as errors in CI.

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,                          // implies noImplicitAny, strictNullChecks, ...
    "noUncheckedIndexedAccess": true,        // arr[i] is T | undefined — catches OOB reads
    "exactOptionalPropertyType": true,       // { a?: number } != { a: number | undefined }
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,            // explicit type-only imports; no elision surprises
    "isolatedModules": true,                 // safe for esbuild/swc single-file transpile
    "skipLibCheck": true,
    "outDir": "dist"
  }
}
```

`tsc --noEmit` is the type gate; bundling/transpiling is a separate concern
(esbuild/swc/tsup) — never trust the bundler for type safety.

```bash
tsc --noEmit            # CI type gate (no output, just checking)
```

Version gates for the options above and the TS 5.x features below: skill:
version-feature-matrix (`_shared/version-feature-matrix.md`).

## ESM and package.json

Modern services ship ESM. Set `"type": "module"` and use `NodeNext` resolution
so `tsc` enforces the runtime's import rules (explicit `.js` specifiers on
relative imports).

```jsonc
// package.json
{
  "type": "module",
  "engines": { "node": ">=20" },
  "packageManager": "pnpm@9.12.0",
  "exports": {
    ".": { "types": "./dist/index.d.ts", "import": "./dist/index.js" }
  }
}
```

Node 22+ can `require()` a synchronous ESM graph; Node 20 cannot — do not rely
on it for a library meant to run on 20. Relative imports in ESM need the
extension: `import { db } from "./db.js"` (the `.js`, not `.ts`).

## Validate at the Boundary (zod / valibot)

TypeScript types vanish at runtime. **Every untrusted input** — request body,
query, params, headers, env, and upstream API responses (OWASP API10) — must be
parsed by a runtime schema, and the static type is *derived from* that schema.

```ts
import { z } from "zod";

const CreateUser = z.object({
  email: z.string().email(),
  age: z.number().int().min(0).max(150),
  role: z.enum(["admin", "member"]).default("member"),
});
type CreateUser = z.infer<typeof CreateUser>;   // single source of truth

// at the edge — never trust req.body's declared type
const result = CreateUser.safeParse(req.body);
if (!result.success) {
  return res.status(400).json({ error: result.error.flatten() });
}
const user: CreateUser = result.data;           // validated, typed
```

Use `.safeParse` (returns a discriminated result) over `.parse` (throws) in
request handlers so the error path is explicit. For env, parse once at startup
and export the typed object — a missing var should crash boot, not request 5000.
`valibot` is the smaller-bundle alternative with the same parse-then-infer model;
pick one per service. Never hand-cast `req.body as CreateUser` — that is a lie to
the compiler (see [references/typescript-anti-patterns.md](references/typescript-anti-patterns.md)).

## Discriminated Unions + Exhaustiveness

Model domain states as a tagged union and let the compiler prove you handled
every case with a `never` check.

```ts
type PaymentEvent =
  | { type: "authorized"; amount: number }
  | { type: "captured"; amount: number; capturedAt: Date }
  | { type: "failed"; reason: string };

function describe(e: PaymentEvent): string {
  switch (e.type) {
    case "authorized": return `auth ${e.amount}`;
    case "captured":   return `captured ${e.amount}`;
    case "failed":     return `failed: ${e.reason}`;
    default: {
      const _exhaustive: never = e;   // compile error if a case is added later
      return _exhaustive;
    }
  }
}
```

`noFallthroughCasesInSwitch` plus the `never` assignment turns "forgot a new
variant" from a production bug into a build failure.

## Result Types: Errors as Values

For expected, recoverable failures (validation, not-found, conflict), return a
Result union instead of throwing. Reserve `throw` for truly exceptional, bug-class
conditions. This keeps error handling visible in the type signature.

```ts
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

type FindUserError = "not_found" | "db_unavailable";

async function findUser(id: string): Promise<Result<User, FindUserError>> {
  const row = await repo.byId(id);
  if (!row) return { ok: false, error: "not_found" };
  return { ok: true, value: row };
}

const r = await findUser(id);
if (!r.ok) return res.status(r.error === "not_found" ? 404 : 503).end();
res.json(r.value);
```

Callers cannot ignore the failure — they must narrow `r.ok` before touching
`r.value`. Map the error variants to HTTP/gRPC status at the edge, once.

## Decorators (NestJS)

NestJS uses stage-3 decorators for DI, routing, and validation. Enable the
TS-emit decorators NestJS expects (it relies on `experimentalDecorators` +
`emitDecoratorMetadata`, distinct from native stage-3 emit):

```jsonc
// tsconfig.json (NestJS)
{ "compilerOptions": { "experimentalDecorators": true, "emitDecoratorMetadata": true } }
```

```ts
@Controller("users")
export class UsersController {
  constructor(private readonly users: UsersService) {}   // DI by type

  @Post()
  @UsePipes(new ZodValidationPipe(CreateUser))            // validate at the edge
  create(@Body() dto: CreateUser) {
    return this.users.create(dto);
  }
}
```

Framework wiring (modules, guards, pipes, interceptors) lives in
[nest-express-fastify-patterns](../nest-express-fastify-patterns/SKILL.md).

## TS 5.x Features Worth Adopting

| Feature | Version | Use for | Fallback (older TS) |
|---------|---------|---------|---------------------|
| `using` / `await using` | 5.2 | deterministic resource cleanup (db client, span, file) | `try/finally` with explicit `close()` |
| Inferred type predicates | 5.5 | `arr.filter(Boolean)` narrows without a manual guard | hand-written `(x): x is T =>` guard |
| `--isolatedDeclarations` | 5.5 | fast `.d.ts` emit for libraries/monorepos | normal `tsc` declaration emit |
| `const` type parameters | 5.0 | preserve literal tuples in generic helpers | `as const` at the call site |
| `satisfies` | 4.9 | typecheck a config object without widening | explicit annotation + manual checks |

```ts
// using: scope-bound cleanup (TS 5.2 + Node 24 / Symbol.dispose polyfill)
async function withTx() {
  await using tx = await pool.begin();   // tx[Symbol.asyncDispose]() runs on scope exit
  await tx.query("...");
  // implicit rollback-or-release at end of block, even on throw
}
```

`using` requires a runtime with `Symbol.dispose`/`asyncDispose` (Node 24 native;
earlier needs the `disposablestack` polyfill and `lib: ["esnext.disposable"]`).
Gate before shipping: skill: version-feature-matrix.

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Runtime `undefined` from `obj[key]` that "can't happen" | `noUncheckedIndexedAccess` off | enable it; narrow before use | this file, Strict Baseline |
| `req.body` typed but garbage at runtime | trusted the declared type, no parse | `zod.safeParse` at the edge | this file, Validate at the Boundary |
| New union variant silently unhandled | no exhaustiveness check | add `never` default + `noFallthroughCasesInSwitch` | this file, Discriminated Unions |
| `Cannot find module './db'` at runtime (ESM) | missing `.js` extension | `import "./db.js"` under `NodeNext` | this file, ESM |
| NestJS "Nest can't resolve dependencies" | decorator metadata not emitted | `emitDecoratorMetadata: true`; check provider in module | [nest-express-fastify-patterns](../nest-express-fastify-patterns/SKILL.md) |
| `tsc` clean but bundle crashes on a type-only import | `isolatedModules`/`verbatimModuleSyntax` mismatch | use `import type`; enable both flags | this file, Strict Baseline |
| `Symbol.dispose is not defined` using `using` | runtime predates Node 24 | polyfill + `lib: esnext.disposable`, or drop to `try/finally` | this file, TS 5.x |

## Deep-Dive References

- [references/typescript-anti-patterns.md](references/typescript-anti-patterns.md)
  — anti-pattern catalog (`any`, non-null `!`, unsafe `as` casts, floating
  promises, `enum` vs union, type-vs-runtime drift) with the detecting
  `@typescript-eslint` rule IDs and the fix for each

## Related Skills

- [nest-express-fastify-patterns](../nest-express-fastify-patterns/SKILL.md) — framework wiring that consumes these types
- [node-async-streams](../node-async-streams/SKILL.md) — Promise typing, no floating promises, `using` for async resources
- [secure-coding](../../_shared/secure-coding/SKILL.md) — why boundary validation blocks injection/SSRF
- [api-security](../../quality/api-security/SKILL.md) — schema validation as an OWASP API3/API10 control
- [be-testing](../../quality/be-testing/SKILL.md) — testing parsers and Result branches
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — Node/TS version minimums for every gate above
