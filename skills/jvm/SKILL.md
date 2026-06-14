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

| Need | Minimum platform | Fallback |
|------|------------------|----------|
| Annotation-driven REST + DI + auto-config | Spring Boot 3.x (Java 17+) | Spring Boot 2.7 (Java 8/11, `javax.*`) |
| `jakarta.*` namespace (Servlet, Persistence, Validation) | Spring Boot 3.x | `javax.*` on Boot 2.x — do not mix |
| Records as request/response DTOs | Java 17 | classes with Lombok `@Value` |
| Virtual threads for blocking I/O endpoints | Java 21 + Boot 3.2 (`spring.threads.virtual.enabled`) | bounded platform-thread pool / WebFlux |
| Reactive non-blocking stack | Spring WebFlux (Reactor) | MVC + virtual threads (simpler) |
| Coroutine-based services / `suspend` controllers | Kotlin 1.6+ on Spring 6 | Reactor `Mono`/`Flux` |
| Null-safety enforced at compile time | Kotlin 2.x | Java + JSpecify `@Nullable` + NullAway |
| Sealed hierarchies for domain modeling | Kotlin `sealed` / Java 17 `sealed` | enums + visitor |
| Pattern matching `switch` over sealed types | Java 21 | `instanceof` chains / Kotlin `when` |
| GraalVM native image (fast startup, low RSS) | Spring Boot 3 AOT + GraalVM | JIT JVM (default; safest) |
| Lightweight non-Spring HTTP server (Kotlin) | Ktor 2.x/3.x | Spring Boot (batteries-included) |
| Build + reproducible deps | Gradle 8.x (Kotlin DSL) or Maven 3.9 | either — pin the wrapper |

**Platform reality (2026):** Spring Boot 3.x requires Java 17 as a hard floor and runs on the `jakarta.*` namespace; Boot 2.x (`javax.*`) is end-of-OSS-support — new services start on 3.x. Java 21 LTS makes virtual threads and pattern matching baseline. Kotlin 2.x (K2 compiler) is the default for Kotlin services. Library support lags platform releases, so gate on the actual versions in your `pom.xml` / `build.gradle.kts` rather than trusting version tables from memory.

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
| [spring-boot/SKILL.md](spring-boot/SKILL.md) | Spring Boot 3.x: controllers, DI, transactions, JPA, validation, security, WebFlux |
| [kotlin-backend/SKILL.md](kotlin-backend/SKILL.md) | Kotlin back-ends: coroutines, null-safety, data/sealed classes, Spring + Kotlin, Ktor |

## Related Skills

- [node-skills](../node/SKILL.md) — the TypeScript/Node.js counterpart for service work
- [api-design](../api/SKILL.md) — REST/GraphQL/gRPC contract design the controllers implement
- [database-engineering](../data/SKILL.md) — schema, migrations, indexing behind JPA/Hibernate
- [secure-coding](../_shared/secure-coding/SKILL.md) — injection-safe queries, secrets hygiene, input validation
- [api-security](../quality/api-security/SKILL.md) — OWASP API Security Top 10 auth-boundary review
- [be-testing](../quality/be-testing/SKILL.md) — JUnit 5 + Testcontainers integration tests
- [version-feature-matrix](../_shared/version-feature-matrix.md) — platform minimums per feature
