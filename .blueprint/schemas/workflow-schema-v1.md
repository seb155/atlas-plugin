# Workflow Skill Schema v1.0

> **Scope**: Normative schema for every `skills/workflow-*/SKILL.md` file in atlas-plugin v6.1.0+.
> **Status**: v1.0 — ships with atlas-plugin v6.1.0.
> **Authority**: `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md` sections D, M.3, M.4, Q.1.
> **Companion**: `skill-frontmatter-v6.md` (parent SKILL.md schema — workflow skills inherit + extend).
> **Updated**: 2026-04-24

---

## 1. Purpose

Workflow skills are **orchestrators**: they chain existing atlas-plugin skills into
enforced pipelines with HITL gates. A workflow skill does not re-implement logic —
it sequences steps, applies Iron Laws, and handles gate transitions.

This schema adds **6 new fields** on top of the base `skill-frontmatter-v6.md`:

1. `workflow_steps[]` — the ordered chain (this is the skill's core)
2. `category` — one of 11 buckets (REQUIRED for workflow-* skills, optional elsewhere)
3. `schema_version` — for migration (Q.5)
4. `parallelizable_groups[]` — explicit parallel-execution declarations (M.3)
5. `output_schema_ref` — JSON schema ref for structured output (Q.1)
6. `resumable: bool` — can this workflow be paused/resumed across sessions (N.6)

---

## 2. Formal Schema (strict YAML)

```yaml
# ----- INHERITED from skill-frontmatter-v6.md (REQUIRED) -----
name: string                           # kebab-case, MUST start with "workflow-"
description: string                    # 1 sentence, <200 chars
effort: enum[low|medium|high|xhigh|max|auto]
thinking_mode: adaptive                # v6.0 constant, workflow inherits
version: semver-string                 # "6.1.0" or later

# ----- INHERITED + REQUIRED for workflow-* (was optional in v6.0) -----
tier: list[core|dev|admin]             # Defaults ['dev'] if absent
category: enum                         # REQUIRED — see § 3
superpowers_pattern: list[iron_law|red_flags|hard_gate]  # Workflows ALWAYS have hard_gate

# ----- NEW v6.1 workflow-specific REQUIRED -----
schema_version: integer                # Start at 1. Bumped on breaking changes.
workflow_steps: list[WorkflowStep]     # See § 4 for WorkflowStep schema
output_schema_ref: string              # Ref to JSON schema; default '.blueprint/schemas/workflow-step-result-v1.json'
resumable: boolean                     # Can be paused/resumed (default: true)

# ----- NEW v6.1 workflow-specific OPTIONAL -----
parallelizable_groups: list[list[int]] # Step numbers that can run in parallel, e.g. [[2,3], [5,6,7]]
estimated_duration_min: integer        # Nominal duration (advisory, used by /atlas roadmap)
persona_tags: list[string]             # e.g. ['engineer', 'pm', 'designer'] — used by _meta.yaml filters
requires_hitl: boolean                 # True if workflow cannot run headless (default: false)

# ----- INHERITED OPTIONAL -----
emoji: single-glyph-string
triggers: list[string]                 # Natural-language triggers (intent-detect hook)
see_also: list[skill-name]
```

### WorkflowStep schema (§ 4)

```yaml
# Each entry in workflow_steps[]:
- step: integer                        # 1-indexed, unique within workflow
  name: string                         # Short human-readable, e.g. "Frame the task"
  skill: string                        # Name of existing atlas-plugin skill to invoke
  gate: enum[MANDATORY|MANDATORY_FOR_NEW|HARD_GATE|CONDITIONAL|ADVISORY]
  purpose: string                      # 1 sentence — why this step exists
  iron_law_ref: string                 # Optional: "LAW-WORKFLOW-001" if step enforces a law
  parallelizable: boolean              # If true, MAY be batched with other parallelizable steps
  depends_on: list[integer]            # Step numbers that MUST complete first
  model_preference: enum[opus|sonnet|haiku|auto]  # Per-step model routing (M.4)
  effort: enum[low|medium|high|xhigh|max|auto]    # Per-step effort (M.4)
  max_retries: integer                 # Default 2 (error recovery, Q.6)
  idempotency_key_template: string     # Optional, interpolated from session state (Q.3)
  timeout_sec: integer                 # Hard timeout (default 300)
  on_skip: string                      # e.g. "log reason to decision-log"
```

### Gate enum specifications

| Value | Meaning | Behavior |
|-------|---------|----------|
| `MANDATORY` | Always runs | Never skipped. Step completion required. |
| `MANDATORY_FOR_NEW` | Only for new features | Skipped if workflow input context indicates existing-feature modification |
| `HARD_GATE` | Blocking validation | Must pass. If fails → `AskUserQuestion` offering retry/skip/abort. Logs to decision-log. |
| `CONDITIONAL` | Runs if predicate | Declares a condition via `when:` key — skipped if false |
| `ADVISORY` | Non-blocking hint | Runs + warns, does not block progression |

---

## 3. Category enum (11 categories)

Every `workflow-*` skill MUST declare one of:

| Category | ID prefix | Skill count target (v6.1.0) |
|----------|-----------|------------------------------|
| `programming` | `workflow-code-change`, etc. | 5 |
| `product` | `workflow-product-vision`, etc. | 5 |
| `uxui` | `workflow-ux-wireframe`, etc. | 5 |
| `collab` | `workflow-brainstorm-collab`, etc. | 3 |
| `architecture` | `workflow-architecture`, etc. | 4 |
| `planning` | `workflow-plan-large`, etc. | 5 |
| `infrastructure` | `workflow-deploy`, etc. | 5 |
| `research` | `workflow-research-deep`, etc. | 4 |
| `documentation` | `workflow-doc-write`, etc. | 4 |
| `analytics` | `workflow-data-analysis`, etc. | 3 |
| `meta` | `workflow-quality-gate`, etc. | 3 |

**Total**: 46 workflows across 11 categories.

---

## 4. Complete example (`workflow-feature`)

```yaml
---
name: workflow-feature
description: "Full feature development pipeline — task-framing through CI-verified ship"
effort: high
thinking_mode: adaptive
version: 6.1.0
tier: [dev]
category: programming
superpowers_pattern: [iron_law, red_flags, hard_gate]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: [[2, 3]]
estimated_duration_min: 120
persona_tags: [engineer]
requires_hitl: false

emoji: "🚀"
triggers: ["new feature", "add X to Y", "build a feature"]
see_also: [workflow-code-change, workflow-bug-fix, workflow-refactor]

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
    purpose: "Generate 2-3 design candidates before coding"
    parallelizable: true
    depends_on: [1]
    model_preference: opus
    effort: high
    max_retries: 2

  - step: 3
    name: "Deep research relevant patterns"
    skill: deep-research
    gate: CONDITIONAL
    purpose: "Pull external context if feature involves new domain"
    parallelizable: true
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 4
    name: "Write the plan"
    skill: writing-plans
    gate: MANDATORY
    purpose: "15-section plan with Gate 12/15 before code"
    parallelizable: false
    depends_on: [2, 3]
    model_preference: opus
    effort: max

  - step: 5
    name: "TDD cycle"
    skill: tdd
    gate: MANDATORY
    purpose: "Red-green-refactor; tests define the done criterion"
    iron_law_ref: LAW-TDD-001
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: high

  - step: 6
    name: "Code review"
    skill: code-review
    gate: HARD_GATE
    purpose: "Self + peer review before merge"
    parallelizable: false
    depends_on: [5]
    model_preference: sonnet
    effort: medium

  - step: 7
    name: "Verification"
    skill: verification-before-completion
    gate: HARD_GATE
    purpose: "Evidence-based done check; no claims without proof"
    parallelizable: false
    depends_on: [6]
    model_preference: sonnet
    effort: medium

  - step: 8
    name: "Finish branch"
    skill: finishing-a-development-branch
    gate: HARD_GATE
    purpose: "Proper branch hygiene + PR prep"
    iron_law_ref: LAW-WORKFLOW-003
    parallelizable: false
    depends_on: [7]
    model_preference: sonnet
    effort: medium

  - step: 9
    name: "CI feedback loop"
    skill: ci-feedback-loop
    gate: HARD_GATE
    purpose: "Monitor CI until green before declaring done"
    iron_law_ref: LAW-WORKFLOW-001
    parallelizable: false
    depends_on: [8]
    model_preference: haiku
    effort: low
---

# Workflow: Feature Development

<HARD-GATE>
NO FEATURE IMPLEMENTATION STARTS WITHOUT task-framing + plan approval.
Signature: sha256:${LAW-WORKFLOW-002}
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "I know what to build, let me just code" | Unframed tasks spawn scope drift. 5 min of framing saves hours. |
| "Plan is overkill for this" | Plan is parametrized by complexity. Small → short plan. Zero → zero plan. |
| "Tests later, let me get something working" | TDD inverts risk: tests define done. Without tests, you don't know. |
</red-flags>

## Process

### Step 1: Task-framing (MANDATORY — LAW-WORKFLOW-002)
Invoke: `task-framing` skill. Output: complexity tier (trivial/moderate/complex).

### Step 2-3: Design exploration (parallelizable)
...
```

---

## 5. Validation rules (enforced by `scripts/workflow-validate.sh`)

| Rule | Enforcement |
|------|-------------|
| `name` starts with `workflow-` | `grep -E '^name: workflow-'` fail if not |
| `category` in the 11-enum | `yq` against registry |
| Every `iron_law_ref` resolves to real law in `iron-laws.yaml` | SHA256 verify |
| Every `skill` in workflow_steps is a registered skill | Check `skills/<name>/SKILL.md` exists |
| `depends_on` step numbers exist in workflow_steps | Cycle detection |
| `parallelizable: true` implies no hard-ordered `depends_on` to same-group peer | Graph validation |
| `schema_version` present + integer | Required field check |
| HARD-GATE block in body references iron_law_ref if declared | Cross-check body ↔ frontmatter |

---

## 6. Migration path (Q.5)

When a workflow's `schema_version` bumps from 1 → 2:

1. **Additive v2 changes** (new optional fields): no action required; v1 workflows still valid
2. **Breaking v2 changes** (removed/renamed fields): `scripts/migrate-workflow-v1-to-v2.sh` runs
3. **Running sessions**: pinned to their workflow's version at start (session-state.json records version)
4. **Next session launch**: user prompted via AskUserQuestion to migrate or keep pinned

---

## 7. See also

- `skill-frontmatter-v6.md` — parent schema for all SKILL.md files
- `philosophy-engine-schema.md` — Iron Laws, Red Flags, Hard Gates
- `session-state-v1.md` — how workflow progress is tracked across sessions
- `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md` — parent plan
- `scripts/execution-philosophy/workflow-registry.yaml` — catalog of all 46 workflows
- `scripts/workflow-validate.sh` — linter that enforces this schema
