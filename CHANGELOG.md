# Changelog

## v5.25.0 (2026-04-18)

### ✨ Features
- feat(profiles): register auto-tail-agent hook in atlas-core



## v5.24.0 (2026-04-18)

### ✨ Features
- feat(hooks): auto-tail-agent for subagent tmux visibility (sp-agent-vis layer 3)



## v5.23.0 (2026-04-17)

### ✨ Features
- feat(models): migrate Opus 4.6 → 4.7 across plugin (model IDs, labels, env vars, routing)
- feat(models): update pricing `cost.sh` to Opus 4.7 rates ($5/$25, down from $15/$75)
- feat(effort): document new `xhigh` effort level (Opus 4.7 only, CC 2.1.111+)
- feat(docs): integrate CC 2.1.105-111 new features (auto mode natif, /less-permission-prompts, /ultrareview, /team-onboarding, /tui, /recap, PreCompact hook, push notifications, ENABLE_PROMPT_CACHING_1H, background monitors)
- feat(profiles): wire sprint 2.5 skills + `pre-push-affected` hook into `dev-addon.yaml` profile (skills now ship correctly with atlas-dev addon install)

### 🔧 Other Changes
- chore(regex): switch `*opus-4-6*` → `*opus-4-[67]*` in context-threshold.sh + atlas-context-size-module.sh (backward compat for legacy sessions)
- chore(benchmarks): annotate benchmarks `as of Opus 4.6` in model-benchmarks skill (follow-up: Opus 4.7 benchmarks via WebSearch)

### 📝 Notes
- Opus 4.6 retired by Anthropic 2026-04-16; all references migrated to 4.7
- Tokenizer change in 4.7 may produce up to +35% tokens for same text — monitor effective cost on long sessions
- Historical evals (`ai_eval_scores.judge_model='claude-opus-4-6'`) remain readable via String column backward compat
- Post-v5.22.0 fixup: sprint 2.5 skills (`test-affected`, `smoke-gate`, `ci-health`) shipped in v5.22.0 but were missing from `profiles/dev-addon.yaml` — now properly included in addon build

## v5.22.0 (2026-04-17)

### ✨ Features
- feat(plugin): sprint 2.5 p3+p4+p5 — test-affected + smoke-gate + ci-health skills

### 🔧 Other Changes
- Merge pull request 'feat(plugin): Sprint 2.5 P3+P4+P5 — test-affected + smoke-gate + ci-health skills' (#20) from feat/test-ci-sprint25-p3-p4-p5 into main

## v5.21.0 (2026-04-15)

### ✨ Features
- feat(daimon): SP-DAIMON P2 calibration rules + pattern detection

### 🔧 Other Changes
- Merge pull request 'feat(daimon): SP-DAIMON P2 calibration rules + pattern detection' (#19) from feat/daimon-p2-calibration into main



## v5.20.1 (2026-04-15)

### 🐛 Bug Fixes
- fix(ci): remove broken publish.yml (legacy tiers gone)

### 🔧 Other Changes
- Merge pull request 'fix(ci): remove broken publish.yml' (#18) from fix/remove-broken-publish into main



## v5.20.0 (2026-04-15)

### ✨ Features
- feat(ci): consolidate forgejo actions to woodpecker (#16)
- feat(ci): consolidate forgejo actions to woodpecker

### 🐛 Bug Fixes
- fix(ci): remove gh mirror until github repo exists

### 🔧 Other Changes
- Merge pull request 'fix(ci): remove gh mirror until github repo exists' (#17) from fix/remove-mirror-until-gh-ready into main



## v5.19.0 (2026-04-15)

### ✨ Features
- feat(daimon): SP-DAIMON P1 Foundation (v5.19.0) (#15)
- feat(daimon): sp-daimon p1 foundation — vault auto-load + context injection

### 🐛 Bug Fixes
- fix(daimon): bump marketplace.json versions to 5.19.0
- fix(daimon): bump .claude-plugin/plugin.json to 5.19.0
- fix(daimon): move README out of hooks/ (test_hook_consistency)
- fix(daimon): declare p1 hooks in profiles/core.yaml

### 🔧 Other Changes
- chore(release): bump version to 5.19.0
- test(daimon): bats tests + fixtures + docs for sp-daimon p1



## v5.18.0 (2026-04-15)

### ✨ Features
- feat(ci): atlas ci watch --live (#14)
- feat(ci): atlas ci watch --live — bash extension P5
- feat(ci): ci_watch_render.py P4 — TUI mode + ANSI colors
- feat(ci): ci_watch_render.py P3 — freeze detector
- feat(ci): ci_watch_render.py P2 — framework progress parsers + log loader
- feat(ci): ci_watch_render.py P1 — skeleton + plain timeline

### 🔧 Other Changes
- docs(ci): P7 — ci-watch-live reference + SKILL.md update + bats fix
- test(ci): bats P6 — 18 cases for atlas ci watch --live + 2 fixtures



## v5.17.1 (2026-04-15)

### 🐛 Bug Fixes
- fix(plugins): remove deprecated .lsp.json files — CC schema v2 mismatch



## v5.17.0 (2026-04-15)

### ✨ Features
- feat(cli,ci): atlas plugin status + archaeology-escape + auto-release dist rebuild

### 🔧 Other Changes
- docs(test-orchestrator): add sota-testing-patterns + 5-level maturity model
- docs(devops-deploy): add sota-deploy-patterns reference + 5-defect audit



## v5.16.0 (2026-04-14)

### ✨ Features
- feat(ci): atlas ci secrets rotate-ssh — automated ssh deploy key rotation



## v5.15.1 (2026-04-14)

### 🐛 Bug Fixes
- fix(hooks): stop hook silent exit on clean worktree (pipefail + missing dev ref)



## v5.15.0 (2026-04-14)

### ✨ Features
- feat(ci): expand atlas ci CLI — rerun/watch/secrets/agents + decode null fix (#13)



## v5.14.0 (2026-04-14)

### ✨ Features
- feat(ci): atlas ci logs — programmatic Woodpecker 3.14 log access (#12)



## v5.13.0 (2026-04-14)

### ✨ Features
- feat(lsp): add typescript-language-server to dev-addon (#11)



## v5.12.3 (2026-04-14)

### 🐛 Bug Fixes
- fix(agents): tmux remain-on-exit for tail pane (#10)



## v5.12.2 (2026-04-14)

### 🐛 Bug Fixes
- fix(lsp): wrap pyright config under server name (dev-addon)



## v5.12.0 (2026-04-14)

### ✨ Features
- feat(cli): version SSoT via installed_plugins.json + fix 3 zsh bugs (#9)

### 🔧 Other Changes
- chore(hooks): add set -euo pipefail to 22 hooks (Task #15) (#8)
- docs(plans): archive ATLAS v5.7.0 engineering plans (#7)



## v5.11.0 (2026-04-14)

### ✨ Features
- feat(hooks): auto-update plugin on SessionStart when marketplace ahead (#6)

### 🔧 Other Changes
- Merge PR #5 — SC2155 cleanup + shellcheck hard-fail
- ci(shellcheck): hard-fail on errors (zero after SC2155 cleanup)
- refactor(shell): batch-fix 119 SC2155 warnings (91% reduction)



## v5.10.0 (2026-04-14)

### ✨ Features
- feat(skills): Code hygiene micro-discipline infrastructure (Phase 9A)

### 🔧 Other Changes
- Merge pull request #4 — Phase 9A Code Hygiene Micro-Discipline



## v5.9.0 (2026-04-14)

### ✨ Features
- feat(skills): SOTA senior patterns infrastructure (Phase 8A+8B2)

### 🔧 Other Changes
- Merge pull request #3 — Phase 8A+8B2 SOTA Senior Patterns



## v5.8.0 (2026-04-14)

### ✨ Features
- feat(lsp): declare bash + yaml + pyright LSP servers (Phase 7A+7B+7C)

### 🐛 Bug Fixes
- fix(ci): gitleaks image tag v8.30.1 (Phase 6F regression)

### 🔧 Other Changes
- Merge pull request #2 — Phase 7 LSP Integration + gitleaks fix
- docs(contributing): LSP setup prerequisites (Phase 7 follow-up)
- docs(lsp-refs): bash-lsp + yaml-lsp reference docs (Phase 7F)
- docs(skills): LSP integration in 3 skills (Phase 7D)



## v5.7.0 (2026-04-14)

### ✨ Features
- feat(sessions): adopt CC 2.1.x native session features (Phase 4)
- feat(worktree): safety exit flow + semantic naming (Phase 3)
- feat(hooks): 6 new CC 2.1.x native events + regression test (Phase 2)
- feat(statusline): v6 layout + 3 new modules (Phase 1)
- feat(context-threshold): model-aware CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (Bug B)

### 🐛 Bug Fixes
- fix(tests): resolve 3 regressions from previous session phases
- fix(profiles): wire 10 pre-v5.7.0 baseline hooks (Phase 6F-bis)
- fix(makefile): deploy atlas-dev via make dev (Bug A)

### 🔧 Other Changes
- Merge pull request #1 — Phase 6 Code Quality SOTA (14 commits, CI green)
- test(shell): bats-core tests for 5 critical hooks (Phase 6H)
- ci(shellcheck): add L1 shellcheck step + Makefile targets (Phase 6G)
- refactor(shell): harden scripts/ root + convert zsh→bash (Phase 6A-3)
- refactor(shell): harden atlas-modules + convert zsh→bash (Phase 6A-2)
- refactor(shell): harden hooks/lib + run-hook (Phase 6A-1)
- ci(woodpecker): accept feat/* + fix/* branch patterns (Phase 6F+)
- refactor(shell): remove eval → bash -c, justify trusted eval (Phase 6B)
- refactor(config): IPs hardcodées → hostnames axoiq.com (Phase 6C)
- security(ci): gitleaks hard-fail + pin image to 8.21 (Phase 6F)
- refactor(pytest): consolidate config to pyproject.toml (Phase 6F)
- docs(contributing): senior dev onboarding guide (Phase 6E)
- chore(deps): add pyproject.toml with pytest + pyyaml (Phase 6D)
- docs(phase-5): CLAUDE.md + CHANGELOG + memory sync
- chore(release): bump to v5.7.0-alpha.1



## v5.7.0-alpha.1 (2026-04-14) — CC 2.1.107 Alignment Big-Bang (in progress)

Plan: `.blueprint/plans/sleepy-tumbling-hennessy.md` (9 phases, 54h, HITL gates)

### ✨ Phase 0 — Critical Bugs Hotfix
- fix(makefile): deploy atlas-dev-addon via `make dev` (L31 iteration loop, Bug A)
- feat(context-threshold): model-aware CLAUDE_AUTOCOMPACT_PCT_OVERRIDE (92% for 1M, 83% for 200K, Bug B)
- feat(hook): context-threshold-injector wires SessionStart + UserPromptSubmit
- feat(module): scripts/atlas-modules/context-threshold.sh — pure function resolver
- fix(settings): raise default CLAUDE_AUTOCOMPACT_PCT_OVERRIDE 83 → 92

### ✨ Phase 1 — Statusline Enrichment (v6 Layout)
- feat(statusline): 3 new CShip custom modules:
  - atlas-effort-module.sh (📊 low/med/high — CC v2.1.84)
  - atlas-cost-usd-module.sh (💰 $X.XX — CC v2.1.x cost.total_cost_usd)
  - atlas-200k-badge-module.sh (⚠️ 200K+ — CC v2.1.87 exceeds_200k_tokens)
- feat(cship): refresh_interval=10 for live rate_limits + cost updates
- fix(module): atlas-context-size detects Opus/Sonnet 4.6 as 1M by default
- fix(hook): session-start deploys 7 modules to ~/.local/share (was 3, fixed atlas-agents gap)
- refactor: consolidate cship.toml source (remove legacy cship-atlas.toml)

### ✨ Phase 2 — Native Hooks Integration (+7 events)
- feat(hook): WorktreeCreate / WorktreeRemove (v2.1.50) — lifecycle
- feat(hook): TeammateIdle / TaskCompleted (v2.1.33) — Agent Teams
- feat(hook): FileChanged (v2.1.83) — opt-in via ATLAS_FILE_CHANGED_ENABLED=1
- feat(hook): TaskCreated (v2.1.84) — usage metrics
- test(hooks): regression test prevents v5.6.1-style silent drops
- Event types in hooks.json: 15 → 22 (+7)

### ✨ Phase 3 — Worktrees + Safety Exit Flow
- feat(hook): worktree-exit-safe intercepts ExitWorktree (v2.1.72+)
  5 options offered: keep | merge | ship-all | PR | discard
  Prevents accidental data loss (CC native just offers keep|delete)
- feat(regex): enforce-worktree-name tightened (rejects date-only, placeholders)
  Accepts: (feat|fix|hotfix|chore|refactor|wip|sandbox)-[a-z0-9-]{3,50}
- feat(cli): atlas feat|fix|hotfix|chore|refactor <description>
  Launches `claude -w <prefix>-<slug> -n <prefix>-<slug>` with validation

### ✨ Phase 4 — Sessions + Native Bonus
- feat(cli): atlas resume <name> dual-mode (project path OR session name via --resume)
- docs(skill): session-pickup prefers /resume <name> (v2.0.64)
- docs(skill): experiment-loop delegates simple recurring to /loop + CronCreate (v2.1.89)
- docs(skill): ultrathink documents /effort (v2.1.84) as simple knob

### 📚 Phase 5 — Docs + Memory Sync
- docs: CLAUDE.md section "CC 2.1.x Native Features Adopted"
- docs: CHANGELOG.md comprehensive entry (this)
- memory: 4 new feedback files documenting lessons

### 🔄 Deferred Phases (6-9)
- Phase 6: Continuous code quality SOTA (10h)
- Phase 7: Continuous LSP integration (5h)
- Phase 8: SOTA senior patterns infrastructure (11h)
- Phase 9: Code hygiene + senior discipline (5h)


## v5.6.2 (2026-04-13)

### 🐛 Bug Fixes
- fix(hooks): wire subagent hooks in core profile (SP-AGENT-VIS unblock)

### 🔧 Other Changes
- refactor(hook): centralize atlas-core latest resolution in deploy block



## v5.6.1 (2026-04-13)

### 🐛 Bug Fixes
- fix(hook): SessionStart deploys statusline modules from highest cache version



## v5.6.0 (2026-04-13)

### ✨ Features
- feat(statusline): add update indicator "↗ X.Y.Z" when marketplace ahead



## v5.5.1 (2026-04-13)

### 🐛 Bug Fixes
- fix(statusline): resolve version from capabilities.json + filesystem scan

### 🔧 Other Changes
- test(agent-vis),build: sp-agent-vis phase 5 polish + build integration



## v5.5.0 (2026-04-13)

### ✨ Features
- feat(hooks,scripts): sp-agent-vis phase 4 — layer 3 cross-platform auto-tail



## v5.4.0 (2026-04-13)

### ✨ Features
- feat(cli,skill): sp-agent-vis phase 3 — layer 4 atlas agents cli



## v5.3.0 (2026-04-13)

### ✨ Features
- feat(statusline): sp-agent-vis phase 2 — layer 2 agents indicator



## v5.2.0 (2026-04-13)

### ✨ Features
- feat(hooks): sp-agent-vis phase 1 — subagent visibility telemetry layer
- feat(hooks,scripts): tdd guard hook + tighter haiku threshold



## v5.1.0 (2026-04-13)

### ✨ Features (SP-ATLAS-MASTER)
- **feat(master)**: Unified adaptive `atlas-assist` skill (single source in atlas-core).
  - Replaces 3× tier-specific atlas-assist (was generated per addon: core/dev/admin)
  - Adapts persona/pipeline/banner at runtime by reading `~/.atlas/runtime/capabilities.json`
  - Resolves `/atlas-admin-addon:atlas-assist` namespace conflict (`user-invocable` failure)
- **feat(discovery)**: Capability Discovery infrastructure
  - 3× `_addon-manifest.yaml` declarative metadata (tier, persona, pipeline, priority)
  - `scripts/atlas-discover-addons.sh` Bash scanner (~130 lines, idempotent)
  - `skills/discovery/SKILL.md` user-invocable inspector
  - SessionStart hook integrates scanner before badge construction
- **feat(ux)**: New `/atlas` slash command (user-invocable in atlas-core)
- **feat(build)**: Renamed build mode `v5` → `modular` (descriptive vs version-tied; `v5` kept as deprecated alias)
- **docs(quickstart)**: New `QUICKSTART-V5.md` (3 install patterns, troubleshooting, v4→v5 migration)

### 🐛 Bug Fixes
- **fix(statusline)**: `atlas-resolve-version.sh:22` typo (was `atlas-admin@atlas-admin-marketplace`,
  now correctly queries `atlas-admin@atlas-marketplace` with multi-key fallback for all 3 plugins).
  Resolves status bar showing v4.43.1 instead of actual v5.x.
- **fix(build)**: `atlas-resolve-version.sh` was referenced by session-start hook but never copied
  from `scripts/` to dist/. Added to runtime_scripts list (latent bug).

### 🔧 Other Changes
- Architecture: Core stays mandatory (25 skills + 1 agent base) — dev/admin addons optional
- Net code change: +325 / -487 lines (158 lines deduplicated)
- Build pipeline: rebuild reproducibility verified (sources fully synced to dist/)

---

## v5.0.3 (2026-04-12)

### 🐛 Bug Fixes
- fix(marketplace): remove unbuilt plugins (frontend/infra/enterprise)



## v5.0.2 (2026-04-12)

### 🐛 Bug Fixes
- fix(audit): v5 completeness — 4 missing skills, cc-native-features ref, clean dist/



## v5.0.1 (2026-04-12)

### 🐛 Bug Fixes
- fix(release): force VERSION=5.0.0 + fix breaking change regex + clean descriptions



## v4.46.1 (2026-04-12)

### 🐛 Bug Fixes
- fix(ci): update CI pipeline for v5 build (build.sh v5 replaces build.sh all)

### 🔧 Other Changes
- feat!(dedup): ATLAS v5.0.0 — Core + Addon architecture, zero duplication



## v4.46.0 (2026-04-12)

### ✨ Features
- feat(dedup): SP-DEDUP Phase 1 — v5 build system (core + addons)



## v4.45.0 (2026-04-12)

### ✨ Features
- feat(dedup): SP-DEDUP Phase 0 — skill classification + v5 profiles



## v4.44.1 (2026-04-12)

### 🐛 Bug Fixes
- fix(ci): sync legacy tier versions (worker/slim) in build step



## v4.44.0 (2026-04-12)

### ✨ Features
- feat(ci): 3-tier test strategy — L1 structural, L2 build, L3 integration



## v4.43.1 (2026-04-12)

### 🐛 Bug Fixes
- fix(ci): use Forgejo native port in WP agents (bypass Caddy SSO)
- fix(ci): escape shell vars in Woodpecker configs ($$ for shell, ${} for WP)
- fix(ci): migrate to Woodpecker CI + consolidate repo to axoiq/atlas-plugin

### 🔧 Other Changes
- ci: trigger Woodpecker CI pipeline [first run]



## v4.37.0 (2026-04-11)

### CC v2.1.101 Alignment Release

Leverages Claude Code v2.1.101 fixes to activate previously documented but non-functional features.

#### Agent Frontmatter Enforcement (Phase 1)
- 13 agents: added `disallowedTools` to YAML frontmatter (CC now enforces and explains)
- 8 read-only agents: `Write, Edit, NotebookEdit` denied
- 2 strict read-only: `Write, Edit, Bash, NotebookEdit` denied (domain-analyst, plan-reviewer)
- 5 write-capable agents: browser MCP tools excluded via glob `mcp__claude-in-chrome__*`, `mcp__plugin_playwright_playwright__*`
- 3 agents unchanged (plan-architect, experiment-runner, design-implementer — full access)

#### Skill Context Fork (Phase 2)
- 4 skills activated `context: fork` + `agent:` frontmatter (CC v2.1.101 fix)
- `codebase-audit` → forks to `context-scanner` agent (isolates massive output)
- `code-review` → forks to `code-reviewer` agent (independent review)
- `plan-review` → forks to `plan-reviewer` agent (unbiased scoring)
- `experiment-loop` → forks to `experiment-runner` agent (autonomous iterations)

#### Configuration (Phase 3)
- `settings.json`: added `API_TIMEOUT_MS: "600000"` (10 min, covers ultrathink)
- New preset: `scripts/presets/debug-tracing.json` (OTEL_LOG_* env vars for debug)
- `atlas-team` skill: documented MCP inheritance + worktree isolation (CC v2.1.101)
- `subagent-dispatch` skill: documented worktree isolation runtime parameter

#### Reference Update (Phase 4)
- `cc-native-features` ref: added v2.1.101 section (16 changes)

#### Cleanup (Phase 5)
- Version bump: 4.36.0 → 4.37.0
- `session-spawn`: documented `--resume <name>` accepts session titles

## v4.0.0 (2026-03-28)

### SP-ECO: ATLAS Ecosystem Architecture

From monolithic plugin to modular marketplace. Topic-based sessions. Self-improving system.

#### Plugin Split (Phase 1)
- 1 monolith (71 skills) → 6 domain plugins in unified marketplace
- `atlas-core` (22 skills, required), `atlas-dev` (22), `atlas-frontend` (8), `atlas-infra` (6+network), `atlas-enterprise` (14), `atlas-experiential` (4)
- build.sh: `./build.sh domains` builds all 6, `./build.sh domain core` builds one
- Makefile: `make dev-domains` for local install
- Hook filter fix: run-hook.sh wrapper regex for correct distribution (core=25, dev=7, frontend=2, infra=2, enterprise=0, experiential=0)

#### Topic-Based Sessions (Phase 2)
- Topic registry (`~/.atlas/topics.json`): create/resume/complete/archive lifecycle
- `atlas synapse {topic}` auto-detects and resumes existing topics
- `atlas dashboard` (alias: `dash`, `d`): tmux session table + topic/plugin counts
- session-start hook: ATLAS_TOPIC env injection + topic dir auto-creation
- session-pickup: topic-aware search (Step 0: .claude/topics/ first)
- session-retrospective: topic linking (handoff → topics.json + topics/ archive)

#### Marketplace Migration (Phase 3)
- `scripts/migrate-marketplace.sh`: 6-step migration with --dry-run, 3 presets (admin/dev/infra)
- atlas-doctor: Cat 13 domain plugin health (old marketplace detect, core dependency, orphan check)
- setup-wizard: plugin selection step with 6 presets (Developer, Full Stack, Admin, Infra, Custom, Skip)
- CI publish.yaml: builds + publishes 6 domains + 3 legacy tiers on tag push

#### Topic Memory (Phase 4)
- decision-log: dual write to `.claude/topics/{topic}/decisions.md`
- session-retrospective: context.md generation per topic
- memory-dream: `--topic {name}` consolidation + `.claude/topics/INDEX.md` generation
- finishing-branch: Step 2.5 preserves topic memory before worktree cleanup

#### Self-Improving System (Phase 5)
- Dream v5: Phase 2.7 (Workflow Audit) + D16 (Workflow Efficiency, 16D total)
- `self-propose` skill: MAPE-K monthly improvement proposals with HITL
- `focus-guard` hook: context-switch + energy alerts (verbosity-aware)
- Learning verbosity: `ATLAS_LEARNING_VERBOSITY` 1=silent, 2=semi (default), 3=full
- `mesh-diagnostics` skill: NetBird/Tailscale mesh health
- `network-audit` skill: DNS, ports, SSL, VLAN diagnostics
- ONBOARDING.md: team onboarding guide (6 phases, < 30 min)

**Stats**: 5 phases, 14 agents, ~155h effort, ~19h wall time, ~$23 token cost
**Breaking**: marketplace renamed `atlas-admin-marketplace` → `atlas-marketplace` (migration script provided)

## v3.42.0 (2026-03-27)

### Standalone Skills for Experiential Memory
- `episode-create`, `intuition-log`, `relationship-manager` as separate routable skills
- Added to admin profile for tier builds

## v3.41.0 (2026-03-27)

### ✨ SP-EXP: Experiential Memory Layer

Major evolution from technical vault to whole-person memory system.
Based on SOTA research: Letta/MemGPT (file-based validated), sleep-time compute
(UC Berkeley), ACT-R cognitive architecture mapping.

#### New Memory Types (4 → 9)
- `episode` — Narrative session memories with energy/mood/confidence context
- `intuition` — Gut feelings and emerging patterns with validation tracking
- `reflection` — Monthly growth retrospectives and meta-learning
- `relationship` — Deep relational context (trust, dynamics, interaction history)
- `temporal` — Facts with time-bounded validity windows

#### Dream Cycle v4 (8 → 11 phases)
- **Phase 2.6** — Experiential Audit (episode coverage, relationship freshness, temporal expiry)
- **Phase 3.7** — Experiential Synthesis (energy patterns, productivity cycles, intuition generation)
- **Phase 4.5** — Reflection Generator (monthly narrative synthesis)
- 6 new HITL gates (H19-H24), total 23

#### Health Scoring (10D → 15D)
- D11: Experiential Coverage (5%)
- D12: Relational Depth (4%)
- D13: Temporal Validity (5%)
- D14: Intuition Quality (3%)
- D15: Growth Trajectory (3%)
- dream-history.jsonl schema v4

#### New Standalone Commands
- `/atlas episode create` — Narrative episode with experiential frontmatter
- `/atlas intuition log` — Capture gut feelings with validation plan
- `/atlas relationship {person}` — Create/update deep relationship profiles

#### New Hooks
- `experiential-capture` (SessionEnd) — Accumulate signals, create pending summary
- `auto-learn` extended — Energy/mood/time_quality/confidence regex (FR+EN)
- `session-start` enhanced — Experiential context injection + sustainability alerts
- `prompt-intelligence` enhanced — Relationship surfacing + decision context

#### Enhanced Skills
- `session-retrospective` — Experiential capture section
- `user-profiler` — 3 experiential sub-dimensions (Energy Awareness, Relational Depth, Growth Tracking)

#### New Reference Documents (7)
- `experiential-schema.md` — Frontmatter schema (backward-compatible)
- `episode-template.md` — Episode creation guide
- `relationship-template.md` — Relationship file template
- `intuition-template.md` — Intuition capture guide
- `reflection-template.md` — Monthly reflection template
- `experiential-synthesis.md` — Phase 3.7 algorithms (H19-H23)
- Updated: `health-scoring.md`, `dream-report-v2.md`, `session-journal.md`

**Files**: 10 modified, 7 new | **SKILL.md**: 591 lines | **References**: 7→13

## v3.19.2 (2026-03-22)

### 🐛 Bug Fixes
- fix(marketplace): rename to atlas-admin for system-wide CC install



## v3.19.1 (2026-03-22)

### 🐛 Bug Fixes
- fix: assign frontend-workflow and test-orchestrator to dev tier

### 🔧 Other Changes
- docs: add .blueprint/ + rules + memory for AI maintainability



## v3.19.0 (2026-03-22)

### ✨ Features
- feat(onboarding,doctor): add Opus 4.6 CC settings validation (15 checks)



## v3.18.1 (2026-03-22)

### 🐛 Bug Fixes
- fix(build): add Forgejo repo URL to marketplace.json source



## v3.18.0 (2026-03-22)

### ✨ Features
- feat(statusline): dynamic version from CC marketplace registry



## v3.17.0 (2026-03-22)

### ✨ Features
- feat(skills): add test-orchestrator skill + gitignore pycache



## v3.16.0 (2026-03-22)

### ✨ Features
- feat(hooks): add version check notification on session start

### 🔧 Other Changes
- refactor(tests): replace hardcoded count thresholds with structural checks



## v3.15.2 (2026-03-22)

### 🐛 Bug Fixes
- fix(ci): replace hardcoded skill count gates with structural checks
- fix(release): auto-sync marketplace.json + plugin.json + VERSION on release



## v3.15.1 (2026-03-22)

### 🐛 Bug Fixes
- fix(release): auto-release now updates plugin.json version



## v3.15.0 (2026-03-22)

### ✨ Features
- feat(skills): add frontend-workflow skill + UX architecture gate



## v3.14.0 (2026-03-22)

### ✨ Features
- feat(hooks): add code-quality-check hook for dead imports and antipatterns

### 🔧 Other Changes
- chore(release): bump to v3.14.0 — sync marketplace + plugin.json versions [skip ci]



## v3.13.1 (2026-03-22)

### 🐛 Bug Fixes
- fix(ci): split workflow into ci.yaml + publish.yaml — fixes false failure status from skipped publish job



## v3.13.0 (2026-03-22)

### ✨ Features
- feat(pickup): search .blueprint/handoffs/ first, sort by date DESC, add Age column and priority indicators



## v3.12.0 (2026-03-21)

### ✨ Features
- feat(setup): add showClearContextOnPlanAccept validation to onboarding + doctor



## v3.11.2 (2026-03-21)

### 🐛 Bug Fixes
- fix(hooks): make async atlas-status-writer resilient to transient errors



## v3.11.1 (2026-03-21)

### 🐛 Bug Fixes
- fix(hooks): remove 'local' keyword outside function in atlas-status-writer

### 🔧 Other Changes
- test(hooks): validate hook file references in dist/ build artifacts



## v3.11.0 (2026-03-21)

### ✨ Features
- feat(plugin): add youtube-transcript skill + ci command + gitignore pycache



## v3.10.0 (2026-03-21)

### ✨ Features
- feat(tests): add smoke/strict test levels — CI skips strict by default



## v3.9.0 (2026-03-21)

### ✨ Features
- feat(ci): add build artifact caching between jobs
- feat(plugin): add /atlas ci command + CI integration

### 🐛 Bug Fixes
- fix(ci): use H1 heading pattern instead of skill reference in ci.md
- fix(ci): add backticks to invoke pattern in ci.md (test compat)
- fix(ci): remove template vars from ci.md command (test compat)

### 🔧 Other Changes
- revert(ci): remove actions/cache — incompatible with manual git clone



## v3.8.0 (2026-03-21)

### ✨ Features
- feat(ci): custom ci-atlas Docker image + simplified workflow



## v3.7.0 (2026-03-21)

### ✨ Features
- feat(hooks): add /rename suggestion with repo-version-branch in session-start
- feat(ci): add auto-release — conventional commits → SemVer → tag → Forgejo release
- feat(plugin): auto-unlock vault via keyring + punycode fix in session-start

### 🐛 Bug Fixes
- fix(ci): remove silent pip error suppression for better debug
- fix(ci): use ATLAS_FORGEJO_TOKEN for all jobs — GITHUB_TOKEN insufficient
- fix(ci): revert to GITHUB_TOKEN for build/test, use ATLAS_FORGEJO_TOKEN for release/publish
- fix(ci): add --break-system-packages for PEP 668 (Python 3.12+ in Ubuntu)
- fix(ci): use FORGEJO_TOKEN for git clone auth (GITHUB_TOKEN insufficient)
- fix(plugin): keyring dead code + secret management rules + require-secrets

### 🔧 Other Changes
- ci: trigger auto-release test (empty commit)


