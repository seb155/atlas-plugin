# SOC2 Trust Service Criteria Mapping

## Security (CC6)
| Control | Audit Check(s) | Status |
|---------|---------------|--------|
| CC6.1 Logical access | SEC-001..005, MT-003, API-002 | Review auth + RBAC |
| CC6.2 User access provisioning | MT-005, MT-007 | UserProject + admin override |
| CC6.3 Role changes | MT-007, SEC-018 | Audit logging on mutations |
| CC6.6 External threats | SEC-007, SEC-008, SEC-015 | Headers, SQL injection, CVEs |
| CC6.7 Data transmission | SEC-020 | HTTPS enforcement |
| CC6.8 Unauthorized changes | DAT-001, DEP-013 | Migration integrity, deploy gates |

## Availability (A1)
| Control | Audit Check(s) | Status |
|---------|---------------|--------|
| A1.1 Processing capacity | PERF-004, OPS-011 | DB indexes, connection pooling |
| A1.2 Environmental safeguards | DEP-002, DEP-007 | Healthchecks, health endpoints |
| A1.3 Recovery procedures | DAT-002, DAT-014, DAT-015 | Backup, strategy, restore docs |

## Processing Integrity (PI1)
| Control | Audit Check(s) | Status |
|---------|---------------|--------|
| PI1.2 Completeness | DAT-003, DAT-013 | FK constraints, enum consistency |
| PI1.3 Timeliness | OPS-001, OPS-002 | Structured logging, correlation IDs |
| PI1.4 Accuracy | DAT-005, DAT-010 | Versioning, config validation |

## Confidentiality (C1)
| Control | Audit Check(s) | Status |
|---------|---------------|--------|
| C1.1 Confidential info | SEC-010, SEC-019 | No secrets in compose, no PII in logs |
| C1.2 Disposal | DAT-004 | Soft delete pattern |

## Privacy
| Control | Audit Check(s) | Status |
|---------|---------------|--------|
| P1.1 Notice | DOC-005 | SECURITY.md (responsible disclosure) |
| P6.1 Consent | MT-001..008 | Multi-tenant isolation |
