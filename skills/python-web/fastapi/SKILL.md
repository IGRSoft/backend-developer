---
name: fastapi
description: >-
  FastAPI web services with Pydantic v2 validation, Annotated dependency
  injection, automatic OpenAPI 3.1, auth dependencies, async SQLAlchemy, and
  background tasks. Use when building or reviewing a FastAPI service, designing
  request/response models, wiring DI or auth, choosing sync vs async routes, or
  integrating an async ORM. Python language depth → system-developer:python-skills.
---

# FastAPI

**Async-first APIs with Pydantic v2 validation, dependency injection, and auto-generated OpenAPI**

## When to Use

Use this skill when:
- Building a new FastAPI service or adding routes to an existing one
- Designing request/response models with Pydantic v2 (validation, serialization)
- Wiring dependency injection (`Annotated[T, Depends(...)]`) and auth dependencies
- Deciding sync (`def`) vs async (`async def`) path operations
- Integrating an async ORM (SQLAlchemy 2.x async engine) with proper session lifecycle
- Offloading work via `BackgroundTasks` or routing to a task queue

For Python *language* concerns — async/await semantics, the event loop,
`asyncio.TaskGroup`, typing/generics, uv/ruff/pytest — use
`system-developer:python-skills`. This skill owns only the FastAPI + persistence
layer. Deep DI graphs, OAuth2/JWT flow, and async session lifecycle:
[references/fastapi-advanced.md](references/fastapi-advanced.md).

## Version Markers & Fallbacks

| Feature | Needs | Fallback |
|---------|-------|----------|
| `Annotated[T, Depends()]` style DI | FastAPI 0.95+ | bare `Depends()` default-arg style (deprecated pattern) |
| Pydantic v2 (`model_validate`/`model_dump`) | FastAPI 0.100+ | Pydantic v1 (`parse_obj`/`dict`) on FastAPI <0.100 |
| OpenAPI 3.1 output | FastAPI 0.99+ | OpenAPI 3.0.x on older releases |
| `lifespan=` context manager | FastAPI 0.93+ | deprecated `@app.on_event("startup")` |

Pin `fastapi`, `pydantic`, `sqlalchemy` in `pyproject.toml`/`uv.lock`. Canonical
version lookup: skill: version-feature-matrix
(`../../_shared/version-feature-matrix.md`).

## Routes: sync vs async

`async def` path operations run on the event loop; `def` operations run in a
thread pool. Never block the loop with sync I/O inside `async def`.

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")          # trivial → either works
async def health() -> dict[str, str]:
    return {"status": "ok"}

@app.get("/report")          # blocking lib (no async client) → use def
def report() -> dict[str, int]:
    return {"rows": legacy_blocking_query()}   # runs in threadpool, loop free
```

Rule: if every call inside is `await`-able (async DB driver, httpx), use
`async def`. If you must call a blocking library, use plain `def` so FastAPI
offloads it — do not call blocking code from `async def`.

## Pydantic v2 Models

Request/response schemas are Pydantic models. Validation is enforced at the
boundary — never trust raw input past the model.

```python
from pydantic import BaseModel, EmailStr, Field, ConfigDict

class UserCreate(BaseModel):
    email: EmailStr
    age: int = Field(ge=0, le=130)
    display_name: str = Field(min_length=1, max_length=80)

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)  # read from ORM objects
    id: int
    email: EmailStr
    display_name: str

@app.post("/users", response_model=UserOut, status_code=201)
async def create_user(payload: UserCreate) -> UserOut:
    user = await repo.insert(payload)   # payload already validated
    return user                          # serialized via UserOut, drops extras
```

`response_model` is an **API3 (broken object property-level authorization)**
control: it strips fields not in the schema, so a `password_hash` on the ORM
row never leaks. Always declare a response model for non-trivial payloads.

## Dependency Injection

`Annotated[T, Depends(provider)]` is the canonical style — composable, typed,
and testable via `app.dependency_overrides`.

```python
from typing import Annotated
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session            # cleanup runs after the response

SessionDep = Annotated[AsyncSession, Depends(get_session)]

@app.get("/users/{user_id}", response_model=UserOut)
async def get_user(user_id: int, session: SessionDep) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="user not found")
    return user
```

Yield-dependencies (the `async with ... yield` form) guarantee teardown even on
error. For nested/scoped DI graphs, see
[references/fastapi-advanced.md](references/fastapi-advanced.md).

## Auth Dependencies (API2 / API5)

Authentication and per-route authorization are dependencies — never inline,
never client-trusted.

```python
from fastapi import Security
from fastapi.security import OAuth2PasswordBearer

oauth2 = OAuth2PasswordBearer(tokenUrl="auth/token")

async def current_user(
    token: Annotated[str, Depends(oauth2)],
    session: SessionDep,
) -> User:
    user = await decode_and_load(token, session)   # verify signature + exp
    if user is None:
        raise HTTPException(401, "invalid credentials",
                            headers={"WWW-Authenticate": "Bearer"})
    return user

def require_role(role: str):
    async def checker(user: Annotated[User, Depends(current_user)]) -> User:
        if role not in user.roles:                  # API5: function-level authz
            raise HTTPException(403, "forbidden")
        return user
    return checker

@app.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    admin: Annotated[User, Depends(require_role("admin"))],
    session: SessionDep,
) -> Response:
    await session.execute(delete(User).where(User.id == user_id))
    await session.commit()
    return Response(status_code=204)
```

BOLA (API1) check: even for an authenticated user, confirm the object belongs to
them before returning it — `if obj.owner_id != user.id: raise HTTPException(403)`.
Auth boundaries are a DR review gate. See
[api-security](../../quality/api-security/SKILL.md).

## Persistence: async SQLAlchemy

Use the SQLAlchemy 2.x typed ORM with the async engine. One session per request
(via the `get_session` dependency above), commit explicitly, parameterize always.

```python
from sqlalchemy import select
from sqlalchemy.orm import Mapped, mapped_column, DeclarativeBase

class Base(DeclarativeBase): ...

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(unique=True, index=True)

# parameterized — never f-string SQL (injection / API-level injection)
stmt = select(User).where(User.email == email)        # bound param, safe
result = await session.scalars(stmt)
users = result.all()
```

N+1 avoidance: eager-load relationships with `selectinload`/`joinedload` instead
of lazy access in a loop. Transaction correctness and idempotency are DR gates —
see [references/fastapi-advanced.md](references/fastapi-advanced.md) § sessions.

## Background Tasks

`BackgroundTasks` runs after the response is sent, **in the same process** — fine
for fire-and-forget like sending an email, wrong for anything that must survive a
restart or scale independently.

```python
from fastapi import BackgroundTasks

@app.post("/signup", status_code=202)
async def signup(payload: UserCreate, tasks: BackgroundTasks) -> dict[str, str]:
    user = await repo.insert(payload)
    tasks.add_task(send_welcome_email, user.email)   # in-process, best-effort
    return {"status": "accepted"}
```

If the work needs durability, retries, or its own scaling, route to a task queue
(Celery, RQ, Arq, or a Kafka/SQS consumer) instead — see
[references/fastapi-advanced.md](references/fastapi-advanced.md) § background.

## Single-Command Build & Test

Scoped, single-invocation commands (no `cd`-chains). The runner/linter are owned
by `system-developer:python-tooling`/`python-testing`; this is the framework
slice:

```bash
uv run pytest tests/ -q                  # unit + integration via httpx/TestClient
uv run ruff check app/                   # lint the service package
uv run pyright app/                      # type gate
```

Evidence (cli-fallback, `requires_screenshots: false`): API request/response
transcripts via `httpx`/`curl`, pytest output, and migration logs — not build or
sanitizer logs.

```bash
curl -s -X POST localhost:8000/users \
  -H 'content-type: application/json' \
  -d '{"email":"a@b.co","age":30,"display_name":"A"}' | jq .
```

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Event loop stalls under load | blocking call inside `async def` | move to `def` (threadpool) or use an async client | this file, Routes |
| `ResponseValidationError` on return | ORM object has fields the model rejects | add `model_config = ConfigDict(from_attributes=True)`; declare `response_model` | this file, Pydantic |
| Password hash leaks in JSON | no `response_model`, returns raw ORM row | add a `*Out` response model (API3) | this file, Pydantic |
| 500 + "another operation in progress" | one `AsyncSession` shared across requests | one session per request via yield-dependency | [fastapi-advanced.md](references/fastapi-advanced.md) § sessions |
| N+1 queries on list endpoint | lazy relationship loads in a loop | `selectinload`/`joinedload` in the `select()` | [fastapi-advanced.md](references/fastapi-advanced.md) § queries |
| Any user can fetch any record | missing ownership check (BOLA / API1) | compare `obj.owner_id` to `current_user.id` | [api-security](../../quality/api-security/SKILL.md) |
| Background task lost on restart | `BackgroundTasks` is in-process | move to a durable task queue | [fastapi-advanced.md](references/fastapi-advanced.md) § background |
| `Depends` not overridden in tests | overriding the wrong callable | override the exact provider in `app.dependency_overrides` | [fastapi-advanced.md](references/fastapi-advanced.md) § di |

## Deep-Dive References

- [references/fastapi-advanced.md](references/fastapi-advanced.md) — nested/scoped
  dependency graphs, OAuth2 password + JWT flow, async session lifecycle and
  transaction patterns, `BackgroundTasks` vs task queue, `lifespan` events,
  dependency overrides in tests

## Related Skills

- [django](../django/SKILL.md) — batteries-included alternative when you want the ORM/admin/DRF stack
- [flask](../flask/SKILL.md) — lighter WSGI micro-service alternative
- system-developer:python-concurrency — event loop, `asyncio.TaskGroup`, async semantics
- system-developer:python-typing — Pydantic-adjacent typing, `Annotated`, generics
- [secure-coding](../../_shared/secure-coding/SKILL.md) — injection, secrets, validation hazards
- [api-security](../../quality/api-security/SKILL.md) — OWASP API Top 10 review (BOLA, authn/z, rate limiting)
- [be-testing](../../quality/be-testing/SKILL.md) — integration tests with `TestClient`/`httpx`, Testcontainers
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — framework/runtime version minimums
