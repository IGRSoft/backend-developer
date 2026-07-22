---
name: model-selection
description: Model and effort selection for backend-developer agents — cost tiers, per-agent assignments, and opus+xhigh override paths. Reference when delegating to or overriding a backend-developer specialist.
effort: low
---

# Model & Effort Selection (backend-developer)

Companion to igrsoft's `skills/shared/model-selection.md`. This file pins the
**backend-developer** per-agent assignments and the override paths the stack
agents expose. Frontmatter in `agents/*.md` is the source of truth — keep this
table in sync with it.

## Cost Tiers

| Model | Relative Cost | Use For |
|-------|---------------|---------|
| **haiku** | 1x (baseline) | Mechanical remediation, dependency operations, formatting |
| **sonnet** | ~10x haiku | Stack implementation, API/schema design, review, test generation, routing |
| **opus** | ~50x haiku | Architecture selection, deep load-trace/threat analysis |

## Effort Levels

`low` ○, `medium` ◐, `high` ●, `xhigh` ⬣.

- `xhigh` is honored **only on Opus** — Sonnet/Haiku silently fall back to
  `high`, so raising effort without raising the model is a no-op.
- Reserve `xhigh` for the hardest long-chain reasoning (architecture trade-offs,
  root-causing a tail-latency regression that spans services, threat modeling).

## Per-Agent Assignment

| Agent | Model | Effort | maxTurns | Override path |
|-------|-------|--------|----------|---------------|
| `backend-developer` (router) | sonnet | medium | 40 | — routes work to specialists |
| `node-developer` | sonnet | high | 50 | → `opus` + `xhigh` for novel design / cross-service refactors |
| `go-developer` | sonnet | high | 50 | → `opus` + `xhigh` for novel design / concurrency-heavy work |
| `jvm-backend-developer` | sonnet | high | 50 | → `opus` + `xhigh` for reactive/transaction-boundary design |
| `python-backend-developer` | sonnet | high | 50 | → `opus` + `xhigh` for async/ORM-boundary work |
| `ruby-developer` | sonnet | high | 50 | → `opus` + `xhigh` for Rails engine / metaprogramming-heavy work |
| `php-developer` | sonnet | high | 50 | → `opus` + `xhigh` for Laravel/Symfony framework-level design |
| `dotnet-developer` | sonnet | high | 50 | → `opus` + `xhigh` for EF Core / minimal-API boundary design |
| `api-designer` | sonnet | high | 50 | → `opus` + `xhigh` for large contract/versioning trade-offs |
| `database-engineer` | sonnet | high | 50 | → `opus` + `xhigh` for sharding / multi-region schema design |
| `backend-architector` | opus | xhigh | 60 | already top tier; self-limits scope at Low complexity per § Complexity Triage |
| `be-test-generator` | sonnet | high | 50 | — sonnet sufficient for pattern work |
| `be-performance-engineer` | sonnet | high | 50 | → `opus` + `xhigh` for deep load-trace analysis (review-only: `disallowed-tools: Write, Edit`) |
| `be-security-auditor` | sonnet | high | 50 | → `opus` + `xhigh` for deep threat modeling (review-only: `disallowed-tools: Write, Edit`) |
| `be-code-fixer` | haiku | medium | 30 | — deterministic minimal-diff remediation |
| `be-dependency-manager` | haiku | low | 20 | — mechanical lockfile/manifest operations |

## Applying an Override

Pass `model`/`effort` on the Task() call (per-invocation, does not edit
frontmatter). Callers of `be-performance-engineer` and `be-security-auditor`
may override to `opus` + `xhigh` when the investigation spans multiple
services or requires long-chain causal reasoning:

```
Task({ subagent_type: "backend-developer:be-performance-engineer",
       model: "opus", effort: "xhigh",
       prompt: "Root-cause the p99 latency regression across the gateway, order service, and the Postgres connection pool from these traces and k6 reports…" })
```

Only override when complexity warrants it — the sonnet/high default covers the
overwhelming majority of backend work. Both review-only agents keep their
`disallowed-tools: Write, Edit` restriction regardless of model: fixes route to
`backend-developer:be-code-fixer`.
