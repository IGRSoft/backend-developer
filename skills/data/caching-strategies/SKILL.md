---
name: caching-strategies
description: >-
  Cache correctly with Redis or Valkey: cache-aside and write-through patterns,
  invalidation, TTL and eviction policy, distributed locks, idempotency stores,
  rate-limit counters, and hot-key mitigation. Use when adding a cache, fixing
  stale reads, designing invalidation, building a rate limiter, making an
  endpoint retry-safe, or diagnosing a hot key.
---

# Caching Strategies

**A cache is a correctness liability you accept for speed — invalidation is the hard half**

## When to Use

Use this skill when:
- Adding a cache in front of a database or expensive computation
- Reads return stale data after a write (invalidation bug)
- Choosing TTL and an eviction policy
- Coordinating work across instances (distributed lock)
- Making a write endpoint safe to retry (idempotency)
- Building a rate limiter or counter
- One key gets disproportionate traffic (hot key)

When the real fix is a better query/index instead of a cache →
[query-optimization](../query-optimization/SKILL.md). Rate limiting as an API
control (OWASP API4) → [api-security](../../quality/api-security/SKILL.md).

## Caching Patterns

| Pattern | Write path | Read path | Use when |
|---------|-----------|-----------|----------|
| **Cache-aside** (lazy) | write DB, delete/invalidate cache | miss → load DB → set cache | default; read-heavy, tolerant of a cold first read |
| **Write-through** | write cache + DB synchronously | always hits warm cache | reads must be warm immediately; accepts write latency |
| **Write-behind** | write cache, async flush to DB | warm | high write volume, can tolerate loss window (rarely worth the risk) |

Cache-aside is the default. **Delete on write, don't update** — deleting is
idempotent and lets the next read repopulate from the source of truth; updating the
cache risks writing a value that loses a race with a concurrent DB write.

```ts
// Cache-aside read (Redis 8 / Valkey, node-redis / ioredis — same command surface)
async function getUser(id: string): Promise<User> {
  const key = `user:${id}`;
  const hit = await redis.get(key);
  if (hit) return JSON.parse(hit);

  const user = await db.user.findUniqueOrThrow({ where: { id } });
  // SET with TTL + NX-free; jitter the TTL to avoid synchronized expiry (stampede)
  await redis.set(key, JSON.stringify(user), "EX", 300 + Math.floor(Math.random() * 60));
  return user;
}

// Invalidate on write — delete, never patch
async function updateUser(id: string, patch: Partial<User>) {
  await db.user.update({ where: { id }, data: patch });
  await redis.del(`user:${id}`);   // next read repopulates from DB
}
```

## Invalidation & Consistency

- **Delete-on-write**, then let reads repopulate. Order: write DB → delete cache. If
  the delete fails, the entry self-heals at TTL.
- **TTL is the safety net**, not the primary mechanism — every cached value carries a
  TTL so a missed invalidation expires on its own. No infinite TTLs on mutable data.
- **Stampede / thundering herd**: when a hot key expires, many requests miss at once
  and hammer the DB. Mitigate with TTL **jitter** (above), a short lock so one request
  recomputes while others serve stale, or pre-warming.
- **Negative caching**: cache "not found" briefly to absorb lookups for missing keys,
  but keep the TTL short so a newly-created row appears quickly.

## TTL & Eviction

```
# redis.conf — bound memory and pick an eviction policy
maxmemory 2gb
maxmemory-policy allkeys-lru      # evict least-recently-used across all keys
```

| Policy | Behavior | Use for |
|--------|----------|---------|
| `allkeys-lru` / `allkeys-lfu` | evict LRU/LFU across all keys | a pure cache (everything expendable) |
| `volatile-lru` / `volatile-ttl` | evict only keys with a TTL | mixed cache + durable keys (locks, counters) |
| `noeviction` | reject writes when full | when losing any key is unacceptable (use a separate instance) |

- **Always set `maxmemory` + a policy** — an unbounded Redis OOMs the host.
- Keep cache data (evictable) and durable data (locks, idempotency keys, counters)
  on separate instances or use `volatile-*` so eviction never drops a lock.

## Distributed Locks

```ts
// Single-instance lock: SET key val NX PX ttl — atomic acquire with expiry
const token = crypto.randomUUID();
const ok = await redis.set(`lock:job:${id}`, token, "NX", "PX", 10_000);
if (!ok) return; // someone else holds it
try {
  await doWork();
} finally {
  // release only if WE still hold it (compare token) — Lua makes it atomic
  await redis.eval(
    `if redis.call("get",KEYS[1])==ARGV[1] then return redis.call("del",KEYS[1]) else return 0 end`,
    1, `lock:job:${id}`, token,
  );
}
```

- `SET ... NX PX` for acquire (atomic, with expiry so a crashed holder can't deadlock).
- Release **only if you still own it** (compare a unique token via Lua) — never blind
  `DEL`, or you'll release someone else's re-acquired lock.
- A single-node lock can be lost on failover. For correctness-critical mutual exclusion
  across a Redis cluster, use Redlock *(understand its trade-offs)* or push the
  invariant into the database (`SELECT ... FOR UPDATE`, unique constraint).

## Idempotency Stores

Make retried writes (network retries, at-least-once queues, client double-submit)
safe — store the result keyed by an idempotency key.

```ts
// Reserve the key atomically; if it existed, return the prior result
const idemKey = `idem:${request.headers["idempotency-key"]}`;
const reserved = await redis.set(idemKey, "in-progress", "NX", "EX", 86_400);
if (!reserved) {
  const prior = await redis.get(idemKey);
  return cachedResponseFor(prior);   // replay the first response, do NOT re-charge
}
const result = await chargeAndPersist(request); // the real, once-only side effect
await redis.set(idemKey, JSON.stringify(result), "EX", 86_400);
return result;
```

- Client sends an `Idempotency-Key`; the server reserves it `NX` before doing the
  side effect, and replays the stored response on duplicates.
- Pair the cache key with a DB uniqueness constraint on the key for durability —
  Redis is the fast path, the DB is the truth.

## Rate-Limit Counters & Hot Keys

```ts
// Fixed-window counter: INCR + EXPIRE on first hit (atomic via pipeline/Lua)
const key = `rl:${userId}:${Math.floor(Date.now() / 60000)}`; // per-minute bucket
const n = await redis.incr(key);
if (n === 1) await redis.expire(key, 60);
if (n > LIMIT) throw new TooManyRequests();
```

- `INCR` + `EXPIRE` for fixed-window; sliding-window or token-bucket (Lua script) for
  smoother limits. This is the storage behind OWASP API4 rate limiting — see
  [api-security](../../quality/api-security/SKILL.md).
- **Hot key** (one key, huge traffic — a viral item, a global counter): mitigate with
  a short local in-process cache (L1) in front of Redis (L2), client-side request
  coalescing, or sharding the counter into N sub-keys summed on read.

## Version Markers & Fallbacks

| Feature | Needs | Fallback |
|---------|-------|----------|
| `SET key val NX PX ttl` (atomic lock) | Redis 2.6.12+ / any Valkey | `SETNX` + separate `EXPIRE` (non-atomic — avoid) |
| `FUNCTION`/server-side functions | Redis 7.0+ / Valkey 7.2+ | `EVAL` Lua scripts |
| `CLIENT NO-EVICT` / fine ACLs | Redis 7.x+ / Valkey 7.2+ | network ACLs + separate instances |
| Hash-field TTL (`HEXPIRE`/`HGETEX`) | Redis 7.4+ / Valkey 8.1+ | separate keyed entries with per-key TTL |
| Valkey (BSD-3 open fork) | drop-in Redis-OSS replacement (LF-stewarded) | Redis 8 (AGPLv3) |
| `OBJECT FREQ` (LFU introspection) | `maxmemory-policy` set to `*-lfu` | `OBJECT IDLETIME` (LRU) |

**Redis 8 vs Valkey — license fork, same patterns.** Redis 8 (GA 2025) ships under AGPLv3 (plus source-available RSALv2/SSPLv1); Valkey is the permissive BSD-3 fork stewarded by the Linux Foundation (AWS/Google/Oracle-backed), a drop-in replacement for Redis OSS tracking the same command surface. Everything in this skill applies to both — choose per your license posture, not per feature. Confirm floors against the [version-feature-matrix](../../_shared/version-feature-matrix.md).

## Diagnostics

| Symptom | Cause | Fix |
|---------|-------|-----|
| Stale reads after a write | cache not invalidated, or updated instead of deleted | delete-on-write; add a TTL safety net |
| DB spikes when a key expires | cache stampede / thundering herd | TTL jitter, single-flight lock, pre-warm |
| Redis OOM / host killed | no `maxmemory` / eviction policy | set `maxmemory` + `allkeys-lru` (or `volatile-*`) |
| A lock is released by the wrong holder | blind `DEL` | compare-token release via Lua |
| Duplicate side effects on retry | no idempotency store | reserve `Idempotency-Key` `NX` before the side effect |
| One key saturates a shard (hot key) | skewed access | L1 local cache, request coalescing, sharded counter |
| Rate limiter off by a window | non-atomic `INCR`+`EXPIRE` race | atomic Lua, or `INCR` then `EXPIRE` only when `n==1` |

## Related Skills

- [query-optimization](../query-optimization/SKILL.md) — when a faster query beats a cache
- [orm-patterns](../orm-patterns/SKILL.md) — caching read models above the ORM
- [schema-design](../schema-design/SKILL.md) — read aggregates worth caching
- [api-security](../../quality/api-security/SKILL.md) — rate limiting (API4) and idempotency at the edge
- [be-performance](../../quality/be-performance/SKILL.md) — load testing cache hit ratios and latency
- [version-feature-matrix](../../_shared/version-feature-matrix.md) — Redis/Valkey version floors
