# /pickup — Resume a previous session with full context reload

Resume work from a handoff file. Loads context, reads referenced files, presents briefing with next action.

## Process

### Step 1: Find handoff files

```bash
ls -t handoff-*.md 2>/dev/null   # Project root, sorted by date desc
ls -t .claude/handoffs/*.json 2>/dev/null  # Structured format
```

**If multiple found** → AskUserQuestion with list:
```
Found 3 handoff files:
  1. handoff-2026-03-19.md — Plugin v3.1 + Feature Mgmt P0-P3
  2. handoff-2026-03-18.md — SynapseCAD Sprint 1.5
  3. handoff-2026-03-17.md — Identity Platform P7-P8
Which session to resume?
```

**If only 1** → auto-load, no prompt.
**If none** → check `git log --oneline -5` + `.blueprint/plans/INDEX.md` + `.blueprint/FEATURES.md` to suggest.

### Step 2: Read handoff + Context Reload files

1. Read the selected handoff file completely
2. Find the "Context Reload" section — read EACH referenced file:
   - `.blueprint/FEATURES.md` (feature registry)
   - The active plan file (from handoff)
   - `.blueprint/plans/INDEX.md`
   - Any other files listed
3. Check git state:
   ```bash
   git branch --show-current
   git log --oneline -5
   git status --short
   git worktree list
   ```

### Step 3: Present rich briefing

```
🏛️ ATLAS │ PICKUP — Resuming session {date}
─────────────────────────────────────────────────────────────────

📋 Focus: {handoff summary}
🌿 Branch: {branch} @ {commit}
📊 Plan: {plan file} — Phase {N} next

📌 Key decisions from last session:
  • {decision 1 + why}
  • {decision 2 + why}

⚠️ Don't re-try:
  • {error 1 — already failed, here's why}

📈 Feature Board:
  {render /atlas board inline}

🎯 Suggested next action:
  {from handoff next_steps}
─────────────────────────────────────────────────────────────────
```

### Step 4: AskUserQuestion for next action

Present the suggested next steps from handoff + feature board suggestions.

**Usage**: `/pickup` or `/atlas pickup`

ARGUMENTS: $ARGUMENTS
