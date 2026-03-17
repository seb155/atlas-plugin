# /pickup — Resume a previous session from handoff context

Resume work from the last `/atlas handoff`. Loads the structured handoff file,
restores context, and presents a ready-to-go briefing.

## Process

### Step 1: Find the latest handoff

Look for handoff files in this priority order:
1. `.claude/handoffs/latest.json` (structured, preferred)
2. `handoff-*.md` files in project root (legacy format, sorted by date desc)
3. `.blueprint/plans/` directory (find plans with pending phases)

If no handoff found, check `git log --oneline -5` and `.blueprint/plans/INDEX.md`
to suggest what to work on.

### Step 2: Load context

From `latest.json`, read:
- `plan` → Read the plan file, identify current phase
- `branch` → Verify we're on the right branch
- `commit` → Compare with current HEAD (show what changed since)
- `summary` → Display what was accomplished
- `next_steps` → Show what to do next
- `decisions` → Key decisions still relevant

### Step 3: Verify state

```bash
git branch --show-current    # Verify branch
git log --oneline -3         # Show recent commits
git status --short           # Any pending changes?
docker compose ps 2>/dev/null # Services running?
```

### Step 4: Present briefing

```
🏛️ ATLAS │ PICKUP
─────────────────────────────────────────────────────────────────

📋 Resuming: {handoff.summary}
📅 Last session: {handoff.date}
🌿 Branch: {branch} @ {commit[:8]}

📌 Where we left off:
{handoff.next_steps}

📊 Plan: {plan_file}
  Phase {N}: {phase_description}
  Progress: {completed}/{total} features

🎯 Ready to continue. What do you want to tackle first?
─────────────────────────────────────────────────────────────────
```

Then use AskUserQuestion to confirm the next action.

### Step 5: Load plan if available

If `plan` path exists, read it and create TaskList for the current phase.

**Usage**: `/pickup` or `/atlas pickup`

ARGUMENTS: $ARGUMENTS
