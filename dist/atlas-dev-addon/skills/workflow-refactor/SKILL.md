---
name: workflow-refactor
description: "Refactor with baseline review + after review + CI. This skill should be used when restructuring code without changing behavior — pattern cleanup, simplification, extraction, or responding to code-review feedback."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-feature, workflow-code-change, workflow-audit]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: programming
emoji: "♻️"
triggers: ["refactor", "clean up", "restructure", "simplify", "extract"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the refactor"
    skill: task-framing
    gate: MANDATORY
    purpose: "Scope boundaries + success criteria (behavior unchanged is the only acceptable outcome)"
    iron_law_ref: LAW-WORKFLOW-002
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Baseline tests pass"
    skill: verification
    gate: MANDATORY
    purpose: "Record pre-refactor test state. If not green, STOP and fix tests first."
    iron_law_ref: LAW-VERIFY-001
    parallelizable: false
    depends_on: [1]
    model_preference: haiku
    effort: low

  - step: 3
    name: "Baseline code review"
    skill: code-review
    gate: MANDATORY
    purpose: "Score BEFORE refactor on 8 dimensions. Target: improve score without regressions."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Execute refactor"
    skill: code-simplify
    gate: MANDATORY
    purpose: "Apply refactor in small commits. Run tests after each change — never let red linger."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: high

  - step: 5
    name: "Post-refactor code review"
    skill: code-review
    gate: HARD_GATE
    purpose: "Re-score on 8 dimensions. Must show improvement + zero regressions."
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: medium

  - step: 6
    name: "Verification"
    skill: verification
    gate: HARD_GATE
    purpose: "Tests still green + behavior unchanged (visual QA if frontend)"
    iron_law_ref: LAW-VERIFY-001
    parallelizable: false
    depends_on: [5]
    model_preference: sonnet
    effort: medium

  - step: 7
    name: "Finish branch"
    skill: finishing-branch
    gate: HARD_GATE
    purpose: "CHANGELOG 'Changed' entry + convention commit"
    iron_law_ref: LAW-WORKFLOW-003
    parallelizable: false
    depends_on: [6]
    model_preference: sonnet
    effort: low

  - step: 8
    name: "CI feedback loop"
    skill: ci-feedback-loop
    gate: HARD_GATE
    purpose: "Green CI — refactor must not break anything"
    iron_law_ref: LAW-WORKFLOW-001
    parallelizable: false
    depends_on: [7]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO REFACTOR SHIPS WITH FAILING TESTS OR BEHAVIOR CHANGE.
Refactor = same behavior, better structure. If behavior changes, it's a feature (use workflow-feature) or a bug fix (use workflow-bug-fix).
</HARD-GATE>

**Iron Laws**: LAW-WORKFLOW-001, LAW-WORKFLOW-002, LAW-WORKFLOW-003, LAW-VERIFY-001.

<red-flags>
| Thought | Reality |
|---|---|
| "I'll refactor + add this feature at the same time" | DON'T. Pure refactors are reviewable. Mixed diffs hide bugs. Ship refactor, then feature. |
| "Tests pass, so refactor is safe" | Tests pass for the CHANGED code. Missing tests = missing safety net. Add characterization tests first. |
| "This is obvious cleanup, skip code-review" | Refactors produce subtle bugs via renamed symbols, moved logic, changed imports. Review catches them. |
| "Smaller commit = less review burden" | YES — but each still reviewed. 10 small refactor commits > 1 giant refactor commit. |
| "I'll refactor then run tests at the end" | Test after EACH change. Red mid-refactor means you immediately know which change broke things. |
</red-flags>

# Workflow: Refactor

## When to use

- Pattern cleanup across files (extract component, move logic, rename)
- Responding to code-review feedback that doesn't change behavior
- Reducing complexity / duplication (code-simplify)
- Architectural cleanup as prep for a feature (refactor first, feature next)

Do NOT use for:
- Behavior changes → `workflow-feature`
- Bug fixes → `workflow-bug-fix`
- Bulk mechanical rename → `workflow-code-change` (trivial tier)

## Process (8 steps, ~90 min)

Key differences vs other workflows:
- **Step 3 baseline code-review**: record BEFORE score
- **Step 5 post-refactor code-review**: record AFTER score, demand improvement
- **Step 6 verification**: emphasis on behavior invariance (not new behavior)

## Success criteria

1. Baseline tests pass BEFORE refactor
2. Post-refactor code-review score ≥ baseline score on 8 dimensions
3. All tests still green
4. If frontend: visual QA confirms no UI changes
5. CHANGELOG entry under "Changed" (not "Added" or "Fixed")

## Success output

```json
{
  "workflow": "refactor",
  "status": "completed",
  "steps_executed": [1, 2, 3, 4, 5, 6, 7, 8],
  "scope": "brief 1-sentence refactor description",
  "code_review_delta": {
    "baseline_score": "N/8",
    "post_score": "M/8 (target M>=N)",
    "improved_dimensions": ["..."]
  },
  "evidence": [
    "Tests: X/X PASS (unchanged from baseline)",
    "Behavior: visual QA + manual check confirm no UI delta",
    "CI pipeline #N: success"
  ],
  "iron_laws_enforced": ["LAW-WORKFLOW-001", "LAW-WORKFLOW-003", "LAW-VERIFY-001"]
}
```

## See also

- `code-simplify` — the core refactor executor skill
- `code-review` — scoring skill used twice (before + after)
- `workflow-audit` — for broader codebase-wide tech debt hunting
- `workflow-feature`, `workflow-bug-fix` — when behavior IS changing
