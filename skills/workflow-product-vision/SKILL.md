---
name: workflow-product-vision
description: "3-12 month product vision doc for client/stakeholders. This skill should be used when building a long-term product narrative, setting Q1-Q4 roadmap direction, or preparing client-facing strategy content."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-product-roadmap, workflow-feature-discovery, workflow-pitch-narrative]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: product
emoji: "🎯"
triggers: ["product vision", "where are we going", "long-term roadmap", "vision for client"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 180
persona_tags: [product_manager, client_demo]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Deep research — current state + market"
    skill: deep-research
    gate: MANDATORY
    purpose: "Multi-query exploration: users, competitors, technology trends"
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: max

  - step: 2
    name: "Collaborative brainstorm"
    skill: workflow-brainstorm-collab
    gate: MANDATORY
    purpose: "HITL divergent: 8-10 strategic directions → converge to 2-3"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Draft vision document"
    skill: document-generator
    gate: MANDATORY
    purpose: "Problem → target users → outcomes → strategic pillars → quarterly milestones"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: high

  - step: 4
    name: "Decision log"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Record strategic choices + rationale + tradeoffs considered (auditable)"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low

  - step: 5
    name: "Stakeholder sync + approval"
    skill: workflow-stakeholder-sync
    gate: HARD_GATE
    purpose: "Present to stakeholders via AskUserQuestion. Iterate until buy-in."
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: medium
---

<HARD-GATE>
NO VISION DOC WITHOUT STAKEHOLDER APPROVAL + DECISION-LOG ENTRY.
Vision is a commitment to a direction — un-validated commitments produce mis-aligned execution.
</HARD-GATE>

**Iron Laws**: LAW-CONTEXT-001 (deep research before strategic doc).

<red-flags>
| Thought | Reality |
|---|---|
| "I know what our vision is — let me just write it" | Vision that skips research recycles stale assumptions. Market, competitors, users change. |
| "Brainstorm is just ideation — I have the answer" | Single-option thinking = weak strategy. Generate 8-10, stress-test, pick with eyes open. |
| "Stakeholder sync is a rubber stamp" | Vision without buy-in is wishful thinking. Get explicit commitment. |
| "Decision-log is bureaucracy" | In 6 months, someone asks "why did we pick X?" — log saves 2 hours of re-litigating. |
</red-flags>

# Workflow: Product Vision

## When to use

- Kickoff of new product / major initiative
- Quarterly strategy refresh (e.g., Q3 planning in Q2)
- Client-facing vision doc (G Mining Program-level direction)
- Response to major market shift or user research finding

Do NOT use for:
- Tactical sprint plan → `workflow-sprint-plan`
- Single feature → `workflow-feature-discovery`
- Individual roadmap update → `workflow-product-roadmap`

## Process (5 steps, ~3h nominal, HITL-heavy)

Key outputs:
1. Deep-research report (market + users + tech) → `memory/research-vision-YYYY.md`
2. Brainstorm output with 8-10 options, user-ranked → `memory/brainstorm-*.md`
3. Vision document (PDF/MD) → `.blueprint/vision/YYYY-QN.md`
4. Decision-log entries → `.claude/decisions.jsonl`
5. Stakeholder approval recorded in vision doc metadata

## Success output

```json
{
  "workflow": "product-vision",
  "status": "completed",
  "vision_doc": ".blueprint/vision/2026-Q2.md",
  "stakeholder_approved": true,
  "approved_by": ["seb", "gignac", "rheaume"],
  "decisions_logged": N,
  "evidence": ["research report", "brainstorm convergence", "stakeholder email trail"],
  "duration_min": 180
}
```

## See also

- `workflow-product-roadmap` — derives quarterly milestones from this vision
- `workflow-feature-discovery` — for specific feature exploration within vision
- `workflow-pitch-narrative` — converts vision → external-facing pitch
- `workflow-client-alignment` — reuse vision doc for ongoing client syncs
