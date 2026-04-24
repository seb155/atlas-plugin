---
name: workflow-incident-postmortem
description: "Incident postmortem + Iron Law check + enforcement protocol. Blameless analysis with structural fixes."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-incident-response, audit-enforcement-protocol, workflow-audit]
thinking_mode: adaptive
version: 6.1.0
tier: [dev, admin]
category: meta
emoji: "🔬"
triggers: ["postmortem", "after incident", "root cause analysis", "incident review"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [devops, engineer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Timeline reconstruction"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Detection → alerts → response → mitigation → resolution. Exact timestamps."
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Root cause (5 whys)"
    skill: systematic-debugging
    gate: MANDATORY
    iron_law_ref: LAW-DBG-001
    purpose: "Why did it happen? Why did detection take X? Why didn't existing rule catch it?"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Iron Law check"
    skill: document-generator
    gate: HARD_GATE
    purpose: "Is this pattern covered by an existing Iron Law? If no, candidate for new law."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Enforcement plan (audit-enforcement-protocol)"
    skill: audit-enforcement-protocol
    gate: HARD_GATE
    purpose: "Concrete structural prevention: L1-L8 layers. ≥4 layers, ≥1 of {L1, L6}."
    parallelizable: false
    depends_on: [3]
    model_preference: opus
    effort: high

  - step: 5
    name: "Postmortem document"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Blameless write-up with timeline, RCA, enforcement, follow-ups, due dates"
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: medium
---

<HARD-GATE>
POSTMORTEMS PRODUCE STRUCTURAL FIXES, NOT PROCESS BAND-AIDS.
"Train everyone to be more careful" = not a fix. Enforcement layer = fix.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Blame the human" | Humans fail predictably under pressure. Systems prevent failure. |
| "Add more training" | Training = memory-dependent. System enforcement = memoryless. |
| "One-off event, no fix needed" | 'One-off' events are precisely the ones that repeat when you look later. |
</red-flags>

# Workflow: Incident Postmortem

## 5 Whys example

"Prod went down" →
- **Why?** Deploy script pushed bad code
- **Why?** CI was skipped
- **Why?** LAW-WORKFLOW-001 was advisory not blocking
- **Why?** Blocking was deemed too strict early in rollout
- **Why?** Enforcement rigor didn't match system criticality → **fix: promote to hard_gate**

## Success output

```json
{
  "workflow": "incident-postmortem",
  "status": "completed",
  "incident_id": "INC-N",
  "root_causes": ["..."],
  "new_iron_law_proposed": true | false,
  "enforcement_score": "N/8",
  "postmortem_doc": "memory/postmortem-INC-N.md",
  "follow_ups": [{"owner": "...", "due": "YYYY-MM-DD"}]
}
```
