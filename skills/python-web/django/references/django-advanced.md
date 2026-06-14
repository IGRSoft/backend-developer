# Django / DRF — Advanced Patterns

Deep-dive companion to [../SKILL.md](../SKILL.md). Covers query optimization,
transactions, custom permissions/throttles, migration safety, and async ORM
caveats. Python *language* depth stays in `system-developer:python-skills`.

## queries — Query Optimization Beyond select/prefetch

- **`only` / `defer`** — fetch a column subset to cut row width on wide tables.
- **`Prefetch`** — customize the prefetch query (filter, order, nest).
- **`annotate` / aggregation** — push computation to the database, not Python.

```python
from django.db.models import Prefetch, Count

authors = (Author.objects
           .annotate(book_count=Count("books"))     # COUNT in SQL, not len()
           .prefetch_related(
               Prefetch("books",
                        queryset=Book.objects.filter(published__year=2026)
                                             .only("id", "title"))))
```

Guard against regressions in tests:

```python
with self.assertNumQueries(2):                       # 1 authors + 1 prefetch
    list(Author.objects.prefetch_related("books"))
```

A list endpoint whose query count scales with the number of returned rows is an
N+1 — the DR review rejects it.

## transactions — Atomicity & Locking

Wrap multi-statement mutations in `transaction.atomic`; lock contended rows with
`select_for_update` to avoid check-then-act races.

```python
from django.db import transaction

with transaction.atomic():
    account = (Account.objects
               .select_for_update()                  # row lock until commit
               .get(pk=account_id))
    if account.balance < amount:
        raise InsufficientFunds()                     # rollback the whole block
    account.balance -= amount
    account.save(update_fields=["balance"])
```

Idempotency (a DR gate): for create/charge endpoints, persist an idempotency key
with a unique constraint; on replay, return the prior result instead of
double-applying. Prefer a unique constraint + `IntegrityError` handling over
read-then-write checks under concurrency.

## permissions — Custom DRF Permissions & Throttles

Function-level (API5) and object-level (API1/API3) authorization belong in
permission classes; resource-consumption limits (API4) belong in throttles.

```python
from rest_framework.permissions import BasePermission
from rest_framework.throttling import ScopedRateThrottle

class HasOrgRole(BasePermission):
    required = "admin"
    def has_permission(self, request, view) -> bool:         # API5: view-level
        return request.user.role == self.required

class IsRowOwner(BasePermission):
    def has_object_permission(self, request, view, obj) -> bool:  # API1: object-level
        return obj.owner_id == request.user.id

class BurstThrottle(ScopedRateThrottle):                      # API4: rate limit
    scope = "burst"     # configure rate in settings: '20/min'
```

Wire throttles in `DEFAULT_THROTTLE_CLASSES`/`DEFAULT_THROTTLE_RATES`. Rate
limiting is an OWASP API4 control — see
[../../../quality/api-security/SKILL.md](../../../quality/api-security/SKILL.md).

## migrations — Zero-Downtime / Safety

Risky operations and their safe equivalents:

| Risky | Why | Safe pattern |
|-------|-----|--------------|
| Add non-null column (no default) on big table | full-table rewrite + lock | add nullable → data migration backfill → `AlterField` to non-null |
| Rename column | breaks running code mid-deploy | add new col → dual-write → backfill → switch reads → drop old |
| Drop column immediately | old code still references it | stop referencing → deploy → drop in a later migration |
| Add index without `CONCURRENTLY` (Postgres) | locks writes | `AddIndexConcurrently` (`django.contrib.postgres`), non-atomic migration |

Always inspect generated SQL before applying:

```bash
uv run python manage.py sqlmigrate app 0007
uv run python manage.py migrate --plan             # show what will run
```

Keep every migration reversible (`reverse_code` for `RunPython`); CI runs
`migrate --check` to fail on missing migrations.

## async — Async ORM Caveats

- Async views can call the `a`-prefixed ORM methods (`aget`, `acreate`,
  `acount`, `async for ... in qs`); the connection still serializes queries.
- Calling a sync ORM method inside `async def` raises `SynchronousOnlyOperation`
  — wrap legacy sync code with `asgiref.sync.sync_to_async`.
- Lazy `QuerySet` evaluation inside an async context is a trap: materialize with
  `async for` or `await qs.afirst()`, not bare iteration.

```python
from asgiref.sync import sync_to_async

@sync_to_async
def legacy_report(user_id: int) -> dict:
    return build_report(user_id)                   # sync ORM, runs in a thread

async def report_view(request):
    data = await legacy_report(request.user.id)
    return JsonResponse(data)
```

## Evidence (cli-fallback)

`requires_screenshots: false`. Acceptable evidence: `curl`/`httpie`
transcripts, pytest output (incl. `assertNumQueries`), k6 load reports, and
`manage.py migrate` logs — not build logs.

```bash
uv run pytest app/tests -q
uv run python manage.py migrate --check
```

## See Also

- [../SKILL.md](../SKILL.md) — Django/DRF overview and version markers
- [../../fastapi/SKILL.md](../../fastapi/SKILL.md) · [../../flask/SKILL.md](../../flask/SKILL.md) — sibling frameworks
- `system-developer:python-concurrency` — async semantics behind async views
- [../../../quality/api-security/SKILL.md](../../../quality/api-security/SKILL.md) — OWASP API Top 10
- [../../../quality/be-testing/SKILL.md](../../../quality/be-testing/SKILL.md) — pytest-django, Testcontainers
