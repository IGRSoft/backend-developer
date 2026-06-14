# Injection, SSRF, Rate Limiting & Misconfiguration (API4/6/7/8/9/10)

Defenses for the "untrusted input reaches a dangerous sink" and "no limits / wrong defaults" risk classes.

## Injection — never build a query from a string

### SQL

```python
cur.execute("SELECT * FROM users WHERE email = %s", (email,))   # GOOD
cur.execute(f"SELECT * FROM users WHERE email = '{email}'")       # BAD — injection
```

```go
db.QueryContext(ctx, "SELECT id FROM users WHERE email = $1", email) // GOOD
```

ORMs parameterize by default — but escape hatches re-open the hole:

```ts
// BAD — raw interpolation defeats Prisma's safety
await db.$queryRawUnsafe(`SELECT * FROM "User" WHERE email = '${email}'`);
// GOOD — tagged template parameterizes
await db.$queryRaw`SELECT * FROM "User" WHERE email = ${email}`;
```

Never concatenate user input into `ORDER BY`/column names (can't be parameterized) — allow-list against known columns instead.

### NoSQL (MongoDB)

```ts
// BAD — operator injection: body { "$gt": "" } matches everything
await users.findOne({ password: req.body.password });
// GOOD — coerce/validate to the expected scalar type first
const password = z.string().parse(req.body.password);
await users.findOne({ password });
```

### Command injection

Never pass user input to a shell. Use the array/exec form (no shell), with an allow-listed binary:

```python
subprocess.run(["convert", infile, outfile], shell=False)   # GOOD
subprocess.run(f"convert {infile} {outfile}", shell=True)    # BAD
```

See [secure-coding](../../../_shared/secure-coding/SKILL.md) for the full injection-safe process-execution rules.

## API7 — SSRF (Server-Side Request Forgery)

Any endpoint that fetches a user-supplied URL (webhooks, "import from URL", image proxy, oEmbed) can be coerced into hitting internal services or the cloud metadata endpoint (`169.254.169.254`).

Defense in depth:

1. **Allow-list destinations** — if you only need a handful of partners, only allow those hosts. This beats every block-list.
2. **Resolve then validate** — resolve the hostname and reject private/link-local/loopback ranges *before* connecting. Re-check after redirects (or disable cross-host redirects).
3. **Block dangerous schemes** — only `https` (and `http` if you must); never `file:`, `gopher:`, `ftp:`.
4. **Pin egress** — route outbound fetches through a proxy that enforces the allow-list; deny the metadata IP at the network layer.

```ts
import dns from "node:dns/promises";
import net from "node:net";

const BLOCKED = [
  "127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
  "169.254.0.0/16", "::1/128", "fc00::/7",
];
async function assertSafeUrl(raw: string) {
  const u = new URL(raw);
  if (u.protocol !== "https:") throw new Error("scheme not allowed");
  const { address } = await dns.lookup(u.hostname);
  if (BLOCKED.some((cidr) => inCidr(address, cidr))) throw new Error("blocked host");
  return u;
}
```

Note the TOCTOU gap between resolve and connect; for hard requirements, use an HTTP client that lets you validate the *connected* IP, or a vetted SSRF-protection library for your stack.

## API4 & API6 — Rate limiting and resource consumption

Unbounded consumption (API4) and unthrottled sensitive flows (API6) both come from missing limits.

```ts
// Express — token-bucket per principal, backed by Redis for multi-instance
import rateLimit from "express-rate-limit";
const limiter = rateLimit({
  windowMs: 60_000, limit: 100, standardHeaders: "draft-7",
  keyGenerator: (req) => req.user?.id ?? req.ip,  // per user, fall back to IP
});
app.use("/api", limiter);
```

```go
// chi + golang.org/x/time/rate, one limiter per key
func RateLimit(rps rate.Limit, burst int) func(http.Handler) http.Handler { /* per-key bucket */ }
```

Beyond rate limits, cap the work each request can demand:

- **Pagination** — enforce a max page size; reject `limit=1000000`.
- **Payload caps** — body size limit (e.g. `express.json({ limit: "100kb" })`).
- **Timeouts** — request, DB query, and upstream-call timeouts so one slow dependency can't pin all workers (see [be-performance](../../be-performance/SKILL.md) for backpressure).
- **Query-complexity limits** for GraphQL (depth/cost analysis) to stop expensive nested queries.
- **Stricter limits on sensitive flows** (API6): login, signup, password reset, payment, invite — per account and per IP.

## API8 — Security misconfiguration

- **CORS** — allow-list exact origins; never `Access-Control-Allow-Origin: *` together with credentials. Echo only allowed origins.
- **Security headers** — `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy` (for HTML responses), `X-Frame-Options`/`frame-ancestors`. Use a helper (`helmet` for Express, Spring Security headers, `secure` middleware) but tune it.
- **No stack traces / internals in error responses** — return a generic message + correlation id; log the detail server-side (see [secure-coding](../../../_shared/secure-coding/SKILL.md) error-message hygiene).
- **Disable debug endpoints, default creds, directory listing, verbose `Server` headers** in production.
- **TLS everywhere**, modern ciphers, HTTP→HTTPS redirect.

```ts
app.use(cors({
  origin: (o, cb) => cb(null, ALLOWED_ORIGINS.includes(o)),
  credentials: true,
}));
```

## API9 — Improper inventory management

- Maintain an inventory of every deployed endpoint and version (an OpenAPI/AsyncAPI spec checked in CI is the source of truth).
- Retire old API versions deliberately; no forgotten `/v1`, `/debug`, `/internal`, or staging hosts reachable from the internet.
- Document host environments (prod/staging/dev) and keep non-prod off the public network or behind auth.

## API10 — Unsafe consumption of upstream APIs

Treat data from third parties as hostile, just like user input:

- Validate upstream responses against a schema before use; don't blindly trust shape, size, or content.
- Set timeouts and size caps on upstream calls; an upstream redirect can itself become an SSRF (validate redirect targets).
- Don't forward upstream errors verbatim to your clients (info leak); map to your own error contract.

## Scanning & verification

- **DAST** — OWASP ZAP baseline scan against a running instance in CI.
- **Schema fuzzing** — Schemathesis drives the OpenAPI spec with malformed input to surface 500s and contract violations (overlaps [be-testing](../../be-testing/SKILL.md)).
- **Dependency/image CVEs** — `npm audit` / `osv-scanner` / `govulncheck` / `trivy` each CI run. Route findings via the [be-security-auditor](../../../_shared/../) review and [be-dependency-manager](../../../_shared/../).

Versions: skill [version-feature-matrix](../../../_shared/version-feature-matrix.md).

## Checklist

- [ ] All queries parameterized; ORM raw escape hatches use bound params; `ORDER BY`/columns allow-listed.
- [ ] NoSQL inputs coerced to expected scalar types (no operator injection).
- [ ] No shell string-building; exec uses the array form with an allow-listed binary.
- [ ] URL-fetching endpoints allow-list destinations and block private/metadata IPs after DNS resolution.
- [ ] Rate limiting per principal + IP; page-size, payload, and timeout caps set.
- [ ] Sensitive flows (login/signup/reset/payment) have stricter, per-account limits.
- [ ] CORS allow-lists exact origins; security headers set; no internals in error bodies.
- [ ] Endpoint inventory maintained; old versions/debug routes retired.
- [ ] Upstream responses schema-validated; upstream calls timed and size-capped.
