---
name: workflow-deploy
description: "Deploy with verification + CI gate + audit-ship. This skill should be used when pushing code to prod or deploying infra changes."
effort: medium
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [workflow-incident-response, devops-deploy, ci-feedback-loop]
thinking_mode: adaptive
version: 6.1.0
tier: [core, dev, admin]
category: infrastructure
emoji: "🚢"
triggers: ["deploy", "push to prod", "ship", "release"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 45
persona_tags: [devops]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Pre-deploy verification"
    skill: verification
    gate: MANDATORY
    iron_law_ref: LAW-VERIFY-001
    purpose: "All tests green + staging smoke + rollback plan exists"
    parallelizable: false
    depends_on: []
    model_preference: sonnet
    effort: low

  - step: 2
    name: "Deploy"
    skill: devops-deploy
    gate: MANDATORY
    purpose: "Trigger deploy pipeline. Observe build output."
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "CI feedback loop"
    skill: ci-feedback-loop
    gate: HARD_GATE
    iron_law_ref: LAW-WORKFLOW-001
    purpose: "Poll deploy pipeline until terminal state"
    parallelizable: false
    depends_on: [2]
    model_preference: haiku
    effort: low

  - step: 4
    name: "Post-deploy smoke"
    skill: api-healthcheck
    gate: HARD_GATE
    purpose: "G3 smoke on live endpoints. Real HTTP + auth + DB."
    parallelizable: false
    depends_on: [3]
    model_preference: haiku
    effort: low

  - step: 5
    name: "Audit log entry"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Who deployed what, when, why. Traceable."
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO DEPLOY WITHOUT PRE + POST SMOKE.
Pre = know what you're shipping. Post = know it actually works.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "CI is green, deploy confidently" | CI tests against test data. Prod has real data. Post-smoke = proof. |
| "Rollback is an escape hatch, not needed" | Every deploy has rollback plan BEFORE deploy. Not during incident. |
| "Smoke is just a curl" | YES and it catches 80% of deploy regressions. Always run. |
</red-flags>

## Success output

```json
{
  "workflow": "deploy",
  "status": "completed",
  "env": "staging | prod",
  "commit_shipped": "sha",
  "ci_pipeline": "#N",
  "post_smoke_pass": true,
  "rollback_plan": "git revert / previous tag"
}
```
