---
name: gms-onboard
description: "Onboarding Auto-Playbook Generator — auto-generate 4-week playbook for new MSE based on discipline, skills matrix, and existing KCs. Pilier 1 (RH). Triggers on: /atlas gms onboard, 'onboard new', 'new team member', 'playbook'."
effort: low
---

# GMS Onboarding Auto-Playbook Generator

> Pilier 1 (RH) — Generate a personalized 4-week onboarding playbook for new MSEs.
> Input: name + discipline. Output: structured playbook with core KCs, shadow schedule, first KC goal.

## When to Use

- `/atlas gms onboard "Name" --discipline EL` — generate playbook for specific person
- User asks about "onboarding", "new team member", "playbook for new engineer"
- User mentions "nouvel employé", "intégration", "formation initiale"

## Process

### Step 1: Gather Input

Use AskUserQuestion to collect:
1. **Name** of new MSE
2. **Discipline** (I&C, EL, ME, Process)
3. **Experience level** (Junior / Mid / Senior)
4. **Start date** (for scheduling)

### Step 2: Read Existing Data

1. **Skills Matrix**: Read MSE profiles to identify discipline champion (highest KC count)
2. **KC Inventory**: Read all KCs for the target discipline, sorted by `confidence` desc
3. **Gap Analysis**: Identify skills with bus factor = 1 in the discipline

### Step 3: Generate Playbook

```markdown
# Onboarding Playbook — {Name} ({Discipline})

> Auto-generated {date} | 4-week structured integration
> Discipline Champion: {champion_name} (shadow partner)

## Week 1: Foundation — Core Knowledge Cards

Goal: Read and understand the top 10 foundational KCs for {discipline}.

| # | KC Title | Type | Author | Priority |
|---|----------|------|--------|----------|
| 1 | {kc_title} | {type} | {author} | 🔴 Critical |
| 2 | {kc_title} | {type} | {author} | 🔴 Critical |
...
| 10| {kc_title} | {type} | {author} | 🟡 Important |

Daily routine:
- [ ] Read 2 KCs per day
- [ ] Note questions for champion
- [ ] Explore Claude Code basics (session, /help, skills)

## Week 2: Shadow — Learn from Champion

Goal: Shadow {champion_name} for 3+ working sessions.

- [ ] Attend {champion_name}'s next Claude Code session (observe workflow)
- [ ] Review {champion_name}'s recent KCs (understand quality bar)
- [ ] Practice: reproduce one KC analysis independently
- [ ] Debrief with champion: gaps identified, questions answered

Shadow focus areas (based on skills matrix gaps):
{list of skills where bus_factor = 1 in this discipline}

## Week 3: First KC — Independent Creation

Goal: Create first independent Knowledge Card.

Suggested KC topics (based on gap analysis):
1. {gap_topic_1} — no KC exists yet, high demand
2. {gap_topic_2} — only 1 KC, needs depth
3. {gap_topic_3} — cross-discipline opportunity

Requirements for first KC:
- [ ] Type: How-to (easiest for first KC)
- [ ] Minimum 3 tags
- [ ] Reviewed by champion before publishing
- [ ] Synced to Forgejo via `/atlas gms sync`

## Week 4: Cross-Discipline Exposure

Goal: Understand how {discipline} connects to other disciplines.

- [ ] Read 3 KCs from adjacent disciplines:
  - {adjacent_discipline_1}: "{kc_title}" — relates to {connection}
  - {adjacent_discipline_2}: "{kc_title}" — relates to {connection}
  - {adjacent_discipline_3}: "{kc_title}" — relates to {connection}
- [ ] Identify 1 cross-discipline insight (shared tags with your work)
- [ ] Attend 1 session from a different discipline MSE

## Checklist — Week 4 Completion

- [ ] Claude Code account active
- [ ] Profile created in gms-cowork-plugins
- [ ] 10+ KCs read (Week 1)
- [ ] 3+ shadow sessions attended (Week 2)
- [ ] 1+ KC created and published (Week 3)
- [ ] 3+ cross-discipline KCs reviewed (Week 4)
- [ ] 1 cross-discipline insight identified (Week 4)
- [ ] Champion sign-off obtained
```

### Step 4: HITL Review

Present the generated playbook to the user via output. Ask:
- "Ce playbook est-il adapté pour {name}? Ajustements?"
- AskUserQuestion with options: Approve / Adjust / Regenerate

### Step 5: Save & Share

On approval:
1. Save as `gms-cowork-plugins/playbooks/onboard-{slug}-{date}.md`
2. If Forgejo accessible: commit + push
3. Suggest: "Partager avec {champion_name} et {name}"

## Adjacent Discipline Mapping

| Discipline | Adjacent 1 | Adjacent 2 | Connection Topic |
|-----------|-----------|-----------|-----------------|
| I&C | EL | Process | Field instrumentation, control loops |
| EL | I&C | ME | Motor control, power distribution |
| ME | EL | Process | Rotating equipment, piping |
| Process | I&C | ME | Process control, equipment sizing |

## Context

- **POC scope**: 8 MSE, 4 disciplines, 3-month pilot
- **Champion**: MSE with highest KC count in the discipline
- **Experience adaptation**: Senior → skip Week 1, focus on KCs; Junior → full 4 weeks
- **Memory**: Save playbook reference in `~/.claude/projects/*/memory/gms-*.md`
