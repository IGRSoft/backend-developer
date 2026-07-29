---
description: Audit, upgrade, or add dependencies — CVE/license reporting and exact pins behind a build+test gate
argument-hint: <audit|upgrade|add> [path, package name, or scope] [--licenses] [--stack node|go|jvm|python|ruby|php|dotnet]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
estimated-cost:
  min-tokens: 1500
  max-tokens: 18000
  model-distribution:
    haiku: 35%
    sonnet: 55%
    opus: 10%
---

# Dependency Lifecycle
<!-- Updated: June 2026 -->

Audit, upgrade, and add dependencies for web and service back-ends across the ecosystems this plugin supports: Node.js/TypeScript (npm/pnpm/yarn), Go (go modules), Java/Kotlin (Maven/Gradle), Python (uv/pip), Ruby (Bundler), PHP (Composer), and C#/.NET (NuGet).

Three subcommands select the operation from the first argument:

- **`deps audit [path|scope]`** — outdated-versions report, CVE/advisory lookup, and license inventory. Read-only; changes nothing. **This is the default.** See [Audit](#audit-deps-audit).
- **`deps upgrade [package|scope]`** — advance exactly one dependency, pinning an exact version and re-running the build and tests before touching the next. See [Upgrade](#upgrade-deps-upgrade).
- **`deps add <package>`** — introduce a new dependency: justify it against the existing graph and the stdlib, vet its supply-chain posture, pin it exactly, and gate on a green build. See [Add](#add-deps-add).

**Dispatch:** parse the first token of `$ARGUMENTS`. If it is `audit`, `upgrade`, or `add`, run that workflow with the remaining args as its scope/target. If the first token is anything else (a path, a flag, or empty), treat the whole argument string as the scope for **`audit`** — the read-only default.

There is no flag form of a subcommand. A mutating mode is selected by the first token only, never by a flag (Rule 2). If `--upgrade` or `--add` appears anywhere in the arguments, do NOT silently fall through to `audit` — stop and emit the "flag-form subcommand" message under Error Handling, so a caller expecting a mutation is never told an audit was what they asked for.

> **Tool discipline:** `audit` is strictly read-only. This command's `allowed-tools` carries `Write`/`Edit` because `upgrade` and `add` edit manifests; the audit workflow MUST NOT modify a file, only report.

[Extended thinking: Dependency changes are among the highest-blast-radius edits in a service — one transitive bump can silently change a serialization format, drop a route handler's middleware contract, or pull in a CVE that ships straight to production. This command separates read-only assessment (`audit`) from mutation (`upgrade`, `add`) via first-token subcommand dispatch, and forces upgrades through a one-dependency, pin-exact, build-and-test-gated loop. Manifest discovery is shared with `skill: language-detection`; CVE lookup prefers each ecosystem's native scanner (npm audit, govulncheck, composer audit, dotnet list package --vulnerable, uv) and falls back to `osv-scanner` and the osv.dev API; license inventory is best-effort and never blocks. Security findings are phrased in OWASP API Security Top 10 (2023) and `igrsoft:security-review-process` vocabulary so they flow cleanly into an SR stage. The heavy reasoning — version-jump risk, breaking-change analysis, manifest edits — is delegated to `subagent_type="backend-developer:be-dependency-manager"`; this command owns discovery, the gate loop, and reporting. Version markers throughout defer to `skills/_shared/version-feature-matrix.md` as the canonical lookup.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Audit is strictly read-only.** Under the `audit` subcommand (including the no-subcommand default), do NOT edit any manifest, lockfile, or source. Discovery, queries, and reporting only. If the user wants changes, they re-run with `upgrade` or `add`.
2. **Dispatch before anything else.** Resolve the subcommand from the first token of `$ARGUMENTS` as the first action of the run, and state which mode you are in before running a single query. Never guess a mutating mode: an unrecognized first token means `audit`, never `upgrade` or `add`.
3. **Upgrade ONE dependency at a time.** Never batch upgrades. Pin the new version to an *exact* version (not a range), then run the build+test gate before proposing the next dependency. A failed gate stops the loop — report and wait.
4. **A new dependency must be justified before it is added.** Under `add`, never install on request alone. First check whether the runtime's standard library, an already-present dependency, or a few lines of local code cover the need, and report that finding. Adding a package is a permanent supply-chain commitment; say so and let the user decide.
5. **Pin exact, never float.** Every version this command writes is exact: an npm `"x.y.z"` (no `^`/`~`) with the lockfile regenerated, a Go `require pkg vX.Y.Z` reconciled via `go mod tidy`, a Maven `<version>x.y.z</version>` / Gradle `group:name:x.y.z`, a Composer `"vendor/pkg": "x.y.z"`, a NuGet `Version="x.y.z"`, or a uv lockfile-resolved pin. Never introduce `*`, `^`, `~`, `latest`, `main`, `RELEASE`, `+`, or a floating range.
6. **Single-command Bash invocations.** Use each tool's own directory flags (`npm --prefix DIR`, `go -C DIR`, `mvn -f DIR/pom.xml`, `composer --working-dir=DIR`, `dotnet --project DIR`, `uv --project DIR`). Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands.
7. **Tool-missing never hard-fails.** If a package manager or scanner binary is absent, print the install hint, skip that ecosystem's pass, and continue with the others. Report what was skipped. A missing native scanner falls back to `osv-scanner` and then the osv.dev API via the network — never skip the CVE pass silently.
8. **Delegate the reasoning, own the loop.** Hand version-jump risk, breaking-change analysis, and manifest edits to `subagent_type="backend-developer:be-dependency-manager"`. This command performs discovery, runs the build+test gate, and synthesizes the report.
9. **Security findings use SR + OWASP vocabulary.** Phrase every CVE/advisory finding in `igrsoft:security-review-process` terms (severity, CVE/GHSA/advisory id, affected version range, fixed-in version, remediation) and map exploitable classes to the OWASP API Security Top 10 (2023) where relevant (e.g. a vulnerable auth library → API2 broken authentication; an SSRF-prone HTTP client → API7) so the output is consumable by an SR stage.
10. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Read-only audit of the current project (auto-detect all ecosystems)
/backend-developer:deps audit

# Same thing — audit is the default when no subcommand is given
/backend-developer:deps

# Audit a specific path
/backend-developer:deps audit services/api

# Audit only the Node.js dependencies
/backend-developer:deps audit --stack node

# Include a full license inventory
/backend-developer:deps audit --licenses

# Upgrade dependencies one at a time, each behind a build+test gate
/backend-developer:deps upgrade --stack go

# Upgrade one named package
/backend-developer:deps upgrade fastify

# Add a new dependency (justify → vet → pin exact → build+test gate)
/backend-developer:deps add zod
```

If no path is given, default to `.`. If no subcommand is given, default to read-only `audit`.

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `<subcommand>` | `audit` | First token: `audit` (read-only), `upgrade` (one gated dependency step), or `add` (introduce a new dependency). An unrecognized first token is treated as scope for `audit`. |
| `[path\|package]` | `.` | For `audit`, the project root to scan — monorepos scan one level of obvious workspace dirs (`packages/`, `services/`, `apps/`). For `upgrade`, an optional package name to target instead of the highest-priority candidate. For `add`, the required package name. |
| `--licenses` | off | `audit` only. Add a full license inventory pass (slower; pulls per-package metadata). Without it, licenses are reported best-effort only. |
| `--stack <node\|go\|jvm\|python\|ruby\|php\|dotnet>` | auto | Restrict to one ecosystem. Without it, every discovered ecosystem is processed (audit) — `upgrade` and `add` require exactly one, so a polyglot repo must name it. Repeatable for `audit`. |

There is deliberately no `--upgrade`/`--add` flag: mutation is selected by the first token only. Passing one is an error, not a silent audit — see Error Handling.

## Manifest Discovery

Scan the project root (and one level of obvious subdirs: `packages/`, `services/`, `apps/`, `src/`) and record every manifest found. A repo may carry more than one — a polyglot monorepo is common — so process each in `audit` mode; require `--stack` to disambiguate `upgrade` and `add` when several are present. The marker → ecosystem → owning-agent mapping is canonical in `skill: language-detection`; keep this discovery list in sync with it.

| Ecosystem | Manifest(s) | Lock/pin artifact | Owning agent |
|-----------|-------------|-------------------|--------------|
| Node.js/TS | `package.json` | `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` | `backend-developer:node-developer` |
| Go | `go.mod` | `go.sum` | `backend-developer:go-developer` |
| Java/Kotlin | `pom.xml` / `build.gradle(.kts)` | resolved versions / `gradle.lockfile` | `backend-developer:jvm-backend-developer` |
| Python | `pyproject.toml` (+ `requirements*.txt`) | `uv.lock` / `poetry.lock` | `backend-developer:python-backend-developer` |
| Ruby | `Gemfile` | `Gemfile.lock` | `backend-developer:ruby-developer` |
| PHP | `composer.json` | `composer.lock` | `backend-developer:php-developer` |
| C#/.NET | `*.csproj` / `Directory.Packages.props` | `packages.lock.json` | `backend-developer:dotnet-developer` |

Discovery details:

- **Node.js:** `package.json` is authoritative. Detect the package manager from the lockfile (`package-lock.json` → npm, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn) and use the matching CLI. The lockfile is the pin of record; an unlocked range in `dependencies` is normal but the lockfile resolves it exactly.
- **Go:** `go.mod` `require` blocks; `go.sum` carries the verified checksums. A `replace` directive pointing at a fork or local path is a supply-chain finding worth flagging.
- **JVM:** Maven `pom.xml` `<dependencies>` (mind `<dependencyManagement>` and BOM imports) or Gradle `dependencies { }`. Gradle dynamic versions (`1.+`, `latest.release`) are unpinned — flag them. A committed `gradle.lockfile` is the pin of record.
- **Python:** `pyproject.toml` `[project].dependencies` / `[dependency-groups]`; `uv.lock` (or `poetry.lock`) is the resolved pin set. A bare `requirements.txt` without a lockfile is a non-uv project — note it and recommend `uv lock`.
- **Ruby:** `Gemfile` declarations; `Gemfile.lock` (the `BUNDLED WITH` + exact gem versions) is the pin of record.
- **PHP:** `composer.json` `require` / `require-dev`; `composer.lock` is the pin of record.
- **.NET:** `<PackageReference>` in `*.csproj`, or central `Directory.Packages.props` (CPM). A committed `packages.lock.json` (restore with lock mode) is the pin of record.

A manifest declaring floating ranges but lacking a committed lockfile is itself an audit finding (non-reproducible builds, drift between CI and prod) — note it and recommend committing the lockfile.

## Audit (`deps audit`)

Produces three sections per discovered ecosystem: **Outdated**, **Vulnerabilities (CVE)**, **Licenses**. No edits.

### Phase 1: Discover

Run Manifest Discovery. If `--stack` is set, keep only those ecosystems. If nothing is found, emit the "no manifests" error and stop.

### Phase 2: Outdated Report (Bash, per ecosystem)

Run the ecosystem's outdated query (read-only). Capture each tool's exit status, not a pipe's.

| Ecosystem | Outdated query | Notes |
|-----------|----------------|-------|
| Node.js | `npm outdated --prefix <path>` (or `pnpm --dir <path> outdated` / `yarn --cwd <path> outdated`) | Lists current → wanted → latest. Exit code 1 just means "outdated found" — not an error. |
| Go | `go -C <path> list -u -m all` | Shows modules with available updates in brackets. Pair with `go -C <path> list -m -u -f '{{if .Update}}{{.Path}} {{.Version}} -> {{.Update.Version}}{{end}}' all`. |
| JVM (Maven) | `mvn -f <path>/pom.xml versions:display-dependency-updates` | Reports newer releases per dependency. Gradle: `gradle -p <path> dependencyUpdates` (Ben Manes plugin) if present. |
| Python | `uv pip list --outdated --project <path>` | Lists outdated packages with current → latest. (Verify the flag against your toolchain via `skills/_shared/version-feature-matrix.md`.) |
| Ruby | `bundle outdated --gemfile <path>/Gemfile` | Lists gems with newer versions, grouped by direct/indirect. |
| PHP | `composer outdated --working-dir=<path> --direct` | Direct deps with newer versions; drop `--direct` for the full graph. |
| .NET | `dotnet list <path> package --outdated` | Requires a prior restore; shows requested/resolved/latest. |

If an ecosystem's binary is missing, print its install hint (see Tool Availability), skip its outdated pass, and continue.

### Phase 3: CVE / Advisory Lookup

Prefer each ecosystem's native scanner; fall back to `osv-scanner` over the lockfile, then to the osv.dev API. **Never skip this pass silently** — a missing scanner means fall back, not omit.

1. **Native scanners (first choice):**
   - Node.js: `npm audit --prefix <path> --json` (or `pnpm --dir <path> audit --json` / `yarn --cwd <path> npm audit`).
   - Go: `govulncheck -C <path> ./...` — call-graph aware; it reports only vulnerabilities actually reachable from your code (lower false-positive rate than manifest-only scanners).
   - JVM: no first-party CLI — use `osv-scanner --lockfile=<path>/pom.xml` (or the Gradle lockfile); cross-check with OWASP Dependency-Check if installed.
   - Python: `uv audit --project <path>` (reads the lockfile, queries OSV — verify the version against `skills/_shared/version-feature-matrix.md`) or `uvx pip-audit` as a fallback.
   - Ruby: `bundle audit check --gemfile <path>/Gemfile` (ruby-advisory-db; run `bundle audit update` first).
   - PHP: `composer audit --working-dir=<path> --format=json` (Packagist security advisories).
   - .NET: `dotnet list <path> package --vulnerable --include-transitive`.
2. **`osv-scanner` (cross-ecosystem fallback / supplement):** `osv-scanner scan source --lockfile=<path>/<lockfile>` for any ecosystem whose native scanner is absent. It understands npm/Go/Maven/Composer/PyPI/RubyGems/NuGet lockfile formats.
3. **API fallback when no scanner is installed:** for each discovered `(ecosystem, name, version)`, query the osv.dev API:
   - URL: `https://api.osv.dev/v1/query`
   - Body shape: `{"package": {"ecosystem": "<npm|Go|Maven|PyPI|RubyGems|Packagist|NuGet>", "name": "<name>"}, "version": "<version>"}`
   - Cross-check well-known CVEs against the NVD when osv.dev returns nothing.
4. **Normalize every finding into SR vocabulary** (per `igrsoft:security-review-process`): `severity` (Critical/High/Medium/Low from CVSS), `advisory id` (CVE-/GHSA-/OSV-), `affected range`, `fixed-in version`, `remediation` (upgrade target). Where the vulnerability class maps cleanly, tag the relevant **OWASP API Security Top 10 (2023)** item (e.g. a JWT-library auth bypass → API2; an HTTP-client SSRF → API7; a deserialization RCE that exposes business flows → API6/API8). Group Critical/High at the top.

### Phase 4: License Inventory

Best-effort by default; a full pass runs only with `--licenses`. Never blocks the audit.

- Node.js: `license-checker-rseidelsohn --start <path> --json` (or `npx license-checker`) for a full pass; otherwise read each package's `license` field.
- Go: `go-licenses report ./...` (run with `-C <path>`) for a full pass; otherwise note module licenses are not declared in `go.mod`.
- JVM: `mvn -f <path>/pom.xml license:aggregate-third-party-report` (license-maven-plugin) for a full pass.
- Python: `uvx pip-licenses` for a full pass; otherwise read `License`/classifier metadata.
- Ruby: `license_finder` if available.
- PHP: `composer licenses --working-dir=<path>`.
- .NET: `dotnet-project-licenses` if available; otherwise read `<PackageLicenseExpression>`.

Flag any GPL/AGPL/SSPL or otherwise copyleft / network-copyleft license against a permissively-licensed or SaaS-distributed service as a review item (not a hard failure) — phrase it as a supply-chain / license-compatibility finding for SR.

### Phase 5: Delegate analysis & report

Hand the raw discovery + queries to the dependency manager for risk framing:

- **Use the Task tool with `subagent_type="backend-developer:be-dependency-manager"`.**
  Prompt: "Audit-mode dependency analysis for the project at `{path}`. Discovered ecosystems: {ecosystems}. Outdated report:\n```\n{outdated_output}\n```\nCVE findings (raw):\n```\n{cve_output}\n```\nLicenses:\n```\n{license_output}\n```\nFor each outdated dependency, classify the version jump (patch/minor/major per semver), note documented breaking changes, and assess upgrade risk (especially framework majors like Express 4→5, NestJS, Spring Boot 2→3, Django, Rails, .NET LTS hops). Normalize every vulnerability into `igrsoft:security-review-process` vocabulary and tag the OWASP API Security Top 10 (2023) class where it applies. Produce a prioritized upgrade plan (security patches first, then patch/minor, then majors individually). Do NOT edit any files — this is read-only audit."
- Synthesize the agent's analysis into the Output Format report.

## Upgrade (`deps upgrade`)

`deps upgrade` advances dependencies one step at a time. This is the incremental-upgrade discipline: plan, pin exact, build+test gate, then stop.

### Phase 1: Resolve targets & scope

1. Run Manifest Discovery; if multiple ecosystems are present, require `--stack` to disambiguate.
2. Run the relevant audit queries (Outdated Report, CVE / Advisory Lookup) to learn current versions, latest versions, and any open CVEs. If the subcommand named a package, target that one; otherwise pick the highest-priority candidate (security patch first, then smallest safe jump).

### Phase 2: Plan the single step (delegate)

- **Use the Task tool with `subagent_type="backend-developer:be-dependency-manager"`.**
  Prompt: "Plan a single-step upgrade of `{package}` ({ecosystem}) in the project at `{path}` from `{current}` toward `{target}`. If the jump crosses a major version, advance only ONE major (v1→v2, never v1→v3) and identify the exact next version to pin. Summarize documented breaking changes between `{current}` and the chosen target (API/contract changes, removed middleware/decorators, ORM migration shifts, config renames), list the manifest edits required (npm exact `"x.y.z"` + lockfile regen, Go `require` + `go mod tidy`, Maven/Gradle exact version, Composer exact + lock, NuGet `Version` + lock, or uv pin), and produce the exact-version pin to write. Return the edits as a concrete diff plan; do not apply yet."

### Phase 3: Apply the pinned edit

Apply the agent's edit, pinning exactly per ecosystem:

| Ecosystem | Pin mechanism |
|-----------|---------------|
| Node.js | Set the exact `"x.y.z"` in `package.json`, then `npm install --prefix <path>` (or `pnpm --dir <path> install` / `yarn --cwd <path> install`) to regenerate the lockfile. |
| Go | `go -C <path> get pkg@vX.Y.Z`, then `go -C <path> mod tidy` to reconcile `go.sum`. |
| JVM | Maven: set the exact `<version>` (in `<dependencyManagement>` if present). Gradle: set `group:name:x.y.z` and refresh the lockfile (`gradle -p <path> dependencies --write-locks`). |
| Python | `uv lock --upgrade-package <pkg>==<x.y.z> --project <path>` (or pin in `pyproject.toml` then `uv lock`), producing an updated `uv.lock`. |
| Ruby | Set the exact version in `Gemfile`, then `bundle lock --update <gem> --gemfile <path>/Gemfile`. |
| PHP | `composer require --working-dir=<path> vendor/pkg:x.y.z` (exact), updating `composer.lock`. |
| .NET | `dotnet add <path> package <pkg> --version x.y.z`, then restore with lock mode to refresh `packages.lock.json`. |

### Phase 4: Build + Test Gate (BINDING)

Run the project's full build and test suite, scoped to the changed ecosystem, via a single scoped Bash command:

- Node.js: `npm --prefix <path> run build && npm --prefix <path> test` is a compound — instead run them as the project's single configured script (`npm --prefix <path> run ci`) or run `tsc -p <path>` and `vitest run --root <path>` (or `jest --rootDir <path>`) as separate scoped invocations.
- Go: `go -C <path> build ./...`, `go -C <path> vet ./...`, `go -C <path> test ./...` (separate scoped calls).
- JVM: `mvn -f <path>/pom.xml verify` (or `gradle -p <path> build`).
- Python: `uv run --project <path> pytest` (and `uv run --project <path> ruff check`).
- Ruby: `bundle exec --gemfile <path>/Gemfile rspec`.
- PHP: `composer --working-dir=<path> test` (the project's configured script) or `<path>/vendor/bin/phpunit`.
- .NET: `dotnet test <path>`.
- Integration tests that need a database/broker should use Testcontainers so the gate runs hermetically.
- **Gate decision:**
  - **PASS** (build/typecheck + tests all green) → report the successful step. Do NOT auto-continue to another dependency; the user re-runs `deps upgrade` for the next, or the loop continues to the next single candidate only if the user invoked a batch intent.
  - **FAIL** → STOP. Report the failing stage and the test triage. Offer to roll back the single edit (revert the manifest + lockfile change) and, if the failure is a code-level break from the new version, hand the excerpt to the owning language agent (`backend-developer:node-developer` / `go-developer` / `jvm-backend-developer` / `python-backend-developer` / `ruby-developer` / `php-developer` / `dotnet-developer`) for a migration patch — then re-run the gate once.

### Phase 5: Report the step

Emit the Output Format "Upgrade Step" block with from→to, the gate result, and the next recommended dependency (but do not start it without a fresh confirmation).

## Add (`deps add`)

`deps add <package>` introduces a dependency the project does not yet have. A new package is a permanent supply-chain commitment — a maintainer you now trust, a transitive graph you now ship, and a CVE surface you now own — so the justification pass comes before the install, not after.

### Phase 1: Resolve ecosystem & target

1. Run Manifest Discovery. `add` needs exactly one ecosystem: if several are present, require `--stack`, and emit the "ambiguous" error otherwise.
2. Confirm the package is not already a direct or transitive dependency. If it is already direct, stop and say so. If it is present only transitively, say so explicitly — promoting a transitive dep to direct is a real change (it pins a version you were previously getting incidentally) and the user should make it deliberately.

### Phase 2: Justify (delegate)

- **Use the Task tool with `subagent_type="backend-developer:be-dependency-manager"`.**
  Prompt: "Evaluate adding `{package}` ({ecosystem}) to the project at `{path}`, whose current direct dependencies are: {manifest dependency list}. Answer, with evidence: (1) does the runtime's standard library already cover this need (Node `node:crypto`/`node:test`/`fetch`, Go stdlib, `java.time`/`java.net.http`, Python `dataclasses`/`pathlib`/`tomllib`, .NET BCL)? (2) does an already-present dependency cover it? (3) is the need small enough to be a few lines of local code? (4) supply-chain posture — release cadence and last release date, maintainer count, transitive dependency count, install scripts or native build steps, license, and any open advisories. Recommend ADD or DON'T-ADD with a one-line rationale and, on ADD, the exact version to pin. Do not edit anything yet."
- Report the recommendation to the user before proceeding. On DON'T-ADD, stop and present the alternative — do not install anyway.

### Phase 3: Vet for advisories

Run the ecosystem's CVE scanner against the proposed package and version before it enters the manifest (`npm audit` after a dry-run resolve, `govulncheck` post-add, `osv-scanner` against the candidate, or the osv.dev API by package + version). A candidate with an open unpatched advisory is reported and NOT installed unless the user overrides after seeing it.

### Phase 4: Add with an exact pin

Install using the ecosystem's own tooling, exact version, dev-vs-runtime scope chosen deliberately:

| Ecosystem | Add command |
|-----------|-------------|
| Node.js | `npm install --prefix <path> --save-exact <pkg>@x.y.z` (dev: `--save-dev`); pnpm `pnpm --dir <path> add --save-exact`, yarn `yarn --cwd <path> add --exact` |
| Go | `go -C <path> get <module>@vX.Y.Z`, then `go -C <path> mod tidy` |
| JVM | Maven: add an exact `<version>` `<dependency>` (use `<dependencyManagement>` if the project centralizes versions). Gradle: `implementation("group:name:x.y.z")` — never a dynamic `+` or `latest.release` |
| Python | `uv add --project <path> '<pkg>==x.y.z'` (dev: `--dev`), refreshing `uv.lock` |
| Ruby | `bundle add <gem> --version 'x.y.z' --gemfile <path>/Gemfile` (exact, not `~>`) |
| PHP | `composer require --working-dir=<path> vendor/pkg:x.y.z` (dev: `--dev`) |
| .NET | `dotnet add <path> package <pkg> --version x.y.z`, then restore with lock mode |

Put test-only, lint-only, and build-only packages in the dev/test scope — a dev dependency in the runtime graph is a shipped attack surface for no benefit.

### Phase 5: Build + Test Gate (BINDING)

Run the same gate as the Upgrade workflow's Phase 4, scoped to the ecosystem. **PASS** → report the added package, its pin, its transitive count, and its license. **FAIL** → STOP, report the failing stage, and offer to revert the manifest and lockfile change.

### Phase 6: Report

Emit the Output Format "Add Step" block. Note explicitly if the package landed in the runtime scope, since that is what ships.

## Tool Availability

Confirm each ecosystem's CLI / scanner before its pass. Missing → print hint, skip that pass, continue. Never hard-fail.

| Missing tool | Install hint |
|--------------|--------------|
| `npm` / `pnpm` / `yarn` | Install Node.js LTS (`https://nodejs.org`); `corepack enable` provides pnpm/yarn (verify against your toolchain) |
| `go` | `https://go.dev/dl/` or `brew install go` |
| `govulncheck` | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| `mvn` / `gradle` | `brew install maven gradle` (or use the project's `./mvnw` / `./gradlew` wrapper) |
| `uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` (verify against your toolchain) |
| `bundle` (Bundler) | `gem install bundler`; `bundle-audit` via `gem install bundler-audit` |
| `composer` | `https://getcomposer.org/download/` or `brew install composer` |
| `dotnet` | Install the .NET SDK (`https://dotnet.microsoft.com/download`) |
| `osv-scanner` | `brew install osv-scanner` (or `go install github.com/google/osv-scanner/cmd/osv-scanner@latest`) — without it, this command falls back to the osv.dev API |
| `trivy` (optional supplement) | `brew install trivy` — scans lockfiles + container images for CVEs |

A missing native scanner triggers the `osv-scanner` → osv.dev API fallback (network), not a skipped CVE pass.

## Output Format

```markdown
## Dependency Audit Report

**Target:** {path}
**Mode:** {audit | upgrade}
**Ecosystems:** {node, go, jvm, python, ruby, php, dotnet — as discovered}

### Outdated

| Ecosystem | Package | Current | Latest | Jump | Risk |
|-----------|---------|---------|--------|------|------|
| node | express | 4.19.2 | 5.1.0 | major | review breaking changes (router/middleware) |
| go | github.com/gin-gonic/gin | v1.9.1 | v1.10.0 | minor | low |
| python | fastapi | 0.110.0 | 0.115.6 | minor | low |
| jvm | org.springframework.boot:spring-boot | 2.7.18 | 3.4.1 | major | Spring Boot 2→3 (jakarta namespace) |

### Vulnerabilities (SR vocabulary + OWASP API Top 10)

| Severity | Advisory | Package | Affected | Fixed in | OWASP | Remediation |
|----------|----------|---------|----------|----------|-------|-------------|
| High | GHSA-xxxx-xxxx | jsonwebtoken | <range> | <x.y.z> | API2 | upgrade to <x.y.z> |
| Medium | CVE-2026-NNNN | axios | <range> | <x.y.z> | API7 (SSRF) | upgrade / pin allowlist |

(If none: "No known vulnerabilities in the queried versions via {native scanner | osv-scanner | osv.dev}.")

### Licenses

| Package | License | Note |
|---------|---------|------|
| <pkg> | MIT | compatible |
| <pkg> | AGPL-3.0 | network-copyleft — review compatibility for a SaaS service (SR item) |

### Prioritized Upgrade Plan
1. **Security first:** {pkg} {cur}→{fixed} (advisory {id}, OWASP {Apin})
2. {pkg} {cur}→{tgt} (patch/minor)
3. {pkg} major upgrades — individually, one at a time

<!-- upgrade mode only -->
### Upgrade Step
- **Package:** {pkg} ({ecosystem})
- **From → To:** {current} → {target} (exact pin)
- **Manifest edits:** {files changed: manifest + lockfile}
- **Build + Test gate:** PASS / FAIL ({failing stage})
- **Next recommended:** {pkg} (run `/backend-developer:deps upgrade --stack {stack}`)

<!-- add mode only -->
### Add Step
- **Package:** {pkg} ({ecosystem}) — pinned `{x.y.z}`
- **Justification:** ADD / DON'T-ADD — {stdlib or existing-dependency alternative considered}
- **Scope:** runtime (ships) / dev (does not ship)
- **Supply chain:** {n} transitive deps · license {SPDX} · last release {date} · advisories {none|list}
- **Manifest edits:** {files changed: manifest + lockfile}
- **Build + Test gate:** PASS / FAIL ({failing stage})

### Skipped
- {ecosystem}: {missing tool} — install hint printed above.
```

## Error Handling

### No manifests found
```
Error: No dependency manifests detected under {path}.
Looked for: package.json, go.mod, pom.xml/build.gradle(.kts), pyproject.toml,
Gemfile, composer.json, *.csproj/Directory.Packages.props.
Suggestion: Run from the project root, or pass an explicit [path].
```

### Multiple ecosystems, ambiguous upgrade or add
```
Error: {N} ecosystems present ({list}). `deps {upgrade|add}` needs exactly one.
Suggestion: Re-run with --stack <node|go|jvm|python|ruby|php|dotnet>.
```

### Flag-form subcommand
```
Error: `{--upgrade|--add}` is not a supported flag. Mutating modes are selected by
the first token only, so this run would otherwise have silently become a read-only audit.
Suggestion: Re-run as `deps {upgrade|add} [package]`.
```
Stop here — do not fall back to `audit`.

### Package not found in manifest (upgrade)
```
Error: {package} is not a declared dependency of the {ecosystem} manifest.
Suggestion: Check the spelling against the manifest, or introduce it with
/backend-developer:deps add {package} --stack {stack}.
```

### Package already present (add)
```
Error: {package} is already a direct dependency of the {ecosystem} manifest at {version}.
Suggestion: To move it to a newer version, use
/backend-developer:deps upgrade {package} --stack {stack}.
```

### Justification says DON'T-ADD
```
Not added: {package}. {be-dependency-manager}'s assessment is that {stdlib API |
already-present dependency {dep} | ~{n} lines of local code} covers this need.
Nothing was installed. Re-run with an explicit override if you still want it.
```
A DON'T-ADD is a stop, not a warning — never install past it on your own judgment.

### Floating versions without a committed lockfile
```
Warning: {manifest} declares ranges/dynamic versions but no committed lockfile —
builds are not reproducible and CI may drift from production.
Suggestion: commit the lockfile (npm install / go mod tidy / uv lock / bundle lock
/ composer install / dotnet restore --use-lock-file) and re-run.
```

### Build+test gate failed after upgrade
Not silent. Report the failing stage from the scoped build+test commands, offer to roll back the single manifest + lockfile edit, and (for a code-level break) route the excerpt to the owning language agent for a migration patch before re-running the gate once.

### Tool missing
Print the install hint, skip that ecosystem's pass, continue. A missing native scanner falls back to `osv-scanner` and then the osv.dev API. The command only reports a hard FAIL when *every* eligible pass was skipped.

## See Also

- `skill: language-detection` — canonical manifest → ecosystem → agent routing (keep discovery in sync).
- `skills/_shared/version-feature-matrix.md` — canonical framework/runtime version + fallback lookup referenced throughout.
- `skill: secure-coding` — supply-chain, OWASP API Top 10, and dependency-trust rules that gate a diff.
- `/backend-developer:build-test` — the build+test workhorse the upgrade gate mirrors per ecosystem.
- `igrsoft:security-review-process` — SR-stage vocabulary used for every vulnerability finding here.
```
