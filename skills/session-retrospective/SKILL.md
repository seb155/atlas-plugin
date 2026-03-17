---
name: session-retrospective
description: "End-of-session review, close, and handoff. Capture lessons learned, update memory, note improvements, verify task completion. Includes session close (summary + cleanup) and handoff (context preservation for resume)."
---

# Session Retrospective

## When to Run
- Before closing or pausing a session
- After completing a major feature/phase
- When context budget is getting tight

## Process

### 1. Task Completion Check
- Run TaskList — verify all tasks are completed or documented
- Any in_progress tasks — note what's remaining

### 2. Lessons Learned
- What surprised you? (unexpected complexity, gotchas)
- What worked well? (patterns, approaches to repeat)
- What would you do differently? (mistakes to avoid)

Save significant lessons to memory (if applicable):
```markdown
# memory/lessons.md (append)
- #{N}: {lesson} — {context}
```

### 3. Improvements Discovered
During the session, did you notice:
- Tech debt? (hardcoded values, duplicated code, missing tests)
- Performance issues? (slow queries, large bundles)
- Security gaps? (missing validation, RBAC holes)
- Documentation gaps? (missing docs, outdated docs)
- SOTA upgrades? (newer library versions, better patterns)

Add to `.blueprint/IMPROVEMENTS.md`:
```markdown
## {date} — Session: {description}

### CRITICAL
- {issue}

### IMPORTANT
- {issue}

### NICE-TO-HAVE
- {issue}

### SOTA
- {upgrade opportunity}
```

### 4. Plan Updates
- Were any plans modified? Update .blueprint/plans/INDEX.md
- New decisions made? Verify they're in decisions.jsonl
- Scope changed? Update the plan

### 5. Summary
Produce a concise session summary:

```
Session Summary — {date}

Completed: {list of completed tasks}
In Progress: {list of remaining tasks}
Decisions: {key decisions made}
Improvements: {N} items added to IMPROVEMENTS.md
Lessons: {key lessons}
```

---

## Session Close Mode

When closing a session (work is **done**, clean finish):

### Close Step 1: Run Steps 1-5 Above

Execute the full retrospective first.

### Close Step 2: Todo Cleanup

Review the current todo list:
- **Completed tasks**: Confirm marked done
- **Incomplete tasks**: Use AskUserQuestion: "Des taches restent incompletes. Voulez-vous les reporter a la prochaine session?"

### Close Step 3: Git Status

Run `git status` and `git log --oneline -5` to capture state.

### Close Step 4: Final Output

```
SESSION COMPLETE

ACCOMPLISHMENTS
- [main work done]
- [key milestones reached]

FILES MODIFIED
- [key files changed — from git status]

CARRY-FORWARD (if any)
- [pending items for next session]
```

---

## Handoff Mode

When pausing a session (will **resume later**, context preservation):

### Handoff Step 1: Run Steps 1-5 Above

Execute the full retrospective first.

### Handoff Step 2: Capture Session State

Collect:
1. **Session metadata** — date, duration estimate, focus area
2. **Task state** — active tasks and completion status (from TaskList)
3. **Recent decisions** — key choices made during work
4. **Work summary** — what was accomplished
5. **Next steps** — how to resume
6. **File references** — key files modified or created (from `git status`)
7. **Branch/worktree** — current branch, worktree name if applicable

### Handoff Step 3: Generate Structured Handoff

**A) JSON handoff** (for `/atlas pickup` — machine-readable):

Write to `.claude/handoffs/latest.json`:

```json
{
  "id": "{project}-{YYYY-MM-DD}-{HH}",
  "date": "YYYY-MM-DDTHH:MM:SSZ",
  "project": "{project name from CLAUDE.md or directory}",
  "branch": "{current branch}",
  "commit": "{HEAD commit hash}",
  "plan": "{path to active plan, e.g. .blueprint/plans/platform-intelligence.md}",
  "phase": 1,
  "summary": "{1-line summary of what was accomplished}",
  "next_steps": ["{step 1}", "{step 2}"],
  "decisions": ["{decision 1}", "{decision 2}"],
  "files_modified": ["{file 1}", "{file 2}"],
  "tasks_pending": ["{task 1}", "{task 2}"],
  "resume_prompt": "lis {plan_path} et commence phase {N}. Contexte: {summary}"
}
```

**B) Markdown handoff** (for humans — readable):

Write to project root: `handoff-{YYYY-MM-DD}.md`

```markdown
# Handoff Context - {Date}

## Resume Session
**Date**: YYYY-MM-DD HH:MM
**Duration**: ~XX min
**Focus**: {work focus area}
**Branch**: {branch name}

## What was done
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
{specific instructions for next session}

## Key Files Modified
- {file path 1}
- {file path 2}

---
*Handoff created YYYY-MM-DD_HH-MM*
```

### Handoff Step 4: Memory Update

If sprint status or architecture changed during the session:
- Update MEMORY.md with new state
- Update session-log.md with session entry

### Handoff Options

- **Default**: auto-generate from session state (git activity, task list)
- **Manual** (`--manual`): interactive prompts for focus, accomplishments, blockers, resume instructions
- **Custom summary** (`--summary "text"`): use provided summary instead of auto-generating

## Key Difference: Close vs Handoff

| | Close | Handoff |
|--|-------|---------|
| **Intent** | Session complete | Will resume later |
| **Output** | Summary display | `handoff-{date}.md` file |
| **Tasks** | Mark done or abandon | Preserve state for resume |
| **Memory** | Update if needed | Always update |
| **Next session** | Fresh start | Read handoff file first |
