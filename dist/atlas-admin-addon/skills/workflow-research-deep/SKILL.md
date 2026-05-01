---
name: workflow-research-deep
description: "Deep research (multi-query) + synthesis + decision-log. For open-ended questions needing external + internal investigation."
effort: medium
superpowers_pattern: [iron_law, red_flags]
see_also: [deep-research, workflow-audit, workflow-exploration]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: research
emoji: "🔬"
triggers: ["deep research", "investigate", "research topic", "explore area"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [engineer, architect, product_manager]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the question"
    skill: task-framing
    gate: MANDATORY
    purpose: "What are we trying to understand? Expected decision output? Constraints?"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Multi-query decomposition"
    skill: deep-research
    gate: MANDATORY
    purpose: "Parallel queries: codebase, docs, web, prior decisions. Aggregate findings."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: max

  - step: 3
    name: "Synthesis"
    skill: document-generator
    gate: MANDATORY
    purpose: "Executive summary, key findings, options, recommendation"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: high

  - step: 4
    name: "Decision log"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Record research outcome + conclusion for future reference"
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "One Google search is enough" | Multi-query = breadth + depth. Parallel subagent dispatch wins. |
| "Write it up later" | Later = lost signal. Synthesize while context fresh. |
</red-flags>

## Success output

```json
{
  "workflow": "research-deep",
  "status": "completed",
  "queries_executed": N,
  "sources_cited": M,
  "report_path": "memory/research-*.md",
  "recommendation": "..."
}
```
