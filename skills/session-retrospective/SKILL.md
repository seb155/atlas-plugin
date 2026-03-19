---
name: session-retrospective
description: "End-of-session review, close, and handoff. Capture lessons learned, update memory, note improvements, verify task completion. Includes session close (summary + cleanup) and handoff (context preservation for resume)."
effort: low
---

# Session Retrospective

## When to Run
- Before closing or pausing a session
- After completing a major feature/phase
- When context budget is getting tight

## Core Process (Steps 1-5, always run first)

### 1. Task Completion Check
Run TaskList → verify all tasks completed or documented. Note in_progress items.

### 2. Lessons Learned
What surprised you? What worked well? What to avoid? Save significant lessons:
`memory/lessons.md` → append `- #{N}: {lesson} — {context}`

### 3. Improvements Discovered
Add to `.blueprint/IMPROVEMENTS.md` with categories: CRITICAL / IMPORTANT / NICE-TO-HAVE / SOTA.
Look for: tech debt, perf issues, security gaps, doc gaps, SOTA upgrades.

### 4. Plan Updates
Update `.blueprint/plans/INDEX.md` if plans modified. Verify decisions in `decisions.jsonl`.

### 5. Summary
Produce: Completed tasks, In Progress, Decisions, Improvements count, Key lessons.

---

## Two Modes

| | Close (work done) | Handoff (resume later) |
|--|---|---|
| **Intent** | Clean finish | Preserve context |
| **Tasks** | Mark done or abandon | Preserve state |
| **Memory** | Update if needed | Always update |
| **Output** | Summary display | `handoff-{date}.md` + `.claude/handoffs/latest.json` |
| **Next session** | Fresh start | Read handoff first |

### Close Mode

After steps 1-5:
1. **Todo cleanup**: Confirm done tasks. AskUserQuestion for incomplete: reporter a la prochaine session?
2. **Git status**: `git status` + `git log --oneline -5`
3. **Final output**: ACCOMPLISHMENTS + FILES MODIFIED + CARRY-FORWARD

### Handoff Mode

After steps 1-5:

**1. Capture state**: session metadata, task state (TaskList), recent decisions, work summary, next steps, files modified (`git status`), branch/worktree.

**2. Generate RICH handoff** (not just a task list):

| Section | Content | Why |
|---------|---------|-----|
| **Context Reload** | List 5 files to read first (FEATURES.md, active plan, INDEX.md, CLAUDE.md, MEMORY.md) | Next session loads these → instant context |
| **État du Projet** | Branch, HEAD, feature board summary, epic progress bars | See project state at a glance |
| **Plan Actif** | Plan file path + phase table (done/next/todo) | Know exactly where we are |
| **Décisions** | Each decision + WHY + alternatives rejected | Don't re-debate settled decisions |
| **Erreurs / Dead-Ends** | What we tried that failed + why | Don't re-try known failures |
| **Feedback Humain** | What user said that shaped approach + memory file ref | Preserve user preferences |
| **Worktrees** | Active worktrees with branch mapping | Know the git topology |
| **Fichiers Modifiés** | Files changed this session (from git) | Quick scan of scope |
| **Issues Connues** | Open bugs, blockers, infra issues | Don't be surprised |
| **Pour Reprendre** | Exact commands to run | Zero-friction resume |

**Output locations**:
- `handoff-{YYYY-MM-DD}.md` in project root (human-readable, git-tracked)
- `.claude/handoffs/latest.json` (machine-readable for `/pickup`)

**3. Memory update**: Update MEMORY.md + session-log.md if sprint/architecture changed.

**Options**: `--manual` (interactive prompts) | `--summary "text"` (custom summary) | default (auto from git + tasks)
