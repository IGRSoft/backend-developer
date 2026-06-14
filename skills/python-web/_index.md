# Python Web Skills Index

Quick navigation for the `skills/python-web/` subtree. Start at [SKILL.md](SKILL.md)
for the guided entry with version snapshot and decision tree.

This domain owns the **web framework + persistence layer** only. Python *language*
depth (modern syntax, typing, asyncio internals, free-threading, uv/ruff
packaging, pytest mechanics) lives in `system-developer:python-skills` — link to
it, never duplicate it.

## Skills

| Skill | Use it for |
|-------|------------|
| [fastapi/SKILL.md](fastapi/SKILL.md) | Async routes, Pydantic v2 validation, `Annotated` dependency injection, automatic OpenAPI 3.1, auth dependencies, async SQLAlchemy/ORM, background tasks |
| [django/SKILL.md](django/SKILL.md) | Models + migrations, DRF serializers/validation, viewsets/routers, ORM `select_related`/`prefetch_related` (N+1), auth/permissions, async views |
| [flask/SKILL.md](flask/SKILL.md) | Blueprints, app factory pattern, request validation (marshmallow/pydantic), SQLAlchemy, extension ecosystem, production WSGI/ASGI deployment |

## References

| File | Use it for |
|------|------------|
| [fastapi/references/fastapi-advanced.md](fastapi/references/fastapi-advanced.md) | Nested dependency graphs, scoped/yield dependencies, OAuth2 password + JWT flow, async session lifecycle, `BackgroundTasks` vs task queue, lifespan events |
| [django/references/django-advanced.md](django/references/django-advanced.md) | Query optimization (`only`/`defer`/`Prefetch`), atomic transactions + `select_for_update`, custom DRF permissions, migration safety, async ORM caveats |
| [flask/references/flask-advanced.md](flask/references/flask-advanced.md) | Application factory + blueprint composition, SQLAlchemy session scoping, Flask extensions, Gunicorn/Uvicorn worker tuning, config layering |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Python language minimums / framework version pins (canonical) | `../_shared/version-feature-matrix.md` |
| Python language depth (typing, asyncio, packaging, pytest) | `system-developer:python-skills` |
| Injection, secrets, pickle/yaml/`shell=True`, OWASP API Top 10 | `../_shared/secure-coding/SKILL.md` |
| API security review (BOLA, auth, rate limiting) | `../quality/api-security/SKILL.md` |
| Backend testing (integration, Testcontainers, transcripts) | `../quality/be-testing/SKILL.md` |
| Workflow stage participation | `../_shared/workflow-integration/SKILL.md` |
