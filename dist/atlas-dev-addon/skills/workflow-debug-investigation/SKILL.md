---
name: workflow-debug-investigation
description: "Systematic debugging + root-cause doc. For non-reproducible or intermittent bugs that need investigation before fix."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-bug-fix, systematic-debugging, workflow-incident-response]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: research
emoji: "🕵️"
triggers: ["debug investigation", "why is X slow", "root cause", "intermittent bug"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Systematic debugging"
    skill: systematic-debugging
    gate: MANDATORY
    iron_law_ref: LAW-DBG-001
    purpose: "Hypothesis → test → verify. Not 'try fixes'."
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: max

  - step: 2
    name: "Root cause document"
    skill: document-generator
    gate: HARD_GATE
    purpose: "Reproducer steps, hypothesis tree, evidence, root cause, proposed fix"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Schedule fix"
    skill: decision-log
    gate: HARD_GATE
    purpose: "File issue OR schedule workflow-bug-fix with reproducer in hand"
    parallelizable: false
    depends_on: [2]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Try random fixes, see what sticks" | Guess-fix wastes hours. Hypothesis-driven = minutes. |
| "Intermittent = unreproducible" | Not always. Log more, reduce input, try different env. Patience. |
| "Fix AND investigate in one go" | Separate. Investigation until reproducer + root cause. THEN workflow-bug-fix. |
</red-flags>

## Success output

```json
{
  "workflow": "debug-investigation",
  "status": "completed",
  "reproducer_found": true,
  "root_cause_identified": true,
  "doc_path": "memory/debug-*.md",
  "follow_up_workflow": "workflow-bug-fix | workflow-incident-response"
}
```
