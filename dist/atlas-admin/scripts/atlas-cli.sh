#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════
# ATLAS — Unified Claude Code Launcher & Management CLI
# © 2026 AXOIQ Inc. | Proprietary Software
# ═══════════════════════════════════════════════════════════════
#
# Usage: atlas [project|subcommand] [flags] [topic] [-- cc-flags...]
#
# Source this file from ~/.zshrc:
#   [ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"
#
# Modularized: main logic lives in atlas-modules/*.sh

ATLAS_VERSION="4.15.2"
ATLAS_CONFIG="${HOME}/.atlas/config.json"
ATLAS_HISTORY="${HOME}/.atlas/history.json"
ATLAS_SHELL_DIR="${HOME}/.atlas/shell"

# ─── Source Modules (order matters) ───────────────────────────
_ATLAS_MOD_DIR="${ATLAS_SHELL_DIR}/modules"

if [ -d "$_ATLAS_MOD_DIR" ]; then
  # Module load order: platform → ui → topics → subcommands → launcher → completions
  for _mod in platform ui topics subcommands launcher completions; do
    [ -f "$_ATLAS_MOD_DIR/${_mod}.sh" ] && source "$_ATLAS_MOD_DIR/${_mod}.sh"
  done
  unset _mod
else
  # Fallback: monolithic mode (modules not yet installed)
  # This happens when atlas-cli.sh is newer than modules
  echo "⚠️  ATLAS modules not found at $_ATLAS_MOD_DIR"
  echo "   Run: make dev (from atlas-dev-plugin/) to install modules"
fi

# ─── Source Setup Wizard ──────────────────────────────────────
[ -f "${ATLAS_SHELL_DIR}/setup-wizard.sh" ] && source "${ATLAS_SHELL_DIR}/setup-wizard.sh"

unset _ATLAS_MOD_DIR
