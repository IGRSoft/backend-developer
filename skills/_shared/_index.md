# Shared Skills Index

Quick navigation for cross-cutting references shared by all backend-developer agents, commands, and skills.

## Workflow Integration

| File | Description |
|------|-------------|
| `workflow-integration/SKILL.md` | Guide for integrating with corpflow 11-stage pipeline — DV/DR/QA contracts, API/transcript cli-fallback evidence, gate feedback |
| `workflow-integration/templates/dv-development.md` | Copy-paste `development-N.md` artifact template (Build/Test Evidence, anchors, frontmatter) |
| `workflow-integration/templates/dr-review.md` | Copy-paste `developer-review-N.md` template with back-end review checklist (API contract, transactions, N+1, idempotency, auth boundaries, migration safety) |
| `workflow-integration/templates/qa-testing.md` | Copy-paste `testing-N.md` template with unit+integration+`analyze-security` gate evidence |

## Routing & Versions

| File | Description |
|------|-------------|
| `language-detection.md` | Marker → stack → agent routing table, detection priority, front-end vs back-end tie-break, system-developer handoff |
| `version-feature-matrix.md` | Node.js 18/20/22 + TS 5.x, Go 1.21-1.23, Java 17/21 + Spring Boot 3.x + Kotlin 2.x, Python web frameworks, ORM/DB engine floors |
| `model-selection.md` | Per-agent model/effort/maxTurns assignments and opus+xhigh override paths |

## Quality & Security

| File | Description |
|------|-------------|
| `severity-matrix.md` | Severity levels, P0-P3 review priorities, effort/impact quadrant, coverage requirements |
| `testing-principles.md` | Test pyramid, per-stack framework matrix, Testcontainers integration tests, quality gates, anti-patterns |
| `secure-coding/SKILL.md` | OWASP API Security Top 10 (2023) defenses, injection-safe data access, secrets hygiene, supply-chain CVEs |
| `secure-coding/references/input-validation-and-parsing.md` | Validation at trust boundaries, schema validation, pagination/size limits (API4), mass-assignment/object-property authorization (API3), safe deserialization |
| `secure-coding/references/command-execution-and-injection.md` | SQL/NoSQL/command injection prevention, SSRF egress allowlists, secrets via env/secret-manager, supply-chain CVEs |

## Quick Links by Problem

### "I need to..."

- **Integrate with corpflow worktask** → `workflow-integration/SKILL.md`
- **Write a DV/DR/QA stage artifact** → `workflow-integration/templates/`
- **Handle the evidence gate for API/service work** → `workflow-integration/SKILL.md § Evidence Gate for Non-UI Work`
- **Route a file/repo to the right agent** → `language-detection.md`
- **Decide front-end vs back-end for a `package.json`** → `language-detection.md § Tie-Breaking Rules`
- **Check if a feature is available on a runtime/framework** → `version-feature-matrix.md`
- **Pick model/effort for a delegation** → `model-selection.md`
- **Set severity/priority on a finding** → `severity-matrix.md`
- **Choose a test framework or coverage target** → `testing-principles.md`
- **Review auth boundaries, injection, or upstream API consumption** → `secure-coding/SKILL.md`
