#!/usr/bin/env bash
# shellcheck shell=bash
# ATLAS Hook Library: Auto-Update Plugin Helper (v5.11+)
#
# Detects when marketplace has a newer version than installed and applies
# the update by: git pull source → make dev → copy dist → patch registry.
#
# CC 2.1.107 limitation: /plugin update slash command does not exist.
# This helper replicates updatePluginOp() internal logic from CC binary.
#
# Usage: source this file from session-start, then call:
#   atlas_auto_update_plugins
#
# Output (stdout): one-line status message (emoji + summary).
# Return: 0 on success or no-op. Non-zero only on serious errors.
#
# Disable: ATLAS_NO_AUTO_UPDATE=1
# Override source repo: ATLAS_SOURCE_REPO=/path/to/atlas-dev-plugin
#
# NOTE: No `set -euo pipefail` here — sourced library must not alter caller shell.

# Get max version among atlas-* plugins in marketplace.json.
# Args: $1 = path to marketplace.json
# Stdout: version string, or empty on error.
_atlas_au_marketplace_max_version() {
  local mp_json="$1"
  [ -r "$mp_json" ] || return 1
  jq -r '
    [.plugins[]? | select(.name | startswith("atlas-")) | .version // empty]
    | sort_by(split("-")[0] | split(".") | map(tonumber? // 0))
    | .[-1] // empty
  ' "$mp_json" 2>/dev/null
}

# Get installed version for a plugin at scope=user.
# Args: $1 = path to installed_plugins.json, $2 = plugin key (e.g. "atlas-core@atlas-marketplace")
# Stdout: version string, or empty.
_atlas_au_installed_user_version() {
  local inst_json="$1" key="$2"
  [ -r "$inst_json" ] || return 1
  jq -r --arg key "$key" '
    .plugins[$key]? // []
    | map(select(.scope == "user"))
    | .[0].version // empty
  ' "$inst_json" 2>/dev/null
}

# Compare two semver-ish strings. Echoes the greater.
# Handles pre-release suffix (5.7.0-alpha.1 < 5.10.0).
_atlas_au_max_version() {
  local a="$1" b="$2"
  printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1
}

# Append a diagnostic line to ~/.atlas/logs/auto-update.log.
# Silent operation — never errors, never noisy on stdout.
_atlas_au_log() {
  local log_dir="${HOME}/.atlas/logs"
  local log_file="${log_dir}/auto-update.log"
  mkdir -p "$log_dir" 2>/dev/null || return 0
  printf '[%s] %s\n' "$(/usr/bin/date -Iseconds 2>/dev/null || date)" "$*" >> "$log_file" 2>/dev/null
}

# Main entry point. Safe to call multiple times (no-op when up to date).
atlas_auto_update_plugins() {
  # Guard: user opted out
  [ "${ATLAS_NO_AUTO_UPDATE:-}" = "1" ] && return 0

  # Guard: jq required
  command -v jq >/dev/null 2>&1 || return 0

  local marketplace_json="${HOME}/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json"
  local installed_json="${HOME}/.claude/plugins/installed_plugins.json"
  local source_repo="${ATLAS_SOURCE_REPO:-${HOME}/workspace_atlas/projects/atlas-dev-plugin}"

  # Guard: required state files exist
  [ -r "$marketplace_json" ] || return 0
  [ -r "$installed_json" ] || return 0

  # Detect gap
  local mp_version inst_version
  mp_version=$(_atlas_au_marketplace_max_version "$marketplace_json")
  [ -z "$mp_version" ] && return 0

  inst_version=$(_atlas_au_installed_user_version "$installed_json" "atlas-core@atlas-marketplace")
  [ -z "$inst_version" ] && return 0  # not installed → don't auto-install

  [ "$mp_version" = "$inst_version" ] && return 0  # up to date

  local latest
  latest=$(_atlas_au_max_version "$inst_version" "$mp_version")
  [ "$latest" != "$mp_version" ] && return 0  # installed is actually newer (pre-release etc)

  # Guard: source repo must exist and be a git repo on main branch with clean state
  # ATLAS_UPGRADE_FORCE=1 bypasses branch/dirty guards (for `atlas upgrade --force`).
  local force="${ATLAS_UPGRADE_FORCE:-0}"

  if [ ! -d "$source_repo/.git" ]; then
    _atlas_au_log "skip: source repo not a git dir at $source_repo (inst=$inst_version mp=$mp_version)"
    printf '🆙 ATLAS v%s disponible (installed v%s) — source repo not found at %s, skipped\n' \
      "$mp_version" "$inst_version" "$source_repo"
    return 0
  fi

  local current_branch
  current_branch=$(git -C "$source_repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [ "$current_branch" != "main" ] && [ "$force" != "1" ]; then
    _atlas_au_log "skip: source on branch=${current_branch:-unknown} (not main) — use atlas upgrade --force to bypass"
    printf '🆙 ATLAS v%s disponible (installed v%s) — source repo on %s, skipped (use `atlas upgrade --force` to bypass, or switch to main)\n' \
      "$mp_version" "$inst_version" "${current_branch:-unknown}"
    return 0
  fi

  # Guard: source repo must be clean (no uncommitted changes) unless forced
  if [ "$force" != "1" ] && { ! git -C "$source_repo" diff --quiet 2>/dev/null || ! git -C "$source_repo" diff --cached --quiet 2>/dev/null; }; then
    _atlas_au_log "skip: source has uncommitted changes — use atlas upgrade --force to bypass"
    printf '🆙 ATLAS v%s disponible (installed v%s) — source repo has uncommitted changes, skipped (use `atlas upgrade --force` to bypass)\n' \
      "$mp_version" "$inst_version"
    return 0
  fi

  _atlas_au_log "start: upgrading inst=$inst_version → mp=$mp_version (branch=$current_branch force=$force)"

  # Pull + build (silent unless failure)
  local build_log
  build_log=$(mktemp -t atlas-auto-update.XXXXXX)
  if ! (
    cd "$source_repo" || exit 1
    git fetch origin main --quiet 2>&1
    git pull --ff-only origin main --quiet 2>&1
    make dev 2>&1
  ) >"$build_log" 2>&1; then
    printf '🆙 ATLAS v%s disponible — auto-update failed (see %s)\n' "$mp_version" "$build_log"
    return 0
  fi
  rm -f "$build_log"

  # Resolve new version from source (may have advanced past mp_version)
  local new_ver
  new_ver=$(tr -d '[:space:]' < "$source_repo/VERSION" 2>/dev/null || echo "")
  [ -z "$new_ver" ] && return 0

  # Copy dist/atlas-*/ → cache/atlas-marketplace/atlas-*/$new_ver/
  # Note: dist dir names vary (atlas-core vs atlas-admin-addon vs atlas-dev-addon)
  local dist_copied=0 addon src dest
  for addon in atlas-core atlas-admin atlas-dev; do
    # Try plugin-aligned dir name first, fall back to -addon suffix
    for src_candidate in "$source_repo/dist/$addon" "$source_repo/dist/${addon}-addon"; do
      if [ -d "$src_candidate" ]; then
        src="$src_candidate"
        dest="${HOME}/.claude/plugins/cache/atlas-marketplace/$addon/$new_ver"
        mkdir -p "$dest"
        cp -r "$src/." "$dest/" 2>/dev/null || continue
        dist_copied=$((dist_copied + 1))
        break
      fi
    done
  done
  [ "$dist_copied" -eq 0 ] && return 0

  # Patch installed_plugins.json scope=user entries (backup first)
  local backup_suffix backup
  backup_suffix=$(date +%Y%m%d-%H%M%S)
  backup="${installed_json}.bak.${backup_suffix}"
  cp "$installed_json" "$backup" || return 1

  local new_sha now tmp_json
  new_sha=$(git -C "$source_repo" rev-parse HEAD 2>/dev/null || echo "")
  now=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
  tmp_json="${installed_json}.tmp.$$"

  local patch_ok=1
  for addon in atlas-core atlas-admin atlas-dev; do
    local key="${addon}@atlas-marketplace"
    local new_path="${HOME}/.claude/plugins/cache/atlas-marketplace/$addon/$new_ver"

    if ! jq --arg key "$key" \
           --arg path "$new_path" \
           --arg ver "$new_ver" \
           --arg sha "$new_sha" \
           --arg now "$now" \
       '(.plugins[$key] // []) |= map(
          if .scope == "user" then
            .installPath = $path | .version = $ver | .gitCommitSha = $sha | .lastUpdated = $now
          else . end
        )' "$installed_json" > "$tmp_json" 2>/dev/null; then
      patch_ok=0
      break
    fi
    mv "$tmp_json" "$installed_json"
  done

  if [ "$patch_ok" -eq 0 ]; then
    cp "$backup" "$installed_json"
    rm -f "$tmp_json"
    printf '🆙 ATLAS v%s auto-update failed at registry patch, reverted (backup: %s)\n' "$new_ver" "$backup"
    return 1
  fi

  # Rotate backups: keep last 3
  # shellcheck disable=SC2012
  ls -t "${installed_json}.bak."* 2>/dev/null | tail -n +4 | xargs -r rm -f

  # Refresh capabilities.json so the running session sees new tier (optional but nice)
  local discover_script="${HOME}/.claude/plugins/cache/atlas-marketplace/atlas-core/${new_ver}/scripts/atlas-discover-addons.sh"
  if [ -x "$discover_script" ]; then
    "$discover_script" >/dev/null 2>&1 || true
  fi

  printf '✅ ATLAS %s → %s auto-installed (restart CC to load new skills/agents)\n' "$inst_version" "$new_ver"
  return 0
}
