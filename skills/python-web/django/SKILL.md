---
name: django
description: >-
  Django and Django REST Framework services: models + migrations, serializers
  and validation, viewsets/routers, ORM optimization (select_related/
  prefetch_related for N+1), auth/permissions, and async views. Use when
  building or reviewing a Django/DRF service, designing models or migrations,
  fixing N+1 queries, or enforcing permissions. Python language depth →
  system-developer:python-skills.
---

# Django / DRF

**Batteries-included web services: ORM + migrations + DRF serializers, viewsets, and permissions**

## When to Use

Use this skill when:
- Building a Django service or a Django REST Framework (DRF) API
- Designing models and writing/reviewing migrations (safety, reversibility)
- Writing DRF serializers (validation) and viewsets/routers
- Diagnosing and fixing N+1 query patterns in the ORM
- Wiring authentication and per-object/per-view permissions
- Adding async views or async ORM calls (Django 4.1+/5.x)

For Python *language* concerns — typing, asyncio internals, uv/ruff/pytest — use
`system-developer:python-skills`. This skill owns the Django + DRF + persistence
layer. Query optimization, transactions, custom permissions, and migration
safety in depth: [references/django-advanced.md](references/django-advanced.md).

## Version Markers & Fallbacks

| Feature | Needs | Fallback |
|---------|-------|----------|
| Async views (`async def` view) | Django 4.1+ | sync views; `sync_to_async` wrapper |
| Async ORM (`aget`/`acreate`/`async for`) | Django 4.1+ (broadened 5.0) | `sync_to_async(qs.get)` shim |
| `GeneratedField` / `db_default` | Django 5.0+ | computed in `save()` / model default |
| DRF 3.15 serializer `UniqueValidator` async-safe paths | DRF 3.15+ | manual `validate_*` checks |

Pin `django`, `djangorestframework` in `pyproject.toml`/`uv.lock`. Canonical
version lookup: skill: version-feature-matrix
(`../../_shared/version-feature-matrix.md`).

## Models & Migrations

Models are the schema source of truth; migrations are generated and reviewed, not
hand-edited casually.

```python
from django.db import models

class Author(models.Model):
    name = models.CharField(max_length=120)

class Book(models.Model):
    title = models.CharField(max_length=200)
    author = models.ForeignKey(Author, on_delete=models.CASCADE,
                               related_name="books")
    published = models.DateField(db_index=True)

    class Meta:
        indexes = [models.Index(fields=["author", "published"])]
```

```bash
uv run python manage.py makemigrations app       # generate migration
uv run python manage.py migrate                   # apply (logs = evidence)
uv run python manage.py sqlmigrate app 0002       # inspect generated SQL first
```

Migration safety (a DR gate): adding a non-null column without a default locks
the table on large datasets — add it nullable, backfill, then enforce. Keep
migrations reversible. See
[references/django-advanced.md](references/django-advanced.md) § migrations.

## DRF Serializers & Validation

Serializers validate input and shape output — input is never trusted past the
serializer.

```python
from rest_framework import serializers

class BookSerializer(serializers.ModelSerializer):
    class Meta:
        model = Book
        fields = ["id", "title", "author", "published"]
        read_only_fields = ["id"]

    def validate_title(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError("title cannot be blank")
        return value
```

Controlling `fields` is an **API3 (broken object property-level authorization)**
control: a field not listed is neither writable nor returned, so internal columns
(e.g. `cost_price`) never leak. Use distinct read/write serializers when input and
output diverge.

## Viewsets & Routers

`ModelViewSet` + a router gives the standard CRUD surface with minimal code; drop
to `APIView` when you need bespoke behavior.

```python
from rest_framework import viewsets, permissions
from rest_framework.routers import DefaultRouter

class BookViewSet(viewsets.ModelViewSet):
    serializer_class = BookSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # BOLA (API1): scope to the requesting user, never return all rows
        return (Book.objects
                .filter(author__owner=self.request.user)
                .select_related("author"))        # avoid N+1 on author

router = DefaultRouter()
router.register("books", BookViewSet, basename="book")
urlpatterns = router.urls
```

The `get_queryset` scoping is the BOLA boundary — filtering by `request.user`
ensures a user cannot read or mutate another user's objects via a guessed id.

## ORM & N+1

The single most common Django performance bug. Use `select_related` (SQL join,
for FK/one-to-one) and `prefetch_related` (separate query, for reverse FK /
many-to-many).

```python
# BAD: 1 query for books + N queries (one per book.author)
for book in Book.objects.all():
    print(book.author.name)                       # lazy load each iteration → N+1

# GOOD: 1 query, author joined
for book in Book.objects.select_related("author"):
    print(book.author.name)

# GOOD: collections — 2 queries total regardless of count
authors = Author.objects.prefetch_related("books")
```

N+1 detection is a DR review gate. Capture query counts in tests with
`assertNumQueries`. Deeper tuning (`Prefetch`, `only`/`defer`):
[references/django-advanced.md](references/django-advanced.md) § queries.

## Auth & Permissions (API2 / API5)

Authentication is middleware/DRF auth classes; authorization is permission
classes — never inline `if` checks scattered across views.

```python
from rest_framework.permissions import BasePermission, SAFE_METHODS

class IsOwnerOrReadOnly(BasePermission):
    def has_object_permission(self, request, view, obj) -> bool:
        if request.method in SAFE_METHODS:
            return True
        return obj.author.owner_id == request.user.id   # object-level (API1/API5)
```

`has_permission` gates the view (function-level, API5); `has_object_permission`
gates the specific instance (object-level, API1). Both run for detail routes.
Custom permission patterns: [references/django-advanced.md](references/django-advanced.md) § permissions.

## Async Views

Django supports `async def` views and async ORM methods. The ORM is async-capable
but still issues one query at a time per connection — async helps with concurrent
external I/O, not parallel SQL on one connection.

```python
from django.http import JsonResponse

async def book_count(request):
    count = await Book.objects.filter(author__owner=request.user).acount()
    return JsonResponse({"count": count})
```

Mixing sync ORM in an async view raises `SynchronousOnlyOperation` — wrap with
`sync_to_async` or use the `a`-prefixed async methods. See
[references/django-advanced.md](references/django-advanced.md) § async.

## Single-Command Build & Test

Scoped, single-invocation commands (no `cd`-chains). Runner/linter owned by
`system-developer:python-tooling`/`python-testing`:

```bash
uv run python manage.py migrate --check          # CI: fail on unapplied migrations
uv run pytest app/tests/ -q                       # pytest-django
uv run ruff check app/                            # lint
```

Evidence (cli-fallback, `requires_screenshots: false`): API request/response
transcripts (`curl`/`httpie`), pytest output, and migration logs — not build logs.

```bash
curl -s localhost:8000/api/books/ \
  -H "authorization: Token $TOK" | jq '.[0]'
```

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Endpoint slow, query count grows with rows | N+1 on a relationship | `select_related` (FK) / `prefetch_related` (reverse/M2M) | this file, ORM & N+1 |
| `SynchronousOnlyOperation` | sync ORM call inside `async def` view | use `aget`/`acount`/... or `sync_to_async` | [django-advanced.md](references/django-advanced.md) § async |
| Internal field returned in API JSON | field listed in serializer `fields` | drop it or split read/write serializers (API3) | this file, Serializers |
| User can fetch another user's object | `get_queryset` not scoped to user | filter by `request.user`; add `has_object_permission` (BOLA) | this file, Viewsets / Auth |
| Migration locks the table in prod | non-null column added with no default on a big table | add nullable → backfill → enforce; split migration | [django-advanced.md](references/django-advanced.md) § migrations |
| `IntegrityError` under concurrency | check-then-insert race | `select_for_update` in `transaction.atomic` or unique constraint | [django-advanced.md](references/django-advanced.md) § transactions |
| Permission bypassed on detail route | only `has_permission` defined | add `has_object_permission` for instance checks | this file, Auth |

## Deep-Dive References

- [references/django-advanced.md](references/django-advanced.md) — query
  optimization (`only`/`defer`/`Prefetch`), `transaction.atomic` +
  `select_for_update`, custom DRF permission and throttle classes, migration
  safety (zero-downtime patterns), async ORM caveats

## Related Skills

- [fastapi](../fastapi/SKILL.md) — async-first alternative when you don't need the full Django stack
- [flask](../flask/SKILL.md) — lighter micro-framework alternative
- system-developer:python-typing — typing models/serializers, generics
- system-developer:python-concurrency — async semantics behind async views
- [secure-coding](../../_shared/secure-coding/SKILL.md) — injection, secrets, validation hazards
- [api-security](../../quality/api-security/SKILL.md) — OWASP API Top 10 review (BOLA, authn/z, rate limiting)
- [be-testing](../../quality/be-testing/SKILL.md) — pytest-django, `assertNumQueries`, Testcontainers
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — framework/runtime version minimums
