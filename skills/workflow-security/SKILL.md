---
name: workflow-security
description: "Security audit + remediation + verify. This skill should be used for security-focused reviews, vulnerability remediation, or compliance work."
effort: high
superpowers_pattern: [iron_law, red_flags, hard_gate]
see_also: [security-audit, workflow-infra-change, enterprise-audit]
thinking_mode: adaptive
version: 6.1.0
tier: [dev, admin]
category: infrastructure
emoji: "🔒"
triggers: ["security audit", "security fix", "vulnerability", "compliance", "CVE"]

schema_version: 1
output_schema_ref: ".blueprint/schemas/workflow-step-result-v1.json"
resumable: true
parallelizable_groups: []
estimated_duration_min: 90
persona_tags: [devops, infra_engineer]
requires_hitl: true

workflow_steps:
  - step: 1
    name: "Security audit"
    skill: security-audit
    gate: MANDATORY
    purpose: "OWASP top 10, dependency CVEs, secrets scan, RBAC review"
    parallelizable: false
    depends_on: []
    model_preference: opus
    effort: max

  - step: 2
    name: "Triage findings"
    skill: document-generator
    gate: MANDATORY
    purpose: "Severity (critical/high/medium/low), affected scope, fix complexity"
    parallelizable: false
    depends_on: [1]
    model_preference: sonnet
    effort: medium

  - step: 3
    name: "Remediate critical+high"
    skill: workflow-code-change
    gate: HARD_GATE
    purpose: "Fix each critical/high finding. Medium+low can be queued."
    parallelizable: false
    depends_on: [2]
    model_preference: sonnet
    effort: high

  - step: 4
    name: "Re-audit"
    skill: security-audit
    gate: HARD_GATE
    purpose: "Confirm fixes closed. No new findings introduced by remediation."
    parallelizable: false
    depends_on: [3]
    model_preference: sonnet
    effort: medium

  - step: 5
    name: "Audit trail"
    skill: decision-log
    gate: HARD_GATE
    purpose: "Findings + fixes + accepted risks with reason + expiry date"
    parallelizable: false
    depends_on: [4]
    model_preference: haiku
    effort: low
---

<HARD-GATE>
NO CRITICAL SECURITY FINDING SHIPS UN-REMEDIATED.
Accepted risk requires explicit HITL + expiry date + compensating control.
</HARD-GATE>

<red-flags>
| Thought | Reality |
|---|---|
| "CVE 8.0 but hard to exploit in our setup" | 'Hard to exploit' is not 'impossible'. Fix or explicit accept-risk. |
| "Secrets in .env, fine as long as .env is gitignored" | Backups, logs, CI env. Assume .env leaks. Use secret manager. |
| "Security audit quarterly is enough" | CVEs drop daily. CI-integrated scan + quarterly deep audit. |
</red-flags>

## Success output

```json
{
  "workflow": "security",
  "status": "completed",
  "findings_total": N,
  "critical": K1, "high": K2, "medium": K3, "low": K4,
  "remediated": M,
  "accepted_risks": [{"id": "...", "expiry": "YYYY-MM-DD", "reason": "..."}],
  "re_audit_clean": true
}
```
