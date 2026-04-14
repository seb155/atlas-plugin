#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Session Names, Project Discovery, History, Branding
# Sourced by atlas-cli.sh — do not execute directly

# ─── Session Name Generator ──────────────────────────────────
_cc_session_name() {
  local dir="${1%/}" topic="$2"
  local repo ver branch name
  repo="${dir##*/}"
  ver=$(cat "$dir/VERSION" 2>/dev/null || jq -r '.version // empty' "$dir/package.json" 2>/dev/null || echo "")
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  name="${repo}"
  [ -n "$ver" ] && name="${name}-v${ver}"
  [ -n "$branch" ] && [ "$branch" != "main" ] && name="${name}-${branch}"
  [ -n "$topic" ] && name="${name}-${topic}"
  echo "$name"
}

# ─── Project Discovery ────────────────────────────────────────
_atlas_discover_projects() {
  local root="$ATLAS_WORKSPACE_ROOT"
  local -a results=()

  # Scan known directories for .git repos
  for scan_dir in "$root" "$root/projects/atlas" "$root/projects"; do
    [ -d "$scan_dir" ] || continue
    for d in "$scan_dir"/*/; do
      [ -d "$d/.git" ] || [ -d "$d/.claude" ] || continue
      local name="${d%/}"
      name="$(basename "$name")"
      results+=("$name:${d%/}")
    done
  done

  # Deduplicate by name (first match wins)
  local -A seen
  for entry in "${results[@]}"; do
    local n="${entry%%:*}"
    [ -z "${seen[$n]+x}" ] && { seen[$n]=1; echo "$entry"; }
  done
}

_atlas_resolve_project() {
  local name="$1"
  [ -z "$name" ] && return 1

  # Direct directory check first
  [ -d "$name" ] && { echo "$name"; return 0; }

  # Scan workspace
  _atlas_discover_projects | while IFS=: read pname ppath; do
    [ "$pname" = "$name" ] && { echo "$ppath"; return 0; }
  done
}

_atlas_known_projects() {
  _atlas_discover_projects | while IFS=: read pname ppath; do
    echo "$pname"
  done
}

# ─── Usage History (recency tracking) ─────────────────────────
_atlas_record_history() {
  local project="$1"
  local ts=$(/usr/bin/date -u +%Y-%m-%dT%H:%M:%SZ)
  python3 -c "
import json, os
path = os.path.expanduser('$ATLAS_HISTORY')
try:
    with open(path) as f: h = json.load(f)
except: h = {}
h['$project'] = {'last_used': '$ts', 'count': h.get('$project', {}).get('count', 0) + 1}
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f: json.dump(h, f, indent=2)
" 2>/dev/null
}

_atlas_recent_projects() {
  local limit="${1:-5}"
  if [ -f "$ATLAS_HISTORY" ]; then
    python3 -c "
import json, os
try:
    with open(os.path.expanduser('$ATLAS_HISTORY')) as f: h = json.load(f)
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    items = []
    for name, data in h.items():
        try:
            lu = datetime.fromisoformat(data['last_used'].replace('Z','+00:00'))
            delta = now - lu
            if delta.days > 0:
                ago = f'{delta.days}d ago'
            elif delta.seconds > 3600:
                ago = f'{delta.seconds // 3600}h ago'
            else:
                ago = f'{delta.seconds // 60}m ago'
        except:
            ago = '?'
        items.append((name, ago, data.get('count', 0), data.get('last_used', '')))
    items.sort(key=lambda x: x[3], reverse=True)
    for name, ago, count, _ in items[:$limit]:
        print(f'{name}|{ago}|{count}')
except Exception as e:
    pass
" 2>/dev/null
  fi
}

# ─── Branding & Colors ────────────────────────────────────────
ATLAS_GOLD="\033[38;5;214m"
ATLAS_NAVY="\033[38;5;18m"
ATLAS_CYAN="\033[1;36m"
ATLAS_DIM="\033[2m"
ATLAS_BOLD="\033[1m"
ATLAS_RESET="\033[0m"

_atlas_header() {
  local plugin_ver=$(_atlas_plugin_version)
  echo ""
  if $ATLAS_HAS_GUM; then
    gum style --border rounded --border-foreground 214 --padding "0 2" --margin "0 1" \
      "🏛️ ATLAS — AXOIQ Engineering Platform" \
      "v${plugin_ver} | CC ${ATLAS_CC_VERSION} | ${ATLAS_HOSTNAME} (${ATLAS_OS}/${ATLAS_ARCH})"
  else
    printf "${ATLAS_GOLD}┌──────────────────────────────────────────────┐${ATLAS_RESET}\n"
    printf "${ATLAS_GOLD}│${ATLAS_RESET}  🏛️ ${ATLAS_BOLD}ATLAS${ATLAS_RESET} — AXOIQ Engineering Platform     ${ATLAS_GOLD}│${ATLAS_RESET}\n"
    printf "${ATLAS_GOLD}│${ATLAS_RESET}  v${plugin_ver} | CC ${ATLAS_CC_VERSION} | ${ATLAS_HOSTNAME}                  ${ATLAS_GOLD}│${ATLAS_RESET}\n"
    printf "${ATLAS_GOLD}└──────────────────────────────────────────────┘${ATLAS_RESET}\n"
  fi
}

_atlas_plugin_version() {
  local cache_dir="${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin"
  if [ -d "$cache_dir" ]; then
    # Get latest version dir
    ls -v "$cache_dir" 2>/dev/null | tail -1 | xargs -I{} cat "$cache_dir/{}/VERSION" 2>/dev/null | tr -d '[:space:]'
  else
    echo "?.?.?"
  fi
}

_atlas_footer() {
  printf "\n  ${ATLAS_DIM}© 2026 AXOIQ Inc. | Proprietary | atlas@axoiq.com${ATLAS_RESET}\n\n"
}

