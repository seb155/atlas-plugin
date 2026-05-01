---
name: workflow-audit-ship
description: "Enterprise audit + ship-all with verification. For final ship-to-production with compliance guarantees."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [enterprise-audit, ship-all, workflow-quality-gate, workflow-security]
thinking_mode: adaptive
version: 6.1.0
tier: [dev, admin]
category: meta
emoji: "🚢"
triggers: ["audit and ship", "enterprise check", "compliance ship", "production release"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [devops]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Enterprise audit"
    skill: enterprise-audit
    gate: MANDATORY
    purpose: "Multi-tenant safety + auth + RBAC + audit trail + backup + portability (15-layer)"
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: high

  - step: 2
    name: "Quality gate"
    skill: workflow-quality-gate
    gate: HARD_GATE
    purpose: "Score ≥ 8/10 on 8 dimensions before ship"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Ship"
    skill: ship-all
    gate: HARD_GATE
    purpose: "Tag, push, deploy, verify post-deploy smoke"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Audit trail"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Release notes + audit trail + CHANGELOG finalized"
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO ENTERPRISE SHIP WITHOUT 15-LAYER AUDIT PASS.
Skipping = legal + financial + reputational exposure.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "It's just a small release" | Enterprise = always complete check. Small releases carry risk too. |
| "Skip quality-gate this time" | Gates exist for a reason. Bypass with documented approval. |
| "We'll ship first, audit after" | Reverse order = leaks + breach exposure in the interim window. |
</red-flags>

# Workflow: Audit Ship

## Enterprise 15-layer audit checklist

1-5: Security (auth, RBAC, secrets, validation, audit log)
6-10: Data (multi-tenant, backup, encryption, retention, portability)
11-13: Operations (observability, structured logs, metrics)
14: Frontend (WCAG 2.2 AA if applicable)
15: HITL (critical actions user-gated)

## Success output

```json
{
  "workflow": "audit-ship",
  "status": "completed",
  "audit_score": "15/15",
  "quality_score": "9.2/10",
  "release_tag": "vX.Y.Z",
  "deploy_pipeline": "#N",
  "changelog_updated": true
}
```
