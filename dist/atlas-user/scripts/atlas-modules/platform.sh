#!/usr/bin/env zsh
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

# ─── Coder Workspace Detection ───────────────────────────────
ATLAS_IN_CODER=false
if [ -n "${CODER_AGENT_TOKEN:-}" ] || [ -n "${CODER:-}" ]; then
  ATLAS_IN_CODER=true
  ATLAS_DEFAULT_SPLIT="false"      # No tmux split in Coder (use VS Code terminals)
  ATLAS_WORKSPACE_ROOT="${HOME}"   # Workspace root is $HOME in Coder
fi
export ATLAS_IN_CODER

# ─── Profile Loading ─────────────────────────────────────────
ATLAS_PROFILE="unknown"
if [ -f "$HOME/.atlas/profile.json" ]; then
  ATLAS_PROFILE=$(python3 -c "import json; print(json.load(open('$HOME/.atlas/profile.json'))['profile'])" 2>/dev/null || echo "unknown")
fi
export ATLAS_PROFILE

