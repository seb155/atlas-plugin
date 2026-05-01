---
name: workflow-prototype
description: "Interactive HTML/React prototype stub. This skill should be used for testable prototypes — real HTML/React users can click through, not Figma mockups."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-ui-mockup, workflow-design-review, workflow-feature]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: uxui
emoji: "🧪"
triggers: ["prototype", "interactive demo", "clickable mock", "user test"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 120
persona_tags: [designer, engineer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Load mockup + flow"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Pull ui-mockup + user-flow outputs"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Build prototype"
    skill: frontend-design
    gate: MANDATORY
    purpose: "React/HTML stub with real interactions (mocked data OK, real UI is not)"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: high

  - step: 3
    name: "Browser smoke test"
    skill: browser-automation
    gate: HARD_GATE
    purpose: "Actually click through the flow via Playwright/Chrome MCP. Screenshots captured."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "HITL demo review"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "AskUserQuestion with screenshots. User approves for user-testing OR flags issues."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low
---

<HARD-GATE>
NO PROTOTYPE DELIVERED WITHOUT BROWSER SMOKE TEST.
A prototype that only looks good in screenshots is a mockup. Click through it.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Static HTML is a prototype" | Prototype = interactive. Static = mockup. Use workflow-ui-mockup for that. |
| "No tests on prototype, it's throwaway" | Prototypes get user-tested. Broken click = bad signal. Test the happy path. |
| "Mock data is fine, don't need real API" | Yes — mock is fine. BUT the UI code should be the one that'll ship. Don't throwaway. |
</red-flags>

# Workflow: Prototype

## Success output

```json
{
  "workflow": "prototype",
  "status": "completed",
  "prototype_url": "http://localhost:PORT or deployed-preview-url",
  "screenshots": ["path1.png", "path2.png"],
  "flow_walkthrough_video": "optional asset",
  "hitl_approved_for_testing": true
}
```
