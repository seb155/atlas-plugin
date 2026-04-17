# ATLAS Plugin Schemas — v6.0 Index

> **Purpose**: Normative schemas that govern `SKILL.md`, `AGENT.md`, and the Execution Philosophy Engine for atlas-dev-plugin v6.0.
> **Updated**: 2026-04-17

---

## Schemas

| Document | Scope | Lines |
|---|---|---|
| [`skill-frontmatter-v6.md`](skill-frontmatter-v6.md) | YAML frontmatter for every `skills/*/SKILL.md` | ~195 |
| [`agent-frontmatter-v6.md`](agent-frontmatter-v6.md) | YAML frontmatter for every `agents/*/AGENT.md` + SOTA effort table for 17 agents | ~190 |
| [`philosophy-engine-schema.md`](philosophy-engine-schema.md) | `iron-laws.yaml`, `red-flags-corpus.yaml`, `<HARD-GATE>` body format, linter contract | ~190 |

Total doc surface: ~575 lines across the three schemas + this index.

---

## Decision rationale

| Key | Why included | Why this form |
|---|---|---|
| `effort` | 6-level Opus 4.7 / Sonnet 4.6 official spec; 88% already present at v5.23 | Enum — testable, CLI-router-parseable |
| `thinking_mode` | Opus 4.7 rejects `extended`; migration must be enforced | Single-value enum (`adaptive`) so lint can grep |
| `superpowers_pattern` | Declarative tier flag — lets linter decide whether `<HARD-GATE>` and `<red-flags>` are required | List so multiple patterns co-exist (e.g. `[iron_law, red_flags, hard_gate]`) |
| `see_also` | Enables skill dependency graph + replaces free-text mentions | Resolvable list for static analysis |
| `version` | Enables mixed v5/v6 coexistence until full migration | Semver string, no runtime impact |
| `isolation` (agents) | Required for worktree-scoped reviewers & experimenters | Enum — `worktree` vs `none`, no halfway |
| `task_budget` (agents) | Observability + cost guardrail | Integer output-token ceiling, advisory first |

### Why these keys, not others

- Rejected `max_tokens` — Opus 4.7 handles via effort; redundant.
- Rejected `temperature` — not exposed in Claude Code harness.
- Rejected `priority` — effort already encodes that.
- Rejected `timeout` — covered by `task_budget` indirectly.

---

## Authority chain

```
.blueprint/plans/regarde-comment-adapter-atlas-compressed-wave.md
         (master plan v6.0 — section D/E/F are the source)
                    │
                    ├── .blueprint/schemas/skill-frontmatter-v6.md
                    ├── .blueprint/schemas/agent-frontmatter-v6.md
                    └── .blueprint/schemas/philosophy-engine-schema.md
                                    │
                                    ├── scripts/execution-philosophy/iron-laws.yaml (Sprint 2)
                                    ├── scripts/execution-philosophy/red-flags-corpus.yaml (Sprint 2)
                                    └── scripts/execution-philosophy/hard-gate-linter.sh (Sprint 2)
```

---

## Migration Checklist — one skill v5.x → v6.0

Use this when upgrading a skill directory (e.g. `skills/tdd/SKILL.md`):

1. **Inventory**: confirm current frontmatter keys (`name`, `description`, `effort`, …).
2. **Decide tier**: `core` / `dev` / `admin` — single value or multi-tier. If the skill duplicates across tiers, plan for SP-DEDUP (Sprint 4).
3. **Classify pattern**: Tier-1 (enforces philosophy) ⇒ `superpowers_pattern: [iron_law, red_flags, hard_gate]`; utility ⇒ `[none]`.
4. **Add required keys**: `thinking_mode: adaptive`, `version: 6.0.0`, and `effort` if missing (default per SOTA table in agent schema).
5. **Populate `see_also`**: scan body for "see also", "related skill", explicit skill names; migrate to list. Empty = `[]`.
6. **Embed `<HARD-GATE>`** (Tier-1 only): copy signature verbatim from `iron-laws.yaml` matching `skill: <name>`.
7. **Embed `<red-flags>` table** (Tier-1 only): populate from `red-flags-corpus.yaml` matching `skill: <name>`.
8. **Lint**: run `./scripts/execution-philosophy/hard-gate-linter.sh skills/<name>/`. Expect exit 0.
9. **YAML parse**: `python -c "import yaml, pathlib; yaml.safe_load(pathlib.Path('skills/<name>/SKILL.md').read_text().split('---')[1])"` ⇒ no exception.
10. **Commit**: `chore(skill): migrate <name> to v6.0 schema` + push.

---

## Not in scope

- `build.sh` modifications — Sprint 1.6 / 1.7.
- SKILL.md / AGENT.md body edits — Sprint 2.4 (top 10) / Sprint 4.x (SP-DEDUP bulk).
- Hook wiring (`PreToolUse[Task]` for `effort-heuristic.sh`) — Sprint 3.4.

---

**Plan reference**: `.blueprint/plans/regarde-comment-adapter-atlas-compressed-wave.md` — sections D (effort), E (philosophy engine), F (frontmatter).
