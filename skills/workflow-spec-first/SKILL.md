---
name: workflow-spec-first
description: "Spec → stakeholder review → implementation handoff. This skill should be used when building a feature that needs formal spec before code (API, protocol, public interface)."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-architecture, workflow-system-design, workflow-feature]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: architecture
emoji: "📜"
triggers: ["spec", "specification", "design doc", "protocol design", "API design"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [engineer, architect]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Context discovery"
    skill: context-discovery
    gate: MANDATORY
    iron_law_ref: LAW-CONTEXT-001
    purpose: "What exists? What constrains? Prior art?"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Draft spec"
    skill: document-generator
    gate: MANDATORY
    purpose: "Problem, non-goals, design, examples, error handling, migration, security"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: max

  - step: 3
    name: "Stakeholder review"
    skill: workflow-stakeholder-sync
    gate: HARD_GATE
    purpose: "Present spec, collect feedback, iterate until approved"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Decision log"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Record spec decisions + alternatives rejected"
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO CODE WITHOUT APPROVED SPEC.
APIs + protocols + public interfaces are contracts — verbal agreements don't scale.
</HARD-GATE>

## Success output

```json
{
  "workflow": "spec-first",
  "status": "completed",
  "spec_path": ".blueprint/specs/X.md",
  "stakeholders_approved": ["..."],
  "iterations": N,
  "ready_for_implementation": true
}
```
