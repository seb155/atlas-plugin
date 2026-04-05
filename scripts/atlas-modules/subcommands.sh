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
      [ -f "$ppath/.claude/CLAUDE.md" ] && desc=$(head -1 "$ppath/.claude/CLAUDE.md" 2>/dev/null | sed 's/^#\s*//')
      [ -z "$desc" ] && [ -f "$ppath/CLAUDE.md" ] && desc=$(head -1 "$ppath/CLAUDE.md" 2>/dev/null | sed 's/^#\s*//')
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
  local project="$1"
  if [ -n "$project" ]; then
    local path=$(_atlas_resolve_project "$project")
    [ -z "$path" ] && { echo "Project '$project' not found."; return 1; }
    builtin cd "$path" && claude -c --chrome
  else
    claude -c --chrome
  fi
}

# atlas status
_atlas_status() {
  _atlas_header
  printf "  ${ATLAS_BOLD}System Status${ATLAS_RESET}\n\n"

  # Git branch
  local branch=$(git branch --show-current 2>/dev/null || echo "N/A")
  local repo=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "N/A")
  printf "  📂 %-14s ${ATLAS_CYAN}%s${ATLAS_RESET} (branch: ${ATLAS_CYAN}%s${ATLAS_RESET})\n" "Repo" "$repo" "$branch"

  # Worktree count
  local WORKSPACE="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local wt_count=$(find "$WORKSPACE" -maxdepth 5 -path "*/.claude/worktrees/*/.git" -type f 2>/dev/null | wc -l)
  local wt_manual=$(find "$WORKSPACE" -maxdepth 4 -path "*/.worktrees/*/.git" -type f 2>/dev/null | wc -l)
  printf "  🌿 %-14s %d CC + %d manual\n" "Worktrees" "$wt_count" "$wt_manual"

  # Tmux sessions
  local tmux_count=0
  if $ATLAS_HAS_TMUX; then
    tmux_count=$(/usr/bin/tmux list-sessions 2>/dev/null | grep -c 'cc-' || echo 0)
  fi
  printf "  🖥️  %-14s %d active\n" "Sessions" "$tmux_count"

  # Memory files
  local mem_dir=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | head -1)
  if [ -n "$mem_dir" ] && [ -d "$mem_dir" ]; then
    local mem_count=$(ls "$mem_dir"/*.md 2>/dev/null | wc -l)
    local mem_lines=$(wc -l < "$mem_dir/MEMORY.md" 2>/dev/null || echo 0)
    local mem_color="${ATLAS_GREEN}"
    [ "$mem_lines" -gt 150 ] && mem_color="${ATLAS_YELLOW}"
    [ "$mem_lines" -gt 200 ] && mem_color="${ATLAS_RED}"
    printf "  🧠 %-14s %d files, ${mem_color}%d${ATLAS_RESET} lines index\n" "Memory" "$mem_count" "$mem_lines"
  fi

  # CI status (if Forgejo token available)
  if [ -n "${FORGEJO_TOKEN:-}" ]; then
    local forgejo_url="${FORGEJO_BASE_URL:-http://192.168.10.75:3000}"
    local ci_status=$(curl -sf --max-time 3 "${forgejo_url}/api/v1/repos/axoiq/synapse/statuses/$(git rev-parse HEAD 2>/dev/null)" \
      -H "Authorization: token ${FORGEJO_TOKEN}" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list) and data:
        states = set(s.get('status','?') for s in data)
        if 'failure' in states: print('❌ FAIL')
        elif 'pending' in states: print('⏳ PENDING')
        elif 'success' in states: print('✅ PASS')
        else: print('⚪ N/A')
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
    "${HOME}/workspace_atlas/projects/atlas-dev-plugin/scripts/plan-lifecycle.sh"
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

# ── Session Tools (SP-EVOLUTION P6) ───────────────────────────

_find_session_tools() {
  local search_paths=(
    "${ATLAS_SHELL_DIR}/../scripts/session-tools.sh"
    "${ATLAS_SHELL_DIR}/../../scripts/session-tools.sh"
    "${HOME}/workspace_atlas/projects/atlas-dev-plugin/scripts/session-tools.sh"
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
  [ -f "$script" ] || script="$(dirname "$(dirname "$ATLAS_SHELL_DIR")")/scripts/task-complexity.sh"
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

# atlas ci — Show CI pipeline status from Forgejo Actions
_atlas_ci() {
  _atlas_header
  printf "  ${ATLAS_BOLD}CI Pipeline Status${ATLAS_RESET}\n\n"

  local forgejo_url="${FORGEJO_BASE_URL:-http://192.168.10.75:3000}"
  local token="${FORGEJO_TOKEN:-}"

  if [ -z "$token" ]; then
    # Try loading from ~/.env
    [ -f "$HOME/.env" ] && source "$HOME/.env" 2>/dev/null
    token="${FORGEJO_TOKEN:-}"
  fi

  if [ -z "$token" ]; then
    printf "  ${ATLAS_DIM}FORGEJO_TOKEN not set. Add to ~/.env${ATLAS_RESET}\n"
    _atlas_footer
    return 1
  fi

  # Detect repo from git remote
  local repo=$(git remote get-url origin 2>/dev/null | sed 's|.*[:/]\([^/]*/[^/]*\)\.git|\1|' || echo "axoiq/synapse")
  local sha=$(git rev-parse HEAD 2>/dev/null | head -c 12 || echo "?")
  local branch=$(git branch --show-current 2>/dev/null || echo "?")

  printf "  📂 ${ATLAS_CYAN}%s${ATLAS_RESET} @ ${ATLAS_DIM}%s${ATLAS_RESET} (%s)\n\n" "$repo" "$sha" "$branch"

  # Fetch commit statuses
  curl -sf --max-time 5 "${forgejo_url}/api/v1/repos/${repo}/statuses/${sha}" \
    -H "Authorization: token ${token}" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if not isinstance(data, list) or not data:
        print('  No CI status for this commit.')
        sys.exit(0)
    seen = set()
    for s in data:
        ctx = s.get('context', '?')
        if ctx in seen:
            continue
        seen.add(ctx)
        status = s.get('status', '?')
        desc = s.get('description', '')[:40]
        icon = '✅' if status == 'success' else '❌' if status in ('failure','error') else '⏳' if status == 'pending' else '⚪'
        print(f'  {icon} {ctx}')
        if desc:
            print(f'     {desc}')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null || printf "  ${ATLAS_DIM}Could not reach Forgejo API${ATLAS_RESET}\n"

  printf "\n"
  _atlas_footer
}

# atlas worktrees (aliases: wt)
_atlas_worktrees() {
  _atlas_header
  printf "  ${ATLAS_BOLD}Git Worktrees${ATLAS_RESET} ${ATLAS_DIM}(scanning workspace)${ATLAS_RESET}\n\n"

  local WORKSPACE="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  local NOW_EPOCH=$(date +%s)
  local found=0

  printf "  ${ATLAS_DIM}%-20s %-24s %-8s %-8s %-6s${ATLAS_RESET}\n" "WORKTREE" "BRANCH" "DIRTY" "AHEAD" "AGE"
  printf "  ${ATLAS_DIM}%-20s %-24s %-8s %-8s %-6s${ATLAS_RESET}\n" "────────────────────" "────────────────────────" "────────" "────────" "──────"

  for repo_dir in $(find "$WORKSPACE" -maxdepth 4 -name ".claude" -type d 2>/dev/null); do
    local wt_dir="$repo_dir/worktrees"
    [ -d "$wt_dir" ] || continue
    local repo_root="$(dirname "$repo_dir")"
    [ -d "$repo_root/.git" ] || continue
    local repo_name=$(basename "$repo_root")

    for wt in "$wt_dir"/*(N/); do
      [ -d "$wt" ] || continue
      local name=$(basename "$wt")
      found=$((found + 1))

      # Get branch
      local branch=$(cd "$wt" && git branch --show-current 2>/dev/null || echo "?")

      # Check dirty
      local dirty_count=$(cd "$wt" && git status --porcelain 2>/dev/null | grep -v node_modules | wc -l)
      local dirty_str="${ATLAS_GREEN}clean${ATLAS_RESET}"
      [ "$dirty_count" -gt 0 ] && dirty_str="${ATLAS_YELLOW}${dirty_count} files${ATLAS_RESET}"

      # Check ahead
      local ahead=$(cd "$wt" && git log dev..HEAD --oneline 2>/dev/null | wc -l)
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
        local name=$(basename "$wt")
        found=$((found + 1))
        local branch=$(cd "$wt" && git branch --show-current 2>/dev/null || echo "?")
        local dirty_count=$(cd "$wt" && git status --porcelain 2>/dev/null | grep -v node_modules | wc -l)
        local dirty_str="${ATLAS_GREEN}clean${ATLAS_RESET}"
        [ "$dirty_count" -gt 0 ] && dirty_str="${ATLAS_YELLOW}${dirty_count} files${ATLAS_RESET}"
        local ahead=$(cd "$wt" && git log dev..HEAD --oneline 2>/dev/null | wc -l)
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

# atlas dashboard (aliases: dash, d)
_atlas_dashboard() {
  local TOPICS_FILE="${HOME}/.atlas/topics.json"

  echo ""
  echo " ATLAS Sessions                                        $(date '+%Y-%m-%d %H:%M %Z')"
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
      project=$(echo "$sess" | sed 's/^cc-//' | cut -d- -f1)
      topic=$(echo "$sess" | sed 's/^cc-[^-]*-*//')
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
  local plugin_src="${HOME}/workspace_atlas/projects/atlas-dev-plugin"
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
  memory_dir=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | head -1)
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
  plugin_count=$(find ~/.claude/plugins/cache/atlas-admin-marketplace/ -maxdepth 1 -type d 2>/dev/null | wc -l)
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
  for tier_dir in "$cache"/atlas-*/; do
    [ -d "$tier_dir" ] || continue
    for ver_dir in "$tier_dir"*/; do
      [ -d "$ver_dir" ] || continue
      local hj="$ver_dir/hooks/hooks.json"
      [ -f "$hj" ] || continue
      local tier=$(basename "$tier_dir")
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
      local lines=$(wc -l < "$path" 2>/dev/null)
      local size=$(du -sh "$path" 2>/dev/null | cut -f1)
      printf "  ✅ %-25s %s lines (%s)\n" "$log" "$lines" "$size"
    else
      printf "  ⬚  %-25s (not yet created)\n" "$log"
    fi
  done

  # 4. Stale local hooks
  echo ""
  local stale=0
  for script in "$HOME/.claude/hooks/"*.sh; do
    [ -f "$script" ] || continue
    local name=$(basename "$script" .sh)
    for tier_dir in "$cache"/atlas-*/; do
      for ver_dir in "$tier_dir"*/; do
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
  _check "gum (TUI)" "command -v gum" "$(gum --version 2>/dev/null | head -1)" "Install: ${_pkg} gum (or go install github.com/charmbracelet/gum@latest)"
  _check "fzf (fuzzy)" "command -v fzf" "$(fzf --version 2>/dev/null)" "Install: ${_pkg} fzf"
  _check "tmux" "command -v tmux" "$(tmux -V 2>/dev/null)" "Install: ${_pkg} tmux"
  _check "Docker" "command -v docker" "$(docker --version 2>/dev/null | head -1)" "Optional"
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
    atlas_line=$(grep -n 'atlas/shell/atlas.sh' "${HOME}/.zshrc" 2>/dev/null | head -1 | cut -d: -f1)
    direnv_line=$(grep -n 'direnv hook' "${HOME}/.zshrc" 2>/dev/null | head -1 | cut -d: -f1)
    zoxide_line=$(grep -n 'zoxide init' "${HOME}/.zshrc" 2>/dev/null | head -1 | cut -d: -f1)
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
    "$(date -r "${HOME}/.atlas/shell/atlas.sh" '+%Y-%m-%d' 2>/dev/null || echo 'present')" \
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
            cp "${HOME}/.zshrc" "${HOME}/.zshrc.atlas-backup.$(date +%s)"
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

