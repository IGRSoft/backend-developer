---
name: kotlin-backend
description: >-
  Kotlin for back-end services — coroutines and structured concurrency,
  null-safety, data classes and sealed hierarchies, Spring Boot with
  Kotlin (suspend controllers), and Ktor; Kotlin 2.x features and Java
  interop. Use when writing or reviewing Kotlin services, choosing
  coroutines over Reactor, modeling domains with sealed types, or
  bridging Kotlin and Java/Spring.
---

# Kotlin Back-End

**Idiomatic, null-safe Kotlin services with structured concurrency on Spring or Ktor**

## When to Use

Use this skill when:
- Writing or reviewing a Kotlin back-end service (Spring Boot or Ktor)
- Replacing Reactor `Mono`/`Flux` chains with `suspend` functions + coroutines
- Coordinating concurrent I/O with structured concurrency (`coroutineScope`, `async`)
- Modeling domains with `data class`, `sealed` hierarchies, and exhaustive `when`
- Eliminating NPEs through the type system (nullable vs non-null, `?:`, `?.let`)
- Bridging Kotlin and Java/Spring (platform types, `@JvmStatic`, constructor DI)

Companion: Spring-specific patterns (transactions, JPA, security) live in
[spring-boot](../spring-boot/SKILL.md); this skill covers the Kotlin language
layer on top of (or instead of) Spring.

## The Kotlin 2.x Baseline

Version *floors* live in the matrix — link, do not pin here. This table marks
*which feature arrived when* and the fallback for older toolchains:
[version-feature-matrix](../../_shared/version-feature-matrix.md).

| Need | Marker | Fallback |
|------|--------|----------|
| K2 compiler (default), faster, stricter | Kotlin 2.0+ (default since 2.0) | Kotlin 1.9 (`languageVersion = "1.9"`) |
| Coroutines + structured concurrency | kotlinx.coroutines 1.8+ | callbacks / Reactor |
| `suspend` controllers in Spring | Spring 6 / Boot 3 + Kotlin 1.6+ | Reactor `Mono`/`Flux` |
| Data classes, sealed classes, `when` exhaustiveness | Kotlin 1.x | — (baseline) |
| Sealed *interfaces* | Kotlin 1.5 | sealed class |
| Context parameters (stabilizing) / value classes (perf) | Kotlin 2.2+ (`-Xcontext-parameters`; verify flag) | regular params / wrapper class |
| Kotlin on **Spring Boot 4.x** | Kotlin 2.2+ required by the Boot 4 BOM | stay on Boot 3.5 with Kotlin 1.9/2.x |
| Ktor server | Ktor 2.x/3.x | Spring Boot |

**Platform reality (2026):** Kotlin 2.x with the K2 compiler is the default for
new services and is stricter about smart-cast and nullability than 1.9. Spring
Boot has first-class Kotlin support (`suspend` MVC handlers, coroutine-aware data
repositories); **Spring Boot 4.x requires Kotlin 2.2+** (its BOM manages the 2.2
series) and leans further into Kotlin via Spring Framework 7's JSpecify-based
null-safety, which interops cleanly with Kotlin's nullability. Pin the Kotlin and
coroutines versions in the build file and gate features on the actual toolchain —
floors in the matrix.

## Null-Safety

The type system is the NPE defense — encode "may be absent" as a nullable type
and let the compiler force you to handle it. Never paper over it with `!!`.

```kotlin
fun greeting(user: User?): String =
    user?.name?.takeIf { it.isNotBlank() }   // safe-call chain, short-circuits on null
        ?.let { "Hello, $it" }
        ?: "Hello, guest"                     // Elvis: default for the null case

// Avoid: u!!.name  — throws NPE, defeats the whole point
```

**Platform types** (`String!`) come from Java with unknown nullability. At the
interop boundary, annotate Java with JSpecify/`@Nullable` or assert intent
explicitly at the Kotlin call site — do not let `String!` propagate into your
domain. See Java Interop below.

## Type Modeling: data & sealed

`data class` gives value semantics (`equals`/`hashCode`/`copy`) for DTOs and value
objects. `sealed` hierarchies make the set of cases closed, so `when` is
exhaustive — the compiler flags a missing branch when you add a case. Model
results and domain states this way instead of nullable returns or exceptions.

```kotlin
data class OrderDto(val id: UUID, val total: Money, val status: OrderStatus)

sealed interface PaymentResult {
    data class Authorized(val ref: String) : PaymentResult
    data class Declined(val reason: String) : PaymentResult
    data object GatewayTimeout : PaymentResult
}

fun handle(r: PaymentResult): HttpStatus = when (r) {   // exhaustive — no else needed
    is PaymentResult.Authorized   -> HttpStatus.OK
    is PaymentResult.Declined     -> HttpStatus.PAYMENT_REQUIRED
    PaymentResult.GatewayTimeout  -> HttpStatus.GATEWAY_TIMEOUT
}
```

## Coroutines & Structured Concurrency

Coroutines replace Reactor for most service code: ordinary-looking sequential code
that suspends instead of blocking. **Structured concurrency** is the core rule —
child coroutines are launched in a scope and the scope does not return until all
children finish; one failure cancels the siblings. Use `coroutineScope` for
fan-out, `async`/`await` for parallel results.

```kotlin
suspend fun loadDashboard(userId: UUID): Dashboard = coroutineScope {
    // both run concurrently; scope awaits both, cancels the other if one fails
    val profile = async { profileClient.fetch(userId) }
    val orders  = async { orderClient.recent(userId) }
    Dashboard(profile.await(), orders.await())
}
```

Rules:
- Suspend functions are **main-safe** — push blocking work (JDBC, file I/O) onto
  `Dispatchers.IO` with `withContext(Dispatchers.IO) { … }`; never block the
  default dispatcher.
- Never launch into `GlobalScope` — it leaks; use the structured scope.
- Cancellation is cooperative — suspending calls check it; tight CPU loops must
  call `ensureActive()`.
- Propagate the incoming request's scope so cancellation flows when the client
  disconnects.

## Spring + Kotlin

Spring Boot (3.x and 4.x) understands coroutines directly: declare `suspend`
controller functions and Spring bridges them to the reactive runtime. Use
constructor injection (idiomatic in Kotlin — primary constructor), and keep
`@Transactional` on the service layer exactly as in
[spring-boot](../spring-boot/SKILL.md). On Boot 4.x, raise the Kotlin plugin and
dependency coordinates to the 2.2 series to match the managed dependency set.

```kotlin
@RestController
@RequestMapping("/api/v1/orders")
class OrderController(private val orders: OrderService) {  // primary-constructor DI

    @GetMapping("/{id}")
    suspend fun get(@PathVariable id: UUID): OrderDto =     // suspend handler
        orders.find(id) ?: throw ResponseStatusException(NOT_FOUND)

    @PostMapping
    @ResponseStatus(CREATED)
    suspend fun create(@Valid @RequestBody cmd: CreateOrder): OrderDto =
        orders.create(cmd)
}
```

Bean Validation (`@Valid` + `jakarta.validation` annotations on a `data class`),
Spring Security method authorization, and JPA fetch strategies all behave as in
the Spring Boot skill — apply those patterns unchanged. Object-level
authorization (BOLA / OWASP API1) is still mandatory: see
[api-security](../../quality/api-security/SKILL.md).

## Ktor

Ktor is the lightweight, coroutine-native alternative when you do not want the
Spring footprint. Routing is a coroutine DSL; handlers are `suspend` by default.

```kotlin
fun Application.module() {
    install(ContentNegotiation) { json() }
    install(StatusPages) {
        exception<EntityNotFound> { call, _ -> call.respond(HttpStatusCode.NotFound) }
    }
    routing {
        route("/api/v1/orders") {
            get("/{id}") {
                val id = UUID.fromString(call.parameters["id"])
                call.respond(orderService.find(id) ?: return@get call.respond(NotFound))
            }
            post {
                val cmd = call.receive<CreateOrder>()    // suspending deserialize
                call.respond(HttpStatusCode.Created, orderService.create(cmd))
            }
        }
    }
}
```

Ktor gives you the contract directly (status codes, content negotiation, auth
plugins) — design it against [api-design](../../api/SKILL.md). Persistence is your
choice (Exposed, jOOQ, JDBC) since there is no JPA layer.

## Java Interop

| Concern | Pattern |
|---------|---------|
| Java method returns possibly-null | Treat as nullable at the boundary; do not let `T!` leak — assign to `T?` |
| Calling Kotlin `object`/companion from Java | `@JvmStatic` on the member; `@JvmField` to expose a plain field |
| Overloaded calls from Java for default args | `@JvmOverloads` on the function/constructor |
| Checked exceptions Java expects | `@Throws(IOException::class)` so Java sees the signature |
| Kotlin `data class` as a JPA entity | Prefer a regular `class` with `var` fields for entities — `data class` equality fights Hibernate identity; keep `data class` for DTOs |

## Build & Test (single scoped commands)

```bash
./gradlew test                   # Gradle (Kotlin DSL): run the suite
./gradlew check                  # tests + ktlint/detekt verification
./gradlew ktlintCheck            # style only
```

Use one scoped invocation at a time (no `cd`-chains). Test with JUnit 5 +
`kotlinx-coroutines-test` (`runTest { … }` for `suspend` code, virtual time for
delays). Stand up real dependencies with Testcontainers for integration — see
[be-testing](../../quality/be-testing/SKILL.md). CI gate: **unit + integration
green AND `osv-scanner`/`trivy` clean** for supply-chain CVEs.

```kotlin
@Test
fun `loadDashboard fans out concurrently`() = runTest {
    val dash = loadDashboard(userId)
    assertEquals(expected, dash)
}
```

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| `NullPointerException` from a Java-returned value | Platform type `T!` leaked unchecked | Bind to `T?` at the interop edge; handle null | this file, Java Interop |
| Coroutine work outlives the request / leaks | Launched in `GlobalScope` | Use the structured `coroutineScope`/request scope | this file, Coroutines |
| Event loop / dispatcher starved, latency spikes | Blocking JDBC call on a coroutine dispatcher | `withContext(Dispatchers.IO) { … }` | this file, Coroutines |
| `when` compiles but misses a new case | `when` used as a statement (not expression) | Make it an expression / use sealed type so it's exhaustive | this file, Type Modeling |
| Hibernate entity equality breaks with `data class` | `data class` `equals`/`hashCode` over mutable id | Use a plain `class` for entities; `data class` only for DTOs | this file, Java Interop |
| Any user reads any record by changing the ID | No object-level authorization (BOLA) | `@PreAuthorize` ownership check / Ktor auth plugin | [api-security](../../quality/api-security/SKILL.md) API1 |
| `suspend` controller returns 500 with reactor error | Blocking inside a suspend handler | Offload to `Dispatchers.IO`; keep handler main-safe | this file, Coroutines |

## Related Skills

- [spring-boot](../spring-boot/SKILL.md) — transactions, JPA/Hibernate, Spring Security applied with Kotlin
- [api-design](../../api/SKILL.md) — REST/GraphQL contract these handlers implement
- [database-engineering](../../data/SKILL.md) — schema, migrations, and query tuning (Exposed/jOOQ/JPA)
- [secure-coding](../../_shared/secure-coding/SKILL.md) — injection-safe queries, secrets hygiene, safe errors
- [api-security](../../quality/api-security/SKILL.md) — OWASP API Top 10 auth-boundary review
- [be-testing](../../quality/be-testing/SKILL.md) — `runTest`, coroutine test dispatchers, Testcontainers
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — Kotlin / coroutines / Spring version minimums
