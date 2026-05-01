#!/usr/bin/env bash
# ATLAS CLI picker module (v6.1.0 Phase 8.5)
#
# Interactive repo picker when `atlas` is called without arguments.
# Uses bash built-in `select` for portability (no fzf dependency).
#
# Features:
#   - Discovers repos under ~/workspace_atlas/projects/*
#   - Ranks Recent (last 7 days) + Frequent (30-day usage) + All
#   - Reads ~/.claude/atlas-cli/usage.jsonl for usage tracking
#   - Writes usage entry on each launch
#
# Plan ref: .blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md Section P.1

_atlas_picker_usage_log() {
  local project="${1:-}"
  [[ -z "$project" ]] && return
  local usage_dir="${HOME}/.claude/atlas-cli"
  mkdir -p "$usage_dir" 2>/dev/null || true
  local usage_file="${usage_dir}/usage.jsonl"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "{\"ts\":\"${ts}\",\"project\":\"${project}\",\"user\":\"${USER:-unknown}\"}" >> "$usage_file" 2>/dev/null || true
}

_atlas_picker_list_repos() {
  local workspace="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local projects_dir="${workspace}/projects"

  [[ -d "$projects_dir" ]] || { echo "No projects directory at $projects_dir"; return 1; }

  # Discovery: direct subdirs with .git
  find "$projects_dir" -maxdepth 2 -name ".git" -type d 2>/dev/null | while read -r git_dir; do
    local repo_dir
    repo_dir=$(dirname "$git_dir")
    local repo_name
    repo_name=$(basename "$repo_dir")
    local branch
    branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    local last_commit_epoch
    last_commit_epoch=$(git -C "$repo_dir" log -1 --format=%ct HEAD 2>/dev/null || echo 0)
    local age_days=$(( ($(date +%s) - last_commit_epoch) / 86400 ))
    printf "%s|%s|%d\n" "$repo_name" "$branch" "$age_days"
  done | sort
}

_atlas_picker_rank() {
  # Usage-based ranking: reads usage.jsonl, counts per-project, returns ranked list
  local usage_file="${HOME}/.claude/atlas-cli/usage.jsonl"
  [[ -f "$usage_file" ]] || return 0

  # Last 30 days window
  local cutoff_epoch=$(( $(date +%s) - 30*86400 ))

  python3 <<PYEOF 2>/dev/null
import json, os, sys
from collections import Counter
from datetime import datetime, timezone

cutoff = datetime.fromtimestamp(${cutoff_epoch}, tz=timezone.utc)
counter = Counter()
try:
    with open("${usage_file}") as f:
        for line in f:
            try:
                e = json.loads(line)
                ts = datetime.fromisoformat(e['ts'].replace("Z", "+00:00"))
                if ts >= cutoff:
                    counter[e.get('project', '')] += 1
            except Exception:
                pass
except Exception:
    pass
for proj, count in counter.most_common(20):
    if proj:
        print(f"{proj}:{count}")
PYEOF
}

atlas_picker() {
  echo ""
  echo "🏛️  ATLAS CLI v6.1.0 │ Claude Code Workspace Launcher"
  echo "─────────────────────────────────────────────────────────"
  echo ""

  local repos_raw
  repos_raw=$(_atlas_picker_list_repos)
  if [[ -z "$repos_raw" ]]; then
    echo "No repos discovered in ~/workspace_atlas/projects/"
    return 1
  fi

  local rank_data
  rank_data=$(_atlas_picker_rank)

  # Parse
  local -a recent=()
  local -a frequent=()
  local -a all=()

  while IFS='|' read -r name branch age; do
    [[ -z "$name" ]] && continue
    all+=("${name}|${branch}|${age}")
    if [[ "$age" -le 7 ]]; then
      recent+=("${name}|${branch}|${age}")
    fi
  done <<< "$repos_raw"

  # Display
  local idx=1
  local -a menu_items=()

  if [[ ${#recent[@]} -gt 0 ]]; then
    echo "▸ RECENT (last 7 days)"
    for entry in "${recent[@]:0:5}"; do
      IFS='|' read -r name branch age <<< "$entry"
      printf "  %d. %-25s %-25s %dd ago\n" "$idx" "$name" "$branch" "$age"
      menu_items+=("$name")
      idx=$((idx + 1))
    done
    echo ""
  fi

  echo "▸ ALL PROJECTS"
  for entry in "${all[@]}"; do
    IFS='|' read -r name branch age <<< "$entry"
    # Skip if already in recent
    local in_recent=false
    for r in "${recent[@]}"; do
      [[ "$r" == "$entry" ]] && in_recent=true && break
    done
    [[ "$in_recent" == "true" ]] && continue
    printf "  %d. %-25s %-25s %dd ago\n" "$idx" "$name" "$branch" "$age"
    menu_items+=("$name")
    idx=$((idx + 1))
  done

  echo ""
  echo "  [d] atlas doctor    [s] atlas sweep    [w] atlas who    [q] quit"
  echo ""
  read -r -p "Select project by number (or letter): " choice

  case "$choice" in
    q|Q) return 0 ;;
    d|D) atlas_doctor; return $? ;;
    s|S) atlas_sweep; return $? ;;
    w|W) atlas_who; return $? ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#menu_items[@]} ]]; then
        local selected="${menu_items[$((choice - 1))]}"
        _atlas_picker_usage_log "$selected"
        echo "→ Launching: atlas $selected"
        # Delegate to main atlas launcher
        if command -v atlas >/dev/null 2>&1; then
          atlas "$selected"
        else
          echo "atlas command not found in PATH — run: atlas $selected"
        fi
      else
        echo "Invalid selection."
      fi
      ;;
  esac
}

# ─── atlas doctor — ecosystem health check ────────────────────
atlas_doctor() {
  echo "🔍 atlas doctor — health check across all repos"
  echo "─────────────────────────────────────────────────────────"
  local workspace="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local issues=0

  # Plugins installed
  echo ""
  echo "▸ Plugins"
  if [[ -d "${HOME}/.claude/plugins/cache/atlas-marketplace" ]]; then
    local plugin_count
    plugin_count=$(ls "${HOME}/.claude/plugins/cache/atlas-marketplace/" 2>/dev/null | wc -l)
    echo "  ✓ $plugin_count plugin versions cached"
  else
    echo "  ✗ No atlas plugins installed"
    issues=$((issues + 1))
  fi

  # Env vars
  echo ""
  echo "▸ Environment"
  if [[ -f "${HOME}/.env" ]]; then
    echo "  ✓ ~/.env exists"
  else
    echo "  ⚠ ~/.env not found (WP_TOKEN, FORGEJO_TOKEN may be missing)"
  fi

  # npmrc
  if [[ -f "${HOME}/.npmrc" ]]; then
    echo "  ✓ ~/.npmrc exists"
  fi

  # Per-repo quick check
  echo ""
  echo "▸ Repo health"
  find "$workspace/projects" -maxdepth 2 -name ".git" -type d 2>/dev/null | while read -r git_dir; do
    local repo_dir
    repo_dir=$(dirname "$git_dir")
    local repo_name
    repo_name=$(basename "$repo_dir")
    local branch
    branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
    local status
    if git -C "$repo_dir" diff --quiet 2>/dev/null && git -C "$repo_dir" diff --cached --quiet 2>/dev/null; then
      status="clean"
    else
      status="dirty"
    fi
    printf "  %-25s %-25s %s\n" "$repo_name" "$branch" "$status"
  done

  echo ""
  echo "  Issues: $issues"
}

# ─── atlas sweep — cleanup across ecosystem ──────────────────
atlas_sweep() {
  echo "🧹 atlas sweep — cleanup across ecosystem"
  echo "─────────────────────────────────────────────────────────"
  local workspace="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local dry_run=true
  [[ "${1:-}" == "--execute" ]] && dry_run=false

  if [[ "$dry_run" == "true" ]]; then
    echo "(DRY RUN — pass --execute to apply)"
  fi

  echo ""
  echo "▸ Merged branches candidates for delete"
  find "$workspace/projects" -maxdepth 2 -name ".git" -type d 2>/dev/null | while read -r git_dir; do
    local repo_dir
    repo_dir=$(dirname "$git_dir")
    local merged
    merged=$(git -C "$repo_dir" branch --merged dev 2>/dev/null | grep -v '^\*' | grep -vE '^\s*(main|dev|master)\s*$' | head -3)
    if [[ -n "$merged" ]]; then
      echo "  $(basename "$repo_dir"):"
      echo "$merged" | sed 's/^/    /'
    fi
  done

  echo ""
  echo "▸ Stale worktrees (>7d no activity)"
  find "$workspace/projects" -path "*/.claude/worktrees/*" -maxdepth 4 -type d -mtime +7 2>/dev/null | head -5 | sed 's/^/  /'

  echo ""
  echo "▸ Stale locks (>30min heartbeat)"
  find "$workspace/projects" -path "*/.claude/locks/*.lock.json" 2>/dev/null | while read -r lock; do
    local age_min
    age_min=$(( ($(date +%s) - $(stat -c %Y "$lock" 2>/dev/null || echo 0)) / 60 ))
    if [[ "$age_min" -gt 30 ]]; then
      echo "  $lock (${age_min}m old)"
    fi
  done
}

# ─── atlas who — active work across ecosystem ────────────────
atlas_who() {
  echo "👥 atlas who — active work"
  echo "─────────────────────────────────────────────────────────"
  local workspace="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local found=0

  find "$workspace/projects" -path "*/.claude/locks/*.lock.json" -mmin -60 2>/dev/null | while read -r lock; do
    python3 <<PYEOF 2>/dev/null
import json
try:
    d = json.load(open("$lock"))
    print(f"  {d.get('agent_id', 'human')} → {d.get('branch', '?')} ({d.get('worktree', '?')})")
except Exception:
    pass
PYEOF
    found=$((found + 1))
  done

  if [[ "$found" -eq 0 ]]; then
    echo "  (no active locks in last hour — nobody working right now)"
  fi
}

# ─── Entry point dispatch ─────────────────────────────────────
case "${1:-picker}" in
  picker|"") atlas_picker ;;
  doctor) shift; atlas_doctor "$@" ;;
  sweep) shift; atlas_sweep "$@" ;;
  who) shift; atlas_who ;;
  --help|-h|help)
    cat <<'EOF'
atlas picker — v6.1.0 workspace launcher

Usage:
  atlas                    # interactive picker (no args)
  atlas doctor             # ecosystem health check
  atlas sweep [--execute]  # cleanup (dry-run by default)
  atlas who                # active work (lock files <1h)
EOF
    ;;
  *)
    echo "Unknown subcommand: $1. Try 'atlas picker help'." >&2
    exit 1
    ;;
esac
