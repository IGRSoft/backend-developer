---
name: go-concurrency
description: >-
  Go concurrency for back-end services — goroutines and channels, context
  propagation and cancellation, sync primitives, errgroup, worker pools, and
  race/leak detection with go test -race. Use when writing or reviewing
  concurrent Go, propagating cancellation through a request, bounding
  parallelism, or triaging data races and goroutine leaks.
---

# Go Concurrency (safe, cancellable, leak-free)

**Every goroutine needs an owner, a stop signal, and a way to report failure. Plumb `context` everywhere; test with `-race`.**

## When to Use

Use this skill when:
- Launching goroutines and coordinating them with channels
- Propagating cancellation and deadlines through `context.Context`
- Choosing between channels and `sync` primitives (`Mutex`, `RWMutex`, `Once`, `WaitGroup`)
- Bounding parallelism with `errgroup` or a worker pool
- Triaging a data race (`go test -race`) or a goroutine leak

Routing: language idioms, errors, generics, slog →
[modern-go](../modern-go/SKILL.md). Deep patterns (pipelines, fan-out/fan-in,
semaphores, graceful shutdown, leak debugging) →
[references/concurrency-patterns.md](references/concurrency-patterns.md).

## Version Snapshot

| Feature | Since | Fallback before that version |
|---------|-------|------------------------------|
| Per-iteration loop variable (safe goroutine capture) | 1.22 | `v := v` shadow inside the loop |
| `context.WithCancelCause` / `context.Cause` | 1.20 | `context.WithCancel` + a separate error channel |
| `context.AfterFunc` | 1.21 | Spawn a watcher goroutine on `ctx.Done()` |
| `sync.OnceFunc` / `sync.OnceValue` | 1.21 | `sync.Once` + a captured closure |
| `golang.org/x/sync/errgroup` (`SetLimit`) | x/sync | Manual `WaitGroup` + buffered semaphore channel |

`errgroup` lives in `golang.org/x/sync`, not the stdlib — add it explicitly.
Canonical minimums: skill [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md).

## Context: Propagate, Cancel, Deadline

Pass `context.Context` as the first parameter through the whole call chain. Derive
per-operation deadlines; cancellation flows downward automatically.

```go
func (s *Service) Handle(ctx context.Context, req Request) (Response, error) {
	// Bound the downstream work; cancel propagates to DB driver, HTTP client, etc.
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel() // ALWAYS — releases the timer even on the happy path

	row, err := s.db.QueryRowContext(ctx, q, req.ID) // respects ctx deadline
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			return Response{}, fmt.Errorf("handle %s: %w", req.ID, ErrTimeout)
		}
		return Response{}, fmt.Errorf("handle %s: %w", req.ID, err)
	}
	_ = row
	return resp, nil
}
```

**Rules**: never store a `Context` in a struct; never pass `nil` — use
`context.TODO()` while wiring; always `defer cancel()`; check `ctx.Err()` in long
loops. Use `context.WithValue` only for request-scoped data (request id, auth
subject), never for optional parameters.

## Goroutines: Owner, Stop, Report

A bare `go f()` whose lifetime you cannot observe is a leak waiting to happen.

```go
// Anti-pattern: fire-and-forget with no cancellation, no error path.
go doWork() // who stops it? where does its error go?

// Pattern: errgroup gives every goroutine a stop signal and an error sink.
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(8) // cap concurrent goroutines

for _, id := range ids { // Go 1.22+: id is per-iteration, safe to capture
	g.Go(func() error {
		return s.process(ctx, id) // first non-nil error cancels ctx for the rest
	})
}
if err := g.Wait(); err != nil { // blocks until all return; returns first error
	return fmt.Errorf("batch: %w", err)
}
```

`errgroup.WithContext` cancels the shared `ctx` on the first error, so siblings
observing `ctx.Done()` stop early. `SetLimit(n)` bounds parallelism without a
manual semaphore. Full worker-pool and pipeline patterns:
[references/concurrency-patterns.md](references/concurrency-patterns.md).

## Channels vs sync Primitives

| Use a channel when | Use a `sync` primitive when |
|--------------------|------------------------------|
| Transferring ownership of data between goroutines | Guarding shared mutable state in place (`Mutex`) |
| Signaling completion / fan-out work | Read-mostly shared state (`RWMutex`) |
| Streaming a pipeline stage to the next | One-time lazy init (`Once`/`OnceValue`) |
| Selecting across cancellation + work (`select`) | Counting in-flight goroutines (`WaitGroup`) |

```go
// Mutex: guard the map; copy out under the lock, never expose the lock.
type Cache struct {
	mu sync.RWMutex
	m  map[string]Entry
}

func (c *Cache) Get(k string) (Entry, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	e, ok := c.m[k]
	return e, ok
}

// Lazy, race-free singleton init (1.21+).
var loadConfig = sync.OnceValue(func() Config { return readConfigFromEnv() })
```

"Share memory by communicating" is the default; a `Mutex` is right when state is
naturally co-located and the critical section is short. Never copy a value that
contains a `sync.Mutex` (vet flags this).

## Race & Leak Detection

The race detector is mandatory in CI. Run the suite under `-race`:

```sh
go test ./... -race                 # CI default — fails the build on any race
go test ./pkg/orders -race -run TestConcurrentApply
go build -race ./cmd/api            # race-enabled binary for a staging soak
```

A `-race` failure prints both conflicting accesses with stacks — fix the
synchronization, never silence it. For goroutine leaks, assert no growth across a
test with `goleak`, and profile a running service:

```sh
go test ./... -run TestNoLeak       # uber-go/goleak in TestMain
curl localhost:6060/debug/pprof/goroutine?debug=2   # net/http/pprof: live stacks
```

Evidence for a concurrency fix is the `go test -race` transcript (before: race
report; after: clean `ok`), plus a goroutine-count delta — not a build log.
Leak/deadlock debugging walkthrough: [references/concurrency-patterns.md](references/concurrency-patterns.md).

## Diagnostics

| Symptom | Cause | Fix |
|---------|-------|-----|
| `DATA RACE` on a map/field under `-race` | Unsynchronized concurrent access | Guard with `Mutex`/`RWMutex`, or pass via channel |
| Goroutines climb without bound | Leak — no cancellation or unread channel | Plumb `ctx`; ensure every send has a receiver and a `ctx.Done()` `select` |
| `all goroutines are asleep - deadlock!` | Unbuffered channel with no concurrent peer; circular wait | Add a reader/writer goroutine, buffer, or `select` with cancellation |
| Work keeps running after client disconnects | `ctx` not propagated to downstream calls | Thread `ctx` into DB/HTTP calls; check `ctx.Err()` in loops |
| `cancel` not called (timer leak) | Missing `defer cancel()` | Always `defer cancel()` right after `WithTimeout`/`WithCancel` |
| Closure captures last loop value | Toolchain < 1.22 loop semantics | Bump `go` to 1.22, or `v := v` inside the loop |
| `WaitGroup` reused/negative counter panic | `Add` after `Wait`, or copied by value | `Add` before launching; pass `*WaitGroup`, never a copy |
| `errgroup` swallows all but one error | By design — returns first error only | Use `errors.Join` per-goroutine, or collect via a results channel |

## Related Skills

- [modern-go](../modern-go/SKILL.md) — generics, error wrapping, slog, stdlib-first idioms
- [be-testing](${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md) — `go test -race`, table-driven tests, Testcontainers
- [be-performance](${CLAUDE_SKILL_DIR}/quality/be-performance/SKILL.md) — pprof, contention profiling, load testing
- [secure-coding](${CLAUDE_SKILL_DIR}/_shared/secure-coding/SKILL.md) — resource-consumption limits, SSRF defense
- [version-feature-matrix](${CLAUDE_SKILL_DIR}/_shared/version-feature-matrix.md) — Go/runtime version minimums
- [references/concurrency-patterns.md](references/concurrency-patterns.md) — pipelines, fan-out/fan-in, semaphores, graceful shutdown, leak debugging
