---
name: handoff
description: Create session handoff context for seamless session resumption
argument-hint: "[--manual] [--summary 'text']"
---

# /handoff - Session Handoff

Generate a structured handoff to preserve session context between Claude Code sessions.

## Quick Actions

| Command | Description |
|---------|-------------|
| `/handoff` | Auto-generate handoff from current session state |
| `/handoff --manual` | Interactive handoff with prompts |
| `/handoff --summary "text"` | Generate with custom summary |

## What Gets Captured

1. **Session metadata** - Date, duration, focus area
2. **Task state** - Active tasks and their completion status
3. **Recent decisions** - Key choices made during work
4. **Work summary** - What was accomplished
5. **Next steps** - How to resume work
6. **File references** - Key files modified or created

## Default Mode

```bash
/handoff
```

This will:
- Read current task list state
- Scan recent git activity
- Generate a handoff markdown file

## Manual Mode

```bash
/handoff --manual
```

Prompts you to provide:
- Session focus description
- Key accomplishments
- Blocking issues (if any)
- Specific resume instructions

## Custom Summary

```bash
/handoff --summary "Completed Phase 1, created new API endpoints"
```

Uses your summary instead of auto-generating one.

## Handoff File Format

The generated markdown follows this structure:

```markdown
# Handoff Context - {Date}

## Resume Session
**Date**: YYYY-MM-DD HH:MM
**Duration**: ~XX min
**Focus**: {Work focus area}

## What was done ✅
### 1. {Task Category}
- {accomplishment 1}
- {accomplishment 2}

## Task State
- [ ] {incomplete task 1}
- [x] {completed task 2}

## Key Decisions
- Decision 1: {description}
- Decision 2: {description}

## To Resume
{Instructions for next session}

## Key Files Modified
- {file path 1}
- {file path 2}

---
*Handoff created YYYY-MM-DD_HH-MM*
```

## Output Location

Save handoff to project memory directory:

```
memory/handoff-{date}.md
```

## Resuming from Handoff

Use `/pickup` to resume from the most recent handoff file.

## Related Commands

- `/end` - Close session (final, not a pause)
- `/ship` - Commit and push before handoff
- `/pickup` - Resume from handoff

ARGUMENTS: $ARGUMENTS
