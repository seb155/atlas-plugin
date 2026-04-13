#!/usr/bin/env bash
# atlas-resolve-version.sh — Resolve ATLAS plugin version + update indicator.
#
# Contract: Plugin distributes this script, Statusline calls it.
# Both sides reference this single file — change once, fix everywhere.
#
# Output formats:
#   "5.5.1"           → installed version, no update available
#   "5.5.1 ↗ 5.5.2"   → installed + arrow + available update (marketplace ahead)
#   "?"               → unresolvable
#
# Strategy chain (for installed version):
#   1. capabilities.json (SessionStart-refreshed SSoT, written by atlas-discover-addons.sh)
#   2. Filesystem scan of plugin cache (zero-dep absolute fallback)
#   3. "?" literal
#
# Update indicator (appended if marketplace registry > installed):
#   - Reads ~/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json
#   - Max plugin version across registry (sort -V)
#   - Appends "↗ X.Y.Z" only when strictly newer than installed
#
# Used by: Starship [custom.atlas_version], atlas-doctor, atlas-assist banner.
# Deployed to: ~/.local/share/atlas-statusline/atlas-resolve-version.sh

# --- Resolve INSTALLED version ---
INSTALLED=""

# Strategy 1: capabilities.json (SSoT)
CAPS="$HOME/.atlas/runtime/capabilities.json"
if [ -r "$CAPS" ]; then
  INSTALLED=$(jq -r '.version // empty' "$CAPS" 2>/dev/null)
fi

# Strategy 2: filesystem scan fallback
if [ -z "$INSTALLED" ] || [ "$INSTALLED" = "null" ]; then
  CACHE="$HOME/.claude/plugins/cache/atlas-marketplace"
  if [ -d "$CACHE" ]; then
    INSTALLED=$(find "$CACHE" -maxdepth 2 -mindepth 2 -type d \
      -regex '.*/[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null \
      | awk -F/ '{print $NF}' | sort -V | tail -1)
  fi
fi

# Unresolvable
[ -z "$INSTALLED" ] && { echo "?"; exit 0; }

# --- Check for AVAILABLE update in marketplace registry ---
AVAILABLE=""
MARKETPLACE="$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json"
if [ -r "$MARKETPLACE" ]; then
  # Extract all plugin versions, sort -V, take highest (semver-correct vs jq's lex max)
  AVAILABLE=$(jq -r '.plugins[]?.version // empty' "$MARKETPLACE" 2>/dev/null \
    | sort -V | tail -1)
fi

# --- Append indicator if update strictly newer ---
if [ -n "$AVAILABLE" ] && [ "$AVAILABLE" != "$INSTALLED" ]; then
  # sort -V: if AVAILABLE is last, it's newer than INSTALLED
  LATEST=$(printf '%s\n%s\n' "$INSTALLED" "$AVAILABLE" | sort -V | tail -1)
  if [ "$LATEST" = "$AVAILABLE" ]; then
    echo "$INSTALLED ↗ $AVAILABLE"
    exit 0
  fi
fi

echo "$INSTALLED"
