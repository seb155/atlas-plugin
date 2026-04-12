# Changelog

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


