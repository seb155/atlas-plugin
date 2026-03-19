# /pickup — Resume a previous session with full context reload

Resume work from a handoff file. Loads context, reads referenced files, presents briefing with next action.

## Process

### Step 1: Find handoff files

```bash
ls -t handoff-*.md 2>/dev/null   # Project root, sorted by date desc
ls -t .claude/handoffs/*.json 2>/dev/null  # Structured format
```

**If multiple found** → Read the first 30 lines of each handoff to extract summary, then present a comparison table via AskUserQuestion:

```
🏛️ ATLAS │ PICKUP — {N} sessions disponibles
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| # | Date       | Focus                      | Livré             | Next Step        |
|---|------------|----------------------------|--------------------|------------------|
| 1 | 2026-03-19 | Plugin v3.1 + Feature Mgmt | P0-P3 ✅ board     | P4 Backend API   |
| 2 | 2026-03-18 | SynapseCAD Sprint 1.5      | 587 WIDs ✅        | Loop diagrams    |
| 3 | 2026-03-17 | Identity Platform          | Headscale ✅       | RBAC sync        |

Quel session reprendre?
```

Extract from each handoff: the "Focus" line (header or first summary), "What was done" (first 2-3 bullets), and "Next Steps" (first item). Keep the table to 1 line per handoff for scannability.

**If only 1** → auto-load, no prompt.
**If none** → check `git log --oneline -5` + `.blueprint/plans/INDEX.md` + `.blueprint/FEATURES.md` to suggest what to work on.

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

### Step 5: EXECUTE immediately after selection (NON-NEGOTIABLE)

When user selects a next action:
- **DO NOT** ask again, re-present options, or confirm
- **DO NOT** show another handoff or another pickup
- **IMMEDIATELY** start working on the selected action:
  - If plan exists → Read the plan, create TaskList, start Phase 1
  - If feature work → Switch to worktree, read FEATURES.md entry, start coding
  - If CI fix → Run diagnostics immediately
- The user already made their choice. **Just go.**

**Usage**: `/pickup` or `/atlas pickup`

ARGUMENTS: $ARGUMENTS
