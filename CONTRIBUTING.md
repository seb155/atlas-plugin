# Contributing to ATLAS

> **Audience**: Senior developers contributing to the ATLAS Claude Code plugin (core + dev + admin addons).
> **Language**: Shell (bash, strict mode), Python 3.11+, YAML.
> **Last updated**: 2026-04-14 (v5.7.0-alpha.1)

This guide covers the contract for adding/modifying skills, hooks, agents, and CI. Follow it. Reviewers will block PRs that skip sections.

---

## 0. Dev Setup

The repo targets Python 3.11+. On Ubuntu 24.04+ (PEP 668 externally-managed), use a venv:

```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin
python3 -m venv .venv
source .venv/bin/activate
pip install -e '.[dev]'      # pulls pyproject.toml deps
```

For shellcheck + bats-core (system packages):

```bash
sudo apt-get install shellcheck bats
```

Verify the setup:

```bash
shellcheck --version   # expect >= 0.8
bats --version         # expect >= 1.5
pytest --markers       # no "unknown mark" warnings
```

---

## 1. Shell Module Contract

Every new shell script (hooks, scripts/atlas-modules, scripts/) MUST follow this skeleton:

```bash
#!/usr/bin/env bash
# <module-name> — one-line purpose
# Sourced-by / Called-by: <caller>
# Exit codes: 0 success | 2 config error | 3 external failure

set -euo pipefail
IFS=$'\n\t'

# Optional cleanup (recommended if creating temp files)
# trap 'rc=$?; rm -f "$tmpfile" 2>/dev/null || true; exit $rc' EXIT

# --- Constants (UPPER_SNAKE) ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Functions (snake_case, `_` prefix = private) ---
_my_helper() {
    local arg="${1:?usage: _my_helper <arg>}"
    # ...
}

# --- Main ---
main() {
    _my_helper "$@"
}

main "$@"
```

**Rules**:
- ALL variables quoted: `"$var"` not `$var`.
- NO `eval` without `# shellcheck disable=SC2046` + justification comment.
- NO hardcoded IPs. Use env vars with sensible defaults: `${WP_HOST:-ci.axoiq.com}`.
- NO silent failures. Use `|| return 3` / `|| exit 2` with a log line.
- `zsh` shebang is DEPRECATED. Convert to bash unless syntax strictly requires zsh.

---

## 2. Hook Registration

A hook is wired in THREE places (all mandatory):

1. **`hooks.json`** — declares the event + handler path + matcher.
2. **`profiles/{tier}.yaml`** — declares which addon owns the hook (`hooks:` array).
3. **`tests/test_hooks_declared_in_profiles.py`** — validates wiring (auto-runs in L1).

**Skipping step 2** = hook is silently filtered out of `dist/` by `scripts/filter-hooks-json.py`. This is the #1 integration bug (see `lesson_profile_yaml_hook_declaration.md`).

**Checklist** when adding a new hook:

- [ ] Handler script follows Shell Module Contract (section 1).
- [ ] Added to `hooks.json` under correct event type.
- [ ] Added to `profiles/{core,dev,admin}.yaml` under `hooks:` array.
- [ ] Unit test in `tests/test_hook_behavior.py` (subprocess invocation).
- [ ] Documented in hook's folder `README.md` (if complex).

---

## 3. Test Execution

| Tier | Command | Scope | When |
|------|---------|-------|------|
| L1 structural | `make test-l1` | fast, `-m "not build and not integration and not broken"` | every push |
| Build | `make test` | full pytest suite | pre-merge |
| Shell lint | `make shellcheck` | all shell scripts | pre-merge |
| Shell tests | `make test-shell` | bats-core | pre-merge |
| CI (Woodpecker) | auto on push | L1 + build-v5 + L2 + L3 (integration) | push/PR |

**Pytest invocations**:

```bash
# Strict mode (recommended): catches unknown marks
pytest --strict-markers -x -q

# Single file with line-trace
pytest tests/test_foo.py -x --tb=line

# With parallelism (after Phase 6D install pytest-xdist)
pytest -n auto tests/
```

**Shell invocations**:

```bash
# Lint all
make shellcheck

# Lint one
shellcheck -x scripts/atlas-modules/subcommands.sh

# Bats tests
make test-shell
```

---

## 4. Version Bump Workflow

Single source of truth: `VERSION` file (pyproject.toml reads it dynamically).

```bash
# Patch bump (5.7.0 → 5.7.1)
make publish-patch

# Minor bump (5.7.0 → 5.8.0)
make publish-minor

# Manual
echo "5.8.0-alpha.1" > VERSION
./build.sh v5                    # propagates to dist/*/plugin.json
git add VERSION dist/
git commit -m "chore(release): bump to 5.8.0-alpha.1"
git tag "v5.8.0-alpha.1"
```

After bump, update `CHANGELOG.md` with:
- Added / Changed / Fixed / Deprecated / Removed sections.
- PR/issue refs when applicable.

---

## 5. Commit Conventions

Conventional Commits format: `type(scope): description`

**Allowed types**: `feat | fix | docs | refactor | perf | test | build | ci | chore | style | security`

**Examples**:

```
feat(statusline): add effort indicator module
fix(makefile): deploy atlas-dev via make dev (Bug A)
refactor(shell): harden hooks/lib + run-hook (round 6A-1)
ci(shellcheck): add L1 shellcheck step (soft-fail 1 week)
security(ci): gitleaks hard-fail (remove failure:ignore)
```

**Rules**:
- Scope is lowercase, 1-2 words. Examples: `makefile`, `statusline`, `hooks`, `pytest`, `shell`, `profiles`.
- Description is imperative mood, lowercase, no trailing period.
- Body (optional): wrap at 72 chars, explain **why** not **what**.
- One logical change per commit. Split refactors into rounds (e.g., `6A-1`, `6A-2`).

---

## 6. Shellcheck Rules

Shellcheck runs on every PR (L1 structural step in `.woodpecker/ci.yml`). Pass by default.

**When to disable a check**:

```bash
# shellcheck disable=SC2046 # direnv output is safe to eval
eval "$(direnv export zsh)"
```

**Rule of thumb**:
- NEVER disable SC2086 (unquoted variable). Fix the quoting.
- SC2034 (unused var): acceptable if exported for child processes.
- SC2164 (cd without check): fix with `cd "$dir" || return 3`.
- SC2046 (word splitting from command substitution): justify inline.

**Disable syntax** applies to the NEXT line only. Don't disable at file level.

---

## 7. Security

**Never commit**:
- Secrets (API tokens, passwords, private keys)
- Personal IPs (use `forgejo.axoiq.com` etc. via env vars, not `192.168.10.*`)
- User-specific paths (use `$HOME` or `$PLUGIN_ROOT`)

**Pre-commit gitleaks** runs on every push to `main`. Hard-fail since v5.7.0 (Phase 6F). Review findings before force-push.

**Env vars for config**:

| Purpose | Env var | Default |
|---------|---------|---------|
| Forgejo API | `ATLAS_FORGEJO_API` | `forgejo.axoiq.com` |
| Woodpecker CI host | `WP_HOST` | `ci.axoiq.com` |
| Plugin version override | (none) | reads `VERSION` file |
| CC session ID | `CLAUDE_SESSION_ID` | auto-injected |

**Reporting a vuln**: email `seb@axoiq.com` (private disclosure). Do NOT open a public issue.

---

## Appendix A — Quick Checklist for Reviewers

Before approving a PR, verify:

- [ ] All new shell scripts follow section 1 (contract).
- [ ] If adding a hook: all 3 wiring places touched (section 2).
- [ ] Tests added or updated for the change.
- [ ] Commits follow section 5 conventions.
- [ ] No hardcoded IPs, secrets, or user-specific paths.
- [ ] Shellcheck passes (section 6).
- [ ] CHANGELOG.md updated if user-visible change.

---

## Appendix B — Useful Make Targets

```bash
make dev                 # build + install to ~/.claude/plugins/cache
make test                # full pytest suite
make test-l1             # L1 only (fast)
make test-shell          # bats tests (requires Phase 6H)
make shellcheck          # lint all shell (requires Phase 6G)
make lint                # structural lint (frontmatter, refs)
make publish-patch       # bump patch + build + tag + push
make publish-minor       # bump minor + build + tag + push
```

---

*Updated: 2026-04-14 — v5.7.0-alpha.1 (Phase 6E)*
