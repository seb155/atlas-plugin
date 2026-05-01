---
name: workflow-adr-log
description: "Decision-log → ADR template → index update. Formal architectural decision record with context + decision + consequences."
effort: low
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [decision-log, workflow-architecture, workflow-facilitate-decision]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: documentation
emoji: "📜"
triggers: ["ADR", "decision record", "architectural decision", "document decision"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [engineer, architect]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Context gather"
    skill: context-discovery
    gate: MANDATORY
    purpose: "Load related decisions from .claude/decisions.jsonl + prior ADRs"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "ADR draft"
    skill: document-generator
    gate: MANDATORY
    purpose: "Template: Status, Context, Decision, Consequences, Alternatives considered"
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: medium

  - step: 3
    name: "Append decision log"
    skill: decision-log
    gate: HARD_GATE
    purpose: ".claude/decisions.jsonl + .blueprint/adrs/00NN-slug.md + index update"
    parallelizable: false
    depends_on: [2]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
EVERY NON-OBVIOUS DECISION GETS AN ADR.
'Non-obvious' = would surprise a new teammate reading code. Document the WHY.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "This decision is obvious" | Obvious to you. 6 months / teammate / future-you needs the rationale. |
| "We'll remember why" | No you won't. Write it down. |
| "ADR is overhead" | 10 min ADR = hours saved later when someone asks 'why did we pick X?'. |
</red-flags>

# Workflow: ADR Log

## ADR template structure

```markdown
# ADR-00NN: <Decision title>

**Status**: proposed | accepted | superseded | deprecated
**Date**: YYYY-MM-DD
**Deciders**: <names>

## Context
<The situation that led to this decision>

## Decision
<What we decided>

## Consequences
**Positive**:
- <benefit>

**Negative**:
- <tradeoff>

## Alternatives considered
- **Option A**: <description> — <why rejected>
- **Option B**: <description> — <why rejected>
```

## Success output

```json
{
  "workflow": "adr-log",
  "status": "completed",
  "adr_path": ".blueprint/adrs/00NN-slug.md",
  "decisions_jsonl_entry_added": true,
  "index_updated": true,
  "adr_number": N
}
```
