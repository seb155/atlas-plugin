---
name: workflow-feature-discovery
description: "Jobs-to-be-done + personas + problem validation. This skill should be used when exploring whether a feature idea solves a real user problem before implementation."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-product-vision, workflow-feature, workflow-client-alignment]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: product
emoji: "🔬"
triggers: ["user research", "jobs to be done", "problem validation", "discovery"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [product_manager, designer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "User profile research"
    skill: user-profiler
    gate: MANDATORY
    purpose: "Who is the target user? Role, goals, pains, current workarounds"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Domain research"
    skill: deep-research
    gate: MANDATORY
    purpose: "How is this problem solved elsewhere? Competitive landscape, similar patterns"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "JTBD framing"
    skill: document-generator
    gate: MANDATORY
    purpose: "When X, I want Y, so I can Z + Importance/Satisfaction matrix"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: high

  - step: 4
    name: "Stakeholder validation"
    skill: workflow-stakeholder-sync
    gate: HARD_GATE
    purpose: "Present JTBD to stakeholders, validate problem exists, get go/no-go"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium
---

<HARD-GATE>
NO FEATURE BUILT WITHOUT VALIDATED JTBD.
"Build it because someone asked" = 60% of features shipped that users never adopt.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "User asked for X, just build X" | Users describe solutions. You need the underlying JOB. Ask 'why' 3 times. |
| "Our competitors have this feature" | Competitor features may be vestigial. Validate YOUR users have the JOB. |
| "Discovery is slow — let's just ship and learn" | Ship-and-learn costs 10x more than 90 min of JTBD interviews. |
</red-flags>

# Workflow: Feature Discovery

## When to use

- New feature idea surfaced by user/stakeholder
- Before committing resources to a major feature
- When user adoption of similar features has been low

## Success output

```json
{
  "workflow": "feature-discovery",
  "status": "completed",
  "jtbd_statement": "When X, I want Y, so I can Z",
  "target_persona": "persona_id",
  "importance_rating": "0-10",
  "current_satisfaction": "0-10",
  "gap": "importance - satisfaction (opportunity size)",
  "go_no_go": "go | no-go | pivot",
  "stakeholders_validated": ["..."],
  "duration_min": 90
}
```

## See also

- `workflow-feature` — CONSUMER (builds what discovery validates)
- `user-profiler` skill — persona research
- `workflow-client-alignment` — aligns stakeholders on discovery findings
