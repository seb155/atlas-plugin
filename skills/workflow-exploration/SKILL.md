---
name: workflow-exploration
description: "Context discovery + codebase map. Low-rigor exploration to understand an area before work."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [context-discovery, workflow-research-deep, workflow-audit]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: research
emoji: "🗺️"
triggers: ["explore", "understand codebase", "learn the code", "familiarize"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 45
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "8-phase context discovery"
    skill: context-discovery
    gate: MANDATORY
    iron_law_ref: LAW-CONTEXT-001
    purpose: "Files, docs, commits, patterns, decisions, skills, CLAUDE.md, tests"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Codebase map"
    skill: document-generator
    gate: MANDATORY
    purpose: "Directory tree, key files, data flow, entry points, testing pattern"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: low
---

## Success output

```json
{
  "workflow": "exploration",
  "status": "completed",
  "areas_mapped": N,
  "map_path": "memory/codemap-*.md"
}
```
