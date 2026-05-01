---
name: workflow-handoff
description: "Retro + dream + a-handoff format + memory write. Produces complete handoff file for session resume."
effort: low
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [session-retrospective, memory-dream, a-handoff, workflow-retrospective]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: documentation
emoji: "👋"
triggers: ["handoff", "end session", "wrap up", "à suivre", "pause work"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [all]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Session retrospective"
    skill: session-retrospective
    gate: MANDATORY
    purpose: "Capture gotchas + decisions from THIS session"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Memory dream"
    skill: memory-dream
    gate: MANDATORY
    purpose: "Consolidate session insights into memory/ files"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Handoff file"
    skill: a-handoff
    gate: HARD_GATE
    purpose: "Write memory/handoff-YYYY-MM-DD-<topic>.md with session state"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Session state persistence"
    skill: document-generator
    gate: HARD_GATE
    purpose: "Update .claude/session-state.json for auto-resume (N.6)"
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
HANDOFF FILES ARE THE DIFFERENCE BETWEEN RESUMABLE VS LOST SESSIONS.
Skip handoff = next session starts from zero + 20 min re-orientation.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "I'll remember tomorrow" | Compaction + sleep + context switch = 50% forgotten. Write it. |
| "Handoff is for long breaks only" | Handoff is for ANY break. 2h off = still benefits from handoff. |
| "Just commit message is enough" | Commit = what changed. Handoff = why + what's next + blockers + state. |
</red-flags>

# Workflow: Handoff

## Handoff file structure

```markdown
---
name: Handoff — {topic}
description: {1-line summary}
type: project
---
# Handoff — {topic}
## Session Intent / Current State / Artifact Trail / Decisions / Errors & Blockers / Next Steps
```

Uses the 6 mandatory sections from `.claude/rules/compaction-protocol.md`.

## When to use

- End of work day
- Before long break (>2h)
- Before context compaction (preserve state)
- Before session switch to another project

## Success output

```json
{
  "workflow": "handoff",
  "status": "completed",
  "handoff_file": "memory/handoff-YYYY-MM-DD-topic.md",
  "session_state_updated": true,
  "active_workflow_resumable": true,
  "next_step": "..."
}
```
