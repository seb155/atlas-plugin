# ATLAS Skill Catalog

> Browsable registry of all 48 skills, 6 agents, and 5 references.
> Regenerate: scan `skills/*/SKILL.md` frontmatter. Last updated: 2026-03-22.

---

## Summary

| Category | Count |
|----------|-------|
| Skills (directories) | 48 |
| References | 5 |
| Agents | 6 |
| **Total components** | **59** |

| Tier | Skills | Agents | Refs | Persona |
|------|--------|--------|------|---------|
| user | 14 | 1 | 2 | helpful assistant |
| dev | +18 (=32) | +5 (=6) | +3 (=5) | senior engineering architect |
| admin | +13 (=45) | — | — | infrastructure architect |
| unassigned | 3 | — | — | — |

*atlas-assist is generated per tier, not in profiles.*

---

## Complete Skill Table

| # | Skill | Tier | Category | Emoji | Effort | Command |
|---|-------|------|----------|-------|--------|---------|
| 1 | atlas-assist | gen | Meta | 🏛️ | — | `/atlas` |
| 2 | atlas-dev-self | admin | Meta | 🔁 | high | `/dev-self` |
| 3 | atlas-doctor | user | Meta | 🩺 | medium | `/doctor` |
| 4 | atlas-location | user | Meta | 📍 | low | `/location` |
| 5 | atlas-onboarding | user | Meta | 👋 | high | `/setup` |
| 6 | atlas-vault | admin | Security | 🔐 | medium | `/vault` |
| 7 | brainstorming | dev | Planning | 💡 | high | `/brainstorm` |
| 8 | browser-automation | user | Meta | 🌐 | low | `/browse` |
| 9 | code-analysis | admin | Quality | 🔎 | medium | — |
| 10 | code-review | dev | Quality | 🔍 | high | `/review` |
| 11 | code-simplify | dev | Quality | ✨ | low | `/simplify` |
| 12 | context-discovery | user | Planning | 🔭 | medium | `/context` |
| 13 | decision-log | dev | Meta | 📋 | low | — |
| 14 | deep-research | user | Knowledge | 📚 | high | `/research` |
| 15 | devops-deploy | admin | Deploy | 🎯 | medium | `/deploy` |
| 16 | document-generator | user | Knowledge | 📄 | medium | `/present` |
| 17 | engineering-ops | dev | Optimize | ⚙️ | high | `/eng` |
| 18 | enterprise-audit | admin | Governance | 🏢 | high | `/audit-enterprise` |
| 19 | executing-plans | dev | Implement | ⚡ | medium | — |
| 20 | experiment-loop | admin | Optimize | 🧬 | high | `/tune` |
| 21 | feature-board | admin | Project | 📌 | low | `/board` |
| 22 | finishing-branch | dev | Ship | 📦 | medium | `/ship` |
| 23 | frontend-design | dev | Planning | 🎨 | medium | `/design` |
| 24 | frontend-workflow | — | Planning | 🎨 | high | — |
| 25 | git-worktrees | dev | Implement | 🌿 | low | — |
| 26 | hookify | dev | Meta | 🪝 | medium | `/hooks` |
| 27 | infrastructure-ops | admin | Infra | 🔧 | high | `/infra` |
| 28 | knowledge-builder | user | Personal | 🧠 | medium | `/learn` |
| 29 | knowledge-manager | admin | Knowledge | 📖 | medium | `/knowledge` |
| 30 | morning-brief | user | Personal | ☀️ | low | `/brief` |
| 31 | note-capture | user | Personal | 📝 | low | `/notes` |
| 32 | plan-builder | dev | Planning | 🏗️ | high | `/plan` |
| 33 | plan-review | admin | Planning | 🏗️ | high | `/review-plan` |
| 34 | platform-update | admin | Meta | 🆙 | medium | `/update` |
| 35 | plugin-builder | dev | Meta | 🔌 | medium | — |
| 36 | reminder-scheduler | user | Personal | ⏰ | low | `/remind` |
| 37 | scope-check | user | Meta | 🛡️ | low | `/scope` |
| 38 | security-audit | admin | Security | 🔐 | high | `/audit` |
| 39 | session-retrospective | dev | Meta | 🔄 | low | `/end` |
| 40 | skill-management | dev | Meta | 🧩 | low | `/skill` |
| 41 | statusline-setup | admin | Infra | 📟 | low | — |
| 42 | subagent-dispatch | dev | Implement | 🤖 | medium | — |
| 43 | systematic-debugging | dev | Quality | 🔬 | medium | `/debug` |
| 44 | tdd | dev | Implement | 🧪 | medium | `/tdd` |
| 45 | test-orchestrator | — | Quality | 🧪 | — | — |
| 46 | user-profiler | user | Personal | 👤 | medium | `/profile` |
| 47 | verification | dev | Quality | 📊 | medium | `/verify` |
| 48 | youtube-transcript | user | Knowledge | 🎬 | — | `/transcript` |

---

## By Category

### 🏗️ Planning (5 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| brainstorming | dev | Collaborative design exploration. 1 question at a time. 2-3 approaches. HITL approval |
| context-discovery | user | Auto-scan project context + CLAUDE.md audit + codemap generation |
| frontend-design | dev | Distinctive, production-grade UI/UX implementation |
| frontend-workflow | — | 6-phase iterative UX development (NEW) |
| plan-builder | dev | Generate ultra-detailed 15-section plans (A-O) with quality gate 12/15 |
| plan-review | admin | Review plans against 15 criteria. Gate: 12/15 |

### ⚡ Implementation (4 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| executing-plans | dev | Load plan → TaskCreate per step → execute with subagents |
| git-worktrees | dev | Isolated branch per feature. Forgejo-native |
| subagent-dispatch | dev | Dispatch Sonnet subagents per task. 2-stage review |
| tdd | dev | Failing test → minimal impl → pass → commit |

### 📊 Quality (6 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| code-analysis | admin | Dead code, dependency graphs, dataflow tracing |
| code-review | dev | Review PR/diffs with confidence filtering |
| code-simplify | dev | Refactoring for clarity and maintainability |
| systematic-debugging | dev | Observe → hypothesize → test → fix (max 2 attempts) |
| test-orchestrator | — | Test pyramid orchestration (NEW) |
| verification | dev | L1-L6 tests + security + perf benchmarks |

### 📚 Knowledge (4 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| deep-research | user | Multi-query decomposition → search → triangulate → synthesize |
| document-generator | user | Generate PPTX/DOCX/XLSX with storytelling and layouts |
| knowledge-manager | admin | Enterprise knowledge layer — coverage, discovery, search |
| youtube-transcript | user | Extract YouTube video transcripts to timestamped markdown |

### 🎯 Deploy (1 skill)
| Skill | Tier | Purpose |
|-------|------|---------|
| devops-deploy | admin | Deploy orchestration with health checks and validators |

### 📦 Ship (1 skill)
| Skill | Tier | Purpose |
|-------|------|---------|
| finishing-branch | dev | Commit + push + PR + CI + cleanup (conventional commits) |

### 🔧 Infrastructure (2 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| infrastructure-ops | admin | VM/container orchestration, networking, monitoring |
| statusline-setup | admin | Configure CShip + Starship status line |

### 🔐 Security (2 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| atlas-vault | admin | Ingest user vault for personalized behavior |
| security-audit | admin | OWASP scanning, RBAC audit, vulnerability assessment |

### 🏢 Governance (1 skill)
| Skill | Tier | Purpose |
|-------|------|---------|
| enterprise-audit | admin | 14-dimension enterprise readiness audit |

### ⚙️ Optimize (2 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| engineering-ops | dev | I&C maintenance + 4-agent estimation pipeline |
| experiment-loop | admin | Autonomous optimization (Karpathy autoresearch) |

### 📌 Project (1 skill)
| Skill | Tier | Purpose |
|-------|------|---------|
| feature-board | admin | Feature registry dashboard — kanban + validation matrix |

### 👤 Personal (5 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| knowledge-builder | user | Learn facts/preferences/relationships |
| morning-brief | user | Compile daily brief — agenda + tasks + suggestions |
| note-capture | user | Quick capture notes with tags and context |
| reminder-scheduler | user | Schedule reminders via CronCreate |
| user-profiler | user | Build and display user's complete profile |

### 🛡️ Meta (11 skills)
| Skill | Tier | Purpose |
|-------|------|---------|
| atlas-assist | gen | Master routing skill (generated per tier) |
| atlas-dev-self | admin | Self-development workflow for the plugin itself |
| atlas-doctor | user | System health check (8 categories, auto-fix) |
| atlas-location | user | Location profiles, WiFi trust, security adaptation |
| atlas-onboarding | user | Guided 5-phase setup wizard |
| browser-automation | user | E2E testing and visual QA |
| decision-log | dev | Log architectural decisions to .claude/decisions.jsonl |
| hookify | dev | Create hooks from conversation patterns |
| platform-update | admin | SOTA audit + auto-update for plugin + CC environment |
| plugin-builder | dev | Build Claude Code plugins from scratch |
| scope-check | user | Detect drift — working outside original scope? |
| session-retrospective | dev | End-of-session lessons + close + handoff |
| skill-management | dev | Create, improve, benchmark skills |

---

## Agent Registry

| Agent | Model | Tier | Purpose | Used By Skills |
|-------|-------|------|---------|----------------|
| context-scanner | haiku | user | CLAUDE.md staleness + gaps audit | context-discovery |
| plan-architect | opus | dev | Ultra-detailed 15-section plans | plan-builder |
| plan-reviewer | sonnet | dev | Score plans against 15 criteria | plan-review |
| code-reviewer | sonnet | dev | PR/diff review + CLAUDE.md compliance | code-review |
| design-implementer | sonnet | dev | Wireframes → React/TypeScript components | frontend-design |
| experiment-runner | sonnet | dev | Autonomous loop: analyze→mutate→test→decide | experiment-loop |

---

## Reference Registry

| Ref | Tier | Purpose |
|-----|------|---------|
| atlas-visual-identity | user | Hook badges, persona headers, emoji maps |
| web-design-guidelines | user | A11y, responsive, typography, colors |
| composition-patterns | dev | React compound components, explicit variants |
| gmining-excel | dev | FRM/LST/TBE formats, openpyxl styles |
| react-best-practices | dev | Re-render prevention, server components |

---

## Skill → Mega Plan Mapping

Which plugin skills support which enterprise sub-plans:

| Sub-Plan | Phase | Skills That Support It |
|----------|-------|----------------------|
| SP-00 Stack Remediation | P0 | verification, code-analysis, systematic-debugging |
| SP-11 Plugin System | P0 | plan-builder, executing-plans, atlas-dev-self, skill-management |
| SP-12 IaC Platform | P0 | infrastructure-ops, devops-deploy, security-audit |
| SP-06 Enterprise Platform | P1 | enterprise-audit, security-audit, code-review |
| SP-08 Enterprise Hub | P1 | feature-board, document-generator, knowledge-manager |
| SP-01 AI SOTA | P2 | experiment-loop, knowledge-builder, deep-research |
| SP-02 Knowledge Digitalization | P3 | knowledge-manager, deep-research, document-generator |
| SP-04 Multi-Discipline | P3 | engineering-ops, plan-builder, tdd |
| SP-07 SynapseCAD | P4 | code-analysis, tdd, verification |
| SP-09 Process Simulation | P4 | experiment-loop, engineering-ops |
| SP-05 Digital Twin | P5 | infrastructure-ops, experiment-loop |
| SP-10 Construction | P5 | feature-board, verification |
| SP-03 Unified Ecosystem | P6 | ALL skills (capstone integration) |

---

*Updated: 2026-03-22 | Maintain when: skill added, removed, or reassigned to different tier*
