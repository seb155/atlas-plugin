---
name: performance-discipline
description: "Performance discipline doctrine — treat performance as a first-class build artifact like correctness. Use when reviewing code (especially AI-generated), planning new features, debating dependencies, or auditing hot paths. Triggers on: 'is this fast enough', 'check perf', 'review for performance', 'AI wrote this is it efficient', 'should we add this dependency', 'startup time', 'memory budget', 'optimize this loop', 'why is this slow', 'audit hot path'."
effort: medium
---

# Performance Discipline — Respect the Machine

> **Source doctrine**: Dave Plummer (ex-Microsoft, creator of Windows Task Manager), *"Why Modern Software Is So Slow"* (2026-04-19, Dave's Garage YouTube). Adopted by ATLAS as a behavior-shaping skill on 2026-04-19.
> **Scope**: User code (Synapse, axoiq-cloud, GMS App, atlas-plugin user-facing features). For ATLAS plugin's own meta-perf (hooks, build, atlas-assist tokens), see `.claude/rules/performance.md`.

---

## Core thesis (60 seconds)

Modern hardware is absurdly powerful. A 2026 laptop is thousands of times faster than a 1995 box. Yet many modern apps take longer to open a window than a 486 took to boot.

The reason is not that programmers got worse. **Standards quietly slid from excellent to acceptable.** We stopped enforcing budgets. We assumed someone else's hardware would eat the bill. We let abstractions hide cost. AI now writes plausible-but-not-lean code at industrial scale.

**The fix is not to ban abstractions or AI.** The fix is to make **performance a first-class build artifact**, gated like correctness, with explicit budgets and active review.

> *"AI is very good at creating code that clears the bar of 'it works'. It has no real native instinct for 'this is a hot path and every cycle here matters'. You have to impose that instinct from the outside."* — Dave Plummer (~13:00)

---

## When to invoke this skill

| Trigger context | Action |
|-----------------|--------|
| Reviewing a PR with > 50 LoC AI-generated code | Run the **8 AI anti-patterns** scan (see `references/anti-patterns-from-plummer.md`) |
| Planning a new feature (any size) | Apply the **3-question decision framework** (below) |
| Debating whether to add a dependency | Apply **dependency justification** (4 questions) |
| Touching code marked `@hot_path` | Read `performance-budget` skill (V2) for the budget; verify no regression |
| Auditing an existing endpoint / page | Cross-check against project's `.atlas/perf-budgets.yaml` (V2 — see `performance-budget` skill) |
| User asks "is this fast enough?" / "why is this slow?" | Diagnose using **whole-system understanding** (see Pillar 3 below) |

**DO NOT** invoke this skill for:
- Trivial changes (typo fixes, comment edits, single-line tweaks)
- Pure refactors that don't change runtime behavior
- Documentation-only PRs

---

## The 4 pillars

### Pillar 1 — Budgets explicit, not aspirational

A budget is a number with a unit and a consequence. It is **not** "we should be fast" or "let's keep an eye on memory."

Every meaningful feature ships with at least one of:

| Budget category | Example concrete budget |
|----------------|-------------------------|
| **Cold-start latency** | `chat-stream first SSE event ≤ 3000ms` (already in `synapse/scripts/smoke-endpoints.yml:83-85`) |
| **Steady-state memory** | `frontend idle ≤ 250 MB heap` |
| **Wakeups / polling** | `background sync ≤ 4 wakeups/min, exponential back-off on failure` |
| **Network round-trips** | `page load ≤ 3 RTT for above-the-fold content` |
| **Database query count** | `page render ≤ 5 queries; alert at 10` |
| **CPU at idle** | `app minimized ≤ 0.5% CPU` |
| **Bundle size** | `frontend route chunk ≤ 200 KB gzip` |
| **Allocation count** | `hot loop iteration ≤ 0 heap allocations` |

If a budget doesn't exist for the area you're touching, **propose one** in your PR description. Do not ship blind.

→ V2 of this work formalizes budgets in `.atlas/perf-budgets.yaml` (see future `performance-budget` skill).

### Pillar 2 — Dependencies are liabilities until proven useful

Every new dependency must answer **4 questions** in writing (PR description, ADR, or `decision-log` entry):

1. **What does this buy the user?** (not the team — the user)
2. **What does it cost the user?** (RAM, battery, bundle size, startup ms, security exposure)
3. **What's the alternative?** (existing utility, 30 LoC inline, do nothing)
4. **What's the removal plan if we change our mind?** (some deps become permanent because nobody can extract them — flag this risk early)

If the answer to #1 is "it lets us ship faster", be honest: you are spending the user's RAM and battery to save your schedule. Sometimes that trade is worth it. Often it is not. **At minimum, say it out loud.**

Existing dependency review tooling: `code-analysis` skill (`/atlas analyze dead-code` via vulture + ruff) detects unused. V3 of this work adds `dependency-justification` skill (workflow guided + JSONL log).

### Pillar 3 — Hot paths deserve human attention

A hot path is code that runs **either very often, or in a latency-critical context**. Examples in Synapse:

- `backend/app/services/pg_search_service.py` — ParadeDB BM25 query (every chat request, knowledge search)
- `backend/app/services/unified_chat_service.py` — chat stream orchestrator (5+ DI deps, must hit < 3s first event)
- `frontend/.../konva-canvas/*.tsx` — interactive diagram render (reference: `synapse/.claude/references/konva-perf.md`)
- `backend/app/services/ag_grid_data_service.py` — AG Grid 50K rows render

Mark them with `@hot_path` (Python decorator/comment, TS comment) so future maintainers (and AI) **know to write tight code there**.

In hot paths, default to:

- ❌ No allocations in the inner loop (preallocate, reuse buffers)
- ❌ No parsing twice (parse once, pass the parsed object)
- ❌ No buffer copies unless required by API boundary
- ❌ No ad-hoc DB queries (use prefetch, joins, batching)
- ✅ Measure before optimizing (profile shows where time goes)
- ✅ Comment the constraint (`# hot path: avoid allocations`)

### Pillar 4 — AI-generated code needs a different review lens

AI clears the bar of "it works." It does not have an instinct for hot paths. It tends to produce **median plausible code**: verbose, layered, defensive, over-allocated.

The danger is **not** the one obviously bad routine — that's easy to spot. The danger is **a thousand slightly-over-engineered chunks** that all pass tests, all look reasonable in review, and together produce a bloated, battery-hungry, mysteriously-slow product.

When reviewing AI-generated code:

1. Run the **8 AI anti-patterns** scan (see `references/anti-patterns-from-plummer.md`):
   - Base64 over byte-friendly transport
   - Layer-cake abstraction
   - Allocation in hot loop
   - N+1 queries
   - Parsing twice
   - Buffer copy without need
   - Idle background work without back-off
   - Defensive over-validation

2. Ask yourself: **"Did the AI choose the best transport, or the most familiar one?"** (Plummer's anecdote: AI sent video bits as base64-encoded JSON over a socket — the most inefficient way possible, but the most "JSON-shaped".)

3. If you cannot say "I would have written this the same way for a hot path", flag it.

This pillar is operationalized by an extension to `senior-review-checklist` (8th dimension, V1 task C1.2) and an enhanced trigger in `code-review` (V1 task C1.3).

---

## 3-question decision framework (apply per feature)

Before writing or accepting any non-trivial code change, answer:

1. **Does this respect a budget?** If yes, which one (link to `.atlas/perf-budgets.yaml` or smoke-endpoints.yml entry). If no, **propose one in this PR**.
2. **Does this add a dependency?** If yes, fill out the 4-question dependency justification in the PR description.
3. **Does this touch a hot path?** If yes, has a profile/benchmark been re-run? Are budgets still respected?

If all 3 answers are "yes" with evidence → ship.
If any answer is "no" or "unsure" → do not merge until resolved.

---

## Decision: when to defer to performance-budget skill (V2)

This skill (`performance-discipline`) carries the **doctrine** — the why and the lens.
The future `performance-budget` skill carries the **mechanics** — the YAML schema, the per-project budget enforcement, the regression % gate, the integration into `verification` L6.

Use this skill (`performance-discipline`):
- Code review with a perf lens
- New feature design
- Dependency debate
- Hot-path identification

Use `performance-budget` (V2, when shipped):
- Defining concrete budgets in `.atlas/perf-budgets.yaml`
- Running `atlas dev verify --layer L6 --check perf-budgets`
- Auditing budget regression on a PR

---

## Cross-references

- **ATLAS plugin meta-perf** (hooks, build, atlas-assist tokens): `.claude/rules/performance.md` (in atlas-plugin repo)
- **Synapse rule** (per-project enforcement, 7 rules graduated WARNING → ERROR): `synapse/.claude/rules/performance-discipline.md` (V1 task C1.4)
- **Future budget skill** (V2): `skills/performance-budget/` (gates `.atlas/perf-budgets.yaml`)
- **Future dependency skill** (V3): `skills/dependency-justification/` (4-question workflow + JSONL log)
- **Existing related skills**: `code-review`, `senior-review-checklist`, `verification` (L6 perf check), `code-analysis` (dead code), `code-simplify` (clarity)
- **Existing reference docs**: `synapse/.claude/references/konva-perf.md` (canvas perf patterns)
- **Anti-patterns deep dive**: `references/anti-patterns-from-plummer.md` (this skill folder)

---

## ATLAS philosophy alignment

This skill honors `docs/PHILOSOPHY.md`:
- **Principle 1** (skills are behavior-shaping code): this skill changes how Claude reviews code — ran through skill-triggering eval before merge
- **Principle 2** (deterministic core, AI-accelerated periphery): the doctrine is human/AI-judgment; the budgets (V2) are deterministic YAML
- **Principle 3** (frameworks before frictions): one skill replaces "remember to check perf each time" — reduces cognitive load
- **Principle 5** (testing funnel sacred): V2 ties perf into G2/G3 gates without weakening G0/G1
- **Principle 7** (tiered architecture for scale): placed in `dev-addon` only (not core overlay) to avoid 75% dup risk

---

## Red flags (when this skill's advice does NOT apply)

- **Non-hot-path code** (config loaders, one-time setup, admin tools) — apply standard rigor, not paranoid optimization
- **Demo / prototype code** with explicit lifetime cap — perf discipline is overhead until the path proves it'll live
- **Standard library APIs you don't control** — diagnose, route around, file an upstream issue; don't fork

When in doubt, **ask the user before introducing optimization complexity** — premature optimization is a real failure mode separate from "no perf discipline."
