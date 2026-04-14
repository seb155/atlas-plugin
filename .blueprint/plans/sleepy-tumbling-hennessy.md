# ATLAS Plugin v5.7.0 — CC 2.1.107 Big-Bang Alignment

> **Created**: 2026-04-14 06:52 EDT
> **Branch**: `feat/atlas-cc-2-1-x-alignment` (new)
> **Owner**: Seb Gagnon
> **Estimated**: 54h total (1 release big-bang v5.7.0, 9 phases). Phase 8 revised +3h (Option C HIGH+MEDIUM). Phase 9 ADDED per HITL 2026-04-14 (code hygiene + senior discipline).
> **Gate**: G1 (design) pending HITL → then implementation
> **HITL decisions 2026-04-14**: big-bang over staggered, session-level isolation (not agent), threshold via module+hook, FileChanged opt-in flag

---

## Context

ATLAS plugin actuellement v5.6.2 sur CC 2.1.107 (Opus 4.6 1M context). Scan complet des release notes CC 2.1.33 → 2.1.107 a identifié 25 features pertinentes, dont 2 BUGS CRITIQUES actifs et 4 axes d'amélioration. Les features CC natives ont rattrapé ~40% du scope du plugin — on doit décider où migrer vers natif vs garder custom pour simplification long-terme.

**Problèmes actifs**:
1. **BUG A** (P0): `make dev` ne deploie PAS `atlas-dev-addon` — seulement core+admin. Cause: Makefile ligne 31 itère `for plugin in atlas-core atlas-admin-addon` sans `atlas-dev-addon`. Résultat: atlas-dev reste stale à v5.6.1 même après un bump.
2. **BUG B** (P0): `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=83` hardcodé dans les settings plugin n'est pas model-aware. Pour Opus 4.6 1M, 83% = 830K tokens → perte de 90K tokens de marge utilisable (optimum 92% = 920K). Pire: l'AI ne reçoit aucune information sur le threshold actuel appliqué, ce qui explique la désynchronisation AI ↔ statusline (statusline dit 21%, AI peut paniquer avec heuristiques legacy 200K).

**Outcome attendu**:
- Bug A fixé: `make dev` deploie les 3 addons systématiquement
- Bug B fixé: threshold model-aware (92% pour 1M, 83% pour 200K), AI reçoit le threshold effectif via system-reminder injecté par hook
- Statusline: 7 champs JSON additionnels adoptés (context size, exceeds_200k, effort, cost USD, remaining %, added_dirs, subagent visibility)
- Hooks: 7 nouveaux événements CC wired (WorktreeCreate/Remove, TeammateIdle, TaskCompleted, FileChanged, TaskCreated + vérif CwdChanged wiring)
- Worktrees: migration graduelle vers `--worktree` natif + `isolation: worktree` frontmatter sur agents dispatcher
- Sessions: adoption `-n`, `/resume <name>`, `/loop`, `/effort` natifs

---

## Recommended Approach — BIG-BANG v5.7.0

Livrer 1 release complète (21h sur ~1 semaine). HITL Seb à chaque gate de phase, PR atomique sur `feat/atlas-cc-2-1-x-alignment` → `dev` → `main` (CI green).

```
v5.7.0 BIG-BANG (46h / ~2 semaines, 8 phases, gates HITL 15min)
  ├─ Phase 0 — Critical bugs hotfix            (2h) G0 HITL ━┓
  ├─ Phase 1 — Statusline enrichment           (4h) G1 HITL  ┃
  ├─ Phase 2 — Native hooks integration        (6h) G2 HITL  ┃ Tous
  ├─ Phase 3 — Worktrees + safety exit flow    (5h) G3 HITL  ┃ dans
  ├─ Phase 4 — Sessions + native bonus         (4h) G4 HITL  ┃ 1 PR
  ├─ Phase 5 — Docs sync (CLAUDE.md/MEMORY)    (2h) G5 HITL  ┃ atomique
  ├─ Phase 6 — Continuous code quality        (10h) G6 HITL  ┃
  ├─ Phase 7 — Continuous LSP integration      (5h) G7 HITL  ┃
  ├─ Phase 8 — SOTA senior patterns (revised) (11h) G8 HITL  ┃
  └─ Phase 9 — Code hygiene + senior discipline (5h) G9 HITL ━┛
                                              ─────
                                               54h

Phase 8 revised after self-review (Option C HIGH+MEDIUM fixes):
  - Fix overlap 8B1 ↔ 6B2 (merge in dispatcher)
  - Fix effort underestimate (AST via tree-sitter, +2.5h)
  - Fix skill overlap (enhance code-review, not create new)
  - Add metrics baseline scan (Phase 8A5)
  - Add cross-project scoping (.atlas/sota-config.yaml)
  - Expand anti-patterns catalog 10 → 20+
  - Add opt-out patterns for generated code
  - Add book references (Fowler, Uncle Bob, Evans)
```

Chaque phase = HITL gate court avant passage à la suivante. Pas de merge final jusqu'à Phase 5 complète.

---

## Phase 0 — Critical Bugs Hotfix (v5.6.3) — 2h

**Goal**: Débloquer `make dev` complet + rendre context threshold model-aware + injecter visibility à l'AI.

### Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/Makefile` L31 | `for plugin in atlas-core atlas-admin-addon` → `for plugin in atlas-core atlas-dev-addon atlas-admin-addon` |
| `~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-modules/context-threshold.sh` (NEW) | Module dynamique: lit `$CLAUDE_MODEL_ID` ou `capabilities.json`, retourne `92` pour 1M suffix, `83` sinon |
| `~/workspace_atlas/projects/atlas-dev-plugin/settings.json` + 3 dist/*/settings.json | Retirer hardcoded `"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "83"` → lire via `$(bash scripts/atlas-modules/context-threshold.sh)` injection OU via nouveau hook |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/context-threshold-injector` (NEW) | SessionStart hook qui écrit `~/.atlas/state/context-threshold.json` ET injecte system-reminder "Your model has 1M context; compaction at 920K tokens (92%)" dans UserPromptSubmit |
| `~/workspace_atlas/projects/atlas-dev-plugin/profiles/core.yaml` | Déclarer `context-threshold-injector` dans hooks: array (CRITIQUE — sinon drop silencieux per `feedback_profile_yaml_hook_declaration.md`) |
| `~/workspace_atlas/projects/atlas-dev-plugin/VERSION` | `5.6.2` → `5.6.3` |
| `~/workspace_atlas/projects/atlas-dev-plugin/CHANGELOG.md` | Entry v5.6.3 hotfix |

### Verification

```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin
make dev
# Expect: "✅ atlas-dev → ~/.claude/plugins/cache/.../atlas-dev/5.6.3" in output

ls ~/.claude/plugins/cache/atlas-marketplace/atlas-dev/
# Expect: 5.6.3 directory present

# Restart CC, check threshold visibility
cat ~/.atlas/state/context-threshold.json
# Expect: {"model": "opus-4-6[1m]", "threshold_pct": 92, "context_size": 1048576}

# Verify AI awareness (query in CC)
# "What's my current context threshold?" → AI should answer 92% / 920K tokens
```

### Rollback

Tag `v5.6.2-stable` avant merge. Si regression: `git revert` + republish patch.

---

## Phase 1 — Statusline Enrichment (v5.7.0) — 4h

**Goal**: Surface 7 JSON fields inutilisés, résoudre drift config (deployed v5 < source v3), ajouter refreshInterval.

### Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/scripts/cship-atlas.toml` | Add `$cship.context_window.remaining_percentage`, `$cship.exceeds_200k_tokens` (badge `⚠️ 200K+`), `$cship.cost.total_cost_usd`, `$cship.effort` (📊 low/med/high indicator), `$cship.workspace.added_dirs`. Add `[cship] refresh_interval = 10` |
| `~/workspace_atlas/projects/atlas-dev-plugin/build.sh` (ou deploy step) | S'assurer que cship-atlas.toml est copié dans `~/.config/cship.toml` à chaque `make dev` (fix drift v5→v3) |
| `~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-context-size-module.sh` | Valider détection 1M: si `context_window.size > 500000` dans JSON input, dire "1M" (au lieu du fallback env var) |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/statusline-setup/SKILL.md` | Documenter nouveaux champs + refresh_interval |
| `~/workspace_atlas/projects/atlas-dev-plugin/dist/atlas-admin-addon/skills/statusline-setup/SKILL.md` | Sync avec source |

### Verification

```bash
diff ~/.config/cship.toml ~/workspace_atlas/projects/atlas-dev-plugin/scripts/cship-atlas.toml
# Expect: empty (no drift)

# Restart CC, check row 2 displays new fields
# Expected format: "████░░...21%  $0.24  📊high  📈 0 0  5h: 2% | 7d: 0%"
```

### Rollback risk

**Low** — CShip skip gracefully les champs inconnus. Retour arrière: restaurer toml précédent.

---

## Phase 2 — Native Hooks Integration (v5.7.0) — 6h

**Goal**: Wirer 7 événements CC 2.1.33+. Consolider hooks custom → natifs.

### Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/hooks.json` | Add blocks: `WorktreeCreate`, `WorktreeRemove`, `TeammateIdle`, `TaskCompleted`, `FileChanged`, `TaskCreated` (vérifier si `CwdChanged` est réellement wired — hook script existe mais agent 2 l'a listé comme manquant) |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/worktree-setup` (NEW) | `WorktreeCreate` handler: valider nom (via `enforce-worktree-name` reuse), copier `.env` + CLAUDE.md symlinks, notifier user |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/worktree-cleanup-native` (NEW) | `WorktreeRemove` handler: remplacer `cleanup-worktrees` (Stop handler) par version event-driven |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/team-idle-notify` (NEW) | `TeammateIdle` handler pour atlas-team skill |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/task-completed-metrics` (NEW) | `TaskCompleted` pour metrics agent-team |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/file-change-test-trigger` (NEW) | `FileChanged` pour reactive test runner (optionnel, flagged) |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/task-created-metrics` (NEW) | `TaskCreated` pour stats TaskCreate tool invocation |
| `~/workspace_atlas/projects/atlas-dev-plugin/profiles/core.yaml` | Add hooks: section entries pour les nouveaux hooks core-level |
| `~/workspace_atlas/projects/atlas-dev-plugin/profiles/dev-addon.yaml` | Ajouter hooks dev-specific (file-change-test-trigger) |
| `~/workspace_atlas/projects/atlas-dev-plugin/profiles/admin-addon.yaml` | Ajouter hooks admin (worktree-setup, team-*, task-*) |
| `~/workspace_atlas/projects/atlas-dev-plugin/tests/test_hooks_declared_in_profiles.py` (NEW) | Pre-commit test — détecte hook dans hooks.json mais absent de profile YAML (évite regression v5.6.1 bug) |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/cleanup-worktrees` | Déprécier (move to `.deprecated/`) — backward-compat 1 cycle mineur |

### Verification

```bash
python3 scripts/filter-hooks-json.py --validate
# Expect: 0 undeclared hooks

python3 -m pytest tests/test_hooks_declared_in_profiles.py -x -q
# Expect: PASS

# Smoke test worktree lifecycle
cd ~/workspace_atlas/projects/atlas/synapse
claude -w test-hook-worktree --print "status"
# Expect: WorktreeCreate fires (logs in ~/.atlas/logs/worktree-events.log)
# Expect after exit: WorktreeRemove fires (cleanup verified)
```

### Rollback risk

**Medium** — profile YAML oversight = drop silencieux. Mitigation: test suite obligatoire avant push + pre-commit hook.

---

## Phase 3 — Session-Level Worktrees + Safety (v5.7.0) — 5h

**Goal**: Migrer `git-worktrees` skill vers pattern session-level (`claude -w <name>`). **Ajouter 2 safety nets critiques** (HITL 2026-04-14):

1. **Naming sémantique enforced** — rejeter noms date-based (ex: `0414`), imposer préfixe (feat/fix/hotfix/chore) + description
2. **Exit flow safe** — intercepter `WorktreeRemove` natif (qui propose delete), wrapper avec options: `keep | merge | ship-all | discard`

### Philosophy (HITL-approved)

```
User ─► claude -w feat-xyz  (session isolation via worktree)
          │
          └─► Session principale dans worktree feat-xyz
                ├─ Agent plan-architect  ─┐
                ├─ Agent team-engineer   ─┤  collaborent
                ├─ Agent design-impl.    ─┤  sur MÊME
                └─ Agent team-reviewer   ─┘  worktree
```

Pas de forks agent-level, pas de merge conflicts artificiels, pas de sync inter-worktrees.

### Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/git-worktrees/SKILL.md` | Thin wrapper: documente pattern `claude -w <name>` (session isolation), `EnterWorktree`/`ExitWorktree` tools pour switch mid-session. Exemples workflow feature branch. Pas d'agent frontmatter. |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/refs/cc-native-features/SKILL.md` | Doc pattern: "session-level worktree = isolation unit. Agents sont outils collaboratifs dans la session." |
| `~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-cli.sh` | **Subcommands enforcés**: `atlas feat <desc>` → `claude -w feat-<desc> -n feat-<desc>`, `atlas fix <bug>` → `claude -w fix-<bug>`, `atlas hotfix <ver>` → `claude -w hotfix-<ver>`, `atlas chore <desc>`. **Rejeter** inputs sans prefix valide via regex check. |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/enforce-worktree-name` (exists) | Renforcer: regex `^(feat|fix|hotfix|chore|refactor)-[a-z0-9-]{3,50}$`. Reject date-only names. Suggest format on reject. |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/worktree-exit-safe` (NEW) | **Hook `ExitWorktree` intercept**: bloque delete pur. Affiche prompt via AskUserQuestion avec 5 options: `keep` (default, safe) / `merge to dev` / `ship-all` / `create PR` / `discard` (explicit confirm requis si uncommitted). |
| `~/workspace_atlas/projects/atlas-dev-plugin/profiles/admin-addon.yaml` | Déclarer `worktree-exit-safe` dans hooks: array |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/finishing-branch/SKILL.md` | Intégration: `worktree-exit-safe` hook délègue à ce skill pour option "ship-all" |
| (Optionnel) `~/workspace_atlas/projects/atlas-dev-plugin/scripts/worktree-sparse-paths.sh` | Helper pour monorepo atlas/ |

### Exit Flow (nouveau pattern)

```
User fait `exit` dans CC session worktree
          │
          ▼
Hook worktree-exit-safe fire (intercept WorktreeRemove)
          │
          ▼
AskUserQuestion:
  ┌─────────────────────────────────────────────┐
  │ Worktree `feat-cc-alignment` a des changes.  │
  │ Comment procéder ?                           │
  │                                               │
  │  ◉ Keep worktree (default, safe)             │
  │  ○ Merge to dev + cleanup                    │
  │  ○ Ship-all (commit + push + deploy)         │
  │  ○ Create PR (push to feature branch)        │
  │  ○ Discard (DANGER — requires typed confirm)│
  └─────────────────────────────────────────────┘
          │
          ▼
Selon choix → invoke skill correspondant ou no-op (keep)
```

### Verification

```bash
# Test naming enforcement
atlas feat 0414  # Reject: "name too short or date-only"
atlas feat cc-alignment  # Accept: creates feat-cc-alignment worktree

# Test exit flow
atlas feat test-safe-exit
# Inside: make a change, then exit
# Expect: prompt with 5 options, NOT silent delete
```

### Rollback risk

**Low** — hooks additifs. Si `worktree-exit-safe` fail, CC fallback = prompt natif (pas pire que status quo).

---

## Phase 4 — Sessions + Native Bonus (v5.7.0) — 4h

**Goal**: Adopter `/rename`, `/resume <name>`, `-n`, `/loop`, `/effort` natifs. Intégrer avec skills existants.

### Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-cli.sh` | Add `-n <session-name>` passthrough vers `claude -n "$name"`. Alias `atlas resume <name>` → `claude --resume <name>` |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/session-pickup/SKILL.md` | Intégrer `/resume <name>` path natif; fallback handoff file si pas nommé |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/experiment-loop/SKILL.md` | Déléguer scheduling à `/loop` + `CronCreate` CC; garder HITL wrapper ATLAS |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/ultrathink/SKILL.md` | Documenter `/effort` comme entrée native; ultrathink reste pour frameworks structurés (ADR, risk, compare) |
| `~/workspace_atlas/projects/atlas-dev-plugin/agents/*/AGENT.md` | Add `memory: user|project|local` frontmatter (v2.1.33) — scope per agent purpose |

### Verification

```bash
atlas -n test-session "hello"
atlas resume test-session
# Expect: round-trip session reload

claude --list-sessions | grep test-session
# Expect: session listed
```

### Rollback risk

**Very low** — toutes additifs.

---

## Phase 5 — Docs + Memory Sync (v5.7.0) — 2h

**Goal**: Sync documentation projet (CLAUDE.md synapse) + memory ATLAS + plugin docs pour que tous les changements Phase 0-4 soient trouvables par futures sessions AI.

### Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/CLAUDE.md` (plugin root) | Add section "CC 2.1.x Native Features Adopted" listant les natives integrations (statusline fields, hooks, worktrees, sessions) |
| `~/workspace_atlas/projects/atlas-dev-plugin/CHANGELOG.md` | Entry v5.7.0 détaillée (6 phases, breaking changes flag si applicable) |
| `~/workspace_atlas/projects/atlas-dev-plugin/README.md` | Update si le README documente les workflows worktree/session |
| `.blueprint/plans/sleepy-tumbling-hennessy.md` (ce plan) | Marker "Status: COMPLETED" après impl |
| `~/workspace_atlas/projects/atlas/synapse/CLAUDE.md` (project) | Add rule "Worktrees: utiliser `atlas feat/fix/hotfix <desc>` — nommage sémantique enforced. Exit flow: voir Phase 3 safety hook." |
| `memory/feedback_atlas_v57_breaking_changes.md` (NEW) | Log les breaking changes et migration guide si applicable |
| `memory/feedback_cc_native_adoption.md` (NEW) | Document pattern "prefer native over custom" — liste ce qui a été migré |
| `memory/feedback_worktree_naming_policy.md` (NEW) | Log la naming policy + raison (date-based rejection) |
| `memory/feedback_worktree_exit_safety.md` (NEW) | Log le safety flow (5 options) + raison (prevent accidental delete) |
| `memory/MEMORY.md` | Update index: add entries pointing to new feedback files. Garder sous 25KB limit. |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/refs/cc-native-features/SKILL.md` | Update list des features CC 2.1.x adoptées (pour futures skills qui y réfèrent) |

### Verification

```bash
# Validate memory integrity
bash scripts/validate-memory.sh  # si existe
# OR: cat memory/MEMORY.md | wc -c  # Expect: <25000 (under limit)

# Validate plugin docs
grep -l "v5.7.0" ~/workspace_atlas/projects/atlas-dev-plugin/*.md
# Expect: CLAUDE.md + CHANGELOG.md + possibly README.md

# Commit shows proper scope
git log --oneline -10
# Expect: commits tagged feat(plugin), fix(makefile), docs(memory), etc.
```

### Rollback risk

**None** — docs only. Revert trivial.

---

## Phase 6 — Code Quality SOTA / Senior-Ready (v5.7.0) — 10h

**Goal**: Hardening du plugin pour passer la review d'un programmeur senior. Base de research web SOTA 2026 (shellcheck, bats-core, set -euo pipefail) + audit interne qui a identifié 10 HIGH/MEDIUM improvements.

### Sub-phases

| Sub-phase | Description | Effort |
|-----------|-------------|--------|
| 6A Shell hardening | Add `#!/usr/bin/env bash` + `set -euo pipefail` + trap EXIT cleanup sur TOUS les hook scripts + `scripts/atlas-modules/*.sh`. Quote all vars. | 3h |
| 6B Remove eval | `scripts/atlas-modules/subcommands.sh` utilise `eval` 2x — remplacer par `command -v` + switch case. | 1h |
| 6C Config hardening | Retirer IP hardcodée `192.168.10.76` → env var `WP_HOST`. Ajouter input validation sur hooks UserPromptSubmit. | 1h |
| 6D Deps management | Créer `pyproject.toml` (pytest≥7, pyyaml≥6). Pin versions. Document Python 3.11+ range. | 0.5h |
| 6E CONTRIBUTING.md | Shell module contract + hook registration + test execution + version bump workflow. | 1h |
| 6F CI hardening | Gitleaks `failure: ignore` → hard-stop. Register pytest marks (skill, strict, broken). | 0.5h |
| 6G Shellcheck integration | Add to `.woodpecker/ci.yml` L1 structural step. Non-blocking initial → hard-fail après 1 semaine. | 1h |
| 6H Bats-core shell tests | Add `tests/shell/` avec bats tests pour hooks critiques (session-start, pre-compact-context, context-threshold-injector, worktree-exit-safe). | 2h |

### Fichiers principaux

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/*` (40+ scripts) | 6A: shebang + set + quoting standard |
| `~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-modules/*.sh` | 6A + 6B: hardening + remove eval |
| `~/workspace_atlas/projects/atlas-dev-plugin/dist/atlas-admin-addon/hooks/ci-auto-monitor/handler.sh` | 6C: IP hardcoded → env var |
| `~/workspace_atlas/projects/atlas-dev-plugin/pyproject.toml` (NEW) | 6D: deps + metadata |
| `~/workspace_atlas/projects/atlas-dev-plugin/CONTRIBUTING.md` (NEW) | 6E: onboarding senior devs |
| `~/workspace_atlas/projects/atlas-dev-plugin/.woodpecker/security.yml` | 6F: hard-fail gitleaks |
| `~/workspace_atlas/projects/atlas-dev-plugin/tests/pytest.ini` | 6F: register marks |
| `~/workspace_atlas/projects/atlas-dev-plugin/.woodpecker/ci.yml` | 6G: add shellcheck step |
| `~/workspace_atlas/projects/atlas-dev-plugin/tests/shell/*.bats` (NEW) | 6H: bats test suite |
| `~/workspace_atlas/projects/atlas-dev-plugin/Makefile` | 6G: `make shellcheck` + `make test-shell` targets |

### Verification

```bash
# 6A: Shellcheck clean
shellcheck scripts/atlas-modules/*.sh hooks/*/handler.sh hooks/session-start hooks/pre-compact-context
# Expect: 0 errors

# 6D: Deps installable
pip install -e .[dev]
# Expect: success

# 6F: Pytest marks registered
python3 -m pytest --markers | grep -E "skill|strict|broken"
# Expect: 3 custom marks listed

# 6G: CI shellcheck runs
grep -A2 "shellcheck" .woodpecker/ci.yml
# Expect: shellcheck step present

# 6H: Bats tests pass
bats tests/shell/
# Expect: all tests pass

# 6F: Gitleaks hard-fail
grep "failure:" .woodpecker/security.yml
# Expect: no "ignore" value
```

### Rollback risk

**Medium** — shell hardening peut révéler des bugs latents (strict mode fail sur unset vars). Mitigation: rollout par groupe de 5-10 scripts, test smoke après chaque groupe.

### Sources SOTA 2026

- Shell scripting: [ShellCheck 2026 best practices](https://www.turbogeek.co.uk/how-to-install-and-use-shellcheck-for-safer-bash-scripts-in-2026/), [Bash best practices OneUptime](https://oneuptime.com/blog/post/2026-02-13-bash-best-practices/view)
- Testing: [bats-core](https://github.com/bats-core/bats-core), [Testing shell scripts with Bats](https://medium.com/@pimterry/testing-your-shell-scripts-with-bats-abfca9bdc5b9)
- Plugin architecture: [Claude Code plugins README](https://github.com/anthropics/claude-code/blob/main/plugins/README.md), [Claude Code hooks reference](https://code.claude.com/docs/en/hooks)

---

## Phase 7 — LSP Integration (v5.7.0) — 5h

**Goal**: Déclarer et intégrer Language Servers pour les stacks qu'ATLAS manipule. CC v2.1.74+ expose un tool `LSP` avec `operation: goToDefinition | findReferences | hover | workspaceSymbol | documentSymbol`. Plugins peuvent ship leurs propres LSP servers dans `plugin.json`.

### État actuel (audit)

```
Plugin LSP status:
  has_lsp: []  (atlas-core, atlas-dev, atlas-admin)
  AUCUN LSP server déclaré dans les 3 manifests

Documentation:
  ✓ skills/refs/external-tools/typescript-lsp.md (uses LSP tool)
  ✓ skills/refs/external-tools/jdtls-lsp.md (Java)
  ✓ skills/plugin-builder/references/lsp-deployment-guide.md

Gap: le plugin SAIT comment utiliser LSP mais ne ship AUCUN server.
```

### Sub-phases

| Sub-phase | Description | Effort |
|-----------|-------------|--------|
| 7A Bash LSP (critique) | Declare `bash-language-server` in atlas-dev manifest. Ship npm install instruction. Utile pour nos 40+ hook scripts. | 1.5h |
| 7B YAML LSP | Declare `yaml-language-server` in atlas-core manifest. Utile pour profiles/*.yaml, hooks.json schema validation. | 1h |
| 7C Python LSP | Declare `pyright` ou `pylsp` in atlas-dev manifest (optionnel, pour tests Python + Synapse backend). | 1h |
| 7D Skill integration | Update `code-review`, `code-analysis`, `systematic-debugging` skills pour suggérer LSP operations au user. | 1h |
| 7E Hook integration | PostToolUse[Edit] pour fichiers `.sh`/`.bash` → query LSP diagnostics → si errors, warn user. | 0.5h |

### Fichiers à modifier

| Fichier | Changement |
|---------|-----------|
| `~/workspace_atlas/projects/atlas-dev-plugin/dist/atlas-dev-addon/.claude-plugin/plugin.json` | Add `"lsps": [{"name": "bash-language-server", "command": "bash-language-server", "args": ["start"], "fileExtensions": [".sh", ".bash"]}]` |
| `~/workspace_atlas/projects/atlas-dev-plugin/dist/atlas-core/.claude-plugin/plugin.json` | Add `yaml-language-server` entry (fileExtensions: .yaml, .yml) |
| `~/workspace_atlas/projects/atlas-dev-plugin/dist/atlas-dev-addon/.claude-plugin/plugin.json` | Add `pyright` entry (fileExtensions: .py) |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/code-review/SKILL.md` | Documenter utilisation LSP: `LSP(operation: "findReferences", filePath: X, line: N)` avant rename |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/code-analysis/SKILL.md` | Documenter LSP workspaceSymbol pour dead code detection |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/systematic-debugging/SKILL.md` | LSP goToDefinition comme step 2 de l'observation |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/lsp-diagnostics-shell` (NEW) | PostToolUse[Edit] sur fichiers shell: query LSP, log diagnostics si errors |
| `~/workspace_atlas/projects/atlas-dev-plugin/profiles/dev-addon.yaml` | Declare `lsp-diagnostics-shell` hook |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/refs/external-tools/bash-lsp.md` (NEW) | Ref doc analogue à typescript-lsp.md pour bash LSP |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/refs/external-tools/yaml-lsp.md` (NEW) | Ref doc YAML LSP |

### Prerequisites (user setup)

```bash
# User doit installer les LSP servers localement:
npm install -g bash-language-server yaml-language-server
pip install pyright
```

→ Documenter dans CONTRIBUTING.md (Phase 6E) + `atlas-doctor` skill check.

### Verification

```bash
# 7A: Bash LSP declared
jq '.lsps' ~/.claude/plugins/cache/atlas-marketplace/atlas-dev/5.7.0/.claude-plugin/plugin.json
# Expect: array with bash-language-server

# 7D: Skills updated
grep -l "LSP(operation:" ~/workspace_atlas/projects/atlas-dev-plugin/skills/{code-review,code-analysis,systematic-debugging}/SKILL.md
# Expect: 3 files

# 7E: Hook wired
grep "lsp-diagnostics-shell" ~/workspace_atlas/projects/atlas-dev-plugin/profiles/dev-addon.yaml
# Expect: hook declared

# Integration test: edit a .sh file avec erreur, vérifier diagnostic
echo 'echo $undefined_var' > /tmp/test.sh
# Via CC Edit tool, hook fires, LSP diagnostic should appear
```

### Rollback risk

**Low** — LSPs sont additifs, fail gracefully si binaire absent. Hook `lsp-diagnostics-shell` non-blocking (warn only).

### Benefits

- **Bash LSP** = linting live de nos 40+ hook scripts (complément à shellcheck)
- **YAML LSP** = validation live de profiles/*.yaml + hooks.json (évite regression silencieuse)
- **Python LSP** = intellisense dans skills Python (Synapse backend integration)
- **LSP-driven skills** = precision supérieure pour refactors (findReferences before rename)

---

## Phase 8 — SOTA Senior Patterns Infrastructure (v5.7.0) — 8h

**Goal**: Transformer ATLAS en **proactive senior co-pilot**. Détecte anti-patterns lors d'édition (hook), suggère refactors SOTA (skill), enforce patterns SOLID/Clean/DDD/Hexagonal (CI). S'applique à TOUT code (existing + future + any project using ATLAS), pas juste le plugin lui-même.

### Principe

```
Dev écrit ou modifie code (dans n'importe quel projet avec ATLAS actif)
    ↓
Hook postedit-pattern-detector fire (PostToolUse[Edit])
    ↓
Analyse code: god class, long method, duplicated code, magic numbers,
             primitive obsession, feature envy, shotgun surgery, etc.
    ↓
Si smell détecté → warn user + suggest refactor (Extract Method, etc.)
    ↓
Log decision dans .claude/decisions.jsonl (accept/dismiss/later)
    ↓
Skill sota-code-patterns peut être invoked à la demande
    ↓
Périodiquement, cron audit → suggest refactor SOTA + update skills
```

### Sub-phases

| Sub | Effort | Description |
|-----|--------|-------------|
| 8A1 | 1h | Skill `sota-code-patterns` (NEW) — guides Clean/Hexagonal/DDD/Layered architecture selection. Quand utiliser chaque. Pragmatic tradeoffs |
| 8A2 | 1h | Skill `senior-review-checklist` (NEW) — checklist systematic code review: SOLID compliance, code smells, design smells, naming, cohesion/coupling, testability |
| 8A3 | 1h | Ref doc `skills/refs/sota-architecture-patterns/` (NEW) — examples Clean/Hexagonal/DDD with file structures + code snippets |
| 8A4 | 1h | Ref doc `skills/refs/code-smells-catalog/` (NEW) — 20+ anti-patterns registry (God Class, Long Method, Feature Envy, Shotgun Surgery, Primitive Obsession, Magic Numbers, Copy-Paste Programming, etc.) |
| 8B1 | 1.5h | Hook `hooks/postedit-pattern-detector` (NEW) — scan edited code, detect common smells via AST/regex, suggest refactor via system-reminder |
| 8B2 | 1h | Skill `code-review` ENHANCEMENT — integrate senior-review-checklist as mandatory step |
| 8B3 | 0.5h | Hook `hooks/pre-commit-architecture-check` — detect obvious violations (e.g., 1000-line file, 200-line function) + block commit |
| 8B4 | 1h | CI step `.woodpecker/sota-review.yml` — metrics: cyclomatic complexity < 10, cohesion/coupling report, file size limits |

### Anti-Patterns Catalog (Phase 8A4 preview)

| Anti-pattern | Detection | Refactor |
|--------------|-----------|----------|
| God Class / Blob | File > 500 lines, class > 300 lines, > 20 methods | Extract classes, split by responsibility |
| Long Method | Function > 50 lines, cyclomatic > 10 | Extract Method, Replace Conditional with Polymorphism |
| Feature Envy | Method uses more data from another class than own | Move Method |
| Shotgun Surgery | One change requires edits in many places | Move Field/Method, Consolidate |
| Primitive Obsession | Many primitives instead of domain objects | Replace Primitive with Object, Value Object |
| Magic Numbers | Hardcoded numeric constants | Replace Magic Number with Named Constant |
| Copy-Paste | Duplicated code blocks | Extract Method, Extract Class |
| Dead Code | Unused functions/classes | Remove after verification |
| Deep Nesting | > 3 levels of nested conditionals | Early return, Guard Clauses |
| Long Parameter List | > 4 parameters | Introduce Parameter Object |

### Architecture Patterns (Phase 8A1 scope)

- **Clean Architecture** (Uncle Bob) — dependency rule, layers (entities, use cases, interface adapters, frameworks)
- **Hexagonal** (Ports & Adapters) — sweet spot simplicité/puissance, testable, replace-friendly
- **Onion Architecture** (Palermo 2008) — core business layer indépendant, separation of concerns
- **DDD** (Domain-Driven Design) — bounded contexts, aggregates, domain events, ubiquitous language
- **CQRS** — separation read/write models pour systems complexes
- **Layered/N-Tier** — pragmatic pour CRUD apps, simple
- **Event-Driven** — async workflows, pub-sub

**When to use which** (documented in skill):
- Clean/Hexagonal = default pour domaines complexes évolutifs
- DDD = si équipe peut investir en ubiquitous language + modeling
- Layered = CRUD simple, bootstrap rapide
- Event-Driven = async workflows, webhooks, microservices

### Fichiers clés

| Fichier | Action |
|---------|--------|
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/sota-code-patterns/SKILL.md` (NEW) | Architecture pattern selection guide |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/senior-review-checklist/SKILL.md` (NEW) | Code review checklist systematic |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/refs/sota-architecture-patterns/` (NEW dir) | Examples + tradeoffs |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/refs/code-smells-catalog/` (NEW dir) | Anti-patterns registry |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/postedit-pattern-detector` (NEW) | Live smell detection |
| `~/workspace_atlas/projects/atlas-dev-plugin/hooks/pre-commit-architecture-check` (NEW) | Block commits with violations |
| `~/workspace_atlas/projects/atlas-dev-plugin/skills/code-review/SKILL.md` | Integrate senior-review-checklist |
| `~/workspace_atlas/projects/atlas-dev-plugin/profiles/{core,dev-addon,admin-addon}.yaml` | Declare new skills + hooks |
| `~/workspace_atlas/projects/atlas-dev-plugin/.woodpecker/sota-review.yml` (NEW) | Architecture metrics CI step |

### Verification

```bash
# 8A1: Skill available
ls ~/.claude/plugins/cache/atlas-marketplace/atlas-dev/5.7.0/skills/sota-code-patterns/
# Expect: SKILL.md + refs

# 8B1: Hook fires on edit with smell
echo "def foo(): $(python3 -c 'print("pass\n" * 60)')" > /tmp/long.py
# Via CC Edit tool: expect warn "Long Method detected (>50 lines)"

# 8B3: Pre-commit blocks big files
echo "$(python3 -c 'print("x = 1\n" * 600)')" > test_big.py
git add test_big.py && git commit -m "test"
# Expect: BLOCKED with "File > 500 lines, split by responsibility"

# 8B4: CI metrics pass
make sota-review
# Expect: cyclomatic complexity max < 10, file size max < 500
```

### Rollback risk

**Medium** — initial deployment peut créer beaucoup de warnings sur existing code. Mitigation:
- `postedit-pattern-detector` commence en mode `warn` (pas block)
- `pre-commit-architecture-check` avec grandfathered list pour existing files
- Tolerance threshold configurable dans `settings.json`
- Rollout gradual: 1 semaine warn-only avant activation block

### Sources SOTA 2026

- Architecture: [Hexagonal vs Clean 2026 — DEV.to](https://dev.to/dev_tips/hexagonal-vs-clean-vs-onion-which-one-actually-survives-your-app-in-2026-273f), [Senior Engineer Roadmap 2026](https://hayksimonyan.substack.com/p/senior-software-engineer-roadmap)
- Patterns: [Clean Architecture — Martin](https://github.com/mehdihadeli/awesome-software-architecture/blob/main/docs/clean-architecture.md), [Domain-Driven Hexagon](https://github.com/Sairyss/domain-driven-hexagon)
- Code smells: [Code Smells and Anti-Patterns — Codacy](https://blog.codacy.com/code-smells-and-anti-patterns), [Code Smell Detection 2026 — CodeAnt](https://www.codeant.ai/blogs/what-is-code-smell-detection)
- Reviews: [Code Review Checklist — Gocodeo](https://www.gocodeo.com/post/the-ultimate-code-review-checklist), [AI Code Review Tools 2026](https://toolradar.com/guides/best-ai-code-review-tools)

### Benefits (cross-project)

- **Applies to ATLAS plugin itself** (eat our own dog food)
- **Applies to Synapse** (backend/frontend refactor guidance)
- **Applies to AXOIQ ecosystem** (axoiq-cloud, atlas-dev-plugin, synapse-pitch)
- **Applies to any project** that has ATLAS installed (reusable senior infrastructure)

---

## Phase 9 — Code Hygiene + Senior Discipline (v5.7.0) — 5h

**Goal**: ATLAS enforce micro-level discipline comme un senior dev rigoureux le ferait. Phase 8 = macro (architecture). Phase 9 = micro (naming, folder structure, docs, variable names). Ensemble = rigueur totale.

### Scope

```
NAMING: variables, functions, files, folders, classes, constants, hooks
STRUCTURE: feature-based, test colocation, separation of concerns
DOCUMENTATION: docstrings, comments WHY-not-WHAT, README per module
HYGIENE: no abbreviations, early return, explicit types, SRP functions
```

### Sub-phases

| Sub | Effort | Description |
|-----|--------|-------------|
| 9A1 | 0.5h | Skill `code-hygiene-rules` (NEW) — guidance par langage |
| 9A2 | 0.5h | Ref `refs/naming-conventions/{python,typescript,bash,yaml}.md` (NEW, 4 files) |
| 9A3 | 0.5h | Ref `refs/folder-structure-patterns/SKILL.md` (NEW) — feature-based, colocation |
| 9A4 | 0.5h | Skill `senior-discipline-checklist` (NEW) — rigueur systematic |
| 9B1 | 1.5h | Hook `naming-enforcer` (NEW) — PostToolUse[Write\|Edit] regex scan naming conventions |
| 9B2 | 1h | Hook `folder-structure-validator` (NEW) — PostToolUse[Write] detect misplaced files |
| 9B3 | 0.5h | Hook `doc-quality-gate` (NEW) — PostToolUse[Write .py\|.ts] check docstrings/JSDoc |

### Detection Examples

```
❌ naming-enforcer catches:
   Python:  def getData()          → def get_data()
   TS:      function calc_total()  → function calculateTotal()
   File:    user_profile.tsx       → user-profile.tsx
   Var:     let d = new Date()     → const currentDate = new Date()
   Folder:  src/utls/              → src/utils/

❌ folder-structure-validator catches:
   /components/UserList.tsx        → prefer /users/list/ (feature-based)
   /Button.tsx (at root)           → missing feature folder
   /tests/test_auth.py isolated    → prefer colocation (next to source)

❌ doc-quality-gate catches:
   def process_order(order):       → missing docstring
     return order.total * 1.15

   export function makeAPICall() { → missing JSDoc on public API
     ...
   }
```

### Cross-Project Configuration

```yaml
# .atlas/hygiene-config.yaml (per-project)
naming:
  variables_python: snake_case
  variables_typescript: camelCase
  files: kebab-case
  allow_abbreviations: [id, url, api, db, ui]  # team-agreed exceptions
folder_structure:
  tests_colocation: true
  feature_based: true
documentation:
  require_docstrings_public: true
  require_readme_per_module: false
  comment_style: why_not_what
```

### Fichiers clés

| Fichier | Type |
|---------|------|
| `skills/code-hygiene-rules/SKILL.md` | NEW |
| `skills/senior-discipline-checklist/SKILL.md` | NEW |
| `skills/refs/naming-conventions/{python,typescript,bash,yaml}.md` | NEW (4) |
| `skills/refs/folder-structure-patterns/SKILL.md` | NEW |
| `hooks/naming-enforcer` | NEW |
| `hooks/folder-structure-validator` | NEW |
| `hooks/doc-quality-gate` | NEW |
| `profiles/{core,dev-addon,admin-addon}.yaml` | UPDATE declare +3 hooks |
| `.atlas/hygiene-config.yaml` (schema template) | NEW |

### Verification

```bash
# 9B1: Naming enforcer catches bad name
echo "def getData(): pass" > /tmp/bad.py
# Edit via CC → WARN "Python functions should be snake_case: getData → get_data"

# 9B2: Folder structure validator catches misplaced file
# Create /components/RandomButton.tsx in project with feature_based: true
# → WARN "Prefer feature-based: /buttons/random/ or similar"

# 9B3: Doc gate catches missing docstring
echo "def process_order(order): return order.total" > /tmp/nodoc.py
# Edit via CC → WARN "Public function missing docstring"
```

### Rollback risk

**Medium** — initial deployment peut créer beaucoup de warnings sur existing code. Mitigation:
- Start warn-only mode pour 1 semaine
- Per-project `.atlas/hygiene-config.yaml` tolerance tunable
- Grandfathered files list pour legacy code
- Allow_abbreviations exceptions team-agreed

### Relation avec Phase 8

| Phase | Focus | Examples |
|-------|-------|----------|
| 8 | MACRO architecture | Clean/Hexagonal/DDD, SOLID violations, god classes |
| 9 | MICRO hygiene | Naming, folder structure, docstrings, variable choice |

Complémentaires, pas redondants. Senior dev fait les 2 passes à la review.

---

## Risks + Mitigation

| Risque | Severity | Mitigation |
|--------|----------|-----------|
| Profile YAML oversight drop hooks (v5.6.1 lesson) | HIGH | Pre-commit test obligatoire (Phase 2) |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` dynamique break existing sessions | MEDIUM | Ship Phase 0 en premier, tester solo 24h avant v5.7.0 |
| cship.toml drift cause display regression | LOW | build.sh enforce deployment step (Phase 1) |
| Agent `isolation: worktree` crée worktrees orphelins | MEDIUM | Phase 2 WorktreeRemove cleanup MUST ship avant Phase 3 |
| Native features CC v2.1.x changent en v2.1.108+ | LOW | Pin CC version requirement ≥2.1.100 dans plugin.json |

---

## Dependencies

```
Phase 0 ───► [Phase 1 ⟷ Phase 2] ───► Phase 3 ───► Phase 4
  │                                     │
  └── Blocker: everything ──────────────┘
      downstream needs 3 addons

  Phase 1 ⟷ Phase 2: parallélisables (no file overlap)
  Phase 3 needs Phase 2 (WorktreeCreate/Remove events wired)
  Phase 4 fully independent (can slip)
```

---

## Verification E2E (après toutes phases)

```bash
# 1. Plugin deployment complet
cd ~/workspace_atlas/projects/atlas-dev-plugin && make dev
ls ~/.claude/plugins/cache/atlas-marketplace/atlas-{core,dev,admin}/5.7.1
# Expect: 3 dirs, all present

# 2. Statusline reflects real 1M context
# Restart CC, query "show context status"
# Statusline row 2 expected: "████░░░...X%  $X.XX  📊high  📈 lines  5h:X% | 7d:X%"
# Threshold row: should see "1M context, compact @ 92%" somewhere

# 3. Hooks coverage
jq '[.hooks[].events[]] | unique' ~/workspace_atlas/projects/atlas-dev-plugin/hooks/hooks.json
# Expect: ≥22 unique events (was 15)

# 4. Worktree lifecycle natif
claude -w feat-smoke-test -n smoke-session
# Inside: /rename works, work, exit → worktree cleaned
claude --resume smoke-session
# Expect: resumed into same worktree

# 5. Test suite
python3 -m pytest tests/ -x -q --tb=short
# Expect: all pass
```

---

## Open Questions (HITL)

1. **Threshold dynamique**: préfère `context-threshold.sh` module (lit `capabilities.json`) OU direct inline env var writer dans SessionStart hook ?
2. **cleanup-worktrees legacy**: soft-deprecate (move to `.deprecated/`) OU hard-delete en v5.7.0 ?
3. **FileChanged hook** (Phase 2): worth shipping, ou defer à v5.8.0 (usage incertain) ?
4. **Release cadence**: v5.6.3 hotfix + v5.7.0 dans 1 semaine OK, OU un seul big-bang v5.7.0 avec tout inclus ?
5. **Agents `isolation: worktree`**: apply à TOUS les dispatcher agents, OU seulement ceux qui modifient le code (exclude researcher/reviewer) ?

---

## Critical Files Reference

```
Phase 0:
  ~/workspace_atlas/projects/atlas-dev-plugin/Makefile
  ~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-modules/context-threshold.sh (NEW)
  ~/workspace_atlas/projects/atlas-dev-plugin/hooks/context-threshold-injector (NEW)
  ~/workspace_atlas/projects/atlas-dev-plugin/profiles/core.yaml

Phase 1:
  ~/workspace_atlas/projects/atlas-dev-plugin/scripts/cship-atlas.toml
  ~/workspace_atlas/projects/atlas-dev-plugin/build.sh
  ~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-context-size-module.sh

Phase 2:
  ~/workspace_atlas/projects/atlas-dev-plugin/hooks/hooks.json
  ~/workspace_atlas/projects/atlas-dev-plugin/hooks/worktree-setup (NEW)
  ~/workspace_atlas/projects/atlas-dev-plugin/hooks/worktree-cleanup-native (NEW)
  ~/workspace_atlas/projects/atlas-dev-plugin/hooks/team-idle-notify (NEW)
  ~/workspace_atlas/projects/atlas-dev-plugin/hooks/task-completed-metrics (NEW)
  ~/workspace_atlas/projects/atlas-dev-plugin/profiles/{core,dev-addon,admin-addon}.yaml
  ~/workspace_atlas/projects/atlas-dev-plugin/tests/test_hooks_declared_in_profiles.py (NEW)

Phase 3:
  ~/workspace_atlas/projects/atlas-dev-plugin/skills/git-worktrees/SKILL.md
  ~/workspace_atlas/projects/atlas-dev-plugin/agents/{plan-architect,design-implementer,team-engineer,team-reviewer}/AGENT.md

Phase 4:
  ~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-cli.sh
  ~/workspace_atlas/projects/atlas-dev-plugin/skills/{session-pickup,experiment-loop,ultrathink}/SKILL.md
```

---

_Plan SSoT. Gate G1 HITL pending Seb approval before Phase 0 execution._
