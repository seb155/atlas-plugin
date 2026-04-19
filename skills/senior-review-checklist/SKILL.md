---
name: senior-review-checklist
description: "Macro-level code review checklist. Use when invoked by code-review, when the user asks to 'senior review', 'SOLID audit', 'code smells check', or before shipping any non-trivial change needing architectural rigor."
effort: medium
refs:
  - code-smells-catalog
  - sota-architecture-patterns
---

# Senior Review Checklist

A systematic checklist for code review at senior level. Runs through 7 dimensions — score each
dimension, then synthesize findings into actionable feedback.

This skill is invoked by:
- `code-review` skill (as mandatory step after diff load + LSP blast-radius check)
- Manual invocation: "run senior review on this PR"

**NOT for:** style nits, formatting, linter-catchable issues (those belong to lint + shellcheck).

## Red Flags (rationalization check)

Before skipping the senior checklist, ask yourself — are any of these thoughts running? If yes, STOP. "Quick glance" reviews let design smells pass that rot the codebase for months.

| Thought | Reality |
|---------|---------|
| "Quick glance is fine for this PR" | Only trivial (style-only, single-line) PRs skip. 50+ lines or 3+ files = full checklist. |
| "Correctness is obvious" | Race conditions, silent except-pass, null at boundaries are NOT obvious. Use the rubric. |
| "Design weight can be eyeballed" | God Class (>500 lines), Long Method (>50 lines), Primitive Obsession have measurable thresholds. Score them. |
| "SOLID is academic" | S (Single Resp), L (Liskov), I (Interface Segregation) failures = fragile code. Grade each. |
| "Naming is a personal preference" | Naming = documentation. Ambiguous names force 2x reading on every future session. |
| "Testability is for the test author" | Testable code is by design — tight coupling = unobservable code. Flag before merge. |
| "Observability is the ops team problem" | No logging on a new mutation endpoint = incident 3 weeks later with no trace. Flag it. |
| "I'll use intuition, not the catalog" | code-smells-catalog + sota-architecture-patterns are structured. Intuition misses 40%. |

## 7 Review Dimensions

### 1. Correctness (40% weight)

Questions:
- Does the code DO what the PR description says?
- Are edge cases handled (empty input, null, concurrency, failures)?
- Are error paths correct (not silently swallowed, not too broad)?
- Are race conditions possible (shared state, async)?
- Are unit tests covering the main paths AND the error paths?

Red flags:
- `except: pass` or `catch (e) {}` — silent failure
- No tests for the new behavior
- Missing null/empty checks at API boundaries
- Mutating shared state without lock

### 2. Design (20% weight)

Use `code-smells-catalog` as reference. Check for:

- **God Class** — file > 500 lines or class > 300 lines
- **Long Method** — function > 50 lines or cyclomatic > 10
- **Long Parameter List** — function > 4 params (introduce Parameter Object)
- **Primitive Obsession** — many `str`/`int` for domain concepts (use Value Object)
- **Feature Envy** — method uses foreign data more than own (Move Method)
- **Shotgun Surgery** — one logical change edits many files (missing abstraction)
- **Copy-Paste** — 3+ duplicated blocks (Extract Method/Class)

Red flags:
- > 3 code smells in one PR
- New God Class or Long Method introduced
- Duplication not extracted

### 3. SOLID Compliance (10% weight)

Quick SOLID check:

| Principle | Check |
|-----------|-------|
| **S**ingle Responsibility | Does this class change for one reason? |
| **O**pen/Closed | Can I extend this without modifying it? |
| **L**iskov Substitution | Do subclasses honor the parent contract? |
| **I**nterface Segregation | Are interfaces small and focused? |
| **D**ependency Inversion | Does domain depend on abstractions, not concretions? |

Red flag: changes break SOLID without a pragmatic justification.

### 4. Naming (10% weight)

Questions:
- Are names precise and unambiguous? (`data` → `parsed_order`)
- Do function names describe WHAT (`calculate_total`) not HOW (`sum_and_tax`)?
- Are booleans phrased as questions? (`is_valid`, `has_permission`)
- Are domain concepts consistent with ubiquitous language?

Red flags:
- Generic names: `data`, `handle`, `process`, `manage`, `do`
- Abbreviations that aren't standard (`usr`, `mgmt`, `ctrl` for non-MVC)
- Type-bearing names (`user_dict`, `items_list`)

### 5. Cohesion & Coupling (10% weight)

Questions:
- Is each module focused on ONE thing? (cohesion)
- Do modules depend on a minimum number of other modules? (coupling)
- Are cross-module calls flowing in ONE direction? (no cycles)

Tools (for automated checks):
- `madge --circular src/` — detect circular imports (JS/TS)
- Python: `python -m pyflakes` + import graph analysis
- LSP `findReferences` to count dependencies per module

Red flags:
- Circular imports introduced
- One module importing > 10 other modules (low cohesion)
- Cross-cutting concerns not extracted to shared layer

### 6. Testability (5% weight)

Questions:
- Can each new unit be tested in isolation (no DB/network)?
- Are side effects (IO, clocks, random) injected (not hardcoded)?
- Are there seams for mocking (interfaces, DI, factories)?

Red flags:
- New code calls `datetime.now()`, `random.choice()`, `requests.get()` directly
- Tests rely on DB state or network
- Impossible to test without spinning up full stack

### 7. Observability & Ops (5% weight)

Questions:
- Are new errors logged with context (not just `logger.error("failed")`)?
- Do new endpoints have metrics/traces?
- Are audit-relevant actions (mutations, security) logged with actor + target?
- Does failure path leave system in a recoverable state (not corrupted)?

Red flags:
- New mutation without audit log (enterprise rule)
- New endpoint without project_id filter (multi-tenant rule)
- Errors logged without correlation ID / trace_id

## Scoring

For each dimension, score 0-5:
- **0** = broken/missing (blocker)
- **1-2** = needs work (request changes)
- **3** = acceptable (minor suggestions)
- **4-5** = strong (approve)

Overall:
- **Blocker** if any dimension = 0 → request changes
- **Needs work** if 2+ dimensions ≤ 2 → request changes
- **Acceptable** if all ≥ 3 → approve with comments
- **Strong** if all ≥ 4 → approve

## Process (5 steps)

1. **Load diff** via `git diff` or PR endpoint
2. **Score 7 dimensions** using the checklist above
3. **Consult `code-smells-catalog`** for design smells
4. **Consult `sota-architecture-patterns`** for architecture alignment
5. **Emit structured review** (output format below)

## Output format

```
🧐 Senior Review — {PR title or branch}

Overall: {Blocker | Needs work | Acceptable | Strong}

Scores (0-5):
  Correctness:      {N}/5    {1-sentence summary}
  Design:           {N}/5    {1-sentence summary}
  SOLID:            {N}/5    {1-sentence summary}
  Naming:           {N}/5    {1-sentence summary}
  Cohesion/Coupling:{N}/5    {1-sentence summary}
  Testability:      {N}/5    {1-sentence summary}
  Observability:    {N}/5    {1-sentence summary}

Blockers:
  - {specific issue + file:line + refactor suggested}

Suggestions (non-blocking):
  - {issue + file:line + rationale}

Nice-to-haves:
  - {style/doc/rename ideas}

Overall recommendation: {Approve | Request changes | Comment}
```

## When to invoke sub-skills

- `code-smells-catalog` — for deep-dive on a specific smell found
- `sota-architecture-patterns` — for architecture-level concerns (not method-level)
- `code-review` — parent skill that orchestrates the full PR review
- `systematic-debugging` — if the PR is a bug fix, verify root cause analysis

## Anti-patterns in reviews

- **Nitpicking**: flagging formatting/style (should be in lint, not review)
- **Bikeshedding**: debating color-of-the-bikeshed (minor naming preferences)
- **Big-bang review**: reviewing a 2000-line PR without segmenting — request split
- **Missing-context review**: reviewing code without reading related tests or domain docs
- **Approval without reading**: rubber-stamping. Always read the diff.

## References

- `skills/refs/code-smells-catalog/` — smell detection + refactor patterns
- `skills/refs/sota-architecture-patterns/` — architecture alignment
- [Code Review Checklist — Gocodeo](https://www.gocodeo.com/post/the-ultimate-code-review-checklist)
- Fowler, *Refactoring* (2nd ed.)
