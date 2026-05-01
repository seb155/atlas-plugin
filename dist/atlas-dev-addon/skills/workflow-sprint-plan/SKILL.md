---
name: workflow-sprint-plan
description: "Sprint planning (2 weeks) + task slicing. This skill should be used at sprint kickoff to slice roadmap items into sprint-sized tasks."
effort: medium
superpowers_pattern: [iron_law, red_flags]
see_also: [workflow-product-roadmap, workflow-plan-feature, workflow-estimate]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: planning
emoji: "🏃"
triggers: ["sprint plan", "2-week plan", "this sprint", "sprint kickoff"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [product_manager, engineer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Roadmap context"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Current quarter roadmap themes + priorities + velocity history"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Slice into sprint-sized tasks"
    skill: document-generator
    gate: MANDATORY
    purpose: "Each task ≤ 1 week nominal. Acceptance criteria. Story points if used."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Estimate sizing"
    skill: workflow-estimate
    gate: MANDATORY
    purpose: "Calibrate with historical velocity. Apply x0.15-0.25 realistic factor."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "HITL commit"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "Team/user commits to sprint scope via AskUserQuestion"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Pack the sprint — we're ambitious" | Over-committed sprints = chronic slippage + morale rot. Calibrate. |
| "No need for acceptance criteria, we know what we want" | Day 9 someone asks 'is this done?' — AC = unambiguous answer. |
| "Story points are cargo-cult" | Use them OR don't, but estimate somehow. Gut-feel = x3 variance. |
</red-flags>

## Success output

```json
{
  "workflow": "sprint-plan",
  "status": "completed",
  "sprint_number": N,
  "dates": "YYYY-MM-DD → YYYY-MM-DD",
  "committed_tasks": M,
  "total_story_points": K,
  "stretch_tasks": L,
  "hitl_committed": true
}
```
