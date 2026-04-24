---
name: code-hygiene-rules
description: "Per-language code hygiene rules. Use before writing new files, during cleanup sprints, or when the user asks to 'enforce hygiene', 'naming conventions', 'folder structure', 'code hygiene'."
effort: low
refs:
  - naming-conventions
  - folder-structure-patterns
---

# Code Hygiene Rules

Micro-level discipline: naming, folder structure, documentation, small code patterns.
Complements Phase 8 (architecture macro) with Phase 9 (hygiene micro). Senior devs apply both.

## When to invoke this skill

- Before writing a new file/module (apply naming + structure rules)
- During cleanup sprints ("let's do code hygiene on package X")
- When reviewing code for Naming dimension of `senior-review-checklist`
- When a new contributor asks "where does this go?"

## 4 dimensions of code hygiene

### 1. Naming

Follow per-language conventions documented in `skills/refs/naming-conventions/`:
- `python.md` — PEP 8 (snake_case vars, PascalCase classes)
- `typescript.md` — camelCase vars, PascalCase components, kebab-case files
- `bash.md` — snake_case funcs + vars, UPPER_SNAKE_CASE env
- `yaml.md` — snake_case or camelCase (pick one per file, don't mix)

Decision check:
- Is the name precise? (`parsed_order` not `data`)
- Is it consistent with team vocabulary? (domain ubiquitous language)
- Does it respect the language convention? (snake_case vs camelCase)
- Is a boolean phrased as question? (`is_valid`, `has_permission`)

### 2. Folder structure

Follow patterns documented in `skills/refs/folder-structure-patterns/`:
- Feature-based > layer-based for apps > 50 files
- Test colocation (TS/JS) or `tests/` tree (Python)
- Shared only if 2+ features use it
- Max 3-4 levels deep from `src/`

Decision check:
- Is this file close to the other files used together?
- Is this in the right feature folder (not a dumping ground)?
- Are tests next to source (colocation) or in parallel tree?
- Are cross-feature imports going through a public API?

### 3. Documentation

Language-specific:
- **Python**: Docstrings on public functions/classes/modules (PEP 257)
- **TypeScript**: JSDoc/TSDoc on exported functions/types, `@param`/`@returns` for non-obvious
- **Bash**: Header comment per script (purpose + usage + exit codes)
- **YAML**: Comment the "why" for non-obvious config choices

Comment philosophy: **"Why, not What"**
```python
# BAD (restates code):
# Increment counter by 1
count += 1

# GOOD (explains why):
# Retry twice — endpoint returns 500 under high load (bug #1234)
retry_count += 1
```

Docstring template (Python):
```python
def process_order(order: Order, *, dry_run: bool = False) -> OrderResult:
    """Apply payment + shipping to an order.

    Args:
        order: Validated order with items and customer
        dry_run: If True, skip side effects (DB write, email)

    Returns:
        OrderResult with success status and any warnings

    Raises:
        PaymentDeclined: If payment gateway rejects
        ShippingUnavailable: If address unservicable
    """
    ...
```

### 4. Small code patterns (within-function hygiene)

- **Early return (guard clauses)** over deep nesting:
  ```python
  # Bad — nested
  def f(x):
      if x:
          if x > 0:
              if x < 100:
                  return compute(x)
      return None

  # Good — flat
  def f(x):
      if not x: return None
      if x <= 0: return None
      if x >= 100: return None
      return compute(x)
  ```

- **Explicit types** (Python 3.11+, TS strict):
  ```python
  # Bad
  def fetch(url, timeout=5):
      ...

  # Good
  def fetch(url: str, timeout: float = 5.0) -> Response:
      ...
  ```

- **Single Responsibility per function**: 1 verb + 1 noun in the name. If name has `and`, split it.
  - `calculate_total_and_send_email()` → split into `calculate_total()` + `send_email()`

- **Magic numbers** → named constants:
  ```python
  # Bad
  if age > 18:
      ...

  # Good
  LEGAL_ADULT_AGE = 18
  if age > LEGAL_ADULT_AGE:
      ...
  ```

- **Early return over long `else if` chains** — use dispatch dicts, polymorphism, or pattern matching (Python 3.10+ match/case).

## Process (when running a hygiene sprint)

### Step 1 — Audit target scope

```bash
# Count files + lines
find src/ -name "*.py" | wc -l
find src/ -name "*.py" -exec wc -l {} + | tail -1

# List files > 300 lines (God Class candidates)
find src/ -name "*.py" -exec wc -l {} + | awk '$1 > 300' | sort -rn

# Find generic-named files
find src/ -name "utils.py" -o -name "helpers.py" -o -name "misc.py"
```

### Step 2 — Identify top 3 issues

Use `senior-discipline-checklist` skill to score:
- Naming violations per file
- Folder structure issues
- Documentation gaps

### Step 3 — Prioritize fixes

- Quick wins (bad names, missing docstrings) — batch fix with sed/Edit
- Structural fixes (move file to feature folder) — plan carefully, update imports
- Refactor patterns (split God Class) — refer to `code-smells-catalog`

### Step 4 — Per-project config

Document team decisions in `.atlas/hygiene-config.yaml`:
```yaml
naming:
  variables_python: snake_case
  variables_typescript: camelCase
  files: kebab-case
  allow_abbreviations: [id, url, api, db, ui, uuid]
folder_structure:
  feature_based: true
  tests_colocation: true      # for TS; Python uses tests/ tree
documentation:
  require_docstrings_public: true
  comment_style: why_not_what
```

## Cross-project applicability

This skill works for ANY project with ATLAS installed:
- New projects: apply rules from start
- Legacy projects: gradual migration, grandfather existing files
- Multi-stack projects: apply language-specific rules from the refs

## Output format

```
🧹 Code Hygiene Report — {scope}

Naming:
  ✓ N files compliant
  ⚠ N violations (list top 5 with file:line)

Folder structure:
  ✓ N features properly grouped
  ⚠ N misplaced files (list)

Documentation:
  ✓ N% functions with docstrings
  ⚠ N public functions missing docs (list top 5)

Prioritized fixes:
  1. {quick win}
  2. {structural}
  3. {refactor}

Next: invoke senior-discipline-checklist for full score.
```

## References

- `skills/refs/naming-conventions/` — language-specific rules
- `skills/refs/folder-structure-patterns/` — folder layout patterns
- `skills/senior-discipline-checklist` — rigor audit
- `skills/refs/code-smells-catalog/` — refactor patterns for structural issues
- `skills/sota-code-patterns` — architecture-level patterns (Phase 8)
