# TypeScript Back-End Anti-Patterns

Detection rule IDs are from `@typescript-eslint` (enable
`plugin:@typescript-eslint/strict-type-checked` for the type-aware rules; they
require `parserOptions.project` pointing at your `tsconfig.json`). Each entry:
the smell, why it bites a service, the detecting rule, and the fix.

## 1. `any` — the type system off-switch

`any` propagates: one `any` poisons every value derived from it, so a typo three
calls away compiles clean and crashes in prod.

- **Detect:** `@typescript-eslint/no-explicit-any`, `no-unsafe-assignment`,
  `no-unsafe-member-access`, `no-unsafe-call`, `no-unsafe-return`.
- **Fix:** use `unknown` for genuinely-unknown input and narrow it (a `zod`
  parse, a type guard). `unknown` forces a check before use; `any` skips it.

```ts
// bad
function handle(payload: any) { return payload.user.id; }   // crashes if shape differs
// good
function handle(payload: unknown) {
  const { user } = Payload.parse(payload);                  // zod narrows unknown -> typed
  return user.id;
}
```

## 2. Non-null assertion `!`

`value!` tells the compiler "trust me, not null" — and is wrong exactly when the
value *is* null (empty DB result, missing header).

- **Detect:** `@typescript-eslint/no-non-null-assertion`.
- **Fix:** narrow with an explicit check, or return a Result/404. With
  `noUncheckedIndexedAccess` on, this surfaces array/index access too.

```ts
const user = await repo.byId(id);
if (!user) return notFound();   // not: repo.byId(id)!.email
```

## 3. Unsafe `as` casts (lying to the compiler)

`req.body as CreateUserDto` asserts a shape the compiler never verified. The cast
silences errors without making the runtime value match.

- **Detect:** `@typescript-eslint/consistent-type-assertions` (forbid casts away
  from `unknown`), `no-unsafe-type-assertion` (where available).
- **Fix:** parse with a runtime schema and infer the type from it; cast only
  through `unknown` when interop genuinely requires it, and validate immediately.

## 4. Floating promises

An un-awaited promise in a handler means errors become unhandled rejections and
ordering is undefined — a top cause of flaky services and lost transactions.

- **Detect:** `@typescript-eslint/no-floating-promises`, `no-misused-promises`
  (e.g. passing an async fn where a `void` callback is expected).
- **Fix:** `await` it, or explicitly `void` a deliberate fire-and-forget after
  attaching a `.catch`. Full treatment: [node-async-streams](../../node-async-streams/SKILL.md).

```ts
// bad — error vanishes, response may send before write completes
auditLog.write(event);
// good
await auditLog.write(event);
// deliberate background work, errors still handled
void auditLog.write(event).catch((e) => logger.error(e));
```

## 5. `enum` over union-of-literals

Numeric `enum`s have surprising runtime objects, reverse mappings, and are not
structurally typed; `const enum` breaks under `isolatedModules`.

- **Detect:** `@typescript-eslint/prefer-literal-enum-member`; project lint rule
  banning `enum` for new code.
- **Fix:** a union of string literals (`as const` object if you need a value
  map). Zero runtime cost, exhaustiveness-friendly.

```ts
type Role = "admin" | "member" | "guest";
const Status = { Active: "active", Closed: "closed" } as const;
type Status = (typeof Status)[keyof typeof Status];
```

## 6. Type/runtime drift (the silent one)

A hand-written `interface` next to a separate `zod` schema (or DB row type) drifts
the moment one changes. The static type says one thing, the parsed value another.

- **Detect:** no single rule — review for duplicated shape definitions.
- **Fix:** derive the type from the schema (`z.infer`) or generate types from the
  DB (Prisma, Drizzle, Kysely codegen). One source of truth per shape.

## 7. `Object`/`{}`/`Function` as types

`{}` means "any non-nullish value", not "empty object"; `Function` is untyped and
callable with anything.

- **Detect:** `@typescript-eslint/no-restricted-types` (or the legacy
  `ban-types`).
- **Fix:** `Record<string, unknown>` for an open object, a precise call signature
  for a function.

## 8. Catch clause `any`

In `catch (e)`, `e` is `unknown` (under `useUnknownInCatchVariables`, default with
`strict`). Treating it as an `Error` without narrowing crashes on thrown non-Errors.

- **Detect:** `@typescript-eslint/no-unsafe-member-access` on `e`.
- **Fix:** narrow: `if (e instanceof Error) ...`, else wrap. Never `catch (e: any)`.

```ts
try { await charge(); }
catch (e) {
  const msg = e instanceof Error ? e.message : String(e);
  logger.error({ err: msg });
}
```
