# Command Execution and Injection (Node / Go / JVM / Python / Ruby / PHP / .NET)

Use this when:

- You build a SQL/NoSQL query, an ORM filter, or any data-driven command.
- You run an external program from a service, or make an outbound HTTP/network call to a host derived from input (SSRF surface).
- You are tempted to interpolate a variable into a query string, a shell command, or `eval`.
- A reviewer flagged an injection, SSRF, secrets, or supply-chain finding.

Skip this file if:

- You are validating or parsing the data itself. Use `input-validation-and-parsing.md`.
- You only need the rule summary. Use the parent `SKILL.md`.

Jump to:

- The Core Doctrine
- SQL — Parameterized Queries Only
- NoSQL — Operator Injection
- Subprocess — Argv, Never a Shell
- SSRF — Egress Allowlists
- Secrets — Secret Manager, Never argv or Logs
- Supply Chain — CVE Scanning
- Why Dynamic Code Execution Is Banned
- Execution Checklist

## The Core Doctrine

There are two ways to send data to an interpreter (a SQL engine, a shell, a deserializer):

1. **As code** — you concatenate the data into a string the interpreter parses. If any part came from untrusted input, the attacker controls the interpreter. This is **injection** (SQL, NoSQL, command).
2. **As data through a structured API** — you hand the interpreter a fixed program/template plus a separate vector of values (bound parameters, an `argv[]` array). The interpreter never parses the values as syntax. A value that happens to contain `'; DROP TABLE users; --` or `; rm -rf /` is just a literal.

**Always use the structured API.** The parameter/argument boundary is the security boundary: each value is exactly one parameter or one `argv` entry, with zero reinterpretation. There is no escaping to get right because the data never enters the grammar.

You only need a raw shell or raw SQL when you genuinely need a feature the structured API lacks. In that case, never put untrusted data in the string — pass it as a bound parameter / positional argument, or reject the operation.

## SQL — Parameterized Queries Only

```ts
// Node (pg): placeholders; the driver sends SQL and values on separate wire protocol fields.
await pool.query("UPDATE users SET email = $1 WHERE id = $2 AND tenant_id = $3",
                 [email, id, tenantId]);
```

```go
// Go (database/sql)
db.ExecContext(ctx, "UPDATE users SET email = ? WHERE id = ?", email, id)
```

```java
// JVM (JDBC)
try (var ps = conn.prepareStatement("UPDATE users SET email = ? WHERE id = ?")) {
    ps.setString(1, email); ps.setLong(2, id); ps.executeUpdate();
}
```

```python
# Python (DB-API / SQLAlchemy Core bound params)
cur.execute("UPDATE users SET email = %s WHERE id = %s", (email, id))
session.execute(text("UPDATE users SET email = :e WHERE id = :id"), {"e": email, "id": id})
```

- ORMs parameterize by default — Prisma/Drizzle/TypeORM query builders, GORM, JPA/Hibernate named params, SQLAlchemy expressions, Eloquent/Doctrine, EF Core LINQ. Stay on the builder; do not drop to raw string SQL.
- A raw escape hatch (`knex.raw`, `sqlalchemy.text`, `FromSqlRaw`, `find_by_sql`) is acceptable **only** with bound parameters — never with an interpolated value. EF Core `FromSqlInterpolated` is safe (it auto-parameterizes the interpolation); `FromSqlRaw($"...")` is not.
- Identifiers (table/column names) cannot be bound — if one is dynamic, map it through a server-side allowlist; never concatenate a client-supplied identifier.

## NoSQL — Operator Injection

A JSON body lets an attacker smuggle query operators where you expected a scalar.

```ts
// DON'T — body { "id": { "$gt": "" } } matches every document; { "$where": "…" } runs JS.
await users.findOne({ id: req.body.id });

// DO — coerce to the expected scalar type first; reject objects.
const id = String(req.body.id);
await users.findOne({ id });
```

- Validate body fields to scalar types before they reach a Mongo filter (see `input-validation-and-parsing.md`); reject `$`-prefixed keys.
- Disable server-side JS: never use `$where`/`$function`/`mapReduce` with input. Use typed query builders.

## Subprocess — Argv, Never a Shell

Most back-ends should not shell out at all. When you must, pass an argument vector — never a constructed shell string.

```ts
// Node — execFile / spawn with an argv array and shell:false (the default).
import { execFile } from "node:child_process";
execFile("/usr/bin/convert", ["--", input, output], { timeout: 30_000 }, cb);
// DON'T — the shell parses the whole string; input can inject.
import { exec } from "node:child_process";
exec(`convert ${input} ${output}`);                              // command injection
```

```go
// Go — argv vector; never sh -c with interpolation.
exec.CommandContext(ctx, "convert", "--", input, output)
// DON'T
exec.Command("sh", "-c", "convert "+input+" "+output)            // command injection
```

```python
# Python — list args, shell=False (default), bounded.
subprocess.run(["/usr/bin/convert", "--", input, output], shell=False, timeout=30, check=True)
# DON'T
subprocess.run(f"convert {input} {output}", shell=True)          # command injection
```

- JVM `ProcessBuilder(List.of(...))`, Ruby `system([...])`/`Open3.capture2(*argv)`, PHP `proc_open` with an arg array, .NET `ProcessStartInfo.ArgumentList` — all take an argv vector. Never the single-string overloads on input.
- Pass `--` (the option terminator) before user-controlled positional arguments so a value like `--output=/etc/passwd` is data, not an option.
- Bound the child with a timeout; invoke by absolute path so a hijacked `PATH` can't substitute a malicious binary.
- Bash/CI glue (migration runners, deploy scripts) follows identical rules — quote every expansion, no `eval`, commands as arrays: see system-developer's [bash-scripting](../../../../system-developer/skills/bash/bash-scripting/SKILL.md).

## SSRF — Egress Allowlists (API7)

When a host or URL is derived from input, the server can be tricked into reaching internal services or the cloud metadata endpoint.

The defense is an **allow-list, validated after DNS resolution**:

1. Parse the URL; require `https` (or an allowlisted scheme) and a host on your allowlist of permitted destinations.
2. Resolve the host, then reject if any resolved IP is loopback, private, link-local, reserved, or `169.254.169.254` (cloud metadata). This defeats DNS rebinding, which a name-only allowlist misses.
3. Disable redirect-following, or re-run steps 1-2 on every redirect target — a 30x to `http://169.254.169.254/` is a classic bypass.

```go
// Go — block private/metadata IPs after resolution, before the request.
ips, err := net.DefaultResolver.LookupIPAddr(ctx, host)
if err != nil { return errBlocked }
for _, a := range ips {
    if a.IP.IsLoopback() || a.IP.IsPrivate() || a.IP.IsLinkLocalUnicast() {
        return errBlocked
    }
}
client := &http.Client{ CheckRedirect: func(*http.Request, []*http.Request) error {
    return http.ErrUseLastResponse }} // do not auto-follow to a new host
```

- For user-registered webhooks, validate the destination at registration **and** before each delivery (the resolved IP can change).
- Bind the outbound client to a pinned egress proxy/allowlist in production where feasible — defense in depth over the in-process check.

## Secrets — Secret Manager, Never argv or Logs

| Rule | How |
|------|-----|
| Source | Secret manager (Vault, AWS/GCP Secrets Manager, KMS) or a scoped runtime env injected by the platform — never committed, never in the image |
| Never argv | argv is world-readable via `ps` and `/proc/PID/cmdline`; pass secrets via env, a file/fd, or the secret manager SDK — never `--password=$PW` |
| Never logged | redact in the logger: `pino` `redact` paths, Go `slog` `ReplaceAttr`, Logback/Log4j masking, Python logging filter, framework scrubbers |
| Never to client | error responses carry a generic message; full detail stays server-side (**API8**) |
| Rotate & scope | short-lived tokens, least-privilege DB roles; a leaked secret is rotated, not just deleted |

```ts
// Node — redact secret paths so they never hit a log sink.
import pino from "pino";
const log = pino({ redact: ["req.headers.authorization", "*.password", "*.apiKey"] });
```

- A secret committed to git history is compromised even after `git rm` — rotate it. CI must run a secret scanner (gitleaks/trufflehog) and fail the build on a hit.

## Supply Chain — CVE Scanning

Third-party dependencies are part of your attack surface. Scan in CI and fail on high severity.

| Ecosystem | Tool | Command (single scoped Bash invocation) |
|-----------|------|------------------------------------------|
| Node | npm audit / osv-scanner | `npm audit --audit-level=high` |
| Go | govulncheck | `govulncheck ./...` |
| Any (lockfile) | osv-scanner | `osv-scanner --lockfile=package-lock.json` |
| Container image | trivy | `trivy image --severity HIGH,CRITICAL myapp:tag` |
| JVM | OWASP dependency-check / `gradle dependencyCheckAnalyze` | `gradle dependencyCheckAnalyze` |
| Python | pip-audit | `pip-audit` |

- Pin dependencies via a committed lockfile so the scan reflects what actually ships.
- Run the scan on every PR; a new HIGH/CRITICAL is a release blocker unless it has a documented, reviewed exception with a tracking reference. Routine upgrade flow belongs to the `be-dependency-manager` agent.

## Why Dynamic Code Execution Is Banned

Constructing code or a query from data and then executing it collapses the data/code boundary — the single most powerful primitive an attacker can reach. It is a non-negotiable rule: **no dynamic code construction or execution at runtime.**

What this bans:

| Stack | Banned construct | Why |
|-------|-----------------|-----|
| Node/TS | `eval`, `new Function(str)`, `vm.runInContext` on input, template-string SQL | Runs attacker JS or attacker SQL |
| Go | `exec.Command("sh","-c",str)` on input, `text/template` into SQL | Runs attacker commands or SQL |
| JVM | `Statement`+concat SQL, reflective load of an input-named class, scripting-engine `eval` | SQL injection / arbitrary class load |
| Python | `eval`, `exec`, `compile`+exec, `pickle.loads`/`yaml.load` on input | Runs attacker Python |
| Ruby/PHP/.NET | `eval`/`instance_eval`, `eval()`/`create_function`, `BinaryFormatter`/dynamic `Assembly.Load` on input | Runs attacker code |
| All | Building SQL/NoSQL/commands by string concatenation | Injection — use parameterized queries / argv vectors |

The replacement is always the same shape: **structured APIs over string interpolation.** Bound parameters instead of concatenated SQL. Argv vectors instead of command strings. Typed query builders instead of operator-bearing JSON. A dispatch table (a map of allowed handlers) instead of `eval`-ing a name. Data parsers (`JSON.parse`, `yaml.safe_load`) instead of `eval`/`pickle`.

If you believe you have a legitimate need to disable this rule, that requires a documented, reviewed justification recorded inline at the call site — and it must never accept data that crosses a trust boundary.

## Execution Checklist

- [ ] All SQL uses bound parameters / prepared statements / ORM builders — no string-built or template-interpolated queries; dynamic identifiers mapped through a server-side allowlist.
- [ ] NoSQL filters receive type-coerced scalars; `$`-operators from input rejected; no `$where`/`$function`.
- [ ] No subprocess on a built shell string — children launched with an argv array, `shell:false`, `--` before positional args, a timeout, and an absolute program path.
- [ ] Outbound calls to input-derived hosts go through an egress allowlist with a post-resolution private/metadata-IP block; redirects not blindly followed (**API7**).
- [ ] Secrets come from a secret manager / scoped env; never in argv, logs, errors-to-client, or the repo; rotated on leak; CI secret scan green.
- [ ] Dependency CVE scan (npm audit / govulncheck / osv-scanner / trivy) runs in CI and is green or has a tracked exception.
- [ ] No `eval`/`new Function`/`pickle`/`BinaryFormatter`/reflective-load-on-input; queries parameterized, commands argv'd, data parsed with safe parsers.

## Related

- `input-validation-and-parsing.md` — validating the data that flows into parameters/arguments, and the deserialization-RCE table
- `../SKILL.md` — non-negotiable rules, OWASP API Top 10 mapping, per-stack injection table
- `../../../../system-developer/skills/bash/bash-scripting/SKILL.md` — strict mode, quoting, and defensive shell patterns for CI/deploy glue
