# JVM Back-End Skills Index

Quick navigation for Spring Boot (Java) and Kotlin back-end skills.

## Core Skills

| File | Description |
|------|-------------|
| `SKILL.md` | Entry point: canonical framework-selection table (need → minimum platform → fallback), decision tree |
| `spring-boot/SKILL.md` | Spring Boot (3.5 / 4.x): REST controllers, constructor DI, @Transactional boundaries, JPA/Hibernate, Bean Validation, Spring Security, WebFlux |
| `kotlin-backend/SKILL.md` | Kotlin for back-ends: coroutines + structured concurrency, null-safety, data/sealed classes, Spring with Kotlin, Ktor |

## Subdirectories

| Directory | Contents | Description |
|-----------|----------|-------------|
| `spring-boot/` | 1 skill + 1 ref | Spring Boot 3.5 / 4.x service patterns and a JPA performance deep-dive |
| `kotlin-backend/` | 1 skill | Idiomatic Kotlin back-end patterns, coroutines, Ktor |

## Reference Files

| File | Use it for |
|------|------------|
| `spring-boot/references/jpa-performance.md` | N+1 detection, fetch joins, `@EntityGraph`, DTO projections, batch sizing, pagination with joins |

## Quick Links by Problem

### "I need to..."

- **Pick Spring Boot vs WebFlux vs Ktor** → `SKILL.md` > Framework Selection Table
- **Write a REST controller with constructor injection** → `spring-boot/SKILL.md` > Controllers & DI
- **Get `@Transactional` boundaries right** → `spring-boot/SKILL.md` > Transactions
- **Diagnose and fix an N+1 query** → `spring-boot/references/jpa-performance.md`
- **Project entities into DTOs without lazy-load surprises** → `spring-boot/references/jpa-performance.md`
- **Validate a request body** → `spring-boot/SKILL.md` > Bean Validation
- **Lock down endpoints with method-level authorization** → `spring-boot/SKILL.md` > Spring Security
- **Write non-blocking reactive endpoints** → `spring-boot/SKILL.md` > WebFlux
- **Use coroutines instead of Reactor** → `kotlin-backend/SKILL.md` > Coroutines
- **Model a domain with sealed hierarchies** → `kotlin-backend/SKILL.md` > Type Modeling
- **Stand up a Ktor service** → `kotlin-backend/SKILL.md` > Ktor
- **Design the API contract first** → `../api/SKILL.md`
- **Tune the schema and migrations** → `../data/SKILL.md`
- **Review auth against OWASP API Top 10** → `../quality/api-security/SKILL.md`
- **Run integration tests with Testcontainers** → `../quality/be-testing/SKILL.md`
