---
name: workflow-plan-large
description: "Large plan builder flow — task-framing → plan-builder (15 sections) → plan-review → HITL approval. For multi-week / multi-phase initiatives."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-plan-feature, workflow-architecture, plan-builder]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: planning
emoji: "📋"
triggers: ["large plan", "mega plan", "multi-phase plan", "sub-plan", "initiative"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 180
persona_tags: [engineer, architect]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Frame the initiative"
    skill: task-framing
    gate: MANDATORY
    iron_law_ref: LAW-WORKFLOW-002
    purpose: "Confirm complexity = complex (if not, use workflow-plan-feature)"
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: max

  - step: 2
    name: "Build 15-section plan"
    skill: plan-builder
    gate: MANDATORY
    iron_law_ref: LAW-PLAN-001
    purpose: "Sections A-O with HITL gates, effort estimates, risk/success metrics"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: max

  - step: 3
    name: "Plan review"
    skill: plan-review
    gate: HARD_GATE
    purpose: "Score ≥12/15 before user review. Identifies weak sections for revision."
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: max

  - step: 4
    name: "HITL approval"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "User approves full plan. AskUserQuestion for any unresolved decisions."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium
---

<HARD-GATE>
NO LARGE INITIATIVE STARTS WITHOUT ≥12/15 PLAN SCORE + HITL APPROVAL.
Large = >10h or >1 week calendar. Calibrate estimates with x0.15-0.25 realistic factor.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "15 sections is overkill" | 15 sections cover known failure modes. Skip = guaranteed rework later. |
| "Plan-review is bureaucracy" | Review catches weak sections before user invests attention. Saves iteration. |
| "I've done this before, shortcut the plan" | Every codebase is different. Plan forces fresh context. |
</red-flags>

## Success output

```json
{
  "workflow": "plan-large",
  "status": "completed",
  "plan_path": ".blueprint/plans/slug.md",
  "plan_score": "13/15",
  "hitl_approved": true,
  "estimated_calendar_weeks": "7-12 (calibrated)",
  "hitl_gates_count": N
}
```
