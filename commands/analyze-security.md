---
description: Scan for OWASP API Top 10 defects — authz boundaries, injection, secrets, and dependency CVEs
argument-hint: [path/scope (default: working changes)] [--deep] [--secrets] [--deps]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 3000
  max-tokens: 22000
  model-distribution:
    haiku: 10%
    sonnet: 75%
    opus: 15%
---

# OWASP API Top 10 Security Scan
<!-- Updated: June 2026 -->

Scan back-end changes for the OWASP API Security Top 10 (2023) — authorization boundaries (BOLA/BFLA), injection, SSRF, rate limiting, and security misconfiguration — plus optional secret scanning and dependency CVE checks. Scope defaults to your working changes; the auditor runs read-only; findings come back as a deduplicated, prioritized P0-P3 report carrying OWASP API IDs and CWE numbers.

[Extended thinking: A missing ownership check on `GET /orders/:id` (BOLA), an admin route reachable by a normal token (BFLA), a string-interpolated SQL `WHERE` clause, a user-supplied URL passed to `fetch` (SSRF), and an unbounded list endpoint with no pagination (API4) are five different failure modes — a single grep pass catches none of them with confidence. This command resolves the scope once, detects which back-end stacks are actually present, then runs the read-only `be-security-auditor` over the resolved file list with explicit OWASP API Top 10 coverage. The `--secrets`, `--deps`, and `--deep` flags arm additional scanners (gitleaks/trufflehog, osv-scanner/govulncheck/trivy, semgrep taint analysis) and fold their output into the same report. The auditor never edits. Every scanner degrades gracefully — a missing tool prints an install hint and reduces depth, it never aborts the scan. Keep the synthesis honest: if there is no material exposure, say so rather than padding with theoretical nits.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Resolve the scope before scanning.** Apply the scope precedence (explicit args > working diff > branch/PR diff) exactly once, list the concrete files under review, and pass that same file list to the auditor and every scanner. Do NOT let the auditor re-scope independently.
2. **The auditor is read-only.** The `be-security-auditor` pass MUST NOT write or edit. It returns structured findings only. This command never applies fixes — route remediation to `/backend-developer:fix` or the `be-code-fixer` separately.
3. **OWASP API Top 10 is the spine.** Every finding maps to an OWASP API ID (API1–API10) where it fits the taxonomy, and to a CWE where applicable. Authorization-boundary review (API1 BOLA, API3 object-property authz, API5 BFLA) is mandatory on every run, not optional.
4. **Flags arm scanners; they do not change the auditor's core duty.** The base auditor pass always runs. `--secrets`, `--deps`, and `--deep` add scanner passes that run alongside the auditor and feed the same synthesis. Do NOT skip the authz/injection review because a flag was set.
5. **Synthesize, deduplicate, normalize.** Merge the auditor output with each scanner's output, drop duplicates and speculative claims, and normalize every survivor to `{file, line, owasp, category (CWE), severity, why, fix, confidence}` before ranking into P0-P3.
6. **Tool-missing never hard-fails.** If gitleaks, osv-scanner, govulncheck, trivy, or semgrep is unavailable, print the install hint, note the reduced depth in the report, and continue. Never abort the whole scan over one missing scanner.
7. **No manufactured findings.** If the auditor and scanners find no material exposure, report that plainly. Do NOT invent P2/P3 nits to fill the report.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Scan your current working changes (staged + unstaged)
/backend-developer:analyze-security

# Scan a specific directory
/backend-developer:analyze-security src/routes/

# Scan a single file
/backend-developer:analyze-security src/controllers/orders.ts

# Scan a branch or PR against the base
/backend-developer:analyze-security feature/checkout-api
/backend-developer:analyze-security 142            # PR number

# Add secret scanning (gitleaks/trufflehog over the scope + history)
/backend-developer:analyze-security --secrets

# Add dependency CVE scanning (osv-scanner/govulncheck/trivy)
/backend-developer:analyze-security --deps

# Deep taint analysis (semgrep) plus all of the above
/backend-developer:analyze-security --deep --secrets --deps
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope` | working changes | File, directory, PR number, or branch to scan. See Scope Resolution. |
| `--deep` | off | Enable semgrep taint analysis (source-to-sink dataflow) over the scope. Raises depth on injection/SSRF detection; slower, higher token cost. |
| `--secrets` | off | Run a secret scanner (gitleaks, falling back to trufflehog) over the scoped files and reachable git history. Reports leaked credentials, tokens, and private keys. |
| `--deps` | off | Run dependency CVE scanners over the resolved manifests/lockfiles (osv-scanner; govulncheck for Go; trivy for images). Maps each advisory to its GHSA/CVE and fixed version. |

## Scope Resolution

Resolve the set of files under review **once**, top-down — the first applicable rule wins:

1. **Explicit args** — a file, directory, PR number, or branch named on the command line.
   - File or directory → scan those paths directly.
   - PR number (bare integer) → `gh pr diff <N> --name-only` for the file list (and `gh pr diff <N>` for the patch). If `gh` is unavailable, print the install hint and fall back to rule 3 against the PR's base branch.
   - Branch name → diff against the merge-base with the default branch: `git diff --name-only $(git merge-base HEAD <branch>)..<branch>`.
2. **Working changes** (no args) — staged and unstaged tracked changes:
   `git diff --name-only HEAD` (plus `git diff --cached --name-only`). This is the default.
3. **Branch/PR diff** (fallback) — when neither explicit paths nor working changes apply, diff the current branch against the default branch's merge-base.

After resolving, **print the concrete file list** and the line ranges (where a diff is involved) before launching the auditor. The auditor and scanners receive this exact list — they do not re-derive scope. Exclude vendored/build artifacts (`node_modules/`, `dist/`, `build/`, `vendor/`, `.venv/`, `target/`, generated client SDKs) from the file list. For `--deps`, also resolve the relevant manifests/lockfiles in scope (`package.json`/`package-lock.json`/`pnpm-lock.yaml`, `go.mod`/`go.sum`, `pom.xml`/`build.gradle`, `requirements.txt`/`pyproject.toml`/`uv.lock`, `Gemfile.lock`, `composer.lock`, `*.csproj`/`packages.lock.json`).

## Stack Detection

Detect which back-end stacks appear in the resolved file list using the canonical `skill: stack-detection` table — do not fork its routing logic. The auditor adapts its injection/ORM/HTTP-client checks to the stacks present:

| Files in scope | Stack / framework signals |
|----------------|---------------------------|
| `.ts`, `.js` + `package.json` (Express/NestJS/Fastify/Hono) | Node.js/TypeScript — Prisma/Drizzle/TypeORM, `fetch`/axios SSRF, JWT/session middleware |
| `.go` + `go.mod` (Gin/Echo/chi/net-http) | Go — GORM/`database/sql`, `net/http` client SSRF, context auth |
| `.java`, `.kt` + `pom.xml`/`build.gradle` (Spring Boot) | JVM — JPA/Hibernate, `RestTemplate`/`WebClient` SSRF, Spring Security |
| `.py` + `pyproject.toml`/`requirements.txt` (FastAPI/Django/Flask) | Python — SQLAlchemy/Django ORM, `requests`/`httpx` SSRF, dependency-injected auth |
| `.rb` + `Gemfile` (Rails) | Ruby — ActiveRecord, `Net::HTTP` SSRF, Devise/Pundit authz |
| `.php` + `composer.json` (Laravel/Symfony) | PHP — Eloquent/Doctrine, Guzzle SSRF, gate/policy authz |
| `.cs` + `*.csproj` (ASP.NET Core) | .NET — EF Core, `HttpClient` SSRF, `[Authorize]` policies |

- A change spanning several stacks runs **one auditor pass over the full list** — the auditor is cross-cutting and stack-aware, so it is not fanned out per language.
- Version-specific checks (e.g. Express 5 async error handling, Spring Security 6 `authorizeHttpRequests`, NestJS guard ordering) follow `skills/_shared/version-feature-matrix.md` — the canonical runtime/framework version lookup.
- If nothing recognized is in scope, report "no reviewable back-end sources in scope" and stop.

## Workflow

### Phase 1: Resolve, Detect, Arm Scanners

1. Resolve the scope (above) and **print the concrete file list**.
2. Detect the stacks present so the auditor's checks are framed correctly.
3. Determine which scanner passes are armed: base auditor (always), `--secrets`, `--deps`, `--deep`. Probe for each armed scanner's binary up front (`command -v gitleaks`, `command -v osv-scanner`, `command -v govulncheck`, `command -v trivy`, `command -v semgrep`); for any missing one, record the install hint for the Reduced-Depth Notes and skip that pass.

### Phase 2: Security Audit + Scanner Passes (parallel, read-only)

Run the auditor and every armed scanner **simultaneously** — they have no dependencies on each other. All are read-only and receive the same resolved file list.

**OWASP API Top 10 audit (always) — Use Task tool with subagent_type="backend-developer:be-security-auditor"**
- Coverage (OWASP API Security Top 10, 2023):
  - **API1 BOLA** — object-level authorization: does every handler that reads/mutates a resource by id verify the caller owns or may access that object, not just that they are authenticated?
  - **API2 Broken authentication** — token/session validation, weak JWT verification (`alg:none`, missing signature/issuer/audience checks), missing expiry, credential handling.
  - **API3 Broken object property-level authorization** — mass assignment / over-posting, sensitive fields writable or returned that should not be (excessive data exposure).
  - **API4 Unrestricted resource consumption** — missing rate limiting, unbounded list endpoints without pagination caps, no payload-size limits, unbounded fan-out / N+1 amplification.
  - **API5 BFLA** — function-level authorization: admin/privileged routes reachable without the required role/scope; verb-level gaps (POST/DELETE unprotected while GET is guarded).
  - **API6 Unrestricted access to sensitive business flows** — no anti-automation on signup/purchase/transfer flows.
  - **API7 SSRF** — user-controlled URLs reaching server-side HTTP clients (`fetch`, axios, `net/http`, `RestTemplate`/`WebClient`, `requests`/`httpx`, Guzzle, `HttpClient`) without allow-listing.
  - **API8 Security misconfiguration** — permissive CORS (`*` with credentials), missing security headers, verbose error/stack-trace leakage, debug endpoints, default credentials, TLS/verify disabled.
  - **API9 Improper inventory management** — undocumented/legacy/`/v1` endpoints, debug routes shipped to prod.
  - **API10 Unsafe consumption of APIs** — trusting upstream/third-party API responses without validation; redirect/SSRF chaining.
  - Plus **injection** (SQL/NoSQL/command — string-built queries, `$where`/`$regex` from input, `exec`/`child_process`/`os.system` with untrusted args) and **secrets hygiene** (hardcoded credentials, tokens).
- Prompt: "Read-only OWASP API Security Top 10 (2023) audit of these files: {file_list} (stacks present: {stacks}). Cover API1 BOLA (object-ownership checks on id-addressed handlers), API2 broken auth (JWT/session verification, alg:none, missing expiry/issuer/audience), API3 object-property authz (mass assignment, excessive data exposure), API4 unrestricted resource consumption (missing rate limits, unbounded list/pagination, payload-size caps), API5 BFLA (admin/privileged route role checks, verb-level gaps), API6 sensitive business flows, API7 SSRF (user-controlled URLs into server-side HTTP clients), API8 security misconfiguration (CORS, security headers, error/stack leakage, disabled TLS verification), API9 inventory (debug/legacy routes), API10 unsafe consumption of upstream APIs, plus injection (SQL/NoSQL/command) and hardcoded secrets. Map each finding to its OWASP API ID and a CWE where applicable. Do NOT edit any file. Return findings as a list of `{file, line, owasp, category (CWE), severity (P0-P3), why, fix, confidence}`. {If --deep: 'Reason about source-to-sink dataflow — trace tainted request input to dangerous sinks, do not stop at surface patterns.'} If there are no material issues, say so directly."

**Secret scan (when `--secrets`)** — run a scoped, read-only secret scanner; never echo full secret values, only the rule id, file, line, and a redacted match:
```bash
gitleaks detect --no-banner --redact --report-format json --source .
```
- Falls back to `trufflehog filesystem --json .` if gitleaks is absent. Both probe reachable git history for the scoped paths. Fold each hit into synthesis as an `API8`/CWE-798 (or CWE-312) finding.

**Dependency CVE scan (when `--deps`)** — run the ecosystem-appropriate scanner over the resolved manifests/lockfiles, one scoped command each:
```bash
osv-scanner --lockfile=package-lock.json --format json    # JS/TS, also go.mod, requirements.txt, etc.
govulncheck ./...                                          # Go (call-graph reachable CVEs)
trivy fs --scanners vuln --format json .                   # container/image + lockfile sweep
```
- Map each advisory to its GHSA/CVE id, affected version, and fixed version. Reachable advisories (govulncheck call-graph hits) rank above merely-present ones. Fold into synthesis as `API8`/supply-chain findings.

**Deep taint analysis (when `--deep`)** — run semgrep with security rulesets for the detected stacks:
```bash
semgrep --config p/owasp-top-ten --config p/secrets --json .
```
- Use semgrep's source-to-sink taint results to corroborate or raise confidence on the auditor's injection/SSRF findings; deduplicate against them in synthesis.

[SYNC POINT: Wait for the auditor and all armed scanners before synthesis.]

### Phase 3: Synthesis

1. **Collect** the auditor findings plus every armed scanner's output.
2. **Deduplicate** — the auditor and semgrep will overlap on the same injection/SSRF sink, and gitleaks may flag a secret the auditor also saw. Merge duplicates at the same `{file, line}`, keeping the higher severity and the clearer fix; credit both lenses in `why` (e.g. "auditor + semgrep taint trace").
3. **Filter** — drop speculative claims with no concrete evidence and drop pure style nits. Per Rule 7, do not backfill.
4. **Normalize** every survivor to `{file, line, owasp, category (CWE), severity, why, fix, confidence}` (severity from `skill: severity-matrix` P0-P3; confidence = high/medium/low).
5. **Rank** into P0-P3. Authorization-boundary and injection findings with high confidence win severity ties — a confirmed BOLA or SQL injection is a merge blocker.
6. **Emit** the Output Format report.

## Output Format

```markdown
## API Security Scan Report

**Scope:** {resolved scope — paths / PR# / branch}
**Files scanned:** {N} ({stacks present})
**Passes:** OWASP API audit{, secrets}{, deps}{, deep taint}
**Scanners run:** {gitleaks/trufflehog | osv-scanner/govulncheck/trivy | semgrep — or "none armed"}

### Summary
{One or two sentences. If clean: "No material API security exposure found — authorization boundaries, injection surfaces, and configuration look sound for the scanned scope." Otherwise: counts by priority and the dominant OWASP categories.}

| Priority | Count |
|----------|-------|
| P0 (block merge) | {n} |
| P1 (fix in this change) | {n} |
| P2 (should fix) | {n} |
| P3 (nice to have) | {n} |

### P0 — Must Fix Before Merge
| File:Line | OWASP | Category | Why | Fix | Confidence |
|-----------|-------|----------|-----|-----|------------|
| {file}:{line} | {API1–API10} | {CWE} | {why it's exploitable} | {minimal fix} | {high/med/low} |

### P1 — Fix In This Change
{same table shape}

### P2 — Should Fix
{same table shape}

### P3 — Nice To Have
{same table shape}

<!-- When --deps surfaced advisories: -->
### Dependency Advisories
| Package | Installed | Fixed In | Advisory | Reachable | Severity |
|---------|-----------|----------|----------|-----------|----------|
| {pkg} | {ver} | {fixed} | {GHSA/CVE} | {yes/no/unknown} | {P0-P3} |

<!-- When a scanner was unavailable: -->
### Reduced-Depth Notes
- {pass}: {missing scanner} unavailable — ran without {capability}. Install: {hint}.
```

## Error Handling

### No reviewable sources in scope
```
Note: No back-end sources found in the resolved scope.
Resolved scope: {scope}
Suggestion: Pass an explicit path, or check that your changes include reviewable handlers/services.
```

### No changes detected (default scope)
```
Note: No staged or unstaged changes to scan.
Suggestion: Name a path, branch, or PR number, e.g. /backend-developer:analyze-security src/routes/
```

### `gh` unavailable for a PR scope
```
Warning: `gh` CLI not found; cannot fetch PR diff directly.
Install: brew install gh   (then `gh auth login`)
Falling back to a branch diff against the default branch.
```

### Scanner missing (reduced depth)
Print the relevant install hint, note reduced depth in the report, and continue — never hard-fail:

| Missing tool | Used for | Install hint |
|--------------|----------|--------------|
| `gitleaks` (secrets) | `--secrets` | `brew install gitleaks` |
| `trufflehog` (secrets fallback) | `--secrets` | `brew install trufflehog` |
| `osv-scanner` (CVEs, multi-ecosystem) | `--deps` | `brew install osv-scanner` |
| `govulncheck` (Go reachable CVEs) | `--deps` | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| `trivy` (image + lockfile CVEs) | `--deps` | `brew install trivy` |
| `semgrep` (taint analysis) | `--deep` | `uv tool install semgrep` (or `brew install semgrep`) |

If no scanner flag is armed, the base auditor pass still runs — the OWASP API audit does not depend on any external binary.

### Ambiguous stack
If detection cannot classify a file (e.g. an extensionless script or a polyglot service), apply `skill: stack-detection` tie-break rules; if still ambiguous, route it to `backend-developer:backend-developer` and note the routing in the report.

## See Also

- `skill: stack-detection` — canonical signal → stack → agent routing (keep this command's detection in sync).
- `skill: severity-matrix` — P0-P3 definitions used by the synthesis ranking.
- `skill: api-security` — OWASP API Top 10 patterns and authz-boundary checklists the auditor draws on.
- `skills/_shared/version-feature-matrix.md` — runtime/framework version lookup for version-specific checks.
- `/backend-developer:review-code` — broader correctness/quality review (this command is the security-focused subset).
- `/backend-developer:deps` — full dependency audit, license inventory, and gated upgrades when `--deps` surfaces advisories.
- `/backend-developer:fix` — hand confirmed P0/P1 findings to `be-code-fixer` for minimal-diff remediation.

If there are no material issues, say that directly instead of manufacturing feedback.
