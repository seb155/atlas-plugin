# 8 AI-Generated Code Anti-Patterns (from Plummer doctrine)

> Source: Dave Plummer, *"Why Modern Software Is So Slow"* (2026-04-19)
> Companion to: `skills/performance-discipline/SKILL.md`
> Use this reference when reviewing AI-generated code, especially diffs > 50 LoC, or when the `code-review` skill triggers the 8th `senior-review-checklist` dimension.

---

## How to use this reference

For each pattern below:
1. **Symptom** — what the bad code looks like
2. **Why AI writes it** — the training-data bias that produces it
3. **Heuristic** — how to grep / detect it programmatically
4. **Fix** — what the lean version looks like
5. **When the bad version is OK** — every rule has exceptions; spell them out

Severity legend: 🔴 HIGH (block merge / fix before ship) | 🟡 MED (PR comment / fix this sprint) | 🟢 LOW (note for next refactor)

---

## Pattern 1 — Base64 over byte-friendly transport 🔴 HIGH

**Symptom**:
```python
# Sending image bytes over a websocket as JSON
payload = {"frame": base64.b64encode(image_bytes).decode("utf-8")}
await websocket.send_json(payload)
```

**Why AI writes it**: training data has thousands of examples of "JSON-in / JSON-out" web APIs. Bytes-as-JSON-via-base64 is the most copy-paste-able pattern. AI optimizes for **familiarity**, not transport efficiency. Plummer's anecdote (~10:18): his Robotron AI did exactly this on a socket interface he'd already built for raw bytes.

**Cost**: base64 inflates payload by ~33%, plus JSON parsing/serialization overhead on both sides, plus an extra string allocation per frame. On a 30 fps video stream that's ~30× wasted bandwidth + CPU.

**Heuristic**:
```bash
rg -n 'b64encode|btoa\(' --type py --type ts -A 3 | grep -E 'send|write|publish|emit'
```

**Fix**: send raw bytes over the byte-capable channel.
```python
await websocket.send_bytes(image_bytes)
```

**When base64 IS OK**:
- Embedding small icons in JSON config (one-time, < 10 KB, won't change)
- Logging/auditing where the payload must be text-safe
- Crossing an explicit text-only boundary (email body, terminal output)

---

## Pattern 2 — Layer-cake abstraction 🟡 MED

**Symptom**: a single feature (e.g., a dropdown menu) pulls in 6 transitively-dependent frameworks. The dependency tree visualization looks like a fern.

**Why AI writes it**: AI suggests popular packages because they appear most in training data. It doesn't see the transitive cost. It also tends to produce one-class-per-concern structures even when 30 lines of inline code would do.

**Cost**: bundle bloat, slower cold start (more JS to parse/eval), security exposure (more code paths to audit), longer dependency-update churn.

**Heuristic** (for a feature suspected of bloat):
```bash
# Frontend
bunx depcheck && bunx bundle-stats
# Backend
pipdeptree | grep <feature-package> -A 20
```

**Fix**: ask the dependency justification 4 questions (Pillar 2 of `SKILL.md`). If the feature can be done in < 100 LoC inline, do that instead.

**When layer-cake IS OK**:
- Feature is genuinely complex (auth, charts, rich-text editor) — building from scratch is real effort
- Library is a reference implementation maintained by domain experts (e.g., `react-aria` for accessibility)
- Removal plan is plausible (the dep is at one well-defined boundary, not 50 import sites)

---

## Pattern 3 — Allocation in hot loop 🟡 MED

**Symptom**:
```python
def process_rows(rows):
    for row in rows:
        result = {"id": row[0], "name": row[1]}  # new dict per iteration
        results.append(result)
```

**Why AI writes it**: training data has more "make a dict for each item" examples than "preallocate then mutate". The dict-per-iteration pattern reads naturally. AI doesn't model GC pressure.

**Cost**: at 50K rows × N requests/min, the GC cost dominates. AG Grid render in Synapse hits this directly.

**Heuristic** (Python):
```bash
# Find dict/list literals inside for loops in @hot_path-marked files
rg -n -A 5 '@hot_path|# hot path' --type py | grep -E '\bfor\b' -A 5 | grep -E '^\s+\w+\s*=\s*[\{\[]'
```

**Fix**:
```python
def process_rows(rows):
    out = [None] * len(rows)  # preallocate
    for i, row in enumerate(rows):
        out[i] = (row[0], row[1])  # tuple is cheaper than dict
    return out
```

For Python, tuples beat dicts; for JS/TS, plain objects beat `Map` for small fixed-shape data.

**When allocation in hot loop IS OK**:
- The loop runs ≤ 100 iterations / never (cold path)
- The allocation is the data being returned to the caller (necessary, not waste)
- Profiling shows the allocation is < 5% of loop time

---

## Pattern 4 — N+1 queries 🔴 HIGH

**Symptom**:
```python
async def list_with_authors(post_ids):
    posts = await db.fetch_all("SELECT * FROM posts WHERE id IN :ids", ids=post_ids)
    for post in posts:
        post["author"] = await db.fetch_one(
            "SELECT * FROM users WHERE id = :id", id=post["author_id"]
        )  # 1 query per post — death by a thousand round-trips
    return posts
```

**Why AI writes it**: the iteration is naturally readable. AI tends to write the obvious imperative version. Modern ORMs (Prisma, SQLAlchemy) make the trap easier — `post.author` is "just" a property access that triggers a query.

**Cost**: 1 + N round-trips. At N=100, even on a local DB, that's seconds of latency. On a network DB, it's a timeout.

**Heuristic**:
```bash
# Python
rg -n -B 2 -A 4 'await\s+\w+\.(fetch|execute|query)' --type py | grep -E 'for|while' -B 4
# TypeScript
rg -n -B 2 -A 4 'await\s+\w+\.(findMany|findOne|query)' --type ts | grep -E 'for|map' -B 4
```

**Fix**: batch with `IN`, `JOIN`, or ORM `prefetch_related` / `include`.
```python
async def list_with_authors(post_ids):
    posts = await db.fetch_all(
        "SELECT p.*, u.name as author_name "
        "FROM posts p JOIN users u ON p.author_id = u.id "
        "WHERE p.id = ANY(:ids)",
        ids=post_ids,
    )
    return posts
```

**When N+1 IS OK**:
- Truly never (this one's hard-line — N+1 is almost always wrong)
- Exception: N is bounded ≤ 3 (e.g., a page with 3 widget queries) and adding the JOIN materially complicates the SQL

---

## Pattern 5 — Parsing twice 🟢 LOW

**Symptom**:
```typescript
const cloned = JSON.parse(JSON.stringify(originalObject));  // deep clone via serialization
```

**Why AI writes it**: it's the "everyone knows" deep-clone idiom. Simple, no dependencies. AI suggests it because Stack Overflow loves it.

**Cost**: serializes + reparses every field, drops Date/RegExp/functions silently, slow on large objects.

**Heuristic**:
```bash
rg -n 'JSON\.parse\(JSON\.stringify' --type ts --type js
rg -n 'json\.loads\(json\.dumps' --type py
```

**Fix**:
- Use `structuredClone(obj)` (modern JS, handles cycles + Date)
- For Python use `copy.deepcopy()`
- For partial clones, just spread / dict copy

**When `JSON.parse(JSON.stringify())` IS OK**:
- Deliberately stripping non-serializable fields (you want Date → string, function → undefined)
- Crossing a serialization boundary anyway (sending to a worker that needs JSON)

---

## Pattern 6 — Buffer copy without need 🟡 MED

**Symptom**:
```python
def write_to_socket(data: bytes):
    buf = bytes(data)  # unnecessary copy of an already-immutable bytes
    socket.send(buf)
```

**Why AI writes it**: defensive style — "make a copy to be safe." AI doesn't model the immutability of `bytes` (Python) or the zero-cost slice of `Uint8Array.subarray` (JS).

**Cost**: 2× memory at the moment of the call, GC pressure on small frequent writes.

**Heuristic**:
```bash
# Python
rg -n '@hot_path|# hot path' --type py -A 30 | grep -E '\bbytes\(|\.copy\(\)|bytearray\('
# JS/TS
rg -n '@hot_path|// hot path' --type ts -A 30 | grep -E 'Buffer\.from|new Uint8Array\(.+\)'
```

**Fix**: pass the original; if a mutation is needed, mutate in-place or return a new object only at the boundary.

**When buffer copy IS OK**:
- Crossing a thread boundary where the original is mutable and may change
- Calling into FFI / native code that requires owned memory
- Defensive at a public API boundary (untrusted input)

---

## Pattern 7 — Idle background work without back-off 🟡 MED

**Symptom**:
```typescript
setInterval(() => {
  fetch("/api/sync").then(handleSync);
}, 1000);  // pings every second forever, no back-off, no clear, no when-tab-hidden pause
```

**Why AI writes it**: "make it stay in sync" → the obvious answer is `setInterval`. AI doesn't surface visibility-API integration, exponential back-off, or unmount cleanup unless prompted.

**Cost**: drains battery on mobile, wastes server CPU + bandwidth, accumulates if the user opens 5 tabs, never shuts down on error.

**Heuristic**:
```bash
rg -n 'setInterval\(' --type ts --type js -A 3 | grep -v 'clearInterval'
rg -n 'asyncio\.sleep\(' --type py -A 5 | grep -E 'while True|while 1'
```

**Fix**:
```typescript
const sync = async () => {
  if (document.hidden) return;  // pause when tab hidden
  try {
    await fetch("/api/sync").then(handleSync);
    delay = 1000;  // reset on success
  } catch {
    delay = Math.min(delay * 2, 60_000);  // back-off on failure, cap 60s
  } finally {
    timer = setTimeout(sync, delay);
  }
};
let delay = 1000;
let timer = setTimeout(sync, delay);
// On unmount: clearTimeout(timer);
```

**When constant interval IS OK**:
- Animation frame (use `requestAnimationFrame`, not `setInterval`)
- Local-only timer (clock display, no I/O)
- The "every N seconds" is a hard product requirement and N is large (≥ 60s)

---

## Pattern 8 — Defensive over-validation 🟢 LOW

**Symptom**:
```python
def get_user_name(user):
    if user is None:
        return ""
    if not isinstance(user, dict):
        return ""
    if "name" not in user:
        return ""
    if not isinstance(user["name"], str):
        return ""
    return user["name"]
```

**Why AI writes it**: AI is trained to "handle edge cases" and verbose defensive code looks rigorous in eval. It also satisfies type-checkers without thought.

**Cost**: 4 branches on a hot path = branch-prediction misses + L1 cache pressure. Worse: it **hides bugs** — if `user` is None when it shouldn't be, the silent empty string masks the upstream error.

**Heuristic** (advisory; high false-positive):
```bash
rg -n 'if.*is None|if not isinstance' --type py -A 1 | grep -B 1 'return ""\|return None\|return \[\]'
```

**Fix**: assert at the boundary, trust internally.
```python
def get_user_name(user: User) -> str:
    return user.name  # User is a typed dataclass, not a dict — invariants enforced at boundary
```

**When defensive validation IS OK**:
- Public API (HTTP endpoint, untrusted input) — validate at the boundary
- Data crossing a serialization / IPC boundary
- Migrating legacy data with known schema drift

---

## How this list evolves

This list is the **starting set** (V1). As we encounter new AI-output patterns in PR review, add them here with the same 5-section structure.

Future automation (V3): semgrep rules for patterns 1, 4, 7 (high-confidence detection), advisory `[mock-budget]`-style PR comments for 2, 3, 5, 6, 8.

Track instances by adding a `[perf-pattern-N]` PR label when reviewing — over time, this dataset informs which patterns deserve deeper tooling investment.

---

## References

- Plummer source video: https://www.youtube.com/watch?v=t992ul_IKtc (transcript: `synapse/data/transcripts/transcript_t992ul_IKtc.txt`)
- ATLAS plan: `synapse/.blueprint/plans/ultrathink-analyse-attentivement-ce-parallel-clock.md`
- Synapse rule (companion): `synapse/.claude/rules/performance-discipline.md`
- Companion skill: `skills/performance-discipline/SKILL.md`
- Pattern reference for semgrep automation (V3): `synapse/.semgrep/synapse-no-internal-mock.yaml` (proven advisory→blocking rollout)
