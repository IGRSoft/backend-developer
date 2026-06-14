# FastAPI — Advanced Patterns

Deep-dive companion to [../SKILL.md](../SKILL.md). Covers nested dependency
graphs, OAuth2/JWT, async session lifecycle, background work routing, lifespan,
and test overrides. Python *language* depth (asyncio internals, typing) stays in
`system-developer:python-skills`.

## di — Nested & Scoped Dependencies

Dependencies compose: a dependency can declare its own dependencies, and FastAPI
resolves the graph once per request, caching each provider's result within that
request (`use_cache=True` by default).

```python
from typing import Annotated
from fastapi import Depends

async def get_settings() -> Settings:           # cached per request
    return Settings()

async def get_session(
    settings: Annotated[Settings, Depends(get_settings)],
) -> AsyncIterator[AsyncSession]:
    engine = make_engine(settings.database_url)
    async with AsyncSession(engine) as session:
        yield session

async def get_repo(
    session: Annotated[AsyncSession, Depends(get_session)],
) -> UserRepo:
    return UserRepo(session)                     # same session as the route uses
```

Disable per-request caching with `Depends(provider, use_cache=False)` only when a
provider must run fresh each time it appears in the graph (rare; usually a smell).

### Overriding in tests

Override the **exact callable** registered as the dependency, not a wrapper:

```python
app.dependency_overrides[get_session] = lambda: fake_session
# ... run TestClient requests ...
app.dependency_overrides.clear()                 # always reset between tests
```

## auth — OAuth2 Password Flow + JWT

A complete, reviewable auth boundary. Verify signature **and** expiry; never
trust claims without verification (API2).

```python
import jwt                                        # PyJWT
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from fastapi.security import OAuth2PasswordRequestForm

ALGO = "HS256"

def issue_token(sub: str, secret: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {"sub": sub, "iat": now, "exp": now + timedelta(minutes=15)}
    return jwt.encode(payload, secret, algorithm=ALGO)

@app.post("/auth/token")
async def login(
    form: Annotated[OAuth2PasswordRequestForm, Depends()],
    session: SessionDep,
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict[str, str]:
    user = await authenticate(session, form.username, form.password)
    if user is None:
        raise HTTPException(401, "incorrect username or password")
    return {"access_token": issue_token(user.email, settings.jwt_secret),
            "token_type": "bearer"}

async def current_user(
    token: Annotated[str, Depends(oauth2)],
    session: SessionDep,
    settings: Annotated[Settings, Depends(get_settings)],
) -> User:
    try:
        claims = jwt.decode(token, settings.jwt_secret, algorithms=[ALGO])
    except jwt.PyJWTError:
        raise HTTPException(401, "invalid token",
                            headers={"WWW-Authenticate": "Bearer"})
    user = await session.scalar(select(User).where(User.email == claims["sub"]))
    if user is None:
        raise HTTPException(401, "user no longer exists")
    return user
```

Notes:
- `authenticate` must use a constant-time password check (`argon2`/`bcrypt`
  `verify`), never `==` on hashes.
- The JWT secret comes from settings/env (API8 misconfiguration; secrets hygiene)
  — never hardcoded. See [../../../_shared/secure-coding/SKILL.md](../../../_shared/secure-coding/SKILL.md).
- Pin `algorithms=[ALGO]` explicitly; never accept `alg` from the token (the
  `alg: none` attack).

## sessions — Async Session Lifecycle & Transactions

One `AsyncSession` per request. Sharing a session across concurrent requests
corrupts state ("another operation is in progress"). The yield-dependency owns
creation and teardown; routes own commit boundaries.

```python
async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:        # SessionLocal = async_sessionmaker
        yield session
        # context manager rolls back if no explicit commit + exception

@app.post("/transfer")
async def transfer(cmd: TransferCmd, session: SessionDep) -> dict[str, str]:
    async with session.begin():                  # atomic: commit on success, rollback on raise
        src = await session.get(Account, cmd.src, with_for_update=True)
        dst = await session.get(Account, cmd.dst, with_for_update=True)
        if src.balance < cmd.amount:
            raise HTTPException(409, "insufficient funds")  # rolls back the block
        src.balance -= cmd.amount
        dst.balance += cmd.amount
    return {"status": "ok"}
```

Idempotency: for create/charge endpoints, accept an `Idempotency-Key` header,
persist it with a unique constraint, and return the prior result on replay — a DR
review gate.

### queries — N+1 Avoidance

Eager-load relationships in the `select()`; never trigger lazy loads in a loop.

```python
from sqlalchemy.orm import selectinload

stmt = (select(Order)
        .where(Order.user_id == user_id)
        .options(selectinload(Order.items)))     # one extra query, not N
orders = (await session.scalars(stmt)).all()
```

- `selectinload` — separate `IN` query; best for collections.
- `joinedload` — single join; best for many-to-one / one-to-one.

## background — BackgroundTasks vs Task Queue

| Need | Use |
|------|-----|
| Fire-and-forget, best-effort, short, no durability | `BackgroundTasks` (in-process, after response) |
| Must survive restart, retries, independent scaling, scheduling | External task queue (Celery / RQ / Arq) or message consumer (Kafka/RabbitMQ/SQS) |

`BackgroundTasks` runs in the same worker; a crash before it finishes loses the
work and it competes with request handling for the loop. For anything that
matters, enqueue a durable job and let a separate worker process it.

## lifespan — Startup/Shutdown

Use the `lifespan` async context manager (the `on_event` decorators are
deprecated). Open pools on startup, close on shutdown.

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.engine = create_async_engine(settings.database_url)
    yield
    await app.state.engine.dispose()             # clean shutdown

app = FastAPI(lifespan=lifespan)
```

## Evidence (cli-fallback)

`requires_screenshots: false`. Acceptable evidence: `httpx`/`curl`
request/response transcripts, pytest output, k6 load reports, migration logs.

```bash
uv run pytest tests/integration -q               # Testcontainers Postgres
curl -s localhost:8000/users/1 -H "authorization: Bearer $TOK" | jq .
```

## See Also

- [../SKILL.md](../SKILL.md) — FastAPI overview and version markers
- [../../django/SKILL.md](../../django/SKILL.md) · [../../flask/SKILL.md](../../flask/SKILL.md) — sibling frameworks
- `system-developer:python-concurrency` — event loop and async semantics
- [../../../quality/api-security/SKILL.md](../../../quality/api-security/SKILL.md) — OWASP API Top 10 review
- [../../../quality/be-testing/SKILL.md](../../../quality/be-testing/SKILL.md) — integration testing, Testcontainers
