---
name: statusline-setup
description: "Status line installer (cross-platform). This skill should be used when the user asks to 'setup statusline', 'install statusline', 'configure cship', '/atlas statusline', or after a fresh ATLAS plugin install."
effort: low
---

# ATLAS Status Line Setup

Single command installs the ATLAS-enhanced Claude Code status line.

## Usage

```bash
# Linux / macOS — interactive (HITL gate before each phase)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/statusline/install.sh"

# Non-interactive (used by auto-heal hook and CI)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/statusline/install.sh" --auto

# Preview without writing anything
bash "${CLAUDE_PLUGIN_ROOT}/scripts/statusline/install.sh" --auto --dry-run

# Install + run doctor at end
bash "${CLAUDE_PLUGIN_ROOT}/scripts/statusline/install.sh" --doctor-after
```

## What it does

1. **Verifies dependencies** — `cship`, `jq`, `bash` present. Warns if `yq` is snap-confined (AppArmor blocks `~/.claude/**`; Sprint A grep fallback handles this, but suggests apt/binary instead).
2. **Deploys artifacts** to `~/.local/share/atlas-statusline/` (territory dotfile-sync does NOT touch — see ADR-023):
   - `statusline-wrapper.sh` (resolves plugin version + delegates to renderer)
   - `atlas-resolve-version.sh` (Tier 1+2+3 version resolver)
   - `modules/atlas-*-module.sh` (legacy CShip helpers, kept for backward-compat — see ADR-024)
3. **Updates `~/.claude/settings.local.json`** with `statusLine.command`. NEVER touches `~/.claude/settings.json` — that's user/team territory and at risk of dotfile-sync overwrite (ADR-023).
4. **Writes `.install-manifest`** with md5 stamps for drift detection (consumed by the SessionStart auto-heal hook).
5. **Verifies render** with mock CC JSON — fails the install if output contains a bare `?` token instead of a real version.

Idempotent: re-running is a no-op when nothing has drifted.

## When it's used automatically

- **SessionStart auto-heal hook** (`hooks/statusline-heal`) writes `~/.atlas/runtime/.statusline-needs-install` when it detects broken settings. The next interactive session should run the installer to clear it.
- The skill's `description` triggers on phrases like "setup statusline" / "install statusline" / "configure cship" — Claude can invoke it itself when the user mentions one of these tasks.

## Diagnostics

Run the 8-level audit:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/statusline/doctor.sh"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/statusline/doctor.sh" --json    # for /atlas doctor integration
bash "${CLAUDE_PLUGIN_ROOT}/scripts/statusline/doctor.sh" --quiet   # CI mode
```

Doctor checks: tools, settings.local.json, wrapper deployed + md5, capabilities.json freshness, cship.toml, starship.toml, mock render (no bare `?`), drift between deployed and source.

## Windows users

The installer is Linux/macOS only. On Windows, the manual setup steps from earlier ATLAS versions still apply: install jq via winget, install CShip via the PowerShell installer at `https://cship.dev/install.ps1`, deploy the scripts manually to `~/.local/share/atlas-statusline/`, and set `statusLine.command` in `~/.claude/settings.local.json`. A first-class Windows installer is tracked as future work.

## Plan and architecture

See `.blueprint/plans/sp-statusline-sota-v3.md` for the full architecture (15 sections), 9 root causes addressed by this rewrite, sprints A–E, and acceptance criteria.

## Related

- ADR-019 — StatusLine SOTA v2 (wrapper deploy pattern, the foundation this builds on)
- ADR-023 — Settings.json territory boundaries (this plan's outcome)
- ADR-024 — CShip custom command JSON limitation (Sprint B finding)
