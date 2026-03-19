---
name: security-audit
description: "Admin-tier security audit pipeline: OWASP Top 10 scanning, RBAC configuration review, secret/credential detection, SSL/TLS validation, container security (Docker/K8s), network access controls, and structured report generation with severity classifications (CRITICAL/HIGH/MEDIUM/LOW). Compliance references: SOC2, ISO 27001."
---

# Security Audit

Systematic security review of infrastructure, code, and configuration.
Produces actionable findings with severity, evidence, and remediation steps.

## Overview

```
SCOPE → SCAN → ANALYZE → REPORT → REMEDIATE
  ↑                                    |
  └──────── Re-audit after fixes ───────┘
```

**Audit principle:** Never exploit vulnerabilities — observe and report only.
**Evidence standard:** Every finding requires a command output or screenshot as proof.
**HITL gate:** Remediation actions on production always require explicit user approval.

---

## Severity Classification

| Severity | SLA | Definition | Examples |
|----------|-----|------------|---------|
| 🔴 CRITICAL | 24h | Immediate exploitation possible, data at risk | Exposed secrets, RCE, auth bypass |
| 🟠 HIGH | 72h | Significant risk, likely exploitable | Unpatched CVEs (CVSS ≥ 7), weak auth |
| 🟡 MEDIUM | 2w | Exploitable with preconditions | Missing rate limiting, info leakage |
| 🔵 LOW | 1mo | Defense-in-depth, unlikely exploitation | Verbose errors, missing headers |
| ⚪ INFO | Backlog | Best practice, no direct risk | Dependency upgrade, config hardening |

---

## Workflow

### Step 1: SCOPE

Define audit boundaries before scanning:

1. Identify target(s): codebase, container images, hosts, APIs, or all
2. Determine environment: dev / staging / prod (prod = read-only scans only)
3. Set compliance frameworks to check (SOC2, ISO 27001, or none)
4. List explicitly out-of-scope items (third-party SaaS, external CDN)

Present scope summary via AskUserQuestion:

```
AskUserQuestion:
  "Audit scope confirmed?"
  - "Approve scope — begin scanning" → proceed Step 2
  - "Narrow scope" → revise
  - "Add targets" → extend list
```

### Step 2: SCAN

Run scanners in parallel where safe. Read-only — no writes, no exploitation.

#### 2a. Secret Detection (Gitleaks)

```bash
# Repo history scan
gitleaks detect --source . --report-format json --report-path /tmp/gitleaks.json
cat /tmp/gitleaks.json | jq '.[] | {RuleID, File, Commit, Secret: (.Secret | .[0:8] + "****")}'

# Staged files only (pre-commit check)
gitleaks protect --staged --verbose

# Environment files
gitleaks detect --source . --no-git --include-paths "**/.env*,**/config/*.yaml,**/config/*.json" \
  --report-format json --report-path /tmp/gitleaks-config.json
```

#### 2b. Container Vulnerability Scan (Trivy + Grype)

```bash
# Trivy — image scan
trivy image --severity CRITICAL,HIGH --format json --output /tmp/trivy.json <image:tag>
trivy image --severity CRITICAL,HIGH <image:tag>

# Trivy — filesystem scan (catches IaC misconfigs too)
trivy fs --scanners vuln,secret,misconfig --format json --output /tmp/trivy-fs.json .

# Grype — alternative with EPSS scoring
grype <image:tag> --output json > /tmp/grype.json
grype <image:tag> -q

# Docker Bench Security (CIS Docker Benchmark)
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /etc:/etc:ro -v /usr/bin/containerd:/usr/bin/containerd:ro \
  -v /usr/bin/runc:/usr/bin/runc:ro \
  -v /usr/lib/systemd:/usr/lib/systemd:ro \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security
```

#### 2c. Dependency Vulnerability Scan

```bash
# Python (pip-audit — preferred over safety)
pip-audit --format json --output /tmp/pip-audit.json
pip-audit -r requirements.txt

# JavaScript/Node
npm audit --json > /tmp/npm-audit.json || bun audit
bunx audit-ci --critical

# SBOM generation (for compliance)
trivy fs --format spdx-json --output /tmp/sbom.spdx.json .
syft . -o spdx-json > /tmp/sbom.spdx.json
```

#### 2d. SSL/TLS Configuration

```bash
# testssl.sh (comprehensive TLS check)
testssl.sh --jsonfile /tmp/testssl.json --severity HIGH <hostname>:443

# Quick checks with openssl
echo | openssl s_client -connect <hostname>:443 -servername <hostname> 2>/dev/null \
  | openssl x509 -noout -dates -subject -issuer

# Check for weak protocols
nmap --script ssl-enum-ciphers -p 443 <hostname>

# Certificate expiry check (warn at 30 days)
echo | openssl s_client -connect <hostname>:443 2>/dev/null \
  | openssl x509 -noout -enddate \
  | awk -F= '{print $2}' | xargs -I{} date -d{} +%s \
  | xargs -I{} sh -c 'echo $(( ({} - $(date +%s)) / 86400 )) days remaining'
```

#### 2e. Network Security

```bash
# Open ports (Nmap — local network only)
nmap -sV --open -p- <host>

# Firewall rules review (UFW)
ufw status verbose

# Tailscale ACL review
tailscale debug acls

# Exposed services check — nothing should answer from 0.0.0.0 unexpectedly
ss -tlnp | grep "0.0.0.0"
docker ps --format "{{.Ports}}" | grep "0.0.0.0"

# Cloudflare Access — verify all admin URLs require auth
source ~/.env
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/access/apps" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[] | {name, domain, allowed_idps}'
```

#### 2f. RBAC Configuration Audit

```bash
# PostgreSQL roles and privileges
psql -U postgres -c "\du"
psql -U postgres -c "SELECT grantee, table_name, privilege_type FROM information_schema.role_table_grants WHERE grantee != 'postgres' ORDER BY grantee;"
psql -U postgres -c "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin FROM pg_roles;"

# Docker socket exposure (critical if readable by non-root)
ls -la /var/run/docker.sock
stat /var/run/docker.sock

# SSH authorized keys audit
for user in $(getent passwd | awk -F: '$7!="/usr/sbin/nologin" && $7!="/bin/false" {print $1}'); do
  f="/home/$user/.ssh/authorized_keys"
  [ -f "$f" ] && echo "=== $user ===" && cat "$f"
done
```

#### 2g. OWASP Top 10 Checklist (API)

For each API endpoint in scope, assess:

| OWASP Risk | Check Method |
|-----------|-------------|
| A01 Broken Access Control | Test unauthenticated access to protected routes |
| A02 Cryptographic Failures | Verify TLS, no sensitive data in logs/URLs |
| A03 Injection | Review parameterized queries, input validation |
| A04 Insecure Design | Review auth flow, HITL gate enforcement |
| A05 Security Misconfiguration | Headers, CORS, debug mode off in prod |
| A06 Vulnerable Components | pip-audit, npm audit, trivy |
| A07 Auth Failures | Session expiry, brute-force protection, MFA |
| A08 Software Integrity | Verify image digests, signed commits |
| A09 Logging Failures | No secrets in logs, audit trail present |
| A10 SSRF | Review any URL-fetch endpoints |

```bash
# HTTP security headers check
curl -sI https://<hostname> | grep -iE "strict-transport|x-frame|x-content-type|content-security|referrer-policy|permissions-policy"

# CORS misconfiguration
curl -sI -H "Origin: https://evil.com" https://<hostname>/api/v1/health | grep -i "access-control"

# Debug mode / info leakage
curl -s https://<hostname>/api/v1/health | jq 'if .debug then "⚠️ DEBUG ON" else "OK" end'
```

### Step 3: ANALYZE

Aggregate all scanner outputs. For each finding:

1. Assign severity (CRITICAL / HIGH / MEDIUM / LOW / INFO)
2. Write evidence block (exact command + truncated output)
3. Write remediation steps (specific, actionable)
4. Map to compliance control if framework selected (SOC2 CC6, ISO 27001 A.x.x)
5. Estimate remediation effort (hours)
6. Flag false positives with justification

**De-duplicate:** Same CVE across multiple images = one finding, list affected images.

### Step 4: REPORT

Generate structured security report:

```
╔══════════════════════════════════════════════════════════════╗
║  SECURITY AUDIT REPORT — 2026-03-18 14:30 EDT               ║
║  Target: synapse (staging + prod)  Framework: SOC2           ║
╠══════════════════════════════════════════════════════════════╣
║  SUMMARY                                                     ║
║  ─────────────────────────────────────────────────────────  ║
║  🔴 CRITICAL   2    🟠 HIGH   5    🟡 MEDIUM   8             ║
║  🔵 LOW        3    ⚪ INFO  11                               ║
╠══════════════════════════════════════════════════════════════╣
║  CRITICAL FINDINGS (fix within 24h)                          ║
║  [C-01] Exposed .env file — path: /opt/synapse/.env          ║
║         Evidence: curl http://... returns 200                ║
║         Fix: nginx deny rule + rotate all secrets            ║
║  [C-02] Docker socket writable by synapse user               ║
║         Evidence: ls -la /var/run/docker.sock → rw-rw----    ║
║         Fix: Remove synapse from docker group                 ║
╠══════════════════════════════════════════════════════════════╣
║  HIGH FINDINGS                                               ║
║  [H-01] CVE-2024-XXXXX in python:3.13.1 (CVSS 8.1)          ║
║  [H-02] TLSv1.0 enabled on api endpoint                      ║
║  ...                                                         ║
╠══════════════════════════════════════════════════════════════╣
║  COMPLIANCE STATUS (SOC2)                                    ║
║  CC6.1 Logical Access    ⚠️  PARTIAL  (H-03, H-04 open)      ║
║  CC6.2 Authentication    ✅  PASS                             ║
║  CC6.3 Authorization     ⚠️  PARTIAL  (C-02 open)            ║
╚══════════════════════════════════════════════════════════════╝
```

Output report to: `/tmp/security-audit-{date}.md` and present inline.

### Step 5: REMEDIATE

For each finding:

1. Present remediation command(s) — no auto-execution
2. Require HITL approval for any prod change
3. After fix, re-run the specific scanner that caught the issue
4. Mark finding as RESOLVED only when re-scan is clean

**HITL Gate (all prod remediations):**

```
AskUserQuestion:
  "Remediate [C-01] Exposed .env — approve execution?"
  - "Approve" → execute fix → re-scan → update report
  - "Manual fix" → provide commands for user to run
  - "Accept risk" → document exception with justification
  - "False positive" → mark with justification
```

---

## Subcommands

| Command | Description | HITL |
|---------|-------------|------|
| `/atlas audit` | Full audit pipeline (all domains) | Scope: yes |
| `/atlas audit secrets` | Secret/credential scan only | No |
| `/atlas audit containers` | Container CVE + misconfig scan | No |
| `/atlas audit ssl` | SSL/TLS certificate + cipher audit | No |
| `/atlas audit network` | Port scan + firewall + ACL review | No |
| `/atlas audit rbac` | DB roles + Docker + SSH access audit | No |
| `/atlas audit owasp` | OWASP Top 10 API checklist | No |
| `/atlas audit deps` | Dependency vulnerability scan | No |
| `/atlas audit report` | Generate report from last scan results | No |
| `/atlas audit remediate <id>` | Execute fix for specific finding | Prod: yes |

---

## Compliance Framework Mapping

### SOC2 Type II (CC Controls)

| Control | Audit Check |
|---------|------------|
| CC6.1 | RBAC audit, least-privilege DB roles, SSH keys |
| CC6.2 | MFA enabled, session timeout, password policy |
| CC6.3 | Access logs, HITL gates enforced, change audit trail |
| CC6.6 | Network controls, Tailscale ACL, Cloudflare Access |
| CC6.7 | Data in transit (TLS 1.2+), data at rest (encrypted volumes) |
| CC7.1 | Monitoring alerts, Uptime Kuma, Grafana alert rules |
| CC8.1 | Change management, PR review, CI gates |

### ISO 27001:2022

| Control | Audit Check |
|---------|------------|
| A.5.15 | Access control policy (RBAC, least privilege) |
| A.5.17 | Authentication management (MFA, key rotation) |
| A.8.8 | Vulnerability management (CVE scan SLA) |
| A.8.9 | Configuration management (no hardcoded secrets) |
| A.8.23 | Web filtering / firewall rules |
| A.8.24 | Use of cryptography (TLS versions, cipher strength) |
| A.8.25 | Secure development (SAST, dependency audit in CI) |

---

## Tool Reference

| Tool | Purpose | Install |
|------|---------|---------|
| `gitleaks` | Secret detection in Git history + files | `brew install gitleaks` |
| `trivy` | Container + filesystem CVE + misconfig | `brew install trivy` |
| `grype` | Container CVE with EPSS scoring | `brew install grype` |
| `syft` | SBOM generation | `brew install syft` |
| `pip-audit` | Python dependency CVEs | `pip install pip-audit` |
| `testssl.sh` | TLS configuration analysis | `brew install testssl` |
| `nmap` | Port scan + service detection | `brew install nmap` |
| `docker-bench-security` | CIS Docker Benchmark | Docker image |
| `hadolint` | Dockerfile linting (security rules) | `brew install hadolint` |

---

## Key Principles

- **Read-only by default** — scans observe, never exploit or modify
- **Evidence required** — every finding backed by command output (no speculation)
- **HITL for prod remediations** — no auto-fix on production
- **Secrets never printed in full** — truncate to first 8 chars + `****`
- **Max 2 fix retries** — if remediation fails twice, escalate via AskUserQuestion
- **Re-audit after fixes** — partial re-scan to confirm resolution, not just "trust the fix"
- **False positives documented** — accepted risks get justification + owner + review date
- **Compliance-mapped** — every CRITICAL/HIGH finding maps to at least one SOC2 or ISO 27001 control

---

## Error Recovery

| Scenario | Action |
|----------|--------|
| Scanner not installed | Provide install command, fallback to manual checklist |
| Network scan blocked | Note in scope limitations, use alternative (API-based check) |
| False positive flood | Tune scanner config (`.trivyignore`, `.gitleaksignore`) |
| Remediation breaks service | Rollback via `infrastructure-ops restart` → AskUserQuestion |
| Credentials found in scan | Immediately flag CRITICAL, ask user to rotate before report |

---

## Integration with Other Skills

| Workflow | Chain |
|----------|-------|
| Before prod release | `security-audit secrets` + `security-audit containers` → `devops-deploy` |
| Post-incident review | `security-audit` full → `infrastructure-ops` remediate |
| Weekly hygiene | `security-audit ssl` + `security-audit deps` → append to IMPROVEMENTS.md |
| Compliance prep | `security-audit` full with SOC2 framework → generate PDF report |
