#!/usr/bin/env bash
# statusline-wrapper.sh — ATLAS status line delegation wrapper (SOTA v2).
#
# DEPLOYED to: ~/.local/share/atlas-statusline/statusline-wrapper.sh
#              (by plugins/atlas-core/hooks/session-start, Section 3)
#
# REFERENCED by: ~/.claude/settings.json statusLine.command
#
# PURPOSE — why this thin wrapper exists:
#   v4.44.0 through v5.30.1 all regressed because the plugin's correct
#   statusline-command.sh was deployed to ~/.claude/statusline-command.sh
#   and then overwritten by ~/.claude-dotfiles/sync.sh (unrelated config
#   sync script). This wrapper lives in ~/.local/share/atlas-statusline/,
#   a territory dotfiles does not touch, and exec's the plugin-shipped
#   statusline-command.sh for the resolved plugin version.
#
# CONTRACT:
#   stdin  → Claude Code status line JSON (model, cwd, context_window, ...)
#   stdout → rendered status line string (ANSI-colored)
#   exit   → 0 on success; emits fallback if version unresolvable
#
# RESOLUTION (reuses atlas-resolve-version.sh 3-tier fallback):
#   Tier 1 — claude plugin list --json  (via resolver)
#   Tier 2 — capabilities.json .version (via resolver)
#   Tier 3 — filesystem scan of plugin cache (local fallback)
#   "?"    — emit minimal banner, drain stdin, exit 0
#
# ADR: docs/ADR/ADR-019-statusline-sota-v2-unification.md

set -uo pipefail

SL_DIR="$HOME/.local/share/atlas-statusline"
RESOLVER="$SL_DIR/atlas-resolve-version.sh"
CACHE_ROOT="$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core"

# ─── Resolve installed version ─────────────────────────────────────────
# Tier 1+2 delegated to resolver (has CLI + caps + fs + TTL cache).
version=""
if [ -x "$RESOLVER" ]; then
  # Resolver may emit "5.5.1 ↗ 5.5.2" when update available — keep first token.
  raw=$("$RESOLVER" 2>/dev/null | head -1)
  version=$(printf '%s' "$raw" | awk '{print $1}')
fi

# ─── Tier 3: direct filesystem scan (resolver absent / unresolvable) ──
if [ -z "$version" ] || [ "$version" = "?" ]; then
  if [ -d "$CACHE_ROOT" ]; then
    version=$(find "$CACHE_ROOT" -maxdepth 1 -mindepth 1 -type d \
      -regex '.*/[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null \
      | awk -F/ '{print $NF}' | sort -V | tail -1)
  fi
fi

# ─── Unresolvable fallback ─────────────────────────────────────────────
# CC expects stdout output on every invocation. Drain stdin so the CC
# JSON writer does not block, then emit a minimal banner with diagnostic.
if [ -z "$version" ]; then
  cat >/dev/null 2>&1 || true
  printf '🏛️ ATLAS ?  (version unresolvable — run /atlas doctor --statusline)'
  exit 0
fi

# ─── Delegate to plugin-shipped statusline-command.sh ─────────────────
PLUGIN_STATUSLINE="$CACHE_ROOT/$version/scripts/statusline-command.sh"

if [ ! -x "$PLUGIN_STATUSLINE" ]; then
  cat >/dev/null 2>&1 || true
  printf '🏛️ ATLAS %s  (statusline script missing at %s)' \
    "$version" "$PLUGIN_STATUSLINE"
  exit 0
fi

# exec replaces this process image — stdin, stdout, and exit code pass through
# to the plugin script. No subshell overhead.
exec "$PLUGIN_STATUSLINE"
