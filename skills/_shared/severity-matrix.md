---
name: severity-matrix
description: Reusable severity and priority definitions for backend-developer commands and agents
---

# Severity Matrix Reference

Shared definitions for severity levels, priority matrices, and effort/impact assessments.

## Severity Levels

| Level | Description | Response Time | Backend Examples |
|-------|-------------|---------------|------------------|
| Critical | Security, data integrity, service down | Immediate | Broken object-level authorization (BOLA), SQL/NoSQL injection, data corruption from a bad migration, secrets in a response body |
| High | Performance blockers, major functionality | Within sprint | N+1 query on a hot endpoint, missing idempotency key on a payment write, unbounded query loading a full table, broken auth boundary |
| Medium | Code quality, minor performance | Quarterly | Swallowed error, duplicated handler validation, missing transaction around a multi-write, chatty downstream calls |
| Low | Style, nice-to-have | Opportunistic | Formatting drift, naming, missing OpenAPI annotation/docstring |

## Review Finding Priorities (P0-P3)

Used by the Implementation/Review response formats of all backend-developer agents:

| Priority | Definition | Backend Examples |
|----------|------------|------------------|
| P0 | Must fix before merge — correctness/security broken | Missing authz check (BOLA/BFLA), SQL/NoSQL/command injection, SSRF, secret leaked in logs or response, irreversible/locking migration, failing tests |
| P1 | Fix in this change — defect likely to bite | Missing transaction on a multi-row write, no idempotency on a retried mutation, N+1 on a request path, unbounded result set, race on a shared counter |
| P2 | Should fix — quality/maintainability | Missing error propagation, magic numbers, oversized handler, weak coverage on changed code, inconsistent error envelope |
| P3 | Nice to have — style | Formatting, naming, comment/OpenAPI polish (auto-fixable via prettier/gofmt/ruff/spotless) |

## Priority Matrix (impact × effort)

| Priority | Impact | Effort | Action |
|----------|--------|--------|--------|
| P0 | Critical | Any | Immediate remediation |
| P1 | High | Low | Do first (quick wins) |
| P2 | High | High | Plan and schedule |
| P3 | Medium | Low | Batch together |
| P4 | Low | High | Deprioritize or skip |

## Effort/Impact Quadrant

```
High Impact ┌──────────────┬──────────────┐
            │   SCHEDULE   │  DO FIRST    │
            │  (P2: Plan)  │ (P1: Quick)  │
            ├──────────────┼──────────────┤
            │    AVOID     │  FILL-INS    │
            │ (P4: Defer)  │ (P3: Batch)  │
Low Impact  └──────────────┴──────────────┘
             High Effort    Low Effort
```

## Code Smell Indicators

| Smell | Thresholds | Impact |
|-------|------------|--------|
| Long function | >40 lines (handler/service method) | Hard to understand/test |
| Large module / controller | >500 lines | Difficult to maintain |
| Cyclomatic complexity | >10 | Error-prone |
| Nesting depth | >3 levels | Reduced readability |
| Parameters | >5 | Hard to use correctly |
| Code duplication | >5% | Maintenance burden |
| Fat controller (logic in handler) | business logic outside service layer | Untestable, leaks transaction/auth concerns |

## Coverage Requirements

| Scope | Minimum | Target |
|-------|---------|--------|
| Critical paths (auth, payments, repositories) | 90% | 95%+ |
| Business logic (services/use-cases) | 75% | 80%+ |
| Utilities | 60% | 70%+ |
| HTTP handlers / glue / config | 50% | 60%+ |

## Usage

Reference this file in commands using:
```markdown
See: skills/_shared/severity-matrix.md for severity definitions
```
