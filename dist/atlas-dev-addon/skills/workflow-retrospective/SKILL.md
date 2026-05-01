---
name: workflow-retrospective
description: "Session retro + team retro + memory index. Captures gotchas and surprises for future reference."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [session-retrospective, workflow-sprint-retro, workflow-handoff]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: documentation
emoji: "🔄"
triggers: ["retrospective", "what I learned", "lessons learned", "postmortem"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [all]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Session retrospective"
    skill: session-retrospective
    gate: MANDATORY
    purpose: "What worked, what didn't, surprises, gotchas — from THIS session/period"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Memory index update"
    skill: memory-dream
    gate: MANDATORY
    purpose: "Extract durable lessons → memory/MEMORY.md index + new handoff/feedback files"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Append decisions.jsonl"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Any non-obvious choices made logged for future sessions"
    parallelizable: false
    depends_on: [2]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Nothing noteworthy this session" | Then retro takes 2 min. If there was SOMETHING surprising, write it. |
| "I'll remember the gotcha" | You won't. 2 months later a similar issue will bite. Write it. |
| "Memory already has enough" | Memory grows. Retros prune stale + add fresh. Cycle is the point. |
</red-flags>

# Workflow: Retrospective

## When to use

- End of work session (pair with workflow-handoff)
- End of sprint (pair with workflow-sprint-retro)
- After an incident (pair with workflow-incident-postmortem)
- Weekly review (Friday habit)

## Success output

```json
{
  "workflow": "retrospective",
  "status": "completed",
  "duration_covered": "session | sprint | week | incident",
  "lessons_captured": N,
  "memory_files_updated": ["..."],
  "decisions_logged": M
}
```
