---
name: security-audit
description: "Admin-tier security audit pipeline. This skill should be used when the user asks to 'security audit', 'OWASP scan', 'RBAC review', 'secret scan', 'SSL audit', '/atlas security audit', or needs SOC2/ISO27001 compliance reports with CRITICAL/HIGH/MEDIUM/LOW severity."
effort: high
---

# Security Audit

Systematic security review. Observe and report only — never exploit.
Every finding requires command output as evidence. HITL gate on all prod remediations.

## Pipeline

```
SCOPE → SCAN → ANALYZE → REPORT → REMEDIATE → Re-audit
```

## Severity Classification

| Severity | SLA | Definition | Examples |
|----------|-----|------------|---------|
| 🔴 CRITICAL | 24h | Immediate exploitation, data at risk | Exposed secrets, RCE, auth bypass |
| 🟠 HIGH | 72h | Significant risk, likely exploitable | Unpatched CVEs (CVSS >= 7), weak auth |
| 🟡 MEDIUM | 2w | Exploitable with preconditions | Missing rate limiting, info leakage |
| 🔵 LOW | 1mo | Defense-in-depth | Verbose errors, missing headers |
| ⚪ INFO | Backlog | Best practice | Dependency upgrade, config hardening |

## Workflow

### Step 1: SCOPE
Define targets (codebase/containers/hosts/APIs), environment (dev/staging/prod), compliance framework (SOC2/ISO27001/none), out-of-scope items.

**HITL Gate**: AskUserQuestion to approve scope before scanning.

### Step 2: SCAN (read-only, parallel where safe)

| Domain | Tool(s) | Key command pattern |
|--------|---------|-------------------|
| **Secrets** | gitleaks | `gitleaks detect --source . --report-format json --report-path /tmp/gitleaks.json` |
| **Containers** | trivy, grype | `trivy image --severity CRITICAL,HIGH <image:tag>` |
| **Dependencies** | pip-audit, npm audit | `pip-audit --format json` / `bun audit` |
| **SSL/TLS** | testssl.sh, openssl | `testssl.sh --severity HIGH <host>:443` |
| **Network** | nmap, ufw, tailscale | `nmap -sV --open -p- <host>` / `ss -tlnp \| grep 0.0.0.0` |
| **RBAC** | psql, stat, SSH keys | `psql -c "\du"` / `ls -la /var/run/docker.sock` |
| **OWASP Top 10** | curl, code review | Headers check, CORS, debug mode, input validation |

**Secrets rule**: Never print full secrets — truncate to 8 chars + `****`.

### Step 3: ANALYZE
For each finding: assign severity, write evidence block, write remediation steps, map to compliance control, estimate hours, flag false positives.
De-duplicate: same CVE across images = one finding.

### Step 4: REPORT
Structured report to `/tmp/security-audit-{date}.md`: summary counts by severity, findings with evidence + fix, compliance status matrix.

### Step 5: REMEDIATE

**HITL Gate (all prod changes)**:
```
AskUserQuestion: "Remediate [{id}] {title} — approve?"
→ Approve | Manual fix | Accept risk | False positive
```
After fix → re-run specific scanner → mark RESOLVED only on clean re-scan. Max 2 fix retries → escalate.

## Subcommands

| Command | Scope | HITL |
|---------|-------|------|
| `audit` | Full pipeline (all domains) | Scope: yes |
| `audit secrets` | Secret/credential scan | No |
| `audit containers` | Container CVE + misconfig | No |
| `audit ssl` | TLS certificate + cipher | No |
| `audit network` | Port + firewall + ACL | No |
| `audit rbac` | DB roles + Docker + SSH | No |
| `audit owasp` | OWASP Top 10 API checklist | No |
| `audit deps` | Dependency vulnerabilities | No |
| `audit report` | Generate report from last scan | No |
| `audit remediate <id>` | Fix specific finding | Prod: yes |

## Compliance Mapping

### SOC2 Type II

| Control | Check |
|---------|-------|
| CC6.1 | RBAC, least-privilege, SSH keys |
| CC6.2 | MFA, session timeout, password policy |
| CC6.3 | Access logs, HITL gates, audit trail |
| CC6.6 | Network controls, Tailscale ACL, CF Access |
| CC6.7 | TLS 1.2+, encrypted volumes |
| CC7.1 | Monitoring alerts, Uptime Kuma, Grafana |
| CC8.1 | Change management, PR review, CI gates |

### ISO 27001:2022

| Control | Check |
|---------|-------|
| A.5.15 | Access control (RBAC, least privilege) |
| A.5.17 | Auth management (MFA, key rotation) |
| A.8.8 | Vulnerability management (CVE scan SLA) |
| A.8.9 | Config management (no hardcoded secrets) |
| A.8.23-25 | Web filtering, cryptography, secure dev |

## Tool Reference

| Tool | Purpose | Install |
|------|---------|---------|
| gitleaks | Secret detection | `brew install gitleaks` |
| trivy | Container/FS CVE + misconfig | `brew install trivy` |
| grype | Container CVE + EPSS | `brew install grype` |
| pip-audit | Python dependency CVEs | `pip install pip-audit` |
| testssl.sh | TLS analysis | `brew install testssl` |
| nmap | Port/service scan | `brew install nmap` |

## Error Recovery

| Scenario | Action |
|----------|--------|
| Scanner not installed | Install command + fallback to manual checklist |
| Network scan blocked | Note in scope, use API-based alternative |
| False positive flood | Tune config (`.trivyignore`, `.gitleaksignore`) |
| Remediation breaks service | Rollback → `infrastructure-ops restart` → AskUserQuestion |
| Credentials found | Immediately CRITICAL, ask user to rotate before report |

## Key Principles
- Read-only scans only — never exploit or modify
- Evidence required — no speculation
- HITL for prod remediations — no auto-fix
- Max 2 fix retries → escalate via AskUserQuestion
- Re-audit after fixes — never trust without re-scan
- Every CRITICAL/HIGH maps to compliance control
