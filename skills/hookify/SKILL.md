---
name: hookify
description: "Create and manage Claude Code hooks from conversation analysis or explicit instructions. This skill should be used when the user asks to 'create a hook', 'hookify this behavior', 'prevent this from happening again', 'add a guard rule', 'block dangerous commands', 'warn about bad patterns', or needs to create .claude/hookify.*.local.md rule files."
effort: medium
---

# Hookify — Create Claude Code Hooks

Create hook rules to prevent problematic behaviors. Rules can be derived from conversation analysis (detecting user frustrations) or from explicit instructions.

## Rule File Format

Rules are stored as `.claude/hookify.{rule-name}.local.md` in the project directory:

```markdown
---
name: {rule-name}
enabled: true
event: bash|file|stop|prompt|all
pattern: {regex-pattern}
action: warn|block
---

{Message shown to Claude when rule triggers}
```

### Frontmatter Fields

| Field | Required | Values | Description |
|-------|----------|--------|-------------|
| `name` | yes | kebab-case | Unique identifier (verb-first: warn-, block-, require-) |
| `enabled` | yes | true/false | Toggle without deleting |
| `event` | yes | bash, file, stop, prompt, all | Which hook event triggers |
| `pattern` | yes* | regex | Python regex to match (*or use `conditions` for advanced) |
| `action` | no | warn (default), block | Warn shows message; block prevents operation |

### Advanced Format (multiple conditions)

```yaml
conditions:
  - field: file_path
    operator: regex_match
    pattern: \.env$
  - field: new_text
    operator: contains
    pattern: API_KEY
```

**Operators**: `regex_match`, `contains`, `equals`, `not_contains`, `starts_with`, `ends_with`

**Fields by event type**:
- bash: `command`
- file: `file_path`, `new_text`, `old_text`, `content`
- prompt: `user_prompt`

## Workflow

### From Explicit Instructions
1. Parse user request for: what tool, what pattern, warn or block
2. Present proposed rule via AskUserQuestion
3. Write `.claude/hookify.{name}.local.md`
4. Confirm: rules are active immediately, no restart needed

### From Conversation Analysis
1. Launch a subagent to scan recent conversation for:
   - Explicit corrections ("don't do X", "stop doing Y")
   - Frustrated reactions ("why did you do X?")
   - Corrections/reversions (user fixing Claude's actions)
   - Repeated issues (same mistake multiple times)
2. Present findings via AskUserQuestion (multi-select which to hookify)
3. For each selected: ask warn vs block via AskUserQuestion
4. Generate and write rule files

## Common Patterns

| Behavior | Event | Pattern |
|----------|-------|---------|
| Dangerous rm | bash | `rm\s+-rf` |
| Privilege escalation | bash | `sudo\s+\|su\s+` |
| console.log in production | file | `console\.log\(` |
| eval/innerHTML | file | `eval\(\|innerHTML\s*=` |
| Editing .env files | file | `\.env$` |
| Missing tests before stop | stop | `.*` |

## HITL Gates

- Before creating any rule → confirm with AskUserQuestion
- For conversation-derived rules → present all findings, let user select
- After creation → test immediately and confirm active
