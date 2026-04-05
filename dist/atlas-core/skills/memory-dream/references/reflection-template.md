# Reflection Template

> Reflections are periodic meta-analyses of experiential data.
> They synthesize episodes, intuitions, and growth signals into
> actionable self-awareness.

## When to Create

- Monthly (end of month) via `/atlas dream --reflection`
- At sprint boundaries (end of 3-5 day sprint)
- At project milestones (phase completion, major release)
- Never more than 2 per month (avoid reflection fatigue)

## Creation Flow (Phase 4.5)

1. Read all episodes from the current period
2. Read all intuition files (validated and unvalidated)
3. Read growth trajectory from dream-history.jsonl
4. Read recent decisions from decisions.jsonl
5. Synthesize patterns, trends, and insights
6. Present via AskUserQuestion (H24) for review
7. Write to `memory/reflection-YYYY-MM.md`

## Template

```markdown
---
name: Reflection — {Month YYYY}
description: {One-line summary of the month's key insight}
type: reflection
knowledge: experiential
period: {YYYY-MM}
episodes_reviewed: {int}
growth_signals:
  - {signal 1}
  - {signal 2}
risk_signals:
  - {risk 1}
strategies_adopted:
  - {strategy 1}
---

# Reflection — {Month YYYY}

**Period**: {start date} to {end date}
**Episodes reviewed**: {N}
**Sessions total**: {N}

## Energy Dashboard

| Metric | This Month | Last Month | Trend |
|--------|-----------|------------|-------|
| Avg energy | {1-5} | {1-5} | {arrow} |
| Peak days | {N} | {N} | |
| Low days | {N} | {N} | |
| Flow sessions | {N} ({%}) | {N} ({%}) | |
| Deep work hours | {N}h | {N}h | |

## What Went Well

{2-3 things that worked. Not features shipped — how you WORKED.
Example: "Morning infrastructure sessions were consistently high-energy.
The pattern of ending each session with a handoff file dramatically reduced
context-loading time. Delegating VM setup to Jonathan freed mental bandwidth."}

## What Was Difficult

{2-3 challenges. Not bugs — experiential challenges.
Example: "Context-switching between pitch work and deep engineering drained
energy faster than expected. Friday afternoons were consistently low-productivity
but I kept scheduling complex work there. Three sessions hit the 'frustrated'
mood mark — all were debugging network issues."}

## Patterns Emerging

{Cross-episode patterns that weren't obvious at the time.}

| Pattern | Episodes | Confidence | Action |
|---------|----------|------------|--------|
| {pattern} | {which episodes} | {high/medium/low} | {what to change} |

## Intuitions Reviewed

| Intuition | Status | Confidence | Notes |
|-----------|--------|------------|-------|
| {intuition topic} | {validated/refuted/pending} | {0.0-1.0} | |

**Accuracy rate**: {N}/{M} validated ({%}) — {better/worse/same} than last month

## Decision Confidence Review

{Look back at decisions made this month. Were confidence levels accurate?}

| Decision | Confidence Then | Outcome | Calibration |
|----------|----------------|---------|-------------|
| {decision} | {0.0-1.0} | {good/mixed/poor} | {over/under/accurate} |

## Relationship Dynamics

{How team interactions evolved.}

| Person | Interactions | Quality | Change |
|--------|-------------|---------|--------|
| {name} | {N} | {quality} | {improving/stable/declining} |

## Sustainability Check

| Signal | Status | Notes |
|--------|--------|-------|
| Energy trend | {rising/stable/declining} | |
| Work-life balance | {healthy/strained/critical} | |
| Pace sustainability | {sustainable/manageable/unsustainable} | |
| Recovery time | {adequate/insufficient} | |

## Strategies for Next Month

{What to change based on this reflection.}

1. **Keep**: {what's working, don't change}
2. **Start**: {new approach to try}
3. **Stop**: {what to eliminate or reduce}
```

## Reflection vs Other Memory Types

| Aspect | Reflection | Episode | Lesson | Dream Report |
|--------|-----------|---------|--------|-------------|
| Scope | Month / sprint | Single session | Single insight | Memory system health |
| Focus | Personal growth | Lived experience | Technical learning | Index quality |
| Audience | Future self | Future self | All sessions | System audit |
| Frequency | 1-2/month | 2-4/week | As needed | Per dream cycle |
| Contains emotions | Aggregated trends | Raw feelings | No | No |

## Integration with Dream Cycle

- Phase 4.5 generates reflections
- Phase 2.6 checks reflection coverage (1+ per month target)
- Phase 3.7 uses reflections to validate/update growth trajectory
- D15 (Growth Trajectory) scoring partially derived from reflection trends
- Reflections reference episodes by filename for traceability
