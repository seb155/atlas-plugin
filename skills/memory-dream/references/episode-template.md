# Episode Template

> Episodes are narrative session memories with experiential context.
> They capture not just WHAT happened, but HOW it felt and WHAT you'd tell your future self.

## When to Create

- After a significant session (2h+, major decisions, breakthroughs, or frustration)
- When `/atlas episode create` is invoked
- When session-start detects pending experiential signals from previous session
- Target: 2-4 episodes per week (50%+ session coverage)

## Creation Flow

1. Read accumulated experiential signals from `~/.claude/atlas-experiential-signals.json`
2. Read session context (tasks completed, files modified, decisions made)
3. Synthesize into narrative format (NOT a task list — story-like)
4. Present via AskUserQuestion (H-gate) for review
5. Write to `memory/episode-YYYY-MM-DD.md`
6. If multiple sessions same day: `episode-YYYY-MM-DD-2.md`

## Template

```markdown
---
name: Episode — {one-line theme}
description: {2-sentence narrative summary including emotional arc}
type: episode
knowledge: experiential
energy: {1-5}
mood: {string}
confidence: {0.0-1.0}
time_quality: {deep|focused|fragmented|interrupted|recovery}
location: {string}
environment: {string}
session_id: {string}
duration_minutes: {int}
flow_state: {boolean}
key_decisions:
  - {decision 1}
  - {decision 2}
blockers_hit:
  - {blocker 1}
energy_arc: {steady|rising|declining|peak-then-crash}
---

# Episode — {Date YYYY-MM-DD HH:MM TZ}

## The Story

{2-3 paragraph narrative of what happened, written in first person.
Not a bullet list — a story. Include emotional transitions.
Example: "Started the morning diving into the VLAN audit. Energy was high after
coffee, and I quickly identified the IP conflict on VM 570. Around 2pm, focus
started fragmenting — too many Slack pings. Shifted to documentation work which
felt more sustainable for the energy level."}

## Key Moments

| Time | Moment | Energy | Significance |
|------|--------|--------|-------------|
| {HH:MM} | {what happened} | {1-5} | {why it matters} |

## Decisions Made

| # | Decision | Confidence | Reversible? | Context |
|---|----------|------------|-------------|---------|
| 1 | {what was decided} | {0.0-1.0} | {yes/no/partially} | {why this matters} |

## Energy Arc

{Describe the energy trajectory through the session.
Example: "Started at 4/5 after good sleep. Peak flow 10:00-12:00 on infrastructure
work. Post-lunch dip to 2/5. Recovered to 3/5 with context switch to lighter tasks."}

## What I'd Tell My Future Self

{1-3 sentences of advice for the next session. Not technical (that's in handoffs)
but experiential.
Example: "Infrastructure work in the morning = gold. Don't schedule calls before noon.
The VLAN debugging was more draining than expected — budget 2x time for network issues."}

## Patterns Noticed

- {Any recurring pattern you're noticing across sessions}
- {Something that worked well / didn't work}
```

## Episode vs Other Memory Types

| Aspect | Episode | Session Log | Handoff | Reflection |
|--------|---------|-------------|---------|------------|
| **Focus** | How it FELT | What was DONE | How to RESUME | What was LEARNED |
| **Tone** | Narrative, personal | Factual, terse | Technical, actionable | Analytical, growth |
| **Frequency** | Per session | Per session | Per session | Monthly |
| **Audience** | Future self | Any session | Next session | Long-term self |
| **Energy/Mood** | Required | Not captured | Not captured | Aggregated |

## Auto-Inference Rules

When creating from accumulated signals:
- `energy` = median of all energy signals in session
- `mood` = most frequent mood signal, or "mixed" if no majority
- `time_quality` = "deep" if flow_state=true, else infer from signal pattern
- `confidence` = average of decision-related confidence signals
- `energy_arc` = inferred from chronological energy signal progression
- `duration_minutes` = session end - session start (from signals.json timestamps)

## Archive Policy

Episodes older than 90 days are candidates for quarterly archive:
- Create `episode-archive-YYYY-Q{N}.md` summary
- Preserve: key decisions, energy trends, recurring patterns
- Remove: full narratives, moment-by-moment details
- Dream Phase 3 proposes archival via HITL gate
