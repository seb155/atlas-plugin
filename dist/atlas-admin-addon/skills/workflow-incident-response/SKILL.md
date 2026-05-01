---
name: workflow-incident-response
description: "Incident triage + hotfix + postmortem. This skill should be used during production incidents (P0-P1)."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-incident-postmortem, deploy-hotfix, workflow-deploy]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: infrastructure
emoji: "🚨"
triggers: ["incident", "outage", "production down", "P0", "P1 critical"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 120
persona_tags: [devops]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Declare + assess scope"
    skill: document-generator
    gate: MANDATORY
    purpose: "Who's affected, when did it start, what's the signal, communicate status"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Root cause hypothesis"
    skill: systematic-debugging
    gate: MANDATORY
    iron_law_ref: LAW-DBG-001
    purpose: "Hypothesis → test → verify. Don't guess-fix in prod."
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Hotfix or rollback"
    skill: deploy-hotfix
    gate: HARD_GATE
    purpose: "Smallest change that restores service. Rollback preferred if recent deploy is suspect."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: high

  - step: 4
    name: "Verify resolution"
    skill: verification
    gate: HARD_GATE
    iron_law_ref: LAW-VERIFY-001
    purpose: "Metrics return to baseline. User report confirms. Don't declare early."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium

  - step: 5
    name: "Communicate resolution"
    skill: document-generator
    gate: HARD_GATE
    purpose: "Status page updated. Affected users notified. Incident channel closed."
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low

  - step: 6
    name: "Schedule postmortem"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Auto-invoke workflow-incident-postmortem within 48h. Don't skip."
    parallelizable: false
    depends_on: [5]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO INCIDENT CLOSED WITHOUT POSTMORTEM SCHEDULED.
Unanalyzed incidents = repeated incidents. 48h window while memory is fresh.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Quick fix, back to normal" | Quick fix = symptom patch. Schedule postmortem to find root cause. |
| "Rollback is admission of failure" | Rollback is smart. Debugging in prod during incident = making it worse. |
| "No need to communicate — it's fixed" | Users need to know. Trust = fast honest communication. |
</red-flags>

## Success output

```json
{
  "workflow": "incident-response",
  "status": "completed",
  "incident_id": "INC-YYYY-MM-DD-N",
  "duration_min": N,
  "users_affected": M,
  "resolution": "hotfix | rollback | config",
  "postmortem_scheduled": "YYYY-MM-DD"
}
```
