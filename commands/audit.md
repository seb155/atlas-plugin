Invoke the `security-audit` skill with the following arguments: $ARGUMENTS

This is the ATLAS security audit command. It runs structured security reviews covering
secrets, container CVEs, SSL/TLS, network access, RBAC, and OWASP Top 10. Produces
severity-classified findings (CRITICAL/HIGH/MEDIUM/LOW) with evidence and remediation steps.

Subcommands:
- `/atlas audit` — Full audit pipeline across all domains (scope confirmation required)
- `/atlas audit secrets` — Secret/credential scan via gitleaks (repo history + config files)
- `/atlas audit containers` — Container CVE + misconfig scan via trivy + grype
- `/atlas audit ssl` — SSL/TLS certificate expiry, cipher strength, protocol audit
- `/atlas audit network` — Port scan + firewall rules + Tailscale ACL + Cloudflare Access
- `/atlas audit rbac` — PostgreSQL roles + Docker socket + SSH authorized keys review
- `/atlas audit owasp` — OWASP Top 10 API checklist (headers, CORS, auth, injection)
- `/atlas audit deps` — Dependency CVE scan (pip-audit for Python, bun/npm audit for JS)
- `/atlas audit report` — Generate/display report from most recent scan results
- `/atlas audit remediate <id>` — Execute fix for a specific finding ID (prod requires HITL)

If no subcommand given, run full audit pipeline with scope confirmation.

Workflow: SCOPE → SCAN → ANALYZE → REPORT → REMEDIATE
Compliance frameworks supported: SOC2 Type II, ISO 27001:2022.
Read-only scans — never exploit, never auto-remediate production without HITL approval.
