# Parallelism Safety Guide

## Core Principle

Multiple Agent tool calls issued in **the same message** execute concurrently.
Multiple Bash calls with `run_in_background: true` in **the same message** also run concurrently.
This is the mechanism for parallelism — no special API, just message batching.

---

## What Is Safe to Parallelize

### 1. Explore / Read-Only Agents

Any number of agents that only read files, search code, or fetch docs can run in parallel.
Reads never conflict with each other.

```
# Safe — all in one message
Agent 1: "Search backend/services/ for existing spec_grouping patterns."
Agent 2: "Search frontend/src/hooks/ for TanStack Query hooks related to tags."
Agent 3: "Read .blueprint/PATTERNS.md and summarize form-submission patterns."
```

**Used in:** `executing-plans` (Parallel Explore Phase)

---

### 2. Code Review Agents

Three specialized review agents can analyze the same diff simultaneously. Each agent
has a single focused responsibility — they do not write files.

```
# Safe — all in one message
Agent 1 (Bug & Logic):      reads diff → reports correctness issues
Agent 2 (Convention/Style): reads diff → reports CLAUDE.md violations
Agent 3 (Simplification):   reads diff → reports DRY / complexity issues
```

**Used in:** `code-review` (Parallel Review)

---

### 3. Independent Test Suites

Backend (pytest), frontend (vitest), and type-check (tsc) touch separate processes
and file systems. Run with `run_in_background: true`.

```bash
# Safe — all in one message, run_in_background: true on each
pytest tests/ -x -q --tb=short   # process 1
bunx vitest --run                 # process 2
bun run type-check                # process 3
```

**Safety gate:** DB migrations must complete sequentially **before** any test runner starts.

**Used in:** `verification` (Parallel Test Execution)

---

### 4. Research Queries

Independent WebSearch calls, Context7 queries, and WebFetch calls for different URLs
can all run in parallel. Each query hits a different external endpoint.

```
# Safe — all in one message
WebSearch: "React 19 concurrent features 2026"
WebSearch: "TanStack Query v5 suspense patterns"
Context7 resolve-library-id: "tanstack-query"
```

**Used in:** `deep-research` (Parallel Research Queries)

---

### 5. Tasks Touching Different Files (No Shared State)

Implementation tasks that modify non-overlapping files can be dispatched in parallel.
Build a dependency graph first — tasks with no `blockedBy` and no shared files are
parallel-safe.

```
Task A: backend/services/my_service.py    ← no deps, unique file
Task B: frontend/src/hooks/use-my.ts      ← no deps, unique file
→ Launch A and B in parallel

Task C: frontend/src/pages/MyPage.tsx     ← imports B
→ Launch C only after B completes (sequential)
```

Use `isolation: "worktree"` in the Agent call for extra safety on write tasks.

**Used in:** `subagent-dispatch` (Parallel Independent Tasks)

---

## What Is NEVER Safe to Parallelize

| Operation | Reason |
|-----------|--------|
| Git commit / push / merge / tag | Shared git index — will corrupt history |
| DB migrations (Alembic) | Schema state is sequential by design |
| Two agents writing the same file | Last write wins — one result is lost |
| Deployment steps (docker build, ssh deploy) | Ordering matters for health |
| Tasks with explicit `blockedBy` dependency | Output of one feeds input of another |
| Playwright E2E + backend restart | E2E requires stable backend during run |
| Security scan + deploy | Scan must pass before deploy starts |

**If in doubt: sequential is always safe. Parallel requires explicit verification that
no shared state exists.**

---

## Pattern Reference

### Pattern A — Parallel Explore (read-only agents)

```
Message N (all in same message):
  Agent("Search backend/ for {topic} patterns")
  Agent("Search frontend/ for {topic} hooks")
  Agent("Read PATTERNS.md for {topic} conventions")

Message N+1 (after all complete):
  Consolidate → begin implementation
```

### Pattern B — Parallel Review (read-only agents)

```
Message N (all in same message):
  Agent("Bug & Logic review of diff: {diff}")
  Agent("Convention review of diff: {diff}")
  Agent("Simplification review of diff: {diff}")

Message N+1 (after all complete):
  Deduplicate → apply confidence filter → present unified report
```

### Pattern C — Parallel Tests (background bash)

```
# Sequential prerequisite:
Bash: alembic upgrade head   ← WAIT for completion

# Parallel launch (same message, run_in_background: true):
Bash (bg): pytest tests/ -x -q --tb=short
Bash (bg): bunx vitest --run
Bash (bg): bun run type-check

# After all 3 notify completion:
Read results → compile verification report
```

### Pattern D — Parallel Research

```
Message N (all in same message):
  WebSearch("{angle 1 query} 2026")
  WebSearch("{angle 2 query} 2026")
  Context7 resolve-library-id("{relevant lib}")

Message N+1 (sequential, depend on search results):
  WebFetch(top URL from angle 1)
  WebFetch(top URL from angle 2)

Message N+2:
  Synthesize → structured summary → cite sources
```

### Pattern E — Parallel Implementation (different files)

```
# Build dependency graph first:
# Task A → file X   (no deps)
# Task B → file Y   (no deps)
# Task C → file Z   (depends on B)

Message N (all in same message):
  Agent(Task A — implement file X, run tests for X)
  Agent(Task B — implement file Y, run tests for Y)

Message N+1 (after A and B complete):
  Agent(Task C — implement file Z using B's output)
```

---

## Consolidating Results from Parallel Agents

When multiple agents return results simultaneously:

1. **Collect all outputs** before acting on any single one
2. **Deduplicate** — same finding from 2 agents = 1 finding
3. **Resolve conflicts** — if agents disagree, flag for human review
4. **Merge context** — combine file maps, pattern lists, issue lists
5. **Then act** — implementation or reporting starts only after consolidation

---

## Performance Expectations

| Scenario | Sequential | Parallel | Speedup |
|----------|-----------|---------|---------|
| 3 explore agents (read) | ~90s | ~35s | ~2.5x |
| 3 review agents (read) | ~120s | ~45s | ~2.7x |
| 3 test suites (bg bash) | ~180s | ~75s | ~2.4x |
| 3 research queries | ~60s | ~25s | ~2.4x |
| 2 impl tasks (diff files) | ~240s | ~110s | ~2.2x |

Typical gain: **2-4x on multi-phase workflows** where phases contain 3+ independent tasks.

---

## Skills That Use This Guide

| Skill | Parallel Pattern Used |
|-------|-----------------------|
| `executing-plans` | Pattern A (Explore Phase) |
| `code-review` | Pattern B (Review Phase) |
| `verification` | Pattern C (Test Suites) |
| `deep-research` | Pattern D (Research Queries) |
| `subagent-dispatch` | Pattern E (Implementation Tasks) |

*Updated: 2026-03-18*
