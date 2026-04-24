# SKILL.md Frontmatter Schema v6.0

> **Scope**: Normative schema for every `skills/*/SKILL.md` file in the ATLAS plugin family (atlas-core, atlas-dev, atlas-admin).
> **Status**: v6.0 — ships with atlas-dev-plugin v6.0.0.
> **Authority**: See `.blueprint/plans/regarde-comment-adapter-atlas-compressed-wave.md` sections D, E, F.
> **Updated**: 2026-04-17

---

## 1. Formal Schema (strict YAML)

```yaml
# ----- REQUIRED (all skills) -----
name: string                       # kebab-case, matches directory; primary key
description: string                # 1 sentence, <200 chars, quoted if contains ':' or punctuation

# ----- REQUIRED in v6.0 for ALL skills (defaults documented) -----
effort: enum[low|medium|high|xhigh|max|auto]
thinking_mode: enum[adaptive]      # v6.0: only 'adaptive' accepted. Opus 4.7 rejects extended.
version: semver-string             # "6.0.0" or later; missing => treated as "5.0.0"

# ----- OPTIONAL (tier-gated enrichment) -----
tier: list[core|dev|admin]         # Defaults to ['dev'] if absent
category: string                   # Free-text grouping (e.g. "engineering", "governance")
emoji: single-glyph-string         # One Unicode char, used in banner

# ----- NEW v6.0 (philosophy engine) -----
superpowers_pattern: list[iron_law|red_flags|hard_gate|none]
see_also: list[skill-name]         # Dependency / companion graph; names must resolve

# ----- OPTIONAL (activation hints — extended from v5.x) -----
triggers: list[string]             # Natural-language triggers for auto-routing
agent: string                      # Default agent for delegation (must match agents/<agent>/AGENT.md)
context: enum[main|fork]           # 'fork' => dispatch in isolated subagent, default 'main'
```

### Enum specifications

| Key | Allowed values | Notes |
|---|---|---|
| `effort` | `low`, `medium`, `high`, `xhigh`, `max`, `auto` | Validated by `hard-gate-linter.sh`. `auto` = CLI router decides. |
| `thinking_mode` | `adaptive` (only) | `extended` is a v5.x artifact and causes build.sh fail in v6.0. |
| `superpowers_pattern[]` | `iron_law`, `red_flags`, `hard_gate`, `none` | Use `none` for utility skills that do not enforce philosophy. |
| `tier[]` | `core`, `dev`, `admin` | Omission defaults to `[dev]`. |
| `context` | `main`, `fork` | `fork` requires `agent:` to be set. |

### YAML constraints

- **No tabs**: 2-space indent everywhere.
- **Quote any string containing `:`, `#`, `{`, `}`, `,`, `|`, `>`, leading `-` or trailing colon**.
- Lists use flow syntax (`[a, b, c]`) when ≤3 items OR block syntax when ≥4.
- Empty `see_also` must be `[]` (not omitted) to pass coherence lint.
- `version` must match `^\d+\.\d+\.\d+(-[a-z0-9]+)?$`.

---

## 2. Migration Table v5.x → v6.0

| v5.x key | v6.0 behavior | Action |
|---|---|---|
| `name` | Unchanged | Keep |
| `description` | Unchanged | Keep |
| `effort` | Now **required** (88% already present in v5.23 inventory) | Add if missing; default `high` for Opus-class, `medium` for routine |
| `triggers` | Unchanged | Keep |
| `agent` | Unchanged | Keep (relevant when `context: fork`) |
| `context` | Unchanged | Keep |
| `thinking_mode` | **NEW** — required enum `adaptive` | Add `thinking_mode: adaptive`. Never write `extended`. |
| `superpowers_pattern` | **NEW** — list | Tier-1 skills: `[iron_law, red_flags, hard_gate]`. Routine: `[none]`. |
| `see_also` | **NEW** — list | Add dependency graph; min `[]`. |
| `version` | **NEW** | Stamp `6.0.0` at migration time. |
| `tier` | Was implicit | Make explicit (`[core]`, `[dev]`, `[admin]`, or multi-tier). |

### Before/After example

**Before (v5.23 — `skills/tdd/SKILL.md`):**

```yaml
---
name: tdd
description: "Test-Driven Development. Failing test → minimal implementation → pass → commit. Strict cycle. Never write implementation without a failing test first."
effort: medium
---
```

**After (v6.0):**

```yaml
---
name: tdd
description: "Iron Law: no production code without failing test. Red-Green-Refactor cycle. Never write implementation without a failing test first."
effort: xhigh
thinking_mode: adaptive
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [verification-before-completion, systematic-debugging]
tier: [core, dev, admin]
version: 6.0.0
---
```

---

## 3. Three Canonical Examples

### 3.1 Minimal skill — no philosophy enforcement

```yaml
---
name: smoke-gate
description: "Post-deploy G3 gate. Run scripts/smoke.sh against dev/staging/prod, emit structured JSON, create Forgejo issue on red (alert-only policy)."
effort: low
thinking_mode: adaptive
superpowers_pattern: [none]
see_also: []
tier: [dev, admin]
version: 6.0.0
triggers:
  - "/atlas smoke-gate"
  - "verify deploy"
---
```

**Rationale**: utility skill — no Iron Law, no HARD-GATE tag required, minimal frontmatter.

### 3.2 Tier-1 skill — full philosophy engine (Iron Law)

Frontmatter:

```yaml
name: test-driven-development
description: "Iron Law: no production code without failing test. Red-Green-Refactor. Use when implementing any feature or bugfix, before writing implementation code."
effort: xhigh
thinking_mode: adaptive
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [verification-before-completion, systematic-debugging, writing-plans]
tier: [core, dev, admin]
version: 6.0.0
category: engineering-discipline
emoji: "🧪"
triggers:
  - "implement feature"
  - "write tests"
  - "bugfix"
```

Body (must follow the frontmatter):

```markdown
<HARD-GATE>
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
This is not a recommendation. This is an Iron Law.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Too small to test" | Trivial tests catch trivial regressions |
| "I'll add tests after" | Tests written after = documentation, not TDD |
| "Just this once, skip it" | First exception breaks the law |
</red-flags>

[skill body continues...]
```

**Rationale**: Tier-1 skill — must ship `<HARD-GATE>` XML tag + `<red-flags>` table in body. `hard-gate-linter.sh` fails the build otherwise.

### 3.3 Skill with see_also dependency graph

```yaml
---
name: code-review
description: "Unified code review. Spec compliance → code quality (two-stage). Wraps /ultrareview for CC 2.1.111+ agents."
effort: xhigh
thinking_mode: adaptive
superpowers_pattern: [iron_law, hard_gate]
see_also:
  - senior-review-checklist
  - senior-discipline-checklist
  - verification-before-completion
  - receiving-code-review
tier: [core, dev, admin]
version: 6.0.0
category: review
emoji: "🔎"
agent: code-reviewer
context: fork
---
```

**Rationale**: `see_also` documents the review pipeline graph. `agent: code-reviewer` + `context: fork` routes to a worktree-isolated subagent (see AGENT schema).

---

## 4. Validation Rules

| Rule ID | Description | Enforcement |
|---|---|---|
| R1 | `name` matches directory basename | `build.sh` |
| R2 | YAML parses cleanly (no tabs, no duplicate keys) | `build.sh` via `yaml.safe_load` |
| R3 | `effort` ∈ enum | `hard-gate-linter.sh` |
| R4 | `thinking_mode == adaptive` (never `extended`) | `test_thinking_migration.bats` |
| R5 | `superpowers_pattern ⊇ {hard_gate}` ⇒ body contains `<HARD-GATE>` | `hard-gate-linter.sh` |
| R6 | `superpowers_pattern ⊇ {red_flags}` ⇒ body contains `<red-flags>` block | `test_red_flags.bats` |
| R7 | Every name in `see_also` resolves to an existing skill | `build.sh` post-inventory |
| R8 | `version` is valid semver | `build.sh` |
| R9 | `tier[]` ⊆ `{core, dev, admin}` | `build.sh` |
| R10 | If `context: fork`, `agent` is set and resolves | `build.sh` |

Backward compat: skills lacking `thinking_mode`, `superpowers_pattern`, `see_also`, `version` load with defaults (`adaptive`, `[none]`, `[]`, `5.0.0`) and emit a deprecation warning — they do NOT fail the build until v6.1.

---

## 5. Linter contract

`hard-gate-linter.sh` exit codes:

- `0` — Skill passes all R1–R10.
- `2` — Skill missing `<HARD-GATE>` when required (blocks build).
- `3` — Skill missing `<red-flags>` table when required (blocks build).
- `4` — Invalid enum value (e.g., `effort: huge`).
- `5` — Unresolved `see_also` dependency (warning in v6.0, error in v6.1).

Integration: `build.sh` calls `hard-gate-linter.sh skills/` after inventory scan; fail-fast on exit ≥ 2.

---

**Source of truth**: this file. All v6.0 skill authoring guides MUST reference this schema.
