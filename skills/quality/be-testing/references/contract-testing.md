# Contract Testing (Pact & Schema)

A unit test on the provider and a unit test on the consumer can both pass while the two disagree about the wire format. Contract tests pin the request/response shape so a "non-breaking" change that actually breaks a consumer fails in CI — not in production.

## Two approaches

| Approach | Drives from | Best for |
|----------|-------------|----------|
| **Consumer-driven (Pact)** | what consumers actually use | internal service-to-service |
| **Schema-based (OpenAPI + Schemathesis)** | the published spec | public/REST APIs, many unknown consumers |

They compose: Pact for the partners you know, schema validation/fuzzing for everyone else.

## Consumer-driven contracts with Pact

The consumer records the interactions it depends on; the provider proves it satisfies them. The contract (a "pact" file) is the shared truth, exchanged via a **broker**.

Target the **Pact Specification v4** (current; ratified 2022) via each language's V4 API — `PactV4` (Pact-JS), PactNet 5.x (.NET), the V4 DSL on the JVM/Python/Go guides. V4 allows mixing HTTP and async-message interactions in one pact file and adds plugin support (e.g. gRPC/Protobuf); PactFlow renders V4 pacts. Older V3 pacts still verify, but write new contracts against V4.

### Consumer side — record expectations

```ts
import { PactV4 } from "@pact-foundation/pact";
import { like } from "@pact-foundation/pact/src/v3/matchers";

const provider = new PactV4({ consumer: "web", provider: "orders-api" });

await provider
  .addInteraction()
  .given("order 42 exists")
  .uponReceiving("a request for order 42")
  .withRequest("GET", "/orders/42")
  .willRespondWith(200, (b) => b.jsonBody({ id: 42, total: like(999) }))
  .executeTest(async (mock) => {
    const client = new OrdersClient(mock.url);
    expect((await client.getOrder(42)).total).toBe(999);
  });
```

Use **matchers** (`like`, `eachLike`, `regex`), not exact values — the consumer cares about *shape and types*, not the provider's specific data. Over-specifying makes the contract brittle.

### Provider side — verify

```java
@Provider("orders-api")
@PactBroker(url = "${PACT_BROKER_URL}")
class OrderContractVerificationTest {
  @TestTemplate @ExtendWith(PactVerificationInvocationContextProvider.class)
  void verify(PactVerificationContext ctx) { ctx.verifyInteraction(); }

  @State("order 42 exists")  // set up the provider state the consumer assumed
  void order42Exists() { seedOrder(42, 999); }
}
```

The provider replays every consumer's recorded requests against the real provider (with its DB seeded to the declared `given` state) and asserts the responses still match. If a field is renamed or a status changes, verification fails.

### The broker & can-i-deploy

The Pact Broker stores contracts and verification results and gates deploys:

```bash
pact-broker can-i-deploy --pacticipant orders-api \
  --version "$GIT_SHA" --to-environment production
```

`can-i-deploy` answers "is there a verified contract with every consumer I'd be deployed alongside?" — it stops a provider change that would break a still-deployed consumer. Tag versions per environment so the broker knows what's actually running where.

## Schema-based validation & fuzzing

For public REST APIs, the OpenAPI spec is the contract. Two uses:

### Validate responses against the spec

Assert in integration tests that real responses conform to the documented schema (`openapi-response-validator`, Spring REST Docs / `springdoc`, `schemathesis` assertions). This keeps the spec honest — docs that lie are worse than none.

### Property-based fuzzing with Schemathesis

Schemathesis (v4+) reads the OpenAPI/GraphQL spec and generates malformed, boundary, and unexpected inputs to find crashes and contract violations automatically. The CLI entrypoint is `st` and the example-count flag is `--max-examples` (`-n`); the v3 `--hypothesis-max-examples` flag was removed in v4:

```bash
st run http://localhost:8080/openapi.json \
  --checks all --max-examples 200          # --mode all also exercises negative inputs
```

It surfaces: unhandled 500s, responses that don't match the declared schema, missing `Content-Type`, and spec/implementation drift. It overlaps API security (it'll find inputs that bypass validation) — pair it with the [api-security](../../api-security/SKILL.md) work.

## Where contract tests run

- **Consumer CI** publishes its pacts to the broker on every build.
- **Provider CI** verifies against all consumer pacts; failing verification fails the provider build.
- **Deploy gate** runs `can-i-deploy` before promoting either side.
- **Schema validation/fuzzing** runs as an integration stage against a started instance.

## Contract test vs integration test

They answer different questions — keep both:

| Test | Question |
|------|----------|
| Integration ([integration-testcontainers](integration-testcontainers.md)) | Does my code work against the real DB? |
| Contract (this file) | Do my API and its consumers/providers agree on the wire? |

A contract test does **not** need the real DB — the provider state is seeded just enough to satisfy the interaction.

## Per-stack tooling

| Stack | Pact / schema |
|-------|---------------|
| Node | `@pact-foundation/pact`; `express-openapi-validator` |
| JVM | `au.com.dius.pact`; Spring Cloud Contract; `springdoc` |
| Python | `pact-python`; `schemathesis`; FastAPI emits OpenAPI natively |
| Go | `pact-go`; `kin-openapi` validation |
| Ruby | `pact` gem; `committee` |
| .NET | `PactNet`; Swashbuckle for the spec |

Versions: skill [version-feature-matrix](../../../_shared/version-feature-matrix.md).

## Checklist

- [ ] Internal service pairs have consumer-driven Pact contracts, verified in provider CI.
- [ ] Pacts use matchers (shape/type), not over-specified exact values.
- [ ] Provider verification seeds the declared `given` states.
- [ ] `can-i-deploy` gates promotion of both sides.
- [ ] Public REST API responses validated against the OpenAPI spec; spec kept honest.
- [ ] Schemathesis (v4, `st run --checks all --max-examples N`) fuzzes the spec for 500s and contract drift in CI.
- [ ] New Pact contracts written against the V4 spec (V4 API / PactNet 5.x); verified via the broker.
