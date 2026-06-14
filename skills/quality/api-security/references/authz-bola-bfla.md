# Authorization: BOLA, BFLA, and Object-Property Authz (API1/3/5)

Deep dive for the top OWASP API risks. Authorization is enforcement, not configuration: it must run on the server, for every object, on every request.

## API1 — Broken Object Level Authorization (BOLA / IDOR)

The request is authenticated, but the handler trusts an `id` from the path/body and never verifies the caller owns that object.

### The ownership predicate belongs in the query

```ts
// Prisma — ownership is a WHERE clause, never a post-fetch `if`
const doc = await db.document.findFirst({
  where: { id, organizationId: req.user.orgId, ownerId: req.user.id },
});
if (!doc) return res.sendStatus(404);
```

```java
// Spring Data — scope the repository method to the principal
Optional<Order> o = orders.findByIdAndCustomerId(id, principal.customerId());
return o.map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
```

```python
# SQLAlchemy / FastAPI
stmt = select(Invoice).where(Invoice.id == id, Invoice.tenant_id == user.tenant_id)
inv = (await session.execute(stmt)).scalar_one_or_none()
if inv is None:
    raise HTTPException(404)
```

### 404 vs 403

Return **404** when the caller is not allowed to know the object exists (the common case for tenant isolation). Reserve **403** for resources the caller knows about but lacks permission on. A 403 on an unknown id leaks existence — an enumeration oracle.

### Don't trust opaque-looking ids

UUIDs are not authorization. They reduce *guessability*, not *authority*. A leaked, logged, or shared UUID is still a valid object reference — the ownership check is what stops misuse.

## API5 — Broken Function Level Authorization (BFLA)

The caller invokes an operation their role/scope does not permit (admin route, bulk export, another tenant's function). Gateways and UI gating are not enough; re-check in the handler.

```go
// Middleware that re-checks role per privileged route group
func RequireRole(role string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            if !auth.FromContext(r.Context()).HasRole(role) {
                http.Error(w, "forbidden", http.StatusForbidden)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}
admin.Use(RequireRole("admin")) // applied to the admin sub-router
```

```csharp
// ASP.NET Core — policy-based authz on the action
[Authorize(Policy = "CanManageUsers")]
[HttpDelete("users/{id}")]
public async Task<IActionResult> Delete(Guid id) { /* ... */ }
```

### RBAC vs ABAC

- **RBAC** — permission keyed on a role (`admin`, `billing`). Simple; coarse. Good for function-level gates.
- **ABAC** — permission computed from attributes of subject, object, and context (`order.ownerId == user.id && order.status == "draft"`). Necessary for object-level rules and multi-tenant ownership. Most real systems combine: RBAC for the route, ABAC for the object.

Centralize the policy (a `can(user, action, object)` function or an engine like OPA/Cedar) so the rule is testable and lives in one place, not scattered across handlers.

## API3 — Broken Object Property Level Authorization

Two failure modes on the *fields* of an object.

### Mass-assignment (excessive input)

The client sends fields it should not control (`role`, `isAdmin`, `balance`, `tenantId`). Allow-list input with a schema or DTO; never bind the whole request body to an entity.

```ts
const CreateUser = z.object({ email: z.string().email(), name: z.string() });
const data = CreateUser.parse(req.body); // role can't slip in — not in the schema
```

```java
// Use a request DTO with only client-settable fields; map explicitly to the entity.
public record CreateUserRequest(@Email String email, @NotBlank String name) {}
// Never @RequestBody UserEntity user;  ← binds role/enabled/etc.
```

```ruby
# Rails strong parameters
params.require(:user).permit(:email, :name) # :role not permitted → ignored
```

### Excessive data exposure (over-broad output)

The serializer returns more than the caller may see (`passwordHash`, internal flags, other users' PII). Allow-list output fields with a response DTO/serializer — never return the raw entity.

```python
# Pydantic response model strips anything not declared
class UserOut(BaseModel):
    id: int
    email: EmailStr
    # password_hash deliberately absent
@app.get("/users/{id}", response_model=UserOut)
async def get_user(id: int): ...
```

## Multi-tenancy

Tenant isolation is BOLA at the tenant grain. Carry `tenantId` in the authenticated principal (from the token/session), inject it into *every* query, and consider Postgres Row-Level Security as defense-in-depth so a forgotten `WHERE` cannot leak across tenants.

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

## Testing authorization

Authz bugs are silent — they pass functional tests because the *owner's* request works. Add negative tests:

- User A cannot read/update/delete User B's object (expect 404/403).
- A non-privileged role hitting a privileged route (expect 403).
- A forbidden field in the body is ignored, not persisted.

See [be-testing](../../be-testing/SKILL.md) for fixtures that mint two principals, and Schemathesis for property-based coverage from the OpenAPI schema.

## Checklist

- [ ] Every object read/write scopes the query to the authenticated principal.
- [ ] Unknown/unauthorized ids return 404 (no existence leak).
- [ ] Every privileged route re-checks role/scope server-side.
- [ ] Input is allow-listed via schema/DTO (no mass-assignment).
- [ ] Output is allow-listed via response DTO (no over-exposure).
- [ ] Tenant id comes from the principal and is injected into every query.
- [ ] Negative authz tests exist for cross-user and cross-role access.
