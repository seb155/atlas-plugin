# ATLAS Plugin — Security Policy & Threat Model

> **Last updated**: 2026-04-19
> **Owner**: Seb Gagnon (AXOIQ) — `security@axoiq.com` (planned)
> **Status**: Draft v1.0 — authored as plan `joyful-hare` Batch 1 REC-018

---

## Scope

This policy covers the **ATLAS Plugin** (source repo `forgejo.axoiq.com/axoiq/atlas-plugin`), distributed as three tiers:
- `atlas-core` (28 skills)
- `atlas-dev-addon` (36 skills)
- `atlas-admin-addon` (67 skills)

Installed via Claude Code plugin system from `plugins.axoiq.com` marketplace (Forgejo-backed).

**Out of scope**:
- Synapse application (see `projects/atlas/synapse/docs/SECURITY.md` — separate policy)
- AXOIQ infrastructure (Proxmox, Cloudflare, NetBird) — internal ops
- Third-party MCP servers referenced by ATLAS skills (users responsible)

---

## Threat Model

### Attacker classes

| Class | Motivation | Capability |
|-------|------------|------------|
| **Supply-chain attacker** | Insert malicious skill into marketplace to steal API keys, exfiltrate data, or establish persistence | Submit skill via PR, exploit review fatigue |
| **Prompt-injection attacker** | Craft SKILL.md content that makes Claude violate safety rules or leak secrets | Write natural language directives in skill body |
| **Curious insider** | Investigate other tenants' data or skill collections | Valid ATLAS install + filesystem access |
| **Accidental** | Developer commits sensitive data, writes over-privileged skill by mistake | Normal contributor workflow |

### Assets under protection

| Asset | Risk if compromised |
|-------|---------------------|
| **User API keys** (`$ANTHROPIC_API_KEY`, `$AWS_*`, `$GITHUB_TOKEN`, `$FORGEJO_TOKEN`, Infisical secrets) | API abuse, cloud resource hijack, repo takeover |
| **ATLAS plugin cache** (`~/.claude/plugins/cache/`) | Agent behavior manipulation, persistence across sessions |
| **Seb's memory/context** (`~/.claude/projects/*/memory/`) | Private notes, business strategy, client data leak |
| **Synapse client data** (THM-012, BRTZ, CAJB, FORAN, oko-ref) | Mining project confidentiality, contract breach |
| **G Mining pilot deployment** (planned 2026-05) | Client trust, commercial relationship, CVE exposure |
| **AXOIQ internal infra** (PVE/TrueNAS/Authentik SSO) | Homelab compromise, identity provider takeover |

### Known threat patterns

Based on **Snyk ToxicSkills audit (February 2026)**:
- 3,984 skills audited from ClawHub + skills.sh
- **36.82%** contained prompt-injection patterns
- **1,467** carried malicious payloads
- **91%** combined prompt injection with traditional payloads (single-vector scanners miss these)

Cited events:
- **ClawHavoc campaign (Feb 2026)**: 1,184 malicious skills distributed as coordinated supply-chain attack
- **CVE-2025-59536** (CVSS 8.7): host-side vulnerability triggered by crafted skill metadata

Reference: https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/

---

## Security Controls

### Layer 1: Skill install gate (ADR-013)

Every third-party skill goes through **`scripts/pre-install-skill-check.sh`** before installation:
- Invokes `npx github:LichAmnesia/skill-lint` (OWASP Agentic Skills Top 10 compliant)
- 10 rules: R01 Prompt Injection, R02 Obfuscation, R03 Shell Danger, R04 Credential Exfil, R05 External Fetch, R06 Suspicious Binaries, R07 Persistence Tamper, R08 Destructive Ops, R09 Metadata Abuse, R10 Over-Privilege
- Verdict: SAFE (install) / WARN (interactive approval required) / TOXIC (blocked, never overridable)
- Regex-based (deterministic, <100ms)

**Limitation**: regex patterns catch known attacks but may miss novel prompt injections. Pair with human review for high-value skills.

See: `docs/ADR/ADR-013-skill-lint-security-baseline.md`

### Layer 2: Plugin manifest validation (REC-008)

**`scripts/validate-plugin-json.sh`** enforces Anthropic canonical plugin.json schema:
- name kebab-case regex
- SemVer version
- description 50-200 chars
- author structured
- license declared

Violations block CI (future — REC-016 Forgejo workflow).

### Layer 3: Skill-activation eval (REC-001 — pending)

Port of `obra/superpowers/tests/skill-triggering/` to ATLAS. Ensures skill descriptions actually trigger correct skills on natural prompts. Nightly regression detects drift.

### Layer 4: Plugin cache read-only (enforced)

`~/.claude/plugins/cache/` is managed by the plugin sync system. Direct writes are **forbidden** and enforced via:
- Rule file: `synapse/.claude/rules/plugin-cache.md`
- Pre-tool-use hook in atlas-core blocks writes to that path

Source edits go to the plugin repo → `make publish` → cache sync. Never the other way.

### Layer 5: Secret scanning (existing)

Pre-commit hook runs **Gitleaks** across:
- Commit messages
- Staged diff
- Known secret patterns (API keys, tokens, private keys)

See: `lefthook.yml` (atlas-plugin repo and downstream Synapse).

### Layer 6: HITL gates (philosophical, per PHILOSOPHY.md §2)

**Every meaningful mutation requires Seb approval** (or designated reviewer). Automated actions limited to:
- Local files in project workspace
- Reversible git operations on feature branches
- Reads (any scope)

Irreversible actions (push, merge, deploy, external API calls with side effects) always prompt.

### Layer 7: Secret manager (Infisical)

API keys, tokens, and credentials stored in **Infisical** (primary) with `.env` fallback. Never committed, never hardcoded in skills. Audit: `atlas-admin-addon:secret-manager` skill.

---

## Vulnerability Disclosure

### How to report

Report vulnerabilities to: **`security@axoiq.com`** (planned) OR open a Forgejo issue with label `security` in `forgejo.axoiq.com/axoiq/atlas-plugin`.

Until `security@axoiq.com` is live (ETA 2026-Q2), use: `s.gagnon.ing@gmail.com`.

### What to include

1. **Vulnerability description**: what you observed
2. **Reproduction steps**: minimal working example
3. **Impact assessment**: what an attacker could do
4. **Suggested remediation** (optional but appreciated)
5. **Your preferred disclosure timeline**

### Our commitment

- **Acknowledge receipt within 72h** (business days)
- **Initial triage within 7 days**
- **Patch timeline**: critical ≤14 days, high ≤30 days, medium ≤90 days
- **Credit you in disclosure** unless you prefer anonymity

### Responsible disclosure

We follow a **90-day disclosure window**:
- Days 1-90: coordinated fix, no public disclosure
- Day 91+: public release of patch + advisory (if fix shipped)
- If fix not shipped by day 90: mutual extension or independent disclosure permitted

---

## Known Limitations & Acknowledged Risks

ATLAS is currently a **single-tenant internal tool** migrating to commercial deployment. Current limitations:

1. **Security testing is incomplete**: skill-triggering eval (REC-001) not yet implemented. Manual review gap.
2. **External plugin review is manual**: no community-contributed skills accepted yet. When they arrive, process is to be defined.
3. **MCP server trust**: ATLAS skills reference MCP servers (context7, playwright, chrome) but don't audit their security. User responsibility.
4. **Log exposure**: Claude conversation transcripts (`~/.claude/projects/*/`) contain sensitive details. `.gitignore` excludes but no encryption at rest.
5. **Homelab single-location**: PVE1/PVE2/PVE3 at single physical location — backup resilience depends on external PBS targets (to verify).
6. **skill-lint is 1-day-old (2026-04-19)**: our primary defense is an immature tool. Mitigation: pair with human review, plan fork (ADR-014) if upstream abandons.

We are **not claiming** to be security-certified (SOC2, ISO27001, etc.) at this time. ATLAS is offered with the understanding that:
- Users run it at their own risk
- G Mining pilot is governed by separate commercial agreement with appropriate warranties
- We apply best-effort security practices but do not warrant against all threats

---

## Compliance References

- **OWASP Agentic Skills Top 10 (AST10)**: https://owasp.org/www-project-agentic-skills-top-10/
- **Snyk ToxicSkills blog**: https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/
- **Anthropic Plugin Security Guidance**: https://code.claude.com/docs/en/plugins (section: security)
- **CVE-2025-59536** (CVSS 8.7): NVD entry (monitored for related CVEs)

---

## Change history

| Date | Change | Source |
|------|--------|--------|
| 2026-04-19 | Initial draft — threat model, 7-layer controls, disclosure process | plan `joyful-hare` REC-018 |

---

*SECURITY.md v1.0 — Draft — authored 2026-04-19 by ATLAS (Opus 4.7). Accepted for publication by Seb Gagnon 2026-04-19 via direct execution approval.*
*Living document — update when threats, controls, or policies evolve.*
