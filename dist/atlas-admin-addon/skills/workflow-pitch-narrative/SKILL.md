---
name: workflow-pitch-narrative
description: "Sales/investor pitch narrative. This skill should be used when building an elevator pitch, sales deck narrative, or investor presentation."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-product-vision, workflow-client-alignment]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: product
emoji: "📢"
triggers: ["pitch", "sales deck", "investor", "elevator pitch"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [product_manager]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Load vision + positioning"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Pull vision doc, value props, target persona, competitive positioning"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Narrative draft"
    skill: document-generator
    gate: MANDATORY
    purpose: "Problem (30s) → agitation (60s) → solution (90s) → proof (90s) → ask (30s)"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Visual assets"
    skill: visual-generator
    gate: MANDATORY
    purpose: "Slides / diagram / demo video — pair with narrative beats"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Dry run"
    skill: verification
    gate: HARD_GATE
    purpose: "Read narrative aloud with timer. 5 min max. Cut anything that drags."
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Features first, then story" | Stories sell. Features are proof-points. Start with the customer's problem. |
| "5 min of narrative, 45 min of features" | Reverse. 5 min of features, 45 min of customer story + Q&A. |
| "Skip the dry-run, I know the content" | Timing matters. A 10-min pitch in a 5-min slot = you get cut mid-ask. |
</red-flags>

# Workflow: Pitch Narrative

## Success output

```json
{
  "workflow": "pitch-narrative",
  "status": "completed",
  "narrative_duration_sec": 300,
  "slides_count": 8,
  "dry_run_timing": "4:42",
  "asset_paths": ["..."]
}
```

## See also

- `workflow-product-vision` — source of positioning
- `workflow-client-alignment` — for client-specific adaptations
- `visual-generator` skill — deck creation
