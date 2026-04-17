# ATLAS Plugin — Claude Code AI Engineering Assistant

> **Stack**: Bash + yq + Python (tests) | **Version**: `cat VERSION` | **Branch**: `main`
> **Repo**: `forgejo.axoiq.com/axoiq/atlas-plugin` | **Owner**: Seb Gagnon (AXOIQ)

## IDENTITY

**ATLAS** is AXOIQ's unified Claude Code plugin — a multi-tier AI engineering assistant with skills, agents, and lifecycle hooks. It replaces 18+ individual plugins with one cohesive system.

**Key insight**: ATLAS develops itself using ATLAS. The plugin-builder, skill-management, and atlas-dev-self skills are used to extend the plugin.

## CC 2.1.x Native Features Adopted (v5.7.0+)

| Feature | CC Version | ATLAS Integration |
|---------|-----------|-------------------|
| Session rename | v2.0.64 | `atlas resume <name>` dual-mode |
| LSP tool | v2.1.74 | (Phase 7 pending) |
| `/effort` | v2.1.84 | documented in ultrathink skill |
| `/loop` + CronCreate | v2.1.89 | experiment-loop delegates simple cases |
| `--worktree` (-w) | v2.1.49 | `atlas feat/fix/hotfix <desc>` wrapper |
| Worktree hooks | v2.1.50 | worktree-setup / -cleanup-native |
| TeammateIdle/TaskCompleted | v2.1.33 | team-idle-notify / task-completed-metrics |
| context_window.size/used_% | v2.1.79 | CShip context_bar |
| rate_limits | v2.1.80 | `$cship.usage_limits` |
| exceeds_200k_tokens | v2.1.87 | atlas-200k-badge-module.sh |
| cost.total_cost_usd | v2.1.x | atlas-cost-usd-module.sh |
| workspace.git_worktree | v2.1.97 | `$cship.worktree` |
| ExitWorktree safety | v2.1.72+ | worktree-exit-safe 5-option flow |
| InstructionsLoaded / ConfigChange | v2.1.83 | already wired pre-v5.7.0 |
| PreCompact / PostCompact | v2.1.89 | already wired pre-v5.7.0 |
| StopFailure / SubagentStart | v2.1.43/78 | already wired pre-v5.7.0 |

Plan: `.blueprint/plans/sleepy-tumbling-hennessy.md` (9 phases total, 5 complete)

## ARCHITECTURE

```
profiles/{user,dev,admin}.yaml   ← Tier definitions (YAML inheritance)
        ↓ build.sh
dist/atlas-{user,dev,user}/      ← Self-contained artifacts (no runtime deps)
        ↓ make dev
~/.claude/plugins/cache/         ← Installed in Claude Code
```

**3-Tier Inheritance**: `user` → `dev` (inherits user) → `admin` (inherits dev)

### 6-Domain Overlay (standalone installs)

In addition to tiers, ATLAS offers **domain plugins** — standalone installs for specific workflows.
Each domain has its own `atlas-assist` router. **No inheritance** between domains.

| Domain | Skills | Role | Audience |
|--------|--------|------|----------|
| `atlas-core` | 14 | Memory, session, context, vault, assist, doctor | Everyone |
| `atlas-dev` | 25 | Planning, TDD, debugging, review, shipping | Developers |
| `atlas-admin` | 27 | Deploy, security, infra, enterprise, experiments | Admins |
| `atlas-frontend` | 5 | UI design, browser automation, visual QA | FE devs |
| `atlas-infra` | 10 | VM/container ops, network, security audit | DevOps |
| `atlas-enterprise` | 14 | Governance, knowledge engine, programme mgmt | Leads |
| `atlas-experiential` | 5 | Episode capture, intuition, relationship memory | Personal |

**⚠️ Duplication risk**: Skills listed in multiple domain profiles are built N times.
Installing all 6 domains = ~282 registrations with ~75% duplication (~177K wasted tokens).
**Recommendation**: Install the **tier** that matches your role (user/dev/admin), NOT all domains.
SP-DEDUP (planned) will resolve this with shared-core + delta architecture.

| Component | Location | Count (admin) |
|-----------|----------|---------------|
| Skills | `skills/*/SKILL.md` | ~67 (profile + atlas-assist) |
| Agents | `agents/*/AGENT.md` | 12 |
| Hooks | `hooks/hooks.json` + scripts | 16 events, ~37 handlers |
| Refs | `skills/refs/*/SKILL.md` | 5 |
| Tests | `tests/test_*.py` | 17 |

### Hook Architecture (IMPORTANT)

- **hooks.json is the SSoT** for all hook registrations. NEVER put hooks in `~/.claude/settings.json`.
- **Naming convention**: Hook scripts in `hooks/` have NO `.sh` extension (e.g., `protect-plugin-cache` not `protect-plugin-cache.sh`).
- **Plugin settings.json**: Only env vars and UI flags. NEVER include a `hooks` block.
- Policy enforcement: `policy-drift-detector` hook warns at session start if deny rules are missing.

## COMMANDS

```bash
# Build
./build.sh all                    # Build 3 tiers → dist/
./build.sh admin                  # Build admin only

# Test (ALWAYS -x --tb=short)
python3 -m pytest tests/ -x -q --tb=short
python3 -m pytest tests/test_skill_frontmatter.py -x -q --tb=short  # Single test

# Dev cycle (build admin + install to CC cache)
make dev

# Publish
make publish-patch                # patch bump → build → test → tag → push
make publish-minor                # minor bump

# Lint
make lint                         # Frontmatter + coverage checks
```

## PRINCIPLES

1. **Self-Contained Tiers** — Each `dist/atlas-{tier}/` is independent. No runtime inheritance.
2. **Build-Time Resolution** — `resolve_field()` in build.sh resolves YAML inheritance recursively.
3. **Dynamic Generation** — `generate-master-skill.sh` builds atlas-assist per tier with real counts.
4. **Test Everything** — 16 test types validate structure, frontmatter, cross-refs, build output, hooks.
5. **Version SSoT** — `VERSION` file → propagated to all JSON manifests by build.sh.
6. **Visual Identity** — All hook outputs use `🏛️ ATLAS │` prefix. See `skills/refs/atlas-visual-identity/`.

## EXTENDING THE PLUGIN

### Adding a Skill
1. Create `skills/{name}/SKILL.md` with frontmatter: `name`, `description`, `effort`
2. Add to appropriate profile (`profiles/{tier}.yaml`)
3. Add to `EMOJI_MAP`, `DESC_MAP`, `CATEGORY_MAP` in `scripts/generate-master-skill.sh`
4. Run `make test` — validates frontmatter, coverage, cross-refs

### Adding an Agent
1. Create `agents/{name}/AGENT.md` with frontmatter: `name`, `description`, `model`
2. Add to profile under `agents:` list
3. Define workflow, tools, constraints in the AGENT.md
4. Read-only agents: add "Tools NOT Allowed" deny list

### Adding a Hook
1. Create executable script in `hooks/{name}`
2. Add entry to `hooks/hooks.json` with event, matcher, async, timeout
3. Brand output with `🏛️ ATLAS │ {emoji}{severity} {CATEGORY} │ {message}`
4. Build copies all executable hooks automatically (wildcard)

### Adding a Reference
1. Create `skills/refs/{name}/SKILL.md`
2. Add to profile under `refs:` list

## ONBOARDING & DOCTOR

- `/atlas setup` — 5-phase wizard (profile, credentials, env, context, optional)
- `/atlas doctor` — 8-category health dashboard with auto-fix
- First-run: SessionStart hook detects missing `~/.atlas/profile.json` → shows `👋 FIRST RUN`
- Storage: `~/.atlas/` (profile.json, doctor-report.json)
- Both skills available in ALL tiers (user, dev, admin)

## VERSION BUMP CONVENTION

Auto-release CI bumps version on push to `main` using conventional commits:

| Commit Type | Bump | Example |
|------------|------|---------|
| `feat(scope):` | **minor** (4.42.0 → 4.43.0) | `feat(plugin): add orchestration` |
| `fix(scope):` | **patch** (4.42.0 → 4.42.1) | `fix(ci): runner config` |
| `perf(scope):` | **patch** (4.42.0 → 4.42.1) | `perf(plugin): model allocation` |
| `feat!(scope):` / `BREAKING CHANGE` | **major** (4.42.0 → 5.0.0) | Breaking changes |
| `chore\|docs\|build\|ci\|refactor\|test\|style` | **NO bump** (skipped) | Non-functional |

**Manual release**: `make publish-patch` (or `publish-minor`) — bumps, builds, tests, tags, pushes.
**NEVER use** `build(v4.X.0):` for version bumps — auto-release ignores this pattern.

## ORCHESTRATION (Opus → Sonnet)

Main session = **Opus 4.7 [1m]** (orchestrator). Subagents = **Sonnet 4.6** (workers).
Both models have 1M context — the differentiator is reasoning quality, not context size.

| Task | Model | Why |
|------|-------|-----|
| Planning, architecture, brainstorm | Opus | GPQA +17pts, adaptive thinking (max) |
| Implementation, tests, review, DB migration | Sonnet | SWE-bench gap 1.2pts, 5x cheaper, 2.7x faster |
| Validation, search | Haiku | Cheapest capable |
| Lint, format, type-check | DET (bash) | Zero AI tokens |

**Complexity Gate**: TRIVIAL (solo) → MODERATE (Sonnet ad-hoc dispatch) → COMPLEX (full pipeline).
**Context Distillation**: ~20K tokens focused prompt per subagent, never full session dump.
**Details**: `skills/refs/model-benchmarks-2026-04/SKILL.md`

## SELF-DEVELOPMENT

This plugin develops itself. When modifying atlas-plugin:
- **Use skill-management** for creating/improving skills
- **Use plugin-builder** for structural changes
- **Use atlas-dev-self** for the full self-development workflow
- **Always run `make test` before commit**
- **Always run `make dev` to install and test in a live CC session**

## KEY FILES

| File | Purpose |
|------|---------|
| `build.sh` | Multi-tier builder with inheritance |
| `scripts/atlas-cli.sh` | Shell launcher (tmux, sessions). See `.blueprint/LAUNCHER-PLAYBOOK.md` |
| `scripts/generate-master-skill.sh` | Dynamic atlas-assist generator |
| `scripts/dev-install.sh` | Build + install to CC cache + sync shell launcher |
| `profiles/*.yaml` | Tier definitions |
| `hooks/hooks.json` | Hook registry |
| `Makefile` | Dev workflow shortcuts |
| `VERSION` | Semver SSoT |
| `tests/conftest.py` | Test fixtures + constants |
| `.forgejo/workflows/ci.yaml` | CI (test on push/PR) |
| `.forgejo/workflows/publish.yaml` | Release (build on tag) |

## CONTEXT LOADING (Lazy)

| Need | Read |
|------|------|
| AXOIQ vision + Synapse concepts | `.blueprint/VISION.md` |
| Build system deep dive | `.blueprint/ARCHITECTURE.md` |
| Skill catalog (48 skills) | `.blueprint/SKILL-CATALOG.md` |
| Integration mapping | `.blueprint/INTEGRATION-MAP.md` |
| Copy-paste patterns | `.blueprint/PATTERNS.md` |
| Test strategy | `.blueprint/TESTING.md` |
| All docs index | `.blueprint/INDEX.md` |

## TESTING

15 test files covering:
- `test_skill_frontmatter` — name, description, effort in every SKILL.md
- `test_skill_coverage` — no orphan skills (except atlas-assist source)
- `test_profiles` — YAML inheritance chain
- `test_build_output` — dist/ artifact completeness
- `test_version_sync` — VERSION matches all manifests
- `test_cross_references` — skills ↔ profiles aligned
- `test_regression_gate` — structural integrity (no commands/ dir)
- `test_hooks_schema` — hooks.json validity
- `test_hook_behavior` — hook script execution
- `test_agent_frontmatter` — agent spec completeness
- `test_manifest` — plugin.json validity
- `test_no_hardcoded_paths` — portability
- `test_skill_quality` — documentation quality

## COMPACTION

Preserve: modified file paths, VERSION, branch, tier being built, test failures,
build.sh changes, skill frontmatter changes, hook additions.
SSoT = VERSION file. Always `make test` before commit.
Memory: `~/.claude/projects/-home-sgagnon-workspace-atlas-projects-atlas-dev-plugin/memory/`
