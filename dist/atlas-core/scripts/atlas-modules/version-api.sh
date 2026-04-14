#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Version API — Single Source of Truth for plugin versions
#
# Replaces scattered folder-path scanning across ui.sh and auto-update.sh.
# All version lookups go through this module. CC's installed_plugins.json is
# the primary SSoT; marketplace.json and capabilities.json are fallbacks.
#
# Public functions:
#   _atlas_version_installed [addon]    → installed version for addon (default: atlas-core)
#   _atlas_version_marketplace [addon]  → marketplace-advertised version
#   _atlas_version_source               → source repo VERSION file (if ATLAS_SOURCE_REPO set)
#   _atlas_addon_path [addon]           → installPath from installed_plugins.json
#   _atlas_upgrade_status               → "up-to-date" | "pending:<ver>" | "unknown"
#   _atlas_version_max <a> <b>          → greater of two semver-ish strings
#
# Sourced by: atlas-cli.sh (first, before ui.sh and subcommands.sh).
# All functions return empty string + exit 0 when data is unavailable (never die).

# ─── Canonical Paths ──────────────────────────────────────────
ATLAS_INSTALLED_JSON="${HOME}/.claude/plugins/installed_plugins.json"
ATLAS_MARKETPLACE_JSON="${HOME}/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json"
ATLAS_CAPABILITIES_JSON="${HOME}/.atlas/runtime/capabilities.json"
ATLAS_SOURCE_REPO="${ATLAS_SOURCE_REPO:-${HOME}/workspace_atlas/projects/atlas-dev-plugin}"

# ─── Internals ────────────────────────────────────────────────

# Guard: jq available. All lookups silently return empty when jq missing.
_atlas_version_has_jq() { command -v jq >/dev/null 2>&1; }

# Read installed version for a plugin key from installed_plugins.json.
# Args: $1 = addon (atlas-core | atlas-admin | atlas-dev). Default atlas-core.
# Stdout: version string, empty on miss.
_atlas_version_installed() {
  local addon="${1:-atlas-core}"
  _atlas_version_has_jq || return 0
  [ -r "$ATLAS_INSTALLED_JSON" ] || return 0
  jq -r --arg key "${addon}@atlas-marketplace" '
    .plugins[$key]? // []
    | map(select(.scope == "user"))
    | .[0].version // empty
  ' "$ATLAS_INSTALLED_JSON" 2>/dev/null
}

# Read marketplace-advertised version from marketplace.json.
# Args: $1 = addon. Default atlas-core.
# Stdout: version string, empty on miss.
_atlas_version_marketplace() {
  local addon="${1:-atlas-core}"
  _atlas_version_has_jq || return 0
  [ -r "$ATLAS_MARKETPLACE_JSON" ] || return 0
  jq -r --arg name "$addon" '
    [.plugins[]? | select(.name == $name) | .version // empty] | .[0] // empty
  ' "$ATLAS_MARKETPLACE_JSON" 2>/dev/null
}

# Read source repo VERSION file (the canonical "what's being built now").
# Stdout: version string, empty if repo missing or VERSION unreadable.
_atlas_version_source() {
  local ver_file="${ATLAS_SOURCE_REPO}/VERSION"
  [ -r "$ver_file" ] || return 0
  tr -d '[:space:]' < "$ver_file" 2>/dev/null
}

# Read addon cache install path from installed_plugins.json.
# Args: $1 = addon. Default atlas-core.
# Stdout: path string, empty on miss.
_atlas_addon_path() {
  local addon="${1:-atlas-core}"
  _atlas_version_has_jq || return 0
  [ -r "$ATLAS_INSTALLED_JSON" ] || return 0
  jq -r --arg key "${addon}@atlas-marketplace" '
    .plugins[$key]? // []
    | map(select(.scope == "user"))
    | .[0].installPath // empty
  ' "$ATLAS_INSTALLED_JSON" 2>/dev/null
}

# Compare two semver-ish strings (handles pre-release suffixes via sort -V).
# Args: $1, $2 = versions. Stdout: greater version.
_atlas_version_max() {
  local a="$1" b="$2"
  [ -z "$a" ] && { echo "$b"; return 0; }
  [ -z "$b" ] && { echo "$a"; return 0; }
  printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1
}

# Classify upgrade state for atlas-core.
# Stdout: "up-to-date" | "pending:<mp_ver>" | "unknown".
_atlas_upgrade_status() {
  local inst mp
  inst=$(_atlas_version_installed atlas-core)
  mp=$(_atlas_version_marketplace atlas-core)

  [ -z "$inst" ] && [ -z "$mp" ] && { echo "unknown"; return 0; }
  [ -z "$inst" ] && { echo "not-installed"; return 0; }
  [ -z "$mp" ] && { echo "up-to-date"; return 0; }

  local latest
  latest=$(_atlas_version_max "$inst" "$mp")
  if [ "$latest" = "$inst" ]; then
    echo "up-to-date"
  else
    echo "pending:${mp}"
  fi
}

# Resolve the "best" atlas-core version to display (for banner, statusline).
# Chain: installed → capabilities.json → marketplace → "unknown".
# Stdout: version string; never "?.?.?".
_atlas_version_display() {
  local v
  v=$(_atlas_version_installed atlas-core)
  [ -n "$v" ] && { echo "$v"; return 0; }

  if _atlas_version_has_jq && [ -r "$ATLAS_CAPABILITIES_JSON" ]; then
    v=$(jq -r '.version // empty' "$ATLAS_CAPABILITIES_JSON" 2>/dev/null)
    [ -n "$v" ] && { echo "$v"; return 0; }
  fi

  v=$(_atlas_version_marketplace atlas-core)
  [ -n "$v" ] && { echo "$v"; return 0; }

  echo "unknown"
}
