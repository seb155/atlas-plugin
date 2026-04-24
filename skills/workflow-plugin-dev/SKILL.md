---
name: workflow-plugin-dev
description: "Atlas-plugin self-development workflow. This skill should be used when adding a new skill, hook, command, or agent to atlas-plugin itself — ATLAS develops ATLAS."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-feature, plugin-builder, skill-management, hookify]
thinking_mode: adaptive
version: 6.1.0
tier: [dev, admin]
category: programming
emoji: "🔧"
triggers: ["add skill", "new hook", "plugin feature", "atlas skill", "extend atlas"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 120
persona_tags: [engineer]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Frame the primitive"
    skill: task-framing
    gate: MANDATORY
    purpose: "Determine primitive type (skill / hook / agent / command) + tier (core/dev/admin)"
    iron_law_ref: LAW-WORKFLOW-002
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: high

  - step: 2
    name: "Plan the primitive"
    skill: plan-builder
    gate: CONDITIONAL
    purpose: "Required for skills/agents. Optional for simple hooks. Required for new commands."
    iron_law_ref: LAW-PLAN-001
    parallelizable: false
    depends_on: [1]
    model_preference: opus
    effort: max

  - step: 3
    name: "Build the primitive"
    skill: plugin-builder
    gate: MANDATORY
    purpose: "Creates skill dir + frontmatter + SKILL.md body OR hook script + registration"
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: high

  - step: 4
    name: "Register in profile"
    skill: skill-management
    gate: MANDATORY
    purpose: "Add to appropriate profile YAML (core/dev-addon/admin-addon) to avoid orphan"
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low

  - step: 5
    name: "Test the primitive"
    skill: tdd
    gate: MANDATORY
    purpose: "Bats test for hooks, Python test for scripts, invocation test for skills"
    iron_law_ref: LAW-TDD-001
    parallelizable: false
    depends_on: [4]
    model_preference: sonnet
    effort: medium

  - step: 6
    name: "Code review"
    skill: code-review
    gate: HARD_GATE
    purpose: "8-dimension review + frontmatter v6 compliance check"
    parallelizable: false
    depends_on: [5]
    model_preference: sonnet
    effort: medium

  - step: 7
    name: "Verification"
    skill: verification
    gate: HARD_GATE
    purpose: "build.sh pass + hard-gate-linter pass + bats green"
    iron_law_ref: LAW-VERIFY-001
    parallelizable: false
    depends_on: [6]
    model_preference: sonnet
    effort: medium

  - step: 8
    name: "Finish branch"
    skill: finishing-branch
    gate: HARD_GATE
    purpose: "CHANGELOG + version bump + PR with new primitive documented"
    iron_law_ref: LAW-WORKFLOW-003
    parallelizable: false
    depends_on: [7]
    model_preference: sonnet
    effort: low

  - step: 9
    name: "CI feedback loop"
    skill: ci-feedback-loop
    gate: HARD_GATE
    purpose: "CI green — atlas-plugin has 30+ tests that MUST pass before ship"
    iron_law_ref: LAW-WORKFLOW-001
    parallelizable: false
    depends_on: [8]
    model_preference: haiku
    effort: low

  - step: 10
    name: "Ship (alpha tag)"
    skill: ship-all
    gate: CONDITIONAL
    purpose: "If ready for user testing: alpha tag. Skip if part of larger feature branch."
    parallelizable: false
    depends_on: [9]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
ATLAS-PLUGIN ADDITIONS MUST PASS: frontmatter v6 schema + hard-gate-linter + profile registration + CI full suite.
Orphaned skills (not in any profile) fail CI. Hooks not registered in hooks.json fail CI.
Applies to: skills/, hooks/, agents/, commands/, scripts/atlas-modules/.
</HARD-GATE>

**Iron Laws**: LAW-WORKFLOW-001, LAW-WORKFLOW-002, LAW-WORKFLOW-003, LAW-PLAN-001, LAW-TDD-001, LAW-VERIFY-001.

<red-flags>
| Thought | Reality |
|---|---|
| "Adding a skill — no plan needed" | Skills have frontmatter contracts + Iron Law references + red-flags tables. Plan = 5 min, avoids rework. |
| "Hook is 20 lines, skip TDD" | Bats tests for hooks are 20 lines too. Worth it — hooks run at every session boundary. |
| "It works on my machine, ship it" | CI runs on python:3.13-slim. Your machine may have extras. hard-gate-linter enforces SHA256 byte-exact. |
| "Profile registration is bureaucracy" | Unregistered = orphan = doesn't ship to users. Registration = 1 line in YAML. |
| "I'll add the CHANGELOG entry later" | Users see CHANGELOG. No entry = invisible change = no adoption. 30 seconds. |
</red-flags>

# Workflow: Plugin Development

## When to use

- Adding a new skill to atlas-core / atlas-dev / atlas-admin
- Creating a new hook (SessionStart, PreToolUse, etc.)
- Adding a new agent (AGENT.md)
- Adding a new slash command
- Extending an existing atlas-module script

Do NOT use for:
- Plugin cache edits (FORBIDDEN per plugin-cache.md rule)
- Modifying user application code → `workflow-feature` / `workflow-code-change`
- Config tweaks only → `workflow-code-change`

## Process (10 steps — 2h nominal)

Same pattern as workflow-feature but with atlas-plugin-specific emphasis:
- **Step 3 plugin-builder**: Scaffolds primitive with schema-correct frontmatter
- **Step 4 profile registration** (NEW vs other workflows): prevents orphan CI failure
- **Step 7 verification** includes: build.sh, hard-gate-linter all, bats suite
- **Step 10 optional ship**: alpha tag if standalone, skip if part of larger work

## Pre-flight check before starting

```bash
# Verify you're in atlas-plugin, not a consuming project
test -f VERSION && test -d skills && test -d hooks || {
  echo "This workflow is for atlas-plugin self-dev only"; exit 1;
}

# Ensure plugin cache rule respected (never edit cache)
[ "$PWD" != *"/.claude/plugins/cache/"* ] || {
  echo "FORBIDDEN: editing plugin cache. Edit source repo."; exit 1;
}
```

## Success criteria

1. Primitive exists in source + registered in profile + in hooks.json (if hook)
2. Tests cover the primitive (bats for hooks/scripts, Python for infra)
3. build.sh passes (no schema violations, frontmatter v6 compliant)
4. hard-gate-linter.sh all passes (SHA256 byte-exact for Iron Law refs)
5. Full pytest suite passes on python:3.13-slim (l1-structural)
6. CI pipeline green on feature branch

## Success output

```json
{
  "workflow": "plugin-dev",
  "status": "completed",
  "primitive_type": "skill|hook|agent|command|module",
  "primitive_name": "new-thing",
  "tier": "dev",
  "registered_in": ["profiles/dev-addon.yaml", "hooks/hooks.json"],
  "tests_added": ["tests/test_new_thing.py"],
  "build_result": "build.sh modular PASS (30/37/68)",
  "hard_gate_result": "10/10 + new-thing OK",
  "evidence": [
    "CI pipeline #N: success",
    "bats tests green"
  ],
  "iron_laws_enforced": ["LAW-WORKFLOW-001", "LAW-VERIFY-001", "LAW-WORKFLOW-003"]
}
```

## See also

- `plugin-builder` — scaffolding skill (step 3)
- `skill-management` — profile registration (step 4)
- `hookify` — for hook-specific creation patterns
- `atlas-dev-self` — higher-level atlas develops atlas workflow
- Plan ref: `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md`
