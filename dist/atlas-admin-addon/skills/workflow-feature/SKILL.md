---
name: workflow-feature
description: "Full feature development pipeline — task-framing → brainstorm → plan → TDD → review → verify → finish → CI. This skill should be used when building a new feature from scratch or when any implementation exceeds 1 hour of expected effort."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-code-change, workflow-bug-fix, workflow-refactor]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: programming
emoji: "🚀"
triggers: ["new feature", "add feature", "build a feature", "implement"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: [[2, 3]]
estimated_duration_min: 120
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the task"
    skill: task-framing
    gate: MANDATORY
    purpose: "Complexity assessment determines rigor level for remaining steps"
    iron_law_ref: LAW-WORKFLOW-002
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: max
    max_retries: 1
    timeout_sec: 600

  - step: 2
    name: "Brainstorm design options"
    skill: brainstorming
    gate: MANDATORY_FOR_NEW
    purpose: "Generate 2-3 design candidates before committing to implementation"
    parallelizable: true
    depends_on: [1]
    model_preference: opus
    effort: high
    max_retries: 2

  - step: 3
    name: "Research relevant patterns"
    skill: deep-research
    gate: CONDITIONAL
    purpose: "Pull external/codebase context if feature touches new domain"
    parallelizable: true
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Write the plan"
    skill: plan-builder
    gate: MANDATORY
    purpose: "15-section plan with Gate 12/15 before any code — LAW-PLAN-001 applies"
    iron_law_ref: LAW-PLAN-001
    parallelizable: false
    depends_on: [2, 3]
    model_preference: opus
    effort: max

  - step: 5
    name: "TDD cycle"
    skill: tdd
    gate: MANDATORY
    purpose: "Red-green-refactor; tests define the done criterion — LAW-TDD-001"
    iron_law_ref: LAW-TDD-001
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: high

  - step: 6
    name: "Code review"
    skill: code-review
    gate: HARD_GATE
    purpose: "Self-review + peer review before merge"
    parallelizable: false
    depends_on: [5]
    model_preference: sonnet
    effort: medium

  - step: 7
    name: "Verification"
    skill: verification
    gate: HARD_GATE
    purpose: "Evidence-based done check — LAW-VERIFY-001"
    iron_law_ref: LAW-VERIFY-001
    parallelizable: false
    depends_on: [6]
    model_preference: sonnet
    effort: medium

  - step: 8
    name: "Finish branch"
    skill: finishing-branch
    gate: HARD_GATE
    purpose: "Branch hygiene + PR prep — LAW-WORKFLOW-003"
    iron_law_ref: LAW-WORKFLOW-003
    parallelizable: false
    depends_on: [7]
    model_preference: sonnet
    effort: medium

  - step: 9
    name: "CI feedback loop"
    skill: ci-feedback-loop
    gate: HARD_GATE
    purpose: "Monitor CI until green — LAW-WORKFLOW-001"
    iron_law_ref: LAW-WORKFLOW-001
    parallelizable: false
    depends_on: [8]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO FEATURE IMPLEMENTATION STARTS WITHOUT TASK-FRAMING + PLAN APPROVAL.
Steps 1, 4, 6, 7, 8, 9 are MANDATORY or HARD_GATE — no shortcuts.
The 2026-04-23 incident happened specifically because this discipline was skipped.
</HARD-GATE>

**Iron Laws enforced**: LAW-WORKFLOW-001, LAW-WORKFLOW-002, LAW-WORKFLOW-003, LAW-PLAN-001, LAW-TDD-001, LAW-VERIFY-001.

<red-flags>
| Thought | Reality |
|---|---|
| "I know what to build, let me just code" | Unframed features spawn scope drift. 5 min framing = hours saved. |
| "Plan is overkill for this" | Plan is parametrized by complexity. Trivial feature = short plan. Zero = zero plan. |
| "Tests later, let me get something working" | TDD inverts risk. Tests define done. "Later" is where bugs hide. |
| "Code review is for big PRs only" | Small PRs hide small bugs that become production incidents. Always review. |
| "Ship it, CI will catch problems" | CI catches YOUR bugs. Meanwhile, teammates branch from a red trunk. |
| "Skip finishing-branch, my commit message is fine" | CHANGELOG + convention + test evidence = 90 seconds. Ping-pong review = 30 min. |
</red-flags>

# Workflow: Feature Development

## When to use this workflow

Use when the feature is:
- **>1 hour of expected effort** (framing will confirm)
- **Multi-file / architectural change**
- **New user-facing functionality**
- **Anything you'd consider "a feature" in a PR description**

Do NOT use for:
- Small focused changes → `workflow-code-change`
- Bug fix with reproducer → `workflow-bug-fix`
- Pure restructuring → `workflow-refactor`
- Plugin primitive (skill/hook) → `workflow-plugin-dev`

## Process (9 steps — 4h flagship, parameterized by framing tier)

### Step 1: Task-framing (MANDATORY — LAW-WORKFLOW-002)

Invoke `task-framing`. Output: complexity tier (trivial/moderate/complex) + rigor level.
If `trivial`: STOP and switch to `workflow-code-change`.
If `complex`: all 9 steps apply.
If `moderate`: steps 3 optional, step 4 shortened (~5 sections not 15).

### Steps 2 + 3: Design exploration (PARALLELIZABLE per M.3)

Can run in single Agent batch call (N.3 parallelizable_groups [[2,3]]):
- **Step 2 brainstorming** (MANDATORY_FOR_NEW): 2-3 design candidates with tradeoffs
- **Step 3 deep-research** (CONDITIONAL): only if feature touches new domain or external system

### Step 4: Plan-builder (MANDATORY — LAW-PLAN-001)

Invoke `plan-builder`. Output: 15-section plan (or shortened for moderate tier).
Score ≥12/15 gate before proceeding. HITL AskUserQuestion for final approval.

### Step 5: TDD (MANDATORY — LAW-TDD-001)

Invoke `tdd`. Red-Green-Refactor cycle. Test FIRST, watch it fail for right reason, then
implement minimal to pass, then refactor.

### Step 6: Code review (HARD_GATE)

Invoke `code-review`. Self-review + (optional) peer via Agent dispatch. 8 dimensions.

### Step 7: Verification (HARD_GATE — LAW-VERIFY-001)

Invoke `verification`. 4-gate pyramid (G0 pre-commit + G1 pre-push + G2 affected CI +
G3 smoke as applicable). Evidence captured THIS turn.

### Step 8: Finishing-branch (HARD_GATE — LAW-WORKFLOW-003)

Invoke `finishing-branch`. Commit hygiene + CHANGELOG + PR description with evidence.

### Step 9: CI feedback loop (HARD_GATE — LAW-WORKFLOW-001)

Invoke `ci-feedback-loop`. Poll pipeline until terminal. Green → feature shipped.

## Escape hatches

- `/atlas workflow skip <step>` — ONLY for steps with non-HARD_GATE status (1, 2, 3, 5). Logs reason.
- `/atlas workflow abort` — drop to ad-hoc mode, decision-log entry
- `/atlas workflow customize` — edit workflow_steps inline for this invocation

HARD_GATE overrides (steps 4, 6, 7, 8, 9) require explicit AskUserQuestion with reason.

## Cross-workflow chaining example

User: "Build a Procurement dashboard for G Mining client demo next week"

Chain detected (Product + UX/UI + Programming):
```
workflow-feature-discovery (Cat 2)
  → workflow-brainstorm-collab (Cat 4)
    → workflow-ux-wireframe (Cat 3)
      → workflow-ui-mockup (Cat 3)
        → workflow-feature (Cat 1)  ← YOU ARE HERE
          → workflow-client-alignment (Cat 2)
            → workflow-handoff (Cat 9)
```

Auto-orchestrator (Phase 7) detects cross-category chains and suggests the first.

## Success output

```json
{
  "workflow": "feature",
  "status": "completed",
  "steps_executed": [1, 2, 3, 4, 5, 6, 7, 8, 9],
  "steps_skipped": [],
  "evidence": [
    "memory/framing-*.md",
    "memory/brainstorm-*.md",
    ".blueprint/plans/{plan-name}.md",
    "Test suite: X/X PASS",
    "CI pipeline #N: success"
  ],
  "iron_laws_enforced": [
    "LAW-WORKFLOW-001", "LAW-WORKFLOW-002", "LAW-WORKFLOW-003",
    "LAW-PLAN-001", "LAW-TDD-001", "LAW-VERIFY-001"
  ],
  "total_duration_min": 120
}
```

## See also

- `workflow-code-change` — for <30m focused edits (less rigor)
- `workflow-bug-fix` — for reproducible bug with regression test focus
- `workflow-refactor` — for pattern-level cleanup
- All chained skills: task-framing, brainstorming, deep-research, plan-builder, tdd, code-review, verification, finishing-branch, ci-feedback-loop
