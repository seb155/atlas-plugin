---
name: workflow-architecture
description: "Architecture decision + plan + ADR. This skill should be used when making system-level design decisions: new subsystem, major refactor, technology choice."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-system-design, workflow-spec-first, decision-log]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: architecture
emoji: "🏛️"
triggers: ["architecture", "system design", "architectural decision", "design system"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 120
persona_tags: [engineer, architect]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Context discovery (LAW-CONTEXT-001)"
    skill: context-discovery
    gate: MANDATORY
    purpose: "8-phase scan: code, docs, commits, decisions, skills, CLAUDE.md, tests"
    iron_law_ref: LAW-CONTEXT-001
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Deep research"
    skill: deep-research
    gate: MANDATORY
    purpose: "External patterns, similar systems, best practices 2026"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: max

  - step: 3
    name: "Architecture plan"
    skill: plan-builder
    gate: MANDATORY
    purpose: "15-section plan — Gate 12/15 before any implementation"
    iron_law_ref: LAW-PLAN-001
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: max

  - step: 4
    name: "ADR"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Formal ADR in .blueprint/adrs/ with context, decision, consequences"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium
---

<red-flags>
| Thought | Reality |
|---|---|
| "Jump to solution, skip research" | Research = 30 min, saves 30 hours of re-architecting later. |
| "ADR later, get code first" | Code without ADR = invisible architecture. Write ADR concurrently. |
| "Small architectural change, no plan needed" | 'Small' architectural changes cascade. 15-section plan scales with scope. |
</red-flags>

## Success output

```json
{
  "workflow": "architecture",
  "status": "completed",
  "adr_path": ".blueprint/adrs/00NN-decision-name.md",
  "plan_path": ".blueprint/plans/slug.md",
  "plan_score": "N/15",
  "context_discovery_complete": true
}
```
