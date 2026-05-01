---
name: workflow-design-review
description: "Design critique with WCAG 2.2 AA + Nielsen heuristics 10. This skill should be used when reviewing UI before ship — accessibility, usability, consistency."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-ui-mockup, workflow-prototype, visual-qa]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: uxui
emoji: "🔍"
triggers: ["design review", "WCAG", "a11y", "accessibility", "heuristic review"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [designer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Visual QA baseline"
    skill: visual-qa
    gate: MANDATORY
    purpose: "Screenshots across breakpoints (mobile/tablet/desktop) + dark/light"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "WCAG 2.2 AA compliance"
    skill: code-review
    gate: HARD_GATE
    purpose: "Color contrast (4.5:1 text / 3:1 UI), focus visible, keyboard nav, ARIA labels"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Nielsen heuristics 10"
    skill: code-review
    gate: MANDATORY
    purpose: "10 heuristics scored: visibility, match real world, user control, consistency, error prevention, recognition over recall, flexibility, aesthetic, help users recover, help docs"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Decision log"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Findings + severity + fix priority + accepted deferrals with reason"
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO UI SHIPS WITHOUT WCAG 2.2 AA PASS.
Failing accessibility = legal liability + excluded users. Not negotiable.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "A11y later, ship first" | 'Later' = never. Retrofit costs 10x build-in. Test now. |
| "Screen readers are edge case" | 1 in 4 users has some form of disability. Not edge. |
| "We passed WCAG last quarter" | Drift happens. Re-check each design review. |
</red-flags>

# Workflow: Design Review

## 10 Nielsen Heuristics Checklist

1. Visibility of system status
2. Match between system and real world
3. User control and freedom
4. Consistency and standards
5. Error prevention
6. Recognition rather than recall
7. Flexibility and efficiency of use
8. Aesthetic and minimalist design
9. Help users recognize, diagnose, recover from errors
10. Help and documentation

## WCAG 2.2 AA essentials

- Contrast: 4.5:1 text, 3:1 UI components
- Focus visible + order logical
- Keyboard accessible (all interactions)
- Labels for form fields + ARIA for custom widgets
- No keyboard trap
- Target size 24x24px minimum
- Consistent help + error identification

## Success output

```json
{
  "workflow": "design-review",
  "status": "completed",
  "wcag_aa_pass": true,
  "nielsen_scores": {"1": 5, "2": 4, ...},
  "findings_count": N,
  "blockers": M,
  "deferred": K,
  "ship_recommendation": "ship | fix-then-ship | redesign"
}
```
