---
name: go-skills
description: >-
  Go back-end skills navigation — modern Go (generics, errors, slog) and
  concurrency (goroutines, context, races). Use when writing or reviewing Go
  services or handling concurrency.
---

# Go Back-End Skills

Modern Go services: idiomatic stdlib-first code, error wrapping, structured logging, and safe concurrency.

## Skill Selection Guide

| I need to... | Use this skill |
|--------------|----------------|
| Generics, error wrapping (`%w`, `errors.Is/As/Join`), slog, stdlib-first | [modern-go](modern-go/SKILL.md) |
| Full Go version feature catalog with fallbacks | [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md) |
| Goroutines, channels, `context`, `errgroup`, worker pools | [go-concurrency](go-concurrency/SKILL.md) |
| Triage a data race or goroutine leak | [go-concurrency](go-concurrency/SKILL.md) (race detection section) |
| HTTP routing, framework selection (Gin/Echo/chi/stdlib) | [backend-developer](${CLAUDE_SKILL_DIR}/../) router → `go-developer` |
| Input validation, SQL/command injection, SSRF defense | [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md) |
| BOLA/auth boundaries, rate limiting, OWASP API Top 10 | [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md) |
| Table-driven tests, Testcontainers integration, `go test -race` | [be-testing](${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md) |

## Decision Tree

```
Go task?
├── Language level / new features
│   ├── Which Go version to target → modern-go/SKILL.md (selection table)
│   ├── Generics, range-over-func, slog → modern-go/SKILL.md
│   └── Feature minimums + fallbacks → ${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md
├── Errors
│   ├── Wrapping (%w), errors.Is/As, errors.Join → modern-go/SKILL.md
│   └── Sentinel vs typed vs opaque → modern-go/SKILL.md
├── Concurrency
│   ├── Goroutines, channels, sync primitives → go-concurrency/SKILL.md
│   ├── context propagation/cancellation → go-concurrency/SKILL.md
│   ├── errgroup, worker pools → go-concurrency/SKILL.md
│   └── Data race / goroutine leak triage → go test -race (go-concurrency/SKILL.md)
├── HTTP / API surface → go-developer (router) + ${CLAUDE_SKILL_DIR}/api/SKILL.md
└── Build, lint, test → go build/test/vet + golangci-lint (be-testing)
```

## Go Toolchain Quick Reference

```sh
go build ./...                  # build all packages
go test ./... -race             # test with the race detector (CI default)
go vet ./...                    # static checks beyond the compiler
golangci-lint run               # aggregated linters (govet, staticcheck, errcheck, …)
govulncheck ./...               # supply-chain CVE scan against the Go vuln DB
go mod tidy                     # reconcile go.mod / go.sum with imports
```

**Go versioning in one line**: generics (`[T any]`) land in **1.18**; `slog`
structured logging in **1.21**; `min`/`max`/`clear` builtins in **1.21**;
range-over-integer in **1.22**; range-over-func iterators in **1.23**.
Pin the toolchain in `go.mod` with a `go 1.23` directive plus a `toolchain`
line. Per-feature minimums: [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md).

The `go` directive in `go.mod` gates which language features compile — bump it
deliberately and let `golangci-lint` flag pre-`go`-directive constructs.

## File Overview

| Path | Purpose |
|------|---------|
| [_index.md](_index.md) | Full subtree navigation |
| [modern-go/SKILL.md](modern-go/SKILL.md) | Generics, error wrapping, range-over-func, slog, stdlib-first idioms |
| [go-concurrency/SKILL.md](go-concurrency/SKILL.md) | Goroutines, channels, context, errgroup, worker pools, race detection |

## Related Skills

- [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md) — canonical runtime/framework minimums
- [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md) — input validation, injection and SSRF defense
- [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md) — OWASP API Security Top 10, auth boundaries, rate limiting
- [be-testing](${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md) — table-driven tests, Testcontainers, `go test -race`
