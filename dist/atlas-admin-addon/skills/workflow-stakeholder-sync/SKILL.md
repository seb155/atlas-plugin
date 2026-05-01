---
name: workflow-stakeholder-sync
description: "Meeting prep + status narrative + 1:1 agenda. This skill should be used before internal syncs, 1:1s, or status updates to produce coherent briefings."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [workflow-client-alignment, workflow-facilitate-decision]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: collab
emoji: "📋"
triggers: ["meeting prep", "1:1", "sync", "status update", "stand-up"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [all]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Context discovery"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Recent git activity, open PRs, blockers, decisions pending"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Status narrative"
    skill: document-generator
    gate: MANDATORY
    purpose: "What shipped / in-progress / blocked / decisions needed. Tight 1-page format."
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Agenda + talking points"
    skill: document-generator
    gate: MANDATORY
    purpose: "Agenda items ordered by priority + talking points per item. Anticipated FAQ."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "I'll wing the sync" | Unprepared syncs = rambling + forgotten items. 10 min prep = focused 30 min. |
| "Skip status writeup, just verbal" | Verbal = lost. Written narrative = reusable in 3 other forums. |
| "Agenda is obvious, no need to write" | If you don't write it, someone else runs the meeting. Set the agenda, own the frame. |
</red-flags>

# Workflow: Stakeholder Sync

## Success output

```json
{
  "workflow": "stakeholder-sync",
  "status": "completed",
  "meeting_type": "1:1 | stand-up | weekly sync | ad-hoc",
  "status_doc": "memory/sync-YYYY-MM-DD-X.md",
  "agenda_items": N,
  "talking_points_prepared": true
}
```
