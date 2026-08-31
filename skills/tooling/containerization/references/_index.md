# Containerization References Index

Deep-dive references for the [containerization](../SKILL.md) skill. Start at the
SKILL.md doctrine and quickstart; come here for per-runtime templates and full
Compose stacks.

## References

| File | Covers | Read when |
|------|--------|-----------|
| `dockerfile-patterns.md` | Multi-stage Dockerfiles for Node, Go (`scratch`), JVM (JRE/jlink), Python (uv), Ruby, PHP-FPM, .NET; distroless targets; BuildKit cache + secret mounts; `.dockerignore`; non-root + read-only hardening | You are writing or shrinking a Dockerfile for a specific runtime |
| `compose-local-deps.md` | Docker Compose stacks for Postgres/MySQL/Mongo/Redis/Kafka/RabbitMQ, healthcheck gating with `depends_on`, seeding/init scripts, networks/volumes, parity with Testcontainers | You need to bring up databases or brokers locally |
| `runtime-contract.md` | Config from environment variables (validated at boot, no environment groupings); build/release/run separation and immutable release promotion; `$PORT` binding on `0.0.0.0`; per-stack `SIGTERM` graceful shutdown (Spring Boot, FastAPI/uvicorn, Puma, ASP.NET Core, PHP-FPM); fast startup | Config lives in a committed file, a deploy drops in-flight requests, or the same artifact can't be promoted across environments |

## Quick Links by Problem

- **Shrink a Node/Python image** → `dockerfile-patterns.md` (distroless, prune)
- **Ship a static Go binary on `scratch`** → `dockerfile-patterns.md` (Go)
- **Slim a Spring Boot image** → `dockerfile-patterns.md` (JVM, jlink/JRE)
- **Pass an npm/private-registry token at build** → `dockerfile-patterns.md` (BuildKit secrets)
- **Run Postgres + Redis locally** → `compose-local-deps.md` (datastores)
- **Run Kafka or RabbitMQ locally** → `compose-local-deps.md` (brokers)
- **Wait for the DB before the app starts** → `compose-local-deps.md` (healthcheck gating)
- **Seed a database on first boot** → `compose-local-deps.md` (init scripts)
- **Decide where config and secrets come from** → `runtime-contract.md` (Config)
- **Stop rebuilding the image per environment** → `runtime-contract.md` (Build, Release, Run)
- **Read the listen port from the platform** → `runtime-contract.md` (Port Binding)
- **Drain in-flight requests on deploy** → `runtime-contract.md` (Graceful Shutdown)
- **Cut a slow JVM/Python cold start** → `runtime-contract.md` (Fast Startup)
