---
name: workflow-ux-wireframe
description: "Low-fi wireframes + ASCII mockups. This skill should be used when sketching UI layout BEFORE pixel-perfect design — speed + iteration over polish."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-ui-mockup, workflow-user-flow, workflow-prototype]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: uxui
emoji: "📐"
triggers: ["wireframe", "low-fi mockup", "sketch UI", "layout exploration"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 45
persona_tags: [designer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "User flow context"
    skill: context-discovery
    gate: MANDATORY
    purpose: "What user journey is this wireframe part of? Load feature-discovery output"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "ASCII mockup via AskUserQuestion preview"
    skill: frontend-design
    gate: MANDATORY
    purpose: "Generate 2-3 layout options as ASCII art — user picks via AskUserQuestion preview field"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Annotate picked option"
    skill: document-generator
    gate: HARD_GATE
    purpose: "Component inventory, states, interactions, spacing hints — ready for ui-mockup"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Skip wireframe, go straight to hi-fi" | Hi-fi locks you in. Wireframes let you iterate 3 options in 10 min vs 3h. |
| "Wireframe should be pretty" | NO. Grayscale, rectangles, labels. Pretty = distracting from structure. |
| "Show only the best option" | Show 2-3. User picks. If user only sees 1, they can't compare. |
</red-flags>

# Workflow: UX Wireframe

Use `AskUserQuestion` with `preview` field to show ASCII mockups side-by-side.

Example preview:
```
┌─────────────────────────────┐
│  [Logo]        [Search] [U] │
│─────────────────────────────│
│  Sidebar │  Main Content    │
│          │                   │
│  [Nav]   │   [Cards Grid]   │
│          │                   │
└─────────────────────────────┘
```

## Success output

```json
{
  "workflow": "ux-wireframe",
  "status": "completed",
  "options_generated": 3,
  "picked_option": 2,
  "ascii_mockup_path": "memory/wireframe-*.md",
  "ready_for_ui_mockup": true
}
```
