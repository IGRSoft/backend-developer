---
name: containerization
description: >-
  Package a web/service back-end into a small, secure container: multi-stage
  Dockerfiles, distroless/minimal base images, layer-cache ordering, non-root
  users, Docker Compose for local dependencies, healthchecks, and BuildKit
  build args/secrets. Use when writing a Dockerfile, shrinking an image,
  wiring local Postgres/Redis/Kafka, or fixing a restart loop.
---

# Containerization

**Build a small image, run it as non-root, gate it with a healthcheck, and bring up deps with Compose.**

## When to Use

Use this skill when you need to:

- Write or shrink a Dockerfile for a Node/Go/JVM/Python/Ruby/PHP/.NET service.
- Keep secrets and dev dependencies *out* of the final image.
- Order layers so a code change doesn't reinstall every dependency.
- Run Postgres/MySQL/Mongo/Redis/Kafka/RabbitMQ locally with one command.
- Add a healthcheck so orchestrators restart a truly-broken container, not a slow-starting one.

Skip if the problem is a runtime symptom inside the container — that is [be-diagnostics](../be-diagnostics/SKILL.md). For what to *measure* once it runs, see [observability](../observability/SKILL.md).

## Doctrine (the five rules)

1. **Multi-stage, always.** A build stage carries the toolchain and dev deps; the final stage carries only the runtime artifact. Never ship `node_modules` build tooling, `.git`, or the JDK when a JRE/native binary will do.
2. **Smallest correct base.** Prefer distroless or `-slim`/`-alpine` *if your runtime is happy on musl*; static Go binaries can use `scratch`. Smaller base = smaller attack surface and faster pulls.
3. **Non-root user.** Create and `USER` a non-root account; the process must not run as UID 0. Combine with a read-only root filesystem where possible.
4. **Order layers cold→hot.** Copy the dependency manifest and install *before* copying source, so editing code reuses the cached dependency layer.
5. **Secrets never land in a layer.** Use BuildKit `--mount=type=secret` for build-time creds and runtime env/secret managers for the rest — never `COPY .env` or `ARG TOKEN=...`.

## Image Build Quickstart

```dockerfile
# syntax=docker/dockerfile:1
# --- build stage ---
FROM node:22-bookworm AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci          # cached unless lockfile changes
COPY . .
RUN npm run build && npm prune --omit=dev

# --- runtime stage (small, non-root) ---
FROM gcr.io/distroless/nodejs22-debian12 AS runtime
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER nonroot
EXPOSE 8080
CMD ["dist/server.js"]
```

```bash
docker build -t orders-api:dev .            # single-command; BuildKit on by default
docker run --rm -p 8080:8080 orders-api:dev
```

Per-runtime templates (Go `scratch`, JVM jlink/JRE, Python uv, .NET, Ruby, PHP-FPM), BuildKit cache and secret mounts, and `.dockerignore` rules: [dockerfile-patterns.md](references/dockerfile-patterns.md).

## Layer Caching: Order Matters

```dockerfile
# WRONG — any source change busts the dependency install
COPY . .
RUN npm ci

# RIGHT — deps install only when the lockfile changes
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

The same principle per ecosystem: copy `go.mod`/`go.sum` then `go mod download`; copy `pom.xml`/`*.gradle` then resolve; copy `pyproject.toml`/`uv.lock` then `uv sync`; copy `Gemfile*` then `bundle install`; copy `composer.json`/`composer.lock` then `composer install`. Always pair with a `.dockerignore` that excludes `.git`, `node_modules`, build output, and `.env`.

## Build Args vs Secrets

```dockerfile
# Build-time secret — never persisted in a layer (BuildKit)
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```

```bash
docker build --secret id=npm_token,env=NPM_TOKEN -t orders-api:dev .
```

- `ARG` is for non-sensitive build inputs (version, target). It can leak via image history — never put credentials in `ARG` or `ENV`.
- Build-time creds → `--mount=type=secret`. Runtime creds → injected env / secret manager at `docker run`/deploy time, not baked in.

## Healthchecks

```dockerfile
# Hit a real readiness endpoint; let the orchestrator restart only when truly dead
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost:8080/healthz || exit 1
```

- **`start-period`** prevents restart loops during slow JVM/cold-start boots — failures during it don't count.
- Expose `/healthz` (liveness: am I up?) and `/readyz` (readiness: can I serve? — DB/cache reachable). Orchestrators route traffic on readiness and restart on liveness.
- A distroless/`scratch` image has no shell or `wget`; use the runtime's own probe (e.g. a tiny Go/Node health binary) or rely on the orchestrator's HTTP probe instead of `HEALTHCHECK`.

## Local Dependencies with Compose

```yaml
services:
  api:
    build: .
    ports: ["8080:8080"]
    environment:
      DATABASE_URL: postgres://app:app@db:5432/app
    depends_on:
      db: { condition: service_healthy }   # wait for the DB to be ready, not just started
  db:
    image: postgres:16
    environment: { POSTGRES_USER: app, POSTGRES_PASSWORD: app, POSTGRES_DB: app }
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      retries: 10
    volumes: ["pgdata:/var/lib/postgresql/data"]
volumes: { pgdata: {} }
```

```bash
docker compose up -d        # bring up deps + app
docker compose logs -f api  # tail the service
```

`depends_on: condition: service_healthy` is the fix for the classic "app starts before the DB accepts connections" race. Use the *same* images here that your Testcontainers integration tests pin, so local and CI behave identically ([be-testing](../../quality/be-testing/SKILL.md)). Compose recipes for MySQL/Mongo/Redis/Kafka/RabbitMQ and seeding: [compose-local-deps.md](references/compose-local-deps.md).

## Image Hardening Checklist

- [ ] Multi-stage; final image has no compilers, package managers, or shells it doesn't need.
- [ ] `USER` is non-root; consider `--read-only` root fs + a writable `tmpfs` for scratch.
- [ ] Pinned base image (digest or specific tag), not `:latest`.
- [ ] No secrets in `ARG`/`ENV`/layers; `.dockerignore` excludes `.env`, `.git`.
- [ ] Vulnerability scan in CI: `trivy image <img>` (and `npm audit` / `govulncheck` / `osv-scanner` for deps).
- [ ] Healthcheck or orchestrator probe wired to a real readiness endpoint.
- [ ] Drop Linux capabilities you don't need (`--cap-drop ALL`, add back only what's required).

These defend the **API8 security-misconfiguration** and supply-chain edges of the [OWASP API Security Top 10](../../quality/api-security/SKILL.md).

## Version & Fallbacks

Distroless tags, BuildKit syntax, and Compose Spec features track engine versions — confirm with `docker version` / `docker compose version` and the version-feature-matrix (skill: version-feature-matrix). Notable floors: BuildKit cache/secret mounts need the `# syntax=docker/dockerfile:1` directive and a modern Docker Engine (BuildKit is the default builder on current engines); `depends_on: condition:` needs Compose **v2** — the Python `docker-compose` v1 is end-of-life and removed from official images, so always invoke `docker compose` (space, no hyphen). If BuildKit is somehow unavailable, fall back to ordered layers + a `.dockerignore` (no secret mounts — use a runtime secret injector instead). Distroless images still pull from the `gcr.io/distroless/*` URLs (the backend moved to Artifact Registry transparently); `-debian12` is the current default with `-debian13` variants also published.

## Related Skills

- [dockerfile-patterns.md](references/dockerfile-patterns.md) — per-runtime multi-stage templates, distroless/scratch targets, BuildKit cache & secrets, hardening
- [compose-local-deps.md](references/compose-local-deps.md) — Compose for Postgres/MySQL/Mongo/Redis/Kafka/RabbitMQ, healthcheck gating, seeding, Testcontainers parity
- [be-diagnostics](../be-diagnostics/SKILL.md) — exposing pprof/JFR ports and `--cap-add SYS_PTRACE` for in-container profiling
- [observability](../observability/SKILL.md) — log to stdout, ship traces/metrics from the container
- [api-security](../../quality/api-security/SKILL.md) — the misconfiguration & supply-chain risks image hardening defends
- [be-testing](../../quality/be-testing/SKILL.md) — Testcontainers reuse these images and Compose stacks
- [secure-coding](../../_shared/secure-coding/SKILL.md) — secrets hygiene and least privilege at the image boundary
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — engine/Compose/BuildKit floors
