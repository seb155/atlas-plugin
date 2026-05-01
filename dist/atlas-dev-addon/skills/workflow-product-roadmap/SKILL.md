---
name: workflow-product-roadmap
description: "Strategic roadmap with OKRs + quarterly themes. This skill should be used when planning a quarter or multi-quarter product roadmap with measurable objectives."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-product-vision, workflow-sprint-plan, workflow-estimate]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: product
emoji: "🗺️"
triggers: ["roadmap", "OKR", "quarterly plan", "product roadmap"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 120
persona_tags: [product_manager]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Load vision context"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Read current vision doc, last roadmap, ongoing initiatives"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Programme management view"
    skill: programme-manager
    gate: MANDATORY
    purpose: "Aggregate WBS / sub-plans / sprints across the programme"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "OKR drafting"
    skill: document-generator
    gate: MANDATORY
    purpose: "Q-themes (3-5) × Objectives (1-2 per theme) × Key Results (3 per obj, measurable)"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: high

  - step: 4
    name: "Priority HITL"
    skill: interactive-flow
    gate: HARD_GATE
    purpose: "AskUserQuestion on priority order — user picks top 3 themes"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low

  - step: 5
    name: "Log decisions"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Themes committed + themes deferred + why"
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO ROADMAP SHIPS WITHOUT USER PRIORITY RANKING + DECISION-LOG.
Roadmaps without priorities = wishlist. Priorities without rationale = re-litigation in 3 months.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "Just write down everything we want to do" | That's a backlog, not a roadmap. Roadmap forces sequencing + tradeoffs. |
| "OKRs are buzzword compliance" | OKRs force "what outcome?" not "what output?". Measurable > activity-based. |
| "Stakeholders will rank priorities later" | Later = never. Get the ranking NOW while they're in session. |
| "This roadmap is for 6 months, don't need a review date" | Roadmaps go stale. Set explicit review date (quarterly recommended). |
</red-flags>

# Workflow: Product Roadmap

## When to use

- Quarterly roadmap kickoff (after product-vision is set)
- Mid-quarter re-prioritization (scope shift event)
- Client-commitment roadmap (contractual deliverables)

## Success output

```json
{
  "workflow": "product-roadmap",
  "status": "completed",
  "roadmap_doc": ".blueprint/ROADMAP-YYYY-QN.md",
  "themes": ["theme1", "theme2", "theme3"],
  "okrs_count": 9,
  "user_priority_ranked": true,
  "review_date": "YYYY-MM-DD",
  "duration_min": 120
}
```

## See also

- `workflow-product-vision` — PARENT (roadmap flows from vision)
- `workflow-sprint-plan` — CHILD (sprints derived from roadmap themes)
- `workflow-estimate` — used to size roadmap items
- `programme-manager` skill — aggregates programme-level view
