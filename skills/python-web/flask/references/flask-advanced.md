# Flask — Advanced Patterns

Deep-dive companion to [../SKILL.md](../SKILL.md). Covers factory + blueprint
composition, SQLAlchemy session scoping, extension order, production worker
tuning, and layered config. Python *language* depth stays in
`system-developer:python-skills`.

## factory — Factory & Blueprint Composition

The factory builds everything per-call so tests get isolated apps and you can run
multiple configs. Extensions are constructed at module scope but **bound** inside
the factory.

```python
# app/extensions.py — constructed unbound
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
db = SQLAlchemy()
migrate = Migrate()

# app/__init__.py — bound in the factory
def create_app(config_object: str = "app.config.Prod") -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_object)
    app.config.from_prefixed_env()           # FLASK_*; secrets from env (API8)

    db.init_app(app)
    migrate.init_app(app, db)                 # order: db before migrate

    register_blueprints(app)
    register_error_handlers(app)
    return app

def register_blueprints(app: Flask) -> None:
    from app.users import bp as users_bp
    from app.orders import bp as orders_bp
    app.register_blueprint(users_bp, url_prefix="/users")
    app.register_blueprint(orders_bp, url_prefix="/orders")
```

`RuntimeError: working outside of application context` means an extension or
`db.session` was touched without an app context — it is almost always an
extension used at import time instead of bound in the factory. In scripts, wrap
work in `with app.app_context():`.

## sessions — SQLAlchemy Session Scoping & Teardown

Flask-SQLAlchemy scopes `db.session` to the request and removes it on teardown, so
each request gets its own session and connections return to the pool. Two failure
modes:

- **`DetachedInstanceError`** — using an ORM object after its session closed
  (e.g. returning it from a background thread, or accessing a lazy attribute past
  the request). Keep ORM work inside the request scope, or re-query.
- **N+1** — lazy relationship access in a loop. Eager-load in the query.

```python
from sqlalchemy.orm import selectinload
from sqlalchemy import select

stmt = (select(Order)
        .where(Order.user_id == g.current_user.id)   # BOLA scope (API1)
        .options(selectinload(Order.items)))          # 1 extra query, not N
orders = db.session.scalars(stmt).all()
```

Commit explicitly; on error, roll back. Wrap multi-statement mutations in a
transaction and lock contended rows:

```python
with db.session.begin():                     # commit on success, rollback on raise
    acct = db.session.get(Account, acct_id, with_for_update=True)
    if acct.balance < amount:
        abort(409, "insufficient funds")
    acct.balance -= amount
```

Idempotency (a DR gate): persist an idempotency key with a unique constraint for
create/charge endpoints; return the prior result on replay.

## extensions — Initialization Order

Bind dependencies before dependents: `db.init_app` before `migrate.init_app`;
auth/session extensions before blueprints that use them. Common set:

```python
login_manager.init_app(app)     # Flask-Login — session cookie auth
jwt.init_app(app)               # Flask-JWT-Extended — verify sig + exp (API2)
limiter.init_app(app)           # Flask-Limiter — rate limit (API4)
cors.init_app(app, origins=settings.ALLOWED_ORIGINS)   # tight origins (API8)
```

Rate limiting is an OWASP API4 control and CORS origin scoping an API8 control —
see [../../../quality/api-security/SKILL.md](../../../quality/api-security/SKILL.md).

## deployment — Production WSGI / ASGI

The dev server is single-threaded; production uses Gunicorn (WSGI) or Uvicorn
(ASGI, for async views).

```bash
# sync WSGI — workers ~= 2*cores+1; tune by load test (k6), not guesswork
uv run gunicorn "app:create_app()" \
  --workers 5 --timeout 30 --graceful-timeout 30 --bind 0.0.0.0:8000

# async ASGI
uv run uvicorn "app.asgi:asgi_app" --workers 4 --host 0.0.0.0 --port 8000
```

Container checklist:
- Health endpoint (`GET /health`) wired for the orchestrator liveness/readiness.
- Run as non-root; read secrets from env/secret store (API8), never baked in.
- One process group per container; let the orchestrator handle restarts.
- Structured JSON logs to stdout; propagate trace context (OpenTelemetry).

## config — Layered Configuration

Class-based config with env overrides; secrets only from the environment.

```python
class Base:
    JSON_SORT_KEYS = False
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True}

class Dev(Base):
    DEBUG = True

class Prod(Base):
    DEBUG = False
    # SECRET_KEY / DATABASE_URL come from FLASK_* env (from_prefixed_env), never here
```

## Evidence (cli-fallback)

`requires_screenshots: false`. Acceptable evidence: `curl`/`httpie`
transcripts, pytest output, k6 load reports, and Flask-Migrate (`db upgrade`)
logs — not build logs.

```bash
uv run pytest tests -q
uv run flask --app "app:create_app" db upgrade
```

## See Also

- [../SKILL.md](../SKILL.md) — Flask overview and version markers
- [../../fastapi/SKILL.md](../../fastapi/SKILL.md) · [../../django/SKILL.md](../../django/SKILL.md) — sibling frameworks
- `system-developer:python-concurrency` — async view semantics
- [../../../quality/api-security/SKILL.md](../../../quality/api-security/SKILL.md) — OWASP API Top 10
- [../../../quality/be-testing/SKILL.md](../../../quality/be-testing/SKILL.md) — pytest + test client, Testcontainers
