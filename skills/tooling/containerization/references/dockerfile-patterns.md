# Dockerfile Patterns Reference

Use this when:

- You are writing or shrinking a Dockerfile for a specific runtime.
- You need BuildKit cache or secret mounts.
- You want a distroless/`scratch` final stage and a non-root user.

Skip if:

- You need to bring up local databases/brokers — that is [compose-local-deps.md](compose-local-deps.md).
- You only need the five-rule doctrine. See [containerization SKILL.md](../SKILL.md).

Jump to:

- .dockerignore First
- Node.js / TypeScript
- Go (scratch)
- JVM (Java / Kotlin)
- Python (uv)
- Ruby (Rails)
- PHP (FPM)
- .NET (ASP.NET Core)
- BuildKit Cache & Secrets
- Non-root & Read-only Hardening

---

## .dockerignore First

Every template assumes a `.dockerignore` so build context stays small and secrets never enter:

```gitignore
.git
node_modules
dist
build
target
__pycache__
.venv
*.log
.env
.env.*
docker-compose*.yml
```

---

## Node.js / TypeScript

```dockerfile
# syntax=docker/dockerfile:1
FROM node:22-bookworm AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM gcr.io/distroless/nodejs22-debian12 AS runtime
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER nonroot
EXPOSE 8080
CMD ["dist/server.js"]
```

pnpm: `--mount=type=cache,target=/pnpm/store pnpm install --frozen-lockfile`. yarn: cache `/usr/local/share/.cache/yarn`.

## Go (scratch)

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.22 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app ./cmd/server

FROM gcr.io/distroless/static-debian12 AS runtime   # or scratch for fully static
COPY --from=build /app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

`CGO_ENABLED=0` produces a static binary so `scratch`/`distroless/static` work. Bring CA certs and timezone data from distroless (or `COPY` them) if you call HTTPS.

## JVM (Java / Kotlin)

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 ./mvnw -q -DskipTests package

FROM eclipse-temurin:21-jre AS runtime              # JRE, not JDK, in the final image
WORKDIR /app
COPY --from=build /src/target/*.jar app.jar
RUN useradd -r -u 10001 appuser
USER appuser
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-jar","app.jar"]
```

Smaller still: Spring Boot layered jars (`-Djarmode=layertools extract`) for better caching, or a custom JRE via `jlink`. Set `-XX:MaxRAMPercentage` so the JVM respects the container memory limit.

## Python (uv)

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev
COPY . .

FROM python:3.12-slim AS runtime
WORKDIR /app
COPY --from=build /app /app
ENV PATH="/app/.venv/bin:$PATH"
RUN useradd -r -u 10001 appuser
USER appuser
EXPOSE 8080
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8080"]
```

For a Django/Gunicorn app swap the `CMD` for `gunicorn`. Use `-slim` over `-alpine` unless you have verified your wheels build on musl.

## Ruby (Rails)

```dockerfile
# syntax=docker/dockerfile:1
FROM ruby:3.3-slim AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev
COPY Gemfile Gemfile.lock ./
RUN --mount=type=cache,target=/usr/local/bundle/cache \
    bundle config set --local without 'development test' && bundle install
COPY . .
RUN bundle exec bootsnap precompile app/ lib/

FROM ruby:3.3-slim AS runtime
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
RUN useradd -r -u 10001 rails && chown -R rails /app
USER rails
EXPOSE 3000
CMD ["bundle","exec","puma","-C","config/puma.rb"]
```

## PHP (FPM)

```dockerfile
# syntax=docker/dockerfile:1
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist --optimize-autoloader

FROM php:8.3-fpm-alpine AS runtime
RUN docker-php-ext-install pdo_pgsql opcache
WORKDIR /var/www
COPY --from=vendor /app/vendor ./vendor
COPY . .
USER www-data
EXPOSE 9000
CMD ["php-fpm"]
```

Pair with an nginx container (or Caddy) in Compose; PHP-FPM speaks FastCGI on 9000, not HTTP.

## .NET (ASP.NET Core)

```dockerfile
# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime    # or :8.0-jammy-chiseled (distroless-like)
WORKDIR /app
COPY --from=build /app .
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet","Orders.Api.dll"]
```

`-chiseled` images are minimal and rootless by default. For native-AOT, publish with `-p:PublishAot=true` and ship on `runtime-deps`.

---

## BuildKit Cache & Secrets

```dockerfile
# Cache mount: persists a package cache across builds without baking it into a layer
RUN --mount=type=cache,target=/root/.npm npm ci

# Secret mount: available only during this RUN, never written to a layer
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci
```

```bash
DOCKER_BUILDKIT=1 docker build --secret id=npm_token,env=NPM_TOKEN -t orders-api:dev .
```

Never use `ARG TOKEN=` for credentials — `ARG`/`ENV` values are visible in `docker history`.

## Non-root & Read-only Hardening

```bash
docker run --rm \
  --read-only --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  -p 8080:8080 orders-api:dev
```

In the Dockerfile, always finish with a non-root `USER` (numeric UID like `10001` so Kubernetes `runAsNonRoot` is satisfied even without `/etc/passwd`). Scan before publishing: `trivy image orders-api:dev`. These choices harden the **API8 misconfiguration** edge ([api-security](../../quality/api-security/SKILL.md)).
