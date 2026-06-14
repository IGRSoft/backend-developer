---
name: spring-boot
description: >-
  Spring Boot 3.x back-end patterns — REST controllers, constructor DI,
  @Transactional boundaries, JPA/Hibernate mapping (N+1, fetch joins, DTO
  projection), Bean Validation, Spring Security, and WebFlux reactive
  endpoints on the jakarta.* namespace. Use when writing or reviewing
  Spring Boot services, mapping JPA entities, securing endpoints, or
  choosing the blocking-vs-reactive stack.
---

# Spring Boot 3.x

**Annotation-driven REST services with correct DI, transactions, persistence, and auth boundaries**

## When to Use

Use this skill when:
- Building or reviewing a Spring Boot 3.x REST or reactive service
- Wiring dependency injection and deciding bean scopes
- Placing `@Transactional` boundaries and reasoning about rollback rules
- Mapping JPA/Hibernate entities and eliminating N+1 queries
- Validating request payloads with Bean Validation (`jakarta.validation`)
- Configuring Spring Security (authentication, method-level authorization)
- Choosing between blocking MVC (+ virtual threads) and WebFlux reactive

Routing: deep JPA/Hibernate performance work (fetch strategies, projections,
batch sizing, pagination) → [references/jpa-performance.md](references/jpa-performance.md).

## The Namespace Rule (Boot 3.x = `jakarta.*`)

| Job | Import | Do not use |
|-----|--------|------------|
| Persistence annotations | `jakarta.persistence.*` | `javax.persistence.*` (Boot 2.x) |
| Validation constraints | `jakarta.validation.*` | `javax.validation.*` |
| Servlet API | `jakarta.servlet.*` | `javax.servlet.*` |

Spring Boot 3.x requires Java 17+ and runs entirely on the `jakarta.*`
namespace. Mixing a `javax.*` library in silently breaks transaction and
validation weaving. Pin Boot in `pom.xml`/`build.gradle.kts` and let the BOM
carry transitive versions. Platform minimums: skill `version-feature-matrix`
(`../../_shared/version-feature-matrix.md`).

## Controllers & DI

Use **constructor injection** (not field `@Autowired`) — it makes
dependencies final, testable, and impossible to forget. A single constructor
needs no annotation. Map request/response bodies with **records** (Java 17).

```java
@RestController
@RequestMapping("/api/v1/orders")
class OrderController {
    private final OrderService orders;

    OrderController(OrderService orders) {   // constructor injection, no @Autowired
        this.orders = orders;
    }

    @GetMapping("/{id}")
    ResponseEntity<OrderResponse> get(@PathVariable UUID id) {
        return orders.find(id)
            .map(OrderResponse::from)
            .map(ResponseEntity::ok)
            .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping
    ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrder cmd) {
        var saved = orders.create(cmd);
        return ResponseEntity
            .created(URI.create("/api/v1/orders/" + saved.id()))
            .body(OrderResponse.from(saved));
    }
}

record CreateOrder(@NotNull UUID customerId,
                   @NotEmpty List<@Valid LineItem> items) {}
```

Keep controllers thin: parse, validate, delegate to a service, map the result.
No persistence or transaction logic in the controller. Contract design (status
codes, pagination, versioning) lives in [api-design](../../api/SKILL.md).

## Error Handling

Centralize error-to-response mapping with `@RestControllerAdvice` so every
endpoint returns a consistent body (RFC 9457 `ProblemDetail`). Never leak stack
traces or SQL to clients — see [secure-coding](../../_shared/secure-coding/SKILL.md).

```java
@RestControllerAdvice
class ApiExceptionHandler {
    @ExceptionHandler(EntityNotFoundException.class)
    ProblemDetail notFound(EntityNotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ProblemDetail invalid(MethodArgumentNotValidException e) {
        var pd = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        pd.setProperty("errors", e.getFieldErrors().stream()
            .collect(toMap(FieldError::getField, FieldError::getDefaultMessage)));
        return pd;
    }
}
```

## Transactions

Annotate the **service layer**, not the repository or controller. `@Transactional`
is a proxy boundary — self-invocation (`this.method()`) bypasses it. Default
rollback fires only on unchecked exceptions; add `rollbackFor` for checked ones.

```java
@Service
class OrderService {
    private final OrderRepository repo;
    private final PaymentClient payments;

    OrderService(OrderRepository repo, PaymentClient payments) {
        this.repo = repo; this.payments = payments;
    }

    @Transactional                              // write boundary spans the whole unit of work
    public Order create(CreateOrder cmd) {
        var order = repo.save(Order.from(cmd));
        payments.authorize(order);              // if this throws, the save rolls back
        return order;
    }

    @Transactional(readOnly = true)             // read-only: Hibernate skips dirty checking
    public Optional<Order> find(UUID id) {
        return repo.findById(id);
    }
}
```

Boundary rules:
- One transaction per unit of work; do not span user think-time.
- `readOnly = true` on queries — enables flush-mode `MANUAL` and JDBC hints.
- Never call a remote API or sleep inside an open transaction holding row locks.
- Idempotency for retried writes (a unique business key + `ON CONFLICT`/`@Version`)
  belongs at this layer — see [api-design](../../api/SKILL.md) > Idempotency.

## JPA & Hibernate

Default all associations to `FetchType.LAZY` (even `@ManyToOne`, which is EAGER
by default — override it). Lazy + iteration is what creates the **N+1 query**
problem; fix it with a fetch join or `@EntityGraph`, not by switching to EAGER.

```java
@Entity
class Order {
    @Id @GeneratedValue UUID id;

    @ManyToOne(fetch = FetchType.LAZY)          // override EAGER default
    @JoinColumn(name = "customer_id")
    Customer customer;

    @OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
    List<LineItem> items = new ArrayList<>();

    @Version long version;                       // optimistic locking
}

interface OrderRepository extends JpaRepository<Order, UUID> {
    // fetch join collapses N+1 into one query
    @Query("select o from Order o join fetch o.items where o.customer.id = :cid")
    List<Order> findWithItems(@Param("cid") UUID customerId);
}
```

Full fetch-strategy decision table, `@EntityGraph` vs fetch join, the pagination
+ join trap, batch sizing, and DTO projections: [references/jpa-performance.md](references/jpa-performance.md).

## Bean Validation

Constrain DTOs with `jakarta.validation` annotations; trigger with `@Valid` on
the controller parameter. Validate at the boundary so the service never sees a
malformed payload. Bean Validation is **input shape only** — it is not an
authorization check (see Spring Security below and OWASP API3 in
[api-security](../../quality/api-security/SKILL.md)).

```java
record CreateUser(
    @NotBlank @Size(max = 100) String name,
    @Email String email,
    @Min(18) int age,
    @Pattern(regexp = "^[A-Z]{2}$") String countryCode) {}

// custom cross-field rule
@Target(TYPE) @Retention(RUNTIME)
@Constraint(validatedBy = DateRangeValidator.class)
@interface ValidDateRange {
    String message() default "end must be after start";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}
```

## Spring Security

Configure a `SecurityFilterChain` bean (no `WebSecurityConfigurerAdapter` in 6.x).
Authenticate with OAuth2/OIDC resource-server (JWT) for APIs; enforce
authorization at the method layer so it cannot be bypassed by a new endpoint.

```java
@Configuration
@EnableMethodSecurity                            // turns on @PreAuthorize
class SecurityConfig {
    @Bean
    SecurityFilterChain api(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())                    // stateless JWT API
            .authorizeHttpRequests(a -> a
                .requestMatchers("/api/v1/public/**").permitAll()
                .anyRequest().authenticated())
            .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()))
            .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
            .build();
    }
}

@Service
class DocumentService {
    @PreAuthorize("@acl.canRead(#id, authentication)")   // object-level check (BOLA defense)
    public Document read(UUID id) { /* ... */ }
}
```

Method-level `@PreAuthorize` with an ownership/ACL check is the primary defense
against **BOLA (OWASP API1)** — never trust an ID from the request to belong to
the caller. URL-pattern rules alone are **broken function-level authorization
(API5)**. Full review checklist: [api-security](../../quality/api-security/SKILL.md).

## WebFlux: When (and When Not)

Use **blocking MVC + virtual threads** (Java 21, `spring.threads.virtual.enabled=true`)
as the default — it gives you high concurrency with ordinary imperative code and
a normal stack trace. Reach for **WebFlux** only when you need backpressure, are
already non-blocking end-to-end (R2DBC, reactive clients), or stream large
results. Do not block a Reactor thread (`block()`, JDBC) inside WebFlux.

```java
@RestController
class PriceController {
    private final PriceClient client;          // returns Mono/Flux

    PriceController(PriceClient client) { this.client = client; }

    @GetMapping("/api/v1/prices/{sku}")
    Mono<Price> price(@PathVariable String sku) {
        return client.fetch(sku)               // non-blocking all the way down
            .timeout(Duration.ofSeconds(2))
            .onErrorResume(TimeoutException.class, e -> Mono.just(Price.unknown(sku)));
    }
}
```

For Kotlin services prefer `suspend` controllers + coroutines over raw Reactor —
see [kotlin-backend](../kotlin-backend/SKILL.md) > Coroutines.

## Build & Test (single scoped commands)

```bash
./mvnw -q verify                 # Maven: compile + unit + integration + checks
./gradlew test                   # Gradle: run the test suite
./gradlew check                  # Gradle: tests + verification tasks
```

Use one scoped invocation at a time (no `cd`-chains). Slice tests with
`@WebMvcTest` (controller layer, mocked services) and `@DataJpaTest` (repository
layer, real JPA). Spin a real PostgreSQL with Testcontainers for integration —
see [be-testing](../../quality/be-testing/SKILL.md). The CI gate is **unit +
integration green AND `osv-scanner`/`trivy` clean** (supply-chain CVEs).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| One list endpoint fires hundreds of `SELECT`s | Lazy association iterated in a loop (N+1) | Fetch join or `@EntityGraph` on the query | [jpa-performance.md](references/jpa-performance.md) § n+1 |
| `LazyInitializationException` in the controller/serializer | Session closed before lazy field accessed | Fetch what you need in the query; map to a DTO inside the transaction | [jpa-performance.md](references/jpa-performance.md) § projections |
| `@Transactional` method never rolls back | Self-invocation or checked exception | Call through the bean proxy; add `rollbackFor` | this file, Transactions |
| Validation annotations ignored | Missing `@Valid` on the parameter | Add `@Valid` to the `@RequestBody`/`@PathVariable` | this file, Bean Validation |
| `firstResult/maxResults specified with collection fetch; applying in memory` | Pagination + join fetch on a collection | Two-query plan: page IDs, then fetch | [jpa-performance.md](references/jpa-performance.md) § pagination |
| Any user can read any record by changing the ID | No object-level authorization (BOLA) | `@PreAuthorize` ownership/ACL check | [api-security](../../quality/api-security/SKILL.md) API1 |
| `block()/blockFirst()/blockLast()` error under WebFlux | Blocking call on an event-loop thread | Use reactive client, or switch to MVC + virtual threads | this file, WebFlux |
| Bean not found / unsatisfied dependency at startup | Component not scanned or wrong package | Place beans under the `@SpringBootApplication` package | this file, Controllers & DI |

## Deep-Dive References

- [references/jpa-performance.md](references/jpa-performance.md) — fetch-strategy
  decision table, N+1 detection, `join fetch` vs `@EntityGraph`, the
  pagination-with-collection-fetch trap, `@BatchSize`, DTO/interface
  projections, and `readOnly` query tuning

## Related Skills

- [kotlin-backend](../kotlin-backend/SKILL.md) — Spring with Kotlin, coroutines instead of Reactor
- [api-design](../../api/SKILL.md) — REST contract, status codes, pagination, idempotency these controllers implement
- [database-engineering](../../data/SKILL.md) — schema design and migration safety behind the JPA entities
- [secure-coding](../../_shared/secure-coding/SKILL.md) — SQL injection (parameter binding), secrets hygiene, safe error messages
- [api-security](../../quality/api-security/SKILL.md) — OWASP API Top 10 auth-boundary review for the security config
- [be-testing](../../quality/be-testing/SKILL.md) — `@WebMvcTest`, `@DataJpaTest`, Testcontainers integration
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — Spring Boot / Java / Hibernate version minimums
