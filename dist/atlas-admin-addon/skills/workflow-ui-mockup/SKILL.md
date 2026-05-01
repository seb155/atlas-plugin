---
name: workflow-ui-mockup
description: "Hi-fi mockup + design system alignment. This skill should be used after wireframe approval to produce pixel-accurate mockups following the design system."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-ux-wireframe, workflow-design-review, workflow-prototype]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: uxui
emoji: "🎨"
triggers: ["hi-fi mockup", "visual design", "figma-style mockup"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [designer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Load wireframe + design system"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Pull approved wireframe + design tokens (colors, spacing, typography)"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Hi-fi mockup draft"
    skill: frontend-design
    gate: MANDATORY
    purpose: "Apply design system, component library, brand. JSX/TSX component preview if possible"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: high

  - step: 3
    name: "Design system compliance check"
    skill: code-review
    gate: HARD_GATE
    purpose: "Lint against design tokens. No custom colors. Spacing follows scale. Typography tier."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Visual QA + states"
    skill: visual-qa
    gate: HARD_GATE
    purpose: "All states covered: default, hover, active, disabled, loading, empty, error"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium
---

<red-flags>
| Thought | Reality |
|---|---|
| "Custom color for this screen only" | 80% of design system drift starts with 'just this one'. Use the token. |
| "Default state only, others later" | Users hit error/empty/loading states constantly. Design all 6 states. |
| "Skip visual QA, looks good to me" | Cross-device, cross-browser, accessibility — QA catches drift you can't see. |
</red-flags>

# Workflow: UI Mockup

## Success output

```json
{
  "workflow": "ui-mockup",
  "status": "completed",
  "mockup_path": "frontend/src/components/MockupX.tsx or figma-url",
  "design_system_compliant": true,
  "states_covered": ["default", "hover", "active", "disabled", "loading", "empty", "error"],
  "wcag_pass": "2.2 AA"
}
```
