---
name: Robust Percolating Stearns — Phase 6 Implementation Plan
description: Sub-plan d'implémentation Phase 6 (Code Quality SOTA / Senior-Ready) extrait de sleepy-tumbling-hennessy.md. Ordre optimisé risque-croissant + décisions architecturales (zsh→bash conversion, ~118 scripts).
parent_plan: sleepy-tumbling-hennessy.md
phase: 6
scope_hours: 10
date: 2026-04-14
branch: feat/atlas-cc-2-1-x-alignment
repo: /home/sgagnon/workspace_atlas/projects/atlas-dev-plugin
---

# Plan d'implémentation — Phase 6 (Code Quality SOTA)

## Context

**Pourquoi ce plan**: Phase 6 du plan `sleepy-tumbling-hennessy.md` pose les guardrails "senior-ready" d'ATLAS v5.7.0 (shellcheck, bats, set -euo pipefail, eval-free, pyproject.toml, CONTRIBUTING.md). Les Phases 7-9 qui suivent (LSP, SOTA patterns, hygiène) dépendent de cette fondation. Un audit codebase montre un scope 3× plus large que prévu (**118 scripts** vs 40+ annoncés).

**Décisions architecturales validées** (HITL 2026-04-14 08:45):
- Convertir les 22 scripts zsh → bash (aucune syntax zsh-specific détectée)
- Ordre optimisé risque-croissant: docs → marks → config → eval → shell → CI → bats (pas 6A→6H séquentiel)

**État de départ** (clean HEAD sur `feat/atlas-cc-2-1-x-alignment`):
- HEAD: `9f5a899 docs(phase-5): CLAUDE.md + CHANGELOG + memory sync`
- 8 commits ahead de main (Phases 0-5)
- Working tree clean

## Scope précis (validé par audit Explore)

| Artefact | Chiffre | Phase |
|----------|---------|-------|
| Scripts shell totaux | 118 | 6A |
| Scripts sans `set -euo pipefail` | 22 | 6A |
| Scripts zsh → bash à convertir | 22 | 6A |
| `eval` occurrences | 16 / 6 fichiers | 6B |
| IPs hardcodées `192.168.10.*` | 6 / 3 fichiers | 6C |
| Marks pytest non-déclarés | 5 (`integration`, `skill`, `strict`, `broken`, `build`) | 6F |
| Hooks non-déclarés (baseline) | 10 | 6F-bis |
| `pyproject.toml` | MISSING | 6D |
| `CONTRIBUTING.md` | MISSING | 6E |
| `tests/shell/` | MISSING | 6H |

## Pre-work (0.5h) — Tooling

Avant tout travail, installer outils localement + dans image CI.

```bash
# Local (pour dev/test)
sudo apt-get install shellcheck bats-core
shellcheck --version  # expect >= 0.8
bats --version        # expect >= 1.5

# CI: ajouter à python:3.13-slim via apt-get (inline) ou image wrapper
# Décision inline first, image optimization en Phase 8 si rebuild fréquent
```

**Verification**: `command -v shellcheck && command -v bats` retourne 0.

---

## Ordre d'exécution optimisé (8 sous-phases, 9.5h)

### Groupe 1 — Docs & Metadata (risque zéro, 1.5h)

#### 6D — pyproject.toml (0.5h)

**Files à créer**:
- `~/workspace_atlas/projects/atlas-dev-plugin/pyproject.toml` (NEW)

**Contenu**:
```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "atlas-dev-plugin"
version = "5.7.0-alpha.1"  # sync with VERSION file
description = "ATLAS AI engineering assistant — Claude Code plugin"
requires-python = ">=3.11"
dependencies = [
    "pyyaml>=6.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4",
    "pytest-xdist>=3.5",
]

[tool.pytest.ini_options]
# Will move pytest.ini content here later if desired
```

**Verification**:
```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin
pip install -e .[dev]  # should succeed
python3 -c "import yaml; print(yaml.__version__)"
```

#### 6E — CONTRIBUTING.md (1h)

**Files à créer**:
- `~/workspace_atlas/projects/atlas-dev-plugin/CONTRIBUTING.md` (NEW)

**Sections obligatoires**:
1. Shell Module Contract — template skeleton pour nouveau hook/module
2. Hook Registration — étapes wire-up (hooks.json + profiles/*.yaml + tests)
3. Test Execution — commandes pytest + bats + shellcheck
4. Version Bump Workflow — VERSION file + CHANGELOG + `make publish-patch/minor`
5. Commit Conventions — lien vers `feedback_commit_conventions.md`
6. Shellcheck Rules — quoi disable via `# shellcheck disable=`, quand
7. Security — no secrets in commits, gitleaks pre-commit, env vars

**Verification**: `grep -c "^## " CONTRIBUTING.md` retourne >= 7.

---

### Groupe 2 — CI hardening (risque faible, 1h)

#### 6F — Pytest marks + Gitleaks hard-fail (0.5h)

**Files modifiés**:
- `tests/pytest.ini` — ajouter 5 marks
- `.woodpecker/security.yml` L13 — retirer `failure: ignore`

**Changes pytest.ini**:
```ini
markers =
    slow: deselect with -m "not slow"
    hook: execute hook scripts via subprocess
    e2e: end-to-end, require dist/ artifacts
    integration: integration tests (skipped in L1)
    skill: tests specific to skill frontmatter/content
    strict: strict-mode validation tests
    broken: known-broken tests (skip in L1)
    build: build artifact validation (L2)
```

**Verification**:
```bash
python3 -m pytest --markers | grep -E "integration|skill|strict|broken|build"
# Expect: 5 marks listed, no warnings
python3 -m pytest tests/ --strict-markers -x -q 2>&1 | grep -c "unknown mark"
# Expect: 0
```

#### 6F-bis — 10 hooks baseline cleanup (0.5h)

**Context**: `tests/test_hooks_declared_in_profiles.py` a un baseline 10-hook pour laisser passer la tech debt pre-v5.7.0. On wire les 10 maintenant.

**Files modifiés**:
- `profiles/core.yaml` — déclarer ~7 hooks
- `profiles/admin.yaml` — déclarer ~2 hooks
- `profiles/dev.yaml` — déclarer ~1 hook
- `tests/test_hooks_declared_in_profiles.py` — vider `KNOWN_UNDECLARED_BASELINE`

**Verification**:
```bash
python3 -m pytest tests/test_hooks_declared_in_profiles.py -v
# Expect: both tests PASS, baseline = set()
```

---

### Groupe 3 — Surgical fixes (risque moyen, 2h)

#### 6C — Config hardening (1h)

**Files modifiés**:
- `scripts/setup-wizard.sh` — `192.168.10.75:3000` → `${ATLAS_FORGEJO_API:-forgejo.axoiq.com}`
- `scripts/atlas-modules/subcommands.sh` — `192.168.10.76:8000` → `${WP_HOST:-ci.axoiq.com}`
- `hooks/ci-auto-monitor/handler.sh` — `192.168.10.76:8000` → `${WP_HOST:-ci.axoiq.com}` (L curl example)
- `hooks/session-start` — input validation sur env vars (sanitize user input)

**Verification**:
```bash
grep -r "192\.168\." hooks/ scripts/ | grep -v "\.md:" | grep -v "#"
# Expect: 0 matches (hors comments docs)
```

#### 6B — Remove eval (1h)

**16 occurrences / 6 fichiers**:

| Fichier | Lignes | Remplacement |
|---------|--------|--------------|
| `scripts/atlas-bootstrap.sh` | 393, 402 | `eval "$cmd" &>/dev/null` → `command -v "$cmd" > /dev/null` |
| `scripts/atlas-modules/subcommands.sh` | 812, 970, 980 | `eval "$2"` → switch case explicite sur `$1` |
| `scripts/atlas-modules/launcher.sh` | 462 | `eval "$(direnv export zsh)"` → garder (direnv intentionnel, flag `# shellcheck disable=SC2046`) |
| `scripts/atlas-e2e-validate.sh` | 17 | `eval "$@"` → `"$@"` direct si args shell-safe |
| `scripts/bw-login.sh` | 3-5 | comments only, no change |
| `scripts/setup-wizard.sh` | 744 | comment only, no change |

**Verification**:
```bash
grep -rn "eval " scripts/ hooks/ | grep -v "^\s*#" | wc -l
# Expect: 1 (direnv line seule, avec shellcheck disable)
```

---

### Groupe 4 — Shell hardening (risque élevé, 3h)

#### 6A — Shell hardening rollout (3h)

**Scope**: 118 scripts → homogénéiser à `#!/usr/bin/env bash` + `set -euo pipefail` + `trap EXIT cleanup` + quoting strict.

**Sous-tâches par groupes de ~25-30 scripts** (4 rounds, smoke test après chaque):

| Round | Target | Count | Smoke check |
|-------|--------|-------|-------------|
| 6A-1 | `hooks/lib/*.sh` + `hooks/run-hook.sh` (scripts partagés) | ~5 | `bash -n hooks/lib/*.sh && pytest tests/test_hooks_schema.py -x` |
| 6A-2 | `scripts/atlas-modules/*.sh` (9 modules + conversion zsh→bash) | ~9 | `atlas list` + `atlas status` via REPL |
| 6A-3 | `scripts/*.sh` (root scripts incl atlas-cli.sh, setup-wizard) | ~15 | Smoke: `./build.sh v5` + `make dev` |
| 6A-4 | `hooks/*/handler.sh` + hooks sans extension (remaining) | ~90 | Full `pytest tests/test_hook_behavior.py -x` |

**Pattern standard appliqué à chaque script**:
```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Optional: trap cleanup
# trap 'rc=$?; rm -f "$tmpfile" 2>/dev/null; exit $rc' EXIT
```

**Conversion zsh → bash (22 scripts)**:
- Remplacer shebang `#!/usr/bin/env zsh` → `#!/usr/bin/env bash`
- Remplacer `${(L)var}` → `${var,,}` (lowercase)
- Remplacer `${(U)var}` → `${var^^}` (uppercase)
- Remplacer `autoload -U colors` → variables directement
- (Audit Explore confirme: AUCUNE syntax zsh-specific trouvée → conversion triviale)

**Rollback strategy**:
- Chaque round = 1 commit séparé. Si smoke fail: `git revert HEAD`.
- Avant round 6A-1: créer tag `safety/pre-p6a`.

**Verification cumulative**:
```bash
# Syntax check tous scripts
for f in $(find hooks/ scripts/ -type f -executable -o -name "*.sh"); do
  bash -n "$f" 2>&1 | grep -v "^$" && echo "FAIL: $f"
done
# Expect: 0 FAIL lines

# Pytest full suite
make test
# Expect: 251/251 PASS (no regression)
```

---

### Groupe 5 — CI integration (risque faible, 3h)

#### 6G — Shellcheck CI step (1h)

**Files modifiés**:
- `.woodpecker/ci.yml` — ajouter step `shellcheck` en L1 structural

**Snippet à ajouter (après l1-structural)**:
```yaml
  l1-shellcheck:
    image: koalaman/shellcheck-alpine:stable
    commands:
      - shellcheck -x scripts/atlas-modules/*.sh hooks/lib/*.sh hooks/*/handler.sh
      - shellcheck -x scripts/atlas-cli.sh scripts/setup-wizard.sh scripts/build.sh
    failure: ignore  # soft-fail pour 1 semaine puis hard-fail en Phase 8
```

**Makefile target parallel** (pour local dev):
```make
shellcheck:
	@shellcheck -x scripts/atlas-modules/*.sh hooks/lib/*.sh hooks/*/handler.sh

test-shell:
	@bats tests/shell/
```

**Verification**:
```bash
make shellcheck 2>&1 | tee /tmp/shellcheck.log
# Expect: 0 errors (après round 6A)
grep -c "^[A-Z]" /tmp/shellcheck.log  # count of findings
# Expect: ~0-5 (warnings tolérés pour le moment)
```

#### 6H — Bats-core shell tests (2h)

**Files à créer**:
- `tests/shell/test_session_start.bats` (NEW)
- `tests/shell/test_pre_compact_context.bats` (NEW)
- `tests/shell/test_context_threshold_injector.bats` (NEW)
- `tests/shell/test_worktree_exit_safe.bats` (NEW)
- `tests/shell/test_atlas_cli_core.bats` (NEW, cover atlas list / atlas status)

**Template bats** (session-start exemple):
```bash
#!/usr/bin/env bats

setup() {
    export PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    export HOME_TMP="$(mktemp -d)"
    export HOME="$HOME_TMP"
}

teardown() {
    rm -rf "$HOME_TMP"
}

@test "session-start writes capabilities.json" {
    run "$PLUGIN_ROOT/hooks/session-start"
    [ "$status" -eq 0 ]
    [ -f "$HOME/.atlas/runtime/capabilities.json" ]
}

@test "session-start detects tier correctly" {
    # ... more cases
}
```

**Verification**:
```bash
bats tests/shell/
# Expect: all tests pass (5 files, ~20 tests total)

make test-shell
# Expect: same as above via Makefile
```

---

## HITL Gates

Suivant pattern validé session précédente (15min entre phases):

| Gate | Après | Critère pass |
|------|-------|--------------|
| G1 | 6D+6E (docs) | Fichiers créés, `pip install -e .[dev]` pass |
| G2 | 6F (marks) | Pytest --strict-markers green |
| G3 | 6F-bis (10 hooks) | Baseline = set(), tests pass |
| G4 | 6C+6B (surgical) | Grep 0 IP, 1 eval restant (direnv), tests pass |
| G5 | 6A-1 (hooks/lib) | Smoke pytest hooks pass |
| G6 | 6A-2 (atlas-modules) | `atlas list` fonctionne |
| G7 | 6A-3 (scripts root) | `./build.sh v5` + `make dev` pass |
| G8 | 6A-4 (hooks handlers) | Full pytest 251/251 pass |
| G9 | 6G (CI shellcheck) | CI pipeline green |
| G10 | 6H (bats) | `bats tests/shell/` pass |

Chaque gate: Seb valide via AskUserQuestion (pass / retry / abort).

---

## Files à modifier (résumé)

### Créations (4 fichiers)
- `pyproject.toml` (6D)
- `CONTRIBUTING.md` (6E)
- `.woodpecker/ci.yml` — ajout step shellcheck (6G, modification)
- `tests/shell/*.bats` — 5 fichiers (6H)

### Modifications
- `tests/pytest.ini` — +5 marks (6F)
- `.woodpecker/security.yml` — retirer `failure: ignore` (6F)
- `tests/test_hooks_declared_in_profiles.py` — baseline cleanup (6F-bis)
- `profiles/{core,dev,admin}.yaml` — wire 10 hooks (6F-bis)
- `scripts/setup-wizard.sh` + `scripts/atlas-modules/subcommands.sh` + `hooks/ci-auto-monitor/handler.sh` — IP → env var (6C)
- `hooks/session-start` — input validation (6C)
- `scripts/atlas-bootstrap.sh` + `scripts/atlas-modules/{subcommands,launcher}.sh` + `scripts/atlas-e2e-validate.sh` — remove eval (6B)
- 118 scripts shell — shell hardening + zsh→bash (6A)
- `Makefile` — `shellcheck` + `test-shell` targets (6G)

---

## Verification globale (post-Phase 6)

```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin

# 1. Syntax check tous scripts
for f in $(find hooks/ scripts/ -type f \( -name "*.sh" -o -executable \) ! -path "*/node_modules/*"); do
  bash -n "$f" || echo "FAIL: $f"
done | grep -c FAIL  # Expect: 0

# 2. Pas de shebang zsh (sauf intentionnel)
grep -r "^#!/usr/bin/env zsh" hooks/ scripts/ | wc -l  # Expect: 0

# 3. Pas d'eval non-disabled
grep -rn "^\s*eval " hooks/ scripts/ | grep -v "shellcheck disable" | wc -l  # Expect: 0

# 4. Pas d'IP hardcodée
grep -rn "192\.168\." hooks/ scripts/ | grep -v "^\s*#" | wc -l  # Expect: 0

# 5. Python tooling
pip install -e .[dev]
python3 -m pytest --markers | grep -E "integration|skill|strict|broken|build" | wc -l  # Expect: 5
python3 -m pytest --strict-markers tests/ -x -q  # Expect: 251/251 pass

# 6. Shellcheck clean
make shellcheck  # Expect: 0 errors

# 7. Bats green
make test-shell  # Expect: all pass

# 8. CI full run (après push)
# Expect: L1 + L2 + shellcheck + security tous green
```

---

## Cost estimate

| Groupe | Sous-phases | Effort | Cumulatif |
|--------|-------------|--------|-----------|
| Pre-work | Install tools | 0.5h | 0.5h |
| 1 Docs | 6D + 6E | 1.5h | 2.0h |
| 2 CI hardening | 6F + 6F-bis | 1.0h | 3.0h |
| 3 Surgical | 6C + 6B | 2.0h | 5.0h |
| 4 Shell | 6A (4 rounds) | 3.0h | 8.0h |
| 5 CI integration | 6G + 6H | 3.0h | 11.0h |
| **Total** | 8 sous-phases + pre-work | **10-11h** | |

**Budget vs réalité session précédente**: 21h estimé → 8h réel = 2.6× plus rapide. Projection P6: 10-11h estimé → ~4-5h réel probable.

---

## Commits plan

| # | Message | Scope |
|---|---------|-------|
| 1 | `chore(deps): add pyproject.toml with pytest + pyyaml` | 6D |
| 2 | `docs(contributing): senior dev onboarding guide` | 6E |
| 3 | `test(pytest): register 5 custom marks + strict-markers` | 6F |
| 4 | `security(ci): gitleaks hard-fail (remove failure:ignore)` | 6F |
| 5 | `fix(profiles): wire 10 baseline hooks (cleanup regression)` | 6F-bis |
| 6 | `refactor(config): IPs hardcodées → env vars WP_HOST/FORGEJO_API` | 6C |
| 7 | `refactor(shell): remove eval 16 occurrences (5/6 fichiers)` | 6B |
| 8 | `refactor(shell): harden hooks/lib + run-hook (round 6A-1)` | 6A-1 |
| 9 | `refactor(shell): harden atlas-modules + convert zsh→bash (6A-2)` | 6A-2 |
| 10 | `refactor(shell): harden scripts/ root + setup-wizard (6A-3)` | 6A-3 |
| 11 | `refactor(shell): harden hooks/*/handler.sh remaining (6A-4)` | 6A-4 |
| 12 | `ci(shellcheck): add L1 shellcheck step (soft-fail 1 week)` | 6G |
| 13 | `test(shell): bats-core tests for 5 critical hooks` | 6H |

13 commits propres, chacun < 15 fichiers, rollback facile.

---

## Références

- **Parent plan**: `.blueprint/plans/sleepy-tumbling-hennessy.md` (Phase 6 section L328-398)
- **Handoff source**: `memory/handoff-2026-04-14-atlas-v570-phases-0-5.md`
- **Audit Explore rapports**: inline dans cette session (118 scripts, 16 eval, 251 tests)
- **SOTA references** (du parent plan):
  - ShellCheck 2026 best practices: https://www.turbogeek.co.uk/how-to-install-and-use-shellcheck-for-safer-bash-scripts-in-2026/
  - bats-core: https://github.com/bats-core/bats-core
  - Claude Code plugins README: https://github.com/anthropics/claude-code/blob/main/plugins/README.md

---

*Updated: 2026-04-14 08:45 EDT — Plan d'implémentation Phase 6, après audit Explore 3-agents + HITL décisions zsh-conversion + ordre optimisé*
