---
name: workflow-system-design
description: "C4 diagram + ADR + review. This skill should be used for system-level design: new service, major subsystem, or component interaction redesign."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-architecture, workflow-spec-first, decision-log]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: architecture
emoji: "🧩"
triggers: ["system design", "C4 diagram", "component diagram", "subsystem design"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 120
persona_tags: [architect]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Context + constraints"
    skill: context-discovery
    gate: MANDATORY
    iron_law_ref: LAW-CONTEXT-001
    purpose: "Existing architecture, non-functional requirements, integration points"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "C4 diagrams (4 levels)"
    skill: document-generator
    gate: MANDATORY
    purpose: "Context → Container → Component → Code. Mermaid or PlantUML."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: max

  - step: 3
    name: "Non-functional analysis"
    skill: document-generator
    gate: MANDATORY
    purpose: "Performance budgets, scalability ceiling, security surface, observability plan"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: high

  - step: 4
    name: "Peer review"
    skill: code-review
    gate: HARD_GATE
    purpose: "8-dim review of design, with emphasis on tradeoffs + rejected alternatives"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium

  - step: 5
    name: "ADR"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Formal ADR with design decision, consequences, reversibility"
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "C4 is overkill for this" | C4 = 4 levels. Draw Level 1+2 in 10 min. Skip 3+4 if truly simple. |
| "Performance is premature optimization" | NON-functional budgets now = known ceiling. Later = 'why is this slow?'. |
| "Skip peer review, I'm the architect" | Lead architect ≠ infallible. Review surfaces blindspots. |
</red-flags>

## Success output

```json
{
  "workflow": "system-design",
  "status": "completed",
  "c4_diagrams": ["context.mmd", "container.mmd", "component.mmd"],
  "nfr_doc": ".blueprint/nfr-X.md",
  "adr_path": ".blueprint/adrs/00NN-system-design-X.md",
  "peer_reviewer": "claude-sonnet-4-6 | seb",
  "review_score": "N/8"
}
```
