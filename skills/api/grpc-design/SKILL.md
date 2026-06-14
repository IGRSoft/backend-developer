---
name: grpc-design
description: >-
  gRPC API design: proto3 message/service modeling, unary and
  server/client/bidirectional streaming, deadline propagation and
  cancellation, the canonical status-code error model, interceptors, and
  backward-compatible proto evolution. Use when defining .proto contracts,
  choosing a streaming mode, propagating deadlines, shaping rich errors, or
  changing a proto without breaking deployed clients.
---

# gRPC Design

**proto3 contracts, streaming modes, deadlines, and wire-compatible evolution for internal service-to-service APIs**

## When to Use

Use this skill when:
- Defining `.proto` messages and services for internal/polyglot RPC
- Choosing among unary, server-streaming, client-streaming, bidi streaming
- Propagating deadlines and handling cancellation across a call chain
- Returning rich, machine-readable errors (canonical codes + `google.rpc.Status`)
- Adding cross-cutting behavior via interceptors (auth, logging, tracing, retries)
- Changing a proto without breaking already-deployed clients

gRPC fits **internal service-to-service, low-latency, streaming, polyglot**
surfaces. For browser/public APIs prefer [rest-design](../rest-design/SKILL.md)
or [graphql-design](../graphql-design/SKILL.md) (or gRPC-Web behind a proxy).

## proto3 Messages & Services

```proto
syntax = "proto3";
package orders.v1;                       // version in the package — see evolution

import "google/protobuf/timestamp.proto";

service OrderService {
  rpc GetOrder      (GetOrderRequest)      returns (Order);
  rpc ListOrders    (ListOrdersRequest)    returns (ListOrdersResponse);
  rpc WatchOrders   (WatchOrdersRequest)   returns (stream OrderEvent);   // server stream
  rpc ImportOrders  (stream OrderRecord)   returns (ImportSummary);       // client stream
  rpc Sync          (stream SyncMsg)       returns (stream SyncMsg);      // bidi
}

message Order {
  string id = 1;
  Status status = 2;
  Money total = 3;
  google.protobuf.Timestamp created_at = 4;
  reserved 5, 6;                         // tombstone removed fields — never reuse
  reserved "legacy_code";
}

enum Status {
  STATUS_UNSPECIFIED = 0;                // 0 must be the safe/unknown default
  STATUS_PENDING = 1;
  STATUS_PAID = 2;
}
```

Conventions:
- **Field numbers are the contract**, not field names — numbers travel on the wire. Never renumber; never reuse a retired number (use `reserved`).
- Every enum's `0` value is `*_UNSPECIFIED` — proto3 can't tell "absent" from "default", so 0 must be the safe fallback.
- Wrap list responses in a message (`ListOrdersResponse { repeated Order orders; string next_page_token; }`) so you can add fields later.

## Streaming Modes

| Mode | Signature | Use for |
|------|-----------|---------|
| Unary | `(Req) returns (Resp)` | normal request/response |
| Server streaming | `(Req) returns (stream Resp)` | feeds, tail-a-log, large result sets |
| Client streaming | `(stream Req) returns (Resp)` | uploads, bulk ingest with one summary |
| Bidirectional | `(stream Req) returns (stream Resp)` | chat, sync, interactive sessions |

Stream when the payload is naturally a sequence or unbounded; otherwise stay
unary — streams add lifecycle/cancellation complexity.

## Deadlines & Cancellation

Every call should carry a deadline; servers must honor cancellation and
**propagate** the remaining budget downstream. A call with no deadline can hang
forever and exhaust a connection pool (OWASP API4).

```go
// Client: set a deadline, not an open-ended call
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel()
resp, err := client.GetOrder(ctx, &pb.GetOrderRequest{Id: id})
```

```go
// Server: respect cancellation; pass ctx down to DB / downstream RPCs
func (s *server) GetOrder(ctx context.Context, req *pb.GetOrderRequest) (*pb.Order, error) {
    if err := ctx.Err(); err != nil {        // already cancelled / deadline exceeded
        return nil, status.FromContextError(err).Err()
    }
    return s.repo.Get(ctx, req.GetId())      // ctx carries the remaining deadline
}
```

Deadlines are **absolute** and propagate through the chain — a downstream call inherits the remaining time, not a fresh timeout.

## Status Codes & Error Model

gRPC has 17 canonical status codes. Map domain failures onto them; add detail
via `google.rpc.Status` detail messages.

| Code | When |
|------|------|
| `INVALID_ARGUMENT` | client sent a bad field (validation) |
| `NOT_FOUND` | resource absent |
| `ALREADY_EXISTS` | create conflict |
| `PERMISSION_DENIED` | authenticated but not allowed (API5/API1) |
| `UNAUTHENTICATED` | missing/invalid credentials (API2) |
| `RESOURCE_EXHAUSTED` | rate/quota limit (API4) |
| `FAILED_PRECONDITION` | state not valid for the call |
| `DEADLINE_EXCEEDED` | call ran past its deadline |
| `UNAVAILABLE` | transient; client may retry with backoff |

```go
st := status.New(codes.InvalidArgument, "amount must be positive")
st, _ = st.WithDetails(&errdetails.BadRequest{FieldViolations: []*errdetails.BadRequest_FieldViolation{
    {Field: "amount", Description: "must be > 0"},
}})
return nil, st.Err()
```

Don't put internal exception text or stack traces in the message (OWASP API8) —
see [secure-coding](../../_shared/secure-coding/SKILL.md).

## Interceptors

Cross-cutting concerns belong in interceptors, not every handler:

```go
func AuthUnaryInterceptor(next grpc.UnaryHandler) grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req any, info *grpc.UnaryServerInfo,
        handler grpc.UnaryHandler) (any, error) {
        if err := verifyToken(ctx); err != nil {       // OWASP API2
            return nil, status.Error(codes.Unauthenticated, "invalid token")
        }
        return handler(ctx, req)
    }
}
```

Standard chain: tracing (OpenTelemetry) → auth → rate limit → logging →
recovery. See [observability](../../tooling/observability/SKILL.md).

## Backward-Compatible Proto Evolution

Safe (wire-compatible):
- **Add** new fields with new numbers, new RPCs, new enum values.
- Add fields to request/response messages — old clients ignore unknown fields.

Breaking (never on a live contract):
- Renumber or reuse a field number; change a field's type.
- Remove a field/RPC without `reserved`; rename a field if using JSON mapping.
- Change cardinality (`repeated` ↔ singular) or move fields in/out of `oneof`.

For genuinely incompatible changes, **bump the package version**
(`orders.v1` → `orders.v2`) and run both servers during migration — the proto
equivalent of API versioning ([api-versioning](../api-versioning/SKILL.md)).
Enforce these rules in CI with `buf breaking`.

## Version Markers & Fallbacks

| Capability | Floor | Fallback when unavailable |
|------------|-------|---------------------------|
| Breaking-change detection | `buf breaking` (current v1.x) | manual review against the merged proto |
| Proto editions | editions 2023 / 2024 (Edition 2024 ships in protoc 32.x+) | stick to proto3 syntax |
| gRPC for browsers | gRPC-Web + Envoy/proxy, or Connect | expose a REST/JSON gateway |
| Rich error details | `google.rpc.Status` + `errdetails` | status code + plain message |

Confirm toolchain support against the
[version-feature-matrix](../../_shared/version-feature-matrix.md).

## Diagnostics

| Symptom | Cause | Fix | Reference |
|---------|-------|-----|-----------|
| Call hangs indefinitely | no deadline set/propagated | `context.WithTimeout`; pass ctx down | this file, deadlines |
| Old client misreads new responses | reused/renumbered field number | Never reuse numbers; `reserved` retired ones | this file, evolution |
| Enum value silently becomes 0 | added value, old client unaware | `0 = *_UNSPECIFIED`; treat unknown as default | this file, proto3 |
| Every handler reimplements auth/log | no interceptor layer | Centralize in interceptors | this file, interceptors |
| Generic `UNKNOWN` errors everywhere | domain errors not mapped | Map to canonical codes + details | this file, status model |
| `buf breaking` fails in CI | wire-incompatible proto change | Bump package version or revert | this file, evolution |

## Related Skills

- [rest-design](../rest-design/SKILL.md) — when a public/cacheable HTTP API fits better
- [graphql-design](../graphql-design/SKILL.md) — client-shaped queries over fixed RPCs
- [api-versioning](../api-versioning/SKILL.md) — package versioning as the gRPC version axis
- [openapi-contracts](../openapi-contracts/SKILL.md) — buf lint/breaking + proto codegen as source of truth
- [api-security](../../quality/api-security/SKILL.md) — auth, rate limiting, error hygiene on RPC
- [observability](../../tooling/observability/SKILL.md) — tracing/metrics interceptors
- [be-testing](../../quality/be-testing/SKILL.md) — contract + integration tests for services
- [secure-coding](../../_shared/secure-coding/SKILL.md) — error hygiene, auth boundaries
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — toolchain floors
