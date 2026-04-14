---
name: senior-discipline-checklist
description: "Systematic rigor audit at micro level: naming, structure, documentation hygiene. Complements senior-review-checklist (macro architecture). Invoke during hygiene sprints or code audit."
effort: medium
refs:
  - naming-conventions
  - folder-structure-patterns
---

# Senior Discipline Checklist

Micro-level rigor audit. Scores a codebase (or a PR) across 5 discipline dimensions.
Pairs with `senior-review-checklist` (macro-architecture review).

- `senior-review-checklist` → Does this code solve the problem with the right architecture?
- `senior-discipline-checklist` → Is this code **rigorous** — well-named, well-placed, well-documented?

Use both passes during a real review. Use this one alone during a code hygiene sprint.

## 5 Discipline Dimensions

### 1. Naming (25% weight)

Consult `refs/naming-conventions/{python,typescript,bash,yaml}.md`.

Questions per file:
- Are variables/functions following language convention?
  - Python: `snake_case`? TS: `camelCase`? Bash: `snake_case`?
- Are file names following project convention? (kebab-case vs PascalCase)
- Are names precise vs generic?
  - Precise: `order_total`, `extract_features`, `UserLoginForm`
  - Generic: `data`, `info`, `handle`, `process`, `manage`
- Are booleans phrased as questions (`is_*`, `has_*`, `can_*`)?
- Are abbreviations in the team allowlist?

Automated checks (to script):
- Python: `grep -rE "def [a-z]+[A-Z]" src/`  → camelCase Python functions (violation)
- TS: `grep -rE "function [a-z_]+_" src/`  → snake_case TS functions (violation)
- Files: `find src -name "*[A-Z]*.tsx"` vs kebab-case convention (flag if inconsistent)

### 2. Folder Structure (20% weight)

Consult `refs/folder-structure-patterns/`.

Questions:
- Are files grouped by feature (not by layer) for apps > 50 files?
- Is nesting ≤ 3-4 levels from `src/`?
- Are tests colocated (TS/JS) or in `tests/` tree (Python) — consistent?
- Are there "catch-all" folders (`utils/`, `helpers/`, `misc/`) with > 10 files? (flag)
- Are shared helpers actually used by 2+ features?

Automated checks:
- Max depth: `find src -type d | awk -F'/' '{print NF}' | sort -rn | head -1`  → expect ≤ 5
- Catch-all folders: `ls src/utils/ src/helpers/ src/common/ 2>/dev/null | wc -l`  → investigate if > 10

### 3. Documentation (20% weight)

Questions:
- Do public functions/classes have docstrings/JSDoc?
- Are comments "Why, not What"? (no comments restating the code)
- Is there a README.md per feature (optional) or per module (if complex)?
- Are non-obvious design decisions documented (in code or in `.blueprint/`)?

Automated checks (Python):
- `ast` parse: count public functions (no `_` prefix) with vs without docstring
- Ruff `D100`/`D101`/`D103` for docstring enforcement

Automated checks (TS):
- Count exported functions with JSDoc: `grep -B1 "^export function" src/*.ts | grep -c "^\*\/"`
- Ratio should be > 80% for public exports.

### 4. Small patterns (15% weight)

Questions:
- Guard clauses instead of deep nesting? (max 3 nest levels)
- Explicit types on public signatures?
- Single Responsibility per function (1 verb + 1 noun in name)?
- Magic numbers replaced with named constants?
- No `and` in function names? (indicates SRP violation)

Automated checks:
- Deep nesting: use `cyclomatic_complexity` tool or regex for `if/for/while` levels
- Magic numbers: grep for bare integer literals > 1 in business logic
  ```
  grep -n "[^a-zA-Z_][0-9][0-9]" src/*.py | grep -v "test_" | grep -v "#"
  ```

### 5. Consistency (20% weight)

Questions:
- Is import order consistent? (stdlib → 3rd party → local)
- Is test naming consistent? (`test_X_does_Y` pattern)
- Are error handling patterns consistent across files?
- Are logger/monitoring patterns consistent?
- Are API response shapes consistent (always `{data, error}` vs sometimes raw)?

Automated checks:
- isort (Python), eslint-plugin-import (TS) for import order
- Per-project style guide in `.atlas/hygiene-config.yaml`

## Scoring

Per dimension, score 0-5:
- **0** = widely inconsistent / missing (blocker)
- **1-2** = pattern exists but poorly applied (request changes)
- **3** = acceptable (minor comments)
- **4-5** = rigorous (approve)

Overall discipline grade:
- `A` (all ≥ 4): SHIP — rigorous senior-level code
- `B` (avg ≥ 3.5, no 0s): ACCEPTABLE — minor polishing
- `C` (avg ≥ 2.5, no 0s): NEEDS WORK — cleanup before ship
- `D/F` (any 0 or avg < 2.5): BLOCKER — significant hygiene debt

## Process (5 steps for a hygiene sprint)

### Step 1 — Scope

Define what you're auditing:
- Full package? (`src/users/`)
- Full repo?
- A PR diff?

### Step 2 — Run automated checks

Use the regex/tool commands above. Capture counts and examples.

### Step 3 — Manual deep read

Pick 3-5 representative files. Read top to bottom for naming/docs/patterns.

### Step 4 — Score the 5 dimensions

Fill in the scoring table:
```
| Dimension       | Score | Notes                          |
|-----------------|-------|--------------------------------|
| Naming          | 4/5   | 2 camelCase in Python (L23, L45) |
| Folder struct   | 3/5   | src/utils/ has 15 files        |
| Documentation   | 2/5   | 60% missing docstrings         |
| Small patterns  | 4/5   | Few magic numbers              |
| Consistency     | 4/5   | Import order mostly OK         |
```

### Step 5 — Prioritized output

```
🧐 Senior Discipline Audit — {scope}

Grade: {A/B/C/D/F}

Scores:
  Naming:         {N}/5
  Folder struct:  {N}/5
  Documentation:  {N}/5
  Small patterns: {N}/5
  Consistency:    {N}/5

Quick wins (1h work):
  - Fix 2 camelCase Python functions in users/service.py (L23, L45)
  - Add docstrings to 5 public functions in orders/api.py

Structural fixes (longer):
  - Split src/utils/ (15 files) by sub-domain (date-, currency-, format-)
  - Move src/random-component.tsx into a feature folder

Refactor candidates:
  - users/service.py L12-67 Long Method (55 lines, cyclomatic 11)
  - orders/controller.py has 4 responsibilities — extract 2 classes

Next: create .atlas/hygiene-config.yaml with team decisions on:
  - file naming convention (kebab-case vs PascalCase for components?)
  - abbreviations allowlist
  - docstring enforcement threshold
```

## Relation to senior-review-checklist

| Skill | Focus | Example check |
|-------|-------|---------------|
| senior-review-checklist | MACRO — is the design right? | God Class, SOLID, architecture alignment |
| senior-discipline-checklist | MICRO — is the execution rigorous? | Naming, docs, small patterns |

Both passes in a thorough PR review. Use discipline alone for cleanup sprints.

## References

- `skills/refs/naming-conventions/` — per-language rules
- `skills/refs/folder-structure-patterns/` — layout patterns
- `skills/refs/code-smells-catalog/` — refactor catalog (Phase 8)
- `skills/senior-review-checklist/` — architecture-level review (Phase 8)
- `skills/code-hygiene-rules/` — operational skill for hygiene sprints
