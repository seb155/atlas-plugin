# Enterprise Audit — Scoring Rubric

> SSoT for all grade calculations. Referenced by `SKILL.md` Phase 3.
> Updated: 2026-03-19

---

## Per-Check Score Weights

Each individual checker produces findings classified by severity. Findings deduct from a dimension's base score of 100.

| Severity | Deduction per finding | Cap (max deduction) |
|----------|-----------------------|---------------------|
| CRITICAL | −20 pts | −60 (3 findings max deduction) |
| HIGH | −10 pts | −40 |
| MEDIUM | −5 pts | −25 |
| LOW | −2 pts | −10 |
| INFO | 0 pts | — |

**Floor**: No dimension score goes below 0.

**Bonus credits** (up to +5 pts per dimension):
- Automated checker CI integration: +2
- Finding fixed since last audit (delta improvement): +1 per resolved HIGH+
- Formal documentation for the dimension exists in `.blueprint/`: +2

---

## Dimension Weights

| # | Dimension | Weight | Rationale |
|---|-----------|--------|-----------|
| 1 | Security | 20% | Non-negotiable for enterprise — any breach = reputational loss |
| 2 | Multi-tenancy | 15% | G Mining manages multiple projects — data isolation is critical |
| 3 | Data integrity | 12% | Financial/engineering data — wrong numbers = wrong decisions |
| 4 | Deployment | 10% | Must be reproducible, rollback-capable, and auditable |
| 5 | Testing | 10% | Coverage + quality gates = confidence in changes |
| 6 | Ops / observability | 8% | Can you detect and diagnose incidents? |
| 7 | Code quality | 6% | Maintainability — especially important with AI co-developer model |
| 8 | Documentation | 5% | Handoff-ready knowledge base |
| 9 | Dependencies | 5% | Supply chain risk — CVEs, license violations |
| 10 | API surface | 4% | Versioned, documented, stable contracts |
| 11 | i18n / localization | 2% | Multilingual operations (FR/EN for Quebec projects) |
| 12 | Accessibility | 1% | WCAG 2.1 AA — internal policy for gov-adjacent clients |
| 13 | Governance | 1% | Change control, review process, decision log |
| 14 | Performance | 1% | Baseline benchmarks documented |

**Total**: 100%

---

## Overall Grade Mapping

```
weighted_overall = Σ(dimension_score × dimension_weight / 100)
```

| Grade | Score Range | Meaning for G Mining |
|-------|-------------|---------------------|
| A | 90 – 100 | Enterprise-ready. Proceed with confidence. |
| B | 80 – 89 | Enterprise-ready with minor gaps. Acceptable for adoption. |
| C | 70 – 79 | Conditional. Address HIGH findings before production rollout. |
| D | 60 – 69 | Not ready. Significant remediation required. |
| F | < 60 | Blocked. Do not proceed with enterprise review until reaudit. |

**G Mining minimum threshold**: **Grade B (≥80)** across overall AND no CRITICAL findings open.

A Grade A in 12 dimensions with a CRITICAL finding in Security still results in a conditional hold until the CRITICAL is resolved.

---

## Dimension-Level Grade Mapping

Same scale applied per dimension:

| Grade | Score | Action |
|-------|-------|--------|
| A | 90+ | No action required |
| B | 80-89 | Monitor; address LOW findings in next sprint |
| C | 70-79 | Schedule remediation within 2 weeks |
| D | 60-69 | Remediate before G Mining review |
| F | <60 | Block G Mining review; escalate to engineering lead |

---

## Delta Scoring

When a previous audit JSON is provided (`--compare`):

```
delta = current_score − previous_score
trend = ↑ (positive) | → (unchanged ±2) | ↓ (negative)
```

Report highlights:
- New findings introduced since last audit (regression)
- Findings resolved since last audit (improvement)
- Dimensions with largest delta (positive or negative)

A regression in CRITICAL or HIGH findings always triggers an AskUserQuestion regardless of overall delta direction.

---

## Audit Frequency Recommendations

| Environment | Full Audit | Quick Audit |
|-------------|-----------|-------------|
| Dev | Monthly | Each sprint |
| Staging | Bi-weekly | Each release candidate |
| Prod | Quarterly | Each prod deploy |
| Pre-G Mining review | Mandatory | N/A |
