---
name: workflow-benchmark
description: "Flow-analytics baseline + comparison + report. For performance benchmarks or feature usage analysis."
effort: medium
superpowers_pattern: [iron_law, red_flags]
see_also: [flow-analytics, workflow-data-analysis, workflow-cost-tracking]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: analytics
emoji: "📈"
triggers: ["benchmark", "performance test", "compare versions", "metrics comparison"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Baseline capture"
    skill: flow-analytics
    gate: MANDATORY
    purpose: "Capture current state metrics before any change. Multiple runs for variance."
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Apply change / comparison condition"
    skill: document-generator
    gate: MANDATORY
    purpose: "Clear isolated change. 1 variable at a time. Document what changed."
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: low

  - step: 3
    name: "Post-change capture"
    skill: flow-analytics
    gate: MANDATORY
    purpose: "Same metrics as baseline. Multiple runs. Statistical significance check."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Delta report"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Baseline vs post, % delta, statistical confidence, recommendation"
    parallelizable: false
    depends_on: [3]
    model_preference: opus
    effort: medium
---

<red-flags>
| Thought | Reality |
|---|---|
| "Single run is enough" | Variance exists. Minimum 3 runs, report median + range. |
| "5% improvement is a win" | 5% may be within noise. Check statistical significance. |
| "Change multiple things at once" | No. 1 variable at a time. Multi-change = can't attribute causation. |
</red-flags>

# Workflow: Benchmark

## Success output

```json
{
  "workflow": "benchmark",
  "status": "completed",
  "metric": "latency p50 | throughput | cost | ...",
  "baseline": N,
  "post_change": M,
  "delta_pct": "+X% | -X%",
  "statistically_significant": true,
  "runs": 5,
  "report_path": "memory/bench-*.md"
}
```
