# ATLAS Skill Authoring Guide

> **Version**: 2.0 | **Updated**: 2026-04-19 (Progressive Disclosure enforced)
> **Template**: `templates/SKILL.md.template`
> **ADRs**: ADR-010 (Progressive Disclosure), ADR-011 (description convention), ADR-013 (security)
> **Source**: plan `joyful-hare` — REC-004 (template) + REC-009 (PD enforcement)

---

## TL;DR

1. Copy `templates/SKILL.md.template` to `skills/<name>/SKILL.md`
2. Fill frontmatter (Level 1): `name`, `description` (ADR-011), `effort`, `version`, `metadata`
3. Write imperative workflow body (Level 2): **target 1500-2000 words, cap 5000**
4. Add bundled resources (Level 3) only if needed: `scripts/` / `references/` / `assets/`
5. Include **Red Flags table** (anti-rationalization)
6. Use **XML tags** for structured directives
7. Run verification: `wc -w SKILL.md` (≤5000) + `bash tests/skill-triggering/run-test.sh <name> prompts/<name>.txt` (activation check)

---

## Progressive Disclosure — 3 Levels (MANDATORY per ADR-010)

ATLAS skills follow Anthropic's canonical 3-level loading system to balance discoverability with context efficiency.

### Level 1 — Metadata (always loaded)

Frontmatter only. ~100 words. Drives skill activation decision.

```yaml
---
name: skill-name-kebab-case
description: "{PURPOSE}. This skill should be used when the user asks to 'X', 'Y', 'Z'."
effort: low | medium | high
version: 0.1.0
metadata:
  category: workflow | meta | domain | infra
  sources: [citations]
---
```

### Level 2 — SKILL.md body (loaded when skill triggers)

**Target**: 1,500-2,000 words. **Hard cap**: 5,000 words.

Content structure:
- Overview (1-2 sentences)
- When to Use / When NOT to Use
- Red Flags table (behavior-shaping skills)
- Workflow (imperative steps)
- Quick Reference
- Common Mistakes

### Level 3 — Bundled resources (on-demand)

Sibling directories, strict semantics:

| Subdir | Content type | Load behavior |
|--------|--------------|---------------|
| `scripts/` | Executable code (bash, python, node) | May be invoked via subprocess without loading to context |
| `references/` | Markdown/JSON/YAML documentation | Loaded into context when Claude deems it needed |
| `assets/` | Binary or static templates (PPTX, PNG, SVG) | **NEVER loaded as context** — used in Claude's OUTPUT only |

**Example**:
```
skills/document-generator/
├── SKILL.md              (Level 2, ~1800 words)
├── scripts/
│   └── render-pptx.py
├── references/
│   ├── pptx-schema.md
│   └── style-guide.md
└── assets/
    ├── template-exec.pptx
    └── template-technical.pptx
```

**Anti-patterns** (CSO-style failure modes):
- ❌ Inline 100-line code snippets in SKILL.md body → move to `scripts/`
- ❌ API reference tables in SKILL.md body → move to `references/`
- ❌ Templates as inline code blocks → move to `assets/`
- ❌ "Example output" in body when actual template exists in `assets/`

### Budget verification

```bash
# Check body length
wc -w skills/my-skill/SKILL.md   # target 1500-2000, must be ≤5000

# If >5000: audit body for Level 3 candidates
grep -n "```" skills/my-skill/SKILL.md  # long code blocks?
grep -c "^##" skills/my-skill/SKILL.md  # too many sections?
```

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
