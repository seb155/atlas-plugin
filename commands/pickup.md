# /pickup — Resume a previous session with full context reload

Resume work from a handoff file. Loads context, reads referenced files, presents briefing with next action.

## Process

### Step 1: Find handoff files

```bash
ls -t memory/handoff-*.md 2>/dev/null   # Memory directory, sorted by date desc
ls -t handoff-*.md 2>/dev/null           # Project root fallback
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

🎯 Suggested next action:
  {from handoff next_steps}
─────────────────────────────────────────────────────────────────
```

### Step 4: AskUserQuestion for next action

Present ONLY the next steps listed in the handoff file's "Prochaines étapes" or "Next Steps" section.
Do NOT add tasks from other features, dirty files, or the general feature board.
The handoff already curated what's relevant — trust it.

### Step 5: Drill into selected action (NON-NEGOTIABLE)

When user selects a next action, **stay in that context**. No re-presenting the pickup menu.

**Process**:

1. **Load context for the selection**:
   - Read the associated plan file (from handoff "Plan Actif" section)
   - Read the FEATURES.md entry for the selected feature
   - Identify the current phase/step in the plan

2. **Switch to correct worktree** (if feature work):
   ```bash
   # Check if worktree exists for this feature
   git worktree list | grep feature/{name}
   ```

3. **Present ONLY tasks from the selected plan/feature** via AskUserQuestion

4. **On task selection → Enter Plan Mode first (NON-NEGOTIABLE)**:
   - Read the FULL plan file (not just summary — every section)
   - **Enter plan mode** to prepare implementation plan
   - ONLY after approval → Create TaskList + start coding

**Rules**:
- **ALWAYS plan before code** — even for "simple" tasks
- Never go back to the handoff/pickup menu after drilling in
- Stay in the selected feature/plan context for the rest of the session

## Related Commands

- `/handoff` - Create handoff (pair with /pickup)
- `/end` - Close session (final)
- `/ship` - Commit and push

ARGUMENTS: $ARGUMENTS
