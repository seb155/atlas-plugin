# ATLAS Plugin Patterns

> Copy-paste templates for extending the plugin. Each pattern includes the minimum viable
> implementation — add domain logic after scaffolding.

---

## Pattern 1: New Skill

### 1a. Create SKILL.md

```markdown
<!-- skills/{name}/SKILL.md -->
---
name: {name}
description: "{One-line description}. Use when {trigger conditions}."
effort: medium
---

# {Title}

{Content — instructions for Claude when this skill is active}
```

### 1b. Add to profile

```yaml
# profiles/{tier}.yaml — add under skills:
skills:
  - {name}
```

### 1c. Add to generate-master-skill.sh

```bash
# scripts/generate-master-skill.sh — add to ALL 3 maps:
# EMOJI_MAP:
[{name}]="🎯"
# DESC_MAP:
[{name}]="{One-line description}"
# CATEGORY_MAP:
[{name}]="CategoryName"
```

### 1d. Create command

```markdown
<!-- commands/{name}.md -->
Invoke the {name} skill with: $ARGUMENTS
```

### 1e. Verify

```bash
make test   # validates frontmatter, coverage, cross-refs
make dev    # install + test in live CC session
```

---

## Pattern 2: New Agent

```markdown
<!-- agents/{name}/AGENT.md -->
---
name: {name}
description: "{Purpose}. {Model} agent. {Key capability}."
model: sonnet  # opus | sonnet | haiku
---

# {Name} Agent

## Purpose
{What this agent does autonomously}

## Workflow
1. {Step 1}
2. {Step 2}
3. {Step 3}

## Tools Available
All tools except {deny list if read-only}

## Output Format
{Expected output structure}
```

Add to `profiles/{tier}.yaml` under `agents:`.

---

## Pattern 3: New Hook

### 3a. Create script

```bash
#!/usr/bin/env bash
# hooks/{name}
# Event: {SessionStart|UserPromptSubmit|PostToolUse|...}

# Read input from stdin (JSON)
INPUT=$(cat)

# Process...
RESULT="relevant info"

# Branded output (MANDATORY format)
echo "🏛️ ATLAS │ {emoji} {CATEGORY} │ ${RESULT}"
```

### 3b. Register in hooks.json

```json
{
  "hooks": [
    {
      "event": "SessionStart",
      "command": "bash hooks/{name}",
      "async": true,
      "timeout": 5000
    }
  ]
}
```

### 3c. Make executable

```bash
chmod +x hooks/{name}
```

**Rules**:
- Async hooks: max 5s, exit 0 on error (non-blocking)
- Sync hooks: max 10s, can block
- ALL hooks are copied to ALL tiers (wildcard)
- Always brand with `🏛️ ATLAS │`

---

## Pattern 4: New Command

```markdown
<!-- commands/{name}.md -->
Invoke the {skill-name} skill with: $ARGUMENTS
```

Add to `profiles/{tier}.yaml` under `commands:`.

**Routing convention**: Command file name = what user types (`/atlas {name}`).
Content = instruction to load the skill.

---

## Pattern 5: New Reference

```markdown
<!-- skills/refs/{name}/SKILL.md -->
---
name: {name}
description: "{Topic} reference guidelines. Use when {context}."
effort: low
---

# {Title} Reference

{Reference content — guidelines, patterns, best practices}
{This is injected as context, NOT as an interactive skill}
```

Add to `profiles/{tier}.yaml` under `refs:`.

---

## Pattern 6: Skill with HITL Gate

```markdown
<!-- Inside SKILL.md -->

## HITL Gates (NON-NEGOTIABLE)

Before proceeding past {phase}, you MUST:
1. Present findings to user via AskUserQuestion
2. Wait for explicit approval
3. Only proceed after "yes" / "approved" / "go ahead"

Never skip HITL gates. Never assume approval from previous interactions.
```

---

## Pattern 7: Skill with Subagent Dispatch

```markdown
<!-- Inside SKILL.md -->

## Agent Dispatch

For {task type}, dispatch a subagent:

Use the Agent tool with:
- `subagent_type`: "{agent-name}"
- `model`: "sonnet"  (or opus for architecture)
- `prompt`: Include full context + expected output format

Review agent output before presenting to user.
```

---

## Pattern 8: Visual Identity Output

All hook and skill outputs follow the ATLAS visual identity:

### Hook Output
```
🏛️ ATLAS │ {emoji}{severity} {CATEGORY} │ {message}
```

### Skill Breadcrumb
```
🏛️ ATLAS │ {PHASE} › {emoji} {skill-name} › {current-step}
─────────────────────────────────────────────────────────────────
```

### Response Footer
```
─────────────────────────────────────────────────────────────────
📌 Recap
• {key info 1}
• {key info 2}

🎯 Next Steps
  1. {recommended action}
  2. {alternative}

💡 Recommendation: {bold recommendation}
─────────────────────────────────────────────────────────────────
```

### Severity Levels
| Emoji | Level | Usage |
|-------|-------|-------|
| ✅ | Success | Operation completed |
| ⚠️ | Warning | Non-blocking issue |
| ❌ | Error | Blocking issue |
| ℹ️ | Info | Status update |

---

## Checklist: Adding Any Component

- [ ] Component file created with proper frontmatter
- [ ] Added to correct tier in `profiles/{tier}.yaml`
- [ ] Command file created in `commands/` (if applicable)
- [ ] Emoji/Desc/Category maps updated in `generate-master-skill.sh` (skills only)
- [ ] `make test` passes (all 16 test files)
- [ ] `make dev` — tested in live CC session
- [ ] SKILL-CATALOG.md updated (`.blueprint/SKILL-CATALOG.md`)

---

*Updated: 2026-03-22 | Maintain when: new pattern discovered or existing pattern changes*
