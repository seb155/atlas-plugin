#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Plugin status & sync
# Sourced by atlas-cli.sh — do not execute directly
#
# Commands:
#   atlas plugin                — show status (default)
#   atlas plugin status         — show version drift across source/cache/shell
#   atlas plugin sync           — run make dev in source repo to re-sync
#   atlas plugin help           — usage info

_ATLAS_PLUGIN_SOURCE="${ATLAS_PLUGIN_SOURCE:-${HOME}/workspace_atlas/projects/atlas-dev-plugin}"
_ATLAS_PLUGIN_CACHE="${HOME}/.claude/plugins/cache/atlas-marketplace"

# ─── Helper: read version from a path ─────────────────────────────
_atlas_plugin_read_version() {
  local path="$1"
  [ -f "$path" ] || { echo "N/A"; return; }
  /bin/cat "$path" 2>/dev/null | /usr/bin/tr -d '[:space:]' || echo "N/A"
}

# ─── Helper: max version in cache dir (semver-aware sort) ─────────
_atlas_plugin_cache_latest() {
  local addon="$1"
  local cache_dir="${_ATLAS_PLUGIN_CACHE}/${addon}"
  [ -d "$cache_dir" ] || { echo "N/A"; return; }
  # Sort versions semver-style (coreutils sort -V), skip dotfiles/orphaned
  /bin/ls "$cache_dir" 2>/dev/null \
    | /bin/grep -E '^[0-9]+\.[0-9]+\.[0-9]+' \
    | /usr/bin/sort -V \
    | /usr/bin/tail -1 \
    || echo "N/A"
}

# ─── Main: atlas plugin status ────────────────────────────────────
_atlas_plugin_status() {
  local source_version marketplace_version shell_version
  local cache_core cache_dev cache_admin

  # Source SSoT
  source_version=$(_atlas_plugin_read_version "${_ATLAS_PLUGIN_SOURCE}/VERSION")

  # Marketplace manifest
  marketplace_version="N/A"
  if [ -f "${_ATLAS_PLUGIN_SOURCE}/.claude-plugin/marketplace.json" ]; then
    marketplace_version=$(/bin/grep -m1 '"version"' "${_ATLAS_PLUGIN_SOURCE}/.claude-plugin/marketplace.json" \
      | /usr/bin/sed -E 's/.*"version":\s*"([^"]+)".*/\1/' \
      | /usr/bin/tr -d '[:space:]')
    [ -z "$marketplace_version" ] && marketplace_version="N/A"
  fi

  # Installed atlas.sh (shell version)
  shell_version="N/A"
  if [ -f "${HOME}/.atlas/shell/atlas.sh" ]; then
    shell_version=$(/bin/grep -m1 '^ATLAS_VERSION=' "${HOME}/.atlas/shell/atlas.sh" \
      | /usr/bin/sed -E 's/.*"([^"]+)".*/\1/')
    [ -z "$shell_version" ] && shell_version="N/A"
  fi

  # Cache installs
  cache_core=$(_atlas_plugin_cache_latest "atlas-core")
  cache_dev=$(_atlas_plugin_cache_latest "atlas-dev")
  cache_admin=$(_atlas_plugin_cache_latest "atlas-admin")

  # Drift detection
  local drift=0
  local drift_reason=""
  if [ "$source_version" != "N/A" ]; then
    for v in "$marketplace_version" "$shell_version" "$cache_core" "$cache_dev" "$cache_admin"; do
      if [ "$v" != "N/A" ] && [ "$v" != "$source_version" ]; then
        drift=1
        break
      fi
    done
  fi

  # Output
  printf "\n"
  printf "🔌 ATLAS Plugin Status\n"
  printf "══════════════════════\n\n"
  printf "  %-28s %s\n" "Source VERSION (SSoT):" "$source_version"
  printf "  %-28s %s\n" "Marketplace manifest:" "$marketplace_version"
  printf "  %-28s %s\n" "Shell atlas.sh (installed):" "$shell_version"
  printf "\n"
  printf "  Cache (CC plugin cache):\n"
  printf "    %-26s %s\n" "atlas-core:" "$cache_core"
  printf "    %-26s %s\n" "atlas-dev:" "$cache_dev"
  printf "    %-26s %s\n" "atlas-admin:" "$cache_admin"
  printf "\n"

  if [ "$drift" = "1" ]; then
    printf "  \033[33m⚠  DRIFT DETECTED\033[0m — installed versions differ from source.\n"
    printf "  \033[36m  Fix:\033[0m cd %s && make dev\n" "$_ATLAS_PLUGIN_SOURCE"
    printf "  \033[36m   Or:\033[0m atlas plugin sync\n"
    printf "\n"
  else
    printf "  \033[32m✓  IN SYNC\033[0m — all versions match source SSoT.\n\n"
  fi

  printf "  Scopes: this report reads USER scope (~/.claude/plugins/cache/).\n"
  printf "          Project-scope plugins (.claude/plugins/) are independent.\n\n"
}

# ─── atlas plugin sync → runs make dev ────────────────────────────
_atlas_plugin_sync() {
  if [ ! -f "${_ATLAS_PLUGIN_SOURCE}/Makefile" ]; then
    printf "\033[31m❌ Atlas plugin source not found at %s\033[0m\n" "$_ATLAS_PLUGIN_SOURCE"
    printf "   Set ATLAS_PLUGIN_SOURCE env var if your clone is elsewhere.\n"
    return 1
  fi

  printf "🔄 Running make dev in %s...\n\n" "$_ATLAS_PLUGIN_SOURCE"
  (cd "$_ATLAS_PLUGIN_SOURCE" && /usr/bin/make dev) && {
    printf "\n\033[32m✓  Plugin re-synced.\033[0m\n"
    printf "   Restart CC to pick up plugin changes.\n"
    printf "   source ~/.zshrc to reload shell atlas.sh.\n\n"
  }
}

# ─── atlas plugin help ────────────────────────────────────────────
_atlas_plugin_help() {
  cat <<'EOF'

🔌 atlas plugin — Atlas plugin management

USAGE
  atlas plugin              Show status (default)
  atlas plugin status       Show version drift across source/cache/shell
  atlas plugin sync         Run `make dev` in source repo to re-sync
  atlas plugin help         This message

SCOPES (user vs project)
  User scope   → ~/.claude/plugins/        Global for all projects
  Project      → .claude/plugins/          Only current project
  atlas reads user scope by default.

DRIFT DETECTION
  "Drift" = Source VERSION differs from installed cache version.
  Happens when:
    - VERSION file was bumped but `make dev` not run
    - Source repo pulled but dist/ wasn't rebuilt
    - Manual edits to atlas.sh or cache dirs
  Fix: `atlas plugin sync` (or `cd atlas-dev-plugin && make dev`)

ENV VARS
  ATLAS_PLUGIN_SOURCE     Override source repo path (default: ~/workspace_atlas/projects/atlas-dev-plugin)

EOF
}

# ─── Main dispatcher ──────────────────────────────────────────────
_atlas_plugin() {
  local sub="${1:-status}"
  case "$sub" in
    status|"")      _atlas_plugin_status ;;
    sync|install)   _atlas_plugin_sync ;;
    help|-h|--help) _atlas_plugin_help ;;
    *) printf "Unknown atlas plugin subcommand: %s\n" "$sub"
       _atlas_plugin_help
       return 1 ;;
  esac
}
