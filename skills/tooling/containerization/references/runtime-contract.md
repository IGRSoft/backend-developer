# Runtime Contract Reference

The contract between the app and whatever platform runs it: where config comes
from, what a release is, how the process gets its port, and how it dies.

Use this when:

- Config is read from a checked-in file, or grouped into `development`/`staging`/`production` blocks.
- The same artifact cannot be promoted from staging to production unchanged.
- The app hardcodes a listen port, or expects the platform to inject a webserver.
- A deploy drops in-flight requests or re-queues nothing on shutdown.

Skip if:

- You are writing the Dockerfile itself — that is [dockerfile-patterns.md](dockerfile-patterns.md).
- You need local Postgres/Kafka — that is [compose-local-deps.md](compose-local-deps.md).

Jump to:

- Config Comes From the Environment
- Build, Release, Run Are Three Stages
- Port Binding
- Graceful Shutdown (per stack)
- Fast Startup
- Contract Checklist

Derived from the [twelve-factor manifesto](https://github.com/twelve-factor/twelve-factor)
(factors III, V, VII, IX), CC BY 4.0.

---

## Config Comes From the Environment

Config is everything that varies between deploys: connection strings,
credentials, per-deploy hostnames, feature toggles bound to an environment.
Internal wiring that is the same in every deploy — route tables, DI graphs,
Spring `@Configuration` — is code, not config, and belongs in the repo.

**The litmus test:** could you open-source the repository right now without
leaking a credential? If not, config has leaked into code.

```bash
# The deploy supplies config; the image carries none of it
docker run --rm -p 8080:8080 \
  -e DATABASE_URL=postgres://app@db:5432/app \
  -e REDIS_URL=redis://cache:6379 \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317 \
  orders-api:1.4.3
```

### Read it once, validate it at boot

Parse and validate the whole environment at startup and fail loudly if
something required is missing. A service that boots happily and then 500s on
the first request that touches an unset variable has turned a config error into
an incident.

```ts
// Node — parse once, export a typed frozen object; crash at boot, not at 3am
import { z } from 'zod';

const Env = z.object({
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
});

export const env = Object.freeze(Env.parse(process.env));
```

```python
# Python — pydantic-settings; the same fail-at-boot contract
from pydantic import PostgresDsn
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: PostgresDsn
    port: int = 8080
    log_level: str = "info"

settings = Settings()  # raises at import if DATABASE_URL is unset
```

```go
// Go — no magic; a required-var helper that panics at boot
func mustEnv(key string) string {
    v, ok := os.LookupEnv(key)
    if !ok || v == "" {
        log.Fatalf("required environment variable %s is not set", key)
    }
    return v
}
```

### No environment groupings

Name each variable for what it controls, never for the environment it belongs
to. A `config/production.yml` — or a `NODE_ENV`/`SPRING_PROFILES_ACTIVE` switch
that changes which datastore the code picks — makes every new deploy a code
change, and the count of named environments grows faster than anyone maintains
them.

```yaml
# WRONG — the app decides its own topology from a name it was handed
production:
  database: postgres://prod-db/app
staging:
  database: postgres://staging-db/app
```

```bash
# RIGHT — each deploy carries its own granular values; the code never branches on a name
DATABASE_URL=postgres://staging-db/app
FEATURE_NEW_CHECKOUT=false
```

Profiles are still legitimate for *code* selection that is genuinely
per-environment and not a resource locator — a dev-only mock mailer, an extra
debug endpoint. The rule is about resource bindings and credentials.

### Secrets

Env vars are the interface; the *source* should be a secret manager (Vault, AWS
Secrets Manager, GCP Secret Manager, a Kubernetes Secret) injected at deploy
time. Never `COPY .env`, never bake a credential into `ARG`/`ENV` — see
[containerization SKILL.md](../SKILL.md) > Build Args vs Secrets and
[secure-coding](../../../_shared/secure-coding/SKILL.md) > Secrets Hygiene.

---

## Build, Release, Run Are Three Stages

| Stage | Input | Output | Who runs it |
|-------|-------|--------|-------------|
| **Build** | Repo at a commit | Immutable artifact (image, jar, binary) — deps resolved, assets compiled | CI, once |
| **Release** | Artifact + this deploy's config | A uniquely-identified, immutable release | Deploy pipeline |
| **Run** | A selected release | Running processes | The platform |

**One artifact, many deploys.** The image that passed staging is the image that
reaches production, bit for bit. Rebuilding per environment means the thing you
tested is not the thing you shipped.

```bash
# Build once, tag by commit — never rebuild per environment
docker build -t orders-api:${GIT_SHA} .
docker push registry.example.com/orders-api:${GIT_SHA}

# Release = that exact artifact + this deploy's config
docker run --env-file staging.env registry.example.com/orders-api:${GIT_SHA}
docker run --env-file prod.env    registry.example.com/orders-api:${GIT_SHA}
```

**Releases are append-only and immutable.** Every release gets a unique
identifier and is never edited in place. Changing anything — a config value, a
line of code — creates a new release. That is what makes rollback a pointer
move instead of a rebuild, and it is why `:latest` is not a release identifier:
it names a moving target, so you cannot say what is running or roll back to
what was.

**Push complexity into build.** Compile, bundle, run codegen, and resolve
dependencies at build time. Work deferred to run is work that can fail on a
node at 3am, on the one path with no human watching.

**Nothing mutates at run time.** No hot-patching a running container, no
editing files inside it — the change cannot propagate back to the build stage,
so it evaporates on the next restart and silently diverges from every replica.

---

## Port Binding

The app is self-contained: it includes its own HTTP server as a declared
dependency and binds a port. It does not get dropped into an Apache module or a
Tomcat container that supplies the runtime around it.

**The port is config.** Read it from the environment with a sane default — the
platform decides what to hand you.

```ts
// Node
app.listen(env.PORT, '0.0.0.0');
```

```go
// Go — bind all interfaces; localhost-only is unreachable from outside the container
port := os.Getenv("PORT"); if port == "" { port = "8080" }
srv := &http.Server{Addr: ":" + port, Handler: mux}
```

```python
# Python — uvicorn reads the same variable
uvicorn.run(app, host="0.0.0.0", port=settings.port)
```

Bind `0.0.0.0`, not `127.0.0.1`: a process listening only on loopback inside a
container is invisible to the orchestrator's probes and to every other pod.

Once a service exports over a port, another service consumes it as a backing
service by receiving its URL through config — the same mechanism as a database.
See [microservices-patterns](../../../architecture/microservices-patterns/SKILL.md)
> Edge & Discovery.

---

## Graceful Shutdown (per stack)

On `SIGTERM` a web process stops accepting new connections, drains in-flight
requests within the platform's grace period, closes pools, and exits. A worker
returns its current job to the queue rather than losing it. Exceeding the grace
period means `SIGKILL` and dropped requests, so the drain deadline must sit
*below* it (Kubernetes default `terminationGracePeriodSeconds: 30`).

Go and Node already have worked examples — see
[go-concurrency](../../../go/go-concurrency/references/concurrency-patterns.md)
> Graceful Shutdown and
[node-async-streams](../../../node/node-async-streams/references/streams-and-workers.md)
> Graceful shutdown. The rest:

```java
// Spring Boot — graceful shutdown is the default since 3.4; the timeout must be under the grace period
// application.yml
// server.shutdown: graceful
// spring.lifecycle.timeout-per-shutdown-phase: 25s
@PreDestroy
void drain() {
    log.info("SIGTERM received, draining");   // Spring stops the connector, then runs this
}
```

```python
# FastAPI/uvicorn — lifespan shutdown runs after the server stops accepting
@asynccontextmanager
async def lifespan(app: FastAPI):
    yield                       # ---- serving ----
    await db_pool.close()       # uvicorn already stopped accepting on SIGTERM
    await redis.aclose()
```

```ruby
# Puma (Rails) — config/puma.rb
# Puma traps SIGTERM and drains workers by default.
worker_shutdown_timeout 25
on_worker_shutdown { ActiveRecord::Base.connection_pool.disconnect! }
```

```csharp
// ASP.NET Core — IHostApplicationLifetime; ShutdownTimeout must be under the grace period
builder.Services.Configure<HostOptions>(o =>
    o.ShutdownTimeout = TimeSpan.FromSeconds(25));

lifetime.ApplicationStopping.Register(() => _log.LogInformation("draining"));
```

```php
// PHP-FPM — the master traps SIGQUIT for a graceful stop; SIGTERM is immediate.
// Send SIGQUIT (docker stop --signal=SIGQUIT), and set in the pool config:
//   process_control_timeout = 25s
// Long-running workers (Laravel Horizon, Symfony Messenger) handle SIGTERM
// themselves and finish the current message before exiting.
```

**Crash-only.** Graceful shutdown is the happy path, not the guarantee. A node
can vanish. In-flight work must be recoverable without it: acknowledge queue
messages only after the work commits, make consumers idempotent, and keep
transactions short. See
[event-driven](../../../architecture/event-driven/SKILL.md) > Idempotent
Consumers.

---

## Fast Startup

A process should be ready to serve within seconds of launch. Slow starts make
scale-out lag demand, stretch every deploy, and turn a restart loop into an
outage.

| Cost at boot | Move it to |
|--------------|------------|
| Asset compilation, bundling, codegen | Build stage |
| Dependency resolution / install | Build stage |
| Schema migration | A separate admin process — see [migrations](../../../data/migrations/SKILL.md) |
| Warming a large cache | Background task after readiness, not before it |
| Eager connections to every downstream | Lazy connect + readiness probe |

When boot is genuinely slow (JVM cold start), do not paper over it with a long
liveness timeout — use `start-period` on the healthcheck, or a startup probe, so
a slow boot is not read as a dead process. See
[containerization SKILL.md](../SKILL.md) > Healthchecks.

---

## Contract Checklist

- [ ] Every config value the deploy varies comes from an env var, validated at boot.
- [ ] No credential in the repo; the open-source litmus test passes.
- [ ] No `config/<environment>.yml` selecting resources by environment name.
- [ ] One artifact promoted across deploys; the release ID is a commit SHA or version, never `:latest`.
- [ ] Nothing is edited inside a running container.
- [ ] The listen port comes from config; the process binds `0.0.0.0`.
- [ ] The HTTP server is a declared dependency, not injected by the environment.
- [ ] `SIGTERM` drains in-flight work with a deadline under the platform's grace period.
- [ ] Queue work is re-queued or idempotently retryable after a hard kill.
- [ ] Boot does no compilation, no dependency install, and no migration.
