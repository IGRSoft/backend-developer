# JPA / Hibernate Performance

Deep-dive companion to [../SKILL.md](../SKILL.md) > JPA & Hibernate. Fetch
strategies, N+1 elimination, projections, pagination traps, and batching for
Spring Data JPA on Hibernate 6.x (Boot 3.x).

## Fetch-Strategy Decision Table

| Situation | Strategy | Why |
|-----------|----------|-----|
| You always need a related entity with the parent | `join fetch` in the query | One round-trip, no N+1 |
| You sometimes need it, conditionally | `@EntityGraph(attributePaths = …)` per query | Reuses one method, declares fetch at call site |
| You only need a few columns of the relation | DTO / interface projection | Skips entity hydration entirely |
| Many parents each with a small collection | `@BatchSize` (IN-clause batching) | Turns N+1 into N/batch queries |
| Association rarely touched | `FetchType.LAZY` (default for `@ManyToOne` only after override) | No cost until accessed |

**Never** set `FetchType.EAGER` on a mapping to "fix" N+1 — it makes *every*
query eager, including ones that do not need the relation, and it stacks
(cartesian explosion) when an entity has multiple eager collections.

## Detecting N+1

Turn on SQL counting in tests so a regression fails the build, not production:

```properties
# application-test.properties
spring.jpa.show-sql=true
logging.level.org.hibernate.SQL=DEBUG
spring.jpa.properties.hibernate.generate_statistics=true
```

Assert the query count in an integration test (Hibernate `Statistics`):

```java
@DataJpaTest
class OrderRepositoryTest {
    @Autowired OrderRepository repo;
    @Autowired EntityManagerFactory emf;

    @Test
    void listWithItems_runsOneQuery() {
        var stats = emf.unwrap(SessionFactory.class).getStatistics();
        stats.clear();

        var orders = repo.findWithItems(CUSTOMER_ID);
        orders.forEach(o -> o.getItems().size());   // force the collection

        assertThat(stats.getPrepareStatementCount()).isEqualTo(1L);  // not 1 + N
    }
}
```

A k6 latency report on the endpoint (p95 climbing with row count) is the
runtime symptom; the statement-count assertion is the unit-level guard. Evidence
for a review = the before/after statement count and the SQL log, not a profiler
flamegraph.

## join fetch vs @EntityGraph

```java
// Explicit fetch join — query owns the fetch plan
@Query("select o from Order o join fetch o.items where o.id = :id")
Optional<Order> findByIdWithItems(@Param("id") UUID id);

// EntityGraph — declarative, composes with derived queries
@EntityGraph(attributePaths = {"items", "customer"})
@Query("select o from Order o where o.id = :id")
Optional<Order> findDetailById(@Param("id") UUID id);
```

Use `join fetch` when the query is hand-written anyway. Use `@EntityGraph` when
you want to add a fetch plan to a derived/named query without rewriting JPQL.
You can fetch **at most one collection** per query — fetching two collections
produces a cartesian product. Fetch one collection per query, or use
`@BatchSize` for the others.

## The Pagination + Collection-Fetch Trap

```java
// BROKEN: Hibernate logs "applying in memory" and pages AFTER loading everything
@Query("select o from Order o join fetch o.items")
Page<Order> findAllPaged(Pageable p);   // HHH90003004 — in-memory pagination
```

When you `join fetch` a collection and paginate, the row count no longer maps to
entity count, so Hibernate fetches **all** rows and paginates in memory —
silently O(table). Fix with a two-query plan: page the IDs (no join), then fetch
the collection for that page.

```java
@Query("select o.id from Order o order by o.createdAt desc")
Page<UUID> pageIds(Pageable p);

@Query("select distinct o from Order o join fetch o.items where o.id in :ids")
List<Order> fetchByIds(@Param("ids") List<UUID> ids);
```

## @BatchSize

For N parents each carrying a small lazy collection where a fetch join would be
awkward, batch the secondary loads:

```java
@OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
@BatchSize(size = 50)                       // loads up to 50 collections per IN query
List<LineItem> items;
```

Or globally:

```properties
spring.jpa.properties.hibernate.default_batch_fetch_size=50
```

This converts 1 + N into 1 + ceil(N/50) round-trips — the cheapest N+1 mitigation
when you cannot restructure the query.

## DTO and Interface Projections

When the response needs a subset of columns, skip entity hydration entirely. This
also sidesteps `LazyInitializationException`: you never touch a lazy field
outside the session because there is no managed entity.

```java
// Constructor (record) projection — typed, explicit
@Query("""
    select new com.acme.api.OrderSummary(o.id, o.status, count(i))
    from Order o left join o.items i
    group by o.id, o.status
    """)
List<OrderSummary> summaries();

record OrderSummary(UUID id, OrderStatus status, long itemCount) {}

// Interface projection — Spring builds the proxy
interface OrderView {
    UUID getId();
    OrderStatus getStatus();
}
List<OrderView> findByCustomerId(UUID customerId);
```

Always map to a DTO **inside** the `@Transactional(readOnly = true)` boundary, then
return the DTO. Returning a managed entity to the controller is what triggers
lazy-load exceptions during JSON serialization.

## readOnly Query Tuning

`@Transactional(readOnly = true)` lets Hibernate set flush mode to `MANUAL` and
skip dirty-checking/snapshotting of loaded entities — measurably cheaper for
large read result sets, and it documents intent. Pair with projections so the
persistence context stays small.

## Related

- [../SKILL.md](../SKILL.md) — Spring Boot service patterns (transactions, controllers)
- [database-engineering](../../../data/SKILL.md) — indexing the columns these queries filter/sort on, migration safety
- [be-performance](../../../quality/be-performance/SKILL.md) — k6 load testing and latency-report evidence
- [version-feature-matrix](../../../_shared/version-feature-matrix.md) — Hibernate / Spring Data versions
