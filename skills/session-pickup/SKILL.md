---
name: session-pickup
description: "Session resume from handoff file. This skill should be used when the user asks to '/pickup', '/atlas pickup', 'resume session', 'continue where I left off', or loads a prior session with full context reload and plan-mode gate."
effort: low
---

# Session Pickup — Resume from Handoff

Resume work from a handoff file. Loads context, reads referenced files, presents briefing with next action.

## v5.7.0+ Native Path (preferred when session is named)

If the previous session was named via `/rename` or launched via `atlas feat/fix/hotfix <desc>`:

```bash
# CC native (v2.0.64+)
claude --resume <session-name>

# ATLAS wrapper (auto-disambiguates project vs session)
atlas resume <session-name>
```

Falls back to handoff-file-based recovery (below) if no session name matches.

## When to Use

- User says "pickup", "resume", "continue where I left off", "what was I working on"
- User runs `/pickup` or `/atlas pickup`
- Start of a new session where prior work exists

## Process

### Step 0: Topic-Aware Pickup (SP-ECO v4)

If `ATLAS_TOPIC` env var is set (injected by session-start hook from CLI topic detection):

1. **Search topic memory first**: Check `.claude/topics/${ATLAS_TOPIC}/` for:
   - `handoffs/` — topic-specific handoff archive (most recent first)
   - `decisions.md` — decisions made during this topic
   - `lessons.md` — lessons learned during this topic
   - `context.md` — key context for this topic

2. **If topic handoff found**: Auto-load it (skip the comparison table). The topic handoff is the most relevant context.

3. **Also load topic memory**: After loading the handoff, read `decisions.md` and `lessons.md` from the topic directory for extra context. This ensures prior decisions are not re-debated.

4. **If no topic handoff**: Fall through to standard handoff search (Step 1 below).

### Step 1: Find handoff files

Search ALL 4 locations, sorted by modification time (most recent first):

```bash
ls -t .claude/topics/${ATLAS_TOPIC}/handoffs/handoff-*.md 2>/dev/null  # Topic-specific (highest priority)
ls -t .blueprint/handoffs/handoff-*.md 2>/dev/null   # Primary (gold standard location)
ls -t handoff-*.md 2>/dev/null                        # Legacy (project root)
ls -t .claude/handoffs/*.json 2>/dev/null              # Structured format
```

**If multiple found** -> Read the first 30 lines of each handoff to extract summary. Present a comparison table via AskUserQuestion sorted by **date DESC** (most recent first), with age and priority indicators:

```
| # | Date       | Age | Focus                      | Delivered          | Next Step        |
|---|------------|-----|----------------------------|--------------------|------------------|
| 1 | 2026-03-21 | 2h  | NetBird SSO + Mesh         | 6/6 nodes P2P     | P2.7 DNS Fix     |
| 2 | 2026-03-21 | 5h  | IaC Phase 1 + NetBird      | PR #1 merged      | P2.4 Authentik    |
| 3 | 2026-03-20 | 1d  | Test Coverage Phase 3      | 32 tests           | FE visual tests  |
```

**Sorting rules**:
- Primary sort: date DESC (most recent first)
- If handoff has pending tasks with "CRITICAL" or "BLOCKER" -> add indicator
- Show "Age" column: `2h`, `5h`, `1d`, `3d` for quick scanning
- Handoffs older than 7 days -> show as stale (context may have drifted)

Extract from each handoff: the "Focus" line (header or first summary), "What was done" (first 2-3 bullets), and "Next Steps" (first item). Keep the table to 1 line per handoff for scannability.

**If only 1** -> auto-load, no prompt.
**If none** -> check `git log --oneline -5` + `.blueprint/plans/INDEX.md` + `.blueprint/FEATURES.md` to suggest what to work on.
**If argument provided** (e.g., `/pickup handoff-2026-03-21-netbird.md`) -> load that specific file directly.

### Step 2: Read handoff + Context Reload files

1. Read the selected handoff file completely
2. Find the "Context Reload" section -- read EACH referenced file:
   - `.blueprint/FEATURES.md` (feature registry)
   - The active plan file (from handoff)
   - `.blueprint/plans/INDEX.md`
   - Any other files listed

### Step 2.5: Restore Approved-Mode State (v6.0.0-alpha.8+)

If handoff contains an `approved_gates_persist` YAML block (from previous session's session-retrospective), restore it into `.claude/session-state.json`:

```yaml
# Example handoff section:
approved_gates_persist:
  autonomy_mode: approved
  approved_gates:
    - gate_id: plan-arch
      scope: branch-feat/atlas-v6-consolidation
      approved_at: 2026-04-23T20:53:00Z
    - gate_id: dedup-phase-2
      scope: session
  ttl_hours: 24
```

Restoration logic:
```bash
# If handoff has approved_gates_persist + TTL not expired
if grep -q "^approved_gates_persist:" "$HANDOFF_FILE"; then
  # Extract block, apply via autonomy-gate
  python3 -c "
import yaml
with open('$HANDOFF_FILE') as f: content = f.read()
# Parse approved_gates_persist block ...
# For each gate, call: ./hooks/autonomy-gate.sh approve <gate_id> <scope>
# Also: ./hooks/autonomy-gate.sh set-mode approved
"
  echo "🔐 Restored N approved_gates from handoff (v6.0 Phase 5 persistence)"
fi
```

**TTL check**: If handoff `session_start` > TTL (default 24h), DO NOT restore approved_gates — default back to `strict` mode. Safe fallback.

**User override**: Add `--no-approved-restore` flag to skip restoration even if handoff has it.
3. Check git state:
   ```bash
   git branch --show-current
   git log --oneline -5
   git status --short
   git worktree list
   ```

### Step 3: Present rich briefing

```
ATLAS | PICKUP -- Resuming session {date}

Focus: {handoff summary}
Branch: {branch} @ {commit}
Plan: {plan file} -- Phase {N} next

Key decisions from last session:
  - {decision 1 + why}
  - {decision 2 + why}

Don't re-try:
  - {error 1 -- already failed, here's why}

Suggested next action:
  {from handoff next_steps}
```

### Step 4: AskUserQuestion for next action

Present ONLY the next steps listed in the handoff file's "Prochaines etapes" or "Next Steps" section.
Do NOT add tasks from other features, dirty files, or the general feature board.
The handoff already curated what's relevant -- trust it.

If the handoff lists "P4 Backend API" as next -> that's the primary option.
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
   git worktree list | grep feature/{name}
   ```

3. **Present ONLY tasks from the selected plan/feature** via AskUserQuestion:

   **CRITICAL**: Do NOT mix tasks from other features/projects.
   Only show tasks that belong to the selected handoff action.
   Extract tasks from the plan file's phase section.

   **SCOPE RULE**: If user selected "P4 Backend API", do NOT show:
   - Tasks from other features
   - CI/CD tasks (different scope)
   - Dirty files from other worktrees
   Only show work from the selected plan section.

4. **On task selection -> Enter Plan Mode first (NON-NEGOTIABLE)**:
   - Read the FULL plan file (not just summary -- every section)
   - Read the FEATURES.md entry for the feature
   - Read the relevant backend/frontend files that will be modified
   - **Enter plan mode** (EnterPlanMode) to prepare implementation plan
   - In plan mode: write a focused implementation plan for THIS phase only
   - Present plan with tasks, files, dependencies -> HITL approval
   - ONLY after approval -> Create TaskList + start coding

**Rules**:
- **ALWAYS plan before code** -- even for "simple" tasks
- Never go back to the handoff/pickup menu after this point
- Stay in the selected feature/plan context for the rest of the session
- If user wants to switch -> they say "switch to X" or run `/pickup` again

## Complementary to Claude Code Session Recap (v6.0+)

CC ships an automatic Session Recap (one-line summary) on every resume. **session-pickup is complementary**, not a replacement:

- **CC Recap** = auto, "what happened last" summary
- **session-pickup** = opt-in via `/pickup`, full context reload from explicit handoff file

Use `session-pickup` after CC's Recap when you need:
- Full context reload (handoff parsing)
- Vault profile auto-load
- Multi-project state (Blueprint plans, etc.)
- Plan mode gate enforcement

See ADR-0003 for design rationale.
