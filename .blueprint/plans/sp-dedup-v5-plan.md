# SP-DEDUP v5.0 — Plugin Architecture Overhaul

> **Date**: 2026-04-12 | **Effort**: ~40h | **Type**: Breaking change v5.0.0
> **Design Doc**: `.blueprint/designs/sp-dedup-v5.md`
> **Users**: 2 (Seb + Jonathan) | **Risk**: Low (clean break, fresh install)

---

## A. Context

84 unique skills distributed across 10 profiles (4 tiers + 6 domains).
221 total registrations, 137 duplicated (62% reuse rate).
Admin user loads ~177K tokens/session ($0.50/session, ~$300/month).
2 competing marketplaces cause version conflicts.

**Target**: Zero duplication. Core + addon model. ~90K tokens for admin (-49%).

## B. File Inventory

### Modified (13 files)
- `_metadata.yaml` — add `plugin:` field per skill
- `build.sh` — produce core + addon artifacts
- `scripts/generate-master-skill.sh` — generate atlas-assist per plugin
- `.claude-plugin/marketplace.json` — single marketplace, list core + addons
- `.claude-plugin/plugin.json` — v5.0.0
- `.woodpecker/ci.yml` — build + test both plugins
- `.woodpecker/auto-release.yml` — release both plugins
- `Makefile` — new targets: build-core, build-addon-{role}
- `CLAUDE.md` — document new architecture
- `DEPLOYMENT.md` — new install instructions
- `pytest.ini` — adapt markers for 2-plugin model
- `tests/conftest.py` — fixtures for core vs addon
- `VERSION` — 5.0.0

### Created (6 files)
- `profiles/core.yaml` — 25 skills (base + experiential)
- `profiles/dev-addon.yaml` — 18 dev-only skills
- `profiles/admin-addon.yaml` — 36 admin-only skills
- `profiles/frontend-addon.yaml` — 5 FE-only skills
- `profiles/infra-addon.yaml` — 10 infra-only skills
- `profiles/enterprise-addon.yaml` — 14 enterprise-only skills

### Deleted (10 files/dirs)
- `profiles/user.yaml` → replaced by core
- `profiles/dev.yaml` → replaced by core + dev-addon
- `profiles/admin.yaml` → replaced by core + admin-addon
- `profiles/slim.yaml` → replaced by core
- `profiles/domain-*.yaml` (6 files) → replaced by *-addon.yaml
- `dist/atlas-slim/` — obsolete
- `dist/atlas-worker/` — legacy, never used

## C. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  atlas-dev-plugin (source repo)                               │
│                                                                │
│  skills/  (84 unique)    agents/  (16)    hooks/  (37)       │
│  _metadata.yaml: each skill has plugin: core|dev|admin|...    │
│                                                                │
│  profiles/                                                     │
│  ├── core.yaml           (25 skills, 4 agents, core hooks)   │
│  ├── dev-addon.yaml      (18 skills, 3 agents, dev hooks)    │
│  ├── admin-addon.yaml    (36 skills, 8 agents, admin hooks)  │
│  ├── frontend-addon.yaml (5 skills, 1 agent)                 │
│  ├── infra-addon.yaml    (10 skills, 2 agents)               │
│  └── enterprise-addon.yaml (14 skills, 6 agents)             │
│                                                                │
│  build.sh core     → dist/atlas-core/     (25 skills)        │
│  build.sh dev      → dist/atlas-dev/      (18 skills)        │
│  build.sh admin    → dist/atlas-admin/    (36 skills)        │
│  build.sh all      → builds core + all addons                │
└──────────────────────────────────────────────────────────────┘

Install combinations:
  Seb (admin):    atlas-core (25) + atlas-admin (36) = 61 skills, ~90K tokens
  Jonathan (dev): atlas-core (25) + atlas-dev (18)   = 43 skills, ~65K tokens
  FE dev:         atlas-core (25) + atlas-frontend (5) = 30 skills, ~50K tokens
```

## D. Data Schema (_metadata.yaml)

Add `plugin:` field to each skill entry:

```yaml
brainstorming:
  emoji: "💡"
  category: Planning
  owner: core        # existing field
  plugin: core       # NEW — which plugin artifact includes this skill
  domain: core       # existing field
  weight: 8

plan-builder:
  emoji: "🏗️"
  category: Planning
  owner: dev
  plugin: dev        # goes in dev-addon, NOT core
  domain: dev
  weight: 9
```

## E. Build System

### build.sh changes

Current: `build.sh admin|dev|user|slim` + `build.sh domains`
New: `build.sh core` + `build.sh addon-dev` + `build.sh addon-admin` + `build.sh all`

Key change: NO inheritance. Each build reads its profile and copies ONLY the skills listed.

```bash
# build.sh core
# Reads profiles/core.yaml → skills list
# Copies those skills to dist/atlas-core/skills/
# Generates atlas-assist for core (25 skills)
# Copies core hooks only
# Writes plugin.json with name: "atlas-core"

# build.sh addon-dev
# Reads profiles/dev-addon.yaml → skills list (delta only)
# Copies those skills to dist/atlas-dev/skills/
# Generates atlas-assist for dev (18 skills + knows core exists)
# Copies dev-specific hooks only
# Writes plugin.json with name: "atlas-dev"
```

### Makefile changes

```makefile
build-core:    ./build.sh core
build-dev:     ./build.sh addon-dev
build-admin:   ./build.sh addon-admin
build-all:     build-core build-dev build-admin build-frontend build-infra build-enterprise
dev:           build-core build-admin && dev-install.sh  # Seb's default
```

## F. Interfaces

### marketplace.json (single marketplace)

```json
{
  "name": "atlas-marketplace",
  "version": "5.0.0",
  "plugins": [
    {"name": "atlas-core", "version": "5.0.0", "description": "ATLAS core — shared base (25 skills)"},
    {"name": "atlas-dev", "version": "5.0.0", "description": "ATLAS dev addon (18 skills)"},
    {"name": "atlas-admin", "version": "5.0.0", "description": "ATLAS admin addon (36 skills)"},
    {"name": "atlas-frontend", "version": "5.0.0"},
    {"name": "atlas-infra", "version": "5.0.0"},
    {"name": "atlas-enterprise", "version": "5.0.0"}
  ]
}
```

### known_marketplaces.json (user install)

```json
{
  "atlas-marketplace": {
    "source": {"source": "git", "url": "https://forgejo.axoiq.com/axoiq/atlas-plugin.git"},
    "autoUpdate": true
  }
}
```

## G. atlas-assist Router

Each plugin gets its OWN atlas-assist SKILL.md (generated by build).

- **atlas-core/atlas-assist**: Lists 25 core skills. Routes core requests.
- **atlas-dev/atlas-assist**: Lists 18 dev skills. Routes dev requests. References core.
- **atlas-admin/atlas-assist**: Lists 36 admin skills. Routes admin requests. References core + dev.

CC loads both atlas-assists. The addon atlas-assist takes priority (ATLAS instruction priority).
Core atlas-assist handles fallback for skills not in the addon.

## H. Dependencies

```
atlas-core (REQUIRED — always installed)
  ├── atlas-dev (OPTIONAL — for developers)
  ├── atlas-admin (OPTIONAL — for admins, includes dev skills conceptually)
  ├── atlas-frontend (OPTIONAL)
  ├── atlas-infra (OPTIONAL)
  └── atlas-enterprise (OPTIONAL)
```

No addon works without core. Each addon is independent of other addons.

## I. Security

- **Hooks**: Core hooks (session-start, session-end, timestamp-injector, etc.) go in atlas-core.
  Addon hooks (enterprise-check, ci-auto-monitor, etc.) go in their addon.
- **Plugin isolation**: CC runs hooks from ALL installed plugins. No conflict if hooks have unique names.
- **Secrets**: No secret changes (forgejo_token stays in WP, not in plugin).

## J. Testing

### Test adaptation

Current 3-tier strategy (L1/L2/L3) adapts:
- L1 structural: tests must discover skills from BOTH core + addon profiles
- L2 build: verify both dist/atlas-core/ AND dist/atlas-{addon}/
- Sentinel test: verify no skill appears in both core AND addon

### New tests

- `test_no_skill_overlap.py`: assert intersection(core.skills, addon.skills) == empty set
- Update `test_e2e_plugin.py`: parametrize over core + addons (not 10 tiers)
- Update `conftest.py`: `ALL_PLUGINS = ["atlas-core", "atlas-dev", "atlas-admin", ...]`

## K. Enterprise (Migration)

| User | Current | After | Action |
|------|---------|-------|--------|
| Seb | atlas-admin (76 skills) | atlas-core + atlas-admin (61) | `git pull && make dev` |
| Jonathan | atlas-dev (40 skills) | atlas-core + atlas-dev (43) | `git pull && make dev` on his machine |

Clean break: old `atlas-admin-marketplace` cache deleted by `make dev` (dev-install.sh handles).

## L. Performance

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Admin tokens/session | ~177K | ~90K | **-49%** |
| Dev tokens/session | ~110K | ~65K | **-41%** |
| Core-only tokens | N/A | ~40K | Lightest |
| Skill registrations | 221 | 84 | **-62%** |
| Duplication rate | 62% | 0% | **-100%** |
| Build artifacts | 10 | 6 | -40% |
| Monthly cost (admin) | ~$300 | ~$150 | **-50%** |

## M. Documentation

| Doc | Change |
|-----|--------|
| `CLAUDE.md` | Architecture section rewritten for core + addon model |
| `DEPLOYMENT.md` | New install instructions (2 plugins) |
| `ONBOARDING.md` | Updated for Jonathan |
| `.blueprint/ARCHITECTURE.md` | New build system docs |
| `.blueprint/SKILL-CATALOG.md` | Updated with plugin field |
| Memory: `atlas-plugin-improvements-backlog.md` | Mark SP-DEDUP as DONE |

## N. Phases

### Phase 0: Inventory + Classification (~2h)

| Task | Hours | Files | Checkpoint |
|------|-------|-------|------------|
| P0.1 Add `plugin:` field to every skill in _metadata.yaml | 1h | `_metadata.yaml` | `grep -c "plugin:" _metadata.yaml` = 84 |
| P0.2 Create core.yaml profile (25 skills) | 0.5h | `profiles/core.yaml` | YAML valid, 25 skills listed |
| P0.3 Create dev-addon.yaml (18 skills, zero core overlap) | 0.5h | `profiles/dev-addon.yaml` | intersection(core, dev) = empty |

### Phase 1: Core Extraction (~8h)

| Task | Hours | Files | Checkpoint |
|------|-------|-------|------------|
| P1.1 Modify build.sh to support `build.sh core` | 3h | `build.sh` | `./build.sh core` produces dist/atlas-core/ |
| P1.2 Generate atlas-assist for core (25 skills) | 2h | `generate-master-skill.sh` | atlas-assist lists exactly 25 skills |
| P1.3 Distribute core hooks | 1h | `hooks/`, profiles | Core hooks copied to dist/atlas-core/hooks/ |
| P1.4 Create core plugin.json | 0.5h | `.claude-plugin/` | `name: "atlas-core"`, version 5.0.0 |
| P1.5 Run tests on core artifact | 1.5h | `tests/` | L1 + L2 pass for atlas-core |

### Phase 2: Addon Refactor (~15h)

| Task | Hours | Files | Checkpoint |
|------|-------|-------|------------|
| P2.1 Create admin-addon.yaml (36 skills) | 1h | `profiles/` | Zero overlap with core |
| P2.2 Create frontend/infra/enterprise addons | 2h | `profiles/` | Zero overlap with core |
| P2.3 Modify build.sh for `build.sh addon-{role}` | 4h | `build.sh` | All 5 addons build cleanly |
| P2.4 Generate atlas-assist for each addon | 3h | `generate-master-skill.sh` | Each addon lists only its delta skills |
| P2.5 Distribute addon-specific hooks | 1h | `hooks/`, profiles | Each addon has only its hooks |
| P2.6 Delete old profiles (user, dev, admin, slim, domain-*) | 0.5h | `profiles/` | Only core + 5 addons remain |
| P2.7 Update all tests for 2-plugin model | 3h | `tests/` | L1 + L2 pass for all plugins |
| P2.8 Add overlap sentinel test | 0.5h | `tests/` | test_no_skill_overlap passes |

### Phase 3: Marketplace Merge (~8h)

| Task | Hours | Files | Checkpoint |
|------|-------|-------|------------|
| P3.1 Create single marketplace.json (6 plugins) | 1h | `.claude-plugin/` | Valid JSON, 6 plugins listed |
| P3.2 Update dev-install.sh for 2-plugin install | 2h | `scripts/dev-install.sh` | `make dev` installs core + admin |
| P3.3 Update Makefile targets | 1h | `Makefile` | `make build-core`, `make dev`, `make build-all` work |
| P3.4 Update known_marketplaces.json (local + infra) | 1h | `~/.claude/`, infra repo | Points to axoiq/atlas-plugin, marketplace name = atlas-marketplace |
| P3.5 Rename marketplace in Forgejo package registry | 1h | Forgejo API | Old atlas-admin-marketplace deprecated |
| P3.6 CI: build + test + release both plugins | 2h | `.woodpecker/` | Pipeline green |

### Phase 4: Migration + Cleanup (~7h)

| Task | Hours | Files | Checkpoint |
|------|-------|-------|------------|
| P4.1 Version bump to 5.0.0 | 0.5h | `VERSION` | `cat VERSION` = 5.0.0 |
| P4.2 Update CLAUDE.md + DEPLOYMENT.md + ONBOARDING.md | 2h | Docs | Architecture section accurate |
| P4.3 Update Synapse CLAUDE.md plugin references | 0.5h | Synapse repo | Points to atlas-marketplace v5 |
| P4.4 Clean dist/ (delete slim, worker, domain-*) | 0.5h | `dist/` | Only 6 dirs remain |
| P4.5 Jonathan migration (guide + verify) | 1h | Jonathan's machine | `make dev` installs core + dev |
| P4.6 Coder templates update (marketplace URLs) | 1h | infra repo | Correct marketplace name |
| P4.7 Final CI run + tag v5.0.0 | 1.5h | CI | Pipeline ALL GREEN, tag created |

## O. Verification

| Phase | Command | Expected |
|-------|---------|----------|
| P0 | `grep -c "plugin:" skills/_metadata.yaml` | 84 |
| P0 | `python3 -c "import yaml; ..."` validate no overlap | 0 overlapping skills |
| P1 | `./build.sh core && ls dist/atlas-core/skills/*/SKILL.md \| wc -l` | 25 |
| P1 | `pytest tests/ -m "not build and not integration and not broken" -x` | 2900+ pass |
| P2 | `./build.sh all && ls dist/*/skills/*/SKILL.md \| wc -l` | 84 (total unique) |
| P2 | `pytest tests/ -m build -x` | Pass (all plugins verified) |
| P3 | `make dev && ls ~/.claude/plugins/cache/atlas-marketplace/` | atlas-core/ + atlas-admin/ |
| P4 | `git tag -l 'v5*'` | v5.0.0 |
| P4 | WP pipeline #N | ALL GREEN |

## Synthese

- **Quoi**: Restructurer le plugin de 10 profils vers core + 5 addons. Zero duplication.
- **Pourquoi**: 177K tokens/session gaspilles ($300/mois), 62% duplication rate
- **Impact**: -49% tokens (177K→90K), 0% duplication, 1 marketplace (vs 2)
- **Risques**: Build system complex → mitige par P1 incremental. Jonathan migration → mitige par P4.5 guide.
- **Critere de succes**: Admin session < 90K tokens, zero overlap, CI green, 2 users migres
