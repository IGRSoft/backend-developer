# DR Stage Artifact Template (backend review)

Primary artifact `.context/developer-review-N.md` is owned by company-workflow's technical-lead; use this when a backend-developer agent takes over DR or contributes the review body. be-code-fixer appends retry narratives to `.context/errors/be-code-fixer.md` instead.

```markdown
---
handoff:
  stage: DR
  verdict: pass         # pass | fail
  summary: "<review outcome — ≤200 chars>"
  key_decisions:        # REQUIRED for DR (= findings)
    - id: f1
      summary: "<P0 finding — ≤160 chars>"
      anchor: developer-review-0.md#findings
  files_touched: []     # only when be-code-fixer applied fixes
  next_stage_focus: "<security surface / test focus for SR/QA — ≤240 chars>"
  refs:
    development: development-0.md#files-changed
---

# Developer Review — <worktask_id>

## findings

| ID | Priority | Area | Location | Issue | Fix |
|----|----------|------|----------|-------|-----|
| f1 | P0 | Auth boundaries | src/routes/orders.ts:42 | <issue> | <fix> |

Checked areas (backend criteria — see workflow-integration/SKILL.md § DR Backend Review Criteria):
- [ ] API-contract adherence: routes/payloads/status codes match contract, no breaking change, pagination honored
- [ ] Error handling: correct status mapping, no internals leaked, structured errors, no swallowed exceptions
- [ ] Transaction correctness: atomic where required, correct isolation, no partial writes on failure
- [ ] N+1 queries: no per-row queries in loops, batched/eager loading, indexes for new predicates
- [ ] Idempotency: retried mutations carry idempotency key or are naturally idempotent
- [ ] Auth boundaries: BOLA/BFLA enforced server-side, tenant isolation on every data access
- [ ] Migration safety: reversible/expand-contract, no destructive change without backfill, safe under mixed old/new code

## verdict

<pass | fail — with one-line justification tied to findings>

## blockers

- <P0/P1 findings that force verdict: fail — these become metadata.gate_blockers[] verbatim on DV re-dispatch; empty list when pass>

## follow-ups

- <P2/P3 findings deferred to backlog, or "None">
```

## Notes

- `blockers` entries are injected **verbatim** into the DV retry prompt (Gate-Feedback Contract) — write them as self-contained, actionable strings with `file:line`.
- Priorities follow `_shared/severity-matrix.md` (P0 = broken authz/injection/data loss, P1 = transaction bug/N+1 at scale/non-idempotent retry, P2 = quality, P3 = style).
- be-code-fixer on a fix-application pass: populate `files_touched`, enforce minimal diff, and record per-blocker resolution in `.context/errors/be-code-fixer.md`.
