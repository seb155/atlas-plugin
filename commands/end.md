---
name: end
description: Properly close and finalize a session with summary and cleanup
argument-hint: "[--quiet]"
---

# /end - Session Close

Properly close a work session with summary and cleanup.

## Usage

| Command | Description |
|---------|-------------|
| `/end` | Full session close with summary |
| `/end --quiet` | Minimal output, just finalize |

## Difference from /handoff

| Command | Intent | When to Use |
|---------|--------|-------------|
| `/handoff` | Pause, will resume later | Mid-task break, context preservation |
| `/end` | Session complete | Work done, clean finish |

```
Session Lifecycle:
[start] → [work] → /end (close)
                 ↓
            /handoff (pause)
```

## Instructions

Execute the full session close workflow:

### Step 0: Session Retrospective

Before generating the session summary, invoke the `session-retrospective` skill to capture lessons learned:
- New gotchas → append to project's `lessons.md`
- Verify all decisions are logged in `.claude/decisions.jsonl`
- Session summary → append to project's `session-log.md`
- Update MEMORY.md if sprint status or architecture changed
- Check CI status if code was pushed during session

### Step 1: Todo Cleanup

Review the current todo list from this conversation:

- **Completed tasks**: Confirm they're marked done
- **Incomplete tasks**: Decide: carry-forward or abandon?

```
If tasks remain pending, ask user via AskUserQuestion:
"Des taches restent incompletes. Voulez-vous les reporter a la prochaine session?"
```

### Step 2: Generate Summary

Create a final summary covering:

1. **Accomplishments** - What was achieved
2. **Files Modified** - Key changes (from git status)
3. **Pending** - Anything remaining (if applicable)

### Step 3: Display Final Output

```
┌─────────────────────────────────────────────────────────────┐
│ 👋 SESSION COMPLETE                                          │
├─────────────────────────────────────────────────────────────┤
│ ✅ ACCOMPLISHMENTS                                           │
│ • [Summarize main work done]                                 │
│ • [Key milestones reached]                                   │
├─────────────────────────────────────────────────────────────┤
│ 📁 FILES MODIFIED                                            │
│ • [List key files changed]                                   │
├─────────────────────────────────────────────────────────────┤
│ ⏳ CARRY-FORWARD (if any)                                    │
│ • [Pending items for next session]                           │
└─────────────────────────────────────────────────────────────┘

A bientot! 🚀
```

## Behavior Rules

1. **Always show accomplishments** - End on a positive note
2. **Be honest about pending work** - Don't hide unfinished tasks
3. **Clean exit** - User should feel closure

ARGUMENTS: $ARGUMENTS
