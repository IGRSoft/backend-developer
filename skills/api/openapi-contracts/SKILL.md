---
name: openapi-contracts
description: >-
  OpenAPI and AsyncAPI contracts as the single source of truth: spec authoring,
  client/server code generation (openapi-generator, oapi-codegen, buf), contract
  testing against a running implementation, and linting/style enforcement with
  spectral. Use when making a spec authoritative, generating SDKs or stubs,
  catching server/spec drift, or wiring contract checks into CI.
---

# OpenAPI & AsyncAPI Contracts

**The spec is the contract: authored first, linted, codegen'd, and tested against the running server**

## When to Use

Use this skill when:
- Making an OpenAPI (3.1) or AsyncAPI (3.0) document the source of truth
- Generating typed clients/servers from a spec (openapi-generator, oapi-codegen, buf)
- Catching drift between the spec and the deployed implementation (contract testing)
- Enforcing API style/consistency with linting (spectral)
- Wiring spec lint + breaking-change + contract checks into CI

This skill encodes the design from [rest-design](../rest-design/SKILL.md),
[graphql-design](../graphql-design/SKILL.md), and
[grpc-design](../grpc-design/SKILL.md) into a reviewable artifact, and is where
[api-versioning](../api-versioning/SKILL.md) gates live.

## Contract-First Workflow

```
author spec ──► lint (spectral) ──► review & merge ──► codegen client+server stubs
     ▲                                                          │
     └──────── contract test (spec ⇄ running server) ◄──────────┘
```

The spec file (`openapi.yaml` / `asyncapi.yaml` / `.proto`) is **reviewed and
merged before handlers exist**. Servers implement against generated interfaces;
clients consume generated SDKs; CI fails the build if the running server drifts
from the merged spec.

## Authoring OpenAPI 3.1

```yaml
openapi: 3.1.0
info: { title: Orders API, version: "2.0.0" }
paths:
  /orders/{id}:
    get:
      operationId: getOrder
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200":
          description: the order
          content:
            application/json:
              schema: { $ref: "#/components/schemas/Order" }
        "404":
          description: not found
          content:
            application/problem+json:                # RFC 9457 — part of the contract
              schema: { $ref: "#/components/schemas/Problem" }
components:
  schemas:
    Order:
      type: object
      required: [id, status, total]
      properties:
        id: { type: string }
        status: { type: string, enum: [PENDING, PAID, CANCELLED] }
        total: { type: integer, description: minor units }
```

- OpenAPI 3.1 aligns with **JSON Schema 2020-12** — reuse the same schemas for request validation and codegen.
- **Document error responses** (`application/problem+json`) as first-class, not just the happy path.
- Stable `operationId`s drive generated method names — treat them as part of the contract.

AsyncAPI 3.0 does the same for event/message surfaces (channels, operations,
messages) — use it for Kafka/RabbitMQ/SQS contracts and webhooks. See
[event-driven](../../architecture/event-driven/SKILL.md).

## Code Generation

| Tool | Input | Generates | Ecosystem |
|------|-------|-----------|-----------|
| `openapi-generator` | OpenAPI 3.x | clients + servers, many langs | polyglot |
| `oapi-codegen` | OpenAPI 3.x | Go server + client (stdlib/Echo/Gin/chi) | Go-native |
| `openapi-typescript` | OpenAPI 3.x | TS types (+ `openapi-fetch` client) | Node/TS |
| `buf generate` | `.proto` | gRPC stubs, many langs | proto |

```bash
# OpenAPI → typed clients/servers (single scoped command — no cd-chains)
npx openapi-generator-cli generate -i openapi.yaml -g typescript-axios -o src/gen

# Go server interfaces + models from the same spec
oapi-codegen -generate types,server -package api openapi.yaml > internal/api/api.gen.go

# Proto → gRPC stubs
buf generate
```

Generate into a dedicated `gen/` directory, keep it out of hand-edits, and
regenerate in CI so a spec change that isn't reflected in code fails the build.

## Contract Testing (Spec ⇄ Implementation)

Codegen guarantees the **types** match; contract testing guarantees the
**running server** matches. Two complementary approaches:

- **Spec-driven validation** — replay the spec's operations against a live server and assert responses validate against the documented schemas (`schemathesis`, `dredd`, Prism proxy in validation mode).
- **Consumer-driven contracts** — consumers publish expectations; providers verify them (Pact). Best across team/service boundaries.

```bash
# Property-based contract testing: generates requests from the spec, checks responses
uvx schemathesis run --base-url http://localhost:8080 openapi.yaml

# Or run the spec as a mock for consumers while the server is built
npx @stoplight/prism-cli mock openapi.yaml
```

This is where the **QA gate** evidence comes from: contract-test output + curl
transcripts, not screenshots — see
[workflow-integration](../../_shared/workflow-integration/SKILL.md) and
[be-testing](../../quality/be-testing/SKILL.md).

## Linting with Spectral

Enforce house style and catch foot-guns before review:

```yaml
# .spectral.yaml
extends: ["spectral:oas"]            # built-in OpenAPI ruleset
rules:
  operation-operationId: error       # every operation needs a stable id
  operation-tag-defined: error
  oas3-valid-media-example: warn
  no-$ref-siblings: error
  problem-json-on-errors:            # custom: 4xx/5xx must use problem+json
    given: "$.paths[*][*].responses[?(@property.match(/^[45]/))].content"
    then: { field: "application/problem+json", function: truthy }
```

```bash
spectral lint openapi.yaml           # single scoped command
buf lint                             # proto style + import rules
```

## Breaking-Change Gates

Tie [api-versioning](../api-versioning/SKILL.md) policy to CI so a wire-breaking
change can't merge unnoticed:

```bash
oasdiff breaking base.yaml revision.yaml   # OpenAPI breaking-change detection
buf breaking --against '.git#branch=main'  # proto breaking-change detection
```

A failure here means: make the change additive, or mint a new major version.

## Version Markers & Fallbacks

| Capability | Floor | Fallback when unavailable |
|------------|-------|---------------------------|
| OpenAPI + JSON Schema 2020-12 | OpenAPI 3.1 | 3.0.x with its bespoke schema subset |
| AsyncAPI event contracts | AsyncAPI 3.0 | 2.x (different channel model) |
| OpenAPI breaking-change CI | `oasdiff` | manual review of the spec diff |
| Proto lint + breaking | `buf` (current) | `protoc` + hand review |
| Property-based contract tests | `schemathesis` 3.x | `dredd`, or hand-written contract tests |

Confirm tool/spec support against the
[version-feature-matrix](../../_shared/version-feature-matrix.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Generated SDK doesn't match server responses | spec not authoritative; hand-edited code drifted | Regenerate in CI; server implements generated iface | this file, workflow |
| Codegen names churn between builds | unstable/missing `operationId` | Pin stable `operationId`s; lint for them | this file, spectral |
| Errors undocumented; clients guess shapes | only happy-path responses in spec | Document `4xx`/`5xx` + problem+json | this file, authoring |
| Spec passes lint but server returns wrong codes | no contract test against the runtime | Add schemathesis/Pact in CI | this file, contract testing |
| Breaking change merged unnoticed | no diff gate | `oasdiff`/`buf breaking` in CI | this file, breaking gates |
| Two teams disagree on payload shape | provider-only spec, no consumer contract | Consumer-driven contracts (Pact) | this file, contract testing |

## Related Skills

- [rest-design](../rest-design/SKILL.md) — the REST design this spec encodes
- [graphql-design](../graphql-design/SKILL.md) — SDL as its own typed contract
- [grpc-design](../grpc-design/SKILL.md) — proto + buf lint/breaking/codegen
- [api-versioning](../api-versioning/SKILL.md) — breaking-change policy the gates enforce
- [be-testing](../../quality/be-testing/SKILL.md) — contract + integration testing
- [api-security](../../quality/api-security/SKILL.md) — OWASP API9 (inventory) via published specs
- [event-driven](../../architecture/event-driven/SKILL.md) — AsyncAPI for message/event contracts
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — spec/tool floors
- [workflow-integration](../../_shared/workflow-integration/SKILL.md) — contract-test evidence in the QA gate
