#!/usr/bin/env bash
# atlas-resolve-version.sh — Resolve ATLAS plugin version.
#
# Contract: Plugin distributes this script, Statusline calls it.
# Both sides reference this single file — change once, fix everywhere.
#
# Strategy chain:
#   1. capabilities.json (SessionStart-refreshed SSoT, written by atlas-discover-addons.sh)
#   2. Filesystem scan of plugin cache (zero-dep absolute fallback)
#   3. "?" literal
#
# Used by: Starship [custom.atlas_version], atlas-doctor, atlas-assist banner.
# Deployed to: ~/.local/share/atlas-statusline/atlas-resolve-version.sh

# Strategy 1: capabilities.json — single source of truth
CAPS="$HOME/.atlas/runtime/capabilities.json"
if [ -r "$CAPS" ]; then
  v=$(jq -r '.version // empty' "$CAPS" 2>/dev/null)
  [ -n "$v" ] && echo "$v" && exit 0
fi

# Strategy 2: filesystem scan — absolute fallback (zero-dep, pure shell)
CACHE="$HOME/.claude/plugins/cache/atlas-marketplace"
if [ -d "$CACHE" ]; then
  v=$(find "$CACHE" -maxdepth 2 -mindepth 2 -type d \
    -regex '.*/[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null \
    | awk -F/ '{print $NF}' | sort -V | tail -1)
  [ -n "$v" ] && echo "$v" && exit 0
fi

echo "?"
