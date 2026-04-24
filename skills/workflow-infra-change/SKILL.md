---
name: workflow-infra-change
description: "Infra change with peer review + deploy. This skill should be used for IaC changes, server config, network, VM, container orchestration."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-deploy, workflow-network, workflow-security, infrastructure-change]
thinking_mode: adaptive
version: 6.1.0
tier: [dev, admin]
category: infrastructure
emoji: "🏗️"
triggers: ["infra change", "infrastructure change", "IaC", "config change"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [devops, infra_engineer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Frame + impact assessment"
    skill: task-framing
    gate: MANDATORY
    purpose: "Blast radius, reversibility, affected services, maintenance window"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Implement change"
    skill: infrastructure-change
    gate: MANDATORY
    purpose: "IaC commit (Terraform/Ansible) or manual Proxmox/k8s operation with snapshot"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: high

  - step: 3
    name: "Peer review (HARD_GATE for shared infra)"
    skill: code-review
    gate: HARD_GATE
    purpose: "IaC diff review + security lens + rollback plan review"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Deploy"
    skill: workflow-deploy
    gate: HARD_GATE
    purpose: "Use workflow-deploy with pre/post smoke"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium

  - step: 5
    name: "Monitor post-change"
    skill: infra-health
    gate: HARD_GATE
    purpose: "Observe metrics 30 min post-deploy. Alert on regression."
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO SHARED-INFRA CHANGE WITHOUT PEER REVIEW + ROLLBACK.
Infra bugs cascade to all services. Second eye catches mis-configurations.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Small config tweak, skip review" | Small tweak to shared infra = amplified blast radius. |
| "Snapshot optional" | Always snapshot Proxmox VM / container before state-changing ops. 5 min insurance. |
| "Monitor = nice-to-have" | Deploy + no monitor = delayed detection. 30 min observation = catch regressions early. |
</red-flags>

## Success output

```json
{
  "workflow": "infra-change",
  "status": "completed",
  "change_type": "IaC | manual",
  "blast_radius": "low | medium | high",
  "peer_reviewer": "...",
  "snapshot_taken": true,
  "monitor_window_min": 30,
  "regressions_detected": 0
}
```
