---
name: modern-go
description: >-
  Modern Go for back-end services — generics, error wrapping (%w,
  errors.Is/As/Join), range-over-func iterators (1.23), structured logging with
  slog, and stdlib-first idioms. Use when writing or reviewing Go service code,
  choosing a Go version, designing error handling, adopting generics or slog, or
  finding a fallback for a newer Go feature.
---

# Modern Go (idiomatic, stdlib-first)

**Lean on the standard library; reach for generics and `slog` where they earn their keep; wrap errors with context.**

## When to Use

Use this skill when:
- Writing or reviewing Go service code and choosing idioms
- Picking a Go toolchain version, or finding a fallback for a feature your floor predates
- Designing error handling — sentinel vs typed vs opaque, wrapping with `%w`
- Adopting generics for reusable containers/helpers without over-abstracting
- Wiring structured logging with `log/slog` and request-scoped context
- Deciding stdlib (`net/http`, `encoding/json`) vs a framework dependency

Routing: HTTP routing and framework selection (Gin/Echo/chi/stdlib) →
`go-developer` via the [backend-developer](${CLAUDE_SKILL_DIR}/../) router;
goroutines, channels, and `context` → [go-concurrency](../go-concurrency/SKILL.md).

## Version Snapshot

Go ships two minors a year (Feb/Aug) and supports only the **two most recent**
majors — pin your floor accordingly. Range-over-func iterators and the `iter`
package, the loop-variable fix, and `ServeMux` method/wildcard routing are all
**baseline now** (≤ 1.22/1.23, below any supported floor); stop gating on them.

| Feature | Since | Fallback before that version |
|---------|-------|------------------------------|
| Generics (`[T any]`, type constraints) | 1.18 | Interfaces + type assertions, or codegen |
| `errors.Join` (multi-error) | 1.20 | `fmt.Errorf` chains or a `multierror` helper |
| `log/slog` structured logging | 1.21 | `zap`/`zerolog`, or `log` + manual fields |
| `min`/`max`/`clear` builtins | 1.21 | Hand-written helpers; delete map keys in a loop |
| Per-iteration loop variable scoping; range-over-integer (`for i := range n`) | 1.22 (baseline) | Shadow with `v := v`; classic 3-clause `for` |
| Range-over-func iterators (`iter.Seq`/`iter.Seq2`), `unique`, `cmp.Or` | 1.23 (baseline) | Return slices/channels, or callback-style funcs |
| Generic type aliases; `go.mod` `tool` directive; `os.Root`; `runtime.AddCleanup`; Swiss-Tables maps | 1.24 | Blank-import `tools.go`; `path/filepath` traversal guards; finalizers |
| `testing/synctest` (stable); `sync.WaitGroup.Go`; container-aware `GOMAXPROCS` (default) | 1.25 | `synctest` experiment (1.24); manual `Add(1)`/`Done`; set `GOMAXPROCS` from cgroup yourself |
| `errors.AsType[T]` (type-safe `errors.As`); `new(expr)`; `slog.NewMultiHandler` | 1.26 | `errors.As` with a target var; `p := &v`; fan-out handlers by hand |

Pin the toolchain in `go.mod` (`go 1.25` + a `toolchain go1.25.x` line, or 1.26 for
the current minor); since 1.21 the `go` directive is a real minimum the toolchain
enforces. Canonical Go floor: skill [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md).

**`encoding/json/v2` is still experimental** as of Go 1.26 — opt in only with
`GOEXPERIMENT=jsonv2` (it lands as the default `encoding/json` backend in 1.27).
Do not depend on `encoding/json/v2` / `encoding/json/jsontext` in shipping code yet;
keep using `encoding/json`.

## Errors: Wrap, Inspect, Aggregate

Wrap with `%w` to preserve the chain; inspect with `errors.Is`/`errors.As`; never
compare error strings.

```go
var ErrNotFound = errors.New("not found")          // sentinel

type ValidationError struct {                       // typed error with data
	Field string
	Msg   string
}

func (e *ValidationError) Error() string {
	return fmt.Sprintf("validation: %s: %s", e.Field, e.Msg)
}

func (s *Store) GetUser(ctx context.Context, id string) (*User, error) {
	u, err := s.q.User(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("get user %s: %w", id, ErrNotFound) // wrap
		}
		return nil, fmt.Errorf("get user %s: %w", id, err)             // add context, keep chain
	}
	return u, nil
}
```

```go
// At the boundary: branch on identity/type, not on message text.
switch {
case errors.Is(err, ErrNotFound):
	http.Error(w, "not found", http.StatusNotFound)
case errors.As(err, &verr): // *ValidationError
	writeJSON(w, http.StatusBadRequest, errorBody{verr.Field, verr.Msg})
default:
	logger.Error("unhandled", "err", err)
	http.Error(w, "internal error", http.StatusInternalServerError) // no internals leaked
}
```

Aggregate independent failures with `errors.Join` (1.20+); `errors.Is`/`As` walk
the joined tree:

```go
err := errors.Join(closeDB(), flushCache(), drainQueue()) // nil if all nil
if err != nil {
	return fmt.Errorf("shutdown: %w", err)
}
```

**Rules**: wrap with `%w` when callers may want to unwrap; otherwise use `%v` to
opaque the cause. Never leak internal error text to API clients — map to a status
and a safe message (see [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md)).

## Structured Logging with slog (1.21+)

Use `slog` for JSON logs in production; attach request-scoped attributes via
`context`. One handler, configured once at startup.

```go
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
	Level: slog.LevelInfo,
}))
slog.SetDefault(logger)

// Per-request: derive a logger carrying the trace/request id.
func withRequestLogger(ctx context.Context, reqID string) context.Context {
	l := slog.Default().With("request_id", reqID)
	return context.WithValue(ctx, loggerKey{}, l)
}

// In a handler:
log := loggerFrom(ctx)
log.InfoContext(ctx, "order created",
	"order_id", o.ID,
	"amount_cents", o.AmountCents,
)
```

Never log secrets, tokens, full request bodies, or PII. Prefer
`InfoContext`/`ErrorContext` so handlers can enrich records from the context.
Fallback before 1.21: `zap`/`zerolog` with equivalent structured fields.

## Generics: Use Them Sparingly (1.18+)

Generics pay off for type-safe containers and small reusable helpers — not for
business logic that wants concrete types.

```go
// Good: a reusable, type-safe helper that would otherwise need interface{}.
func MapSlice[T, U any](in []T, f func(T) U) []U {
	out := make([]U, len(in))
	for i, v := range in {
		out[i] = f(v)
	}
	return out
}

// Constraint by an interface set when you need operators.
type Number interface{ ~int | ~int64 | ~float64 }

func Sum[N Number](xs []N) N {
	var total N
	for _, x := range xs {
		total += x
	}
	return total
}
```

Do not genericize a function used at one concrete type. Prefer an interface for
runtime polymorphism (a `Repository` boundary); prefer generics for compile-time
type identity across call sites.

## Range-over-func Iterators (baseline since 1.23)

Custom iterators with `iter.Seq[T]` / `iter.Seq2[K,V]` compose with `for ... range`
and stream without materializing slices. This is baseline on every supported
toolchain — adopt it freely; the fallback below only matters for legacy floors.

```go
func Lines(r io.Reader) iter.Seq2[int, string] {
	return func(yield func(int, string) bool) {
		sc := bufio.NewScanner(r)
		for n := 1; sc.Scan(); n++ {
			if !yield(n, sc.Text()) {
				return // consumer broke out — stop producing
			}
		}
	}
}

for n, line := range Lines(file) { process(n, line) }
```

Fallback before 1.23: return a slice (eager) or a channel + cancellation, or take
a `func(T) bool` callback.

## Stdlib-First Defaults

| Need | Reach for (stdlib) | Add a dependency only when |
|------|--------------------|-----------------------------|
| HTTP server/client + routing | `net/http` `ServeMux` (`GET /users/{id}`, `r.PathValue`, 1.22+) | Middleware trees → chi; opinionated framework → Gin/Echo |
| JSON | `encoding/json` | Hot-path perf proven by a benchmark → `sonic`/`go-json` |
| Logging / config / crypto | `log/slog`, `os.Getenv`, `crypto/rand` | Many config sources/precedence → `viper` |

`net/http`'s 1.22 `ServeMux` supports method+path patterns
(`mux.HandleFunc("GET /users/{id}", h)`) and `r.PathValue("id")` — many services
no longer need a router dependency.

## Diagnostics

| Symptom | Cause | Fix |
|---------|-------|-----|
| `errors.Is(err, ErrX)` always false | Wrapped with `%v` instead of `%w` | Wrap with `%w` so the chain is walkable |
| Error string comparison breaks after refactor | Branching on `err.Error()` text | Use sentinel + `errors.Is`, or typed + `errors.As` |
| Internal SQL/driver text reaches the client | Returning `err` straight to the response | Map to status + safe message at the boundary |
| `slog` output is unstructured text | `NewTextHandler` in production | Use `NewJSONHandler`; reserve text for local dev |
| Generic helper won't compile on a type | Constraint too narrow / missing `~` | Add `~int` etc. for named types; widen the set |
| `iter.Seq` / `for i := range n` won't compile | Legacy toolchain (< 1.23 / < 1.22 — below any supported floor) | Bump the `go` directive to a supported minor; only fall back on truly pinned legacy builds |
| `encoding/json/v2` symbols undefined | Built without `GOEXPERIMENT=jsonv2` (still experimental through 1.26) | Use `encoding/json` (v1); don't ship on v2 until it's the default in 1.27 |

## Related Skills

- [go-concurrency](../go-concurrency/SKILL.md) — goroutines, channels, `context`, `errgroup`, race detection
- [be-testing](${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md) — table-driven tests, Testcontainers, `go test -race`
- [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md) — input validation, injection/SSRF defense, error-message hygiene
- [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md) — OWASP API Security Top 10, auth boundaries
- [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md) — Go/runtime version minimums
