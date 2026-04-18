#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Platform Detection & Configuration
# Sourced by atlas-cli.sh — do not execute directly

# Ensure standard paths are available (fixes "command not found" in exec contexts)
[[ ":$PATH:" != *":/usr/bin:"* ]] && export PATH="/usr/bin:$PATH"
[[ ":$PATH:" != *":/usr/local/bin:"* ]] && export PATH="/usr/local/bin:$PATH"

# Source the setup wizard (sectioned configuration)
[ -f "${ATLAS_SHELL_DIR}/setup-wizard.sh" ] && source "${ATLAS_SHELL_DIR}/setup-wizard.sh"

# ─── Platform Detection (cached for session) ──────────────────
_atlas_detect_platform() {
  # OS
  case "$(uname -s)" in
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        ATLAS_OS="wsl"
      else
        ATLAS_OS="linux"
      fi
      ;;
    Darwin*) ATLAS_OS="macos" ;;
    MINGW*|MSYS*|CYGWIN*) ATLAS_OS="windows" ;;
    *) ATLAS_OS="unknown" ;;
  esac

  # Architecture
  ATLAS_ARCH="$(uname -m)"

  # Terminal capabilities
  ATLAS_TERM="${TERM_PROGRAM:-${TERM:-dumb}}"
  ATLAS_HAS_TRUECOLOR=false
  [[ "$COLORTERM" == "truecolor" || "$COLORTERM" == "24bit" ]] && ATLAS_HAS_TRUECOLOR=true

  # Tools available
  ATLAS_HAS_GUM=$(command -v gum &>/dev/null && echo true || echo false)
  ATLAS_HAS_FZF=$(command -v fzf &>/dev/null && echo true || echo false)
  ATLAS_HAS_DOCKER=$(command -v docker &>/dev/null && echo true || echo false)
  ATLAS_HAS_TMUX=$(command -v tmux &>/dev/null && echo true || echo false)
  ATLAS_HAS_BUN=$(command -v bun &>/dev/null && echo true || echo false)

  # Hostname (for multi-machine awareness)
  ATLAS_HOSTNAME="$(hostname -s 2>/dev/null || echo unknown)"

  # Claude Code version
  ATLAS_CC_VERSION="$(claude --version 2>/dev/null | /usr/bin/head -1 | grep -oP '[\d.]+' || echo "?")"
}
_atlas_detect_platform

# ─── Configuration Defaults ───────────────────────────────────
_atlas_read_config() {
  local key="$1" default="$2"
  if [ -f "$ATLAS_CONFIG" ]; then
    python3 -c "
import json, os
try:
    with open(os.path.expanduser('$ATLAS_CONFIG')) as f:
        c = json.load(f)
    val = c
    for k in '$key'.split('.'):
        val = val[k]
    # Normalize booleans to lowercase for shell
    if isinstance(val, bool):
        print('true' if val else 'false')
    else:
        print(val)
except:
    print('$default')
" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Read launcher defaults
ATLAS_DEFAULT_WORKTREE=$(_atlas_read_config "launcher.worktree" "true")
ATLAS_DEFAULT_SPLIT=$(_atlas_read_config "launcher.split" "true")
ATLAS_DEFAULT_EFFORT=$(_atlas_read_config "launcher.effort" "max")
ATLAS_DEFAULT_CHROME=$(_atlas_read_config "launcher.chrome" "true")
ATLAS_WORKSPACE_ROOT=$(_atlas_read_config "launcher.workspace_root" "$HOME/workspace_atlas")
ATLAS_WORKSPACE_ROOT="${ATLAS_WORKSPACE_ROOT/#\~/$HOME}"

# ─── Coder Workspace Detection ───────────────────────────────
ATLAS_IN_CODER=false
if [ -n "${CODER_AGENT_TOKEN:-}" ] || [ -n "${CODER:-}" ]; then
  ATLAS_IN_CODER=true
  ATLAS_DEFAULT_SPLIT="false"      # No tmux split in Coder (use VS Code terminals)
  ATLAS_WORKSPACE_ROOT="${HOME}"   # Workspace root is $HOME in Coder
fi
export ATLAS_IN_CODER

# ─── User Preset Loading (ATLAS_PROFILE — e.g. "axoiq") ─────
# Note: distinct from Launch Profiles (~/.atlas/profiles/*.yaml, loaded below).
ATLAS_PROFILE="unknown"
if [ -f "$HOME/.atlas/profile.json" ]; then
  ATLAS_PROFILE=$(python3 -c "import json; print(json.load(open('$HOME/.atlas/profile.json'))['profile'])" 2>/dev/null || echo "unknown")
fi
export ATLAS_PROFILE

# ─── Launch Profile Loading (v5.28.0+) ──────────────────────
# ATLAS_LAUNCH_PROFILE = active launch profile (YAML in ~/.atlas/profiles/)
# Distinct from ATLAS_PROFILE (user preset like "axoiq").
#
# Schema: templates/profiles/base.yaml (comments document all fields).
# Parser: yq v4+ (github.com/mikefarah/yq)
# Inheritance: profiles can `extends: base`, max depth 3 (base → parent → leaf).
#
# After load, these env vars are set (empty if field missing):
#   ATLAS_LP_TIER, ATLAS_LP_PERMISSION_MODE, ATLAS_LP_EFFORT,
#   ATLAS_LP_WORKTREE, ATLAS_LP_FORK_SESSION, ATLAS_LP_BARE,
#   ATLAS_LP_MCP_PROFILE, ATLAS_LP_WIFI_TRUST_REQUIRED

# _atlas_load_profile <name> → sets ATLAS_LP_* env vars
# Returns: 0=ok, 1=profile not found, 2=yq unavailable
_atlas_load_profile() {
  local profile="$1"
  local profile_dir="${HOME}/.atlas/profiles"
  local profile_file="${profile_dir}/${profile}.yaml"

  if ! command -v yq &>/dev/null; then
    echo "⚠️  [atlas] yq not installed — launch profiles require yq (github.com/mikefarah/yq v4+)" >&2
    return 2
  fi

  if [ ! -f "$profile_file" ]; then
    echo "❌ [atlas] Launch profile '$profile' not found at $profile_file" >&2
    return 1
  fi

  # Build inheritance chain (max depth 3): [base, parent, leaf]
  local -a chain=("$profile")
  local current="$profile"
  local depth=0
  while [ "$depth" -lt 3 ]; do
    local extends_val
    extends_val=$(yq eval '.extends // ""' "${profile_dir}/${current}.yaml" 2>/dev/null)
    [ -z "$extends_val" ] || [ "$extends_val" = "null" ] && break
    [ ! -f "${profile_dir}/${extends_val}.yaml" ] && {
      echo "⚠️  [atlas] Profile '$current' extends '$extends_val' but file not found. Skipping chain." >&2
      break
    }
    chain=("$extends_val" "${chain[@]}")  # Prepend base (walk up)
    current="$extends_val"
    depth=$((depth + 1))
  done

  export ATLAS_LAUNCH_PROFILE="$profile"
  export ATLAS_LP_CHAIN="${chain[*]}"

  # Load fields in chain order (base → leaf), later overrides earlier
  local fields=(tier permission_mode effort worktree fork_session bare mcp_profile wifi_trust_required)
  for field in "${fields[@]}"; do
    for p in "${chain[@]}"; do
      local val
      val=$(yq eval ".${field}" "${profile_dir}/${p}.yaml" 2>/dev/null)
      if [ -n "$val" ] && [ "$val" != "null" ]; then
        local var="ATLAS_LP_$(echo "$field" | tr '[:lower:]-' '[:upper:]_')"
        export "$var=$val"
      fi
    done
  done

  return 0
}

# _atlas_reset_launch_profile → clears all ATLAS_LP_* env vars
# Useful between launches in the same shell session.
_atlas_reset_launch_profile() {
  local v
  for v in ATLAS_LAUNCH_PROFILE ATLAS_LP_CHAIN \
           ATLAS_LP_TIER ATLAS_LP_PERMISSION_MODE ATLAS_LP_EFFORT \
           ATLAS_LP_WORKTREE ATLAS_LP_FORK_SESSION ATLAS_LP_BARE \
           ATLAS_LP_MCP_PROFILE ATLAS_LP_WIFI_TRUST_REQUIRED; do
    unset "$v"
  done
}

# _atlas_list_profiles → prints available launch profile names (one per line)
_atlas_list_profiles() {
  local profile_dir="${HOME}/.atlas/profiles"
  [ ! -d "$profile_dir" ] && return 1
  local f
  for f in "$profile_dir"/*.yaml; do
    [ -f "$f" ] && basename "$f" .yaml
  done
}

# _atlas_detect_profile → prints profile name to stdout (or empty if none match)
# Resolution order (first match wins):
#   1. Walk cwd → parent dirs looking for .atlas/project.json with "profile" field
#   2. Scan ~/.atlas/profiles/*.yaml for cwd_match glob matching $PWD
#   3. Return empty + exit 1 if no match
# Used by launcher.sh when no explicit --profile flag given AND auto-detect enabled.
_atlas_detect_profile() {
  local profile_dir="${HOME}/.atlas/profiles"
  local cwd="${PWD}"

  # 1. Walk cwd → parent for .atlas/project.json manifest
  local search="$cwd"
  while [ -n "$search" ] && [ "$search" != "/" ]; do
    if [ -f "${search}/.atlas/project.json" ]; then
      local manifest_profile
      manifest_profile=$(python3 -c "
import json, sys
try:
    with open('${search}/.atlas/project.json') as f:
        data = json.load(f)
    print(data.get('profile', ''))
except Exception:
    pass
" 2>/dev/null)
      if [ -n "$manifest_profile" ] && [ -f "${profile_dir}/${manifest_profile}.yaml" ]; then
        echo "$manifest_profile"
        return 0
      fi
    fi
    search="$(dirname "$search")"
  done

  # 2. Scan profiles for cwd_match glob
  [ ! -d "$profile_dir" ] && return 1
  command -v yq &>/dev/null || return 2

  # Enable globstar for ** matching (saved/restored)
  local _globstar_saved=false
  shopt -q globstar 2>/dev/null && _globstar_saved=true
  shopt -s globstar 2>/dev/null

  local f profile_name patterns pattern matched=""
  for f in "$profile_dir"/*.yaml; do
    [ -f "$f" ] || continue
    profile_name=$(basename "$f" .yaml)

    patterns=$(yq eval '.cwd_match // [] | .[]' "$f" 2>/dev/null)
    [ -z "$patterns" ] && continue

    while IFS= read -r pattern; do
      [ -z "$pattern" ] && continue
      # shellcheck disable=SC2053 — intentional glob match with unquoted pattern
      if [[ "$cwd" == $pattern ]]; then
        matched="$profile_name"
        break 2
      fi
    done <<< "$patterns"
  done

  # Restore globstar state
  $_globstar_saved || shopt -u globstar 2>/dev/null

  if [ -n "$matched" ]; then
    echo "$matched"
    return 0
  fi
  return 1
}

