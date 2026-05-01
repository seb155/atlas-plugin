---
name: workflow-exploration
description: "Context discovery + codebase map. Low-rigor exploration to understand an area before work."
effort: low
superpowers_pattern: [iron_law, red_flags]
see_also: [context-discovery, workflow-research-deep, workflow-audit]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: research
emoji: "🗺️"
triggers: ["explore", "understand codebase", "learn the code", "familiarize"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 45
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "8-phase context discovery"
    skill: context-discovery
    gate: MANDATORY
    iron_law_ref: LAW-CONTEXT-001
    purpose: "Files, docs, commits, patterns, decisions, skills, CLAUDE.md, tests"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: medium

  - step: 2
    name: "Codebase map"
    skill: document-generator
    gate: MANDATORY
    purpose: "Directory tree, key files, data flow, entry points, testing pattern"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: low
---

# Workflow: Exploration

## When to use

- First session in an unfamiliar codebase
- Onboarding to a new subsystem
- Before planning a multi-file refactor (need to understand before changing)
- When someone asks "how does X work here?"

Do NOT use for:
- Specific bug → `workflow-debug-investigation`
- Audit tech-debt → `workflow-audit`
- Research external patterns → `workflow-research-deep`

## Process (2 steps, ~45 min)

### Step 1: 8-phase context discovery (LAW-CONTEXT-001)

Invoke `context-discovery`. Walks the 8 phases:
1. Files scan (structure, sizes, age)
2. Recent commits (last 30 days) — what's been changing
3. Docs audit (CLAUDE.md, .blueprint/, README)
4. Patterns (greps for idioms, conventions)
5. Decisions log (.claude/decisions.jsonl) — prior choices
6. Skills + hooks inventory (if applicable)
7. CLAUDE.md rules — what's enforced
8. Tests — what's tested (implicit contract)

### Step 2: Codebase map

Invoke `document-generator` with exploration template:
- Directory tree (3-level, annotated)
- Key files (top 10 by criticality)
- Data flow diagram (Mermaid)
- Entry points (main, API, CLI)
- Testing pattern (where, how, coverage)
- Gotchas (non-obvious conventions, workarounds)
- Open questions (things unclear — for follow-up research)

## Red flags to watch for

| Thought | Reality |
|---|---|
| "I'll dive in and learn by doing" | You miss the 20% that's non-obvious. 45 min exploration = saves hours of confusion. |
| "Skip phase 5 decisions log" | decisions.jsonl contains the 'why' that code doesn't. Read it. |
| "Don't need to map test patterns" | Knowing how to test = knowing how to contribute. Test patterns first. |

## Success output

```json
{
  "workflow": "exploration",
  "status": "completed",
  "phases_completed": 8,
  "areas_mapped": N,
  "map_path": "memory/codemap-{slug}-YYYY-MM-DD.md",
  "open_questions_captured": M,
  "ready_for_planning": true
}
```

## See also

- `context-discovery` — core 8-phase scan skill
- `workflow-research-deep` — for external research (this workflow is internal-focus)
- `workflow-audit` — for quality/enforcement focus (this workflow is orientation-focus)
