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
   # If exists: cd .worktrees/{name}
   ```

3. **Present task breakdown** via AskUserQuestion:
   ```
   🏛️ ATLAS │ P4 Backend API — Tasks
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Plan: glittery-cuddling-phoenix.md (Section P4)
   Branch: dev | Worktree: (main)

   | # | Task                              | Effort | Dep |
   |---|-----------------------------------|--------|-----|
   | 1 | FEATURES.md parser (regex)        | 1-2h   | —   |
   | 2 | GET /features endpoint            | 1h     | #1  |
   | 3 | GET /features/{id} endpoint       | 1h     | #1  |
   | 4 | GET /features/board endpoint      | 1h     | #1  |
   | 5 | GET /features/matrix endpoint     | 1h     | #1  |
   | 6 | Tests + validation                | 1-2h   | #2-5|

   Which task to start? (or "all" to create TaskList and go)
   ```

4. **On task selection → Enter Plan Mode first (NON-NEGOTIABLE)**:
   - Read the FULL plan file (not just summary — every section)
   - Read the FEATURES.md entry for the feature
   - Read the relevant backend/frontend files that will be modified
   - **Enter plan mode** (EnterPlanMode) to prepare implementation plan
   - In plan mode: write a focused implementation plan for THIS phase only
   - Present plan with tasks, files, dependencies → HITL approval
   - ONLY after approval → Create TaskList + start coding

   This ensures the AI understands the FULL context before writing any code.
   The plan mode also lets the user review and adjust before committing.

**Rules**:
- **ALWAYS plan before code** — even for "simple" tasks
- Never go back to the handoff/pickup menu after this point
- Stay in the selected feature/plan context for the rest of the session
- If user wants to switch → they say "switch to X" or run `/pickup` again

**Usage**: `/pickup` or `/atlas pickup`

ARGUMENTS: $ARGUMENTS
