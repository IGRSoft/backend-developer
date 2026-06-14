# API Index

Quick navigation for REST, GraphQL, gRPC, versioning, and contract tooling.

## Skills

| Path | Description |
|------|-------------|
| `SKILL.md` | Entry router: skill selection, protocol router, symptom router, version snapshot, decision tree |
| `rest-design/SKILL.md` | Resource modeling, Richardson maturity, status codes, cursor vs offset pagination, RFC 9457 errors, idempotency keys, HATEOAS, caching headers |
| `rest-design/references/rest-semantics.md` | HTTP semantics deep dive: conditional requests/ETags, idempotency-key storage, HATEOAS link patterns, content negotiation |
| `graphql-design/SKILL.md` | Schema-first SDL, query/mutation/subscription, N+1 + DataLoader, Relay connection pagination, error handling |
| `graphql-design/references/graphql-security.md` | Persisted queries, depth/complexity limiting, introspection control, authorization in resolvers |
| `grpc-design/SKILL.md` | proto3 messages/services, unary/streaming, deadlines/cancellation, status error model, interceptors, backward-compatible proto evolution |
| `api-versioning/SKILL.md` | URL vs header vs media-type versioning, semver for APIs, deprecation policy, backward/forward compatibility, contract evolution |
| `openapi-contracts/SKILL.md` | OpenAPI/AsyncAPI as source of truth, spec authoring, codegen (openapi-generator/oapi-codegen/buf), contract testing, spectral linting |

## Quick Links by Problem

### "I need to..."

- **Model a REST resource and pick status codes** → `rest-design/SKILL.md`
- **Page a large list safely** → `rest-design/SKILL.md` (cursor pagination)
- **Return structured errors** → `rest-design/SKILL.md` (RFC 9457 problem+json)
- **Kill GraphQL N+1** → `graphql-design/SKILL.md` (DataLoader)
- **Define a gRPC streaming RPC** → `grpc-design/SKILL.md`
- **Ship a breaking change safely** → `api-versioning/SKILL.md`
- **Generate clients from the spec** → `openapi-contracts/SKILL.md`

### "I'm getting..."

- **Duplicate side effects on client retry** → `rest-design/SKILL.md` (idempotency keys)
- **A GraphQL query that overloads the DB** → `graphql-design/references/graphql-security.md` (depth/complexity)
- **A gRPC call that never times out** → `grpc-design/SKILL.md` (deadlines)
- **Old clients broken by a proto change** → `grpc-design/SKILL.md` (proto evolution)
- **A generated SDK that drifts from the server** → `openapi-contracts/SKILL.md` (contract testing)
