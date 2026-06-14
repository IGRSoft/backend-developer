# Go Skills Index

Quick navigation for the `skills/go/` subtree. Start at [SKILL.md](SKILL.md) for
the guided entry with decision tree and Go toolchain quick reference.

## Skills

| Skill | Use it for |
|-------|------------|
| [modern-go/SKILL.md](modern-go/SKILL.md) | Generics (`[T any]`), error wrapping (`%w`, `errors.Is/As/Join`), range-over-func (1.23), structured logging with `slog`, stdlib-first idioms |
| [go-concurrency/SKILL.md](go-concurrency/SKILL.md) | Goroutines and channels, `context` propagation and cancellation, `sync` primitives, `errgroup`, worker pools, race detection, leak avoidance |

## References

| File | Use it for |
|------|------------|
| [go-concurrency/references/concurrency-patterns.md](go-concurrency/references/concurrency-patterns.md) | Fan-out/fan-in, pipelines, semaphores, rate limiting, graceful shutdown, debugging goroutine leaks and deadlocks |

## Cross-Tree

| Topic | Location |
|-------|----------|
| Runtime/framework minimums (canonical) | `${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md` |
| Input validation, injection & SSRF defense | `${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md` |
| OWASP API Security Top 10, auth boundaries | `${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md` |
| Table-driven tests, Testcontainers, `-race` | `${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md` |
| REST/GraphQL/gRPC API design | `${CLAUDE_SKILL_DIR}/api/SKILL.md` |
