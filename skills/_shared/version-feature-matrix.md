---
name: version-feature-matrix
description: Canonical lookup mapping back-end runtimes and frameworks (Node.js 22/24 LTS + TypeScript 5.9, Go 1.24-1.26 (supported 1.25/1.26), Java 17/21/25 LTS + Spring Boot 4.x/3.5 + Kotlin 2.x, Python web frameworks, Ruby 4.0/Rails 8.x, PHP 8.2+/Laravel 12/Symfony 7.4 LTS, .NET 10 LTS + ASP.NET Core, ORM/DB engine floors incl. MongoDB) to minimum versions and headline features. Reference before asserting feature availability or pinning a runtime/framework.
---

# Version & Feature Matrix

Canonical lookup for "which runtime/framework version do I need for this feature, and what do I get". Every version-specific claim in this plugin's skills should link here rather than restate minimums. Runtime and framework support shifts between minor releases — for entries marked *(verify against your toolchain)*, confirm against your environment (`node --version`, `tsc --version`, `go version`, `java --version`, `mvn -v`, `python3 -VV`) and the vendor's release notes before relying on a feature in CI.

## Node.js & TypeScript

| Runtime / Tool | Status anchor | What you get (one line) |
|----------------|---------------|-------------------------|
| Node.js 20 (LTS "Iron") | EOL 2026-04-30 — no further patches *(retired)* | Final maintenance line; migrate off — stable require(ESM) (20.19+), permission model, `--env-file`, V8 11.3 |
| Node.js 22 (LTS "Jod") | Maintenance LTS | `require()` of ESM (stable/unflagged), stable WebSocket client + `glob` (`node:fs`), `node --run`, `--env-file`, V8 12.4 — needs `disposablestack` polyfill for `using`/`Symbol.dispose` |
| Node.js 24 (LTS "Krypton") | Active LTS — the safe baseline for new services | Native `using`/`await using` + `Symbol.dispose` (V8 13.6, stable 24.2), `--permission` (stable), npm 11, AsyncContext upgrades |
| TypeScript 5.x | 5.9 current (5.0 → 5.9) | `const` type params, decorators (TC39 stage 3), `using`/`await using` (5.2), `satisfies`, inferred type predicates (5.5), `import defer` (5.9), `--isolatedDeclarations` (5.5) |
| TypeScript native port (tsgo / TS 7) | Preview — TS 7.0 beta (Apr 2026), `@typescript/native-preview` | Go-based `tsc`, ~10x faster typecheck; preview only — declaration emit + full `--build` incomplete; keep classic `tsc` as the authoritative gate |

**Fallback rows**:
- No global `fetch` (Node < 18) → `undici` or `node-fetch` as a dependency; never assume `fetch` on the older LTS without a polyfill.
- No stable `node:test` (Node < 20) → keep `vitest`/`jest`; the in-tree runner (stable on current LTS) suits libraries / simple services, but most service teams still pin Vitest for watch mode, snapshots, and coverage/mocking DX.
- `using`/`await using` need TS 5.2+ **and** a runtime with `Symbol.dispose`/`asyncDispose` (native on the newest LTS line; the prior LTS needs the `disposablestack` polyfill + `lib: esnext.disposable`) — gate on both, not the TS version alone.

## Go

| Version | Status anchor | What you get (one line) |
|---------|---------------|-------------------------|
| 1.24 | Released 2025-02 — EOL 2026-02 *(verify against your toolchain)* | Generic type aliases, `go.mod` `tool` directive, Swiss-Tables maps, `os.Root` (path-traversal-safe FS), `runtime.AddCleanup`, weak pointers, `testing/synctest` (experimental) |
| 1.25 | Released 2025-08 — current supported floor | `testing/synctest` stable, `sync.WaitGroup.Go`, container-aware `GOMAXPROCS` (default), `encoding/json/v2` + Green Tea GC as experiments |
| 1.26 | Released 2026-02 — current minor | Green Tea GC default, `new(expr)`, self-referential generic type params, `errors.AsType[T]`, `slog.NewMultiHandler`, `crypto/hpke` (RFC 9180) |

**Fallback rows**:
- loopvar (1.22) and `ServeMux` method/wildcard routing (1.22) are BASELINE on every supported toolchain — no `i:=i` shadow, no third-party router needed for simple routing. Only matters on pinned legacy (<1.22) builds.
- range-over-func iterators + `iter` package are BASELINE (1.23, below floor); adopt freely. Pre-1.23 fallback: return slices/channels or callback funcs.
- `encoding/json/v2` is EXPERIMENTAL through 1.26 (`GOEXPERIMENT=jsonv2`); it becomes the default `encoding/json` backend in 1.27. Ship on `encoding/json` (v1) until then.
- Generics floor is 1.18 — assume present on all supported versions here.

## Java, Spring Boot & Kotlin

| Runtime / Framework | Status anchor | What you get (one line) |
|---------------------|---------------|-------------------------|
| Java 17 (LTS) | Conservative baseline — Spring Boot 4 minimum; free updates to 2026-09 | Records, sealed classes, pattern matching for `instanceof`, switch expressions, text blocks |
| Java 21 (LTS) | Prior LTS — premier support to 2028-09 | Virtual threads (Project Loom, `Thread.ofVirtual`), pattern matching for `switch`, record patterns, sequenced collections |
| Java 25 (LTS) | Current LTS — GA 2025-09-16, preferred for new services | Virtual threads + structured concurrency mature, scoped values, pattern-matching refinements, generational ZGC default; first-class on Spring Boot 4 |
| Spring Boot 4.x | Current line — GA 2025-11-20, on Spring Framework 7 (Jakarta EE 11); Java 17 min, Java 25 first-class | `jakarta.*` namespace, Jackson 3 default, JSpecify null-safety, modularized jars, first-class API versioning + HTTP Service Clients (`@ImportHttpServices`), virtual-thread support (opt-in `spring.threads.virtual.enabled`), Hibernate 7 |
| Spring Boot 3.5 | Supported fallback — final 3.x minor, OSS support to 2026-06-30; Java 17 baseline | `jakarta.*` namespace, Micrometer/OpenTelemetry observability, Spring AOT/GraalVM native images, virtual-thread support (3.2+, opt-in), Hibernate 6 |
| Kotlin 2.x | 2.0 K2 compiler → 2.3 current (2025-12); Spring Boot 4 requires 2.2+ | K2 compiler (faster, stricter), stable `data object`, context parameters (preview, 2.2+), improved smart casts; coroutines/`kotlinx.coroutines` versioned independently — pin in the build file |

**Fallback rows**:
- Virtual threads need Java 21+ **and** `spring.threads.virtual.enabled=true` (opt-in — never default-on; Spring Boot 3.2+ wires them when the property is set). A newer JDK (24+) is recommended for the smoothest pinning behavior. On Java 17 / older Boot keep the platform-thread pool and tune `server.tomcat.threads.max`.
- Not ready for Boot 4 (Jackson 3 / JSpecify / modularized-starter churn, or a transitive lib still on Jackson 2 only)? Stay on Spring Boot 3.5 — OSS support runs to 2026-06; both lines share the `jakarta.*` namespace and every pattern in `skill: spring-boot`.
- The `javax.*` → `jakarta.*` migration is the hard gate moving to Spring Boot 3+ — a library still on `javax.servlet` will not load; check transitive deps, not just your code.
- Pre-Java 17 (8/11) → no records/sealed types; use Lombok or plain classes and stay on Spring Boot 2.7.x (its own EOL — *(verify against your toolchain)*).

## Python Web Frameworks

Python **language** minimums (3.12-3.14, free-threading, t-strings, deferred annotations) are **not forked here** — the `python-backend-developer` agent defers language-version questions to `system-developer`'s `version-feature-matrix.md`. This table covers only the web-framework layer.

| Framework | Status anchor | What you get (one line) |
|-----------|---------------|-------------------------|
| FastAPI | current 0.1xx (0.136.x) — Pydantic **v2 required** | ASGI, Pydantic v2 models, dependency injection, automatic OpenAPI; v1 support dropped (min `pydantic>=2.7`), default strict `Content-Type` JSON check; needs an ASGI server (`uvicorn`/`hypercorn`) |
| Pydantic | v2 (Rust core), current 2.13.x | ~5-50x faster validation than v1, `model_validate`, stricter coercion; v1→v2 is a breaking migration — `pydantic.v1` shim is temporary, plan the move |
| Django | 5.2 LTS (2025-04, support ~2028-04) anchor; 6.0 (2025-12) current STS | `CompositePrimaryKey` (5.2), built-in Tasks framework + AsyncPaginator + native CSP (6.0); async views/ORM (partial), `ASGI`; 6.0 needs Python 3.12+ |
| Flask | 3.1 (Werkzeug 3.1) current line | WSGI minimalist core; pair with `gunicorn`; async views supported but request-scoped, not full ASGI |

**Fallback rows**:
- Pydantic v1 codebase → keep v1 until you can do the v2 migration in one pass; mixing `pydantic.v1` and v2 models in one validation graph is a known foot-gun. Current FastAPI dropped v1 — pin an older FastAPI only as a stopgap and migrate to v2 (the `pydantic.v1` shim is temporary, not a destination).
- Sync-only WSGI deploy (Flask/old Django) under high concurrency → scale with process workers (`gunicorn -w`), not async; true async throughput needs an ASGI stack (FastAPI / Django ASGI).

## Ruby & Rails

| Runtime / Framework | Status anchor | What you get (one line) |
|---------------------|---------------|-------------------------|
| Ruby 4.0.x | Current major (4.0.0 2025-12, ~bi-monthly patches) — Rails 8 needs **>= 3.2.0**, 3.3/3.4 recommended | ZJIT compiler (YJIT successor), Ruby Box experimental isolation, Ractor improvements; YJIT enabled by Rails 7.2+ on Ruby 3.3+ |
| Ruby 3.4 / 3.3 | 3.4 active; 3.3 security-only; 3.2 EOL *(verify against your toolchain)* | Minimum supported runtimes for current Rails; 3.2 is the hard Rails 8 floor |
| Rails 8.1 | Current stable (8.1.0 2025-10-22; 8.1.3 latest) — safe baseline for new apps; supported to 2027-10 | Active Job Continuations, `deprecate_association`, Markdown rendering, Local CI (`bin/ci`), `affected_rows`; builds on the 8.0 Solid stack |
| Rails 8.0 | Supported to 2026-11 | Solid Queue/Cache/Cable (DB-backed, drop Redis; SQLite-in-prod viable), Propshaft default asset pipeline, Kamal 2 + Thruster, authentication generator, `params.expect`, `Regexp.timeout=1s` default |
| Rails 7.2 | Maintenance — security-only until 2026-08-09 *(verify against your toolchain)* | `with_connection`, `explain` on relation methods, PG `date`→`Date`, YJIT default on Ruby 3.3+, Puma threads 5→3 |

**Fallback rows**:
- Pre-Rails 8 → no Solid Queue/Cache/Cable: keep Sidekiq/Resque + Redis (jobs), Redis/Memcached (cache), Redis Action Cable adapter; Sprockets instead of Propshaft.
- Pre-Rails 8 → no `params.expect`: use `params.require(...).permit(...)` (functionally equivalent allow-list; weaker error semantics — `500` on a tampered non-hash shape).
- Pre-Rails 7.2 → no `with_connection` / no `explain` on terminal relation methods: rely on implicit per-statement checkout and `relation.explain` only.
- Rails 7.1 is EOL (2025-10-01) — do not pin new work to it; 7.2 is the lowest still-patched line and exits security support 2026-08.

## PHP / Laravel / Symfony

| Runtime / Framework | Status anchor | What you get (one line) |
|---------------------|---------------|-------------------------|
| PHP 8.2 (floor) | Security-only, EOL 2026-12-31 — minimum for current Laravel 12 / Symfony 7.4 LTS | `readonly` props, enums, fibers; prefer 8.3+ for new projects |
| PHP 8.3 | Recommended new-project target — security support to 2027-11 | Typed class constants, `json_validate()`, `#[\Override]`, dynamic class-constant fetch |
| PHP 8.4 (GA, Nov 2024) | Active support | Property hooks, asymmetric visibility (`public private(set)`), array helpers (`array_find`/`array_any`/`array_all`), revamped DOM API |
| PHP 8.5 (GA, Nov 2025) | Active support — verify framework support before adopting | Pipe operator `\|>`, `clone with`, first-class callables in const expr, built-in URI extension |
| Laravel 12 (current stable, Feb 2025) | Requires PHP 8.2+; security to 2027-02-24 | Maintenance-focused release; Laravel has no LTS majors — each major = 18mo bugfix + 2yr security |
| Laravel 13 (Mar 2026) | Newest major | Requires PHP 8.3+ (drops 8.2); supports 8.3/8.4/8.5 |
| Symfony 7.4 (LTS, Nov 2025) | Current Symfony LTS (replaces 6.4); PHP 8.2+ | Bugfix to Nov 2028, security to Nov 2029; bridge release to Symfony 8.0 |

**Fallback rows**:
- Pre-PHP 8.4 → no property hooks/asymmetric visibility: explicit getters/setters + `readonly`/private+getter.
- Pre-PHP 8.3 → no typed class constants / `json_validate()` / `#[\Override]`: untyped const + `json_decode(JSON_THROW_ON_ERROR)` + doc-comment override convention.
- On Laravel < 12 / Symfony < 7.4 → consult that release's own minimum-PHP and EOL; do not assume 8.4 features.

## .NET Runtime & ASP.NET Core

| Runtime / Framework | Status anchor | What you get (one line) |
|---------------------|---------------|-------------------------|
| .NET 8 (LTS) | Prior LTS — EOL 2026-11-10 *(verify against your toolchain)* | Keyed DI, `TimeProvider`, minimal-API `[AsParameters]`+`TypedResults`, `IExceptionHandler` pipeline; C# 12 baseline |
| .NET 9 (STS) | STS — EOL 2026-11-10 (same day as .NET 8) | Interim feature band between the two LTS lines; do not pin service code to an STS |
| .NET 10 (LTS) | Current LTS — released 2025-11-11, EOL 2028-11-14 — safe baseline for new services | Built-in minimal-API validation (`AddValidation()`), OpenAPI 3.1 + native YAML (JSON Schema 2020-12), `ServerSentEvents` result, tighter `IProblemDetailsService`/`IExceptionHandler`; ships C# 14 (extension members, `field` keyword, null-conditional assignment) |
| ASP.NET Core rate limiting | Built-in since .NET 7 (`Microsoft.AspNetCore.RateLimiting`) | Fixed/sliding-window, token-bucket, concurrency limiters; 429 on exceed; distributed via Redis/SQL cache |

**Fallback rows**:
- Pre-.NET 10 minimal-API validation → no built-in `AddValidation()`; use FluentValidation / `MiniValidation` or manual checks (≤ASP.NET Core 9).
- OpenAPI 3.1 + YAML export needs ASP.NET Core 10 → on ≤9 use OpenAPI 3.0 via Swashbuckle/NSwag.
- C# 14 features (extension members, `field`, null-conditional assignment) need the .NET 10 SDK → on older SDKs use explicit backing fields and extension methods only.
- STS lines (.NET 9) are not a service-code baseline — pin to the active LTS for production.

## ORM & Database Engine Floors

| Component | Floor assumed by this plugin | Reason |
|-----------|------------------------------|--------|
| PostgreSQL | 16+ baseline; 18 for new clusters | `MERGE` (15), `jsonb` subscripting (14); 18 adds async I/O, skip-scan index lookups, built-in `uuidv7()`, OAuth — the safe modern target |
| MySQL | 8.4 LTS (8.0 EOL April 2026) | CTEs, window functions, `JSON` functions, instant DDL; 8.4 is the LTS replacing 8.0; 9.x is the Innovation track (vector, HyperGraph) — pin LTS for service code |
| MongoDB | 8.0 LTS | multi-document transactions, `$lookup`, change streams, time-series; 8.0 is the production-recommended LTS (5-year lifecycle), 36% faster reads than 7.0 |
| Prisma (TS) | 6.x current; 7.x Rust-free default | interactive transactions, driver adapters (GA in 6.16), typed SQL; v7 makes the Rust-free TS query compiler the default (3x faster, ESM-first); migrations via `prisma migrate` |
| Drizzle (TS) | current 0.4x stable; v1 in beta | SQL-first typed queries, relational queries, lightweight migrations (`drizzle-kit`) |
| TypeORM (TS) | 0.3.x; 1.0 GA (Node 20+ floor) | Decorator/DataMapper ORM, `DataSource` API; 1.0 (2026-05) is the first major since 2016 — modernizes the platform floor and removes deprecated APIs; pin patch versions *(verify against your toolchain)* |
| Hibernate (JVM) | 6.x (Boot 3.x) / 7.x (Boot 4.x) | Jakarta Persistence (`jakarta.persistence`); 7.x = JPA 3.2 + Jakarta EE 11 + Jakarta Data 1.0 (Boot 4); 6.x = Boot 3.x; 5.x uses `javax.*` and will not work on Boot 3+ |
| Eloquent (Laravel) | Laravel 12 (PHP 8.2+) | `$fillable` allowlist, eager loading via `with()`, `DB::transaction`; ships with Laravel — pin via `laravel/framework` |
| Doctrine ORM (PHP) | 3.x (DBAL 4.x) | Native lazy objects + PHP 8.4 property-hook support (ORM 3.4+); ORM 2.x EOL approaching; ORM 4.0 will require PHP 8.4 |
| GORM (Go) | v2 (`gorm.io/gorm`) | Struct-tag ORM; context-aware API, prepared-stmt cache; prefer explicit `Preload` to dodge N+1 |
| EF Core (.NET) | 10 (LTS); 8 prior LTS | `LeftJoin`/`RightJoin` LINQ operators, named query filters (`IgnoreQueryFilters("name")`), complex types → JSON columns, vector type + `VECTOR_DISTANCE()`; `ExecuteUpdate`/`ExecuteDelete` bulk ops (since 7) bypass change tracker + global query filters; requires .NET 10 SDK/runtime |
| SQLAlchemy (Python) | 2.0+ (current 2.0.50; 2.1 in beta) | New `select()` 2.0 style, typed `Mapped[...]` ORM, async via `AsyncSession` |
| Redis / Valkey | Redis 8 (AGPLv3) or Valkey 8.1+ (BSD-3) | Functions, `CLIENT NO-EVICT`, ACLs, hash-field TTL (7.4+); **license fork** — Redis 8 is AGPLv3 (tri-license), Valkey is the BSD-3 Linux-Foundation drop-in Redis-OSS replacement; same command surface — pick per license posture |

## Usage Rules

1. **Feature-test, then version-pin**: detect capability at runtime where possible (e.g. `typeof fetch`, `Thread.ofVirtual` reflection, `pg_catalog` version query) rather than hard-coding a version comparison.
2. **Every skill claim that names a runtime/framework version links here** — do not restate minimum versions elsewhere; one table to update.
3. **Hedge volatile minutiae**: where this table says *(verify against your toolchain)*, the support landed across several releases or the EOL is near — confirm on the actual CI image / base container before pinning.
4. **Pin in the manifest, not in prose**: lock exact versions in `package.json`/`go.mod`/`pom.xml`/`build.gradle.kts`/`pyproject.toml`/`Gemfile`/`composer.json`/`*.csproj` + lockfile; this table records floors and headline features, not your pins.

## Related Skills

- `language-detection.md` — routing (marker → stack → agent) before version questions arise
- `model-selection.md` — model/effort to pass with the routed `Task()` call
- system-developer's `version-feature-matrix.md` — Python/C/C++/Bash **language** floors (we link, do not fork)
