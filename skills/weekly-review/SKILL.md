---
name: weekly-review
description: "Weekly reflection routine. This skill should be used when the user asks for a 'weekly review', 'week retro', 'OKR check', '/atlas weekly', or at end-of-week for life-domains + wins + blockers + next-week priorities."
effort: medium
---

# Weekly Review — Structured Reflection Cycle

5-10 minute weekly review combining life domain survey, goal tracking, wins celebration,
and next-week planning. Inspired by Daniel Pink's time management framework.

## Trigger

- `/atlas review` or `/atlas weekly`
- Auto-suggested Sunday 17:00-22:00 (via hook nudge)
- "weekly review", "weekly check-in", "how was my week"

## Workflow

### Phase 1: Life Domains Survey (1 minute)

Quick pulse check across 5 soft domains. Use AskUserQuestion with a single multi-select
style question (or 1 question per domain, max 5 rapid-fire questions):

```
🔵 WEEKLY PULSE — Semaine du {date}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**5 Domains** (1-5 scale each):

| Domain | Question | Scale |
|--------|----------|-------|
| 🧠 Mental | Clarté mentale et focus cette semaine? | 1-5 |
| 👨‍👩‍👧 Famille | Qualité du temps en famille? | 1-5 |
| ❤️ Couple | Connection et satisfaction relationnelle? | 1-5 |
| 🤝 Social | Interactions sociales et amis? | 1-5 |
| 🎮 Loisirs | Temps de détente et plaisir? | 1-5 |

Present as 1 AskUserQuestion per domain (5 questions total, sequential).
Each question has options: 1 (Faible), 2 (Sous la moyenne), 3 (Correct), 4 (Bien), 5 (Excellent).

Save scores to `memory/weekly-survey-{date}.md`.

### Phase 2: OKR Progress Check (2 minutes)

Read current quarter OKR goals from `memory/quarterly-goals.md` (or create if first time).

Display progress table:

```
📊 OKR Q{N} — Progress
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| Objective | KR | Progress | Δ Week |
|-----------|------|----------|--------|
| {obj 1}   | KR1  | ██░░░ 40% | +5%  |
|           | KR2  | ████░ 80% | +10% |
| {obj 2}   | KR1  | █░░░░ 20% | +0%  |
```

Use AskUserQuestion: "Des mises à jour sur tes objectifs cette semaine?" with options:
- Update progress → prompt for specific KR updates
- No changes
- Review/modify goals

### Phase 3: Wins & Blockers (2 minutes)

Use AskUserQuestion — 2 sequential questions:

**Question 1**: "🏆 Tes 3 victoires de la semaine?" (free text, or suggest from git/task activity)

**Question 2**: "🚧 Blockers ou frustrations?" with options:
- No blockers
- Technical blocker → describe
- Process blocker → describe
- Personal/energy blocker → describe

### Phase 4: Next Week Planning (1 minute)

Based on OKR progress + blockers + energy trends:

Use AskUserQuestion to present **top 3 priorities** for next week:

```
🎯 NEXT WEEK — Top 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| # | Priority | Aligned To | Why Now |
|---|----------|------------|---------|
| 1 | {task}   | {OKR/goal} | {reason}|
| 2 | {task}   | {OKR/goal} | {reason}|
| 3 | {task}   | {OKR/goal} | {reason}|
```

Options: Accept, Reorder, or Custom priorities.

## Output Format

```
📋 WEEKLY REVIEW COMPLETE — Semaine {N}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Life Pulse: {avg}/5 (trend: ↑↓→ vs last week)
  🧠 Mental: {score}  👨‍👩‍👧 Famille: {score}
  ❤️ Couple: {score}  🤝 Social: {score}  🎮 Loisirs: {score}

🎯 OKR: {N}% overall progress (Δ +{N}% this week)

🏆 Wins: {count} victories celebrated
🚧 Blockers: {count} identified ({resolved}/{total})

📅 Next Week:
  1. {priority 1}
  2. {priority 2}
  3. {priority 3}

🔥 Review Streak: {N} consecutive weeks
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Streak Tracking

- Increment weekly streak on review completion
- Reset if >9 days gap between reviews
- Store in `memory/review-streak.md`
- Streaks are motivational — celebrate milestones (4, 8, 12, 26, 52 weeks)

## Memory Files

| File | Purpose | Format |
|------|---------|--------|
| `memory/weekly-survey-{date}.md` | Domain scores per week | YAML frontmatter + scores |
| `memory/quarterly-goals.md` | Current OKR objectives | Markdown with KR progress |
| `memory/review-streak.md` | Streak counter + history | Append-only log |
| `memory/weekly-wins.md` | Running wins log | Weekly entries |

## Trend Detection

After 4+ weeks of data, show trends:
- Domain scores trending down → suggest focus area
- OKR stalling → suggest strategy change
- Consistent blockers → escalate pattern

## Integration Points

| System | How |
|--------|-----|
| `morning-routine` skill | Energy data feeds into weekly trends |
| Memory files | All survey data persisted for trends |
| Git activity | Suggest wins from commit history |
| Task lists | Identify completed tasks for celebration |
| Handoff files | Carry-forward items for next week |

## Rules

- ALWAYS use AskUserQuestion (never free text questions)
- Keep total review under 10 minutes
- 5 domain questions are SEQUENTIAL (1 per AskUserQuestion call)
- Wins celebration is mandatory — always ask, never skip
- If first review ever → create quarterly-goals.md from scratch (guided OKR setup)
- Trends require 4+ data points — don't show trends before week 4
