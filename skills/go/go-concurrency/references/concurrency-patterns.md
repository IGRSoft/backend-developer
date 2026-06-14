# Go Concurrency Patterns (deep dive)

Composable patterns for back-end services: bounded parallelism, pipelines,
graceful shutdown, and leak/deadlock debugging. Companion to
[../SKILL.md](../SKILL.md).

## Worker Pool (bounded parallelism)

Use a fixed pool when you want a stable number of workers draining a queue, with
backpressure from a bounded channel. Prefer `errgroup.SetLimit` for one-shot
batches; prefer an explicit pool for a long-lived consumer.

```go
func ProcessAll(ctx context.Context, jobs <-chan Job, workers int) error {
	g, ctx := errgroup.WithContext(ctx)
	for i := 0; i < workers; i++ {
		g.Go(func() error {
			for {
				select {
				case <-ctx.Done():
					return ctx.Err()
				case j, ok := <-jobs:
					if !ok {
						return nil // channel closed: producer is done
					}
					if err := handle(ctx, j); err != nil {
						return fmt.Errorf("job %s: %w", j.ID, err)
					}
				}
			}
		})
	}
	return g.Wait()
}
```

The producer owns `jobs` and is the only one that closes it. Workers exit on
either a closed channel (normal) or `ctx.Done()` (cancelled). `errgroup` cancels
`ctx` on the first error, draining the rest.

## Fan-Out / Fan-In

Split a stream across N workers, then merge results. Every stage selects on
cancellation so a slow or aborted consumer never strands producers.

```go
func fanIn[T any](ctx context.Context, chans ...<-chan T) <-chan T {
	out := make(chan T)
	var wg sync.WaitGroup
	wg.Add(len(chans))
	for _, ch := range chans {
		go func(c <-chan T) {
			defer wg.Done()
			for v := range c {
				select {
				case out <- v:
				case <-ctx.Done():
					return
				}
			}
		}(ch)
	}
	go func() { wg.Wait(); close(out) }() // close out only after all feeders drain
	return out
}
```

Rule: the goroutine that owns a channel closes it; downstream goroutines only
receive. Closing from the receive side causes "send on closed channel" panics.

## Pipeline

Chain stages where each is a function `<-chan In -> <-chan Out`. Cancellation
propagates by closing upstream or via `ctx`.

```go
func stage[I, O any](ctx context.Context, in <-chan I, f func(I) O) <-chan O {
	out := make(chan O)
	go func() {
		defer close(out)
		for v := range in {
			select {
			case out <- f(v):
			case <-ctx.Done():
				return
			}
		}
	}()
	return out
}

// nums -> squares -> negatives, each stage its own goroutine.
out := stage(ctx, stage(ctx, gen(ctx, 1, 2, 3), square), negate)
```

## Semaphore (cap concurrency without a pool)

When you want to launch one goroutine per item but cap how many run at once, use a
buffered channel as a counting semaphore (or `errgroup.SetLimit`).

```go
sem := make(chan struct{}, maxConcurrent)
var wg sync.WaitGroup
for _, u := range urls {
	wg.Add(1)
	go func(u string) {
		defer wg.Done()
		sem <- struct{}{}        // acquire (blocks at the limit — backpressure)
		defer func() { <-sem }() // release
		fetch(ctx, u)
	}(u)
}
wg.Wait()
```

This also doubles as a rate/resource limit for outbound calls — pair it with
`api-security`'s unrestricted-resource-consumption (API4) defenses. On Go 1.25+,
`wg.Go(func(){ … })` replaces the `wg.Add(1)` + `go func(){ defer wg.Done(); … }()`
boilerplate above (one call, no `Add`/`Done` mismatch); `errgroup.SetLimit` remains
the choice when a worker can return an error.

## Graceful Shutdown

Drain in-flight work on SIGTERM with a deadline; refuse new work; cancel the rest.

```go
func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	srv := &http.Server{Addr: ":8080", Handler: mux}
	errCh := make(chan error, 1)
	go func() { errCh <- srv.ListenAndServe() }()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		shutCtx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
		defer cancel()
		return srv.Shutdown(shutCtx) // stop accepting, drain in-flight requests
	}
}
```

Set the drain deadline below your orchestrator's termination grace period (e.g.
Kubernetes `terminationGracePeriodSeconds`) so the platform doesn't SIGKILL
mid-drain. Close background workers and flush logs/metrics after `Shutdown`
returns.

## Debugging Leaks and Deadlocks

| Symptom | How to find it | Fix |
|---------|----------------|-----|
| Goroutine count grows over time | `curl localhost:6060/debug/pprof/goroutine?debug=2` and diff stacks; `uber-go/goleak` in `TestMain` | Find the blocked send/receive; add `ctx.Done()` `select` or ensure the channel is drained/closed |
| Test hangs forever | `go test -timeout 30s`; the panic dumps all goroutine stacks | Trace the circular wait; buffer a channel or reorder lock acquisition |
| `fatal error: all goroutines are asleep - deadlock!` | Runtime detects no runnable goroutine | Ensure every unbuffered send has a concurrent receiver; avoid waiting on yourself |
| Intermittent wrong results under load | `go test -race -count=10` | Add synchronization at the flagged accesses |
| Lock held too long, latency spikes | `pprof` block/mutex profiles (`runtime.SetMutexProfileFraction`) | Shrink the critical section; switch to `RWMutex` or sharding |

`goleak` skeleton:

```go
func TestMain(m *testing.M) {
	goleak.VerifyTestMain(m) // fails if goroutines outlive the tests
}
```

Evidence for a concurrency fix is the `go test -race` transcript and a
goroutine-count delta from pprof — not a build log. See
[be-performance](${CLAUDE_SKILL_DIR}/quality/be-performance/SKILL.md) for the
pprof/contention-profiling workflow.

## Related

- [../SKILL.md](../SKILL.md) — goroutines, channels, context, errgroup, race detection
- [../../modern-go/SKILL.md](../../modern-go/SKILL.md) — error wrapping for goroutine error sinks
- [be-testing](${CLAUDE_SKILL_DIR}/quality/be-testing/SKILL.md) — `-race`, `goleak`, Testcontainers
- [api-security](${CLAUDE_SKILL_DIR}/quality/api-security/SKILL.md) — resource-consumption limits (API4)
