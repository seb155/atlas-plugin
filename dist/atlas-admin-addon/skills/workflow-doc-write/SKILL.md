---
name: workflow-doc-write
description: "Template per doc type (README, API, runbook, tutorial). Ensures consistency + audience-appropriate depth."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [document-generator, workflow-adr-log, workflow-handoff]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: documentation
emoji: "📘"
triggers: ["write docs", "README", "API docs", "runbook", "tutorial"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [all]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Identify doc type + audience"
    skill: task-framing
    gate: MANDATORY
    purpose: "README (new users) ≠ API ref (integrators) ≠ runbook (oncall) ≠ tutorial (learners)"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Template selection"
    skill: document-generator
    gate: MANDATORY
    purpose: "Pick appropriate template. Load examples from existing docs for voice match."
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: low

  - step: 3
    name: "Draft"
    skill: document-generator
    gate: MANDATORY
    purpose: "Write content following template. Code samples tested. Links verified."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Self-review"
    skill: code-review
    gate: HARD_GATE
    purpose: "Run reader perspective: can a new person follow this? Skip acronyms explained."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low
---

<red-flags>
| Thought | Reality |
|---|---|
| "Docs are obvious, write from memory" | Your memory has context a reader doesn't. Write for 'new hire day 1'. |
| "Examples are optional" | Examples are 50% of doc value. Include 2-3 per concept. |
| "Update later if outdated" | Outdated docs = anti-docs (worse than none). Set review date. |
</red-flags>

# Workflow: Document Writing

## When to use

- New feature ships → needs user-facing README/CHANGELOG
- New API endpoint → needs integration doc
- Oncall runbook for a service
- Tutorial for onboarding / skill ramp

Each doc type has its own template structure — agent loads the right one.

## Doc type templates

| Type | Audience | Structure |
|------|----------|-----------|
| README | New users / contributors | What + Why + Quickstart + Install + Common tasks |
| API reference | Integrators | Endpoint + Request/Response + Examples + Errors |
| Runbook | Oncall engineers | Alert/signal + Diagnosis + Fix steps + Escalation |
| Tutorial | Learners | Goal + Prerequisites + Steps + Check + Further reading |

## Success output

```json
{
  "workflow": "doc-write",
  "status": "completed",
  "doc_type": "README | API | runbook | tutorial",
  "audience": "...",
  "doc_path": "docs/X.md",
  "self_review_passed": true
}
```
