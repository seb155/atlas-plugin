---
name: workflow-brainstorm-collab
description: "HITL facilitated brainstorm — divergent WITH user, converge to shared decision. This skill should be used when the user says 'brainstorm with me', 'help me think about', or needs iterative idea exploration."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [brainstorming, workflow-facilitate-decision, interactive-flow]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: collab
emoji: "🤝"
triggers: ["brainstorm with me", "help me think about", "explore options together", "what about"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 45
persona_tags: [all]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Frame the question"
    skill: task-framing
    gate: MANDATORY
    purpose: "What problem are we brainstorming? Scope + constraints + success criteria"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Divergent — agent produces 8-10 options"
    skill: brainstorming
    gate: MANDATORY
    purpose: "Wide net: include weird, safe, ambitious, constrained, contrarian options"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: max

  - step: 3
    name: "User ranks via AskUserQuestion"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "Present 8-10 options with previews. User picks top 2-3. This is the HITL core."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: low

  - step: 4
    name: "Convergent — deepen top 2-3"
    skill: brainstorming
    gate: MANDATORY
    purpose: "Detail each shortlisted option: pros, cons, risks, effort. Tradeoff matrix."
    parallelizable: false
    depends_on: [3]
    model_preference: opus
    effort: high

  - step: 5
    name: "Decision"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Pick or defer. Record rationale. Non-picked options noted for future reference."
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: low
---

<HARD-GATE>
NO BRAINSTORM-COLLAB SHIPS WITHOUT USER PICKING.
This is the point of HITL — if agent picks alone, use workflow-brainstorm-solo.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Agent picks the best option, user just rubber-stamps" | Then it's not collab. Real HITL = user has real choice + can say "none of these, try again". |
| "Show 3 options, it's enough" | Shows what agent already decided. 8-10 = forcing function to include contrarian. |
| "Just 2 minutes of brainstorming, then code" | Brainstorm-collab IS a workflow. Give it 45 min. Shortcuts = groupthink. |
</red-flags>

# Workflow: Brainstorm (Collab)

## Success output

```json
{
  "workflow": "brainstorm-collab",
  "status": "completed",
  "options_generated": 10,
  "user_shortlist": [2, 5, 7],
  "final_decision": "option 5",
  "decision_log_entry": ".claude/decisions.jsonl#N"
}
```
