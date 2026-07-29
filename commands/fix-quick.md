---
description: Run per-ecosystem linters and formatters and apply the safe, mechanical auto-fixes
argument-hint: [path (default .)] [--check] [--fix] [--stack node|go|jvm|python|ruby|php|dotnet]
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 800
  max-tokens: 8000
  model-distribution:
    haiku: 55%
    sonnet: 42%
    opus: 3%
---

# Quick Fix
<!-- Updated: June 2026 -->

Run each ecosystem's standard linter and formatter over the target back-end, report violations, and — in `--fix` mode — apply the safe, deterministic auto-fixes, then re-check. Fast, cheap, and reversible: this is the deterministic-cleanup pass, not a review. Deep, judgment-bearing fixes escalate to `/backend-developer:review-code --fix`.

[Extended thinking: This command is the backend-developer analogue of a pre-commit / CI lint stage. It detects which stacks are present, discovers each stack's config (so it honors project rules instead of imposing its own), and runs linters/formatters in a fixed order per stack. `--check` is the CI mode — no edits, exit-code-honest, with a per-rule violation count — and `--fix` applies only the mechanical fixes (`eslint --fix`, `biome check --write`, `gofmt -w`, `ruff check --fix`, `rubocop -a`, `php-cs-fixer fix`, `dotnet format`) then re-runs the linters to confirm. Anything a formatter or `--fix` rule cannot resolve mechanically (type errors, security findings, semantic lint) is reported, not forced; those land in `review-code --fix`. Keep it mostly on haiku: the work is tool invocation and table assembly, not analysis — sonnet only when a mixed-stack monorepo needs disambiguation. Version-sensitive flag spellings: see `skills/_shared/version-feature-matrix.md`.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **`--check` never edits.** In `--check` (or default-with-no-flag) mode, run every tool in its report-only variant. Do NOT pass `--fix`, `--write`, `-w`, or `-a`. If any tool reports a violation, the command result is FAIL — surface the per-rule violation counts.
2. **`--fix` applies only mechanical fixes, then re-checks.** Run formatters and the auto-fixable lint rules, then re-run the linters in report-only mode. Report what was fixed and what still remains. Never claim "clean" without the post-fix re-check passing.
3. **Honor project config, do not impose.** Discover and use `eslint.config.{js,ts}`/`.eslintrc*`, `biome.json`, `.golangci.yml`, `.editorconfig`, `[tool.ruff]` in `pyproject.toml`, `.rubocop.yml`, `.php-cs-fixer.dist.php`/`phpstan.neon`, and `.editorconfig`/`*.editorconfig` for .NET (see Config Discovery). Pass no opinionated overrides when a config exists; fall back to the documented defaults only when none is found, and say so in the report.
4. **Type/semantic linters are report-only.** `tsc --noEmit`, `mypy`, `go vet`, `phpstan`, and security-flavored rules are never auto-fixed — they always land in the report and, when they need judgment, under "Needs review". Never force a fix that changes behavior.
5. **Single-command Bash invocations.** Use each tool's own path/glob/recursion flags. Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands. Run a package-manager script (`npm run lint`, `pnpm lint`) only when it maps to the same report-only behavior.
6. **Tool-missing never hard-fails.** If a linter/formatter binary is absent, print the install hint, skip that stack's pass, and continue. Report what was skipped.
7. **This is the shallow pass.** Do NOT attempt semantic refactors, API redesigns, transaction-boundary changes, or fixes that alter behavior. When a finding needs judgment, list it under "Needs review" and point to `/backend-developer:review-code --fix`. Do not delegate to an agent from this command.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Report violations across all detected stacks (CI-safe, no edits)
/backend-developer:fix-quick . --check

# Auto-fix everything fixable, then re-check
/backend-developer:fix-quick . --fix

# Fix only the Node/TypeScript service under a subtree
/backend-developer:fix-quick services/api --fix --stack node

# Check just the Go module (exit non-zero if any violation)
/backend-developer:fix-quick cmd/ --check --stack go
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path` | `.` | Directory or file to lint. Stack detection and tool discovery are rooted here. |
| `--check` | default | Report-only. No edits. FAIL if any violation remains. This is the CI mode. |
| `--fix` | off | Apply mechanical formatter + auto-fix-rule changes, then re-check. Mutually exclusive with `--check`; `--fix` wins if both are passed (with a warning). |
| `--stack node\|go\|jvm\|python\|ruby\|php\|dotnet` | auto | Restrict the run to one stack. Without it, every detected stack is processed. |

When neither `--check` nor `--fix` is given, default to `--check`.

## Stack Detection

Detect which stacks are present, then run each one's pass. The manifest → stack map is canonical in `skill: language-detection` — do not fork it. For this command, detect **per file/subtree**, not a single project stack, because a polyglot monorepo may need eslint for `services/api`, golangci-lint for `cmd/worker`, and rubocop for `legacy/` in one invocation.

| Stack | Files / markers linted |
|-------|------------------------|
| Node | `*.ts`, `*.tsx`, `*.js`, `*.mjs` near `package.json` |
| Go | `*.go` near `go.mod` |
| JVM | `*.java`, `*.kt`, `*.kts` near `pom.xml`/`build.gradle*` |
| Python | `*.py`, `*.pyi` near `pyproject.toml`/`requirements.txt` |
| Ruby | `*.rb`, `*.rake`, `Rakefile` near `Gemfile` |
| PHP | `*.php` near `composer.json` |
| .NET | `*.cs` near `*.csproj`/`*.sln` |

`--stack` overrides detection and processes only that stack's files.

## Config Discovery

Before running each stack's tools, discover its configuration so the run honors project rules. Record which config (if any) was found in the report.

| Stack | Config files (in precedence order) | If missing |
|-------|------------------------------------|------------|
| Node | `biome.json`/`biome.jsonc`, `eslint.config.{js,ts,mjs}`, `.eslintrc*`, `.prettierrc*`, `tsconfig.json` | prefer Biome if present, else ESLint; Prettier only if configured; `tsc` only if a `tsconfig.json` exists, else note "tsc skipped (no tsconfig)" |
| Go | `.golangci.yml`/`.golangci.yaml`/`.golangci.toml` | golangci-lint: built-in default linters; `gofmt`/`go vet` need no config |
| JVM | `.editorconfig` (ktlint), `spotless` block in `build.gradle*`/`pom.xml` | ktlint: official Kotlin style defaults; if neither ktlint nor spotless is wired, note "no JVM formatter configured" |
| Python | `[tool.ruff]` (and `[tool.mypy]`) in `pyproject.toml`, `ruff.toml`/`.ruff.toml`, `mypy.ini` | ruff: documented defaults; mypy: run only if a config or type hints/`py.typed` are present, else note "mypy skipped (no config)" |
| Ruby | `.rubocop.yml` | rubocop: bundled defaults (noisy — say so in the report) |
| PHP | `.php-cs-fixer.dist.php`/`.php-cs-fixer.php`, `phpstan.neon`/`phpstan.dist.neon` | php-cs-fixer: PSR-12 default ruleset; phpstan: run only if a `phpstan.neon` exists, else note "phpstan skipped (no config)" |
| .NET | `.editorconfig`, `Directory.Build.props` | `dotnet format` reads `.editorconfig`; with none, only whitespace/import organization applies |
| All | `.editorconfig` | informational — Biome, gofmt-adjacent tools, ktlint, and `dotnet format` all consult it |

Exact flag spellings and which features a given tool version supports vary across releases — when a flag is rejected, check `skills/_shared/version-feature-matrix.md` before improvising.

## Per-Stack Tool Order

Run tools in this order. In `--fix`, formatters run **before** the final lint re-check so formatting churn does not mask real lint findings.

| Stack | Lint (check) | Format (check) | Fix (mechanical) |
|-------|--------------|----------------|------------------|
| Node | `eslint <path>` **or** `biome check <path>` (no `--write`); `tsc --noEmit` (report-only) | `prettier --check <path>` (if configured) **or** Biome formatter via `biome check` | `eslint --fix <path>` / `biome check --write <path>`; then `prettier --write <path>` if used |
| Go | `golangci-lint run <pkgs>`; `go vet ./...` (report-only) | `gofmt -l <files>` (lists would-change) | `gofmt -w <files>`; `golangci-lint run --fix <pkgs>` (only auto-fixable linters) |
| JVM | `ktlint <globs>` (no `-F`) | ktlint reports format diffs; `gradle spotlessCheck` if wired | `ktlint -F <globs>`; `gradle spotlessApply` |
| Python | `ruff check <path>`; `mypy <path>` (if configured, report-only) | `ruff format --check --diff <path>` | `ruff check --fix <path>` then `ruff format <path>` |
| Ruby | `rubocop <path>` | rubocop reports layout cops in the same pass | `rubocop -a <path>` (safe autocorrect only; never `-A`) |
| PHP | `php-cs-fixer fix --dry-run --diff <path>`; `phpstan analyse <path>` (if configured, report-only) | php-cs-fixer `--dry-run` shows the diff | `php-cs-fixer fix <path>` |
| .NET | `dotnet format --verify-no-changes <proj>`; analyzer warnings surface in `dotnet build` | `dotnet format` reports style violations | `dotnet format <proj>` (whitespace + style + analyzer fixers) |

Notes:
- **`golangci-lint --fix` and `rubocop -a` are conservative**: apply only the safe-autofix linters/cops the project opted into; never invent rules or use `rubocop -A` (unsafe autocorrect can change behavior — out of scope, Rule 7).
- **`tsc`, `mypy`, `go vet`, and `phpstan` are report-only.** None has a safe mechanical fixer; their findings always land in the report and, when they need judgment, under "Needs review".
- `ruff check --statistics` and `golangci-lint run --output.tab.path=stdout` produce the per-rule counts used for the violation summary in `--check`. (golangci-lint v2 replaced the v1 `--out-format=<fmt>` flag with per-format `--output.<fmt>.path`; on a v1 toolchain use `--out-format=tab`. v2 also renamed config keys — `linters.default` replaced `enable-all`/`disable-all`, and `golangci-lint migrate` converts a v1 config.)

## Workflow

### Phase 1: Detect & Discover (Bash)

1. Confirm `path` exists; if not, emit the Error Handling "path not found" message and stop.
2. Resolve mode: `--fix` if present (warn if `--check` also passed), else `--check`.
3. Detect stacks present under `path` (honoring `--stack`). If none match, emit "no lintable sources" and stop.
4. For each detected stack, run Config Discovery and note which config was found.
5. Verify each stack's tools exist (`command -v eslint biome gofmt golangci-lint ktlint ruff mypy rubocop php-cs-fixer dotnet`). Missing → print install hint, skip that stack's pass, note the skip.
6. For Node, decide Biome-vs-ESLint by config presence (Rule 3); for Python/PHP, decide whether type/static analysis runs by config presence (Rule 4).

### Phase 2a: Check mode (`--check`)

1. For each stack, run the **lint (check)** and **format (check)** commands from the tool-order table. Do NOT edit.
2. Collect violations per tool. For Python, capture `ruff check --statistics`; for Go, capture the golangci-lint per-linter counts (the per-rule summary).
3. Assemble the Output Format report. If any tool reported a violation, result is FAIL (non-zero — CI-honest). If all clean, PASS.

### Phase 2b: Fix mode (`--fix`)

1. For each stack, apply the **fix (mechanical)** commands from the tool-order table via `Bash`:
   - Node: `eslint --fix` / `biome check --write`, then `prettier --write` if used.
   - Go: `gofmt -w`, then conservative `golangci-lint run --fix`.
   - JVM: `ktlint -F` / `gradle spotlessApply`.
   - Python: `ruff check --fix`, then `ruff format`.
   - Ruby: `rubocop -a` (safe only).
   - PHP: `php-cs-fixer fix`.
   - .NET: `dotnet format`.
2. Record each file touched and the rule/category of each applied fix (for the File | Line | Fix table).
3. **Re-check**: re-run the report-only lint commands (Phase 2a step 1) to confirm. Anything still failing is reported as remaining, with `tsc`/`mypy`/`go vet`/`phpstan` judgment items routed to "Needs review".
4. Result is PASS only if the re-check is clean; otherwise PARTIAL with the remaining count.

### Phase 3: Report (Bash)

Emit the Output Format. In `--fix`, include the applied-fix table, the rollback hint, and any "Needs review" escalation. In `--check`, include the violation table and per-rule counts.

## Tool Availability

| Missing tool | Install hint |
|--------------|--------------|
| `eslint` / `prettier` | `npm i -D eslint prettier` (or run via `npx`) |
| `biome` | `npm i -D @biomejs/biome` (or `pnpm add -D @biomejs/biome`) |
| `tsc` | `npm i -D typescript` |
| `gofmt` / `go vet` | ship with the Go toolchain — `brew install go` |
| `golangci-lint` | `brew install golangci-lint` (or `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`) |
| `ktlint` | `brew install ktlint` |
| `ruff` / `mypy` | `uv tool install ruff` / `uv tool install mypy` |
| `rubocop` | `gem install rubocop` (or `bundle add rubocop --group development`) |
| `php-cs-fixer` / `phpstan` | `composer require --dev friendsofphp/php-cs-fixer phpstan/phpstan` |
| `dotnet format` | ships with the .NET SDK — `dotnet tool install -g dotnet-format` on older SDKs |

Exact flag spellings vary across tool releases — verify against your toolchain (and `skills/_shared/version-feature-matrix.md`) when a flag is rejected. Never hard-fail on a missing tool: print the hint, skip that stack, continue, and report the skip.

## Output Format

```markdown
## Lint & Fix Report

**Target:** {path}
**Mode:** check | fix
**Stacks:** {Node, Go, Python — detected}
**Configs found:** {biome.json ✅ | .golangci.yml ✅ | [tool.ruff] ✅ | .rubocop.yml ❌ (defaults) | ...}

| Stack | Tool | Violations | Status |
|-------|------|-----------:|--------|
| Node | eslint | 5 | ❌ (no-unused-vars ×3, eqeqeq ×1, no-floating-promises ×1) |
| Node | prettier | 2 files | ❌ would reformat |
| Node | tsc | 1 | ⚠ report-only |
| Go | golangci-lint | 3 | ❌ (errcheck ×2, ineffassign ×1) |
| Go | gofmt | 1 file | ❌ would reformat |
| Python | ruff check | 4 | ❌ (F401 ×2, E711 ×1, UP032 ×1) |
| Python | mypy | 1 | ⚠ report-only |

**Result:** PASS / FAIL / PARTIAL — {N violations across M tools}

<!-- --fix mode only: applied fixes -->
### Fixes Applied ({total})

| File | Line | Fix |
|------|------|-----|
| services/api/src/user.ts | 42 | eslint no-unused-vars: removed unused import `crypto` |
| services/api/src/user.ts | 88 | prettier: reformatted object literal |
| cmd/worker/main.go | 17 | gofmt: gofmt'd imports + alignment |
| app/models.py | 3 | ruff F401: removed unused import `os` |
| app/models.py | 17 | ruff E711: `== None` → `is None` |

### Rollback
To undo every change this run made:
```bash
git checkout -- {files}
```

<!-- when mechanical fixes cannot resolve everything -->
### Needs review ({count})
- {file}:{line}: {tsc/mypy/go vet/phpstan finding that needs judgment}
- Escalate with: `/backend-developer:review-code --fix {path}`

<!-- on skipped stacks only -->
### Skipped
- {stack}: {missing tool} — install hint printed above.
- Node tsc: no `tsconfig.json` — skipped (type-check not configured).
```

In `--check` mode, the "Violations" column doubles as the per-rule summary: each cell shows the count and (for eslint/ruff/golangci-lint/rubocop) the rule codes, so a CI run surfaces exactly which rules tripped.

## Error Handling

### Path not found
```
Error: Path not found: {path}
Suggestion: Pass a directory or file that exists, e.g. /backend-developer:fix-quick . --check
```

### No lintable sources
```
Error: No Node, Go, JVM, Python, Ruby, PHP, or .NET sources found under {path}.
Suggestion: Check the path, or pass --stack to target a specific ecosystem.
```

### Both --check and --fix passed
```
Warning: --check and --fix are mutually exclusive; proceeding with --fix.
(Run again with only --check for a CI-safe, no-edit pass.)
```

### Type/static analysis not configured
`tsc` runs only with a `tsconfig.json`; `mypy` only with a config or type hints; `phpstan` only with a `phpstan.neon`. When absent, skip that report-only check and note it — the formatter and lint passes still run.

### Tool missing
Print the install hint from Tool Availability, skip that stack's pass, continue. Only when *every* detected stack is skipped does the command report FAIL with the aggregated install hints.

## See Also

- `skill: language-detection` — canonical manifest → stack → agent routing (keep detection in sync).
- `/backend-developer:build-test` — run before building to cut compiler/transpiler-warning noise; build green first, then lint.
- `/backend-developer:review-code --fix` — escalation target for findings that need judgment (semantic refactors, auth-boundary or transaction changes, API-contract fixes) beyond mechanical lint fixes.
- `/backend-developer:fix-modernize` — for cross-version modernization (`ruff --select UP`, `golangci-lint` modernizers, framework migrations) which goes deeper than this command's mechanical pass.
- `skills/_shared/version-feature-matrix.md` — canonical lookup for which linter/formatter version supports which flag.
```