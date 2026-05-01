---
name: workflow-estimate
description: "Complexity sizing + story points. This skill should be used when estimating effort for tasks — with calibration factor applied."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [workflow-sprint-plan, workflow-plan-feature, task-framing]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: planning
emoji: "⏱️"
triggers: ["estimate", "sizing", "story points", "how long"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [engineer, product_manager]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Framing input"
    skill: task-framing
    gate: MANDATORY
    purpose: "Complexity tier drives estimate approach"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Nominal estimate"
    skill: document-generator
    gate: MANDATORY
    purpose: "Best-case hours/days/points if everything goes well"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: low

  - step: 3
    name: "Calibrate with velocity"
    skill: flow-analytics
    gate: MANDATORY
    purpose: "Apply historical x0.15-0.25 factor. 10h nominal → 40-66h realistic."
    parallelizable: false
    depends_on: [2]
    model_preference: haiku
    effort: low

  - step: 4
    name: "Risk buffer"
    skill: document-generator
    gate: MANDATORY
    purpose: "Add 20-30% buffer for unknowns. Document what's NOT in the estimate."
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "I can do this in 2 hours" | Historical velocity says x3-6. Say 6-12h instead. Err toward honest. |
| "Estimates are useless anyway" | Estimates + calibration factor = probabilistic range. Useful for committing. |
| "Don't include risk buffer — looks padded" | Padded estimates + hit = predictable. Tight estimates + miss = blame game. |
</red-flags>

## Seb's calibration rule

Reference: `feedback_time_estimation_always_wrong.md` — gut estimates are x3-6 too optimistic.
Apply **x0.15-0.25** factor: nominal 10h → realistic 40-66h.

## Success output

```json
{
  "workflow": "estimate",
  "status": "completed",
  "nominal_hours": 10,
  "calibrated_range_hours": "40-66",
  "risk_buffer_pct": 25,
  "final_commit_hours": "50-82",
  "out_of_scope_notes": ["..."]
}
```
