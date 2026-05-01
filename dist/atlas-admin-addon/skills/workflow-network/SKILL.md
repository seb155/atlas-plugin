---
name: workflow-network
description: "Network change + verification. This skill should be used for VLAN, firewall, routing, VPN, DNS changes."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-infra-change, workflow-security, infrastructure-ops]
thinking_mode: adaptive
version: 6.1.0
tier: [dev, admin]
category: infrastructure
emoji: "🌐"
triggers: ["network", "VLAN", "firewall", "routing", "VPN", "DNS"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [infra_engineer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Pre-change topology snapshot"
    skill: infrastructure-ops
    gate: MANDATORY
    purpose: "Diagram current state + reachability tests from multiple vantage points"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Plan + HITL gate"
    skill: document-generator
    gate: HARD_GATE
    purpose: "Change plan + rollback plan + expected reachability delta. User confirms."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: medium

  - step: 3
    name: "Apply change"
    skill: infrastructure-ops
    gate: MANDATORY
    purpose: "UDM / pfSense / Tailscale / Cloudflare config change"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Post-change connectivity verification"
    skill: mesh-diagnostics
    gate: HARD_GATE
    purpose: "Ping/curl from multiple nodes, DNS lookup, port scan. Before declaring done."
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: medium
---

<HARD-GATE>
NO NETWORK CHANGE WITHOUT MULTI-VANTAGE VERIFICATION.
"Works from my laptop" is not proof. Test from agent, server, phone, offsite.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Small firewall rule, no plan needed" | Firewall rules deny/allow cascading to 50+ services. Plan = understand impact. |
| "Change works from my laptop, done" | Laptop is one vantage point. Test from 3+. |
| "Skip rollback plan — I can undo manually" | At 3 AM during an outage, plan = your future self. Write it now. |
</red-flags>

## Success output

```json
{
  "workflow": "network",
  "status": "completed",
  "change_type": "VLAN | firewall | routing | VPN | DNS",
  "pre_change_reachability": {...},
  "post_change_reachability": {...},
  "vantages_tested": ["laptop", "prod-server", "offsite"],
  "rollback_verified": true
}
```
