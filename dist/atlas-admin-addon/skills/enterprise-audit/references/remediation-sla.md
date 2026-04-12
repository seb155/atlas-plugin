# Remediation SLA by Severity

| Severity | SLA | Definition | Examples | Action |
|----------|-----|------------|---------|--------|
| CRITICAL | 24h | Blocks sale, immediate risk | Missing LICENSE, exposed secrets, auth bypass | Stop other work, fix immediately |
| HIGH | 72h | Must fix before demo | No Sentry, missing project_id filter, :latest in prod | Schedule in current sprint |
| MEDIUM | 2 weeks | Fix for credibility | Missing docs, no log rotation, weak password policy | Add to backlog, next sprint |
| LOW | 1 month | Nice-to-have | Signed commits, SBOM, deprecation headers | Track, address when convenient |
| INFO | Backlog | Informational only | Best practice suggestions | No action required |

## Escalation
- If CRITICAL not resolved in 48h → escalate to project owner
- If 3+ HIGH findings open > 1 week → schedule remediation sprint
- Track progress via _audit-history/ JSON comparison
