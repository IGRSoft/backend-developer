---
name: version-feature-matrix
description: Canonical lookup mapping back-end runtimes and frameworks (Node.js 18/20/22 + TypeScript 5.x, Go 1.21-1.23, Java 17/21 LTS + Spring Boot 3.x + Kotlin 2.x, Python web frameworks, ORM/DB engine floors) to minimum versions and headline features. Reference before asserting feature availability or pinning a runtime/framework.
---

# Version & Feature Matrix

Canonical lookup for "which runtime/framework version do I need for this feature, and what do I get". Every version-specific claim in this plugin's skills should link here rather than restate minimums. Runtime and framework support shifts between minor releases — for entries marked *(verify against your toolchain)*, confirm against your environment (`node --version`, `tsc --version`, `go version`, `java --version`, `mvn -v`, `python3 -VV`) and the vendor's release notes before relying on a feature in CI.

## Node.js & TypeScript

| Runtime / Tool | Status anchor | What you get (one line) |
|----------------|---------------|-------------------------|
| Node.js 18 (LTS "Hydrogen") | Maintenance — EOL 2025-04 *(verify against your toolchain)* | Global `fetch`/`Request`/`Response` (undici), Web Streams, `node:test` runner (experimental), built-in `--watch` |
| Node.js 20 (LTS "Iron") | Active/Maintenance LTS | Stable `node:test` + `mock`, permission model (`--experimental-permission`), stable `--env-file`, V8 11.3 |
| Node.js 22 (LTS "Jod") | Active LTS — the safe baseline for new services | `require()` of ESM (flagged then stable), stable WebSocket client, `--run` script shortcut, V8 12.4, glob in `node:fs` |
| TypeScript 5.x | 5.0 → 5.x current | `const` type params, decorators (TC39 stage 3), `using`/`await using` (explicit resource mgmt, TS 5.2+), `satisfies`, `--moduleResolution bundler`, `--verbatimModuleSyntax` |

**Fallback rows**:
- No global `fetch` (Node < 18) → `undici` or `node-fetch` as a dependency; never assume `fetch` on the older LTS without a polyfill.
- No stable `node:test` (Node < 20) → keep `vitest`/`jest`; the in-tree runner is fine for libraries on 20+ but most services still pin a framework for coverage + mocking ergonomics.
- `using`/`await using` need TS 5.2+ **and** a runtime/polyfill for `Symbol.dispose`/`Symbol.asyncDispose` — gate on both, not the TS version alone.

## Go

| Version | Status anchor | What you get (one line) |
|---------|---------------|-------------------------|
| 1.21 | Released 2023-08 | `min`/`max`/`clear` builtins, `log/slog` structured logging, `slices`/`maps`/`cmp` std packages, loopvar preview |
| 1.22 | Released 2024-02 | Per-iteration loop variables (loopvar shipped — closures in `for` are safe), `net/http.ServeMux` method+wildcard routing, `math/rand/v2` |
| 1.23 | Released 2024-08 | Range-over-func iterators (`for x := range seq`), `iter` package, `unique` package, timer/`time` GC improvements |

**Fallback rows**:
- Pre-1.22 loop-variable capture bug → declare `v := v` inside the loop body before closing over it; do not assume the fix on 1.21 or earlier.
- Pre-1.22 `ServeMux` routing (no method/pattern matching) → keep `chi`/`gin`/`echo` for routing, or match methods manually; the stdlib router only suffices on 1.22+.
- Pre-1.21 structured logging → `zap`/`zerolog`; `log/slog` is the std answer only from 1.21.
- Generics floor is 1.18 — assume present on all supported versions here.

## Java, Spring Boot & Kotlin

| Runtime / Framework | Status anchor | What you get (one line) |
|---------------------|---------------|-------------------------|
| Java 17 (LTS) | The conservative baseline | Records, sealed classes, pattern matching for `instanceof`, switch expressions, text blocks |
| Java 21 (LTS) | Current LTS — preferred for new services | Virtual threads (Project Loom, `Thread.ofVirtual`), pattern matching for `switch`, record patterns, sequenced collections |
| Spring Boot 3.x | 3.0+ requires Java 17 baseline | Jakarta EE namespace (`jakarta.*` not `javax.*`), observability via Micrometer/OpenTelemetry, native images via Spring AOT/GraalVM, virtual-thread support (3.2+, `spring.threads.virtual.enabled`) |
| Kotlin 2.x | 2.0 K2 compiler → 2.x current | K2 compiler (faster, stricter), stable `data object`, improved smart casts; coroutines/`kotlinx.coroutines` versioned independently — pin in the build file |

**Fallback rows**:
- Virtual threads need Java 21 **and** Spring Boot 3.2+ to be wired automatically — on Java 17 / Boot 3.0-3.1 keep the platform-thread pool and tune `server.tomcat.threads.max`.
- The `javax.*` → `jakarta.*` migration is the hard gate moving to Spring Boot 3 — a library still on `javax.servlet` will not load; check transitive deps, not just your code.
- Pre-Java 17 (8/11) → no records/sealed types; use Lombok or plain classes and stay on Spring Boot 2.7.x (its own EOL — *(verify against your toolchain)*).

## Python Web Frameworks

Python **language** minimums (3.12-3.14, free-threading, t-strings, deferred annotations) are **not forked here** — the `python-backend-developer` agent defers language-version questions to `system-developer`'s `version-feature-matrix.md`. This table covers only the web-framework layer.

| Framework | Status anchor | What you get (one line) |
|-----------|---------------|-------------------------|
| FastAPI | 0.11x+ current | ASGI, Pydantic v2 models, dependency injection, automatic OpenAPI; needs an ASGI server (`uvicorn`/`hypercorn`) |
| Pydantic | v2 (Rust core) | ~5-50x faster validation than v1, `model_validate`, stricter coercion; v1→v2 is a breaking migration — `pydantic.v1` shim exists but plan the move |
| Django | 5.x (5.0 needs Python 3.10+; 5.1/5.2 *(verify against your toolchain)*) | Async views/ORM (partial), `ASGI`, built-in `{% querystring %}`, composite PKs (5.2) |
| Flask | 3.x | WSGI minimalist core; pair with `gunicorn`; async views supported but request-scoped, not full ASGI |

**Fallback rows**:
- Pydantic v1 codebase → keep v1 until you can do the v2 migration in one pass; mixing `pydantic.v1` and v2 models in one validation graph is a known foot-gun.
- Sync-only WSGI deploy (Flask/old Django) under high concurrency → scale with process workers (`gunicorn -w`), not async; true async throughput needs an ASGI stack (FastAPI / Django ASGI).

## ORM & Database Engine Floors

| Component | Floor assumed by this plugin | Reason |
|-----------|------------------------------|--------|
| PostgreSQL | 14+ baseline; 16 for new clusters | `MERGE` (15), logical replication improvements (16), `jsonb` subscripting (14); 16 is the safe modern target |
| MySQL | 8.0+ | CTEs, window functions, `JSON` functions, instant DDL |
| Prisma (TS) | 5.x current | `relationJoins`, typed SQL, driver adapters; migrations via `prisma migrate` |
| Drizzle (TS) | current stable | SQL-first typed queries, lightweight migrations (`drizzle-kit`) |
| TypeORM (TS) | 0.3.x | Decorator/DataMapper ORM; pin patch versions — historically volatile *(verify against your toolchain)* |
| Hibernate (JVM) | 6.x | Jakarta Persistence (`jakarta.persistence`), required by Spring Boot 3; 5.x uses `javax.*` and will not work on Boot 3 |
| GORM (Go) | current stable | Struct-tag ORM; prefer explicit `Preload` to dodge N+1 |
| EF Core (.NET) | 8+ (LTS) | `ExecuteUpdate`/`ExecuteDelete` bulk ops, JSON columns, compiled models |
| SQLAlchemy (Python) | 2.0+ | New `select()` 2.0 style, typed `Mapped[...]` ORM, async via `AsyncSession` |
| Redis | 7.x | Functions, `CLIENT NO-EVICT`, ACL v2; use for cache/rate-limit/session stores |

## Usage Rules

1. **Feature-test, then version-pin**: detect capability at runtime where possible (e.g. `typeof fetch`, `Thread.ofVirtual` reflection, `pg_catalog` version query) rather than hard-coding a version comparison.
2. **Every skill claim that names a runtime/framework version links here** — do not restate minimum versions elsewhere; one table to update.
3. **Hedge volatile minutiae**: where this table says *(verify against your toolchain)*, the support landed across several releases or the EOL is near — confirm on the actual CI image / base container before pinning.
4. **Pin in the manifest, not in prose**: lock exact versions in `package.json`/`go.mod`/`pom.xml`/`build.gradle.kts`/`pyproject.toml` + lockfile; this table records floors and headline features, not your pins.

## Related Skills

- `language-detection.md` — routing (marker → stack → agent) before version questions arise
- `model-selection.md` — model/effort to pass with the routed `Task()` call
- system-developer's `version-feature-matrix.md` — Python/C/C++/Bash **language** floors (we link, do not fork)
