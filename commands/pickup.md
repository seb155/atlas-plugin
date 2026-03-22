# /pickup — Resume a previous session with full context reload

Resume work from a handoff file. Loads context, reads referenced files, presents briefing with next action.

## Process

### Step 1: Find handoff files

Search ALL 3 locations, sorted by modification time (most recent first):

```bash
ls -t .blueprint/handoffs/handoff-*.md 2>/dev/null   # Primary (gold standard location)
ls -t handoff-*.md 2>/dev/null                        # Legacy (project root)
ls -t .claude/handoffs/*.json 2>/dev/null              # Structured format
```

**If multiple found** → Read the first 30 lines of each handoff to extract summary. Present a comparison table via AskUserQuestion sorted by **date DESC** (most recent first), with age and priority indicators:

```
🏛️ ATLAS │ PICKUP — {N} sessions disponibles
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| # | Date       | Age | Focus                      | Livré             | Next Step        |
|---|------------|-----|----------------------------|--------------------|------------------|
| 1 | 2026-03-21 | 2h  | NetBird SSO + Mesh         | 6/6 nodes P2P ✅   | P2.7 DNS Fix     |
| 2 | 2026-03-21 | 5h  | IaC Phase 1 + NetBird      | PR #1 merged ✅    | P2.4 Authentik    |
| 3 | 2026-03-20 | 1d  | Test Coverage Phase 3      | 32 tests ✅        | FE visual tests  |

Quel session reprendre?
```

**Sorting rules**:
- Primary sort: date DESC (most recent first)
- If handoff has pending tasks with "CRITICAL" or "BLOCKER" → add 🔴 indicator
- Show "Age" column: `2h`, `5h`, `1d`, `3d` for quick scanning
- Handoffs older than 7 days → show as `⚠️ stale` (context may have drifted)

Extract from each handoff: the "Focus" line (header or first summary), "What was done" (first 2-3 bullets), and "Next Steps" (first item). Keep the table to 1 line per handoff for scannability.

**If only 1** → auto-load, no prompt.
**If none** → check `git log --oneline -5` + `.blueprint/plans/INDEX.md` + `.blueprint/FEATURES.md` to suggest what to work on.
**If argument provided** (e.g., `/pickup handoff-2026-03-21-netbird.md`) → load that specific file directly.

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

Present ONLY the next steps listed in the handoff file's "Prochaines étapes" or "Next Steps" section.
Do NOT add tasks from other features, dirty files, or the general feature board.
The handoff already curated what's relevant — trust it.

If the handoff lists "P4 Backend API" as next → that's the primary option.
Add at most 1-2 alternatives FROM THE SAME HANDOFF (not from other features).

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

3. **Present ONLY tasks from the selected plan/feature** via AskUserQuestion:

   **CRITICAL**: Do NOT mix tasks from other features/projects.
   Only show tasks that belong to the selected handoff action.
   Extract tasks from the plan file's phase section.

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

   Start with task #1? (or "all" for TaskList)
   ```

   **SCOPE RULE**: If user selected "P4 Backend API", do NOT show:
   - SynapseCAD tasks (different feature)
   - CI/CD tasks (different scope)
   - Rule Engine HITL (different feature)
   - Dirty files from other worktrees
   Only show P4-related work from the plan.

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
