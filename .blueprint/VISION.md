# ATLAS Plugin — Strategic Vision

> Context document for AI sessions working on the plugin. Covers the broader AXOIQ ecosystem,
> Synapse platform concepts, and the enterprise mega plan that this plugin supports.
>
> **Key principle**: ATLAS Plugin = GENERIC (works for any company). AXOIQ = reference preset.

---

## AXOIQ Ecosystem

AXOIQ is a tech company building AI-powered engineering tools for mining capital projects.
ATLAS Plugin is the AI co-developer layer that accelerates development across all products.

| # | Product | Status | Relationship to ATLAS | Mega Plan |
|---|---------|--------|----------------------|-----------|
| 1 | **ATLAS Plugin** | v3.18+ ✅ | **THIS REPO** — generic AI co-dev | SP-11 |
| 2 | **Synapse Platform** | Active ✅ | Primary consumer — mining engineer workspace | Core |
| 3 | **Enterprise Hub** | P1-P6 ✅ | Corporate intelligence — uses plugin skills | SP-08 |
| 4 | **SynapseCAD** | Active ✅ | Automated I&C drawing engine | SP-07 |
| 5 | **@axoiq/atlas-workspace** | P1-P3 ✅ | AI chat + Excalidraw + Terminal | — |
| 6 | **IaC Developer Platform** | P1-P4 ✅ | Infra automation — uses infrastructure-ops | SP-12 |
| 7 | **Cloud Portal** | Planned | cloud.axoiq.com — centralized workspace | SP-03 |
| 8 | **Process Simulation** | Planned | Mass balance, equipment sizing | SP-09 |
| 9 | **Mine Optimizer** | Planned | NPV/IRR/Monte Carlo scenarios | SP-09 |
| 10 | **3D Visualization** | Merged ✅ | React Three Fiber — Nexus integration | SP-05 |
| 11 | **Document Control** | Planned | Versioned engineering deliverables | SP-10 |
| 12 | **Construction Tracking** | Planned | Installation, punchlist, handover | SP-10 |
| 13 | **Knowledge Management** | Planned | RAG + tacit capture + mobile field | SP-02 |
| 14 | **Digital Twin** | Planned | 3D + IoT + predictive maintenance | SP-05 |

**Plugin stays generic**: No AXOIQ-specific URLs hardcoded. Company presets live in `~/.atlas/config.json`.

---

## Synapse Core Concepts

Synapse = **mining engineer's digital workspace** (replaces Excel + P6 + AVEVA + SAP).
Understanding these concepts helps when building skills that touch Synapse workflows.

### Engineering Chain (Material-First)
```
IMPORT → CLASSIFY → ENGINEER → SPEC GROUP → E-BOM → PROCURE → ESTIMATE → OUTPUTS
```
**Rule**: `PACKAGES → MATERIAL → ACTIVITIES → HOURS → COSTS`. Hours/costs are NEVER pre-calculated.

### Part Lifecycle
```
G-Part (generic) → E-Part (engineered) → M-Part (material) → I-Part (installed) → S-Part (spare)
```

### MBSE 4-Layer Model
| Layer | Question | DB Table | Purpose |
|-------|----------|----------|---------|
| QUOI | What material? | `material_catalog` | Material database |
| OÙ | Where used? | `package_material_rules` | Package assignment rules |
| COMMENT | How presented? | `frm_item_presentation` | FRM/BOM formatting |
| QUI | Which instrument? | `instruments` | ISA-20 instrument instances |

### Multi-Discipline (8 planned)
| # | Discipline | Status | Standard |
|---|-----------|--------|----------|
| 1 | I&C (Instrumentation & Controls) | ✅ Active | ISA 5.1/88/95 |
| 2 | Electrical | Planned (SP-04) | IEC 60617 |
| 3 | Mechanical | Planned (SP-04) | ASME |
| 4 | Process | Planned (SP-04) | ISA 5.1 |
| 5 | Piping | Planned (SP-04) | ASME B31 |
| 6 | Civil/Structural | Planned (SP-04) | ACI/AISC |
| 7 | Mining | Planned (SP-04) | CIM |
| 8 | Controls/Automation | Planned (SP-04) | IEC 61131 |

### 3-Tier Rule Inheritance
```
ISA 5.1 (global standard) → Company overrides → Project overrides
```
New client = YAML import, zero code changes.

---

## Enterprise Mega Plan 2026-2029

12+1 sub-plans, **2,582h**, 7 phases, **46 HITL gates**.
Plugin is Phase 0 tooling (SP-11) — everything else depends on it.

```
Phase 0 ─── SP-00 (Stack 70h) + SP-11 (Plugin 50h) + SP-12 (IaC 72h)
  │
Phase 1 ─── SP-06 (Enterprise Platform 200h) + SP-08 (Hub 80h)
  │
Phase 2 ─── SP-01 (AI SOTA 540h)
  │
Phase 3 ─── SP-04 (Multi-Discipline 300h) + SP-02 (Knowledge 400h)
  │
Phase 4 ─── SP-07 (SynapseCAD 150h) + SP-09 (Process Sim 150h)
  │
Phase 5 ─── SP-05 (Digital Twin 250h) + SP-10 (Construction 120h)
  │
Phase 6 ─── SP-03 (Unified Ecosystem 200h) ← capstone
```

**HITL Gates**: G1 (Design ≥12/15) → G2 (50% + demo) → G3 (E2E + security) → G4 (All Tier 2+)

---

## Atlas AI SOTA (SP-01, 540h)

The most ambitious sub-plan — building a self-improving AI engineering assistant.

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Working Memory | 200K token context | Current session state |
| Episodic Memory | Zep Cloud, 90-day TTL | Cross-session learning |
| Semantic Memory | ParadeDB pgvector | Domain knowledge retrieval |
| Procedural Memory | Tool/skill registry | How-to knowledge |
| Flywheel | MAPE-K loop | Monitor→Analyze→Plan→Execute→Knowledge |
| Multi-Agent | Claude Agent SDK + A2A + MCP | Orchestrated agent workflows |
| Self-Improvement | SICA scaffold editing | Prompt/tool optimization (no weight mods) |
| Eval Suite | LLM-as-Judge + HITL sampling | Quality regression detection |

**Plugin relevance**: Skills like `experiment-loop`, `knowledge-builder`, `session-retrospective` are building blocks for this system.

---

## Digital Twin Infrastructure (SP-05, 250h)

| Component | Technology | Plugin Skills |
|-----------|-----------|---------------|
| 3D Visualization | React Three Fiber | — |
| IoT Feeds | OPC UA / MQTT | `infrastructure-ops` |
| Predictive Maintenance | ML models | `experiment-loop` |
| Operator Feedback | Mobile PWA | — |

---

## Enterprise Platform (SP-06, 200h)

| Feature | Current | Target | Plugin Skills |
|---------|---------|--------|---------------|
| Auth | JWT local | Keycloak OIDC (Q3 2026) | `security-audit` |
| RBAC | Basic roles | Role + project + discipline | `enterprise-audit` |
| Multi-Tenant | project_id filter | Full tenant isolation | `enterprise-audit` |
| Collaboration | — | Yjs CRDT (Q4 2026) | — |
| Offline | — | Tauri desktop (Q4 2026) | — |

---

## Business Context

| Dimension | Detail |
|-----------|--------|
| Client anchor | G Mining (Eldorado Gold) — Perama Hill THM-012 FEL3 I&C |
| Revenue model | SaaS Synapse + AI consulting (150-250$/h) |
| Reference projects | BRTZ, CAJB, FORAN, GOYW-OKO, GYOW (CAGM = template) |
| Subventions | SR&ED (35%) + CRIC QC (30%) + IRAP (50-200K$) |

### 8 Personas → Plugin Skill Mapping

| Persona | Key Plugin Skills |
|---------|------------------|
| I&C Engineer | `engineering-ops`, `tdd`, `systematic-debugging` |
| Electrical Engineer | `engineering-ops`, `plan-builder` (future SP-04) |
| Project Manager | `feature-board`, `document-generator`, `morning-brief` |
| Procurement | `enterprise-audit`, `document-generator` |
| Admin/IT | `infrastructure-ops`, `security-audit`, `devops-deploy` |
| Client | `user-profiler`, `deep-research` |
| AI Developer | `experiment-loop`, `knowledge-builder`, `atlas-dev-self` |
| Plugin Developer | `skill-management`, `plugin-builder`, `atlas-dev-self` |

---

*Updated: 2026-03-22 | SSoT for AXOIQ vision context in plugin sessions*
