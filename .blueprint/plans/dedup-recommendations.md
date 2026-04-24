# Sprint 4 Dedup Recommendations — HITL Review Required

> **Status**: ANALYSIS ONLY — zero files modified, zero destructive action
> **Artifacts**: `tests/dedup/dedup-analysis.csv` (117 rows)
> **Author**: plan-architect (Opus 4.7, ultrathink)
> **Generated**: 2026-04-17

## Summary

| Metric | Value |
|---|---:|
| Skills currently on disk (unique `SKILL.md`) | **117** |
| Profile-listed total (with dev+admin overlaps) | 131 |
| dev+admin duplicate listings | **33** |
| Tier-1 protected skills (never touch) | **19** |
| Long skills flagged for trim (>250L) | 15 |
| Merge-sibling candidates | 2 (high-risk) |
| Estimated post-Phase-1 count | 117 unique, 117 total (zero overlap) |
| Estimated post-Phase-2 count | **115** unique |
| Plan v6.0 Sprint 4 target | "~60 skills" — requires MAJOR consolidation beyond this analysis |

## Key finding

**The "131" in the plan is an artifact of profile-list overlap**. All 33 duplicates share a single physical `SKILL.md` on disk — the duplication exists ONLY in `admin-addon.yaml` repeating the dev-addon list. Fixing this is a **YAML-only change**, zero content loss, zero risk to runtime behavior.

## Recommendation breakdown

| Strategy | Count | Risk |
|---|---:|---|
| `keep-as-is` | 74 | none |
| `canonical-dev-only` | 31 | low-medium |
| `canonical-dev-only+trim` | 2 | medium |
| `trim-only` | 8 | medium |
| `merge-siblings` | 2 | high |
| **Total** | **117** | — |

| Risk level | Count |
|---|---:|
| none | 73 |
| low | 10 |
| medium | 32 |
| high | 2 |

---

## Analysis by tier

### Core tier (27 skills) — HIGH PROTECTION

**Protected (14 skills)** — foundational, security, or session-critical. NEVER touch:
`atlas-assist`, `atlas-vault`, `atlas-doctor`, `atlas-onboarding`, `atlas-location`, `atlas-workspace-setup`, `context-discovery`, `discovery`, `agent-visibility`, `session-pickup`, `session-retrospective`, `session-spawn`, `memory-dream`, `knowledge-builder`, `scope-check`, `user-profiler`, `cost-analytics`.

**Trim candidates (6 skills, ~2,250L → ~1,400L target, -38%)**:

| Skill | Lines | Target | Rationale |
|---|---:|---:|---|
| `memory-dream` | 1167 | 400 | 16-phase cycle exhaustively documented; move examples to refs/ |
| `atlas-doctor` | 946 | 400 | 8-category diagnostic with verbose auto-fix recipes |
| `session-spawn` | 351 | 280 | 3 modes share 60% scaffolding — consolidate prefix |
| `atlas-workspace-setup` | 248 | 220 | Multi-mode tmux setup — dedupe blocks |
| `atlas-assist` | 463 | 400 | Compress persona examples; **HARD-GATE MUST STAY** |
| `morning-brief` / `morning-routine` | 185+130 | 240 | Merge candidate (see merge-siblings below) |

**No cross-tier duplicates in core** (27 skills all unique to core).

### Dev tier (36 skills) — MEDIUM PROTECTION

All 33 of the dev+admin overlaps are OWNED by dev (per `_metadata.yaml`). Admin-addon.yaml lists them redundantly.

**Trim candidates (2 skills)**:

| Skill | Lines | Target | Rationale |
|---|---:|---:|---|
| `execution-strategy` | 346 | 280 | Move manifest schema to refs/ |
| `ship-all` | 281 | 230 | Consolidate env-specific branches |

**Dev-only non-duplicates (kept as-is)**: `ci-health`, `smoke-gate`, `test-affected` (3 skills — dev-exclusive).

### Admin tier (67 skills) — HIGH CHURN TARGET

After removing the 33 dev-inherited duplicates, admin-addon ships **34 unique skills** (not 67). That's a tight, focused superset.

**Trim candidates (7 skills, ~2,830L → ~2,100L target, -26%)**:

| Skill | Lines | Target | Rationale |
|---|---:|---:|---|
| `atlas-team` | 710 | 350 | 5 blueprints with duplicated tmux scaffolding |
| `feature-board` | 497 | 300 | Dashboard logic belongs in script, not SKILL.md body |
| `onboarding-check` | 385 | 280 | 12 checks prose-heavy — tabulate |
| `product-health` | 324 | 260 | Long validation table → refs/ |
| `infrastructure-change` | 306 | 250 | 5 component runbooks → split refs/ |
| `ultrathink` | 293 | 240 | 6 subcommands with verbose examples |
| `statusline-setup` | 278 | 220 | Cross-platform installer → script |
| `code-analysis` | 264 | 220 | 4 analysis modes with similar examples |

**High-risk merge candidates (2 skills)** — DO NOT EXECUTE WITHOUT SEB APPROVAL:

| Merge target | Folds in | Rationale | Risk |
|---|---|---|---|
| `knowledge-engine` (155L) | `knowledge-manager` (97L) | Both expose Unified Knowledge Layer — overlap ~60%. Admin callers import both today. | HIGH — breaks existing flows |
| `gms` (new skill) | `gms-cockpit`+`gms-profiler`+`gms-insights`+`gms-onboard` (596L total) | All 4 form G Mining suite — could be one skill with 4 subcommands | HIGH — changes POC interface |

### Refs tier (12 files) — ZERO CHANGE

All 12 refs are reference catalogs (code-smells-catalog, sota-architecture-patterns, etc.). Already single-ownership via profile `refs:` field. Not skill duplicates.

### Shared / orphan (8 skills)

| Skill | Current state | Recommendation |
|---|---|---|
| `atlas-assist` | Hand-crafted master (v5.1+ unified) | keep — CC loads `scripts/atlas-assist-master.md` |
| `hardware-capacity`, `iac-orchestrator`, `infra-inventory`, `mesh-diagnostics`, `network-audit`, `proxmox-admin` | domain-exclusive (infra) — not in tier profiles | keep — built by `build.sh domain infra` |
| `self-propose` | domain-exclusive (enterprise) | keep — built by `build.sh domain enterprise` |

---

## Cross-tier duplicates (PRIORITY TARGETS — 33 skills)

All 33 live in `profiles/admin-addon.yaml` AND `profiles/dev-addon.yaml`. Since `_metadata.yaml` declares `owner: dev` for each, the canonical recommendation is **move admin-addon.yaml to inheritance-only**:

```yaml
# profiles/admin-addon.yaml — BEFORE (67 skills listed)
skills:
  - brainstorming       # duplicated from dev
  - plan-builder        # duplicated from dev
  - ... (31 more duplicates)
  - devops-deploy       # admin-exclusive
  - ...

# profiles/admin-addon.yaml — AFTER (inherits dev, lists 34 admin-exclusives)
inherits: dev-addon
skills:
  - devops-deploy
  - deploy-hotfix
  - infrastructure-ops
  - infrastructure-change
  - statusline-setup
  - security-audit
  - enterprise-audit
  - codebase-audit
  - code-analysis
  - product-health
  - plan-review
  - programme-manager
  - feature-board
  - onboarding-check
  - marketplace-manager
  - persona-loadout
  - auto-orchestrator
  - platform-update
  - knowledge-engine
  - knowledge-manager
  - experiment-loop
  - idle-curiosity
  - atlas-team
  - atlas-dev-self
  - gms-cockpit
  - gms-profiler
  - gms-onboard
  - gms-insights
  - atlas-analytics
  - ultrathink
  - secret-manager
  - skill-security-audit
  - agent-readiness
  - infra-health
```

`build.sh resolve_field()` already handles `inherits:` recursion (tested line 220-236).

**Acceptance test**: After the YAML change, `./build.sh admin` must produce **the same `dist/atlas-admin/skills/` directory** (67 skills) as before. The only difference is zero duplicate list entries in the source profile.

---

## Execution plan (if HITL approved)

### Phase 0 — Safety net (15 min)
1. Create backup branch: `git checkout -b feat/v6-sprint4-dedup-backup`
2. Snapshot baseline: `./build.sh all && ls -1 dist/atlas-admin/skills/ | sort > /tmp/baseline-admin-skills.txt`
3. Commit baseline snapshot for differential verification.

### Phase 1 — Inheritance fix (30 min, LOW risk) — **BLOCKED 2026-04-17**
1. Edit `profiles/admin-addon.yaml`: add `inherits: dev-addon`, remove 33 duplicated entries.
2. Run `./build.sh admin`.
3. Diff: `ls -1 dist/atlas-admin/skills/ | sort > /tmp/after-admin-skills.txt && diff /tmp/baseline-admin-skills.txt /tmp/after-admin-skills.txt` — MUST be empty.
4. Run full test suite: `cd tests && pytest test_profiles.py test_skill_dependencies.py test_skill_coverage.py -x -q --tb=short`.
5. Verify `scripts/atlas-discover-addons.sh` still reports correct capabilities.

**STATUS — BLOCKED**: `./build.sh modular` (v5+ default architecture invoked
by `make dev`) calls `build_modular_plugin` (build.sh L695), which reads
skills directly from profile YAML via `yq -r '.skills // [] | .[]'` (L729) and
DOES NOT call `resolve_field` — so `inherits:` is ignored in modular mode.
Adding `inherits: dev-addon` + trimming admin profile to 34 admin-unique skills
DROPS 33 dev-shared skills from `dist/atlas-admin-addon/skills/` (verified
2026-04-17: 67 → 34 SKILL.md regressed). The legacy `./build.sh all` tier mode
(L876-879) still uses `build_tier` which DOES walk inheritance correctly via
`resolve_field` (L210-236), but modular is the production build path used by
`make dev`/`make publish`.

**Workaround proposed → Sprint 7 task `build-modular-inherits`** (~2-3h):
Refactor `build_modular_plugin` to call `resolve_field "$name" "skills"` (and
the same for `agents`/`refs`) instead of the direct `yq` read on L729/L741/L751.
Hook delta logic (L756-774) is already correct — it reads only OWN hooks,
matching SP-HOOK-DEDUP intent. Acceptance: after refactor, applying the
inheritance YAML diff above produces the same `dist/atlas-admin-addon/skills/`
listing (67 entries) as baseline.

**Action this sprint**: NO change to `profiles/admin-addon.yaml` — the
duplicated 33-skill listing is the only working source of truth for the
modular admin build right now. Phase 2 (trim verbose skills) and Phase 3
(merge-siblings, HITL gated) are unaffected and remain executable.

### Phase 2 — Trim verbose skills (4-6h, MEDIUM risk)
For each of 15 trim candidates:
1. Extract structured content (examples, schemas, edge cases) to `skills/refs/<skill>-details/REF.md`.
2. Rewrite SKILL.md body to scannable hot-path (~50% of original).
3. Run `tests/test_skill_frontmatter.py` + `tests/test_skill_quality.py`.
4. Smoke test: invoke skill via `claude Skill=<name>` in sandbox.
5. Commit incrementally (1 skill per commit).

### Phase 3 — Merge-sibling review (HITL required, HIGH risk)
Each merge candidate needs Seb approval with explicit rationale:
- `knowledge-engine` + `knowledge-manager` → does this break existing `/atlas knowledge` flows?
- `gms-*` suite → does the POC team (8 MSE) rely on the distinct skill names?

### Phase 4 — Regression verification (2h)
1. Snapshot behavior: `build.sh all && pytest tests/ -x -q --tb=short`
2. Compare skill counts per tier against `tests/inventory/skills-audit-v5.23.csv`.
3. Manual smoke: run `/atlas` in a fresh session, verify skill list matches.

---

## Risk assessment

| Risk level | Count | What they are |
|---|---:|---|
| LOW | 10 | Small dev+admin skills (<150L), plus cosmetic trims |
| MEDIUM | 32 | Medium dev+admin skills + long-skill trims (>250L) |
| HIGH | 2 | Merge candidates (`knowledge-*`, `gms-*` suite) |
| NONE | 73 | Already canonical, refs, Tier-1 protected |

**Total potentially changed**: 42 skills (36% of 117) — but ONLY the 33 dev+admin entries touch profile YAML. The 15 trims touch SKILL.md bodies. The 2 merges would delete files.

### Blast radius by phase

| Phase | Files touched | Skills affected | Rollback |
|---|---:|---:|---|
| Phase 1 (inherit) | 1 YAML | 0 | `git revert` |
| Phase 2 (trim) | 15 SKILL.md + 15 refs/ | 15 | `git revert` per skill |
| Phase 3 (merge) | Up to 5 files deleted | Up to 5 | branch-level revert |

---

## HITL questions for Seb (REQUIRED before any execution)

1. **Approve Phase 1 inheritance fix?** (33 YAML lines removed, zero content change, reversible)
2. **Approve Phase 2 trim pass?** Which of the 15 skills can be shortened now vs deferred? (suggest: start with `memory-dream`, `atlas-doctor`, `atlas-team` — highest impact)
3. **Merge `knowledge-engine` + `knowledge-manager`?** Risk: breaks `/atlas knowledge` consumers. Alternative: keep both but cross-link in descriptions.
4. **Consolidate `gms-*` suite into one skill?** Risk: changes POC UX for 8 MSE. Alternative: keep all 4 but extract shared scaffolding to `gms-core/REF.md`.
5. **Does the "~60 skills" target in v6.0 Plan section K include refs?** If yes, target ≈ 48 skills + 12 refs. If no, it requires deleting ~57 skills — far beyond what this analysis recommends.
6. **Should `morning-routine` (130L) and `morning-brief` (185L) merge into `morning` with subcommands?** Both are core tier — low risk, user-facing.

---

## What this analysis did NOT do

- No files modified. No skills deleted. No profile YAML changed.
- No subjective judgment on which skills are "low-value" — that requires domain context only Seb has.
- No deprecation aliases designed — that's Phase 3 territory.
- No build execution / test runs — recommendations are static analysis only.

---

## References

- CSV catalog: `tests/dedup/dedup-analysis.csv` (117 rows, 6 columns)
- Source inventory: `tests/inventory/skills-audit-v5.23.csv`
- Profiles: `profiles/core.yaml`, `profiles/dev-addon.yaml`, `profiles/admin-addon.yaml`
- Metadata: `skills/_metadata.yaml` (owner authoritative source)
- Dependencies: `skills/_dependencies.yaml` (blast-radius input)
- Build logic: `build.sh::resolve_field()` lines 210-236 (inheritance recursion)
- Plan v6.0 Sprint 4: target "131→60 skills (-54%)"

*Generated by plan-architect Opus 4.7 ultrathink. Zero destructive actions taken. Seb HITL required before any execution.*
