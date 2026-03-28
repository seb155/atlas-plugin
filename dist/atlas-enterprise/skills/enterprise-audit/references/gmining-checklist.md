# G Mining Due Diligence Checklist

> What G Mining's technical auditors will specifically verify during enterprise review.
> Use this as the manual fallback when `toolkit.audit` is unavailable.
> Updated: 2026-03-19

---

## 1. Business Continuity

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| Bus factor | At least 2 engineers with full context on core subsystems | Commit history shows >1 contributor per critical module |
| Knowledge concentration | No single person holds all passwords/keys | Vault / secrets manager with shared access |
| Succession plan documented | `.blueprint/` contains onboarding guide | `ONBOARDING.md` or equivalent |
| Vendor dependency | No single vendor can unilaterally block operations | Contractual or technical mitigations documented |
| Backup developer access | G Mining can access codebase without AXOIQ | Forgejo repo access policy documented |

---

## 2. Regulatory Compliance

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| SOC2 readiness | At least 60% of CC6 controls addressed | Security audit report, RBAC config |
| PIPEDA compliance | No Canadian personal data stored without consent mechanism | Data classification map, privacy policy reference |
| Data residency | Engineering data stays in Canada (or G Mining-approved region) | Infra map, cloud region config |
| Audit trail | All data mutations logged with user + timestamp | DB audit log schema, sample query |
| Data retention policy | Defined and documented (production data lifecycle) | `.blueprint/` or admin config |

---

## 3. Scalability Evidence

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| Load testing performed | Results documented (target: 50+ concurrent users) | Load test report or `.blueprint/perf-benchmarks.md` |
| Concurrent user benchmark | Response times acceptable under realistic load | Benchmark numbers in docs |
| DB index strategy | Indexes exist for high-frequency queries | `\d+` output or migration files with index declarations |
| Cache layer documented | Strategy defined (Valkey/Redis usage patterns) | Architecture doc, cache key conventions |
| Horizontal scale path | Architecture supports adding nodes without re-architecture | ADR or `.blueprint/SCALABILITY.md` |

---

## 4. IP Clean Room

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| OSS license audit | No GPL/AGPL contamination in core proprietary modules | `pip-audit` + `bun audit` + license report |
| No vendor lock-in (hard) | Can migrate off any single vendor in <90 days | Architecture decision records |
| IP ownership documented | AXOIQ owns all custom code; no contractor IP ambiguity | Contract references or IP assignment docs |
| No unlicensed assets | All fonts, icons, imagery are licensed for commercial use | Asset inventory with license tags |
| No reverse-engineered code | No decompiled or obfuscated third-party code embedded | Code review, no `# decompiled` or similar markers |

---

## 5. Data Portability

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| Standard export formats | Engineering data exportable as Excel, PDF, CSV | Export endpoints documented, tested |
| Full data dump available | Admin can export complete project dataset | `pg_dump` procedure documented, tested |
| Import round-trip | Exported data can be re-imported without loss | Import/export test exists or is documented |
| No proprietary-only storage | No data stored exclusively in non-portable binary format | Architecture review |
| API export documented | REST endpoints return structured data (JSON/CSV) | OpenAPI spec available |

---

## 6. SLA Definition

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| RTO defined | Recovery Time Objective documented (target: <4h prod) | `.blueprint/` or ops runbook |
| RPO defined | Recovery Point Objective documented (target: <1h prod) | Backup schedule + DB PITR config |
| Uptime target | SLA percentage defined (target: 99.5% prod) | Monitoring dashboard or SLA doc |
| Incident response plan | Escalation path documented | Runbook or `.blueprint/INCIDENT-RESPONSE.md` |
| Planned maintenance window | Defined and communicated | Config or operational calendar |

---

## 7. Incident History

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| Incident log exists | All production incidents recorded | `.blueprint/_audit-history/incidents.md` or equivalent |
| Post-mortems written | P0/P1 incidents have root cause analysis | Post-mortem docs |
| MTTR tracked | Mean time to recovery calculated | Incident log with timestamps |
| Regression prevention | Each incident led to a fix or mitigation | Commit or ticket references in post-mortem |
| No recurring incidents | Same root cause not appearing 3+ times | Incident pattern analysis |

---

## 8. Third-Party Dependency Risk

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| Dependency inventory | All dependencies listed with versions | `requirements.txt`, `package.json` committed |
| Critical deps identified | Top 5 dependencies by blast radius flagged | Dependency map or comment in CLAUDE.md |
| CVE monitoring active | Automated scan in CI pipeline | CI config shows `pip-audit` / `bun audit` step |
| Abandoned dep detection | No dependency with last release >2 years (HIGH) | Audit report |
| License compatibility | All licenses compatible with commercial deployment | License report |

---

## 9. Code Ownership

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| Commit history clarity | Authors identifiable, commit messages follow convention | `git log --oneline -50` |
| CODEOWNERS or equivalent | Ownership mapped for critical modules | `CODEOWNERS` file or `.blueprint/MODULES.md` |
| No orphaned modules | Every module has at least one recent contributor | `git log --follow` per critical file |
| Code review evidence | PRs show review activity (not self-merge) | Forgejo PR history |
| Convention consistency | Single style enforced (Biome/ruff) with CI gate | CI config, pre-commit config |

---

## 10. Upgrade Path

| Check | Pass Criteria | Evidence Required |
|-------|--------------|-------------------|
| Migration strategy documented | Schema changes use versioned migrations | Alembic migration files, sequential numbering |
| Zero-data-loss migrations | Tested rollback path for each migration | Migration tests or documented procedure |
| Major version upgrade plan | Upgrade path exists for Python, Node, PostgreSQL | `.blueprint/UPGRADE-PLAN.md` or equivalent |
| Blue/green or rolling deploy | No hard downtime required for upgrades | Deployment config, compose file strategy |
| Data backup before deploy | Automated pre-deploy backup in CI/CD pipeline | Deploy script or CI config shows backup step |

---

## Audit Readiness Summary

Before scheduling a G Mining technical review, the following must all be true:

```
[ ] Overall enterprise audit grade: B or higher (≥80/100)
[ ] Zero open CRITICAL findings
[ ] All HIGH findings have a documented owner + remediation date
[ ] SOC2 CC6 controls at least 60% addressed
[ ] SLA (RTO/RPO) documented and tested
[ ] Full data export tested within last 30 days
[ ] Incident log current (updated within last 90 days)
[ ] License audit clean (no GPL contamination)
[ ] Load test results available (<90 days old)
[ ] Migration rollback tested
```
