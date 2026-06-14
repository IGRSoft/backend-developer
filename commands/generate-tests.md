---
name: generate-tests
description: Generate unit, integration, and contract tests for back-end code using the project framework
argument-hint: "[path/scope (default: working changes)] [--coverage-gaps] [--integration] [--contract]"
allowed-tools: Read, Glob, Grep, Bash
estimated-cost:
  min-tokens: 2000
  max-tokens: 16000
  model-distribution:
    haiku: 20%
    sonnet: 70%
    opus: 10%
---

# Generate Tests
<!-- Updated: June 2026 -->

Generate a runnable test suite for back-end code — unit, integration, and contract — register it with the project's test runner, and prove it discovers and runs before reporting success. The product is *passing, discoverable tests* — not test source files on disk.

[Extended thinking: The hard part of back-end test generation is not writing assertions — it is honoring the project's existing framework, wiring tests into the runner so it discovers them, and proving they actually execute against real boundaries. A unit test that mocks the database into oblivion proves nothing about a transaction; an integration test that never spins up Postgres is a lie. This command refuses to introduce a second framework into a project that already has one, delegates the actual test authoring to be-test-generator (which knows happy-path + edge-case + failure-mode coverage per stack, plus auth-boundary and idempotency cases), then runs a verification gate that reuses build-test's detect-install-test logic. With `--integration` it stands up real dependencies via Testcontainers; with `--contract` it pins the API surface with Pact / schema tests so a producer change that breaks a consumer fails CI. A generated test that does not run, or runs but the runner never discovers, is a defect, not a deliverable. The command halts and routes the failure back rather than declaring victory.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Detect the framework FIRST — never introduce a second one.** Before generating anything, scan for the framework already in use (see Phase 1). If the project already tests with Vitest, do NOT generate Jest; if it uses pytest, do NOT add unittest; if `*_test.go` files use the stdlib `testing` package, do NOT pull in a different harness. The CLI flags only *select test type* (`--integration`, `--contract`) — they do NOT override an in-use framework. If detection finds two competing frameworks already wired in, STOP and report the conflict.
2. **Delegate generation to be-test-generator.** Do NOT author test bodies yourself. The agent owns happy-path + edge-case + failure-mode coverage, including auth-boundary, validation, and idempotency cases. You own detection, registration, and verification.
3. **Registration is part of the deliverable.** A test the runner cannot discover does not exist. After generation you MUST wire tests into the project's conventions: correct file naming/location (`*.test.ts`, `*_test.go`, `tests/test_*.py`, `*Test.java`, `*Tests.cs`, `*_spec.rb`), shared setup (`conftest.py`, `setupFiles`, `TestMain`, `@SpringBootTest` base class), and Testcontainers lifecycle for integration. Verify registration by *listing* tests (`vitest list`, `go test -list`, `pytest --collect-only`), not by eyeballing files.
4. **Verification gate is mandatory.** Generated tests MUST compile (TS/Go/Java/C#) and MUST run (all stacks). Reuse the detection + install + test logic from `/backend-developer:build-test`. A suite that does not build, or builds but does not run, is a FAILURE — report it as such and route the error back to the matching language agent. Do NOT report success on un-run tests.
5. **Single-command Bash invocations.** Use runner directory/project flags (`npm --prefix <path> test`, `go test ./<pkg>/...`, `uv run --project <path> pytest <path>/tests`, `mvn -f <path>/pom.xml test`, `dotnet test <path>`). Never `cd`-chain or `&&`-chain directory changes — scoped Bash patterns do not match compound commands.
6. **Tool-missing never hard-fails.** If the framework's toolchain binary (or the Docker daemon needed for Testcontainers) is absent, print the install hint, skip that test type/stack, and continue with the others. Report what was skipped. Never hard-fail the whole command for one missing tool.
7. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Detect the framework and generate + register + verify unit tests for the working changes
/backend-developer:generate-tests

# Generate tests for one module/package
/backend-developer:generate-tests src/orders

# Target untested branches surfaced by a coverage run
/backend-developer:generate-tests src/orders --coverage-gaps

# Add Testcontainers-backed integration tests for a repository layer
/backend-developer:generate-tests src/repositories --integration

# Pin the HTTP API surface with consumer-driven contract tests
/backend-developer:generate-tests src/api --contract
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `path/scope` | working changes (`git diff` set) | File, module, package, or directory to generate tests for. Detection scan is rooted at its enclosing project. |
| `--coverage-gaps` | off | Run a coverage pass first (`vitest --coverage` / `jest --coverage`, `go test -coverprofile`, `pytest --cov`, JaCoCo, `dotnet test --collect:"XPlat Code Coverage"`) and target generation at uncovered branches/lines instead of generating broadly. Requires a buildable, already-runnable existing suite to measure against. |
| `--integration` | off | Generate integration tests that exercise real dependencies (DB, cache, broker) via **Testcontainers** — Postgres/MySQL/MongoDB/Redis/Kafka containers spun up in setup, torn down in teardown. Requires a running Docker daemon. |
| `--contract` | off | Generate **contract tests** — Pact consumer/provider pacts for service-to-service calls, or schema tests (OpenAPI/JSON Schema response validation, gRPC `.proto`/protobuf round-trips) for the HTTP/gRPC surface. Pins the API so a producer change that breaks a consumer fails the gate. |

## Framework Detection

Detection is the first and most important step. Scan top-down; the **in-use** framework always wins.

| Stack | Scan for (in priority order) | Resolved framework |
|-------|------------------------------|--------------------|
| Node/TS | `vitest` in `package.json` devDeps + `vitest.config.*`; `*.test.ts` importing `vitest` | Vitest |
| Node/TS | `jest`/`ts-jest` in devDeps + `jest.config.*`; `__tests__/` | Jest |
| Node/TS | `node:test` import + `--test` in scripts | node:test |
| Go | `*_test.go` files; `testify` in `go.mod` (assertions) | stdlib `testing` (+ testify) |
| Python | `[tool.pytest.ini_options]` in `pyproject.toml`; `pytest` in dev deps; `tests/test_*.py` using fixtures | pytest |
| Java/Kotlin | `junit-jupiter` / `spring-boot-starter-test` in `pom.xml`/`build.gradle`; `*Test.java` | JUnit 5 (+ Spring Test) |
| Ruby | `rspec` in `Gemfile`; `spec/*_spec.rb` | RSpec |
| PHP | `phpunit/phpunit` in `composer.json`; `tests/*Test.php` | PHPUnit |
| C#/.NET | `xunit`/`nunit`/`MSTest` package refs; `*Tests.cs` | xUnit (or detected runner) |
| Integration (any) | Testcontainers binding (`@testcontainers/*`, `testcontainers-go`, `testcontainers[python]`, `org.testcontainers`) | Testcontainers + above unit framework |
| Contract (any) | `@pact-foundation/pact`, `pact-go`, Pact JVM; OpenAPI spec + schema-validation lib | Pact / schema tests |

Resolution rules:

- **In-use beats everything.** If the scan finds Vitest already wired in, do NOT generate Jest tests even if Jest is also installed — STOP and report the conflict (Error Handling → "framework conflict") when two unit frameworks compete.
- **Empty project.** No framework markers found → pick the framework matrix default for the detected stack (`skill: testing-strategy`): Node/TS → Vitest, Go → stdlib `testing`, Python → pytest, Java/Kotlin → JUnit 5, Ruby → RSpec, PHP → PHPUnit, .NET → xUnit. Announce the choice in the report. Integration → add Testcontainers; contract → add Pact.
- **Mixed-language repo.** Detect per language and generate per language; never cross frameworks. Language ownership follows `skill: language-detection`.

This routing is a specialization of the shared detection table — keep it in sync with `skill: language-detection`, do not fork it.

## Workflow

### Phase 1: Detect (Bash + Read)

1. Resolve the scope. If no `path` given, use the working-changes set (`git diff --name-only` + staged). If `path` given, confirm it exists; if not, emit the Error Handling "path not found" message and stop.
2. Resolve the language(s) of the scope via `skill: language-detection` (extension census + manifest markers).
3. For each language, run Framework Detection. Record the **in-use** framework, or the resolved default when empty.
4. If two competing unit frameworks are both wired in, STOP and emit "framework conflict".
5. Verify the framework's toolchain exists (`command -v node`/`npm` + a `vitest`/`jest` binary; `command -v go`; `command -v uv`/`pytest`; `command -v mvn`/`gradle`; `command -v dotnet`; `command -v ruby`/`bundle`; `command -v php`/`composer`). For `--integration`, verify the **Docker daemon** is reachable (`docker info`). If missing, print the install hint (Tool Availability), skip that test type/stack, continue.
6. Identify the units under test: exported functions/classes/handlers, route/controller definitions, repository and service methods, and (for `--contract`) the request/response shapes of the public API. Read them so the generation prompt carries real signatures, route paths, and DTO schemas.

### Phase 2: Coverage Baseline (Bash) — only with `--coverage-gaps`

1. Require an existing suite that already builds and runs (otherwise there is nothing to measure). If none, fall back to broad generation and note it.
2. Run the coverage pass, teeing to `.context/logs/`:

   | Stack | Coverage command |
   |-------|------------------|
   | Node/TS | `npm --prefix <path> run test -- --coverage` (Vitest/Jest) |
   | Go | `go test ./<pkg>/... -coverprofile=<path>/cover.out` then `go tool cover -func=<path>/cover.out` |
   | Python | `uv run --project <path> pytest --cov=<package> --cov-report=term-missing` |
   | Java/Kotlin | `mvn -f <path>/pom.xml test` with JaCoCo, read `target/site/jacoco/jacoco.xml` |
   | .NET | `dotnet test <path> --collect:"XPlat Code Coverage"` then read the Cobertura report |

3. Parse uncovered lines/branches. Build a gap list (`{file, symbol, uncovered branch/line}`) to hand the generator, so it targets the gaps rather than re-covering covered code.

### Phase 3: Generate (delegate to be-test-generator)

Delegate per language. Pass the units under test, the resolved framework, the requested test type(s), and (if any) the coverage gap list. The agent must cover, for each unit: **happy path + edge cases + failure modes** — explicitly including invalid/empty/oversized input, validation rejection, **auth boundaries** (unauthenticated, wrong-tenant/owner — BOLA/BFLA), **idempotency** (repeated requests, retry safety), partial failure / timeout / connection reset, and transaction rollback where applicable.

- Node/TS tree:
  **Use Task tool with subagent_type="backend-developer:be-test-generator"**
  Prompt: "Generate {framework} tests for the Node/TS units in `{path}`: {signatures/routes}. Framework is already in use / chosen: {framework} — do NOT introduce any other framework. Cover, per unit: happy path; edge cases (empty/oversized payloads, boundary values, malformed JSON, non-UTF-8 input); failure modes (validation rejection 4xx, auth boundaries — unauthenticated 401, wrong-owner/tenant 403 (BOLA/BFLA), idempotency on retry, DB/upstream timeout and connection reset, transaction rollback). Use AAA structure and `describe/it` with `test_[unit]_[scenario]_[expected]`-style names per `skill: testing-strategy`. {test_type_block} {coverage_gaps_block} Return the test source files and confirm the file naming/location so Vitest/Jest discovers them. Do not run the suite yourself; I run the verification gate."
- Go tree → **subagent_type="backend-developer:be-test-generator"** (same coverage; framework = stdlib `testing` + testify; table-driven tests, `t.Run` subtests, `httptest.Server` for handlers, registration = `*_test.go` in the package).
- Python → **subagent_type="backend-developer:be-test-generator"**
  Prompt: "Generate pytest tests for the Python module(s)/FastAPI/Django/Flask views in `{path}`: {symbols/routes}. pytest is the project framework — do NOT add unittest. Cover happy path; edge cases (empty/`None`, boundary values, malformed body, large inputs); failure modes (validation errors, auth boundaries 401/403 — BOLA/BFLA, idempotency on retry, upstream timeout/connection reset via mocked or Testcontainers boundaries, transaction rollback). Use `@pytest.mark.parametrize` for input families, `httpx`/`TestClient` for endpoints, and place shared fixtures in `conftest.py`. {test_type_block} {coverage_gaps_block} Follow `skill: testing-strategy`. Return test files plus any new `conftest.py`; do not run the suite."
- Java/Kotlin → **subagent_type="backend-developer:be-test-generator"** (JUnit 5 + Spring Test; `@SpringBootTest`/`@WebMvcTest`/`MockMvc`, `@DataJpaTest` for repositories; registration = `*Test.java` under `src/test/java`).
- Ruby → **subagent_type="backend-developer:be-test-generator"** (RSpec request specs + model specs; `spec/*_spec.rb`).
- PHP → **subagent_type="backend-developer:be-test-generator"** (PHPUnit / Laravel feature tests; `tests/*Test.php`).
- .NET → **subagent_type="backend-developer:be-test-generator"** (xUnit + `WebApplicationFactory` for endpoint tests; `*Tests.cs`).

`{test_type_block}` expands per flag:
- `--integration`: "Generate **integration** tests using Testcontainers: spin up the real dependency ({Postgres|MySQL|MongoDB|Redis|Kafka}) in setup, run migrations, exercise the repository/service against it, tear the container down in teardown. No mocking of the datastore."
- `--contract`: "Generate **contract** tests: {Pact consumer pacts for the outbound service calls / Pact provider verification against the published pact} and/or schema tests validating responses against the OpenAPI/JSON-Schema or protobuf definition. Fail the test if the response shape drifts from the contract."

If the generator returns tests for a unit you did not ask for, or in a framework other than the resolved one, reject that portion and re-prompt — do not accept framework drift.

### Phase 4: Register (Bash)

Wire the generated tests into the runner so it discovers them. Registration is verified by *listing*, not by reading source. The generator returns files in the conventional location; confirm placement and shared setup.

| Framework | Placement / setup | Discovery check |
|-----------|-------------------|-----------------|
| Vitest | `*.test.ts` co-located or under `test/`; `setupFiles` in `vitest.config.*` if shared setup needed | `npx --prefix <path> vitest list` |
| Jest | `*.test.ts` / `__tests__/`; `setupFilesAfterEnv` in `jest.config.*` | `npx --prefix <path> jest --listTests` |
| Go (testing) | `*_test.go` in the package under test; `TestMain` for shared setup/Testcontainers lifecycle | `go test ./<pkg>/... -list '.*'` |
| pytest | `tests/test_*.py`; add/extend `conftest.py`; ensure `[tool.pytest.ini_options] testpaths` if absent | `uv run --project <path> pytest --collect-only -q` |
| JUnit 5 | `src/test/java/.../*Test.java`; `@SpringBootTest` base class for shared context / Testcontainers `@Container` | `mvn -f <path>/pom.xml test -Dtest='*Test' -DskipTests=false --also-make` (or `--dry-run`) |
| RSpec | `spec/**/*_spec.rb`; `spec_helper.rb`/`rails_helper.rb` | `bundle exec rspec --dry-run` |
| PHPUnit | `tests/*Test.php`; `phpunit.xml` testsuite paths | `vendor/bin/phpunit --list-tests` |
| xUnit | `*Tests.cs` in the test project; `WebApplicationFactory` fixture | `dotnet test <path> --list-tests` |

For empty-project scaffolding, also pin the dependency: add the framework + (if `--integration`) Testcontainers + (if `--contract`) Pact to the manifest, and create the config/test directory. Keep the pin in step with `skill: build-systems` and `skill: testing-strategy`.

### Phase 5: Verification Gate (Bash) — MANDATORY

Reuse `/backend-developer:build-test`'s detect → install → build → test logic. Tee to `.context/logs/generate-tests-<timestamp>.log`.

1. **Build/compile (TS/Go/Java/C# only):** type-check / compile the test target.
   ```bash
   npm --prefix "$path" run typecheck 2>&1 | tee -a "$LOG"   # or tsc --noEmit / go vet ./... / mvn -f compile
   ```
   Capture `${PIPESTATUS[0]}`. If the test target does NOT compile → gate FAIL (stage `compile`). Route back per "Gate Failure."
2. **Discover:** run the framework's list/collect command (Phase 4 column). If the new tests are NOT discovered → gate FAIL (registration defect). Fix placement/config and re-list.
3. **Run:**

   | Framework | Run command |
   |-----------|-------------|
   | Vitest | `npm --prefix <path> run test` (or `npx vitest run`) |
   | Jest | `npm --prefix <path> test -- --runInBand` |
   | Go (testing) | `go test ./<pkg>/... -race` |
   | pytest | `uv run --project <path> pytest -x -q` |
   | JUnit 5 | `mvn -f <path>/pom.xml test` (or `gradle test`) |
   | RSpec | `bundle exec rspec` |
   | PHPUnit | `vendor/bin/phpunit` |
   | xUnit | `dotnet test <path>` |

   For `--integration`, the run requires a reachable Docker daemon; Testcontainers starts/stops the containers. Capture `${PIPESTATUS[0]}`. **A suite that does not run is a FAILURE, not a deliverable.** New tests that fail because they expose a real bug (broken auth boundary, lost transaction, contract drift) → report as a finding (the test is correct, the code is not); new tests that fail because they are wrong → route back to the generator.
4. Only when the suite **builds, is discovered, and runs** do you report success. The CLI-fallback evidence for this gate is the **test runner output, the coverage report, the Testcontainers/migration logs, and (for `--contract`) the pact verification transcript** — captured in the log, not a screenshot.

### Phase 6: Report (Bash)

Emit the Output Format summary. State pass/fail of the verification gate explicitly — never imply success without it.

## Gate Failure (route back, do not declare victory)

When the verification gate fails, classify and delegate, then re-run from the failing phase:

| Failure | Cause | Route to |
|---------|-------|----------|
| Test target does not compile (TS/Go/Java/C#) | Bad import, wrong type, API misuse in test | `backend-developer:be-test-generator` (fix the test) or the owning language agent (if the test exposed a public-API issue) |
| Tests not discovered | Wrong file name/location, missing `conftest.py`/`setupFiles`/`TestMain`, testsuite path off | Fix registration yourself (Phase 4), re-list |
| Test runs but a new test is wrong | Bad assertion / fixture / wrong container config | `backend-developer:be-test-generator` |
| Test runs and exposes a real bug | The code under test is broken (auth boundary, transaction, idempotency, contract drift) | Report as a finding; route the fix to the owning language agent (`node-developer`/`go-developer`/`jvm-backend-developer`/`python-backend-developer`/`ruby-developer`/`php-developer`/`dotnet-developer`) — do NOT weaken the test to make it pass |

Delegation prompt shape: "Generated-test verification failed at the **{stage}** stage for `{path}` ({framework}). Error and context from `{LOG}`:\n```\n{excerpt}\n```\nFix the {test|registration|code} minimally so the suite builds, is discovered, and runs. Return the patch; I re-run the gate." Re-run the gate after each fix; report each cycle. Never silently auto-iterate.

## Tool Availability

| Missing tool | Install hint |
|--------------|--------------|
| `node` / `npm` / `pnpm` / `yarn` | install Node LTS via `fnm`/`nvm` or `brew install node`; Vitest/Jest install via `npm i -D vitest`/`jest` |
| `go` | `brew install go`; testify via `go get github.com/stretchr/testify` |
| `uv` / `pytest` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` (verify against your toolchain); pytest installs via `uv add --dev pytest` |
| `mvn` / `gradle` | `brew install maven`/`gradle`; JUnit 5 + Spring Test via `spring-boot-starter-test` |
| `dotnet` | install the .NET SDK from `dotnet.microsoft.com`; xUnit via `dotnet add package xunit` |
| `ruby` / `bundle` | `brew install ruby`; `gem install rspec` or add to `Gemfile` |
| `php` / `composer` | `brew install php composer`; `composer require --dev phpunit/phpunit` |
| Docker daemon (for `--integration`) | start Docker Desktop / `colima start`; Testcontainers requires a reachable daemon (`docker info`) |
| Pact tooling (for `--contract`) | `npm i -D @pact-foundation/pact` / `go get github.com/pact-foundation/pact-go/v2` / Pact JVM plugin |

Never hard-fail on a missing tool — print the hint, skip that test type/stack, continue.

## Output Format

```markdown
## Generate Tests Report

**Target:** {path or working changes}
**Language(s):** {Node/TS | Go | Java/Kotlin | Python | Ruby | PHP | .NET}
**Framework:** {Vitest | Jest | go testing | pytest | JUnit 5 | RSpec | PHPUnit | xUnit} ({detected in-use | matrix default})
**Test types:** {unit | unit + integration (Testcontainers) | unit + contract (Pact/schema)}
**Coverage mode:** {broad | --coverage-gaps targeting N gaps}
**Log:** .context/logs/generate-tests-{timestamp}.log

### Tests Generated ({count})

| File | Cases | Coverage focus |
|------|-------|----------------|
| src/orders/order.service.test.ts | 9 | happy path, validation 4xx, BOLA 403, idempotent retry, tx rollback |
| ... | ... | ... |

### Registration
- {Files placed per convention | conftest.py added | TestMain Testcontainers lifecycle wired}
- Discovery check: {N tests now listed by vitest list / go test -list / pytest --collect-only}

### Verification Gate
| Step | Result | Notes |
|------|--------|-------|
| Compile (TS/Go/Java/C#) | ✅ / ❌ / N/A | {type errors, or clean} |
| Discover | ✅ / ❌ | {N new tests discovered} |
| Run | ✅ / ❌ | {N passed, M failed; containers up/down for --integration} |

**Gate:** PASS / FAIL ({failing step})

<!-- On gate failure only: -->
### Gate Failure
- **Stage:** {compile | discover | run}
- **Cause:** {one-line}
- **Routed to:** backend-developer:{agent}
- **Status:** {patch applied + re-run PASS | awaiting fix | real bug surfaced — see finding}

<!-- When a new test exposed a real bug: -->
### Findings (tests correct, code under test failing)
- {file:line} — {what the test proved is broken: e.g. wrong-tenant read returned 200, or pact drift} → fix routed to backend-developer:{language-agent}

<!-- On skipped languages/test types only: -->
### Skipped
- {language / --integration}: {missing tool or Docker daemon} — install hint printed above.
```

## Error Handling

### Path not found
```
Error: Path not found: {path}
Suggestion: Pass a file, package, or directory that exists, e.g. /backend-developer:generate-tests src/orders
```

### Framework conflict
```
Error: Two unit frameworks are wired in ({a} and {b}) — cannot pick a target.
Mixing frameworks fragments the suite and the runner config.
Suggestion: Consolidate on one framework first (out of scope for this command), then re-run.
```

### No framework, no language signal
```
Error: Could not resolve a language for {path} (no source extensions, manifests, or imports).
Suggestion: Point at the source file/module to test, or scope to a package with a manifest.
```

### --coverage-gaps with no runnable suite
```
Warning: --coverage-gaps needs an existing suite that already builds and runs to measure.
None found — falling back to broad generation. Run generate-tests once, then re-run
with --coverage-gaps to target the remaining gaps.
```

### --integration with no Docker daemon
```
Warning: --integration needs a reachable Docker daemon for Testcontainers.
`docker info` failed — skipping integration tests, generating unit tests only.
Start Docker (Docker Desktop / colima start) and re-run with --integration.
```

### Verification gate fails
Not silently ignored. The suite is reported FAIL with the failing step, the failure is routed back per "Gate Failure," and success is NOT reported until the suite builds, is discovered, and runs.

### Toolchain missing
Print the install hint from Tool Availability, skip that language/test type, continue. Only when *every* targeted language is skipped does the command report FAIL with the aggregated install hints.

## See Also

- `/backend-developer:build-test` — the detect/install/build/test logic the verification gate reuses; run it first to confirm the project builds before adding tests.
- `/backend-developer:security-scan` — run the new tests' suite alongside an OWASP API Top 10 scan once they are green; auth-boundary tests pair with the scan's BOLA/BFLA checks.
- `/backend-developer:code-review` — review the code before adding tests to it; `--coverage-gaps` pairs well after a review.
- `skill: testing-strategy` — test pyramid, framework matrix, coverage targets, AAA/naming, Testcontainers and contract-testing conventions.
- `skill: language-detection` — canonical marker → language → agent routing (keep the framework table in sync).
- `skill: _shared/version-feature-matrix.md` — canonical framework/runtime version → feature lookup and fallbacks.
