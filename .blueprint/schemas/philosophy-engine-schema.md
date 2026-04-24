# Execution Philosophy Engine Schema v6.0

> **Scope**: File-based engine at `scripts/execution-philosophy/` — validates Iron Laws, Red Flags, and `<HARD-GATE>` enforcement across SKILL.md files.
> **Status**: v6.0 foundation (Sprint 2 delivers the linter + migration of top-10 skills).
> **Authority**: `.blueprint/plans/regarde-comment-adapter-atlas-compressed-wave.md` section E.
> **Updated**: 2026-04-17

---

## 1. Directory Layout

```
scripts/execution-philosophy/
├── iron-laws.yaml              # Registry — verbatim Iron Laws corpus
├── red-flags-corpus.yaml       # Cognitive rationalisations → reality map
├── hard-gate-linter.sh         # Bash linter invoked by build.sh
├── effort-heuristic.sh         # task text → suggested effort (regex + keyword map)
└── two-stage-review.sh         # spec-compliance phase → code-quality phase wrapper
```

Zero DB. Everything file-based. Zero infra. Fits ATLAS plugin cache sync model (read-only at runtime, sourced from atlas-dev-plugin repo).

---

## 2. `iron-laws.yaml` — Schema

```yaml
version: 6.0.0
laws:
  - id: TDD-001
    title: "No production code without a failing test first"
    skill: test-driven-development
    tier: [core, dev, admin]
    signature: |
      NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
      This is not a recommendation. This is an Iron Law.
    override_requires: HITL    # AskUserQuestion required to skip
    sha256: "<computed at build time>"

  - id: DBG-001
    title: "No fixes without root cause investigation"
    skill: systematic-debugging
    tier: [core, dev, admin]
    signature: |
      NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.
      If you haven't completed Phase 1, you cannot propose fixes.
    override_requires: HITL
    sha256: "<computed>"

  - id: DESIGN-001
    title: "No implementation without approved design"
    skill: brainstorming
    tier: [core, dev, admin]
    signature: |
      Do NOT invoke any implementation skill, write any code, scaffold
      any project, or take any implementation action until you have
      presented a design and the user has approved it.
    override_requires: HITL
    sha256: "<computed>"

  - id: VERIFY-001
    title: "No completion claim without verification evidence"
    skill: verification-before-completion
    tier: [core, dev, admin]
    signature: |
      NO "DONE" WITHOUT RUNNING THE VERIFICATION COMMAND AND READING ITS OUTPUT.
    override_requires: HITL
    sha256: "<computed>"
```

### Field constraints

| Field | Type | Rule |
|---|---|---|
| `version` | semver | Matches plugin version at release |
| `laws[].id` | `XXX-NNN` | 3–4 uppercase letters, dash, 3-digit number |
| `laws[].title` | string | ≤80 chars, single sentence |
| `laws[].skill` | kebab-case | Must resolve to `skills/<skill>/SKILL.md` |
| `laws[].tier[]` | enum | Subset of `{core, dev, admin}` |
| `laws[].signature` | multiline | Verbatim text injected inside `<HARD-GATE>` — byte-exact match required |
| `laws[].override_requires` | enum | `HITL` (AskUserQuestion) or `none` |
| `laws[].sha256` | hex string | Computed at `build.sh` time; signature drift ⇒ fail |

---

## 3. `red-flags-corpus.yaml` — Schema

Captures cognitive rationalisations (thoughts that signal the agent is about to break an Iron Law) mapped to their reality check.

```yaml
version: 6.0.0
corpus:
  - skill: test-driven-development
    flags:
      - thought: "This is too small to test"
        reality: "Skills evolve — test anyway. Trivial tests catch trivial regressions."
      - thought: "I'll add tests after"
        reality: "Tests written after = documentation, not TDD. They cannot fail for the right reason."
      - thought: "Already manually tested"
        reality: "Ad-hoc ≠ systematic. No record. Can't re-run under pressure."

  - skill: systematic-debugging
    flags:
      - thought: "Quick fix for now, investigate later"
        reality: "First fix sets the pattern. Later never comes."
      - thought: "Emergency, no time for process"
        reality: "Systematic debugging is FASTER than guess-and-check thrashing."
      - thought: "It's probably X"
        reality: "Symptom ≠ root cause. Stop guessing."

  - skill: brainstorming
    flags:
      - thought: "This is too simple to need a design"
        reality: "Simple projects are where unexamined assumptions cause wasted work."
```

### Table format injected into SKILL.md body

```markdown
<red-flags>
| Thought | Reality |
|---|---|
| "This is too small to test" | Skills evolve — test anyway |
| "I'll add tests after" | Tests written after = documentation, not TDD |
</red-flags>
```

Rules:
- Column headers **exactly** `Thought` and `Reality`.
- Double-quotes around "Thought" value (matches Superpowers convention).
- One row per flag. Max 20 rows per table.
- `<red-flags>` open/close tags on their own lines (linter relies on line-start regex).

---

## 4. `<HARD-GATE>` XML Tag — Body Format

Inspiration: `superpowers:brainstorming` (verbatim), `superpowers:test-driven-development`, `superpowers:systematic-debugging`.

```markdown
<HARD-GATE>
{signature from iron-laws.yaml verbatim — multiline allowed}
</HARD-GATE>
```

Rules:
- Opening `<HARD-GATE>` on line-start, closing `</HARD-GATE>` on line-start.
- Positioned **before** the first `##` heading in the skill body (directly after frontmatter is acceptable).
- Content matches `laws[].signature` byte-for-byte (lint compares SHA256).
- Exactly **one** `<HARD-GATE>` block per skill. Multiple blocks ⇒ lint fail.

---

## 5. `hard-gate-linter.sh` — Contract

### Invocation

```bash
./scripts/execution-philosophy/hard-gate-linter.sh <skills-dir>
```

### Lint rules enforced

| ID | Rule | Exit code on fail |
|---|---|---|
| L1 | Skill declaring `superpowers_pattern: [..., hard_gate, ...]` MUST contain `<HARD-GATE>` block in body | 2 |
| L2 | Skill declaring `superpowers_pattern: [..., red_flags, ...]` MUST contain `<red-flags>` block with valid table headers | 3 |
| L3 | Skill declaring `superpowers_pattern: [..., iron_law, ...]` MUST link to an `iron-laws.yaml` entry via `name:` field equality | 2 |
| L4 | `<HARD-GATE>` signature MUST match iron-laws.yaml SHA256 | 2 |
| L5 | Skill frontmatter `thinking_mode` MUST be `adaptive`; `extended` ⇒ fail | 4 |
| L6 | Skill frontmatter `effort` MUST be in enum `{low, medium, high, xhigh, max, auto}` | 4 |
| L7 | Every `see_also[]` entry MUST resolve to an existing skill directory (warning in v6.0, error in v6.1) | 5 |
| L8 | Max one `<HARD-GATE>` block per skill | 2 |
| L9 | Red-flags table headers MUST be exactly `\| Thought \| Reality \|` | 3 |
| L10 | `iron-laws.yaml` MUST load cleanly (yaml.safe_load) | 1 (fatal) |

### Exit codes

| Code | Meaning |
|---|---|
| 0 | All lints pass |
| 1 | Fatal I/O error (file unreadable, YAML corrupt) |
| 2 | Missing `<HARD-GATE>` or signature drift |
| 3 | Missing or malformed `<red-flags>` table |
| 4 | Invalid enum value (effort, thinking_mode) |
| 5 | Unresolved `see_also` (warning in v6.0 — logs but returns 0) |

### Build integration

```bash
# In build.sh, after skill inventory:
./scripts/execution-philosophy/hard-gate-linter.sh skills/ || {
  echo "FAIL: philosophy engine lint violations"
  exit 1
}
```

---

## 6. `effort-heuristic.sh` — Contract (Sprint 2.3)

Takes a task description from stdin and emits a suggested `effort` value.

```bash
echo "refactor the auth pipeline and add MFA" | ./effort-heuristic.sh
# stdout: xhigh
```

Keyword map (first match wins):

| Keywords (regex, case-insensitive) | Suggested effort |
|---|---|
| `architect`, `design system`, `mega plan`, `15.section`, `ultrathink` | `max` |
| `refactor`, `security audit`, `multi.file`, `migration`, `debug.*root cause` | `xhigh` |
| `implement`, `add feature`, `fix bug`, `multi.step` | `high` |
| `lint`, `format`, `rename`, `bump version`, `single.file` | `medium` |
| `status`, `list`, `check`, `grep`, `echo` | `low` |
| *(no match)* | `auto` (defer to CLI router) |

Hook `PreToolUse[Task]` invokes this heuristic and sets `effort` dynamically when the agent dispatches without explicit override.

---

## 7. `two-stage-review.sh` — Contract (Sprint 2.5)

Forces the code-review skill to run two sequential phases:

1. **Phase 1 — Spec compliance**: does the diff match the stated plan/spec? Emits PASS/FAIL.
2. **Phase 2 — Code quality**: SOLID, naming, coupling, coverage. Only runs if Phase 1 = PASS.

CLI wraps `/ultrareview` (CC 2.1.111+) and emits structured JSON per phase. Fails loudly if user tries to skip phase 1.

---

## 8. Observability

Hook `PostToolUse[Task]` appends one JSONL line per dispatch to `.claude/metrics/effort-audit.jsonl`:

```json
{"ts":"2026-04-17T19:30:00-04:00","agent":"code-reviewer","effort_requested":"xhigh","effort_actual":"xhigh","tokens_out":94211,"budget":150000,"budget_breach":false}
```

Weekly rollup via `atlas-analytics` — detects drift (e.g. `medium` requested but Opus under the hood ⇒ config bug).

---

**Source of truth**: this file. Sprint 2 tasks 2.1–2.6 implement against this contract verbatim.
