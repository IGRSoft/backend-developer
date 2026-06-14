# QA Stage Artifact Template (backend testing)

Primary artifact `.context/testing-N.md` is owned by igrsoft's qa-engineer; use this when be-test-generator or a backend-developer agent takes over QA or supplies the evidence body.

```markdown
---
handoff:
  stage: QA
  verdict: go           # go | no-go
  summary: "<test outcome — ≤200 chars>"
  files_touched:        # REQUIRED for QA (= tests added)
    - test/orders.e2e.spec.ts
  key_decisions:        # REQUIRED for QA (= results)
    - id: q1
      summary: "<suite result — ≤160 chars, e.g. '128/128 pass; npm audit clean'>"
      anchor: testing-0.md#results
  open_questions: []
  refs:
    development: development-0.md#tests-added
---

# QA Testing — <worktask_id>

## results

| Suite | Command | Result | Transcript |
|-------|---------|--------|------------|
| unit | `pnpm vitest run` | 128/128 pass | .context/logs/vitest-<worktask_id>.log |
| integration | `pnpm vitest run --project integration` | 31/31 pass (Testcontainers Postgres) | .context/logs/integration-<worktask_id>.log |
| security-scan | `npm audit --omit=dev` | 0 high/critical | .context/logs/audit-<worktask_id>.log |

Gate (both required for `go` — workflow-integration/SKILL.md § QA Gate):
- [ ] All tests pass (full suite, not only new tests; integration tests against real deps)
- [ ] Security-scan clean (OWASP API Top 10) + integration tests green (Testcontainers where present)

## coverage

| Component | Tool | Line % | Target |
|-----------|------|--------|--------|
| src/routes/orders | c8 / go cover / JaCoCo / coverage.py | <n>% | per _shared/testing-principles.md |

## regressions

- <failures vs. the pre-change baseline, with suspected cause and owner, or "None">

## verdict

<go | no-go — one-line justification; on no-go list blocking defects>

Blocking defects (no-go only — these become `metadata.gate_blockers[]` verbatim on DV re-dispatch):
- <self-contained, actionable string with file:line / failing test name / vuln id>
```

## Notes

- Security-scan evidence is part of the gate, not optional garnish: run the changed ecosystem's vuln scanner (`npm audit` / `osv-scanner` / `govulncheck` / `trivy`) and confirm no OWASP API Top 10 regression (auth boundaries, rate limiting, injection, SSRF); attach the transcript path.
- Every transcript path in `## results` must exist under `.context/logs/`.
- Test selection for focused re-runs: `vitest run -t <name>`, `go test -run <regex>`, `mvn -Dtest=<Class> test`, `pytest -k <expr>`.
- Frontmatter budget: ≤200 tokens, ≤30 lines.
