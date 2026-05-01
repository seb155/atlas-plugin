---
name: workflow-audit
description: "Codebase audit + report + enforcement plan. Uses 4-phase audit protocol (inventory → fix → enforce → verify)."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [codebase-audit, audit-enforcement-protocol, workflow-quality-gate]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: research
emoji: "🔎"
triggers: ["audit", "code review deep", "tech debt scan", "compliance check"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 120
persona_tags: [engineer, architect]
requires_hitl: false

workflow_steps:
  - step: 1
    name: "Phase 1 — Inventory"
    skill: codebase-audit
    gate: MANDATORY
    purpose: "Ground-truth baseline. Count violations, top offenders, drift from prior audit."
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: max

  - step: 2
    name: "Phase 2 — Fix"
    skill: workflow-refactor
    gate: MANDATORY
    purpose: "One-time cleanup. Commit per logical unit."
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: high

  - step: 3
    name: "Phase 3 — Enforce (≥4/8 layers, ≥1 of L1 or L6)"
    skill: document-generator
    gate: HARD_GATE
    purpose: "Add semgrep/lefthook/CI gate/regression test. DoD = audit-enforcement-protocol"
    parallelizable: false
    depends_on: [2]
    model_preference: opus
    effort: high

  - step: 4
    name: "Phase 4 — Verify enforcement catches synthetic violation"
    skill: verification
    gate: HARD_GATE
    iron_law_ref: LAW-VERIFY-001
    purpose: "Prove the enforcement works. Synthetic violation → detected → fix → not detected."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium

  - step: 5
    name: "Registry entry"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Add to .blueprint/AUDITS-REGISTRY.md with score N/8"
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO AUDIT COMPLETE WITHOUT ENFORCEMENT + VERIFICATION + REGISTRY.
Documentation-only audits = 0% efficacy. Enforce or don't bother.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "I fixed the violations, done" | They come back. Enforcement layer is mandatory. |
| "Score 2/8 is fine" | DoD = ≥4/8 with ≥1 of {L1 type-impossible, L6 regression test}. Anything less = fake enforcement. |
| "Skip Phase 4 verification, I know it works" | Prove it catches real violations. Non-negotiable. |
</red-flags>

## Success output

```json
{
  "workflow": "audit",
  "status": "completed",
  "audit_id": "AUDIT-N",
  "baseline_violations": K1,
  "remaining_violations": K2,
  "enforcement_score": "N/8",
  "layers_active": ["L3", "L4", "L5", "L6", "L7"],
  "registry_entry": ".blueprint/AUDITS-REGISTRY.md#N"
}
```
