# ADR-013: skill-lint as Security Baseline for Third-Party Skills

**Status**: Accepted
**Date**: 2026-04-19
**Deciders**: Seb Gagnon
**Source**: Benchmark 2026-04-19 (plan `joyful-hare`, Batch 1)
**Source repo**: LichAmnesia/skill-lint (https://github.com/LichAmnesia/skill-lint)
**Related**: ADR-014 (fork skill-lint, pending), ADR-011 (description convention)

---

## Context

The agent-skills ecosystem has a documented security problem:

- **Snyk ToxicSkills audit (Feb 2026)**: 3,984 skills audited from ClawHub + skills.sh → **36.82%** contained prompt-injection patterns, **1,467** carried malicious payloads
- **ClawHavoc campaign (Feb 2026)**: 1,184 malicious skills distributed as coordinated supply-chain attack
- **CVE-2025-59536** (CVSS 8.7): host-side vulnerability triggered by crafted skill metadata
- **91%** of malicious skills combine prompt injection with traditional payloads — single-vector scanners miss them

ATLAS currently ships 131 skills (all Seb-authored or curated) with plans to open external contributions (G Mining partners, community). There is no automated security gate.

Risk exposure:
- Malicious third-party skill enters ATLAS marketplace → affects all installations
- G Mining pilot (May 2026) imperiled if supply-chain incident occurs
- ATLAS `skill-security-audit` skill is prose guidance, not executable scanner

LichAmnesia/skill-lint (created 2026-04-19) is a Node.js security scanner with:
- 10 rules mapped to OWASP Agentic Skills Top 10 (AST10)
- CI-first UX (exit codes 0=SAFE, 1=WARN, 2=TOXIC, 3=ERROR)
- Zero-dep-aside-from-chalk+yaml (lean)
- `npx skill-lint <url>` — zero-install
- MIT license, deterministic regex-based (fast, <100ms)

## Decision

ATLAS adopts **skill-lint as its security baseline** via three integration points:

### 1. Runtime dependency (primary)

ATLAS invokes `skill-lint` via `npx` at skill-install time. **No fork, no port** — depend on upstream.

Rationale:
- Upstream is actively maintained (authored 2026-04-19 by expert security researcher)
- Regex-based → no LLM/runtime cost for ATLAS
- `npx` pattern → zero install friction (Node 20+ already required for `@axoiq/atlas-cli`)
- Fork only if ATLAS-specific rules needed (ADR-014 pending)

### 2. Script wrapper

New script: `scripts/pre-install-skill-check.sh`

Behavior:
- Input: skill URL (GitHub/Forgejo) OR local directory path
- Runs: `npx --yes skill-lint "$INPUT" --json`
- Parses verdict from JSON (`{"verdict": "SAFE|WARN|TOXIC"}`)
- Exit codes passthrough: 0=SAFE, 1=WARN, 2=TOXIC, 3=ERROR
- If WARN: prompt user to review findings
- If TOXIC: print findings and refuse

### 3. CI gate (future — REC-016)

`.forgejo/workflows/skill-security.yml` runs skill-lint on every PR that touches `plugins/external/*` or adds new skills. Implemented separately per REC-016.

## Consequences

### Positive

- **Supply-chain protection**: malicious third-party skills blocked at install time
- **Zero LLM cost**: deterministic regex = no API calls during scanning
- **Immediate deployment**: `npx` pattern → no ATLAS install changes required for users
- **OWASP alignment**: ATLAS inherits AST10 compliance via dependency
- **Upstream improvements flow free**: new rules added to skill-lint benefit ATLAS automatically

### Negative

- **Regex has limits**: modern prompt injections evolve faster than regex patterns. False negatives possible for novel attacks.
- **Runtime dependency on `npx`**: `skill-lint` must remain available on npm registry. Risk of upstream deletion (low but non-zero). Mitigation: cache latest known-good version.
- **Node 20+ required**: blocks users on older Node. Mitigation: `package.json` engines + pre-install check.
- **No ATLAS-specific rules initially**: plugin-cache read-only, CSO compliance, etc. not covered until ADR-014 fork.

### Risks

- **Upstream abandonment**: skill-lint is 1-day-old project (2026-04-19). Risk of abandonment.
  - *Mitigation*: pin version in `package.json`, audit author activity quarterly, ADR-014 fork if signals negative
- **False positives**: R01 prompt-injection regex may flag legitimate skills documenting injection attacks (e.g., ATLAS skill-security-audit itself)
  - *Mitigation*: `skill-lint --ignore-rules R01 <path>` for whitelisted internal skills, documented in `scripts/pre-install-skill-check.sh`
- **Version pinning vs freshness tradeoff**: pinning avoids breaking changes but misses new rules
  - *Mitigation*: minor version range (`^0.1.0`), Dependabot-style weekly check

## Alternatives considered

### A1 — Port skill-lint to ATLAS (fork + maintain)

Rejected as initial approach: we get the security benefit faster by depending. Fork is ADR-014 pending, when ATLAS-specific rules are needed (plugin-cache enforcement, etc.).

### A2 — Build ATLAS scanner from scratch

Rejected: duplicates work, slower to ship, no benefit vs depending on skill-lint. OWASP AST10 compliance would require re-researching the threat taxonomy.

### A3 — Use generic code scanners (semgrep, gitleaks)

Rejected: those tools catch traditional code payloads but miss `SKILL.md` prose-based prompt injection (the most common attack surface per Snyk stats). skill-lint is purpose-built for the agent-skill attack surface.

### A4 — Human review only (no automation)

Rejected: 131 current skills + unknown future community contributions make this unsustainable. Human review augments but cannot replace automated gate.

### A5 — No security gate (status quo)

Rejected: G Mining pilot approaches. Unacceptable posture for commercial deployment.

## Implementation path

- [x] **Phase 1 (this ADR, 2026-04-19)**: decision documented
- [ ] **Phase 2 (REC-015, 1-3h)**: `scripts/pre-install-skill-check.sh` wrapper script
- [ ] **Phase 3 (REC-019, 3-5h)**: integrate into `/atlas audit-enterprise` skill
- [ ] **Phase 4 (REC-016, 2-4h)**: Forgejo CI workflow `.forgejo/workflows/skill-security.yml`
- [ ] **Phase 5 (REC-018, 3-5h)**: document threat model in `docs/SECURITY.md` with this ADR as technical reference
- [ ] **Ongoing**: quarterly review of skill-lint upstream activity, update pinned version

## Usage example

```bash
# Pre-install check for a third-party skill
./scripts/pre-install-skill-check.sh https://github.com/someone/questionable-skill

# Output example (TOXIC):
#   [skill-lint] Verdict: TOXIC (score 15)
#     R01 Prompt Injection (CRITICAL): "ignore previous instructions" at SKILL.md:23
#     R04 Credential Exfil (CRITICAL): $ANTHROPIC_API_KEY interpolated in curl at scripts/exfil.sh:12
#   ❌ Refusing to install.
#   Exit code: 2

# Output example (SAFE):
#   [skill-lint] Verdict: SAFE (score 0)
#   ✅ No security findings.
#   Exit code: 0

# Integration in ATLAS workflow
atlas skill install @community/some-skill
  ↓ invokes pre-install-skill-check.sh
  ↓ if SAFE → proceed to install
  ↓ if WARN → prompt Seb for explicit approve
  ↓ if TOXIC → abort with details
```

## References

- LichAmnesia/skill-lint README + `src/rules/R01-R10.js`
- OWASP Agentic Skills Top 10: https://owasp.org/www-project-agentic-skills-top-10/
- Snyk ToxicSkills blog: https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/
- CVE-2025-59536 (CVSS 8.7)
- ATLAS benchmark report 2026-04-19 §Per-repo Analysis #3 (skill-lint)
- ATLAS benchmark matrix 2026-04-19 (REC-015, REC-016, REC-017, REC-018, REC-019)

---

*ADR-013 authored 2026-04-19 by ATLAS (Opus 4.7) as plan `joyful-hare` Batch 1 REC-015. Accepted by Seb Gagnon 2026-04-19 via direct execution approval.*
