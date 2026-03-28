# Intuition Template

> Intuitions capture gut feelings, emerging patterns, and tacit knowledge
> that hasn't been formalized into decisions or lessons yet.

## When to Create

- When `/atlas intuition log` is invoked
- When a user expresses uncertainty: "something feels off about...", "I have a feeling..."
- When Dream Phase 3.7 detects recurring observations across 3+ episodes
- When a decision is made with low confidence (< 0.5)

## Creation Flow

1. Capture the gut feeling in the user's own words
2. Identify supporting observations (what led to this feeling)
3. Define implications (what would it mean if true)
4. Create a concrete validation plan
5. Present via AskUserQuestion for review
6. Write to `memory/intuition-{topic-slug}.md`

## Template

```markdown
---
name: Intuition — {one-line description}
description: {the gut feeling + domain in one sentence}
type: intuition
knowledge: tacit
confidence: {0.3-0.7}
domain: {technical|team|strategic|process|product}
pattern_source:
  - {observation 1}
  - {observation 2}
confidence_trend: {rising|stable|declining}
validated: false
---

# Intuition — {Topic}

**Captured**: {YYYY-MM-DD HH:MM TZ}
**Domain**: {technical | team | strategic | process | product}

## The Feeling

{In the user's own words, what the gut feeling is.
Example: "Something feels off about our Zustand store architecture.
Every new feature adds more selectors and the stores are getting tangled.
I can't point to a specific bug, but the codebase feels increasingly fragile."}

## Supporting Observations

{What concrete things led to this feeling? Not proof — just signals.}

| # | Observation | When | Weight |
|---|------------|------|--------|
| 1 | {what you noticed} | {date/context} | {strong/moderate/weak} |
| 2 | {what you noticed} | {date/context} | {strong/moderate/weak} |

## If This Is True...

{What are the implications? What would change?
Example: "If the store architecture is fundamentally wrong, we'll hit
a wall at ~50 features. Refactoring later costs 3-5x more than fixing now.
The new developer in April will inherit this complexity."}

## Validation Plan

{How to confirm or refute this intuition. Concrete, measurable steps.}

| # | Check | Expected if TRUE | Expected if FALSE |
|---|-------|-------------------|---------------------|
| 1 | {what to check} | {what you'd see} | {what you'd see} |
| 2 | {what to check} | {what you'd see} | {what you'd see} |

## Status

- [ ] Observations still accumulating
- [ ] Validation checks completed
- [ ] Confirmed / Refuted
- [ ] Action taken (if confirmed)
```

## Lifecycle

```
CREATED (confidence 0.3-0.5)
  → observations accumulate
  → confidence_trend: rising / stable / declining
  → Dream Phase 3.7 checks for validation opportunities

VALIDATING (confidence 0.5-0.7)
  → validation plan executed
  → evidence gathered

VALIDATED (confidence 0.7-1.0, validated: true)
  → becomes a lesson, feedback rule, or architectural decision
  → linked to the resulting action

ARCHIVED (confidence declining, > 60 days)
  → Dream Phase 3.7 proposes archive
  → kept for pattern recognition but deprioritized
```

## Confidence Calibration

After validation, track accuracy over time:
- Intuitions that were validated → confidence calibration goes UP for that domain
- Intuitions that were refuted → calibration goes DOWN
- Dream Phase 4.5 (Reflection) tracks intuition accuracy rate

## Connection to Decision Log

When an intuition leads to a decision:
- Update the intuition file with `validated: true` and `validated_date`
- Add entry to `.claude/decisions.jsonl` with `intuition_ref: "intuition-{topic}.md"`
- This creates a traceable chain: gut feeling → validation → decision
