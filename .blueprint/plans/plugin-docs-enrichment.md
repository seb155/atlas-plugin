# Plan: Enrichir la Documentation du Repo ATLAS Plugin

> **Objectif**: Intégrer la vision complète (Enterprise, Digital Twin, Synapse, Atlas AI, AXOIQ) dans la documentation du repo ATLAS Plugin pour que chaque session AI ait le contexte stratégique nécessaire.
>
> **Score actuel**: AI Maintainability 6/10 → **Cible 9/10**
> **Effort**: ~16h (4 phases, 4-5 sessions)
>
> **Repo cible**: `/home/sgagnon/workspace_atlas/projects/atlas-dev-plugin/`
> **Plan SSoT**: Le plan d'exécution vivra dans `atlas-dev-plugin/.blueprint/plans/` (créé en Phase 0)
> **Lien mega plan**: Ce plan correspond à **SP-11** du mega plan Synapse. Un pointeur sera ajouté dans `sp11-atlas-plugin-mega.md`.
> **Ce fichier**: Design doc de référence dans Synapse — l'exécution se fait depuis le repo plugin.

---

## A. Context

Le repo ATLAS Plugin (`/home/sgagnon/workspace_atlas/projects/atlas-dev-plugin/`) est **bien architecturé** (3-tier, 49 skills, 6 agents, 45 commands) mais **sous-documenté** pour la maintenance AI :

| Gap | Impact | Priorité |
|-----|--------|----------|
| Zéro `.blueprint/` | AI ne peut pas lazy-load le contexte détaillé | P0 |
| Zéro mémoire projet | Zéro apprentissage cross-session | P0 |
| Zéro vision stratégique | AI ignore l'écosystème AXOIQ 19 produits | P0 |
| Zéro intégration mapping | AI ignore les connexions Synapse↔Hub↔Cloud | P1 |
| Zéro catalog skills | AI scanne 49 répertoires pour trouver un skill | P1 |
| Counts obsolètes dans CLAUDE.md | ~40 skills (réel: 49), ~37 cmds (réel: 45) | P1 |
| Zéro rules enterprise | AI manque le contexte domaine AXOIQ | P2 |
| Zéro test strategy doc | AI devine les patterns de test | P2 |

---

## B. Inventaire des fichiers

### À CRÉER (10 fichiers)

| # | Fichier | Repo | Lignes | Phase |
|---|---------|------|--------|-------|
| 1 | `.blueprint/INDEX.md` | plugin | ~50 | P0 |
| 2 | `.blueprint/VISION.md` | plugin | ~100 | P0 |
| 3 | `.blueprint/ARCHITECTURE.md` | plugin | ~80 | P0 |
| 4 | `memory/MEMORY.md` | CC project¹ | ~40 | P0 |
| 5 | `.blueprint/SKILL-CATALOG.md` | plugin | ~120 | P1 |
| 6 | `.blueprint/PATTERNS.md` | plugin | ~80 | P1 |
| 7 | `.blueprint/INTEGRATION-MAP.md` | plugin | ~70 | P2 |
| 8 | `.blueprint/TESTING.md` | plugin | ~60 | P2 |
| 9 | `.claude/rules/enterprise-context.md` | plugin | ~35 | P2 |
| 10 | `.claude/rules/performance.md` | plugin | ~25 | P2 |

¹ CC project memory = `~/.claude/projects/-home-sgagnon-workspace-atlas-projects-atlas-dev-plugin/memory/`

### À MODIFIER (1 fichier)

| Fichier | Changements | Phase |
|---------|-------------|-------|
| `CLAUDE.md` | +Lazy-load table, +COMPACTION section, fix counts, +memory pointer | P0+P3 |

---

## C. Architecture des documents

### `.blueprint/INDEX.md` — Navigation Hub (Pattern Synapse)

```markdown
# .blueprint/ Documentation Index
> Tier 1 = always relevant, Tier 2 = on-demand

| T | File | Role — Maintain When |
|:-:|------|---------------------|
| 1 | VISION.md | AXOIQ ecosystem + Synapse integration — strategy change |
| 1 | ARCHITECTURE.md | Build system, inheritance, CI/CD — build change |
| 1 | SKILL-CATALOG.md | All 49 skills registry + dependencies — skill added/removed |
| 1 | PATTERNS.md | Copy-paste templates for new skills/agents/hooks — pattern change |
| 2 | INTEGRATION-MAP.md | Plugin ↔ Synapse/Hub/Cloud connections — integration change |
| 2 | TESTING.md | Test strategy, pyramid, coverage — test change |
```

### `.blueprint/VISION.md` — Le document clé (vision complète)

```markdown
# ATLAS Plugin — Strategic Vision

## AXOIQ Ecosystem (19 Products)
Table: Product | Status | Relationship to ATLAS | Sub-plan
- ATLAS Plugin = GENERIC AI co-dev (public, any company)
- Synapse = mining engineer digital workspace
- Enterprise Hub = corporate intelligence
- SynapseCAD = automated drawing engine
- ... (15 more, table format)

## Synapse Core Concepts (pour context domaine)
- Engineering Chain: IMPORT→CLASSIFY→ENGINEER→SPEC→BOM→PROCURE→ESTIMATE→OUTPUTS
- Part Lifecycle: G→E→M→I→S-Part
- MBSE 4-layer: QUOI (catalog) / OÙ (rules) / COMMENT (presentation) / QUI (instruments)
- Material-First: PACKAGES→MATERIAL→ACTIVITIES→HOURS→COSTS
- 8 disciplines: I&C (actif) + EL, ME, Process, Piping, Civil, Mining, Controls
- Standards: ISA 5.1/88/95, IEC 81346, ISO 15926

## Enterprise Mega Plan 2026-2029
- ASCII dependency graph des 12+1 sub-plans
- SP-11 = CE plugin (Phase 0, 50h)
- 2,582h total, 7 phases, 46 HITL gates

## Atlas AI SOTA (SP-01, 540h)
- 4-tier memory: Working + Episodic + Semantic + Procedural
- MAPE-K flywheel: Monitor→Analyze→Plan→Execute→Knowledge
- Multi-agent: Claude Agent SDK + A2A + MCP
- Self-improvement: SICA scaffold editing
- Eval suite: LLM-as-Judge + HITL sampling

## Digital Twin Infrastructure (SP-05, 250h)
- React Three Fiber 3D viz
- IoT: OPC UA / MQTT sensor feeds
- Predictive maintenance loop
- Plugin skills: infrastructure-ops, experiment-loop

## Enterprise Platform (SP-06, 200h)
- Auth: JWT → Keycloak OIDC (Q3 2026)
- RBAC: role + project + discipline scoping
- Multi-tenant: project_id on every query
- Collaboration: Yjs CRDT (Q4 2026)

## Business Context
- Client anchor: G Mining (Eldorado Gold, Perama Hill THM-012)
- 8 personas mapping to plugin skills
- Revenue: SaaS + AI consulting
```

### `.blueprint/ARCHITECTURE.md` — Build system deep dive

```markdown
# ATLAS Plugin Architecture

## Build Pipeline (Mermaid diagram)
profiles/*.yaml → build.sh resolve_field() → dist/atlas-{tier}/ → make dev → CC cache

## Tier Inheritance
user (base) → dev (inherits user) → admin (inherits dev)
resolve_field() logic explained

## generate-master-skill.sh
How atlas-assist is dynamically built per tier with real counts

## CI/CD Pipeline
.forgejo/workflows/ → test → build → publish → auto-release

## Hook Lifecycle
Event → hooks.json matcher → async/sync → branded output

## Directory Structure (annotated tree)
```

### `.blueprint/SKILL-CATALOG.md` — Registre navigable

```markdown
# ATLAS Skill Catalog (49 skills)

## Summary Table
| # | Skill | Tier | Category | Emoji | Command | Agent? |
Table of all 49 skills with metadata

## By Category (grouped)
### Planning (brainstorming, context-discovery, frontend-design, plan-builder)
### Implementation (executing-plans, git-worktrees, subagent-dispatch, tdd)
### Quality (code-analysis, code-review, code-simplify, systematic-debugging, verification)
### Knowledge (deep-research, document-generator, knowledge-manager, youtube-transcript)
### DevOps (devops-deploy, finishing-branch)
### Infrastructure (infrastructure-ops, statusline-setup)
### Security (atlas-vault, security-audit)
### Meta (atlas-dev-self, atlas-doctor, hookify, platform-update, plugin-builder, scope-check, session-retrospective, skill-management, decision-log)
### Personal (knowledge-builder, morning-brief, note-capture, reminder-scheduler, user-profiler)
### Governance (enterprise-audit)
### Optimize (engineering-ops, experiment-loop)

## Agent Registry
| Agent | Model | Purpose |
6 agents with descriptions

## Skill→Synapse Mapping
Which skills support which mega plan sub-plans
```

### CLAUDE.md — Ajouts ciblés (+25 lignes max)

```markdown
## CONTEXT LOADING (Lazy)

| Need | Read |
|------|------|
| AXOIQ vision + Synapse context | `.blueprint/VISION.md` |
| Build system deep dive | `.blueprint/ARCHITECTURE.md` |
| Skill catalog (49 skills) | `.blueprint/SKILL-CATALOG.md` |
| Integration mapping | `.blueprint/INTEGRATION-MAP.md` |
| Copy-paste patterns | `.blueprint/PATTERNS.md` |
| Test strategy | `.blueprint/TESTING.md` |
| All docs index | `.blueprint/INDEX.md` |

## COMPACTION

Preserve: modified file paths, VERSION, branch, tier being built, test failures,
build.sh changes, skill frontmatter changes, hook additions.
SSoT = VERSION file. Always `make test` before commit.
```

Fix counts table:
```
| Skills | skills/*/SKILL.md | 49 (admin) |
| Commands | commands/*.md | 45 |
| Hooks | hooks/hooks.json | 9 |
| Tests | tests/test_*.py | 19 |
```

---

## D. Phases d'exécution

### Phase 0: Foundation (4h, 1 session) — **Depuis le repo atlas-dev-plugin**

| # | Tâche | Fichier (dans atlas-dev-plugin) | Vérification |
|---|-------|---------|-------------|
| 0.1 | Créer `.blueprint/` + `.blueprint/plans/` dirs | `mkdir -p .blueprint/plans` | `ls .blueprint/` |
| 0.2 | Copier ce plan dans le repo plugin | `.blueprint/plans/plugin-docs-enrichment.md` | Plan présent dans les deux repos |
| 0.3 | Écrire INDEX.md | `.blueprint/INDEX.md` | Tous fichiers listés |
| 0.4 | Écrire VISION.md | `.blueprint/VISION.md` | 19 produits, mega plan, AI SOTA, DT |
| 0.5 | Écrire ARCHITECTURE.md | `.blueprint/ARCHITECTURE.md` | Build pipeline documenté |
| 0.6 | Créer memory dir + MEMORY.md | CC project memory path | `ls` confirme |
| 0.7 | Update CLAUDE.md | `CLAUDE.md` | Lazy-load table ajoutée, counts fixés |
| 0.8 | Ajouter pointeur dans SP-11 Synapse | `sp11-atlas-plugin-mega.md` | Lien bidirectionnel confirmé |

### Phase 1: Skill Catalog + Patterns (4h, 1 session)

| # | Tâche | Fichier | Vérification |
|---|-------|---------|-------------|
| 1.1 | Scanner 49 skills (frontmatter) | lecture seule | Données collectées |
| 1.2 | Écrire SKILL-CATALOG.md | `.blueprint/SKILL-CATALOG.md` | 49 entries, by-category |
| 1.3 | Écrire PATTERNS.md | `.blueprint/PATTERNS.md` | 8 patterns couverts |
| 1.4 | Update INDEX.md | `.blueprint/INDEX.md` | Nouveaux fichiers ajoutés |

### Phase 2: Integration + Rules (4h, 1 session)

| # | Tâche | Fichier | Vérification |
|---|-------|---------|-------------|
| 2.1 | Écrire INTEGRATION-MAP.md | `.blueprint/INTEGRATION-MAP.md` | 6 points d'intégration |
| 2.2 | Écrire TESTING.md | `.blueprint/TESTING.md` | Pyramide + 19 test files |
| 2.3 | Écrire enterprise-context.md | `.claude/rules/enterprise-context.md` | Domaine AXOIQ couvert |
| 2.4 | Écrire performance.md | `.claude/rules/performance.md` | Hook/skill constraints |

### Phase 3: Polish + Verification (4h, 1 session)

| # | Tâche | Vérification |
|---|-------|-------------|
| 3.1 | CLAUDE.md: +COMPACTION, +memory pointer | `wc -l` < 200 |
| 3.2 | Cross-check: INDEX vs fichiers réels | Tous listés, zéro orphelin |
| 3.3 | Cross-check: SKILL-CATALOG vs `ls skills/` | 49 match |
| 3.4 | Cross-check: VISION vs Synapse mega plan | Alignement confirmé |
| 3.5 | Zéro hardcode AXOIQ URLs | `grep -r "axoiq.com" .blueprint/` = context only |
| 3.6 | Build + tests passent | `make test` vert |
| 3.7 | Commit + push | `git push origin dev` |

---

## E. Vérification end-to-end

```bash
# 1. Structure exists
ls /home/sgagnon/workspace_atlas/projects/atlas-dev-plugin/.blueprint/
# Expected: INDEX.md VISION.md ARCHITECTURE.md SKILL-CATALOG.md PATTERNS.md INTEGRATION-MAP.md TESTING.md

# 2. CLAUDE.md under budget
wc -l /home/sgagnon/workspace_atlas/projects/atlas-dev-plugin/CLAUDE.md
# Expected: < 200 lines

# 3. Rules exist
ls /home/sgagnon/workspace_atlas/projects/atlas-dev-plugin/.claude/rules/
# Expected: 6 files (4 existing + 2 new)

# 4. Memory bootstrapped
ls ~/.claude/projects/-home-sgagnon-workspace-atlas-projects-atlas-dev-plugin/memory/
# Expected: MEMORY.md

# 5. No hardcoded AXOIQ URLs (except contextual references)
grep -r "axoiq.com" /home/sgagnon/workspace_atlas/projects/atlas-dev-plugin/.blueprint/ | grep -v "contextual\|example\|vision"
# Expected: 0 matches or context-only

# 6. Build passes
cd /home/sgagnon/workspace_atlas/projects/atlas-dev-plugin && make test
# Expected: all green

# 7. Skill count matches catalog
ls skills/ | grep -v refs | wc -l
# Expected: matches SKILL-CATALOG.md count
```

---

## F. Impact attendu

| Dimension | Avant (6/10) | Après (9/10) | Gain |
|-----------|-------------|-------------|------|
| Onboarding session | Exploration manuelle | Lazy-load table | **3x plus rapide** |
| Découverte de skills | Scanner 49 dirs | SKILL-CATALOG table | **10x plus rapide** |
| Contexte cross-système | Zéro | VISION + INTEGRATION-MAP | **∞ (de rien à tout)** |
| Réutilisation patterns | Lire skills existants | PATTERNS templates | **2x plus rapide** |
| Mémoire cross-session | Aucune | MEMORY.md index | **Apprentissage persistant** |
| Awareness enterprise | Aucune | 2 rules files | **Contexte domaine** |
| Stratégie de test | Deviner | TESTING.md doc | **Guidance claire** |

---

## G. Cross-Repo Linking

```
atlas-dev-plugin/                          synapse/
├── .blueprint/                            ├── .blueprint/plans/
│   ├── INDEX.md                           │   ├── squishy-scribbling-parnas.md  ← CE FICHIER (design doc)
│   ├── VISION.md                          │   └── sp11-atlas-plugin-mega.md     ← pointeur ajouté (0.8)
│   ├── ARCHITECTURE.md                    │
│   ├── SKILL-CATALOG.md                   └── CLAUDE.md (inchangé)
│   ├── PATTERNS.md
│   ├── INTEGRATION-MAP.md
│   ├── TESTING.md
│   └── plans/
│       └── plugin-docs-enrichment.md  ← COPIE DU PLAN (exécution)
├── .claude/rules/
│   ├── enterprise-context.md (NEW)
│   └── performance.md (NEW)
├── CLAUDE.md (UPDATED)
└── ...

CC Project Memory:
~/.claude/projects/-home-sgagnon-workspace-atlas-projects-atlas-dev-plugin/memory/
└── MEMORY.md (NEW)
```

**Principe**: Le plan d'exécution vit dans `atlas-dev-plugin`. Ce fichier Synapse = design doc de référence + lien SP-11.

---

*Plan: squishy-scribbling-parnas | Target: ATLAS Plugin AI Maintainability 6→9/10 | Effort: ~16h*
*Repo: atlas-dev-plugin | Lien: SP-11 mega plan Synapse*
