---
name: morning-routine
description: "Daily morning routine command center. This skill should be used when the user asks to 'morning routine', 'start my day', '/atlas morning', or needs brief + energy check-in + priority review + brain-dump triage."
effort: medium
---

# Morning Routine — Daily Command Center

Unified daily entry point that combines morning briefing, energy check-in, and priority setting.
Extends the `morning-brief` skill with personal wellness tracking.

## Trigger

- `/atlas morning` or `/atlas routine`
- Auto-suggested by `morning-brief` hook (6-10am local time)
- "start my day", "morning routine", "daily check-in"

## Workflow

### Phase 1: Quick Check-In (30 seconds)

Use AskUserQuestion — ONE question with 4 energy-level options:

```
☀️ MORNING CHECK-IN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Comment tu te sens ce matin?
```

Options:
- 🟢 **Excellent** — High energy, deep work ready
- 🟡 **Normal** — Standard day, balanced tasks
- 🟠 **Low** — Tired, prefer lighter work
- 🔴 **Rough** — Minimal capacity, maintenance only

Save to memory: `memory/daily-checkin-{date}.md` (1 line, append-only log).

### Phase 2: Morning Brief

Invoke the `morning-brief` skill to fetch:
- 📅 Today's agenda / calendar
- 📋 Open tasks from last session
- 🌿 Git activity (recent commits, open PRs)
- 📧 Important messages (if email integration active)

Display as a compact dashboard table.

### Phase 3: Priority Setting

Based on energy level + open tasks + agenda:

Use AskUserQuestion to present **top 3 suggested priorities** for the day:

```
🎯 PRIORITIES DU JOUR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Basé sur ton énergie ({level}) et tes tâches ouvertes:

| # | Priority | Source | Effort |
|---|----------|--------|--------|
| 1 | {task 1} | {plan/handoff} | ~Xh |
| 2 | {task 2} | {backlog} | ~Xh |
| 3 | {task 3} | {suggestion} | ~Xh |
```

Options: Accept priorities, Reorder, or Custom.

**Energy-based adjustment**:
- 🟢 Excellent → suggest deep work (architecture, complex features)
- 🟡 Normal → balanced mix (implementation + review)
- 🟠 Low → lighter tasks (docs, code review, planning)
- 🔴 Rough → maintenance only (CI fixes, small bugs, cleanup)

### Phase 4: Brain Dump (Optional)

Ask: "Des idées ou pensées à capturer avant de commencer?"

If yes → capture via `note-capture` skill, classify as:
- 💡 IDEA — feature/improvement ideas
- 📋 TASK — action items to add to backlog
- 💭 INSIGHT — learnings or observations
- 📚 RESOURCE — links, references to save

If no → proceed directly to work.

## Output Format

```
☀️ MORNING ROUTINE COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ Energy: {level}
🎯 Today's Focus:
  1. {priority 1}
  2. {priority 2}
  3. {priority 3}

📊 Streak: {N} consecutive days
💡 Captured: {N} brain dump items (if any)

Ready to work! Use /pickup to resume a session or start fresh.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Streak Tracking

- Increment daily streak when morning routine is completed
- Reset if >36h gap between routines
- Store in `memory/routine-streak.md`
- Display streak count in output

## Integration Points

| System | How |
|--------|-----|
| `morning-brief` skill | Invoked for agenda/tasks/git data |
| `note-capture` skill | Brain dump processing |
| Memory files | `daily-checkin-{date}.md`, `routine-streak.md` |
| Handoff files | Read latest for task suggestions |
| Git state | Recent activity for priority suggestions |

## Rules

- ALWAYS use AskUserQuestion for check-in and priorities (never free text questions)
- Keep total routine under 2 minutes
- Energy check-in is 1 question, not a survey
- Priorities max 3 items — focused, not overwhelming
- Brain dump is optional — respect "no" immediately
