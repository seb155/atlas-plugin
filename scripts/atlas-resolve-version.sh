#!/usr/bin/env bash
# atlas-resolve-version.sh — Resolve ATLAS plugin version from CC marketplace
#
# Contract: Plugin distributes this script, Statusline calls it.
# Both sides reference this single file — change once, fix everywhere.
#
# Fallback chain:
#   1. CC marketplace registry (installed_plugins.json) — always current after /plugin
#   2. Hook-written session state (session-state.json) — current after first prompt
#   3. VERSION file in CLAUDE_PLUGIN_ROOT — available during hook execution
#   4. "?" — last resort
#
# Used by: Starship [custom.atlas_version], atlas-doctor, atlas-assist banner
# Deployed to: ~/.local/share/atlas-statusline/atlas-resolve-version.sh

INSTALLED="${HOME}/.claude/plugins/installed_plugins.json"
STATE="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}/session-state.json"
VERSION_FILE="${CLAUDE_PLUGIN_ROOT:-}/VERSION"

# Strategy 1: CC marketplace registry (always current)
# Iterate over all 3 ATLAS plugins (admin/dev/core) — return most recently installed version.
# Fixes prior typo (was: "atlas-admin@atlas-admin-marketplace" — wrong marketplace name).
if [ -f "$INSTALLED" ]; then
  v=$(jq -r '
    [
      (.plugins["atlas-admin@atlas-marketplace"] // []),
      (.plugins["atlas-core@atlas-marketplace"]  // []),
      (.plugins["atlas-dev@atlas-marketplace"]   // [])
    ]
    | flatten
    | map(select(.version != null and .version != ""))
    | (max_by(.installedAt) // {}).version // empty
  ' "$INSTALLED" 2>/dev/null)
  [ -n "$v" ] && echo "$v" && exit 0
fi

# Strategy 2: Hook-written session state
if [ -f "$STATE" ]; then
  v=$(jq -r '.plugin_version // empty' "$STATE" 2>/dev/null)
  [ -n "$v" ] && echo "$v" && exit 0
fi

# Strategy 3: VERSION file in plugin root
if [ -n "$VERSION_FILE" ] && [ -f "$VERSION_FILE" ]; then
  v=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]')
  [ -n "$v" ] && echo "$v" && exit 0
fi

echo "?"
