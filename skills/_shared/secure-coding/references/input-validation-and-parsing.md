# Input Validation and Parsing (Node / Go / JVM / Python / Ruby / PHP / .NET)

Use this when:

- You accept bytes from outside the process — a request body/query/path/header, a webhook, a queue payload, or an upstream API response.
- You parse untrusted numbers, lengths, encodings, or structured data.
- You bind a request body to a model (mass-assignment surface) or serialize a model into a response (over-fetch surface).
- You paginate or size a result set, or you deserialize data and need to know which formats are safe.

Skip this file if:

- You are executing a subprocess, building a query, or making an outbound call. Use `command-execution-and-injection.md`.
- You only need the rule summary. Use the parent `SKILL.md`.

Jump to:

- Validation Doctrine
- Schema Validation at the Boundary
- Safe Number and Length Parsing
- Pagination and Resource Bounds (API4)
- Mass-Assignment and Property-Level Authorization (API3)
- Deserialization Risks
- External / Upstream API Responses (API10)
- Validation Checklist

## Validation Doctrine

Treat the request boundary as a trust boundary. Every value crossing it is hostile until proven otherwise. Three properties must hold before an untrusted value is used:

1. **Bounded** — length, count, and page size are within a known maximum (reject, never truncate silently when truncation changes meaning).
2. **Well-formed** — content type, encoding, type, and structure match the expected schema.
3. **In range** — numeric values fall inside the domain the code actually supports.

Validate **once, at the boundary**, into a typed internal representation (a DTO/struct), then trust that type downstream; do not re-validate ad hoc deep in the call stack. Prefer allow-lists (enumerate what is permitted) over deny-lists (enumerate what is forbidden) — deny-lists always miss a case.

Fail closed: on any validation failure, reject the whole request with a generic error and a 4xx; log the detail server-side. Never "best-effort fix" attacker data, and never echo the offending value or a stack trace back to the client (**API8**).

## Schema Validation at the Boundary

Parse into a schema; do not hand-roll `if (typeof x !== ...)` checks scattered through a handler. A schema gives you bounded + well-formed + in-range in one place, and a typed object out.

### Node/TS — zod / valibot

```ts
import { z } from "zod";

const CreateOrder = z.object({
  sku: z.string().min(1).max(64).regex(/^[A-Z0-9-]+$/),
  qty: z.number().int().positive().max(1000),
  note: z.string().max(280).optional(),
}).strict();                              // .strict() rejects unknown keys (mass-assignment guard)

export function parseCreateOrder(body: unknown) {
  return CreateOrder.parse(body);          // throws on any violation → 400 in the error handler
}
```

- Use `.strict()` (zod) / `object` without passthrough (valibot) so unexpected keys are rejected, not silently ignored.
- Validate at the edge of the handler, before any business logic or DB call; pass the parsed, typed object inward.

### Go — go-playground/validator

```go
type CreateOrder struct {
    SKU string `json:"sku" validate:"required,max=64,alphanum"`
    Qty int    `json:"qty" validate:"required,gt=0,lte=1000"`
}

dec := json.NewDecoder(r.Body)
dec.DisallowUnknownFields()              // reject unexpected keys (mass-assignment guard)
var in CreateOrder
if err := dec.Decode(&in); err != nil { http.Error(w, "bad request", 400); return }
if err := validate.Struct(in); err != nil { http.Error(w, "bad request", 400); return }
```

- `DisallowUnknownFields()` on the decoder is the Go equivalent of zod `.strict()`.
- Bound `http.MaxBytesReader(w, r.Body, maxBytes)` before decoding so a huge body cannot exhaust memory (**API4**).

### JVM — Bean Validation (Jakarta) on a DTO

```java
public record CreateOrder(
    @NotBlank @Size(max = 64) @Pattern(regexp = "[A-Z0-9-]+") String sku,
    @Positive @Max(1000) int qty) {}

// @Valid on the controller param triggers validation; bind to the DTO, never the entity.
@PostMapping("/orders")
ResponseEntity<?> create(@Valid @RequestBody CreateOrder in) { ... }
```

- Bind to a DTO/record, never directly to the JPA entity — that is the mass-assignment defense (**API3**).
- Configure Jackson `FAIL_ON_UNKNOWN_PROPERTIES = true` to reject unexpected fields.

### Python — Pydantic v2

```python
from pydantic import BaseModel, Field, ConfigDict

class CreateOrder(BaseModel):
    model_config = ConfigDict(extra="forbid")    # reject unknown keys (mass-assignment guard)
    sku: str = Field(min_length=1, max_length=64, pattern=r"^[A-Z0-9-]+$")
    qty: int = Field(gt=0, le=1000)

order = CreateOrder.model_validate(payload)        # raises ValidationError → 422
```

- `extra="forbid"` rejects unexpected fields. FastAPI does this automatically when you type the body as the model.
- The validated model is your typed internal representation; do not pass the raw `dict` past this point.

Ruby (Rails strong params + ActiveModel validations), PHP (Laravel `FormRequest` rules / Symfony Validator), and .NET (DataAnnotations / FluentValidation on a request model) follow the same shape: a declared schema, unknown fields rejected, bound to a request type — never the persistence model. Version-specific validator features are in [version-feature-matrix.md](../version-feature-matrix.md).

## Safe Number and Length Parsing

Parsing user-supplied numbers is where overflow and silent truncation enter. Reject non-numeric junk; range-check after parsing; never feed an unvalidated number into a size, limit, or allocation.

### Node/TS

```ts
function parsePositiveInt(raw: unknown, max: number): number {
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1 || n > max) throw new Error("out of range");
  return n;
}
```

- `Number("")`/`Number("  ")` is `0` and `Number("0x10")` parses — prefer `Number.isInteger` + explicit bounds over `parseInt` (which reads `"12abc"` as `12`).

### Go / JVM / Python / .NET

```go
n, err := strconv.Atoi(raw)               // total parse: errors on junk
if err != nil || n < 1 || n > max { return errBadInput }
```

- Go `strconv.Atoi`/`ParseInt(…, bitSize)`, Java `Integer.parseInt` (catch `NumberFormatException`), Python `int(s)` (raises `ValueError`), .NET `int.TryParse` — all reject malformed input. Apply the **domain** range check (page max, array bound) after the parse.
- **Never** `eval`/`Function(...)`/`exec` to "parse" a number — that is arbitrary code execution. Use the language's total integer parser.

## Pagination and Resource Bounds (API4)

Unbounded result sets and unbounded request bodies are denial-of-service and cost vectors. Bound everything the caller can grow.

| Bound | Rule |
|-------|------|
| Page size | Default (e.g. 20) **and** a hard server-side max (e.g. 100); clamp, do not trust the client `limit` |
| Pagination strategy | Cursor/keyset for large or hot tables — avoid deep `OFFSET` scans that worsen linearly |
| Body size | Reject before parsing: `express.json({limit})`, `http.MaxBytesReader` (Go), `MaxRequestBodySize` (ASP.NET), multipart caps (Spring) |
| Collection length | Cap array/`items` length in the schema (`z.array(...).max(n)`, `@Size`, `Field(max_length=n)`) |
| Query timeout | `statement_timeout` (Postgres), context deadline (Go), `@Transactional(timeout)` (Spring) so one query can't hold a connection forever |

```ts
const limit = Math.min(Math.max(Number(query.limit) || 20, 1), 100); // default 20, hard max 100
```

## Mass-Assignment and Property-Level Authorization (API3)

Two symmetric failures: writing a field the caller shouldn't set (mass-assignment), and returning a field the caller shouldn't see (over-fetch).

- **On write**: never bind the raw request body to your persistence model. Bind to a DTO/strong-params allowlist of writable fields, then copy approved fields onto the entity. A body with `{"role":"admin"}` must not become a privileged update.
- **On read**: serialize through an explicit response DTO/serializer that allowlists fields. Never `return user;` if `user` carries `passwordHash`, `mfaSecret`, internal flags, or another tenant's data.

```ts
// DO — explicit allowlist of writable fields
const { sku, qty, note } = CreateOrder.parse(body);
await repo.create({ sku, qty, note, tenantId: ctx.auth.tenantId }); // tenantId from token, not body

// DON'T — spreads whatever the client sent, including role/tenantId/isAdmin
await repo.create({ ...body });
```

- Server-controlled fields (`tenantId`, `ownerId`, `role`, timestamps) are set from the verified session/token, **never** read from the body — that is also the BOLA/BFLA defense (**API1/API5**, see parent `SKILL.md`).

## Deserialization Risks

Deserialization that can instantiate arbitrary types or run code is remote code execution.

| Format / API | Safe? | Use instead |
|--------------|-------|-------------|
| Java native serialization (`ObjectInputStream.readObject`) on untrusted bytes | **No — RCE** | JSON (Jackson) with a fixed target type; if unavoidable, an `ObjectInputFilter` allowlist |
| Python `pickle` / `marshal` on untrusted bytes | **No — RCE** | `json`; a schema-validated (Pydantic) structure |
| Ruby `Marshal.load` / `YAML.load` on untrusted input | **No — object injection** | `JSON.parse`; `YAML.safe_load` |
| PHP `unserialize()` on untrusted input | **No — object injection** | `json_decode`; if needed, `unserialize($s, ['allowed_classes' => false])` |
| .NET `BinaryFormatter` | **No — removed/banned** | `System.Text.Json` with a known type |
| `yaml.load(...)` full loader (Python) | **No — constructs objects** | `yaml.safe_load(...)` |
| `JSON.parse` / `json.loads` / Jackson data binding | Yes (data only; still validate the shape) | — |
| XML with external entities enabled | Risky — XXE / entity expansion | disable DTDs/external entities; `defusedxml` (Python), secure-processing features (JVM) |

- After parsing JSON/YAML, the data is still untrusted — validate the schema (types, required keys, ranges) before use. **Parsing is not validation.**
- For XML, explicitly disable DOCTYPE/external-entity resolution to defeat XXE and billion-laughs expansion.

## External / Upstream API Responses (API10)

A response from a remote service is untrusted input even when the service is "ours":

- Check the status code and content type before parsing; do not assume `200` or JSON.
- Bound the response size (`maxContentLength` / a capped reader) — a hostile or buggy upstream can stream forever and exhaust memory.
- Validate the parsed structure with the same schema discipline as a request body; never trust a field to be present, in range, or non-malicious.
- Keep TLS verification on. Do not set `rejectUnauthorized:false` (Node), `InsecureSkipVerify:true` (Go), a trust-all `HostnameVerifier`/`X509TrustManager` (JVM), `verify=False` (Python `requests`/`httpx`), or `ServerCertificateCustomValidationCallback => true` (.NET) — each enables MITM. For a self-signed dev cert, add the CA to the trust store; disabling verification requires a documented, reviewed justification and must never reach production.
- The host you fetch may itself be input — apply the SSRF egress controls in `command-execution-and-injection.md` (**API7**).

## Validation Checklist

- [ ] Every request body/query/header is parsed through a schema (zod/valibot, validator, Bean Validation, Pydantic, FormRequest, FluentValidation) into a typed DTO at the boundary.
- [ ] Unknown fields are rejected (`.strict()` / `DisallowUnknownFields` / `extra="forbid"` / `FAIL_ON_UNKNOWN_PROPERTIES`).
- [ ] Numbers parsed with a total parser and domain-range-checked; never `eval`/`Function`.
- [ ] Page size has a default **and** a hard server-side max; body size capped before parsing; collection lengths bounded (**API4**).
- [ ] Writes bind an allowlist of fields (no raw-body spread); server-controlled fields (`tenantId`/`ownerId`/`role`) set from the token, not the body (**API3/API1**).
- [ ] Responses serialized through an allowlist DTO — no secrets/internal flags/cross-tenant fields leak (**API3**).
- [ ] No native/`pickle`/`Marshal`/`unserialize`/`BinaryFormatter` deserialization of untrusted bytes; parsed structures schema-validated; XXE disabled.
- [ ] Upstream API responses status/type-checked, size-bounded, schema-validated; TLS verification on (**API10**).
- [ ] Validation failures fail closed with a generic 4xx; no stack trace or offending value returned to the client (**API8**).

## Related

- `command-execution-and-injection.md` — injection-safe queries/execution, SSRF egress allowlists, the dynamic-code-execution ban, supply-chain scanning
- `../SKILL.md` — non-negotiable rules, OWASP API Top 10 mapping, authorization-boundary and diagnostic tables
- `../version-feature-matrix.md` — validator/framework version and fallback lookup
