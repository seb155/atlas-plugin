---
name: workflow-data-analysis
description: "Data exploration + hypothesis + visualization. For ad-hoc analysis that needs to be documented."
effort: medium
superpowers_pattern: [iron_law, red_flags]
see_also: [workflow-benchmark, flow-analytics, workflow-research-deep]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: analytics
emoji: "📊"
triggers: ["data analysis", "explore data", "visualize", "analytics"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [engineer, product_manager]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the question"
    skill: task-framing
    gate: MANDATORY
    purpose: "What decision depends on this analysis? What's the minimum evidence needed?"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Data exploration"
    skill: document-generator
    gate: MANDATORY
    purpose: "Source, schema, sample, integrity checks (nulls, outliers, duplicates)"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Hypothesis + test"
    skill: document-generator
    gate: MANDATORY
    purpose: "State hypothesis, run query, capture evidence (stats + viz)"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: high

  - step: 4
    name: "Findings doc"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Executive summary + methodology + data + conclusion + caveats"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Chart looks compelling, ship it" | Check the data. Sample size, outliers, selection bias. |
| "Skip methodology section" | Next person reviewing = can they reproduce? Methodology = reproducibility. |
| "One viz is enough" | Different views reveal different stories. Multi-angle. |
</red-flags>

# Workflow: Data Analysis

## Success output

```json
{
  "workflow": "data-analysis",
  "status": "completed",
  "question": "...",
  "hypothesis": "...",
  "evidence": "...",
  "conclusion": "...",
  "report_path": "memory/analysis-*.md",
  "caveats": ["..."]
}
```
