---
name: workflow-cost-tracking
description: "Cost analytics + dashboard + alerts. For AI/infra cost visibility and optimization."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [cost-analytics, workflow-benchmark, workflow-audit]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: analytics
emoji: "💰"
triggers: ["cost tracking", "spend", "budget", "AI cost", "infra cost"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 45
persona_tags: [product_manager, devops]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Cost data gather"
    skill: cost-analytics
    gate: MANDATORY
    purpose: "Pull spend data: AI (Anthropic usage), infra (Proxmox, Cloudflare), services"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Trend analysis"
    skill: document-generator
    gate: MANDATORY
    purpose: "MoM growth, top line items, anomalies, cost-per-user if applicable"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Optimization suggestions"
    skill: document-generator
    gate: MANDATORY
    purpose: "Quick wins (caching, right-sizing) + longer-term levers (model routing, tier swap)"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: medium

  - step: 4
    name: "Alert thresholds"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Set WARNING + CRITICAL thresholds. Hook to notify if exceeded."
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Cost is fine, not worth tracking" | 'Fine' drifts. Without tracking, no early warning. Set thresholds. |
| "AI cost is negligible" | Until it's not. Prompt caching + model routing can cut 60%. |
| "Alert thresholds are nice-to-have" | They're the early warning system. Not optional. |
</red-flags>

# Workflow: Cost Tracking

## Success output

```json
{
  "workflow": "cost-tracking",
  "status": "completed",
  "period": "monthly",
  "total_spend": "$N",
  "mom_delta_pct": "+X% | -X%",
  "top_line_items": [{"name": "...", "cost": "..."}],
  "optimizations": ["..."],
  "alerts_configured": {"warning": "$Y", "critical": "$Z"}
}
```
