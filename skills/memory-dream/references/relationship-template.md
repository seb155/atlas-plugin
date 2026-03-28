# Relationship Template

> Relationship files capture deep relational context — who people are,
> how you work together, what they're good at, and how the dynamic evolves.

## When to Create

- When `/atlas relationship {person}` is invoked
- When Dream Phase 3.7 detects a person mentioned 3+ times without a relationship file
- When onboarding a new team member
- Target: 5-15 relationship files (core team + key stakeholders)

## Creation Flow

1. Check if relationship file already exists for this person
2. If exists: update `last_interaction` and add interaction history entry
3. If new: gather context from conversation, team files, existing memory
4. Present via AskUserQuestion for review
5. Write to `memory/relationship-{person-slug}.md`

## Template

```markdown
---
name: {Full Name}
description: {Role + relationship summary in one line}
type: relationship
knowledge: propositional
person: {Full Name}
role: {Professional Role}
organization: {Company / Team}
strengths:
  - {strength 1}
  - {strength 2}
growth_areas:
  - {area 1}
interaction_style: {how they prefer to communicate}
trust_level: {low|medium|high}
collaboration_quality: {excellent|good|needs-alignment|difficult}
last_interaction: {YYYY-MM-DD}
---

# {Full Name}

## Identity

| Field | Value |
|-------|-------|
| Role | {role} |
| Organization | {company / team} |
| Location | {if known} |
| Contact | {preferred channel — Slack, email, etc.} |
| Working with since | {YYYY-MM} |

## Strengths & Expertise

{2-3 sentences on what this person excels at and what you trust them with.
Example: "Jonathan brings deep mechanical engineering expertise and an instinct
for practical implementation. Strong at translating complex specs into actionable
tasks. I trust him to own infrastructure decisions independently."}

## Working Dynamic

{How you collaborate. What works, what doesn't.
Example: "Best collaboration happens in focused 1:1 sessions. Prefers concrete
examples over abstract architecture discussions. Tends to be quiet in large
meetings but has excellent ideas when given space."}

## Trust & Delegation

| Area | Trust Level | Notes |
|------|-------------|-------|
| {area 1} | {low/medium/high} | {what you'd delegate, what needs oversight} |
| {area 2} | {low/medium/high} | |

## Growth Trajectory

{How this person is developing. What they're learning. How you can support.
Example: "Growing quickly in Docker/DevOps — went from no container experience
to managing full compose stacks in 3 months. Next growth area: database
administration and backup strategies."}

## Interaction History

| Date | Context | Quality | Notes |
|------|---------|---------|-------|
| {YYYY-MM-DD} | {what you worked on} | {excellent/good/mixed} | {key takeaway} |
```

## Freshness Rules

- `last_interaction` updated whenever the person is mentioned in a session
- Dream Phase 3.7 (H22) proposes updates when person appears in recent sessions
- Stale threshold: 30 days without interaction for active team members
- Phase 2.6 flags relationships where `last_interaction` > 30d AND person is in ACTIVE WORK

## Privacy

- Relationship files are per-user (never shared cross-project)
- Trust levels and growth areas are sensitive — HITL on all writes
- Never include personal information beyond professional context
- Excluded from cross-project Phase 5 entity reconciliation
