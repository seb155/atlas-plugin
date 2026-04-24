---
name: workflow-user-flow
description: "End-to-end user journey map. This skill should be used when mapping multi-step user interactions across screens or states."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-feature-discovery, workflow-ux-wireframe, workflow-prototype]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: uxui
emoji: "🧭"
triggers: ["user flow", "journey map", "user path"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 45
persona_tags: [designer, product_manager]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Persona + JTBD context"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Load feature-discovery JTBD + target persona"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Flow diagram (Mermaid)"
    skill: document-generator
    gate: MANDATORY
    purpose: "Entry points → decisions → screens → exit points with annotations"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Edge cases + error paths"
    skill: brainstorming
    gate: MANDATORY
    purpose: "What if user cancels? Network fails? Validation errors? Back button?"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "HITL review"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "AskUserQuestion with Mermaid diagram preview. User confirms or flags gaps."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Happy path only, handle edges later" | Edge paths are 40% of user hits. Design them upfront. |
| "Flow is obvious, skip the diagram" | Obvious to you ≠ obvious to dev/QA/onboarding. Diagram = shared truth. |
| "One flow per feature" | Some features have 3-5 flows (create/edit/delete/share/restore). Map each. |
</red-flags>

# Workflow: User Flow

## Output example

```mermaid
graph LR
  A[Landing] --> B{Logged in?}
  B -->|Yes| C[Dashboard]
  B -->|No| D[Login]
  D --> E{Auth OK?}
  E -->|Yes| C
  E -->|No| F[Error state]
  F --> D
```

## Success output

```json
{
  "workflow": "user-flow",
  "status": "completed",
  "mermaid_diagram": "...",
  "screens_mapped": N,
  "edge_cases_covered": M,
  "hitl_approved": true
}
```
