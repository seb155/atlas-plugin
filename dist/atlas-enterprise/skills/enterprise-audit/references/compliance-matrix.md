# Enterprise Compliance Matrix

> Maps audit dimensions and checks to industry compliance frameworks.
> Use this to demonstrate G Mining that Synapse covers enterprise controls.

## SOC2 Type II — Trust Service Criteria

### Security (CC6)

| Control | Description | Audit Checks | Priority |
|---------|-------------|--------------|----------|
| CC6.1 | Logical access controls | SEC-001..005, MT-003, API-002 | CRITICAL |
| CC6.2 | User provisioning/deprovisioning | MT-005, MT-007, SEC-018 | HIGH |
| CC6.3 | Role changes tracked | SEC-018, DAT-005 | HIGH |
| CC6.6 | External threat protection | SEC-007, SEC-008, SEC-015, DPH-001 | CRITICAL |
| CC6.7 | Data transmission security | SEC-020, DEP-011 | HIGH |
| CC6.8 | Prevention of unauthorized changes | DAT-001, DEP-012, DEP-013 | CRITICAL |

### Availability (A1)

| Control | Description | Audit Checks | Priority |
|---------|-------------|--------------|----------|
| A1.1 | Processing capacity | PERF-004, OPS-011, PERF-006 | MEDIUM |
| A1.2 | Environmental safeguards | DEP-002, DEP-007, OPS-001 | HIGH |
| A1.3 | Recovery procedures | DAT-002, DAT-014, DAT-015, GOV-005 | CRITICAL |

### Processing Integrity (PI1)

| Control | Description | Audit Checks | Priority |
|---------|-------------|--------------|----------|
| PI1.2 | Completeness of processing | DAT-003, DAT-013, MT-001 | HIGH |
| PI1.3 | Timely processing | OPS-001, OPS-002, OPS-005 | MEDIUM |
| PI1.4 | Accuracy of processing | DAT-005, DAT-010, CQ-010 | MEDIUM |

### Confidentiality (C1)

| Control | Description | Audit Checks | Priority |
|---------|-------------|--------------|----------|
| C1.1 | Confidential information identified | SEC-010, SEC-019, DPH-008 | CRITICAL |
| C1.2 | Disposal of confidential info | DAT-004 | MEDIUM |

### Privacy (P)

| Control | Description | Audit Checks | Priority |
|---------|-------------|--------------|----------|
| P1.1 | Privacy notice | DOC-005 (SECURITY.md) | HIGH |
| P6.1 | Consent and data isolation | MT-001..008 | CRITICAL |

## ISO 27001:2022 — Selected Controls

| Control | Description | Audit Checks |
|---------|-------------|--------------|
| A.5.15 | Access control | SEC-001..005, API-002, MT-003 |
| A.8.9 | Configuration management | DEP-003, DEP-009, OPS-012 |
| A.8.24 | Use of cryptography | SEC-003, SEC-020 |
| A.8.25 | Secure development lifecycle | CQ-001..012, TST-001..012 |
| A.8.28 | Secure coding | SEC-008, SEC-014, CQ-004 |
| A.8.31 | Separation of environments | DEP-003, DEP-011 |

## PIPEDA / Privacy (Canadian)

| Principle | Audit Checks | Notes |
|-----------|--------------|-------|
| Accountability | GOV-001, DOC-005 | Privacy officer, disclosure policy |
| Consent | MT-001..008 | Data isolation per tenant |
| Limiting collection | SEC-019 | No PII in logs |
| Safeguards | SEC-001..025 | Full security dimension |
| Openness | DOC-001..010 | Documentation completeness |
| Individual access | GOV-004 | Data export/portability |

## Coverage Summary

| Framework | Controls Mapped | Coverage |
|-----------|----------------|----------|
| SOC2 Type II | 14/17 TSC controls | ~82% |
| ISO 27001:2022 | 6/93 Annex A controls | ~6% (security subset) |
| PIPEDA | 6/10 principles | ~60% |

**Note**: Full SOC2/ISO compliance requires organizational controls (policies, training, vendor management) beyond what code audit covers. This matrix addresses the **technical controls** only.
