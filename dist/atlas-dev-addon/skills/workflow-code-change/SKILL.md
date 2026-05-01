---
name: workflow-code-change
description: "Small focused code change with verify + CI gate. This skill should be used when the user asks for a tweak, small fix, or modify-function task — addresses the 2026-04-23 incident (unverified pushes) with LAW-WORKFLOW-001 enforcement."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-feature, workflow-bug-fix, workflow-refactor]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: programming
emoji: "💻"
triggers: ["change code", "tweak", "small fix", "modify function", "adjust"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 30
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the change"
    skill: task-framing
    gate: MANDATORY
    purpose: "Confirm scope is trivial/moderate (if complex, switch to workflow-feature)"
    iron_law_ref: LAW-WORKFLOW-002
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low
    max_retries: 1
    timeout_sec: 300

  - step: 2
    name: "Make the change"
    skill: tdd
    gate: CONDITIONAL
    purpose: "If logic change: TDD. If pure rename/format: skip."
    iron_law_ref: LAW-TDD-001
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Verify"
    skill: verification
    gate: HARD_GATE
    purpose: "Run verification command, confirm evidence — no 'should work' claims"
    iron_law_ref: LAW-VERIFY-001
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: low

  - step: 4
    name: "Finish branch"
    skill: finishing-branch
    gate: HARD_GATE
    purpose: "Commit hygiene + CHANGELOG entry if user-visible"
    iron_law_ref: LAW-WORKFLOW-003
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low

  - step: 5
    name: "CI feedback loop"
    skill: ci-feedback-loop
    gate: HARD_GATE
    purpose: "Poll CI until green. NO second change until verified."
    iron_law_ref: LAW-WORKFLOW-001
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO SECOND CHANGE TO THIS BRANCH WITHOUT CI VERIFY.
Step 5 is NOT optional. Skipping = LAW-WORKFLOW-001 violation.
This workflow exists precisely because the 2026-04-23 incident proved the cost.
</HARD-GATE>

**Iron Laws enforced**: LAW-WORKFLOW-001, LAW-WORKFLOW-002, LAW-WORKFLOW-003, LAW-TDD-001, LAW-VERIFY-001.

<red-flags>
| Thought | Reality |
|---|---|
| "It's a one-line change, skip the framing" | Framing = 30 seconds. Prevents the one-line becoming a rabbit hole. |
| "Just push and check CI later" | 2026-04-23: 27 pushes deep before anyone looked. Check AFTER each push. |
| "Don't need TDD for this, I'll add a test later" | "Later" is a lie we tell ourselves. Either logic changes → test, or pure format → declare in framing. |
| "Ship it, CI will catch problems" | CI catches YOUR problems. Meanwhile teammates branching from red main catch your cascade. |
| "Skip finishing-branch, commit is fine" | CHANGELOG + commit message convention + test evidence in PR description. 90 seconds prevents 30-min review ping-pong. |
</red-flags>

# Workflow: Code Change

## When to use this workflow

Use when the change is:
- **<30 min expected effort** (per task-framing result)
- **1-2 files touched**
- **Known pattern** (no architectural change)
- **User-verifiable outcome** (e.g., "button turns blue", "endpoint returns X")

Do NOT use for:
- New features → `workflow-feature`
- Bug with non-trivial root cause → `workflow-bug-fix`
- Cross-file restructure → `workflow-refactor`
- New skill/hook/plugin primitive → `workflow-plugin-dev`

## Process

### Step 1: Frame the change (MANDATORY — LAW-WORKFLOW-002)

Invoke `task-framing` skill. Expected output: tier `trivial` or `moderate`.
If framing returns `complex`, STOP and switch to `workflow-feature`.

Acceptance: written framing doc (~100 words) saved to `memory/framing-*.md`.

### Step 2: Make the change (CONDITIONAL — LAW-TDD-001)

Decision matrix from framing:
- **Pure rename/format/typo**: skip TDD, go to step 3
- **Logic change, existing tests cover**: run tests first, modify code, re-run
- **Logic change, no coverage**: invoke `tdd` skill (Red-Green-Refactor)

Red flag: "The change is obvious, tests aren't needed" — decide based on tier,
not on feel.

### Step 3: Verify (HARD_GATE — LAW-VERIFY-001)

Invoke `verification` skill. Output: fresh evidence from the verification command
(NOT "should pass" claims). Evidence must include:
- Tests passing count + command used
- Lint/typecheck pass
- Manual check if user-visible (screenshot or curl output)

Acceptance: verification command executed THIS turn, output captured.

### Step 4: Finish branch (HARD_GATE — LAW-WORKFLOW-003)

Invoke `finishing-branch` skill. Output: commit with convention message,
CHANGELOG entry if user-visible, optional PR.

### Step 5: CI feedback loop (HARD_GATE — LAW-WORKFLOW-001)

Invoke `ci-feedback-loop` skill. Poll CI until terminal state.
- If `success`: workflow complete, declare done
- If `failure`: triage → fix → push → re-enter step 5 (max 3 iterations before HITL)

## Escape hatches

Per Section N.4 of parent plan:
- `/atlas workflow skip <step>` — log reason, proceed (NOT for step 3 or 5, which are HARD_GATE)
- `/atlas workflow abort` — drop to ad-hoc mode, decision-log entry
- `/atlas workflow customize` — edit workflow_steps inline for this invocation

HARD_GATE steps (3, 4, 5) require AskUserQuestion override with explicit reason
logged to `decision-log`.

## Example invocation

```
User: "tweak the button color in the header from blue to green"

[Step 1] Task-framing output:
  Tier: trivial
  Files: 1 (components/Header.tsx)
  Pattern: known (tailwind color class swap)
  Reversibility: easy
  Rigor: skip TDD (pure class change), verify visual, ship

[Step 2] Skipped (framing = trivial, class change only)

[Step 3] Verify:
  bun run test:smoke → 48/48 PASS
  Visual QA via browser-automation → screenshot: green header confirmed

[Step 4] Finishing-branch:
  git commit -m "style(header): green brand color"
  CHANGELOG.md: "- Header: updated brand color to green"

[Step 5] CI feedback loop:
  git push
  Monitor pipeline #N → success
  Done.
```

## Success output

Produce a workflow-step-result-v1 JSON:

```json
{
  "workflow": "code-change",
  "status": "completed",
  "steps_executed": [1, 2, 3, 4, 5],
  "steps_skipped": [],
  "evidence": [
    "memory/framing-2026-04-24-header-color.md",
    "CI pipeline #N: success"
  ],
  "iron_laws_enforced": ["LAW-WORKFLOW-001", "LAW-WORKFLOW-002", "LAW-WORKFLOW-003", "LAW-VERIFY-001"]
}
```

## See also

- `workflow-feature` — for >30m changes or multi-file features
- `workflow-bug-fix` — when the change fixes a reproducible bug
- `workflow-refactor` — for pattern-level cleanup across files
- `task-framing`, `tdd`, `verification`, `finishing-branch`, `ci-feedback-loop` — chained skills
