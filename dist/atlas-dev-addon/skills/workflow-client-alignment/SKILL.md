---
name: workflow-client-alignment
description: "Stakeholder sync, demo prep, alignment doc. This skill should be used before client demos, quarterly business reviews, or whenever you need explicit buy-in from external stakeholders."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-stakeholder-sync, workflow-product-vision, workflow-pitch-narrative]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: product
emoji: "🤝"
triggers: ["client meeting", "demo prep", "alignment", "QBR", "stakeholder meeting"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [client_demo, product_manager]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Context gather"
    skill: context-discovery
    gate: MANDATORY
    purpose: "What did we commit? What did we ship? What's the current state?"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Demo prep checklist"
    skill: document-generator
    gate: MANDATORY
    purpose: "Agenda + talking points + demo script + FAQ anticipated"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Smoke-test demo path"
    skill: verification
    gate: HARD_GATE
    purpose: "Actually run the demo flow end-to-end. Do NOT skip — live demo bugs are career-limiting."
    iron_law_ref: LAW-VERIFY-001
    parallelizable: false
    depends_on: [2]
    model_preference: haiku
    effort: low

  - step: 4
    name: "Alignment doc"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Post-meeting: decisions made, next steps, owner assignments, follow-ups"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low
---

<HARD-GATE>
NO CLIENT DEMO WITHOUT SMOKE-TEST.
Live demo red path = trust damage. Always run the exact flow 30 min before.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "I'll improvise the demo" | Client asked a question, demo froze, career moment. Script first. |
| "We tested yesterday, should be fine" | Yesterday ≠ now. Something changed. Run it fresh. |
| "No need for post-meeting doc, I'll remember" | 2 weeks later, nobody remembers who owns what. Doc = ground truth. |
</red-flags>

# Workflow: Client Alignment

## Success output

```json
{
  "workflow": "client-alignment",
  "status": "completed",
  "meeting_date": "YYYY-MM-DD",
  "attendees": ["..."],
  "demo_smoke_tested": true,
  "decisions_logged": N,
  "follow_ups": [{"owner": "X", "due": "YYYY-MM-DD", "item": "..."}],
  "alignment_doc": "memory/alignment-YYYY-MM-DD-client.md"
}
```

## See also

- `workflow-stakeholder-sync` — for internal meetings
- `workflow-product-vision` — ensures demo aligns with promised direction
- `workflow-pitch-narrative` — for sales / investor context
