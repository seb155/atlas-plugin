---
name: workflow-plan-feature
description: "Feature-scope plan-builder flow. Smaller than workflow-plan-large — for single-feature <1 week work."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-plan-large, workflow-feature, plan-builder]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: planning
emoji: "📝"
triggers: ["plan feature", "plan this", "short plan", "quick plan"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [engineer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Frame"
    skill: task-framing
    gate: MANDATORY
    iron_law_ref: LAW-WORKFLOW-002
    purpose: "Confirm moderate-scope feature (if complex, use workflow-plan-large)"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Shortened plan (5-8 sections)"
    skill: plan-builder
    gate: MANDATORY
    iron_law_ref: LAW-PLAN-001
    purpose: "Context, scope, implementation steps, verification, risks. Not 15 sections — 5-8 sufficient."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "HITL approval"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "Quick user review. AskUserQuestion on anything ambiguous."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Skip plan, just code it" | Feature = >1h. Framing rule says plan. 15 min now saves rework. |
| "Full 15-section for a 1-week feature" | Overkill. Shortened plan (5-8 sections) covers moderate scope adequately. |
</red-flags>

## Success output

```json
{
  "workflow": "plan-feature",
  "status": "completed",
  "plan_path": ".blueprint/plans/feat-slug.md",
  "sections": 7,
  "hitl_approved": true,
  "estimated_hours": N
}
```
