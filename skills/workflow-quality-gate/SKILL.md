---
name: workflow-quality-gate
description: "Verification + code review + audit-ship. Single entry point for pre-ship quality check across all workflows."
effort: low
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [verification, code-review, workflow-audit-ship, ship-all]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: meta
emoji: "🎚️"
triggers: ["quality gate", "before shipping", "final check", "pre-ship"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Verification (L1-L6)"
    skill: verification
    gate: MANDATORY
    iron_law_ref: LAW-VERIFY-001
    purpose: "Tests + lint + typecheck + build — evidence captured this turn"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Code review (8 dimensions)"
    skill: code-review
    gate: MANDATORY
    purpose: "Security, performance, readability, tests, docs, naming, simplicity, AI-perf"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Quality score"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Total score / 10. Block ship if < 8. Log deferred findings."
    parallelizable: false
    depends_on: [2]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO SHIP WITHOUT QUALITY GATE ≥ 8/10.
Sub-8 ships = production bugs + reviewer time burn. 30 min gate = hours saved.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Tests pass, ship it" | Tests are 1 of 8 dimensions. Check all. |
| "Quality is subjective" | 8 dimensions + concrete criteria = objective-ish scoring. |
| "Skip on hotfix" | Exception only for P0 incident response. Document deferred items. |
</red-flags>

# Workflow: Quality Gate

## Success output

```json
{
  "workflow": "quality-gate",
  "status": "completed | blocked",
  "score": "8.5/10",
  "dimensions": {"security": 9, "perf": 8, ...},
  "ship_recommendation": "ship | fix-first"
}
```
