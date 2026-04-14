#!/usr/bin/env zsh
# ATLAS CLI Module: Subcommands (list, resume, status, dashboard, help, hooks, doctor)
# Sourced by atlas-cli.sh — do not execute directly

# ─── Subcommands ──────────────────────────────────────────────

# atlas list [--all]
_atlas_list() {
  _atlas_header

  if [[ "$1" == "--all" ]]; then
    printf "  ${ATLAS_BOLD}All projects${ATLAS_RESET} ${ATLAS_DIM}(scanning ${ATLAS_WORKSPACE_ROOT})${ATLAS_RESET}\n\n"
    _atlas_discover_projects | while IFS=: read pname ppath; do
      local desc=""
      [ -f "$ppath/.claude/CLAUDE.md" ] && desc=$(/usr/bin/head -1 "$ppath/.claude/CLAUDE.md" 2>/dev/null | /usr/bin/sed 's/^#\s*//')
      [ -z "$desc" ] && [ -f "$ppath/CLAUDE.md" ] && desc=$(/usr/bin/head -1 "$ppath/CLAUDE.md" 2>/dev/null | /usr/bin/sed 's/^#\s*//')
      printf "    ${ATLAS_CYAN}%-14s${ATLAS_RESET} %-44s ${ATLAS_DIM}%s${ATLAS_RESET}\n" "$pname" "$ppath" "$desc"
    done
  else
    printf "  ${ATLAS_BOLD}Recent projects${ATLAS_RESET}\n\n"
    local has_recent=false
    _atlas_recent_projects 8 | while IFS='|' read pname ago count; do
      has_recent=true
      local ppath=$(_atlas_resolve_project "$pname")
      printf "    ${ATLAS_CYAN}%-14s${ATLAS_RESET} ${ATLAS_DIM}%-10s${ATLAS_RESET} (${count}x)\n" "$pname" "$ago"
    done
    if ! $has_recent; then
      printf "    ${ATLAS_DIM}No history yet. Run 'atlas list --all' to discover projects.${ATLAS_RESET}\n"
    fi
  fi

  _atlas_footer
}

# atlas resume [project]
_atlas_resume() {
  # v5.7.0+ — Dual-mode resume (Phase 4):
  #   1. atlas resume               → claude -c (last session)
  #   2. atlas resume <project>     → cd to project + claude -c (legacy)
  #   3. atlas resume <session-name> → claude --resume <name> (v2.0.64+)
  # Disambiguation: project lookup first, fallback to --resume by name.
  local arg="$1"
  if [[ -z "$arg" ]]; then
    claude -c --chrome
    return
  fi

  # Priority 1: resolve as project path (legacy behavior)
  local path
  path=$(_atlas_resolve_project "$arg" 2>/dev/null || echo "")
  if [[ -n "$path" ]]; then
    builtin cd "$path" && claude -c --chrome
    return
  fi

  # Priority 2: pass through as --resume session name (v2.0.64+)
  echo "Resuming session by name: $arg (via claude --resume)"
  claude --resume "$arg"
}

# atlas status
_atlas_status() {
  _atlas_header
  printf "  ${ATLAS_BOLD}System Status${ATLAS_RESET}\n\n"

  # Git branch
  local branch=$(git branch --show-current 2>/dev/null || echo "N/A")
  local repo="${$(git rev-parse --show-toplevel 2>/dev/null):t}"
  [ -z "$repo" ] && repo="N/A"
  printf "  📂 %-14s ${ATLAS_CYAN}%s${ATLAS_RESET} (branch: ${ATLAS_CYAN}%s${ATLAS_RESET})\n" "Repo" "$repo" "$branch"

  # Worktree count
  local WORKSPACE="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local wt_count=$(find "$WORKSPACE" -maxdepth 5 -path "*/.claude/worktrees/*/.git" -type f 2>/dev/null | /usr/bin/wc -l)
  local wt_manual=$(find "$WORKSPACE" -maxdepth 4 -path "*/.worktrees/*/.git" -type f 2>/dev/null | /usr/bin/wc -l)
  printf "  🌿 %-14s %d CC + %d manual\n" "Worktrees" "$wt_count" "$wt_manual"

  # Tmux sessions
  local tmux_count=0
  if $ATLAS_HAS_TMUX; then
    tmux_count=$(/usr/bin/tmux list-sessions 2>/dev/null | grep -c 'cc-' || echo 0)
  fi
  printf "  🖥️  %-14s %d active\n" "Sessions" "$tmux_count"

  # Memory files
  local mem_dir=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | /usr/bin/head -1)
  if [ -n "$mem_dir" ] && [ -d "$mem_dir" ]; then
    local mem_count=$(ls "$mem_dir"/*.md 2>/dev/null | /usr/bin/wc -l)
    local mem_lines=$(/usr/bin/wc -l < "$mem_dir/MEMORY.md" 2>/dev/null || echo 0)
    local mem_color="${ATLAS_GREEN}"
    [ "$mem_lines" -gt 150 ] && mem_color="${ATLAS_YELLOW}"
    [ "$mem_lines" -gt 200 ] && mem_color="${ATLAS_RED}"
    printf "  🧠 %-14s %d files, ${mem_color}%d${ATLAS_RESET} lines index\n" "Memory" "$mem_count" "$mem_lines"
  fi

  # CI status (Woodpecker CI)
  if [ -n "${WP_TOKEN:-}" ]; then
    local wp_url="${WP_URL:-http://192.168.10.76:8000}"
    local ci_status
    ci_status=$(curl -sf --max-time 3 "${wp_url}/api/repos/1/pipelines?per_page=1" \
      -H "Authorization: Bearer ${WP_TOKEN}" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data:
        p = data[0]
        s = p.get('status','?')
        n = p.get('number','?')
        if s == 'success': print(f'✅ #{n}')
        elif s == 'failure': print(f'❌ #{n}')
        elif s in ('running','pending'): print(f'⏳ #{n}')
        elif s == 'killed': print(f'⚠️ #{n} killed')
        else: print(f'⚪ #{n} {s}')
    else: print('⚪ N/A')
except: print('⚪ N/A')
" 2>/dev/null || echo "⚪ N/A")
    printf "  🔧 %-14s %s\n" "CI" "$ci_status"
  fi

  # Plugin version
  local plugin_ver=$(_atlas_plugin_version 2>/dev/null || echo "?")
  printf "  🔌 %-14s v%s\n" "Plugin" "$plugin_ver"

  printf "\n"
  _atlas_footer
}

# atlas plans [stale] — Plan lifecycle dashboard
_atlas_plans() {
  local plans_dir=".blueprint/plans"
  [ -d "$plans_dir" ] || plans_dir="$(git rev-parse --show-toplevel 2>/dev/null)/.blueprint/plans"
  [ -d "$plans_dir" ] || { echo "No .blueprint/plans/ found"; return 1; }

  local subcmd="${1:-scan}"  # scan, stale, roadmap
  local script=""
  local search_paths=(
    "${ATLAS_SHELL_DIR}/../scripts/plan-lifecycle.sh"
    "${ATLAS_SHELL_DIR}/../../scripts/plan-lifecycle.sh"
    "${ATLAS_PLUGIN_SOURCE:-$HOME/workspace_atlas/projects/atlas-dev-plugin}/scripts/plan-lifecycle.sh"
  )
  # Also search plugin cache (shell-agnostic)
  if command -v find >/dev/null 2>&1; then
    while IFS= read -r p; do
      [ -f "$p" ] && search_paths+=("$p")
    done < <(find "${HOME}/.claude/plugins/cache" -maxdepth 3 -name "plan-lifecycle.sh" 2>/dev/null)
  fi
  for p in "${search_paths[@]}"; do
    [ -f "$p" ] && { script="$p"; break; }
  done
  [ -z "$script" ] && { echo "plan-lifecycle.sh not found"; return 1; }

  bash "$script" "$subcmd" "$plans_dir"
}

# ── Plugin Tools (SP-EVOLUTION P9) ────────────────────────────

_find_plugin_tools() {
  local search_paths=(
    "${ATLAS_SHELL_DIR}/../scripts/plugin-tools.sh"
    "${ATLAS_SHELL_DIR}/../../scripts/plugin-tools.sh"
    "${ATLAS_PLUGIN_SOURCE:-$HOME/workspace_atlas/projects/atlas-dev-plugin}/scripts/plugin-tools.sh"
  )
  if command -v find >/dev/null 2>&1; then
    while IFS= read -r p; do
      [ -f "$p" ] && search_paths+=("$p")
    done < <(find "${HOME}/.claude/plugins/cache" -maxdepth 3 -name "plugin-tools.sh" 2>/dev/null)
  fi
  for p in "${search_paths[@]}"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

# atlas repos — Multi-repo workspace overview
_atlas_repos() {
  local script=$(_find_plugin_tools) || { echo "plugin-tools.sh not found"; return 1; }
  bash "$script" repos
}

# atlas cost — Session cost estimates
_atlas_cost() {
  local script=$(_find_plugin_tools) || { echo "plugin-tools.sh not found"; return 1; }
  bash "$script" cost "$@"
}

# atlas deps — Plan dependency graph
_atlas_deps() {
  local plans_dir=".blueprint/plans"
  [ -d "$plans_dir" ] || plans_dir="$(git rev-parse --show-toplevel 2>/dev/null)/.blueprint/plans"
  [ -d "$plans_dir" ] || { echo "No .blueprint/plans/ found"; return 1; }
  local script=$(_find_plugin_tools) || { echo "plugin-tools.sh not found"; return 1; }
  bash "$script" deps "$plans_dir"
}

# atlas init [template] [dir] — Project scaffolding
_atlas_init() {
  local script=$(_find_plugin_tools) || { echo "plugin-tools.sh not found"; return 1; }
  bash "$script" init "$@"
}

# ── Session Tools (SP-EVOLUTION P6) ───────────────────────────

_find_session_tools() {
  local search_paths=(
    "${ATLAS_SHELL_DIR}/../scripts/session-tools.sh"
    "${ATLAS_SHELL_DIR}/../../scripts/session-tools.sh"
    "${ATLAS_PLUGIN_SOURCE:-$HOME/workspace_atlas/projects/atlas-dev-plugin}/scripts/session-tools.sh"
  )
  if command -v find >/dev/null 2>&1; then
    while IFS= read -r p; do
      [ -f "$p" ] && search_paths+=("$p")
    done < <(find "${HOME}/.claude/plugins/cache" -maxdepth 3 -name "session-tools.sh" 2>/dev/null)
  fi
  for p in "${search_paths[@]}"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

# atlas sessions — Show active tmux/worktree sessions
_atlas_sessions() {
  local script=$(_find_session_tools) || { echo "session-tools.sh not found"; return 1; }
  bash "$script" sessions
}

# atlas budget — Context budget estimate
_atlas_budget() {
  local script=$(_find_session_tools) || { echo "session-tools.sh not found"; return 1; }
  bash "$script" budget
}

# atlas import-handoff <file> — Parse handoff → session-state.json
_atlas_import_handoff() {
  local file="${1:-}"
  [ -z "$file" ] && { echo "Usage: atlas import-handoff <handoff-file.md>"; return 1; }
  local script=$(_find_session_tools) || { echo "session-tools.sh not found"; return 1; }
  bash "$script" import "$file"
}

# atlas replay — Session replay log stats
_atlas_replay() {
  local script=$(_find_session_tools) || { echo "session-tools.sh not found"; return 1; }
  bash "$script" replay "$@"
}

# atlas complexity "description" — Classify task complexity for model selection
_atlas_complexity() {
  local desc="$*"
  [ -z "$desc" ] && { echo "Usage: atlas complexity \"task description\""; return 1; }
  local script="${ATLAS_SHELL_DIR}/../scripts/task-complexity.sh"
  [ -f "$script" ] || script="${${ATLAS_SHELL_DIR:h}:h}/scripts/task-complexity.sh"
  [ -f "$script" ] || { echo "task-complexity.sh not found"; return 1; }
  local result=$(bash "$script" "$desc")
  local level=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['level'])" 2>/dev/null)
  local model=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['model'])" 2>/dev/null)
  local score=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['score'])" 2>/dev/null)
  local icon="🟢"
  case "$level" in
    trivial) icon="🟢" ;;
    moderate) icon="🟡" ;;
    complex) icon="🟠" ;;
    architectural) icon="🔴" ;;
  esac
  echo "${icon} ${level} → ${model} (score: ${score})"
}

# atlas ci — Show CI pipeline status from Woodpecker CI
_atlas_ci() {
  _atlas_header
  printf "  ${ATLAS_BOLD}CI Pipeline Status (Woodpecker)${ATLAS_RESET}\n\n"

  local token="${WP_TOKEN:-}"
  local wp_url="${WP_URL:-http://192.168.10.76:8000}"

  if [ -z "$token" ]; then
    [ -f "$HOME/.env" ] && source "$HOME/.env" 2>/dev/null
    token="${WP_TOKEN:-}"
  fi

  if [ -z "$token" ]; then
    printf "  ${ATLAS_DIM}WP_TOKEN not set. Generate at ci.axoiq.com/user/cli-and-api${ATLAS_RESET}\n"
    _atlas_footer
    return 1
  fi

  local sha=$(git rev-parse HEAD 2>/dev/null | /usr/bin/head -c 12 || echo "?")
  local branch=$(git branch --show-current 2>/dev/null || echo "?")

  printf "  📂 ${ATLAS_CYAN}axoiq/synapse${ATLAS_RESET} @ ${ATLAS_DIM}%s${ATLAS_RESET} (%s)\n\n" "$sha" "$branch"

  # Fetch recent pipelines
  curl -sf --max-time 5 "${wp_url}/api/repos/1/pipelines?per_page=5" \
    -H "Authorization: Bearer ${token}" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if not data:
        print('  No pipelines found.')
        sys.exit(0)
    for p in data:
        n = p.get('number', '?')
        status = p.get('status', '?')
        branch = p.get('branch', '?')
        sha = p.get('commit', '?')[:7]
        msg = p.get('message', '')[:40]
        icon = '✅' if status == 'success' else '❌' if status in ('failure','error') else '⏳' if status in ('running','pending') else '⚠️' if status == 'killed' else '⚪'
        print(f'  {icon} #{n} {status:10s} {branch} ({sha})')
        if msg:
            print(f'     {msg}')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null || printf "  ${ATLAS_DIM}Could not reach Woodpecker API at ${wp_url}${ATLAS_RESET}\n"

  printf "\n  🔗 ${ATLAS_DIM}https://ci.axoiq.com/repos/1${ATLAS_RESET}\n\n"
  _atlas_footer
}

# atlas worktrees (aliases: wt)
_atlas_worktrees() {
  _atlas_header
  printf "  ${ATLAS_BOLD}Git Worktrees${ATLAS_RESET} ${ATLAS_DIM}(scanning workspace)${ATLAS_RESET}\n\n"

  local WORKSPACE="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local NOW_EPOCH=$(/usr/bin/date +%s)
  local found=0

  printf "  ${ATLAS_DIM}%-20s %-24s %-8s %-8s %-6s${ATLAS_RESET}\n" "WORKTREE" "BRANCH" "DIRTY" "AHEAD" "AGE"
  printf "  ${ATLAS_DIM}%-20s %-24s %-8s %-8s %-6s${ATLAS_RESET}\n" "────────────────────" "────────────────────────" "────────" "────────" "──────"

  for repo_dir in $(find "$WORKSPACE" -maxdepth 4 -name ".claude" -type d 2>/dev/null); do
    local wt_dir="$repo_dir/worktrees"
    [ -d "$wt_dir" ] || continue
    local repo_root="${repo_dir:h}"
    [ -d "$repo_root/.git" ] || continue
    local repo_name="${repo_root:t}"

    for wt in "$wt_dir"/*(N/); do
      [ -d "$wt" ] || continue
      local name="${wt:t}"
      found=$((found + 1))

      # Get branch
      local branch=$(cd "$wt" && git branch --show-current 2>/dev/null || echo "?")

      # Check dirty
      local dirty_count=$(cd "$wt" && git status --porcelain 2>/dev/null | grep -v node_modules | /usr/bin/wc -l)
      local dirty_str="${ATLAS_GREEN}clean${ATLAS_RESET}"
      [ "$dirty_count" -gt 0 ] && dirty_str="${ATLAS_YELLOW}${dirty_count} files${ATLAS_RESET}"

      # Check ahead
      local ahead=$(cd "$wt" && git log dev..HEAD --oneline 2>/dev/null | /usr/bin/wc -l)
      local ahead_str="${ATLAS_DIM}0${ATLAS_RESET}"
      [ "$ahead" -gt 0 ] && ahead_str="${ATLAS_CYAN}${ahead}${ATLAS_RESET}"

      # Age in days
      local last_epoch=$(cd "$wt" && git log -1 --format=%ct HEAD 2>/dev/null || echo "$NOW_EPOCH")
      local age_days=$(( (NOW_EPOCH - last_epoch) / 86400 ))
      local age_str="${age_days}d"
      [ "$age_days" -ge 7 ] && age_str="${ATLAS_YELLOW}${age_days}d${ATLAS_RESET}"
      [ "$age_days" -ge 14 ] && age_str="${ATLAS_RED}${age_days}d${ATLAS_RESET}"

      printf "  %-20s %-24s %-8s %-8s %-6s\n" "${repo_name}/${name}" "$branch" "$dirty_str" "$ahead_str" "$age_str"
    done

    # Also check .worktrees/ (manual)
    local manual_dir="$repo_root/.worktrees"
    if [ -d "$manual_dir" ]; then
      for wt in "$manual_dir"/*(N/); do
        [ -d "$wt" ] || continue
        local name="${wt:t}"
        found=$((found + 1))
        local branch=$(cd "$wt" && git branch --show-current 2>/dev/null || echo "?")
        local dirty_count=$(cd "$wt" && git status --porcelain 2>/dev/null | grep -v node_modules | /usr/bin/wc -l)
        local dirty_str="${ATLAS_GREEN}clean${ATLAS_RESET}"
        [ "$dirty_count" -gt 0 ] && dirty_str="${ATLAS_YELLOW}${dirty_count} files${ATLAS_RESET}"
        local ahead=$(cd "$wt" && git log dev..HEAD --oneline 2>/dev/null | /usr/bin/wc -l)
        local ahead_str="${ATLAS_DIM}0${ATLAS_RESET}"
        [ "$ahead" -gt 0 ] && ahead_str="${ATLAS_CYAN}${ahead}${ATLAS_RESET}"
        local last_epoch=$(cd "$wt" && git log -1 --format=%ct HEAD 2>/dev/null || echo "$NOW_EPOCH")
        local age_days=$(( (NOW_EPOCH - last_epoch) / 86400 ))
        local age_str="${age_days}d"
        [ "$age_days" -ge 7 ] && age_str="${ATLAS_YELLOW}${age_days}d${ATLAS_RESET}"
        printf "  %-20s %-24s %-8s %-8s %-6s\n" "${repo_name}/${name}*" "$branch" "$dirty_str" "$ahead_str" "$age_str"
      done
    fi
  done

  if [ "$found" -eq 0 ]; then
    printf "  ${ATLAS_DIM}No worktrees found.${ATLAS_RESET}\n"
  fi
  printf "\n  ${ATLAS_DIM}* = manual (.worktrees/)${ATLAS_RESET}\n"

  _atlas_footer
}

# atlas cleanup [--age N] [--dry-run]
# Remove stale worktrees (default: older than 14 days, clean, no unmerged commits)
_atlas_cleanup() {
  local age_threshold=14
  local dry_run=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --age)   age_threshold="$2"; shift 2 ;;
      --age=*) age_threshold="${1#*=}"; shift ;;
      --dry-run|-n) dry_run=true; shift ;;
      *) shift ;;
    esac
  done

  _atlas_header
  printf "  ${ATLAS_BOLD}Worktree Cleanup${ATLAS_RESET} ${ATLAS_DIM}(stale > ${age_threshold}d, clean, no unmerged)${ATLAS_RESET}\n\n"

  local WORKSPACE="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local NOW_EPOCH=$(/usr/bin/date +%s)
  local removed=0
  local skipped=0

  for repo_dir in $(find "$WORKSPACE" -maxdepth 4 -name ".claude" -type d 2>/dev/null); do
    local repo_root="${repo_dir:h}"
    [ -d "$repo_root/.git" ] || continue
    local repo_name="${repo_root:t}"

    # Scan both .claude/worktrees/ (CC-auto) and .worktrees/ (manual)
    for wt_parent in "$repo_dir/worktrees" "$repo_root/.worktrees"; do
      [ -d "$wt_parent" ] || continue
      for wt in "$wt_parent"/*(N/); do
        [ -d "$wt" ] || continue
        local name="${wt:t}"

        # Skip if dirty
        local dirty_count=$(cd "$wt" && git status --porcelain 2>/dev/null | grep -v node_modules | /usr/bin/wc -l)
        if [ "$dirty_count" -gt 0 ]; then
          printf "  ${ATLAS_DIM}⊘${ATLAS_RESET} ${repo_name}/${name} ${ATLAS_YELLOW}(${dirty_count} dirty files, skipping)${ATLAS_RESET}\n"
          skipped=$((skipped + 1)); continue
        fi

        # Skip if ahead of dev (unmerged commits)
        local ahead=$(cd "$wt" && git log dev..HEAD --oneline 2>/dev/null | /usr/bin/wc -l)
        if [ "$ahead" -gt 0 ]; then
          printf "  ${ATLAS_DIM}⊘${ATLAS_RESET} ${repo_name}/${name} ${ATLAS_CYAN}(${ahead} unmerged commits, skipping)${ATLAS_RESET}\n"
          skipped=$((skipped + 1)); continue
        fi

        # Check age
        local last_epoch=$(cd "$wt" && git log -1 --format=%ct HEAD 2>/dev/null || echo "$NOW_EPOCH")
        local age_days=$(( (NOW_EPOCH - last_epoch) / 86400 ))
        if [ "$age_days" -lt "$age_threshold" ]; then
          # Not old enough, skip silently
          continue
        fi

        # Candidate for removal
        if $dry_run; then
          printf "  ${ATLAS_YELLOW}would remove${ATLAS_RESET} ${repo_name}/${name} ${ATLAS_DIM}(${age_days}d old)${ATLAS_RESET}\n"
        else
          if (cd "$repo_root" && git worktree remove --force "$wt" 2>/dev/null); then
            printf "  ${ATLAS_GREEN}✓ removed${ATLAS_RESET} ${repo_name}/${name} ${ATLAS_DIM}(${age_days}d old)${ATLAS_RESET}\n"
            removed=$((removed + 1))
          else
            printf "  ${ATLAS_RED}✗ failed${ATLAS_RESET} ${repo_name}/${name} ${ATLAS_DIM}(try: git worktree prune)${ATLAS_RESET}\n"
          fi
        fi
      done
    done
  done

  printf "\n"
  if $dry_run; then
    printf "  ${ATLAS_DIM}Dry run. Rerun without --dry-run to apply.${ATLAS_RESET}\n"
  else
    printf "  ${ATLAS_BOLD}Summary${ATLAS_RESET}: ${ATLAS_GREEN}${removed} removed${ATLAS_RESET}, ${ATLAS_DIM}${skipped} skipped${ATLAS_RESET}\n"
  fi
  _atlas_footer
}

# atlas dashboard (aliases: dash, d)
_atlas_dashboard() {
  local TOPICS_FILE="${HOME}/.atlas/topics.json"

  echo ""
  echo " ATLAS Sessions                                        $(/usr/bin/date '+%Y-%m-%d %H:%M %Z')"
  echo " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Get tmux sessions
  local has_sessions=false
  if $ATLAS_HAS_TMUX && /usr/bin/tmux list-sessions 2>/dev/null | grep -q "cc-"; then
    echo " # │ Session              │ Project  │ Topic       │ Branch              │ Status"
    echo " ──┼──────────────────────┼──────────┼─────────────┼─────────────────────┼────────"

    local idx=0
    /usr/bin/tmux list-windows -a -F '#{session_name}:#{window_name}:#{window_active}:#{pane_current_path}' 2>/dev/null | \
      grep "^cc-" | while IFS=: read -r sess win active cwd; do
      idx=$((idx + 1))

      # Extract project and topic from session name
      local project topic branch status
      project=$(echo "$sess" | /usr/bin/sed 's/^cc-//' | /usr/bin/cut -d- -f1)
      topic=$(echo "$sess" | /usr/bin/sed 's/^cc-[^-]*-*//')
      [ -z "$topic" ] && topic="(default)"

      # Get branch from cwd
      branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "—")
      [ ${#branch} -gt 20 ] && branch="${branch:0:17}..."

      # Status
      if [ "$active" = "1" ]; then
        status="ACTIVE"
      else
        status="IDLE"
      fi

      printf " %d │ %-20s │ %-8s │ %-11s │ %-19s │ %s\n" \
        "$idx" "$sess" "$project" "$topic" "$branch" "$status"
      has_sessions=true
    done

    if ! $has_sessions; then
      echo " (no active CC sessions in tmux)"
    fi
  else
    echo " (no tmux sessions found — start one with: atlas <project> [topic])"
  fi

  echo " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Topic summary from registry
  if [ -f "$TOPICS_FILE" ]; then
    local active_count completed_count
    active_count=$(python3 -c "import json; d=json.load(open('$TOPICS_FILE')); print(sum(1 for v in d.values() if v.get('status')=='active'))" 2>/dev/null || echo "0")
    completed_count=$(python3 -c "import json; d=json.load(open('$TOPICS_FILE')); print(sum(1 for v in d.values() if v.get('status')=='completed'))" 2>/dev/null || echo "0")
    echo " Topics: ${active_count} active, ${completed_count} completed"
  fi

  # ── Health & Version ────────────────────────────────────────────
  echo ""

  # Plugin version (from VERSION file in source)
  local plugin_version="?"
  local plugin_src="${ATLAS_PLUGIN_SOURCE:-$HOME/workspace_atlas/projects/atlas-dev-plugin}"
  [ -f "$plugin_src/VERSION" ] && plugin_version=$(cat "$plugin_src/VERSION" | tr -d '[:space:]')

  # Installed cache version
  local cache_version="?"
  local cache_dir="${HOME}/.claude/plugins/cache/atlas-admin-marketplace"
  if [ -d "$cache_dir" ]; then
    cache_version=$(ls -1 "$cache_dir/atlas-admin/" 2>/dev/null | sort -V | tail -1)
  fi

  # Version sync status
  local sync_status="✅ synced"
  if [ "$plugin_version" != "$cache_version" ]; then
    sync_status="⚠️  drift ($plugin_version → $cache_version)"
  fi

  echo " Plugin: v${cache_version} ${sync_status}"

  # Dream health score (last dream report)
  local memory_dir
  memory_dir=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | /usr/bin/head -1)
  if [ -n "$memory_dir" ] && [ -f "$memory_dir/dream-history.jsonl" ]; then
    local dream_info
    dream_info=$(tail -1 "$memory_dir/dream-history.jsonl" | python3 -c "
import sys,json
d=json.loads(sys.stdin.readline())
score=d.get('score','?')
grade=d.get('grade','?')
date=d.get('date',d.get('timestamp','?'))[:10]
print(f'{score}/10 ({grade}) — {date}')
" 2>/dev/null || echo "?")
    echo " Health: ${dream_info}"
  fi

  # Hook activity (last 24h from hook-log.jsonl)
  local hook_log="${HOME}/.claude/hook-log.jsonl"
  if [ -f "$hook_log" ]; then
    local hook_stats
    hook_stats=$(python3 -c "
import json
from datetime import datetime, timedelta
cutoff = (datetime.now() - timedelta(hours=24)).isoformat()
counts = {}
with open('$hook_log') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
            if e.get('ts','') >= cutoff:
                h = e.get('handler','?')
                counts[h] = counts.get(h, 0) + 1
        except: pass
total = sum(counts.values())
top3 = sorted(counts.items(), key=lambda x: -x[1])[:3]
top_str = ', '.join(f'{k}({v})' for k,v in top3)
print(f'{total} triggers — top: {top_str}')
" 2>/dev/null || echo "?")
    echo " Hooks: ${hook_stats}"
  fi

  # TOM state (current)
  local tom_state="${HOME}/.claude/atlas-tom-state.json"
  if [ -f "$tom_state" ]; then
    local tom_info
    tom_info=$(python3 -c "
import json
with open('$tom_state') as f:
    d = json.load(f)
state = d.get('state','?')
conf = d.get('confidence',0)
if state != 'standard':
    print(f'{state} ({conf*100:.0f}%)')
else:
    print('standard')
" 2>/dev/null || echo "?")
    echo " ToM: ${tom_info}"
  fi

  # Installed plugins
  local plugin_count
  plugin_count=$(find ~/.claude/plugins/cache/atlas-admin-marketplace/ -maxdepth 1 -type d 2>/dev/null | /usr/bin/wc -l)
  plugin_count=$((plugin_count - 1))  # subtract the parent dir
  [ $plugin_count -lt 0 ] && plugin_count=0
  echo " Plugins: ${plugin_count} tiers installed"

  echo ""
}

# atlas help
_atlas_help() {
  _atlas_header

  if $ATLAS_HAS_GUM; then
    gum style --margin "0 2" "$(cat <<'HELP'
USAGE
  atlas <project> [flags] [topic] [-- claude-flags...]
  atlas <subcommand> [args]

SUBCOMMANDS
  list [--all]         Show projects (--all scans workspace)
  resume [project]     Resume most recent session
  status               Active tmux sessions
  topics               List topic registry (active & completed)
  setup                Run onboarding wizard
  doctor               Health check
  hooks                Hook health dashboard
  help                 This help

FLAGS
  -i, --inline         No worktree, no split (same terminal)
  -y, --yolo           Bypass all permissions
  -a, --auto           Auto mode (Sonnet classifier)
  -p, --plan           Plan mode (read-only)
  -b, --bare           Fast startup, no plugins/hooks
  -e, --effort LEVEL   Effort: low|medium|high|max [default: max]
      --no-split       Disable tmux split
      --no-worktree    Disable worktree
  -c, --continue       Resume most recent session
  -r, --resume NAME    Resume session by name
  -n, --name NAME      Override session name

EXAMPLES
  atlas synapse                    Default: worktree + split + effort max
  atlas synapse -y                 Yolo mode (no permission prompts)
  atlas synapse -i                 Inline (no worktree, no split)
  atlas synapse vault-fix          Named topic for session
  atlas synapse -- --model sonnet  Pass extra flags to Claude Code
  atlas                            Interactive project picker
HELP
)"
  else
    cat <<HELP
  ${ATLAS_BOLD}USAGE${ATLAS_RESET}
    atlas <project> [flags] [topic] [-- claude-flags...]
    atlas <subcommand> [args]

  ${ATLAS_BOLD}SUBCOMMANDS${ATLAS_RESET}
    list [--all]         Show projects (--all scans workspace)
    resume [project]     Resume most recent session
    status               Active tmux sessions
    dashboard (dash, d)   Session & topic overview
    topics               List topic registry (active & completed)
    setup                Run onboarding wizard
    doctor               Health check
    help                 This help

  ${ATLAS_BOLD}FLAGS${ATLAS_RESET}
    -i, --inline         No worktree, no split (same terminal)
    -y, --yolo           Bypass all permissions
    -a, --auto           Auto mode (Sonnet classifier)
    -p, --plan           Plan mode (read-only)
    -b, --bare           Fast startup, no plugins/hooks
    -e, --effort LEVEL   Effort: low|medium|high|max [default: max]
        --no-split       Disable tmux split
        --no-worktree    Disable worktree
    -c, --continue       Resume most recent session
    -r, --resume NAME    Resume session by name
    -n, --name NAME      Override session name

  ${ATLAS_BOLD}EXAMPLES${ATLAS_RESET}
    atlas synapse                    Default: worktree + split + effort max
    atlas synapse -y                 Yolo mode (no permission prompts)
    atlas synapse -i                 Inline (no worktree, no split)
    atlas synapse vault-fix          Named topic for session
    atlas synapse -- --model sonnet  Pass extra flags to Claude Code

  ${ATLAS_BOLD}DEFAULTS${ATLAS_RESET} (edit ~/.atlas/config.json → launcher)
    worktree=${ATLAS_DEFAULT_WORKTREE}  split=${ATLAS_DEFAULT_SPLIT}  effort=${ATLAS_DEFAULT_EFFORT}  chrome=${ATLAS_DEFAULT_CHROME}

  ${ATLAS_BOLD}PLATFORM${ATLAS_RESET}
    OS: ${ATLAS_OS}  Arch: ${ATLAS_ARCH}  Terminal: ${ATLAS_TERM}  Host: ${ATLAS_HOSTNAME}
    Docker: ${ATLAS_HAS_DOCKER}  Tmux: ${ATLAS_HAS_TMUX}  Bun: ${ATLAS_HAS_BUN}  gum: ${ATLAS_HAS_GUM}

HELP
  fi

  _atlas_footer
}

# atlas hooks — Hook health dashboard
_atlas_hooks() {
  _atlas_header
  printf "  ${ATLAS_CYAN}🪝 Hook Health Dashboard${ATLAS_RESET}\n\n"

  local cache="$HOME/.claude/plugins/cache/atlas-admin-marketplace"
  local settings="$HOME/.claude/settings.json"

  # 1. Plugin hooks
  local found=0
  for tier_dir in "$cache"/atlas-*/(N); do
    [ -d "$tier_dir" ] || continue
    for ver_dir in "$tier_dir"*/(N); do
      [ -d "$ver_dir" ] || continue
      local hj="$ver_dir/hooks/hooks.json"
      [ -f "$hj" ] || continue
      local tier="${tier_dir:t}"
      local events=$(python3 -c "import json; d=json.load(open('$hj')); print(len(d.get('hooks',{})))" 2>/dev/null)
      local handlers=$(python3 -c "
import json
d=json.load(open('$hj'))
t=sum(len(h) for es in d.get('hooks',{}).values() for e in es for h in [e.get('hooks',[])])
print(t)
" 2>/dev/null)
      printf "  ✅ %-20s %s events, %s handlers\n" "$tier" "$events" "$handlers"
      found=1
      break
    done
  done
  [ $found -eq 0 ] && printf "  ❌ No plugin hooks.json found\n"

  # 2. settings.json hooks (should be empty)
  echo ""
  if [ -f "$settings" ]; then
    local has_hooks=$(python3 -c "import json; d=json.load(open('$settings')); print(len(d['hooks']) if 'hooks' in d else 0)" 2>/dev/null)
    if [ "$has_hooks" != "0" ]; then
      printf "  ⚠️  settings.json has %s hook type(s) — should be 0 (plugin is SSoT)\n" "$has_hooks"
      printf "     Run: ${ATLAS_CYAN}atlas setup hooks${ATLAS_RESET} to clean up\n"
    else
      printf "  ✅ settings.json: clean (no hooks block)\n"
    fi
  fi

  # 3. Log files
  echo ""
  printf "  ${ATLAS_CYAN}📊 Hook Logs${ATLAS_RESET}\n"
  for log in task-log.jsonl permission-log.jsonl atlas-audit.log compaction-log.txt; do
    local path="$HOME/.claude/$log"
    if [ -f "$path" ]; then
      local lines=$(/usr/bin/wc -l < "$path" 2>/dev/null)
      local size=$(du -sh "$path" 2>/dev/null | /usr/bin/cut -f1)
      printf "  ✅ %-25s %s lines (%s)\n" "$log" "$lines" "$size"
    else
      printf "  ⬚  %-25s (not yet created)\n" "$log"
    fi
  done

  # 4. Stale local hooks
  echo ""
  local stale=0
  for script in "$HOME/.claude/hooks/"*.sh(N); do
    [ -f "$script" ] || continue
    local name="${${script:t}%.sh}"
    for tier_dir in "$cache"/atlas-*/(N); do
      for ver_dir in "$tier_dir"*/(N); do
        if [ -f "$ver_dir/hooks/$name" ] 2>/dev/null; then
          printf "  ⚠️  Stale: %s.sh (exists in plugin as %s)\n" "$name" "$name"
          stale=$((stale + 1))
          break 2
        fi
      done
    done
  done
  [ $stale -eq 0 ] && printf "  ✅ No stale local hooks\n"

  echo ""
  _atlas_footer
}

# atlas doctor
_atlas_doctor() {
  local fix_mode=false
  [[ "${1:-}" == "--fix" ]] && fix_mode=true

  _atlas_header
  printf "  ${ATLAS_BOLD}Health Check${ATLAS_RESET}\n\n"

  local checks=0 passed=0
  local -a failures=()

  _check() {
    checks=$((checks + 1))
    if eval "$2" &>/dev/null; then
      passed=$((passed + 1))
      printf "    ${ATLAS_CYAN}✓${ATLAS_RESET} %-30s %s\n" "$1" "$3"
    else
      failures+=("$1")
      printf "    \033[1;31m✗\033[0m %-30s %s\n" "$1" "$4"
    fi
  }

  # OS-aware install hints
  local _pkg="sudo apt install"
  [[ "$ATLAS_OS" == "macos" ]] && _pkg="brew install"
  [[ "$ATLAS_OS" == "wsl" ]] && _pkg="sudo apt install"

  printf "    ${ATLAS_BOLD}Tools${ATLAS_RESET}\n"
  _check "PATH has /usr/bin" "echo \$PATH | grep -q '/usr/bin'" "/usr/bin in PATH" "BROKEN! Run: export PATH=/usr/bin:/bin:\$PATH"
  _check "PATH has /bin" "echo \$PATH | grep -q ':/bin'" "/bin in PATH" "BROKEN! Check ~/.zshenv"
  _check "Claude Code" "[ -x ${HOME}/.local/bin/claude ]" "v${ATLAS_CC_VERSION}" "NOT INSTALLED — see code.claude.com"
  _check "gum (TUI)" "command -v gum" "$(gum --version 2>/dev/null | /usr/bin/head -1)" "Install: ${_pkg} gum (or go install github.com/charmbracelet/gum@latest)"
  _check "fzf (fuzzy)" "command -v fzf" "$(fzf --version 2>/dev/null)" "Install: ${_pkg} fzf"
  _check "tmux" "command -v tmux" "$(tmux -V 2>/dev/null)" "Install: ${_pkg} tmux"
  _check "Docker" "command -v docker" "$(docker --version 2>/dev/null | /usr/bin/head -1)" "Optional"
  _check "bun" "command -v bun" "$(bun --version 2>/dev/null)" "Install: curl -fsSL https://bun.sh/install | bash"
  _check "python3" "command -v python3" "$(python3 --version 2>/dev/null)" "REQUIRED"
  _check "jq" "command -v jq" "$(jq --version 2>/dev/null)" "Install: ${_pkg} jq"
  _check "git" "command -v git" "$(git --version 2>/dev/null)" "REQUIRED"
  _check "direnv" "command -v direnv" "$(direnv --version 2>/dev/null)" "Recommended: ${_pkg} direnv"
  _check "zoxide" "command -v zoxide" "installed" "Optional: smart cd — ${_pkg} zoxide"
  _check "starship" "command -v starship" "installed" "Optional: prompt — curl -sS https://starship.rs/install.sh | sh"

  echo ""
  printf "    ${ATLAS_BOLD}ATLAS Platform${ATLAS_RESET}\n"
  _check "ATLAS config" "[ -f $ATLAS_CONFIG ]" "$ATLAS_CONFIG" "Run: atlas setup"
  _check "ATLAS plugin" "[ -d ${HOME}/.claude/plugins/cache/atlas-admin-marketplace ]" "v$(_atlas_plugin_version)" "Install in CC: /plugin install atlas-admin"
  _check "Workspace" "[ -d $ATLAS_WORKSPACE_ROOT ]" "$ATLAS_WORKSPACE_ROOT" "Set launcher.workspace_root in config"

  echo ""
  printf "    ${ATLAS_BOLD}User Config${ATLAS_RESET}\n"

  # Check 1: .zshrc sources atlas.sh
  _check ".zshrc sources atlas.sh" \
    "grep -q 'atlas/shell/atlas.sh' '${HOME}/.zshrc'" \
    "atlas.sh sourced" \
    "Add: [ -f \"\\\$HOME/.atlas/shell/atlas.sh\" ] && source \"\\\$HOME/.atlas/shell/atlas.sh\""

  # Check 2: .zshrc ordering — direnv+zoxide must come AFTER atlas.sh source
  _check_zshrc_ordering() {
    [ ! -f "${HOME}/.zshrc" ] && return 1
    local atlas_line direnv_line zoxide_line
    atlas_line=$(grep -n 'atlas/shell/atlas.sh' "${HOME}/.zshrc" 2>/dev/null | /usr/bin/head -1 | /usr/bin/cut -d: -f1)
    direnv_line=$(grep -n 'direnv hook' "${HOME}/.zshrc" 2>/dev/null | /usr/bin/head -1 | /usr/bin/cut -d: -f1)
    zoxide_line=$(grep -n 'zoxide init' "${HOME}/.zshrc" 2>/dev/null | /usr/bin/head -1 | /usr/bin/cut -d: -f1)
    [ -z "$atlas_line" ] && return 1
    # If direnv/zoxide exist, they must come after atlas.sh
    [ -n "$direnv_line" ] && [ "$direnv_line" -lt "$atlas_line" ] && return 1
    [ -n "$zoxide_line" ] && [ "$zoxide_line" -lt "$atlas_line" ] && return 1
    return 0
  }
  _check ".zshrc ordering" "_check_zshrc_ordering" \
    "direnv+zoxide after atlas.sh" \
    "Move direnv/zoxide to END of ~/.zshrc — run: atlas setup sync"

  # Check 3: cship.toml configured
  _check "cship.toml" \
    "grep -q 'atlas_version' '${HOME}/.config/cship.toml'" \
    "ATLAS modules present" \
    "Run: atlas setup sync"

  # Check 4: starship.toml ATLAS modules
  _check "starship.toml" \
    "grep -q 'custom.atlas_version' '${HOME}/.config/starship.toml'" \
    "ATLAS modules present" \
    "Run: atlas setup sync"

  # Check 5: Statusline scripts deployed
  _check "Statusline scripts" \
    "[ -x '${HOME}/.local/share/atlas-statusline/atlas-resolve-version.sh' ]" \
    "deployed" \
    "Start a CC session to auto-deploy"

  # Check 6: atlas.sh deployed to ~/.atlas/shell/
  _check "atlas.sh deployed" \
    "[ -f '${HOME}/.atlas/shell/atlas.sh' ]" \
    "$(/usr/bin/date -r "${HOME}/.atlas/shell/atlas.sh" '+%Y-%m-%d' 2>/dev/null || echo 'present')" \
    "Start a CC session to auto-deploy"

  echo ""
  printf "    ${ATLAS_BOLD}Score: ${passed}/${checks}${ATLAS_RESET}\n"

  if [ "$passed" -eq "$checks" ]; then
    printf "    ${ATLAS_CYAN}All checks passed!${ATLAS_RESET}\n"
  else
    printf "    \033[1;33m${#failures[@]} issue(s). Run 'atlas doctor --fix' or 'atlas setup sync'.${ATLAS_RESET}\n"
  fi

  # --fix mode: offer to fix known issues
  if $fix_mode && [ ${#failures[@]} -gt 0 ] && $ATLAS_HAS_GUM; then
    echo ""
    printf "    ${ATLAS_BOLD}Auto-fix${ATLAS_RESET}\n"
    for fail in "${failures[@]}"; do
      case "$fail" in
        ".zshrc sources atlas.sh")
          if gum confirm "Add atlas.sh source to ~/.zshrc?" 2>/dev/null; then
            cp "${HOME}/.zshrc" "${HOME}/.zshrc.atlas-backup.$(/usr/bin/date +%s)"
            echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> "${HOME}/.zshrc"
            printf "    ${ATLAS_CYAN}✓${ATLAS_RESET} Added atlas.sh source to ~/.zshrc\n"
          fi ;;
        ".zshrc ordering")
          printf "    → Run 'atlas setup sync' to fix ordering\n" ;;
        "cship.toml"|"starship.toml")
          printf "    → Run 'atlas setup sync' to sync config\n" ;;
        "Statusline scripts"|"atlas.sh deployed")
          printf "    → Start a Claude Code session to auto-deploy\n" ;;
      esac
    done
  fi

  _atlas_footer
}

# atlas setup — routed to setup-wizard.sh (if loaded)
# Usage: atlas setup [all|cc|terminal|proj|<section-name>]
# Sections: identity, model, permissions, shell, secrets, projects, statusline, performance, plugins


# (Old inline setup removed — now in setup-wizard.sh)

# atlas update — Refresh CLI modules from Coder workspace skel
_atlas_update() {
  local skel="/opt/workspace-skel/.atlas/shell"
  if [ ! -d "$skel" ]; then
    echo "Not in a Coder workspace (no skel found at $skel)"
    return 1
  fi
  cp -r "$skel/modules/"* "$HOME/.atlas/shell/modules/"
  cp "$skel/atlas.sh" "$HOME/.atlas/shell/atlas.sh"
  echo "✅ ATLAS CLI updated from skel"
}

# ═══════════════════════════════════════════════════════════════════
# v4.42 additions — Bridge CI/CD + toolkit integration
# ═══════════════════════════════════════════════════════════════════

# atlas --check [project]
# Pre-flight validation without launching Claude Code.
# Reports: docker containers, Forgejo reachable, Woodpecker CI, .env, graph fresh, CC settings
_atlas_preflight() {
  local project="$1"
  _atlas_header
  printf "  ${ATLAS_BOLD}Pre-flight Checks${ATLAS_RESET}"
  [ -n "$project" ] && printf " ${ATLAS_DIM}(${project})${ATLAS_RESET}"
  printf "\n\n"

  local failures=0
  local warnings=0

  _check() {
    local name="$1" check_cmd="$2" fix_hint="$3"
    if eval "$check_cmd" &>/dev/null; then
      printf "  ${ATLAS_GREEN}✓${ATLAS_RESET} %s\n" "$name"
    else
      printf "  ${ATLAS_RED}✗${ATLAS_RESET} %s ${ATLAS_DIM}— %s${ATLAS_RESET}\n" "$name" "$fix_hint"
      failures=$((failures + 1))
    fi
  }

  _warn() {
    local name="$1" check_cmd="$2" hint="$3"
    if eval "$check_cmd" &>/dev/null; then
      printf "  ${ATLAS_GREEN}✓${ATLAS_RESET} %s\n" "$name"
    else
      printf "  ${ATLAS_YELLOW}⚠${ATLAS_RESET} %s ${ATLAS_DIM}— %s${ATLAS_RESET}\n" "$name" "$hint"
      warnings=$((warnings + 1))
    fi
  }

  # 1. Claude binary available
  _check "Claude Code installed" "command -v claude" "install: curl -fsSL https://claude.ai/install.sh | sh"

  # 2. Docker running (for synapse backend, etc.)
  if $ATLAS_HAS_DOCKER; then
    _warn "Docker daemon reachable" "docker ps" "start Docker: systemctl start docker"
  fi

  # 3. Git worktree support
  _check "Git available" "command -v git" "install git"

  # 4. .env loaded
  _warn ".env vars loaded" "[ -n \"\$FORGEJO_TOKEN\" ] || [ -f \"\$HOME/.env\" ]" "source ~/.env"

  # 5. Forgejo reachable
  if [ -n "${FORGEJO_URL:-}" ] || [ -n "${FORGEJO_TOKEN:-}" ]; then
    _warn "Forgejo reachable" "curl -sf -o /dev/null https://forgejo.axoiq.com/api/v1/version" "check VPN / Forgejo status"
  fi

  # 6. Woodpecker CI reachable
  if [ -n "${WP_TOKEN:-}" ]; then
    _warn "Woodpecker CI reachable" "curl -sf -o /dev/null https://ci.axoiq.com/api/user -H 'Authorization: Bearer $WP_TOKEN'" "check VPN / WP status"
  fi

  # 7. Tmux (if split enabled)
  if [ "$ATLAS_DEFAULT_SPLIT" = "true" ]; then
    _check "Tmux installed" "command -v tmux" "install tmux (split: true requires it)"
  fi

  # 8. Code intelligence graph freshness (if project specified or CWD is synapse)
  local workspace_root="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local proj_path=""
  if [ -n "$project" ] && [ -d "$workspace_root/projects/atlas/$project" ]; then
    proj_path="$workspace_root/projects/atlas/$project"
  elif [ -d "$(pwd)/toolkit/code_intelligence" ]; then
    proj_path="$(pwd)"
  fi

  if [ -n "$proj_path" ] && [ -f "$proj_path/.code-intelligence/graph.db" ]; then
    local graph_age=$(( ($(/usr/bin/date +%s) - $(/usr/bin/stat -c %Y "$proj_path/.code-intelligence/graph.db" 2>/dev/null || echo 0)) / 3600 ))
    if [ "$graph_age" -lt 1 ]; then
      printf "  ${ATLAS_GREEN}✓${ATLAS_RESET} Code graph fresh (${graph_age}h old)\n"
    else
      printf "  ${ATLAS_YELLOW}⚠${ATLAS_RESET} Code graph stale (${graph_age}h old) ${ATLAS_DIM}— will rebuild on launch${ATLAS_RESET}\n"
      warnings=$((warnings + 1))
    fi
  fi

  printf "\n"
  if [ "$failures" -gt 0 ]; then
    printf "  ${ATLAS_RED}✗ ${failures} failure(s)${ATLAS_RESET}, ${ATLAS_YELLOW}${warnings} warning(s)${ATLAS_RESET}\n"
    _atlas_footer
    return 1
  elif [ "$warnings" -gt 0 ]; then
    printf "  ${ATLAS_YELLOW}⚠ ${warnings} warning(s)${ATLAS_RESET} ${ATLAS_DIM}(non-blocking)${ATLAS_RESET}\n"
  else
    printf "  ${ATLAS_GREEN}✓ All checks passed${ATLAS_RESET}\n"
  fi
  _atlas_footer
  return 0
}

# atlas feature <name>
# Create a CI-triggering feature branch with date prefix
# Naming: feature/YYYY-MM-DD-<slug>
_atlas_feature() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Usage: atlas feature <name>"
    echo "Creates: feature/$(/usr/bin/date +%Y-%m-%d)-<slug> (CI-triggering)"
    return 1
  fi

  # Slug: lowercase, replace spaces/special with dashes
  local slug=$(echo "$name" | /usr/bin/tr '[:upper:] ' '[:lower:]-' | /usr/bin/sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//')
  local branch="feature/$(/usr/bin/date +%Y-%m-%d)-${slug}"

  printf "  ${ATLAS_BOLD}New feature branch${ATLAS_RESET}\n"
  printf "    Branch: ${ATLAS_CYAN}%s${ATLAS_RESET}\n" "$branch"
  printf "    CI: ${ATLAS_GREEN}enabled${ATLAS_RESET} (matches feature/* pattern)\n"

  # Check if in a git repo
  if ! git rev-parse --git-dir &>/dev/null; then
    echo "  Error: not in a git repository"
    return 1
  fi

  git checkout -b "$branch" 2>&1 | head -3
  printf "  ${ATLAS_GREEN}✓${ATLAS_RESET} Branch created. Now: atlas \"${name}\" to launch Claude Code\n"
}

# v5.7.0+ — Semantic worktree naming (Phase 3 of sleepy-tumbling-hennessy)
#
# Usage: atlas feat|fix|hotfix|chore|refactor <description>
# Creates: <prefix>-<description> worktree + session with same name
# Enforces: regex ^(feat|fix|hotfix|chore|refactor)-[a-z0-9-]{3,50}$
#           (rejects date-only names like "0414")
_atlas_semantic_worktree() {
  local prefix="$1"
  shift
  local desc="$*"

  if [[ -z "$desc" ]]; then
    echo "Usage: atlas $prefix <description>"
    echo "  Example: atlas $prefix cc-alignment → worktree ${prefix}-cc-alignment"
    echo "  Rules: kebab-case, 3-50 chars, [a-z0-9-] only"
    return 1
  fi

  # Slugify: lowercase, kebab-case
  local slug
  slug=$(echo "$desc" | /usr/bin/tr '[:upper:] _' '[:lower:]--' | /usr/bin/sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//')

  # Validate: no date-only, proper length
  if ! echo "$slug" | grep -qE '^[a-z0-9-]{3,50}$'; then
    echo "❌ Invalid name: '$slug'"
    echo "   Must match: [a-z0-9-]{3,50}"
    return 1
  fi

  # Reject date-only patterns (like "0414", "2026-04-14", etc.)
  if echo "$slug" | grep -qE '^[0-9-]+$'; then
    echo "❌ Date-only names rejected: '$slug'"
    echo "   Use a semantic description (e.g., '$prefix bug-fix' not '$prefix $slug')"
    return 1
  fi

  local branch="${prefix}-${slug}"

  # Launch claude with worktree + session name
  printf "🌳 Launching worktree: %s (session: %s)\n" "$branch" "$branch"
  local claude_bin
  claude_bin=$(command -v claude 2>/dev/null || echo "/usr/local/bin/claude")
  if [[ ! -x "$claude_bin" ]]; then
    echo "❌ claude binary not found"
    return 1
  fi

  "$claude_bin" -w "$branch" -n "$branch"
}

# atlas promote <worktree-name>
# Convert worktree-X (experimental, no CI) → feature/YYYY-MM-DD-X (CI-ready)
_atlas_promote() {
  local wt_name="$1"
  if [ -z "$wt_name" ]; then
    echo "Usage: atlas promote <worktree-name>"
    echo "Converts worktree-<name> branch to feature/$(/usr/bin/date +%Y-%m-%d)-<name> (CI-ready)"
    return 1
  fi

  # Strip worktree- prefix if user included it
  wt_name="${wt_name#worktree-}"
  local old_branch="worktree-${wt_name}"
  local new_branch="feature/$(/usr/bin/date +%Y-%m-%d)-${wt_name}"

  if ! git show-ref --verify --quiet "refs/heads/${old_branch}"; then
    echo "  Error: branch ${old_branch} not found"
    return 1
  fi

  printf "  ${ATLAS_BOLD}Promote worktree → feature${ATLAS_RESET}\n"
  printf "    %s → ${ATLAS_CYAN}%s${ATLAS_RESET}\n" "$old_branch" "$new_branch"

  git branch -m "$old_branch" "$new_branch" 2>&1 | head -3
  printf "  ${ATLAS_GREEN}✓${ATLAS_RESET} Branch renamed. Push to trigger CI: git push -u origin %s\n" "$new_branch"
}

# atlas review [files...]
# Standalone Pass 0 (DET) code review via toolkit/code_intelligence
_atlas_review() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$repo_root" ]; then
    echo "  Error: not in a git repository"
    return 1
  fi

  if [ ! -d "$repo_root/toolkit/code_intelligence" ]; then
    echo "  Error: toolkit/code_intelligence not found in $repo_root"
    echo "  This command requires Synapse v1+ (PR #164 merged)."
    return 1
  fi

  cd "$repo_root" || return 1
  if [ $# -eq 0 ]; then
    # Default: review diff vs dev
    python3 -m toolkit.code_intelligence.review_pass0 --range "origin/dev...HEAD" --format markdown
  else
    python3 -m toolkit.code_intelligence.review_pass0 --files "$@" --format markdown
  fi
}

# atlas blast <files...>
# Blast-radius analysis via toolkit/code_intelligence
_atlas_blast() {
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$repo_root" ]; then
    echo "  Error: not in a git repository"
    return 1
  fi

  if [ ! -d "$repo_root/toolkit/code_intelligence" ]; then
    echo "  Error: toolkit/code_intelligence not found in $repo_root"
    return 1
  fi

  if [ $# -eq 0 ]; then
    echo "Usage: atlas blast <files...>"
    return 1
  fi

  cd "$repo_root" || return 1
  python3 -m toolkit.code_intelligence impact "$@"
}

