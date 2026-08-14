---
name: api-skills
description: >-
  API design skills navigation — REST, GraphQL, gRPC, versioning, and
  OpenAPI/AsyncAPI contracts. Use when designing or reviewing API contracts,
  schemas, or versioning; choosing a protocol (REST vs GraphQL vs gRPC);
  modeling resources, errors, and pagination; or routing a "how should this
  endpoint behave", "breaking change", or "contract drift" question to the
  right guide.
---

# API Skills

**Protocol selection, contract design, and versioning for web/service back-ends**

Thin router. Pick a sub-skill from the tables below; the leaf skills teach.

## Skill Selection

| I need to... | Use this skill |
|--------------|----------------|
| Model resources, status codes, pagination, idempotency, problem+json errors | [rest-design/SKILL.md](rest-design/SKILL.md) |
| Author a GraphQL schema, kill N+1 with DataLoader, page with connections | [graphql-design/SKILL.md](graphql-design/SKILL.md) |
| Define proto3 services, streaming, deadlines, a status error model | [grpc-design/SKILL.md](grpc-design/SKILL.md) |
| Pick a versioning scheme and write a deprecation policy | [api-versioning/SKILL.md](api-versioning/SKILL.md) |
| Make the spec the source of truth: codegen, lint, contract tests | [openapi-contracts/SKILL.md](openapi-contracts/SKILL.md) |

## Protocol Router

Start here when you have a constraint, not a protocol name.

| Constraint | Likely fit | Go to |
|------------|------------|-------|
| Public/partner API, browser clients, cacheable reads | REST + OpenAPI | [rest-design](rest-design/SKILL.md) |
| Many client-shaped views, over/under-fetching pain, mobile | GraphQL | [graphql-design](graphql-design/SKILL.md) |
| Internal service-to-service, low latency, streaming, polyglot | gRPC + proto3 | [grpc-design](grpc-design/SKILL.md) |
| Event/webhook surface, async producers/consumers | AsyncAPI | [openapi-contracts](openapi-contracts/SKILL.md) > AsyncAPI |
| Existing API must change without breaking callers | (any) + versioning | [api-versioning](api-versioning/SKILL.md) |
| Generated clients/servers must stay in sync with the contract | spec-first | [openapi-contracts](openapi-contracts/SKILL.md) |

## Symptom Router

Start here when you have a behavior, not a tool name.

| Symptom | Likely cause | Go to |
|---------|--------------|-------|
| Client got `200` with an error body, or `500` for a validation fault | status-code/error-model drift | [rest-design](rest-design/SKILL.md) > status codes + RFC 9457 |
| Duplicate side effects on retry (double charge, double order) | no idempotency key | [rest-design](rest-design/SKILL.md) > idempotency |
| List endpoint slows/skips rows as data grows | offset pagination on a mutating set | [rest-design](rest-design/SKILL.md) > cursor pagination |
| GraphQL request fans out to thousands of DB calls | resolver N+1 without batching | [graphql-design](graphql-design/SKILL.md) > DataLoader |
| Untrusted query exhausts the server | no depth/complexity limit | [graphql-design](graphql-design/SKILL.md) > limits · [api-security](../quality/api-security/SKILL.md) |
| gRPC call hangs forever | no deadline propagated | [grpc-design](grpc-design/SKILL.md) > deadlines |
| Adding a proto field broke old clients | wire-incompatible change | [grpc-design](grpc-design/SKILL.md) > proto evolution |
| Mobile app pinned to v1 breaks on deploy | uncoordinated breaking change | [api-versioning](api-versioning/SKILL.md) |
| Generated SDK doesn't match the running server | spec is not the source of truth | [openapi-contracts](openapi-contracts/SKILL.md) > contract testing |

## Spec & Tooling Version Snapshot (verify against your toolchain)

Floors this plugin assumes. Spec revisions and generators shift between releases — confirm with `--version` and the [version-feature-matrix](../_shared/version-feature-matrix.md) before pinning in CI.

| Spec / Tool | Assumed floor | Why |
|-------------|---------------|-----|
| OpenAPI | 3.1.x baseline; 3.2.0 (GA Sep 2025) where tooling supports it | JSON Schema 2020-12 alignment, `webhooks`; 3.2 is strictly additive over 3.1 (structured tags, streaming media types, new OAuth flows) — 3.1 descriptions stay valid |
| AsyncAPI | 3.x (3.1.0 current) | event/message contracts, channel/operation split; 3.1 is a non-breaking minor over 3.0 |
| JSON Schema | 2020-12 | `$dynamicRef`, unevaluated keywords; the dialect OpenAPI 3.1/3.2 aligns to |
| Protocol Buffers | proto3 baseline; editions (2023, 2024 latest) where supported | optional/oneof semantics; editions replace `syntax=` with feature flags — Edition 2024 ships in protoc 32.x+ |
| RFC 9457 | current | `application/problem+json` (Standards Track, obsoletes RFC 7807) |
| GraphQL spec | September 2025 edition | first ratified edition since Oct 2021; `@oneOf` input objects + schema coordinates now in-spec; `@defer`/`@stream` still draft (Stage 2) *(verify)* |
| openapi-generator | 7.x | multi-language client/server codegen |
| oapi-codegen | 2.x | Go-native server/client from OpenAPI |
| buf | current stable (v1.x) | proto lint, breaking-change detection, codegen |
| spectral | 6.x | OpenAPI/AsyncAPI linting & style rules |

## Decision Tree

```
API task?
├── "Design an HTTP/JSON resource API" → rest-design/SKILL.md
│   ├── resource modeling, Richardson maturity → rest-design/SKILL.md
│   ├── pagination (cursor vs offset) → rest-design/SKILL.md > pagination
│   ├── errors (RFC 9457 problem+json) → rest-design/SKILL.md > errors
│   └── idempotency, caching headers, HATEOAS → rest-design/references/rest-semantics.md
├── "Design a GraphQL schema" → graphql-design/SKILL.md
│   ├── schema-first SDL, resolvers → graphql-design/SKILL.md
│   ├── N+1 / DataLoader, Relay connections → graphql-design/SKILL.md
│   └── persisted queries, depth/complexity → graphql-design/references/graphql-security.md
├── "Design a gRPC service" → grpc-design/SKILL.md
│   ├── proto3 messages/services, streaming → grpc-design/SKILL.md
│   └── deadlines, status model, interceptors → grpc-design/SKILL.md
├── "Change an API without breaking callers" → api-versioning/SKILL.md
└── "Make the contract the source of truth" → openapi-contracts/SKILL.md
    ├── authoring + linting (spectral) → openapi-contracts/SKILL.md
    └── codegen + contract testing → openapi-contracts/SKILL.md
```

## Conventions Across API Design

- **Contract first, code second.** The OpenAPI/AsyncAPI/proto file is reviewed and merged before handlers exist; servers and clients are generated or validated against it.
- **Errors are part of the contract.** REST returns `application/problem+json` (RFC 9457); gRPC uses canonical status codes + `google.rpc.Status`; GraphQL uses typed errors in the `errors` array. Never overload `200` with an embedded failure.
- **Authorization is per-object, not per-route only.** Object-level checks (OWASP API1/API3) live in the handler, not just the gateway — see [api-security](../quality/api-security/SKILL.md).
- **Single-command Bash invocations.** Use `buf lint`, `spectral lint openapi.yaml`, `npx openapi-generator-cli generate ...` — never `cd`-chains. Scoped Bash allowlists do not match compound commands.
- **Evidence is transcripts, not screenshots.** Non-UI API work defaults to `requires_screenshots: false`; cli-fallback evidence = curl/httpie request/response transcripts, contract-test output, and k6 load reports — see [CORPFLOW.md](../../CORPFLOW.md).

## Related Skills

- [rest-design](rest-design/SKILL.md) — resources, status codes, pagination, RFC 9457, idempotency, caching
- [graphql-design](graphql-design/SKILL.md) — schema-first SDL, DataLoader, connections, depth/complexity limits
- [grpc-design](grpc-design/SKILL.md) — proto3, streaming, deadlines, status model, interceptors
- [api-versioning](api-versioning/SKILL.md) — URL/header/media-type schemes, semver, deprecation, compatibility
- [openapi-contracts](openapi-contracts/SKILL.md) — spec as source of truth, codegen, contract testing, linting
- [api-security](../quality/api-security/SKILL.md) — OWASP API Top 10 controls layered onto the contract
- [be-testing](../quality/be-testing/SKILL.md) — contract + integration testing of the designed API
- [secure-coding](../_shared/secure-coding/SKILL.md) — injection-safe handlers, secrets hygiene, auth boundaries
- [version-feature-matrix](../_shared/version-feature-matrix.md) — spec/tool/runtime floors
- [CORPFLOW.md](../../CORPFLOW.md) — API Evidence and the cli-fallback transcript norm
