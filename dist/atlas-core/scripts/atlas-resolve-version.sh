#!/usr/bin/env bash
# atlas-resolve-version.sh — Resolve ATLAS plugin version + update indicator.
#
# SSoT contract: plugin distributes this script; Starship / cship / atlas-doctor consume.
# Schema v2 (v5.30.0+): 3-tier resolution with 5s TTL cache + drift sentinel.
#
# Output formats:
#   "5.5.1"           → installed version, no update available
#   "5.5.1 ↗ 5.5.2"   → installed + arrow + available update (marketplace ahead)
#   "?"               → unresolvable (no CLI, no caps, no cache)
#
# Resolution chain:
#   Tier 0: .resolve-version.cache  (mtime < 5s → return, skip everything)
#   Tier 1: claude plugin list --json  (canonical SSoT, ~1.5s fork cost)
#   Tier 2: ~/.atlas/runtime/capabilities.json  (SessionStart snapshot)
#   Tier 3: filesystem scan of plugin cache (zero-dep absolute fallback)
#   "?"   : literal (nothing found)
#
# Drift sentinel:
#   If Tier-1 version differs from capabilities.json version, `touch .capabilities.stale`.
#   The capabilities-refresh hook (UserPromptSubmit) sees this and reruns
#   atlas-discover-addons.sh once per user turn — no explicit /reload-plugins event needed.
#
# Update indicator (unchanged from v1):
#   Reads ~/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json
#   Appends "↗ X.Y.Z" only when strictly newer than installed (sort -V).
#
# Used by: Starship [custom.atlas_version], cship.toml, atlas-doctor, atlas-assist banner.
# Deployed to: ~/.local/share/atlas-statusline/atlas-resolve-version.sh

set -uo pipefail

# ─── Paths ──────────────────────────────────────────────────────────────
RUNTIME_DIR="$HOME/.atlas/runtime"
CAPS="$RUNTIME_DIR/capabilities.json"
CACHE_FILE="$RUNTIME_DIR/.resolve-version.cache"
STALE_SENTINEL="$RUNTIME_DIR/.capabilities.stale"
MARKETPLACE_REG="$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json"
CACHE_DIR="$HOME/.claude/plugins/cache/atlas-marketplace"
TTL_SECONDS=5

mkdir -p "$RUNTIME_DIR" 2>/dev/null

# ─── Tier 0: TTL cache ──────────────────────────────────────────────────
# Starship refreshes ~1s; Tier 1 costs ~1.5s CLI fork. Cache 5s or freeze.
# Bypass: set ATLAS_RESOLVE_NO_CACHE=1 (used by tests)
if [ -f "$CACHE_FILE" ] && [ "${ATLAS_RESOLVE_NO_CACHE:-0}" != "1" ]; then
  _now=$(date -u +%s 2>/dev/null || echo 0)
  _mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  _age=$((_now - _mtime))
  if [ "$_age" -ge 0 ] && [ "$_age" -lt "$TTL_SECONDS" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# ─── Tier 1 helper: canonical CC CLI ────────────────────────────────────
# Bypass: set ATLAS_NO_CLAUDE=1 (used by tests)
resolve_via_cli() {
  [ "${ATLAS_NO_CLAUDE:-0}" = "1" ] && return 1
  command -v claude >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local json
  json=$(timeout 2 claude plugin list --json 2>/dev/null) || return 1
  [ -n "$json" ] || return 1
  # Pick atlas-core (reference plugin — its version drives the top-level .version).
  # Does NOT filter by .enabled (that field is CWD-scoped, version unchanged).
  # Prefer enabled, fall back to any, sort by lastUpdated desc.
  printf '%s' "$json" | jq -rs '
    .[0]
    | map(select(.id == "atlas-core@atlas-marketplace"))
    | (map(select(.enabled == true)) + map(select(.enabled != true)))
    | sort_by(.lastUpdated) | reverse
    | .[0]
    | if . == null then empty else .version end
  ' 2>/dev/null | head -1
}

# ─── Tier 2 helper: capabilities.json snapshot ─────────────────────────
resolve_via_caps() {
  [ -r "$CAPS" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -r '.version // empty' "$CAPS" 2>/dev/null
}

# ─── Tier 3 helper: filesystem scan ─────────────────────────────────────
resolve_via_fs() {
  [ -d "$CACHE_DIR" ] || return 1
  find "$CACHE_DIR" -maxdepth 2 -mindepth 2 -type d \
    -regex '.*/[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null \
    | awk -F/ '{print $NF}' | sort -V | tail -1
}

# ─── Main resolution chain ─────────────────────────────────────────────
INSTALLED=""
CLI_VER=""

CLI_VER=$(resolve_via_cli)
if [ -n "$CLI_VER" ] && [ "$CLI_VER" != "null" ]; then
  INSTALLED="$CLI_VER"
fi

if [ -z "$INSTALLED" ]; then
  _caps_ver=$(resolve_via_caps)
  if [ -n "$_caps_ver" ] && [ "$_caps_ver" != "null" ]; then
    INSTALLED="$_caps_ver"
  fi
fi

if [ -z "$INSTALLED" ]; then
  INSTALLED=$(resolve_via_fs)
fi

# Unresolvable
if [ -z "$INSTALLED" ]; then
  echo "?"
  exit 0
fi

# ─── Drift detection: sentinel for capabilities-refresh hook ──────────
# Write-only side of the sentinel pattern. The UserPromptSubmit hook
# (capabilities-refresh) reads and deletes this file once per user turn.
if [ -n "$CLI_VER" ] && [ -r "$CAPS" ]; then
  _caps_ver=$(resolve_via_caps)
  if [ -n "$_caps_ver" ] && [ "$_caps_ver" != "$CLI_VER" ]; then
    touch "$STALE_SENTINEL" 2>/dev/null
  fi
fi

# ─── Update indicator: marketplace registry ahead? ─────────────────────
AVAILABLE=""
if [ -r "$MARKETPLACE_REG" ] && command -v jq >/dev/null 2>&1; then
  AVAILABLE=$(jq -r '.plugins[]?.version // empty' "$MARKETPLACE_REG" 2>/dev/null \
    | sort -V | tail -1)
fi

# ─── Build output ───────────────────────────────────────────────────────
OUTPUT="$INSTALLED"
if [ -n "$AVAILABLE" ] && [ "$AVAILABLE" != "$INSTALLED" ]; then
  LATEST=$(printf '%s\n%s\n' "$INSTALLED" "$AVAILABLE" | sort -V | tail -1)
  if [ "$LATEST" = "$AVAILABLE" ]; then
    OUTPUT="$INSTALLED ↗ $AVAILABLE"
  fi
fi

# ─── Cache and emit (atomic write) ─────────────────────────────────────
echo "$OUTPUT" > "${CACHE_FILE}.tmp" 2>/dev/null && \
  /bin/mv -f "${CACHE_FILE}.tmp" "$CACHE_FILE" 2>/dev/null

echo "$OUTPUT"
