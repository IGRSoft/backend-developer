# Compose Local Dependencies Reference

Use this when:

- You need Postgres/MySQL/Mongo/Redis/Kafka/RabbitMQ running locally with one command.
- You want the app to wait for a dependency to be *ready*, not just *started*.
- You want local parity with the images your integration tests pin.

Skip if:

- You are writing the service's own Dockerfile — that is [dockerfile-patterns.md](dockerfile-patterns.md).
- You only need the doctrine. See [containerization SKILL.md](../SKILL.md).

Jump to:

- The App + Datastore Stack
- Healthcheck Gating
- Datastores (Postgres / MySQL / Mongo / Redis)
- Brokers (Kafka / RabbitMQ)
- Seeding & Init Scripts
- Parity with Testcontainers

---

## The App + Datastore Stack

```yaml
services:
  api:
    build: .
    ports: ["8080:8080"]
    environment:
      DATABASE_URL: postgres://app:app@db:5432/app
      REDIS_URL: redis://cache:6379
    depends_on:
      db:    { condition: service_healthy }
      cache: { condition: service_healthy }
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: app
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d app"]
      interval: 5s
      timeout: 3s
      retries: 10
    volumes: ["pgdata:/var/lib/postgresql/data"]
  cache:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 10
volumes:
  pgdata: {}
```

```bash
docker compose up -d          # start everything, detached
docker compose ps             # see health status
docker compose logs -f api    # tail the app
docker compose down -v        # stop and drop volumes (fresh DB next time)
```

## Healthcheck Gating

`depends_on:` alone only waits for the container to *start*, not for the database to accept connections — the classic startup race. The fix is a `healthcheck` on the dependency plus `condition: service_healthy`:

```yaml
depends_on:
  db: { condition: service_healthy }
```

Each datastore needs its own readiness probe (below). `interval`/`retries` set how long Compose waits before giving up.

## Datastores

```yaml
# MySQL
mysql:
  image: mysql:8
  environment:
    MYSQL_DATABASE: app
    MYSQL_USER: app
    MYSQL_PASSWORD: app
    MYSQL_ROOT_PASSWORD: root
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-papp"]
    interval: 5s
    retries: 10
  volumes: ["mysqldata:/var/lib/mysql"]

# MongoDB
mongo:
  image: mongo:7
  healthcheck:
    test: ["CMD", "mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
    interval: 5s
    retries: 10
  volumes: ["mongodata:/data/db"]

# Redis (already shown above)
```

## Brokers

```yaml
# Kafka (KRaft mode — no ZooKeeper)
kafka:
  image: confluentinc/cp-kafka:7.6.0
  environment:
    KAFKA_NODE_ID: 1
    KAFKA_PROCESS_ROLES: broker,controller
    KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
    KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
    KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
    KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
    KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
    KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
  healthcheck:
    test: ["CMD-SHELL", "kafka-topics --bootstrap-server localhost:9092 --list || exit 1"]
    interval: 10s
    retries: 10
  ports: ["9092:9092"]

# RabbitMQ (with management UI)
rabbitmq:
  image: rabbitmq:3-management
  ports: ["5672:5672", "15672:15672"]
  healthcheck:
    test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
    interval: 10s
    retries: 10
```

## Seeding & Init Scripts

```yaml
db:
  image: postgres:16
  volumes:
    - ./db/init:/docker-entrypoint-initdb.d:ro   # *.sql / *.sh run once, on first boot
    - pgdata:/var/lib/postgresql/data
```

Postgres, MySQL, and Mongo official images all run scripts in `/docker-entrypoint-initdb.d` exactly once, when the data volume is empty. Put schema/seed SQL there for a ready-to-use local DB. To re-run, `docker compose down -v` to drop the volume. Keep seed data tiny and non-secret — production schema comes from migrations, not init scripts.

## Parity with Testcontainers

Pin the **same image tags** in Compose and in your Testcontainers integration tests so "works locally" and "passes in CI" mean the same thing:

```java
// Java — Testcontainers, same postgres:16 as Compose
static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16");
```

```go
// Go — testcontainers-go
req := testcontainers.ContainerRequest{Image: "postgres:16", ExposedPorts: []string{"5432/tcp"},
  WaitingFor: wait.ForListeningPort("5432/tcp")}
```

```ts
// Node — testcontainers
const pg = await new PostgreSqlContainer("postgres:16").start();
```

Testcontainers gives each test run a throwaway container (parallel-safe, no port clashes); Compose gives you a long-lived local stack for manual work. Both should reference the same versions tracked in the version-feature-matrix (skill: version-feature-matrix). Full integration-test patterns: [be-testing](../../quality/be-testing/SKILL.md).
