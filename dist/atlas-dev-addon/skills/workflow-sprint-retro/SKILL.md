---
name: workflow-sprint-retro
description: "Session-retrospective + team retro. This skill should be used at sprint end to capture what-went-well / what-didn't / actions."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [workflow-retrospective, session-retrospective, workflow-sprint-plan]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: planning
emoji: "🔄"
triggers: ["retro", "retrospective", "sprint end", "what went well", "post-sprint"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [all]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Session retrospective (per-agent)"
    skill: session-retrospective
    gate: MANDATORY
    purpose: "Gotchas, surprises, good patterns from THIS agent's sessions"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Sprint aggregation"
    skill: document-generator
    gate: MANDATORY
    purpose: "Commitment vs delivered, blockers, estimates vs actuals (velocity input)"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: medium

  - step: 3
    name: "Actions"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Max 3 actions with owners + due dates. More = nothing gets done."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: low

  - step: 4
    name: "HITL confirm actions"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "User commits to action items. Anything not committed = dropped."
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Skip retro, just start next sprint" | No retro = same problems next sprint. 30 min = compounding improvement. |
| "List 10 action items" | 10 items = 0 done. 3 items with owners = 2-3 done. |
| "Blame doesn't help" | Avoid blame, but NAMES help: 'who felt the pain, who owns the fix'. |
</red-flags>

## Success output

```json
{
  "workflow": "sprint-retro",
  "status": "completed",
  "sprint_number": N,
  "committed_vs_delivered": "X/Y points",
  "velocity_observed": Z,
  "well": ["..."],
  "improve": ["..."],
  "actions": [{"owner": "X", "due": "YYYY-MM-DD", "item": "..."}]
}
```
