---
name: python-web-skills
description: >-
  Python web framework skills navigation — FastAPI, Django, Flask. Use when
  writing or reviewing Python web services: async routes, ORM/persistence,
  request validation, auth, and migrations. Pure Python language depth (typing,
  asyncio internals, free-threading, packaging) links to system-developer:python/*.
---

# Python Web Skills

**Navigation and version snapshot for Python web-service development (FastAPI / Django / Flask)**

This domain owns the **web-framework + persistence layer**. For Python *language*
depth — modern syntax, static typing, asyncio internals, free-threading,
uv/ruff/packaging, pytest mechanics — defer to the system-developer python skills
(`system-developer:python-skills` and its leaves). Do not fork them here.

## Version Snapshot

| Framework | Headline (one line) |
|-----------|---------------------|
| FastAPI 0.115+ | Pydantic v2 validation, async-first routes, `Annotated` dependency injection, automatic OpenAPI 3.1; Starlette ASGI core |
| Django 5.x (5.0/5.1/5.2 LTS) | Async views/ORM (`acreate`/`aget`/async querysets), DRF 3.15 serializers + viewsets, `db_default`, `GeneratedField` |
| Flask 3.1 | App factory + blueprints, optional async views (ASGI via `asgiref`), Werkzeug 3 server gateway |
| Pydantic 2.x | Rust `pydantic-core`, `model_validate`/`model_dump`, `Annotated` constraints — the validation spine across FastAPI |
| SQLAlchemy 2.x | `Mapped[]`/`mapped_column` typed ORM, `select()` 2.0 style, async engine (`asyncpg`) |

Framework minutiae shift between releases — pin in `pyproject.toml`/`uv.lock` and
verify against your interpreter (`python3 -VV`) and installed versions
(`uv pip list`). Canonical lookup: skill: version-feature-matrix
(`_shared/version-feature-matrix.md`).

**Toolchain in one line (delegated):** `uv` (env + lock) · `ruff` (lint + format)
· `pyright`/`mypy` (CI gate) · `pytest` (tests) — all owned by
`system-developer:python-tooling` and `system-developer:python-testing`. This
domain adds the framework-specific layers on top.

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Build an async API with Pydantic v2 validation + DI + OpenAPI | [fastapi/SKILL.md](fastapi/SKILL.md) |
| Build a Django/DRF service: models, migrations, serializers, viewsets, ORM N+1 | [django/SKILL.md](django/SKILL.md) |
| Build a Flask app: blueprints, app factory, SQLAlchemy, production WSGI/ASGI | [flask/SKILL.md](flask/SKILL.md) |
| Add type annotations, generics, protocols, strict checking | system-developer:python-typing |
| Pick asyncio vs threads vs subinterpreters; understand the event loop | system-developer:python-concurrency |
| Set up uv, ruff, packaging, project structure | system-developer:python-tooling |
| Write or structure pytest tests (mechanics) | system-developer:python-testing |
| Enforce OWASP API Top 10 / injection / secrets hygiene | [_shared/secure-coding/SKILL.md](../_shared/secure-coding/SKILL.md) |

## Decision Tree

```
Python web task?
├── Which framework version has feature X? → version-feature-matrix (canonical)
├── Async API, Pydantic v2, OpenAPI auto-gen → fastapi/SKILL.md
│   ├── DI / auth dependency → fastapi/SKILL.md § Dependency Injection / Auth
│   └── async SQLAlchemy / background tasks → fastapi/SKILL.md § Persistence
├── Batteries-included / admin / DRF REST → django/SKILL.md
│   ├── N+1 (select_related/prefetch_related) → django/SKILL.md § ORM & N+1
│   └── serializers / permissions → django/SKILL.md § DRF
├── Lightweight / WSGI / micro-service → flask/SKILL.md
│   └── app factory + blueprints → flask/SKILL.md § App Factory
├── Language feature / typing / asyncio internals → system-developer:python-skills
├── API security (OWASP API Top 10, injection) → ../quality/api-security/SKILL.md
├── Testing strategy (integration, Testcontainers) → ../quality/be-testing/SKILL.md
└── Migrating language standard → /system-developer:code-modernize
```

## File Overview

| File | Purpose |
|------|---------|
| [_index.md](_index.md) | Full navigation for the python-web/ subtree |
| [fastapi/SKILL.md](fastapi/SKILL.md) | Async routes, Pydantic v2, DI, OpenAPI, auth deps, async SQLAlchemy, background tasks |
| [django/SKILL.md](django/SKILL.md) | Models + migrations, DRF serializers/viewsets, ORM N+1 fixes, auth/permissions, async views |
| [flask/SKILL.md](flask/SKILL.md) | Blueprints, app factory, request validation, SQLAlchemy, extensions, production WSGI/ASGI |

## Related Skills

- system-developer:python-skills — Python language depth (typing, asyncio, free-threading, tooling, pytest); **do not fork**
- [secure-coding](../_shared/secure-coding/SKILL.md) — injection, secrets, `shell=True`/pickle/yaml hazards, OWASP API Top 10 spine
- [api-security](../quality/api-security/SKILL.md) — BOLA/auth/rate-limit review for HTTP surfaces
- [be-testing](../quality/be-testing/SKILL.md) — integration tests, Testcontainers, API transcripts as evidence
- [version-feature-matrix](../_shared/version-feature-matrix.md) — canonical framework/runtime version minimums
