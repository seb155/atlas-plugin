---
name: workflow-bug-fix
description: "Bug fix pipeline with reproducer → regression test → root cause → fix → CI verify. This skill should be used when debugging a reproducible bug, user reports 'X is broken', or fixing production incidents."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-feature, workflow-code-change, workflow-debug-investigation]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: programming
emoji: "🐛"
triggers: ["fix bug", "broken", "error", "debug", "this isn't working"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 60
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the bug"
    skill: task-framing
    gate: MANDATORY
    purpose: "Assess severity + scope + affected users"
    iron_law_ref: LAW-WORKFLOW-002
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Systematic debugging"
    skill: systematic-debugging
    gate: MANDATORY
    purpose: "Hypothesis-driven root cause (not 'try fixes until green')"
    iron_law_ref: LAW-DBG-001
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: high

  - step: 3
    name: "Write regression test"
    skill: tdd
    gate: MANDATORY
    purpose: "Failing test BEFORE fix. Reproduces the bug + prevents regression."
    iron_law_ref: LAW-TDD-001
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Code review"
    skill: code-review
    gate: HARD_GATE
    purpose: "Verify fix is root-cause + regression test is meaningful"
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: low

  - step: 5
    name: "Verification"
    skill: verification
    gate: HARD_GATE
    purpose: "Evidence: regression test GREEN + full suite GREEN + manual repro no longer triggers"
    iron_law_ref: LAW-VERIFY-001
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: low

  - step: 6
    name: "Finish branch"
    skill: finishing-branch
    gate: HARD_GATE
    purpose: "CHANGELOG bug entry + convention commit + PR linking issue"
    iron_law_ref: LAW-WORKFLOW-003
    parallelizable: false
    depends_on: [5]
    model_preference: sonnet
    effort: low

  - step: 7
    name: "CI feedback loop"
    skill: ci-feedback-loop
    gate: HARD_GATE
    purpose: "Green CI before closing issue"
    iron_law_ref: LAW-WORKFLOW-001
    parallelizable: false
    depends_on: [6]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO BUG FIX WITHOUT A FAILING REGRESSION TEST FIRST.
Even "obvious one-line fix" needs the test — otherwise the bug comes back in 3 months.
Signature: sha256:LAW-TDD-001 (inherited from Superpowers verbatim).
</HARD-GATE>

**Iron Laws**: LAW-WORKFLOW-001, LAW-WORKFLOW-002, LAW-WORKFLOW-003, LAW-DBG-001, LAW-TDD-001, LAW-VERIFY-001.

<red-flags>
| Thought | Reality |
|---|---|
| "I know what's wrong — let me just fix it" | Bugs lie. Your mental model of the code may be the bug. Prove it with a failing test. |
| "Test-first is overkill for a one-liner" | One-liners come back. A test locks in the fix permanently. 2 min now vs 2 hours recurring debug. |
| "Symptoms fixed, moving on" | Fix the ROOT CAUSE. Symptom-only fixes produce 3 more symptoms elsewhere. systematic-debugging surfaces root. |
| "Skip code-review, it's a trivial fix" | Trivial fixes produce subtle regressions. Second pair of eyes catches the 1% that's non-obvious. |
| "Push the fix now, I'll test in prod" | CI is the last line before prod. If the fix is bad, CI catches it. If CI says green, you ship confidently. |
</red-flags>

# Workflow: Bug Fix

## When to use

- Reproducible bug (can trigger it on demand)
- User report of broken behavior
- Test failure you need to fix (red → green on a specific test)
- Production incident post-mortem fix

Do NOT use for:
- "Make X faster" → `workflow-refactor` or investigate perf separately
- "Refactor X" without specific bug → `workflow-refactor`
- Unreproducible bug → `workflow-debug-investigation` first (research, then fix)

## Process (7 steps, ~60 min for moderate bugs)

Same pattern as workflow-code-change but with emphasis on:
- **Step 2 systematic-debugging** (not in code-change): hypothesis→test→verify cycle
- **Step 3 regression test** BEFORE fix (not after)
- **Step 5 verification** includes manual repro confirmation

## Success criteria

1. Regression test exists + FAILED before the fix + PASSES after
2. Full test suite GREEN (no collateral breakage)
3. Manual reproduction no longer triggers the bug
4. CI pipeline GREEN on push
5. CHANGELOG entry under "Fixed" section linking to issue

## Success output

```json
{
  "workflow": "bug-fix",
  "status": "completed",
  "steps_executed": [1, 2, 3, 4, 5, 6, 7],
  "regression_test": "path/to/test_the_bug.py::test_X",
  "root_cause": "1-sentence summary from systematic-debugging",
  "evidence": [
    "Regression test: red → green confirmed",
    "Full suite: X/X PASS",
    "Manual repro: no longer triggers",
    "CI pipeline #N: success"
  ],
  "iron_laws_enforced": ["LAW-WORKFLOW-001", "LAW-DBG-001", "LAW-TDD-001", "LAW-VERIFY-001"]
}
```

## See also

- `systematic-debugging` — the core investigation skill
- `workflow-debug-investigation` — for non-reproducible bugs (investigate first)
- `workflow-incident-postmortem` — for prod incident cycle
- `workflow-feature`, `workflow-code-change` — non-bug workflows
