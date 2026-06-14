# DV Stage Artifact Template (backend work)

Copy this to `.context/development-N.md` (`N` from `task.metadata.run_index`; e.g. `development-0.md`). H2 anchors are fixed by igrsoft's anchor allow-list — keep them exactly as written (kebab-case, H2); backend sections nest as H3.

```markdown
---
handoff:
  stage: DV
  verdict: ok           # ok | blocked | escalate
  summary: "<what was implemented — ≤200 chars>"
  files_touched:        # REQUIRED for DV
    - src/routes/orders.ts
    - test/orders.e2e.spec.ts
  next_stage_focus: "<hint for DR/QA — ≤240 chars>"
  key_decisions: []
  open_questions: []
  remediation_consumed: []   # rework only (metadata.retry_count>0): gate_blockers[] addressed this run
  refs:
    plan: planning-0.md#requirements
    decisions: analyzing-0.md#decisions
---

# DV Development — <worktask_id>

## files-changed

| File | Change | Why |
|------|--------|-----|
| src/routes/orders.ts | <summary> | <reason> |

### decisions

- <non-obvious implementation choice + rationale; reference analyzing-N.md anchors>

### tool-invocations

- `pnpm build && pnpm typecheck`
- `pnpm vitest run`
- `pnpm prisma migrate diff --from-schema-datamodel --to-schema-datasource`  # migration dry-run, schema changed

## tests-added

| Test | Framework | Covers |
|------|-----------|--------|
| test/orders.e2e.spec.ts | Vitest + supertest | <behavior> |

### build-evidence

- Runtime + framework: <e.g. node 22, NestJS 11 — verify against _shared/version-feature-matrix.md>
- Build / typecheck: pass (`tsc --noEmit` clean) | <go build ./... | mvn compile | ...>
- Lint: <eslint / golangci-lint / ruff / checkstyle result — 0 issues>
- Integration tests: <n>/<n> pass (Testcontainers Postgres) — transcript: .context/logs/<tool>-<worktask_id>.log
- Migration dry-run: <output summary, or "n/a — no schema change">

## deviations

- <departures from analyzing-N.md, or "None">

## follow-ups

- <deferred work, flagged risks, or "None">
```

## Notes

- **Screenshots**: backend/API work defaults `metadata.requires_screenshots: false` — no manifest needed. If the flag is unset/true and cannot be changed, write a **cli-fallback** manifest at `.context/images/<worktask_id>/screenshots.md` (rows with `source: cli-fallback` pointing at request/response transcripts, test output, k6 reports, or migration logs as `.txt` files; `screenshot_count` = row count) before returning, or `dv-screenshot-gate.sh` blocks `SubagentStop`. See `workflow-integration/SKILL.md § Screenshot Gate for API Work`.
- `remediation_consumed:` is populated only on a rework re-dispatch — list the `metadata.gate_blockers[]` strings (from the DR/QA gate) this run fixed. See `workflow-integration/SKILL.md § Gate-Feedback Contract`.
- Frontmatter budget: ≤200 tokens, ≤30 lines. Emit it unconditionally — it is the state.json merge input regardless of filename.
- Tee raw build/test output to `.context/logs/` — the Build Evidence transcript path must exist on disk. Where a migration was added, include its dry-run/log output.
