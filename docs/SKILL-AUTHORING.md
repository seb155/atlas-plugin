# ATLAS Skill Authoring Guide

> **Version**: 1.0 | **Created**: 2026-04-19
> **Template**: `templates/SKILL.md.template`
> **Source**: plan `joyful-hare` REC-004 + benchmark findings (obra/superpowers, anthropics/claude-plugins-official)

---

## TL;DR

1. Copy `templates/SKILL.md.template` to `skills/<name>/SKILL.md`
2. Fill `name`, `description`, `effort`, `version` in frontmatter
3. Write imperative workflow body (≤ 1,500-2,000 words)
4. Include **Red Flags table** (anti-rationalization)
5. Use **XML tags** for structured directives
6. Run `scripts/validate-skill-frontmatter.sh` (future — REC-013)

---

## Frontmatter Rules

Follow **ADR-011** for the `description` field. Summary:

| Field | Required | Format | Example |
|-------|----------|--------|---------|
| `name` | ✅ | kebab-case, regex `^[a-z][a-z0-9]*(-[a-z0-9]+)*$` | `systematic-debugging` |
| `description` | ✅ | Form A (canonical) or Form B (shorthand), ≤ 500 chars | See below |
| `effort` | ✅ | `low` / `medium` / `high` | `high` for deep reasoning skills |
| `version` | recommend | SemVer | `0.1.0` (initial), `1.0.0` (stable) |
| `metadata.category` | recommend | domain/meta/workflow/infra | `workflow` |
| `metadata.sources` | optional | citation list if derived | `[obra/superpowers writing-skills]` |

### Form A — Anthropic canonical (default, user-facing skills)

```yaml
description: "Strategic idea intake and roadmap integration. This skill should be used when the user says 'nouvelle idée', 'idea', 'feature request', 'what if', 'on devrait'."
```

### Form B — obra shorthand (meta/internal skills)

```yaml
description: "Scope drift detector. Use when touching files outside original task scope, before proceeding with changes."
```

### Forbidden patterns (CSO violations)

```yaml
# ❌ BAD: summarizes workflow — Claude will follow description, skip body
description: "Dispatches subagent per task with code review between tasks and two-stage verification"

# ❌ BAD: first person
description: "I help you debug by checking for race conditions"

# ❌ BAD: pure workflow summary (no triggers)
description: "Learn facts, preferences, relationships about the user"
```

---

## XML Tag Conventions

ATLAS adopts structured XML tags from obra/superpowers for **behavior-shaping emphasis**. These are not markup — they are **parsed directives** that Claude recognizes.

### `<EXTREMELY-IMPORTANT>`

Non-negotiable rules. Claude treats content inside as blocking instructions.

```markdown
<EXTREMELY-IMPORTANT>
Never commit secrets. If `gitleaks` flags a value, STOP and ask.
</EXTREMELY-IMPORTANT>
```

Use for:
- 1% rules ("even 1% chance → invoke skill")
- Security invariants
- HITL gate triggers

### `<SUBAGENT-STOP>`

Marks sections that subagents should skip. Useful for skills that have autonomous-invocation logic but behave differently when dispatched.

```markdown
<SUBAGENT-STOP>
If you were dispatched as a subagent with a specific scoped task, skip
the autonomous skill-discovery logic below. Your dispatcher decided.
</SUBAGENT-STOP>
```

### `<REQUIRED:>` / `<SEE-ALSO:>`

Cross-skill dependencies. Use inline, not as block.

```markdown
**REQUIRED:** atlas-core:atlas-assist — base context for routing
**SEE ALSO:** atlas-dev-addon:tdd, atlas-admin-addon:security-audit
```

**DO NOT** use `@` syntax for cross-references — it force-loads 200k+ tokens immediately. Use skill-name references only.

---

## Red Flags Tables (anti-rationalization)

Every skill that shapes agent behavior (as opposed to pure reference docs) should include a **Red Flags table**. Purpose: intercept the rationalizations Claude generates to avoid invoking the skill.

Pattern:

```markdown
## Red Flags (rationalization check)

Before skipping this skill, ask yourself — are any of these thoughts
running? If yes → STOP, you're rationalizing.

| Thought | Reality |
|---------|---------|
| "This is a simple question" | Questions are tasks. Check for skills. |
| "I know this pattern already" | Skills evolve. Read current version. |
| "The skill is overkill here" | Simple → complex fast. Use it. |
```

Minimum 3 rows. Draw from observed rationalizations in your own ATLAS sessions (add new rows when new rationalization patterns emerge).

---

## Skill Structure (body)

After frontmatter + optional XML tags, follow this outline:

```markdown
# {Skill Title}

## Overview
{1-2 sentences: what IS this skill? Core principle}

## When to Use
{Bullet list: triggers + anti-triggers}

## Red Flags (if behavior-shaping)
{Table as above}

## Required Background (optional)
{REQUIRED/SEE-ALSO cross-references}

## Workflow
### Step 1: {action}
### Step 2: {action}
### Step 3: {action}

## Quick Reference
{Table or bullets for scanning}

## Common Mistakes
{Bullets with fix}

## Real-World Impact (optional)
{Concrete outcomes, incidents prevented}

## References
{Links to related skills, docs, external}
```

---

## Writing Style

### Imperative form (preferred)

> "To debug, run `pytest -x`. Check output. Fix first failing test."

### NOT second person

> ❌ "You should run pytest and check the output..."

### NOT first person

> ❌ "I will debug by running pytest..."

### NOT narratives

> ❌ "Once upon a time, I had a bug. I ran pytest..."

Skills are **procedural knowledge** for future Claude instances. Keep them procedural.

---

## Token Budget

Per **obra/superpowers** guidelines (evidence-based):

| Skill type | Word limit (SKILL.md body) |
|------------|----------------------------|
| getting-started workflows (always loaded) | **<150 words** |
| Frequently-referenced skills | **<200 words** |
| Standard skills | **<500 words** |
| Reference/comprehensive skills | **<2,000 words** |

Techniques to stay under budget:
- Move detailed content to `references/` subdir — loaded only when Claude needs it
- Move scripts to `scripts/` — executed without loading to context
- Use cross-references instead of repeating content
- Compress examples aggressively

Verification: `wc -w skills/**/SKILL.md | sort -n`

---

## Bundled Resources (optional)

Per **Anthropic official** structure:

```
skill-name/
├── SKILL.md              # required
├── references/           # optional — docs loaded on-demand
│   ├── patterns.md
│   └── advanced.md
├── scripts/              # optional — executable code
│   └── helper.sh
└── assets/               # optional — files for output, not context
    ├── template.pptx
    └── logo.png
```

- `scripts/` — executed deterministically, token-efficient
- `references/` — Claude loads only when needed (grep-friendly)
- `assets/` — never loaded as context, used in Claude's output

---

## Validation

Before committing a new skill:

```bash
# Check frontmatter format
bash scripts/validate-skill-frontmatter.sh skills/your-skill/SKILL.md  # future (REC-013)

# Check word count
wc -w skills/your-skill/SKILL.md

# Run skill-lint for security (REC-015, ADR-013)
bash scripts/pre-install-skill-check.sh skills/your-skill/

# Activation test (REC-001 — when framework ships)
bash tests/skill-triggering/run-test.sh your-skill prompts/your-skill.txt
```

---

## Migration Path (existing skills)

For skills that don't conform to this template:

1. **Prioritize by tier**: user-facing (high visibility) first
2. **Fix description** (ADR-011): Form A or Form B only
3. **Add Red Flags table** if behavior-shaping
4. **Adopt XML tags** where emphasis needed
5. **Measure token count**: move overflows to `references/`
6. **Validate**: run lint + activation test

Full migration is tracked as **REC-002** (CSO audit) — separate plan required.

---

## References

- `templates/SKILL.md.template` — canonical starting point
- `docs/ADR/ADR-011-skill-description-convention.md` — description rules
- `docs/ADR/ADR-013-skill-lint-security-baseline.md` — security gate
- obra/superpowers `skills/writing-skills/SKILL.md` — TDD-for-skills
- anthropics/claude-plugins-official `plugins/plugin-dev/skills/skill-development/SKILL.md` — canonical structure
- `synapse/.blueprint/reports/atlas-benchmark-report-2026-04-19.md` — benchmark source

---

*SKILL-AUTHORING.md v1.0 — 2026-04-19 — authored as plan `joyful-hare` Batch 1 REC-004. Living doc.*
