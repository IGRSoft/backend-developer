---
name: flask
description: >-
  Flask web services: blueprints, the application factory pattern, request
  validation (marshmallow/pydantic), SQLAlchemy, the extension ecosystem, and
  production WSGI/ASGI deployment. Use when building or reviewing a Flask app,
  structuring blueprints, validating requests, wiring SQLAlchemy, or choosing a
  production server. Python language depth → system-developer:python-skills.
---

# Flask

**Lightweight WSGI services: app factory + blueprints, explicit validation, and SQLAlchemy**

## When to Use

Use this skill when:
- Building a Flask micro-service or API, or reviewing one
- Structuring code with the application factory + blueprints
- Validating requests (marshmallow or pydantic — Flask has no built-in validation)
- Wiring SQLAlchemy (Flask-SQLAlchemy or plain SQLAlchemy 2.x sessions)
- Choosing and configuring extensions
- Deploying behind a production WSGI (Gunicorn/uWSGI) or ASGI (Uvicorn) server

For Python *language* concerns — typing, asyncio internals, uv/ruff/pytest — use
`system-developer:python-skills`. This skill owns the Flask + persistence layer.
Factory/blueprint composition, session scoping, and worker tuning in depth:
[references/flask-advanced.md](references/flask-advanced.md).

## Version Markers & Fallbacks

Target current **Flask 3.1+ on Werkzeug 3.1+** (the maintained line) for new
services; the older 2.x/3.0 fallbacks remain only for code that hasn't migrated.
Exact floors live in the matrix — link, don't restate.

| Feature | Since | Fallback (legacy only) |
|---------|-------|------------------------|
| Async view functions (`async def`) | Flask 2.0+ (`flask[async]`) | sync views; run async work via a queue |
| `flask --app` CLI / factory autodetect | Flask 2.2+ | `FLASK_APP` env var |
| Flask 3.1 on Werkzeug 3.1 (current maintained line) | Flask 3.1+ | Flask 3.0/2.3 on Werkzeug 2/3.0 |
| Flask-SQLAlchemy 3.1 (SQLAlchemy 2.0 typed API) | Flask-SQLAlchemy 3.1+ | 2.x legacy `Query` API |

Pin `flask`, `flask-sqlalchemy` (or `sqlalchemy`), and your validation lib in
`pyproject.toml`/`uv.lock`. Canonical version lookup (current floors): skill: version-feature-matrix
(`../../_shared/version-feature-matrix.md`).

## App Factory

Build the app inside a function so config, extensions, and blueprints are wired
per-instance — essential for testing (each test gets a fresh app) and for
running multiple configurations.

```python
from flask import Flask

def create_app(config_object: str = "app.config.Prod") -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_object)
    app.config.from_prefixed_env()          # FLASK_SECRET_KEY etc. (API8: no hardcoded secrets)

    db.init_app(app)                         # extensions bound to this app
    from app.users import bp as users_bp
    app.register_blueprint(users_bp, url_prefix="/users")
    return app
```

```bash
uv run flask --app "app:create_app" run     # dev server (never production)
```

Never instantiate `Flask(__name__)` at import time with globals — that defeats
the factory and breaks test isolation. See
[references/flask-advanced.md](references/flask-advanced.md) § factory.

## Blueprints

Blueprints partition routes by feature; the factory composes them. Each blueprint
is a module with its own views, kept thin.

```python
from flask import Blueprint, request, jsonify, abort

bp = Blueprint("users", __name__)

@bp.get("/<int:user_id>")
def get_user(user_id: int):
    user = db.session.get(User, user_id)
    if user is None:
        abort(404)
    # BOLA (API1): confirm ownership before returning
    if user.owner_id != g.current_user.id:
        abort(403)
    return jsonify(UserSchema().dump(user))
```

## Request Validation (marshmallow / pydantic)

Flask does not validate input — wire marshmallow or pydantic explicitly. Validate
at the boundary; reject before touching the database.

```python
from marshmallow import Schema, fields, ValidationError

class UserCreateSchema(Schema):
    email = fields.Email(required=True)
    age = fields.Integer(required=True, validate=lambda v: 0 <= v <= 130)

@bp.post("/")
def create_user():
    try:
        data = UserCreateSchema().load(request.get_json())   # raises on bad input
    except ValidationError as err:
        return jsonify(errors=err.messages), 422
    user = User(**data)
    db.session.add(user)
    db.session.commit()
    return jsonify(UserSchema().dump(user)), 201
```

The dump schema controls which fields are serialized (API3 — internal columns
like `password_hash` never appear). pydantic works equally well if you prefer it
across services; pick one per service for consistency.

## SQLAlchemy

Use Flask-SQLAlchemy (or plain SQLAlchemy 2.x with a scoped session). One session
per request; commit explicitly; always parameterize.

```python
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import select

db = SQLAlchemy()

# parameterized — never f-string interpolation into SQL (injection)
stmt = select(User).where(User.email == email)        # bound param, safe
user = db.session.scalars(stmt).first()
```

The request-scoped session is torn down automatically at the end of the request.
Avoid lazy-loading relationships in a loop (N+1) — use `selectinload`/
`joinedload`. Session scoping and teardown:
[references/flask-advanced.md](references/flask-advanced.md) § sessions.

## Extensions

Flask's power is its extension ecosystem. Common, reviewable choices:

| Need | Extension | Note |
|------|-----------|------|
| Auth sessions / login | Flask-Login | session cookie auth |
| JWT auth | Flask-JWT-Extended | verify signature + exp (API2) |
| Rate limiting | Flask-Limiter | resource-consumption control (API4) |
| Migrations | Flask-Migrate (Alembic) | reviewable, reversible migrations |
| CORS | Flask-CORS | scope origins tightly (API8) |

Initialize each via `ext.init_app(app)` in the factory — never at module import.

## Production WSGI / ASGI

The dev server (`flask run`) is single-threaded and not for production. Serve via
a production server:

```bash
# WSGI (sync) — Gunicorn, the common default
uv run gunicorn "app:create_app()" --workers 4 --bind 0.0.0.0:8000

# ASGI (async views) — Uvicorn via an ASGI shim
uv run uvicorn "app.asgi:asgi_app" --workers 4 --host 0.0.0.0 --port 8000
```

Worker count rule of thumb: `2 * cores + 1` for sync workers; tune via load test,
not guesswork. Container/health-check and worker tuning:
[references/flask-advanced.md](references/flask-advanced.md) § deployment.

## Single-Command Build & Test

Scoped, single-invocation commands (no `cd`-chains). Runner/linter owned by
`system-developer:python-tooling`/`python-testing`:

```bash
uv run pytest tests/ -q                  # uses app factory + test client
uv run ruff check app/                   # lint
uv run flask --app "app:create_app" db upgrade   # Flask-Migrate (Alembic)
```

Evidence (cli-fallback, `requires_screenshots: false`): `curl`/`httpie`
request/response transcripts, pytest output, migration logs — not build logs.

```bash
curl -s -X POST localhost:8000/users/ \
  -H 'content-type: application/json' \
  -d '{"email":"a@b.co","age":30}' | jq .
```

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Tests bleed state into each other | app created once at import | use `create_app()` per test (factory) | this file, App Factory |
| `RuntimeError: working outside of application context` | extension used before `init_app`/no app context | bind via factory; use `with app.app_context()` | [flask-advanced.md](references/flask-advanced.md) § factory |
| Unvalidated field reaches the DB | no schema on the route | `Schema().load(...)` before persisting (422 on error) | this file, Validation |
| Internal field in JSON response | dump schema includes it | drop from the dump schema (API3) | this file, Validation |
| Any user reads any record | no ownership check | compare `obj.owner_id` to current user (BOLA/API1) | this file, Blueprints |
| N+1 on list endpoint | lazy relationship in a loop | `selectinload`/`joinedload` in the `select()` | [flask-advanced.md](references/flask-advanced.md) § sessions |
| `flask run` falls over under load | dev server in production | Gunicorn/Uvicorn with tuned workers | this file, Production |
| `DetachedInstanceError` | object used after session closed | keep work inside the request scope / re-query | [flask-advanced.md](references/flask-advanced.md) § sessions |

## Deep-Dive References

- [references/flask-advanced.md](references/flask-advanced.md) — application
  factory + blueprint composition patterns, SQLAlchemy session scoping and
  teardown, extension initialization order, Gunicorn/Uvicorn worker tuning and
  health checks, layered config (dev/test/prod)

## Related Skills

- [fastapi](../fastapi/SKILL.md) — async-first alternative with built-in validation + OpenAPI
- [django](../django/SKILL.md) — batteries-included alternative (ORM/admin/DRF)
- system-developer:python-typing — typing schemas and views, generics
- system-developer:python-concurrency — async view semantics, the event loop
- [secure-coding](../../_shared/secure-coding/SKILL.md) — injection, secrets, validation hazards
- [api-security](../../quality/api-security/SKILL.md) — OWASP API Top 10 review (BOLA, authn/z, rate limiting)
- [be-testing](../../quality/be-testing/SKILL.md) — pytest + test client, Testcontainers
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — framework/runtime version minimums
