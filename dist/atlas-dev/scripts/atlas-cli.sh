#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════
# ATLAS — Unified Claude Code Launcher & Management CLI
# © 2026 AXOIQ Inc. | Proprietary Software
# ═══════════════════════════════════════════════════════════════
#
# Usage: atlas [project|subcommand] [flags] [topic] [-- cc-flags...]
#
# Source this file from ~/.zshrc:
#   [ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"

ATLAS_VERSION="4.13.0"
ATLAS_CONFIG="${HOME}/.atlas/config.json"
ATLAS_HISTORY="${HOME}/.atlas/history.json"
ATLAS_SHELL_DIR="${HOME}/.atlas/shell"

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
  ATLAS_HAS_TMUX=$([ -x /usr/bin/tmux ] && echo true || echo false)
  ATLAS_HAS_BUN=$(command -v bun &>/dev/null && echo true || echo false)

  # Hostname (for multi-machine awareness)
  ATLAS_HOSTNAME="$(hostname -s 2>/dev/null || echo unknown)"

  # Claude Code version
  ATLAS_CC_VERSION="$(claude --version 2>/dev/null | head -1 | grep -oP '[\d.]+' || echo "?")"
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
      local name=$(basename "$d")
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
  printf "  ${ATLAS_BOLD}Active sessions${ATLAS_RESET}\n\n"

  if $ATLAS_HAS_TMUX && /usr/bin/tmux list-sessions 2>/dev/null | grep -q 'cc-'; then
    /usr/bin/tmux list-sessions 2>/dev/null | grep 'cc-' | while read line; do
      printf "    ${ATLAS_CYAN}%s${ATLAS_RESET}\n" "$line"
    done
  else
    printf "    ${ATLAS_DIM}No active tmux sessions.${ATLAS_RESET}\n"
  fi

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

  # Installed plugins
  local plugin_count
  plugin_count=$(find ~/.claude/plugins/cache/atlas-marketplace/ -maxdepth 1 -type d 2>/dev/null | wc -l)
  plugin_count=$((plugin_count - 1))  # subtract the parent dir
  [ $plugin_count -lt 0 ] && plugin_count=0
  echo " Plugins: ${plugin_count}/6 ATLAS domain plugins installed"

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

# ─── Interactive Menu (atlas with no args) ────────────────────
_atlas_interactive_menu() {
  _atlas_header

  if $ATLAS_HAS_GUM; then
    _atlas_gum_menu
  elif $ATLAS_HAS_FZF; then
    _atlas_fzf_menu
  else
    _atlas_basic_menu
  fi
}

_atlas_gum_menu() {
  # Build menu items: recent projects + actions
  local -a items=()
  local -a project_names=()

  # Recent projects
  local recents=$(_atlas_recent_projects 5)
  if [ -n "$recents" ]; then
    while IFS='|' read pname ago count; do
      items+=("▶ ${pname}  (${ago}, ${count}x)")
      project_names+=("$pname")
    done <<< "$recents"
  fi

  # All projects not in recents
  local all_projects=$(_atlas_known_projects)
  if [ -n "$all_projects" ]; then
    while read pname; do
      # Skip if already in recents
      local skip=false
      for r in "${project_names[@]}"; do
        [ "$r" = "$pname" ] && { skip=true; break; }
      done
      $skip && continue
      items+=("  ${pname}")
      project_names+=("$pname")
    done <<< "$all_projects"
  fi

  # Actions separator + items
  items+=("─────────────────────────")
  project_names+=("__separator__")
  items+=("📋 list --all       Scan all projects")
  project_names+=("__list_all__")
  items+=("🔄 resume           Resume last session")
  project_names+=("__resume__")
  items+=("📊 status           Active sessions")
  project_names+=("__status__")
  items+=("⚙️  setup            Configure ATLAS")
  project_names+=("__setup__")
  items+=("🩺 doctor           Health check")
  project_names+=("__doctor__")
  items+=("❓ help             Documentation")
  project_names+=("__help__")

  # Show gum choose menu
  local choice=$(printf '%s\n' "${items[@]}" | gum choose \
    --header "Select a project or action:" \
    --cursor "→ " \
    --cursor.foreground 214 \
    --selected.foreground 214 \
    --height 20)

  [ -z "$choice" ] && return 0

  # Find index of choice
  local idx=0
  for item in "${items[@]}"; do
    if [ "$item" = "$choice" ]; then
      local action="${project_names[$((idx + 1))]}"
      case "$action" in
        __separator__) _atlas_interactive_menu ;; # Re-show menu
        __list_all__) _atlas_list --all ;;
        __resume__) _atlas_resume ;;
        __status__) _atlas_status ;;
        __setup__) _atlas_setup ;;
        __doctor__) _atlas_doctor ;;
        __help__) _atlas_help ;;
        *) atlas "$action" ;; # Launch project
      esac
      return
    fi
    idx=$((idx + 1))
  done
}

_atlas_fzf_menu() {
  printf "  ${ATLAS_BOLD}Select project:${ATLAS_RESET}\n\n"

  local choice=$(_atlas_discover_projects | while IFS=: read pname ppath; do
    echo "$pname"
  done | fzf --header="ATLAS — Select project" --height=15 --reverse --border)

  [ -n "$choice" ] && atlas "$choice"
}

_atlas_basic_menu() {
  printf "  ${ATLAS_BOLD}Recent projects:${ATLAS_RESET}\n\n"
  local idx=1
  local -a names=()

  _atlas_recent_projects 5 | while IFS='|' read pname ago count; do
    printf "    ${ATLAS_CYAN}%d)${ATLAS_RESET} %-14s ${ATLAS_DIM}(%s)${ATLAS_RESET}\n" "$idx" "$pname" "$ago"
    names+=("$pname")
    idx=$((idx + 1))
  done

  echo ""
  printf "  ${ATLAS_BOLD}Actions:${ATLAS_RESET}\n"
  printf "    l) list all    r) resume    s) status    h) help    q) quit\n\n"
  printf "  Select: "
  read -r sel

  case "$sel" in
    [0-9]*) local name="${names[$sel]}"; [ -n "$name" ] && atlas "$name" ;;
    l) _atlas_list --all ;;
    r) _atlas_resume ;;
    s) _atlas_status ;;
    h) _atlas_help ;;
    q) return 0 ;;
  esac
}

# ─── Tmux Split Launcher ─────────────────────────────────────
_atlas_split_launch() {
  local project="$1" path="$2" session_name="$3"
  shift 3
  local cmd=("$@")

  if ! $ATLAS_HAS_TMUX; then
    echo "tmux required for split mode. Install: ${_pkg:-sudo apt install} tmux"
    echo "Falling back to inline mode..."
    (builtin cd "$path" && "${cmd[@]}")
    return
  fi

  # Collision handler: session already exists → ask user
  if /usr/bin/tmux has-session -t "$session_name" 2>/dev/null; then
    if $ATLAS_HAS_GUM; then
      local action
      action=$(gum choose --header "Session '${session_name}' exists:" \
        "📎 Attach (resume existing)" \
        "🔄 Kill & Replace" \
        "✏️  Rename" 2>/dev/null || echo "")
      case "$action" in
        *Attach*)
          if [ -n "$TMUX" ]; then
            /usr/bin/tmux switch-client -t "$session_name"
          else
            /usr/bin/tmux attach-session -t "$session_name"
          fi
          return ;;
        *Kill*)
          /usr/bin/tmux kill-session -t "$session_name" 2>/dev/null ;;
        *Rename*)
          local new_label
          new_label=$(gum input --header "New session name:" --width 40 2>/dev/null || echo "")
          [ -z "$new_label" ] && return 1
          session_name="cc-${project}-${new_label}" ;;
        *)
          return 0 ;;  # User cancelled
      esac
    else
      echo "Session '${session_name}' already exists. Kill it first or use a different name."
      return 1
    fi
  fi

  # Build the claude command string with full PATH export prefix
  # Append "; exit" so the tmux shell auto-closes when claude exits
  local path_export="export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\${HOME}/.local/bin:\${HOME}/.bun/bin:\${HOME}/.cargo/bin:\${HOME}/.npm-global/bin:/usr/local/go/bin:\${HOME}/go/bin:\${PATH}"
  local cmd_str="${cmd[*]}"
  local full_cmd="${path_export} && ${cmd_str}; exit"

  if [ -n "$TMUX" ]; then
    # Already inside tmux → create detached session, then switch to it
    /usr/bin/tmux new-session -d -s "$session_name" -n "${project}" -c "$path"
    /usr/bin/tmux send-keys -t "$session_name" "$full_cmd" C-m
    /usr/bin/tmux switch-client -t "$session_name"
  else
    # Outside tmux → create and attach directly
    /usr/bin/tmux new-session -s "$session_name" -n "${project}" -c "$path" \; \
      send-keys "$full_cmd" C-m
  fi
}

# ─── Topic Registry ──────────────────────────────────────────
ATLAS_TOPICS_FILE="${HOME}/.atlas/topics.json"

_atlas_topics_init() {
  [ -f "$ATLAS_TOPICS_FILE" ] || echo '{}' > "$ATLAS_TOPICS_FILE"
}

_atlas_topic_get() {
  local topic="$1"
  _atlas_topics_init
  python3 -c "
import json, sys
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
t = topics.get('$topic')
if t:
    print(json.dumps(t))
else:
    sys.exit(1)
" 2>/dev/null
}

_atlas_topic_create() {
  local topic="$1" project="$2" branch="$3"
  _atlas_topics_init
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
topics['$topic'] = {
    'project': '$project',
    'branches': ['$branch'] if '$branch' else [],
    'sessions': [],
    'handoffs': [],
    'plans': [],
    'created': datetime.now().isoformat(),
    'lastActive': datetime.now().isoformat(),
    'status': 'active'
}
with open('$ATLAS_TOPICS_FILE', 'w') as f:
    json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_update_active() {
  local topic="$1"
  _atlas_topics_init
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    topics['$topic']['lastActive'] = datetime.now().isoformat()
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_add_session() {
  local topic="$1" session_name="$2"
  python3 -c "
import json
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    sessions = topics['$topic'].get('sessions', [])
    if '$session_name' not in sessions:
        sessions.append('$session_name')
        topics['$topic']['sessions'] = sessions
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_add_handoff() {
  local topic="$1" handoff_path="$2"
  python3 -c "
import json
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    handoffs = topics['$topic'].get('handoffs', [])
    if '$handoff_path' not in handoffs:
        handoffs.append('$handoff_path')
        topics['$topic']['handoffs'] = handoffs
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_complete() {
  local topic="$1"
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    topics['$topic']['status'] = 'completed'
    topics['$topic']['completedAt'] = datetime.now().isoformat()
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topics_list() {
  _atlas_topics_init
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if not topics:
    print('No topics registered.')
else:
    active = {k:v for k,v in topics.items() if v.get('status') == 'active'}
    completed = {k:v for k,v in topics.items() if v.get('status') == 'completed'}
    if active:
        print(f'Active topics ({len(active)}):')
        for name, t in sorted(active.items(), key=lambda x: x[1].get('lastActive',''), reverse=True):
            proj = t.get('project', '?')
            last = t.get('lastActive', '')[:16].replace('T', ' ')
            handoff_count = len(t.get('handoffs', []))
            print(f'  {name:20s}  {proj:12s}  last: {last}  handoffs: {handoff_count}')
    if completed:
        print(f'Completed topics ({len(completed)}):')
        for name, t in sorted(completed.items(), key=lambda x: x[1].get('completedAt',''), reverse=True)[:5]:
            proj = t.get('project', '?')
            print(f'  {name:20s}  {proj:12s}  (completed)')
" 2>/dev/null
}

# ─── Main Entry Point ────────────────────────────────────────
atlas() {
  # Ensure standard system paths are in PATH and clear stale command cache
  export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin:${HOME}/.bun/bin:${HOME}/.cargo/bin:${HOME}/.npm-global/bin:/usr/local/go/bin:${HOME}/go/bin:${PATH}"
  hash -r 2>/dev/null  # Reset zsh command hash table (fixes stale "not found" cache)

  # No args = interactive menu
  if [ $# -eq 0 ]; then
    _atlas_interactive_menu
    return
  fi

  # Subcommand dispatch
  case "$1" in
    list)    shift; _atlas_list "$@"; return ;;
    resume)  shift; _atlas_resume "$@"; return ;;
    status)  _atlas_status; return ;;
    setup)   shift; _atlas_setup "$@"; return ;;
    doctor)  shift; _atlas_doctor "$@"; return ;;
    hooks)   _atlas_hooks; return ;;
    topics)  _atlas_topics_list; return ;;
    dashboard|dash|d) _atlas_dashboard; return ;;
    help|-h|--help) _atlas_help; return ;;
    --version|-v) echo "ATLAS CLI v${ATLAS_VERSION} | Plugin v$(_atlas_plugin_version) | CC v${ATLAS_CC_VERSION}"; return ;;
  esac

  # Parse project + flags
  local project="" topic=""
  local worktree=$ATLAS_DEFAULT_WORKTREE
  local split=$ATLAS_DEFAULT_SPLIT
  local effort=$ATLAS_DEFAULT_EFFORT
  local chrome=$ATLAS_DEFAULT_CHROME
  local yolo=false auto_mode=false plan_mode=false bare=false
  local cont=false resume_name="" session_name="" wt_name=""
  local -a extra_args=()
  local parsing_extra=false

  for arg in "$@"; do
    if $parsing_extra; then
      extra_args+=("$arg")
      continue
    fi

    case "$arg" in
      --) parsing_extra=true ;;
      -i|--inline) worktree=false; split=false ;;
      -y|--yolo) yolo=true ;;
      -a|--auto) auto_mode=true ;;
      -p|--plan) plan_mode=true ;;
      -b|--bare) bare=true ;;
      --no-split) split=false ;;
      --no-worktree) worktree=false ;;
      -c|--continue) cont=true ;;
      -e|--effort)
        # Next arg is the effort level (handled below)
        ;;
      -r|--resume)
        # Next arg is the session name (handled below)
        ;;
      -n|--name)
        # Next arg is the session name (handled below)
        ;;
      low|medium|high|max)
        # Effort level value (follows -e)
        effort="$arg"
        ;;
      -s|--split) split=true ;;
      -w|--worktree) worktree=true ;;
      -*)
        echo "Unknown flag: $arg. Run 'atlas help'."
        return 1
        ;;
      *)
        if [ -z "$project" ]; then
          project="$arg"
        elif [ -z "$topic" ]; then
          topic="$arg"
        elif [[ "$worktree" == "true" ]] && [ -z "$wt_name" ]; then
          wt_name="$arg"
        else
          extra_args+=("$arg")
        fi
        ;;
    esac
  done

  # Resolve project path
  local path=$(_atlas_resolve_project "$project")
  if [ -z "$path" ]; then
    echo "Project '${project}' not found. Run 'atlas list --all' to see available projects."
    return 1
  fi

  # Record usage
  _atlas_record_history "$project"

  # ─── Topic Detection (after project resolved, before CC launch) ───
  if [ -n "$topic" ]; then
    local topic_data
    topic_data=$(_atlas_topic_get "$topic" 2>/dev/null)

    if [ -n "$topic_data" ]; then
      # Existing topic — check for handoff
      local latest_handoff
      latest_handoff=$(python3 -c "
import json
t = json.loads('''$topic_data''')
handoffs = t.get('handoffs', [])
print(handoffs[-1] if handoffs else '')
" 2>/dev/null)

      if [ -n "$latest_handoff" ]; then
        export ATLAS_TOPIC="$topic"
        export ATLAS_TOPIC_HANDOFF="$latest_handoff"
      fi

      _atlas_topic_update_active "$topic"
    else
      # New topic — create entry
      local branch
      branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
      _atlas_topic_create "$topic" "$project" "$branch"
      export ATLAS_TOPIC="$topic"
    fi

    _atlas_topic_add_session "$topic" "$name"
  fi

  # Auto-rebuild plugin if source is newer than cache (zero-friction dev)
  local _plugin_src="${HOME}/workspace_atlas/projects/atlas-dev-plugin"
  if [ -f "${_plugin_src}/VERSION" ]; then
    local _src_time _cache_time
    _src_time=$(stat -c %Y "${_plugin_src}/VERSION" 2>/dev/null || echo 0)
    _cache_time=$(stat -c %Y "${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/"*/VERSION 2>/dev/null | head -1 || echo 0)
    if [ "${_src_time:-0}" -gt "${_cache_time:-0}" ]; then
      echo "🔄 Plugin source newer than cache, rebuilding..."
      (cd "${_plugin_src}" && make dev-admin 2>/dev/null) && echo "   ✅ Plugin rebuilt" || echo "   ⚠️  Plugin rebuild failed (non-blocking)"
    fi
  fi

  # Fix CC settings before launch (remove overly broad deny rules)
  [ -x "${HOME}/.atlas/scripts/fix-cc-settings.sh" ] && "${HOME}/.atlas/scripts/fix-cc-settings.sh" >/dev/null 2>&1

  # Load secrets (Vaultwarden unlock if needed — interactive mode for gum prompt)
  export ATLAS_INTERACTIVE=1
  [ -f "${HOME}/.atlas/scripts/load-secrets.sh" ] && source "${HOME}/.atlas/scripts/load-secrets.sh"
  unset ATLAS_INTERACTIVE

  # Resolve claude binary path (don't depend on PATH in subshell)
  local claude_bin="${HOME}/.local/bin/claude"
  [ ! -x "$claude_bin" ] && claude_bin=$(command -v claude 2>/dev/null || echo "claude")
  local -a cmd=("$claude_bin")

  # Worktree — always with a meaningful name (never random)
  if [[ "$worktree" == "true" ]]; then
    if [ -n "$wt_name" ]; then
      # Explicit name: atlas -w synapse pitch-demo
      cmd+=(-w "$wt_name")
    elif [ -n "$topic" ]; then
      # Topic provided: atlas synapse pitch-demo → use topic as worktree name
      cmd+=(-w "$topic")
    else
      # Fallback: project-MMDD (still meaningful, never random)
      local _wt_project
      _wt_project=$(basename "$path")
      cmd+=(-w "${_wt_project}-$(date '+%m%d')")
    fi
  fi

  # Effort
  [ -n "$effort" ] && [ "$effort" != "auto" ] && cmd+=(--effort "$effort")

  # Permission modes (mutually exclusive, last wins)
  if $yolo; then
    cmd+=(--dangerously-skip-permissions)
  elif $auto_mode; then
    cmd+=(--enable-auto-mode --permission-mode auto)
  elif $plan_mode; then
    cmd+=(--permission-mode plan)
  fi

  # Bare mode
  $bare && cmd+=(--bare)

  # Chrome
  [[ "$chrome" == "true" ]] && ! $bare && cmd+=(--chrome)

  # Continue / Resume
  $cont && cmd+=(-c)
  [ -n "$resume_name" ] && cmd+=(-r "$resume_name")

  # Session name — interactive prompt for split mode, auto for inline
  local name="${session_name:-$(_cc_session_name "$path" "$topic")}"
  local tmux_session_name="cc-${project}${topic:+-$topic}"

  # Multi-session: prompt for name in split mode (skip if -n was passed)
  if [[ "$split" == "true" ]] && ! $bare && [ -z "$session_name" ] && $ATLAS_HAS_GUM && $ATLAS_HAS_TMUX; then
    local base_name="cc-${project}"
    local default_suffix=""
    local n=1
    # Auto-incremental: find next available number
    while /usr/bin/tmux has-session -t "${base_name}${default_suffix:+-$default_suffix}" 2>/dev/null; do
      default_suffix="$n"
      n=$((n + 1))
    done

    local user_label
    user_label=$(gum input --header "📋 Session name:" \
      --placeholder "${default_suffix:-"Enter=auto, or type a name"}" \
      --width 40 2>/dev/null || echo "")

    if [ -n "$user_label" ]; then
      tmux_session_name="${base_name}-${user_label}"
      name="${project}-${user_label}"
    elif [ -n "$default_suffix" ]; then
      tmux_session_name="${base_name}-${default_suffix}"
      name="${project}-${default_suffix}"
    fi
    # else: first session, use default cc-project
  fi

  cmd+=(-n "$name")

  # Extra passthrough args
  [ ${#extra_args[@]} -gt 0 ] && cmd+=("${extra_args[@]}")

  # Launch with full PATH guaranteed
  local _full_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin:${HOME}/.bun/bin:${HOME}/.cargo/bin:${HOME}/.npm-global/bin:/usr/local/go/bin:${HOME}/go/bin"

  if [[ "$split" == "true" ]] && ! $bare; then
    _atlas_split_launch "$project" "$path" "$tmux_session_name" "${cmd[@]}"
  else
    # builtin cd bypasses zoxide wrapper; direnv export loads .envrc silently
    builtin cd "$path" \
      && eval "$(DIRENV_LOG_FORMAT= direnv export zsh 2>/dev/null)" \
      && export PATH="$_full_path" \
      && "${cmd[@]}"
  fi
}

# ─── Backward Compatibility (deprecated, remove after 2026-04-27) ──
atlas-synapse()       { echo "⚠️  Deprecated: use 'atlas synapse'" >&2; atlas synapse "$@"; }
atlas-synapse-w()     { echo "⚠️  Deprecated: use 'atlas synapse'" >&2; atlas synapse "$@"; }
atlas-synapse-split() { echo "⚠️  Deprecated: use 'atlas synapse'" >&2; atlas synapse "$@"; }
atlas-w()             { echo "⚠️  Deprecated: use 'atlas <project>'" >&2; atlas "$@"; }
atlas-split()         { echo "⚠️  Deprecated: use 'atlas <project>'" >&2; atlas "$@"; }

# ─── Zsh Completion ───────────────────────────────────────────
if [ -n "$ZSH_VERSION" ]; then
  _atlas_completions() {
    local -a subcommands projects flags

    subcommands=(
      'list:Show projects (--all for workspace scan)'
      'resume:Resume most recent session'
      'status:Active tmux sessions'
      'dashboard:Session & topic overview'
      'dash:Session & topic overview (alias)'
      'topics:List topic registry (active & completed)'
      'setup:Run onboarding wizard'
      'doctor:Health check'
      'hooks:Hook health dashboard'
      'help:Show documentation'
    )

    projects=($(_atlas_known_projects))

    flags=(
      '-i:Inline mode (no worktree, no split)'
      '--inline:Inline mode (no worktree, no split)'
      '-y:Yolo mode (bypass permissions)'
      '--yolo:Yolo mode (bypass permissions)'
      '-a:Auto mode (Sonnet classifier)'
      '--auto:Auto mode (Sonnet classifier)'
      '-p:Plan mode (read-only)'
      '--plan:Plan mode (read-only)'
      '-b:Bare mode (fast, no plugins)'
      '--bare:Bare mode (fast, no plugins)'
      '-e:Set effort level (low/medium/high/max)'
      '--effort:Set effort level'
      '-c:Continue last session'
      '--continue:Continue last session'
      '-r:Resume session by name'
      '--resume:Resume session by name'
      '-n:Override session name'
      '--name:Override session name'
      '--no-split:Disable tmux split'
      '--no-worktree:Disable worktree'
      '-h:Show help'
    )

    if (( CURRENT == 2 )); then
      _describe 'subcommand' subcommands
      compadd -a projects
    else
      _describe 'flag' flags
    fi
  }
  compdef _atlas_completions atlas 2>/dev/null
fi

# ─── First-run Detection ─────────────────────────────────────
if [ ! -f "$ATLAS_CONFIG" ] || ! python3 -c "import json; json.load(open('$ATLAS_CONFIG')).get('launcher')" 2>/dev/null; then
  if [ -t 0 ] && [ -t 1 ]; then
    # Only show in interactive shells, not during script execution
    printf "\n  ${ATLAS_GOLD}🏛️ ATLAS${ATLAS_RESET} detected but not configured.\n"
    printf "  Run ${ATLAS_BOLD}atlas setup${ATLAS_RESET} to configure your environment.\n\n"
  fi
fi
