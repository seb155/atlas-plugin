---
name: skill-management
description: "Create, improve, benchmark, and manage Claude Code skills and plugins. This skill should be used when the user asks to 'create a skill', 'write a new skill', 'improve this skill', 'add a skill to the plugin', 'create a plugin', 'benchmark a skill', 'review skill quality', or needs guidance on skill structure, progressive disclosure, SKILL.md format, or plugin development."
effort: low
---

# Skill & Plugin Management

Create, improve, and maintain Claude Code skills and plugins. Covers the full lifecycle from ideation to packaging.

## Red Flags (rationalization check)

Before skipping skill-management conventions, ask yourself — are any of these thoughts running? If yes, STOP. Skills are behavior-shaping code; malformed skills silently fail to activate.

| Thought | Reality |
|---------|---------|
| "I'll wing the SKILL.md format" | Malformed frontmatter breaks discovery. Always copy `templates/SKILL.md.template`. |
| "Description = what the skill does" | Description = WHEN to use, not WHAT it does (CSO rule, ADR-011). Workflow summary = skill-body skip. |
| "I don't need Red Flags for this skill" | Behavior-shaping skills need them (ADR-009). Utility/reference skills are exempt. |
| "5000 words is fine, more detail is better" | Target 1500-2000 (ADR-010). Past 5000 = Level 3 candidates (move to references/). |
| "Inline scripts in SKILL.md is convenient" | Anti-pattern. Move to `scripts/` (executable) or `references/` (docs loaded on demand). |
| "I'll edit the plugin cache directly" | NEVER. `~/.claude/plugins/cache/` is read-only. Edit source repo, then `make dev`. |
| "Progressive Disclosure is ceremony" | Level 1 (frontmatter) always loaded, Level 2 on trigger, Level 3 on-demand. Saves 80%+ context. |
| "Skip the activation test — it's manual" | Without pressure-test RED/GREEN (obra TDD-for-skills), you can't verify the skill triggers. |

## Skill Anatomy

```
skill-name/
├── SKILL.md              # Required: frontmatter + instructions
├── references/           # Optional: detailed docs (loaded on demand)
├── scripts/              # Optional: executable utilities
├── examples/             # Optional: working code examples
└── assets/               # Optional: templates, images, fonts
```

### SKILL.md Structure

```yaml
---
name: skill-name
description: "Third-person description with trigger phrases. This skill should be used when the user asks to 'do X', 'do Y', 'do Z'."
---

# Skill Title

[Body: imperative/infinitive form instructions, 1500-2000 words ideal, <5k max]
[References to bundled resources]
```

### Progressive Disclosure (3 levels)
1. **Metadata** (name + description) — always in context (~100 words)
2. **SKILL.md body** — loaded when skill triggers (<5k words)
3. **Bundled resources** — loaded as needed by Claude (unlimited)

## Skill Creation Process

### 1. Understand Use Cases
Gather concrete examples of how the skill will be used.
Ask via AskUserQuestion:
- What functionality should the skill support?
- What would a user say to trigger it?
- What examples demonstrate the workflow?

### 2. Plan Resources
For each use case, identify:
- **Scripts**: Code rewritten repeatedly → extract to `scripts/`
- **References**: Schemas, docs, domain knowledge → extract to `references/`
- **Assets**: Templates, images, boilerplate → extract to `assets/`

### 3. Create Structure
```bash
mkdir -p skills/{name}/{references,examples,scripts}
```

### 4. Write SKILL.md
**Frontmatter rules**:
- `name`: kebab-case identifier
- `description`: third-person, specific trigger phrases, concrete scenarios
- No other fields

**Body rules**:
- Imperative/infinitive form (NOT second person)
- Keep lean: 1500-2000 words, move detail to references/
- Reference all bundled resources explicitly
- Include when-to-read guidance for reference files

### 5. Validate
| Check | Pass criteria |
|-------|---------------|
| Frontmatter | Has `name` and `description` |
| Description | Third-person, specific triggers, not vague |
| Body style | Imperative form, no "you should" |
| Size | SKILL.md < 3000 words (ideally 1500-2000) |
| References | All referenced files exist |
| Examples | Complete and working |
| Progressive disclosure | Detail in references/, core in SKILL.md |

### 6. Iterate
Use the skill on real tasks → notice struggles → update → repeat.

## Plugin Structure

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json        # Manifest
├── commands/              # Slash commands (.md files)
├── skills/                # Skills (directories with SKILL.md)
├── agents/                # Agent definitions (.md files)
├── hooks/                 # Hook scripts (Python/Bash)
└── templates/             # Shared templates
```

### plugin.json Manifest
```json
{
  "name": "plugin-name",
  "version": "0.1.0",
  "description": "What this plugin does"
}
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Vague description | Add specific trigger phrases |
| Everything in SKILL.md | Move detail to references/ |
| Second person ("you should") | Use imperative ("Configure the...") |
| No resource references | Link to references/, examples/, scripts/ |
| Weak triggers | Add quoted user phrases in description |
| Over 3000 words in SKILL.md | Split to reference files |

## HITL Gates

- Before creating a new skill → confirm purpose and scope via AskUserQuestion
- After writing SKILL.md → present for review before finalizing
- Before packaging → validate checklist with user
