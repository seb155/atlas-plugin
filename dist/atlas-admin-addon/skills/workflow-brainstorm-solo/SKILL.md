---
name: workflow-brainstorm-solo
description: "Autonomous ideation — agent produces doc not decision. This skill should be used when you want the agent to explore options and produce a brief for later review."
effort: medium
superpowers_pattern: [iron_law, red_flags]
see_also: [workflow-brainstorm-collab, brainstorming, decision-log]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: architecture
emoji: "💭"
triggers: ["brainstorm options", "think about", "ideate", "explore approaches"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the exploration"
    skill: task-framing
    gate: MANDATORY
    purpose: "Topic + scope + expected output format"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Divergent ideation"
    skill: brainstorming
    gate: MANDATORY
    purpose: "6-8 options with 1-line pros/cons. Include contrarian + conservative + ambitious."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Brief document"
    skill: document-generator
    gate: MANDATORY
    purpose: "Markdown doc: problem, options, agent recommendation (not decision)"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium
---

<red-flags>
| Thought | Reality |
|---|---|
| "Agent picks best option" | NO — solo brainstorm produces DOC, not decision. Decision = brainstorm-collab or facilitate-decision. |
| "3 options is enough" | Too narrow. 6-8 forces wider thinking + contrarian inclusion. |
</red-flags>

## When to use solo vs collab

- **Solo**: early exploration, no rush, want a doc to read later, async work
- **Collab**: live decision needed, HITL picking desired, real-time iteration

## Success output

```json
{
  "workflow": "brainstorm-solo",
  "status": "completed",
  "options_generated": 8,
  "doc_path": "memory/brainstorm-*.md",
  "agent_recommendation": "option N",
  "ready_for_user_review": true
}
```
