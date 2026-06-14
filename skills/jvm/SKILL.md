---
name: jvm-skills
description: >-
  JVM back-end skills navigation — Spring Boot (Java) and Kotlin services.
  Use when writing or reviewing Spring Boot / JVM services, JPA mapping,
  or Kotlin back-ends.
---

# JVM Back-End Skills

**Framework selection and navigation for Spring Boot (Java) and Kotlin service development**

## Framework Selection Table (canonical)

Every JVM back-end decision starts here. Pick the framework/feature that fits the runtime you target; if your platform is pinned lower, use the fallback column.

| Need | Current line | Fallback |
|------|--------------|----------|
| Annotation-driven REST + DI + auto-config | Spring Boot 4.x (Java 25/21) | Spring Boot 3.5/3.x (Java 17+) |
| `jakarta.*` namespace (Servlet, Persistence, Validation) | Spring Boot 4.x / 3.x | `javax.*` on Boot 2.x (EOL) — do not mix |
| Records as request/response DTOs | records (since Java 17) | classes with Lombok `@Value` |
| Virtual threads for blocking I/O endpoints | opt-in `spring.threads.virtual.enabled` (since Java 21 + Boot 3.2; JDK 24+ recommended) | bounded platform-thread pool / WebFlux |
| Reactive non-blocking stack | Spring WebFlux (Reactor) | MVC + virtual threads (simpler) |
| Coroutine-based services / `suspend` controllers | Kotlin 2.3 on Spring 6/7 | Reactor `Mono`/`Flux` |
| Null-safety enforced at compile time | Kotlin 2.x (K2) | Java + JSpecify `@Nullable` + NullAway |
| Sealed hierarchies for domain modeling | Kotlin `sealed` / Java `sealed` (since Java 17) | enums + visitor |
| Pattern matching `switch` over sealed types | `switch` patterns (since Java 21) | `instanceof` chains / Kotlin `when` |
| GraalVM native image (fast startup, low RSS) | Spring AOT + GraalVM (Boot 3+) | JIT JVM (default; safest) |
| Lightweight non-Spring HTTP server (Kotlin) | Ktor 3.x | Spring Boot (batteries-included) |
| Build + reproducible deps | Gradle 9.x (Kotlin DSL) or Maven 3.9 | either — pin the wrapper |

**Platform reality (2026):** Spring Boot 4.x is the current line, built on Spring Framework 7 (Jakarta EE 11) and running on the `jakarta.*` namespace; Boot 3.5 is the supported fallback and Boot 2.x (`javax.*`) is EOL — new services start on the current line. Java 25 is the current LTS; Java 21 is the prior LTS and Java 17 the Spring Boot 4 minimum (see the matrix). Virtual threads are opt-in (`spring.threads.virtual.enabled`, JDK 24+ recommended), not default-on. Kotlin 2.x (K2 compiler) is the default for Kotlin services, with Boot 4 requiring Kotlin 2.2+. Library support lags platform releases, so gate on the actual versions in your `pom.xml` / `build.gradle.kts` rather than trusting version tables from memory.

Per-feature platform minimums: skill `version-feature-matrix` (`../_shared/version-feature-matrix.md`).

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Build Spring Boot REST controllers, DI, transactions | [spring-boot/SKILL.md](spring-boot/SKILL.md) |
| Map entities with JPA/Hibernate, kill N+1 queries | [spring-boot/SKILL.md](spring-boot/SKILL.md) > JPA & Hibernate |
| Validate request bodies (Bean Validation) | [spring-boot/SKILL.md](spring-boot/SKILL.md) > Bean Validation |
| Secure endpoints (Spring Security, method auth) | [spring-boot/SKILL.md](spring-boot/SKILL.md) > Spring Security |
| Write reactive non-blocking endpoints (WebFlux) | [spring-boot/SKILL.md](spring-boot/SKILL.md) > WebFlux |
| Write idiomatic Kotlin services, coroutines, null-safety | [kotlin-backend/SKILL.md](kotlin-backend/SKILL.md) |
| Use coroutines + structured concurrency on the back-end | [kotlin-backend/SKILL.md](kotlin-backend/SKILL.md) > Coroutines |
| Build a Ktor service | [kotlin-backend/SKILL.md](kotlin-backend/SKILL.md) > Ktor |
| Design the REST/GraphQL contract first | [api-design](../api/SKILL.md) |
| Model the schema, migrations, indexing | [database-engineering](../data/SKILL.md) |
| Harden auth boundaries against OWASP API Top 10 | [api-security](../quality/api-security/SKILL.md) |
| Run unit + integration tests (Testcontainers) | [be-testing](../quality/be-testing/SKILL.md) |

## Decision Tree

```
JVM back-end task?
├── Which framework/feature fits my platform? → Framework Selection Table (above)
├── Java + Spring Boot service → spring-boot/SKILL.md
│   ├── REST controllers + DI → spring-boot/SKILL.md > Controllers & DI
│   ├── @Transactional boundaries → spring-boot/SKILL.md > Transactions
│   ├── JPA mapping / N+1 / fetch joins → spring-boot/SKILL.md > JPA & Hibernate
│   ├── Bean Validation on DTOs → spring-boot/SKILL.md > Bean Validation
│   ├── AuthN/AuthZ → spring-boot/SKILL.md > Spring Security
│   └── Reactive stack → spring-boot/SKILL.md > WebFlux
├── Kotlin service (Spring or Ktor) → kotlin-backend/SKILL.md
│   ├── Coroutines + structured concurrency → kotlin-backend/SKILL.md > Coroutines
│   ├── Null-safety + data/sealed classes → kotlin-backend/SKILL.md > Type Modeling
│   ├── Spring with Kotlin → kotlin-backend/SKILL.md > Spring + Kotlin
│   └── Ktor service → kotlin-backend/SKILL.md > Ktor
├── API contract design → ../api/SKILL.md
├── Schema, migrations, query tuning → ../data/SKILL.md
├── Auth boundaries / OWASP API Top 10 → ../quality/api-security/SKILL.md
└── Tests (unit + Testcontainers integration) → ../quality/be-testing/SKILL.md
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the jvm/ subtree |
| [spring-boot/SKILL.md](spring-boot/SKILL.md) | Spring Boot 3.5/4.x: controllers, DI, transactions, JPA, validation, security, WebFlux |
| [kotlin-backend/SKILL.md](kotlin-backend/SKILL.md) | Kotlin back-ends: coroutines, null-safety, data/sealed classes, Spring + Kotlin, Ktor |

## Related Skills

- [node-skills](../node/SKILL.md) — the TypeScript/Node.js counterpart for service work
- [api-design](../api/SKILL.md) — REST/GraphQL/gRPC contract design the controllers implement
- [database-engineering](../data/SKILL.md) — schema, migrations, indexing behind JPA/Hibernate
- [secure-coding](../_shared/secure-coding/SKILL.md) — injection-safe queries, secrets hygiene, input validation
- [api-security](../quality/api-security/SKILL.md) — OWASP API Security Top 10 auth-boundary review
- [be-testing](../quality/be-testing/SKILL.md) — JUnit 5 + Testcontainers integration tests
- [version-feature-matrix](../_shared/version-feature-matrix.md) — platform minimums per feature
