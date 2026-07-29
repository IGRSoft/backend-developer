---
description: Select the best back-end architecture pattern for a service, feature, or platform
argument-hint: <feature, service, or platform scope> [--api] [--scope module|service|platform] [--stack node|go|jvm|python|ruby|php|dotnet]
allowed-tools: Read, Glob, Grep
model: opus
estimated-cost:
  min-tokens: 3000
  max-tokens: 18000
  model-distribution:
    haiku: 10%
    sonnet: 60%
    opus: 30%
---

# Architecture Selection
<!-- Updated: June 2026 -->

Choose the back-end architecture for a new service, feature, or platform slice. Captures the real constraints (runtime mix, deployment topology, data ownership, consistency requirement, transaction span, team and ops capacity), evaluates fit across the supported pattern menu, and returns one recommendation with a concrete module/service layout and explicit boundaries. Read-only and advisory — it writes analysis artifacts, never source.

[Extended thinking: Back-end architecture is not one choice, it is three orthogonal ones — a structural pattern (modular monolith, microservices, hexagonal, layered), a consistency model (strong vs eventual), and an integration model (in-process calls, pub/sub, saga orchestration, saga choreography). Teams routinely conflate them and end up with distributed services over a shared database, which buys every cost of microservices and none of the benefits. This command forces the axes apart, anchors each pick to a constraint the codebase or the user actually stated, and defaults to the smallest structure that still holds the invariants: a modular monolith with strong consistency until a boundary is proven. It also splits the question by owner — structure, data ownership, and consistency belong to `backend-developer:backend-architector`; the wire contract (REST vs GraphQL vs gRPC, versioning, error envelope, pagination) belongs to `backend-developer:api-designer`. Introducing a broker, a second datastore, or an event-sourcing framework is a real operational bill; the recommendation must name that bill rather than assume the team will absorb it.]

## CRITICAL BEHAVIORAL RULES

You MUST follow these rules exactly. Violating any of them is a failure.

1. **Capture constraints before recommending.** Run the Constraint Capture pass first and write `.context/arch-constraints.json`. Do NOT name a pattern before the constraints exist. If a decision-critical constraint (transaction span, data ownership, consistency requirement, deployment topology) cannot be inferred from the codebase or the argument, ASK the user — do not guess.
2. **Read-only.** This command and every agent it launches analyze and advise. They may write analysis artifacts under `.context/`, and nothing else. No source file, manifest, migration, schema, or proto is created or edited here. Scaffolding is a separate, explicitly-requested follow-up.
3. **Separate the three axes.** Always report a structural pattern, a consistency model, and an integration/messaging model as three distinct picks with their own justification. Do NOT collapse them into one label.
4. **Smallest viable structure wins.** Default to a modular monolith with a single transactional store and strong consistency. Recommend microservices, a message broker, per-service datastores, CQRS, event sourcing, or a saga only when a stated constraint forces it, and state the operational cost each one adds.
5. **Route API-shape questions to the API designer.** When the argument concerns protocol choice (REST vs GraphQL vs gRPC vs WebSocket/streaming), contract shape, versioning, pagination, or error envelope — or when `--api` is set — additionally delegate to `backend-developer:api-designer`. Structure questions stay with `backend-developer:backend-architector`. Never let the architector invent the wire contract when the question IS the wire contract.
6. **Validate, do not rubber-stamp.** If the user named a pattern, report `fit` or `mismatch` against the captured constraints with 1-2 concrete reasons, and name the closest-fit alternative on `mismatch`. Agreeing with a stated preference that the constraints contradict is a failure.
7. **Name version and operational markers.** Every recommendation states its runtime/framework floor (per `skills/_shared/version-feature-matrix.md`) and what it adds to the operating surface — a broker, a second store, a scheduler, a new deploy unit — with a fallback if the floor is not met.
8. **Never enter plan mode.** This command IS the procedure — execute it.

## Usage

```bash
# Pick the architecture for a new service
/backend-developer:arch-select "order fulfillment service with inventory reservation"

# Scope the decision to a module inside an existing codebase
/backend-developer:arch-select "billing module" --scope module

# Platform-wide decomposition question
/backend-developer:arch-select "split the monolith so checkout can scale independently" --scope platform

# Validate a pattern the team already picked
/backend-developer:arch-select "should notifications be event-driven with an outbox?"

# API shape is the question — routes to api-designer as well
/backend-developer:arch-select "public partner API for the catalog" --api

# Force the stack when detection is ambiguous (polyglot monorepo)
/backend-developer:arch-select "reporting read model" --stack go
```

## Options

| Option | Default | Effect |
|--------|---------|--------|
| `scope argument` | required | Free-text description of the feature, service, or platform slice, or a path to analyze. Without it, the command asks. |
| `--api` | auto | Force the API-contract pass. Auto-enabled when the argument mentions REST/GraphQL/gRPC/WebSocket, a contract, versioning, pagination, or an error envelope. |
| `--scope module\|service\|platform` | inferred | Decision blast radius. `module` = inside one deployable; `service` = one new/changed deployable; `platform` = boundaries across several owners. Drives Quick Recommendation vs Deep Refactor mode. |
| `--stack node\|go\|jvm\|python\|ruby\|php\|dotnet` | auto | Force the runtime instead of detecting it via `skill: language-detection`. Use in polyglot monorepos. |

## Pre-flight

1. Check session state: does `.context/arch-select-state.json` exist? If yes, resume from the last completed step rather than restarting.
2. Otherwise create `.context/` and initialize `arch-select-state.json` with the argument, flags, and an empty step log.

## Step 1: Constraint Capture

Gather each constraint from the argument first, then the codebase. Record where each value came from (`stated` / `detected` / `asked` / `assumed`).

| Constraint | How to determine |
|-----------|-----------------|
| **Runtime mix** | Manifest markers via `skill: language-detection` — `package.json` + `tsconfig.json` → Node/TS; `go.mod` → Go; `pom.xml`/`build.gradle` → JVM; `pyproject.toml` → Python web; `Gemfile` → Ruby; `composer.json` → PHP; `*.csproj` → .NET. `--stack` overrides. |
| **Deployment topology** | Count real deploy units: `Dockerfile`s, `docker-compose.yml` services, k8s manifests/Helm charts, CI deploy jobs. One unit vs many changes the answer more than anything else. |
| **Data ownership** | Migration directories, connection strings/env names, ORM configs. One store shared by everything, one store per service, or a mix? Two services writing the same table is the single strongest signal against decomposition. |
| **Consistency requirement** | Which invariants must hold at commit time (balances, stock reservation, uniqueness) vs which tolerate lag (search index, analytics, notifications, denormalized views). |
| **Transaction span** | Does one use case write to more than one store or more than one owner? A genuine cross-owner write is the only thing that justifies a saga. |
| **Read/write asymmetry** | Read:write ratio and hot paths. Heavy asymmetry plus audit/temporal needs is the CQRS / event-sourcing trigger. |
| **Messaging tolerance** | Is a broker already present (Kafka, RabbitMQ, SQS/SNS, NATS, Redis Streams) in compose files, infra manifests, or dependencies? Adding the first broker is a large step; using an existing one is small. |
| **Latency & scale targets** | p95/p99 budget, expected RPS, whether any component must scale independently of the rest. "Team autonomy" alone is not a scaling constraint. |
| **API surface & clients** | Who consumes it — browser, mobile, internal services, third parties — and whether a committed OpenAPI/proto/SDL already exists (`openapi.*`, `*.proto`, `schema.graphql`). |
| **Team & ops capacity** | Number of owning teams, on-call maturity, existing observability (OpenTelemetry, dashboards). Microservices without tracing and per-service on-call is a liability. |
| **Existing conventions** | Detected structure in the codebase — layering, ports/adapters, outbox tables, existing consumers. A working convention beats a theoretically better one. |

If a decision-critical constraint is missing (deployment topology, data ownership, consistency requirement, transaction span), ask the user before proceeding. Do not assume.

Write: `.context/arch-constraints.json` — every constraint with its value and provenance.

## Pattern Menu

The recommendation combines one pick from each axis. Anchors are this plugin's skills.

**Axis 1 — structure**

| Pattern | Best for | Anchor |
|---------|----------|--------|
| Modular monolith | Default for new back-ends; one deployable, in-process module boundaries, one transactional store | `skill: microservices-patterns` |
| Layered / clean | Controllers → services → repositories, acyclic deps; default *inside* a service | `skill: microservices-patterns` |
| Hexagonal / ports-adapters | Isolating DB, broker, and external-API I/O behind interfaces for testability and swap-ability | `skill: microservices-patterns` |
| Microservices | Independent scale/deploy, per-service data ownership — only when a boundary is proven | `skill: microservices-patterns` |
| API gateway / BFF | Edge aggregation, auth termination, per-client response shaping over several services | `skill: api-skills` |

**Axis 2 — consistency and transaction boundary**

| Model | Best for | Anchor |
|-------|----------|--------|
| Strong (single-store transactions) | Invariants that must hold synchronously; row locks, `SERIALIZABLE`, one commit | `skill: orm-patterns` |
| Eventual (idempotent consumers) | Cross-service or replicated state; dedup keys, reconciliation jobs, retry-tolerant handlers | `skill: caching-strategies` |
| Read-model projection (CQRS) | Heavy read/write asymmetry; write model plus projected read models | `skill: cqrs-event-sourcing` |
| Event sourcing | Audit/temporal requirements, replay and rebuild; append-only event store as the source of truth | `skill: cqrs-event-sourcing` |

**Axis 3 — integration and messaging**

| Model | Best for | Anchor |
|-------|----------|--------|
| In-process calls | Inside one deployable; the default until a boundary is proven | `skill: microservices-patterns` |
| Synchronous RPC/HTTP | Request-scoped cross-service reads where the caller must block on a fresh answer | `skill: api-skills` |
| Pub/sub with a transactional outbox | Async fan-out and integration; at-least-once delivery without dual-write loss | `skill: event-driven` |
| Saga (orchestration) | Multi-service writes with a central coordinator issuing steps and compensations | `skill: saga-orchestration` |
| Saga (choreography) | Multi-service writes via reactive event chains, no coordinator, per-step compensation | `skill: event-driven` |

Store-selection questions (relational vs document vs key-value vs search, indexing, partitioning) anchor to `skill: schema-design`; delivery guarantees and dedup anchor to `skill: event-driven`.

## Step 2: Structural Selection

**Use Task tool with subagent_type="backend-developer:backend-architector"**

Prompt: "Select the back-end architecture for this scope: {argument}. Mode: {Quick Recommendation for module/service scope with clear constraints | Deep Refactor for platform scope, decomposition, or a service-boundary change}. Captured constraints (with provenance): {constraints from Step 1}. Runtime mix: {stacks}. Report three separate picks: (1) structural pattern, (2) consistency model and transaction boundary, (3) integration/messaging model — each with 1-2 constraint-anchored reasons. Apply your Guardrails: prefer the smallest structure that holds the invariants; default to a modular monolith with a single transactional store and strong consistency until a boundary is proven; do NOT introduce a broker, a second datastore, an event-sourcing framework, or a new deploy unit unless a stated constraint forces it — and if you do, name the operational cost it adds. If the user named a pattern, return `fit` or `mismatch` with reasons and the closest-fit alternative on mismatch. State the runtime/framework version floor per `skills/_shared/version-feature-matrix.md` with a fallback. Do NOT write or edit any source file."

Write: `.context/arch-selection.json` — the three picks, fit result, reasons, alternatives, operational cost, version floors.

## Step 3: API Contract Selection (conditional)

Run this step when `--api` is set, when the argument concerns protocol/contract/versioning/pagination/error shape, or when Step 2's recommendation puts a new contract on a cross-owner boundary.

**Use Task tool with subagent_type="backend-developer:api-designer"**

Prompt: "Select the API shape for this scope: {argument}. Structural context from architecture selection: {structural pattern, integration model, consistency model}. Clients and consumers: {from constraints}. Existing committed contracts: {openapi/proto/graphql files found, or none}. Recommend: (1) protocol — REST vs GraphQL vs gRPC vs WebSocket/streaming — using the protocol-selection table in `skill: api-skills`, with the trade-off that decides it; (2) contract source of truth and where it lives (`skill: openapi-contracts` for REST, `skill: graphql-design` for SDL, `skill: grpc-design` for proto); (3) versioning and deprecation strategy per `skill: api-versioning`; (4) resource/operation model, pagination, filtering, and error-envelope shape per `skill: rest-design`; (5) idempotency strategy for mutating operations (idempotency key or natural dedup key). Flag any change that would break existing clients and state the deprecation window it needs. Do NOT write or edit any source file or spec."

Write: `.context/arch-api-selection.json` — protocol, contract home, versioning strategy, error/pagination conventions, idempotency approach, break risk.

## Step 4: Structure Blueprint

**Use Task tool with subagent_type="backend-developer:backend-architector"**

Prompt: "For the selected architecture — structure: {pattern}; consistency: {model}; integration: {model} — produce a concrete layout for: {argument}. Runtime: {stack/framework}. Include: module/package/service directory tree with real names from this project's domain (not placeholders); the public contract surface of each boundary; ports/interfaces and their adapter implementations; where transactions open and commit; datastore ownership per module/service; where idempotency keys and dedup live; the async/consumer entry points if messaging is in play; configuration and dependency-injection seams; and the test seams that make each boundary testable in isolation. Match the conventions already present in this codebase. Do NOT create any file."

## Step 5: Output

Write the final report to `.context/arch-selection.md` and present the summary.

### Selection Report Format

```markdown
## Architecture Selection: {Scope Name}

**Scope:** {module | service | platform}
**Runtime(s):** {stacks detected/forced}
**Mode:** {Quick Recommendation | Deep Refactor}

### Recommendation
| Axis | Pick | Why |
|------|------|-----|
| Structure | {pattern} | {1-2 constraint-anchored reasons} |
| Consistency | {strong / eventual / CQRS / event-sourced} | {reason} |
| Integration | {in-process / RPC / pub-sub+outbox / saga} | {reason} |

- **Fit:** {fit | mismatch — only when the user named a pattern}
- **Alternative:** {closest fit and the trade-off, when mismatch}
- **Operational cost added:** {new deploy units, broker, datastore, scheduler — or "none"}

### Constraints Summary
| Factor | Value | Source |
|--------|-------|--------|
| Deployment topology | {n deploy units} | {stated/detected/asked} |
| Data ownership | {shared store / per-service / mixed} | {…} |
| Consistency requirement | {invariants that must hold synchronously} | {…} |
| Transaction span | {single store / cross-owner} | {…} |
| Read/write asymmetry | {ratio or n/a} | {…} |
| Messaging in place | {broker or none} | {…} |
| Team & ops capacity | {teams, observability maturity} | {…} |

### API Contract
<!-- Only when Step 3 ran -->
- **Protocol:** {REST | GraphQL | gRPC | WebSocket} — {deciding trade-off}
- **Contract source of truth:** {path and format}
- **Versioning:** {strategy and deprecation window}
- **Pagination / errors:** {conventions}
- **Idempotency:** {key strategy for mutating operations}
- **Break risk:** {existing clients affected, or "none"}

### Structure
{directory tree with real module/service/package names}

### Key Boundaries
- **Public contract surface:** {endpoints, events, RPC methods}
- **Ports and adapters:** {interfaces and their implementations}
- **Transaction boundaries:** {where a transaction opens and commits}
- **Data ownership:** {which module/service owns which store or table group}
- **Idempotency & dedup:** {keys, tables, consumer semantics}
- **Auth boundary:** {where authn/authz is enforced}

### Version & Portability Markers
| Requirement | Floor | Fallback if unmet |
|-------------|-------|-------------------|
| {runtime/framework feature} | {version} | {alternative} |

### Testing Strategy
- {what each boundary needs — unit at the port, integration at the adapter}
- {how to stub dependencies and fake the broker/store}
- {contract tests for the published API/event schema}

### Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| {risk} | {consequence} | {mitigation} |

### Next Steps
1. {first implementation step}
2. {second step}
3. {third step}
```

Present the summary and offer the follow-ups: scaffold the contract with `/backend-developer:gen-api`, design the schema with `/backend-developer:db-migrate`, or review an existing codebase against this pick with `/backend-developer:arch-review`.

## Error Handling

### No scope argument
```
Error: arch-select needs a scope to decide on.
Suggestion: /backend-developer:arch-select "order fulfillment service with inventory reservation"
```

### Decision-critical constraint missing
```
Note: Cannot select an architecture without {constraint}.
Missing: {deployment topology | data ownership | consistency requirement | transaction span}
Question: {the specific question to answer}
```
Stop and ask. Do not assume a value for these four — every one of them can flip the recommendation.

### No back-end codebase detected (greenfield)
Not an error. Greenfield is the normal case for this command: skip codebase-derived constraints, mark them `stated`/`asked`, note "greenfield — no existing conventions to preserve" in the report, and continue.

### Ambiguous stack (polyglot monorepo)
Apply the `skill: language-detection` tie-break rules. If still ambiguous, ask which service the decision is for, or accept `--stack`. Do not average across runtimes — version floors and framework idioms differ per stack.

### User-named pattern contradicts the constraints
Not an error. Report `mismatch` with the specific contradicting constraints, name the closest-fit alternative, and state what would have to change for the named pattern to become correct. Do not silently accept it.

### API question with no structural question
When the argument is purely about contract shape, run Step 3 and report the API block only. Note in the report that no structural change was requested, and skip Step 4.

## Related Commands

- `/backend-developer:arch-review` — review an existing codebase against the pattern this command selected.
- `/backend-developer:gen-api` — scaffold the contract and handlers once the protocol and shape are settled.
- `/backend-developer:db-migrate` — design and apply the schema and migrations for the chosen data ownership model.
- `/backend-developer:fix-refactor` — move existing code onto the selected structure.
- `/backend-developer:develop-feature` — end-to-end feature build that starts from this decision.
- `/backend-developer:review-code` — review the implementation once it lands.
- `/backend-developer:build-test` — the build gate; confirm the structure still builds and tests green.
- `skill: architecture-skills` — architecture navigation entry point (`skills/architecture/SKILL.md`).
- `skill: microservices-patterns`, `skill: event-driven`, `skill: cqrs-event-sourcing`, `skill: saga-orchestration` — the structural, messaging, and consistency playbooks.
- `skill: api-skills`, `skill: rest-design`, `skill: graphql-design`, `skill: grpc-design`, `skill: api-versioning`, `skill: openapi-contracts` — contract-side anchors for Step 3.
- `skill: schema-design` — store selection, indexing, and ownership modeling.
- `skills/_shared/version-feature-matrix.md` — runtime/framework version → feature lookup for the version markers.
- `skill: language-detection` — canonical marker → runtime → agent routing.
