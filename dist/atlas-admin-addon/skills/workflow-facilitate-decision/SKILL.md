---
name: workflow-facilitate-decision
description: "Tradeoff matrix + HITL approval + ADR entry. This skill should be used when a decision needs explicit rationale (architectural, product, process) recorded for future reference."
effort: low
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [decision-log, workflow-brainstorm-collab, workflow-adr-log]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: collab
emoji: "⚖️"
triggers: ["decide", "tradeoff", "pick between", "should we", "decision needed"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [all]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Frame the decision"
    skill: task-framing
    gate: MANDATORY
    purpose: "What is being decided? Who is affected? Reversibility? Deadline?"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Tradeoff matrix"
    skill: document-generator
    gate: MANDATORY
    purpose: "Options × criteria (cost, effort, risk, reversibility, time-to-value). Scored."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: medium

  - step: 3
    name: "HITL approval"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "AskUserQuestion with matrix preview. User approves or requests changes."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: low

  - step: 4
    name: "Record decision"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Append to .claude/decisions.jsonl + optionally create ADR"
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO ARCHITECTURAL DECISION SHIPS WITHOUT RECORD.
6 months from now, someone asks 'why X?' — a decision log saves 2 hours of re-argue.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Obvious choice, don't need a matrix" | Obvious to you. Matrix takes 5 min, makes the choice defensible. |
| "Tribal knowledge is enough" | Tribal knowledge = single point of failure. Someone leaves, knowledge vanishes. |
| "I'll write the ADR tomorrow" | Won't happen. Write now while rationale is fresh. |
</red-flags>

# Workflow: Facilitate Decision

## Success output

```json
{
  "workflow": "facilitate-decision",
  "status": "completed",
  "decision": "...",
  "picked": "option N",
  "rejected_options": ["..."],
  "decision_log_entry": ".claude/decisions.jsonl#N",
  "adr_path": ".blueprint/adrs/00NN-..." (optional)
}
```
