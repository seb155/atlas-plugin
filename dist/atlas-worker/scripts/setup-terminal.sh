#!/usr/bin/env bash
# ATLAS Terminal Setup — Shell completions, aliases, DX tools
# Usage: ./setup-terminal.sh [--check|--install|--completions-only]
# Detects OS/shell/terminal and configures optimal DX experience.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source platform detection
source "${SCRIPT_DIR}/detect-platform.sh"
PLATFORM=$(detect_platform)
OS=$(echo "$PLATFORM" | python3 -c "import sys,json; print(json.load(sys.stdin)['os'])")
SHELL_NAME=$(echo "$PLATFORM" | python3 -c "import sys,json; print(json.load(sys.stdin)['shell'])")
TERMINAL=$(echo "$PLATFORM" | python3 -c "import sys,json; print(json.load(sys.stdin)['terminal'])")

# RC file detection
case "$SHELL_NAME" in
  zsh)  RC_FILE="${HOME}/.zshrc" ;;
  bash) RC_FILE="${HOME}/.bashrc" ;;
  fish) RC_FILE="${HOME}/.config/fish/config.fish" ;;
  *)    RC_FILE="${HOME}/.${SHELL_NAME}rc" ;;
esac

MODE="${1:---check}"

# ═══════════════════════════════════════════════════════════════
# CHECK MODE — Report what's configured and what's missing
# ═══════════════════════════════════════════════════════════════

check_terminal() {
  echo "🏛️ ATLAS │ 🖥️ TERMINAL CHECK │ ${OS} │ ${SHELL_NAME} │ ${TERMINAL}"
  echo ""

  local score=0 max=0

  # 1. Shell completions
  max=$((max + 1))
  if [ "$SHELL_NAME" = "zsh" ] && [ -f "${HOME}/.oh-my-zsh/custom/plugins/atlas/_atlas" 2>/dev/null ]; then
    echo "  ✅ ATLAS zsh completion installed"
    score=$((score + 1))
  else
    echo "  ❌ ATLAS zsh completion not installed"
  fi

  # 2. Claude Code completion
  max=$((max + 1))
  if claude completion --shell zsh >/dev/null 2>&1; then
    if grep -q "claude completion" "$RC_FILE" 2>/dev/null || [ -f "${HOME}/.oh-my-zsh/custom/plugins/claude/_claude" 2>/dev/null ]; then
      echo "  ✅ Claude Code zsh completion wired"
      score=$((score + 1))
    else
      echo "  ⚠️ Claude Code completion available but not wired"
    fi
  else
    echo "  ℹ️ Claude Code completion not available (check claude --help)"
  fi

  # 3. ATLAS aliases
  max=$((max + 1))
  if grep -q "atlas()" "$RC_FILE" 2>/dev/null; then
    echo "  ✅ ATLAS session aliases configured"
    score=$((score + 1))
  else
    echo "  ❌ ATLAS session aliases missing"
  fi

  # 4. Starship prompt
  max=$((max + 1))
  if command -v starship &>/dev/null; then
    echo "  ✅ Starship prompt installed ($(starship --version 2>/dev/null | head -1))"
    score=$((score + 1))
  else
    echo "  ❌ Starship not installed"
  fi

  # 5. FZF integration
  max=$((max + 1))
  if command -v fzf &>/dev/null; then
    echo "  ✅ FZF fuzzy finder installed"
    score=$((score + 1))
  else
    echo "  ❌ FZF not installed (Ctrl+R history, Ctrl+T file picker)"
  fi

  # 6. Zsh autosuggestions
  max=$((max + 1))
  if [ -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" 2>/dev/null ]; then
    echo "  ✅ Zsh autosuggestions enabled"
    score=$((score + 1))
  elif [ "$SHELL_NAME" = "zsh" ]; then
    echo "  ❌ Zsh autosuggestions not installed"
  else
    echo "  ⏭️ Zsh autosuggestions (zsh only)"
    max=$((max - 1))
  fi

  # 7. Zsh syntax highlighting
  max=$((max + 1))
  if [ -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" 2>/dev/null ]; then
    echo "  ✅ Zsh syntax highlighting enabled"
    score=$((score + 1))
  elif [ "$SHELL_NAME" = "zsh" ]; then
    echo "  ❌ Zsh syntax highlighting not installed"
  else
    echo "  ⏭️ Zsh syntax highlighting (zsh only)"
    max=$((max - 1))
  fi

  # 8. Zoxide (smart cd)
  max=$((max + 1))
  if command -v zoxide &>/dev/null; then
    echo "  ✅ Zoxide smart cd installed"
    score=$((score + 1))
  else
    echo "  ❌ Zoxide not installed (frecency-based cd)"
  fi

  # 9. Delta (git diff)
  max=$((max + 1))
  if command -v delta &>/dev/null; then
    echo "  ✅ Delta git diff viewer installed"
    score=$((score + 1))
  else
    echo "  ⚠️ Delta not installed (pretty git diffs)"
  fi

  # 10. Bat (syntax highlighted cat)
  max=$((max + 1))
  if command -v bat &>/dev/null || command -v batcat &>/dev/null; then
    echo "  ✅ Bat syntax viewer installed"
    score=$((score + 1))
  else
    echo "  ⚠️ Bat not installed (syntax highlighted file viewing)"
  fi

  # 11. Direnv
  max=$((max + 1))
  if command -v direnv &>/dev/null; then
    echo "  ✅ Direnv auto-env loading installed"
    score=$((score + 1))
  else
    echo "  ⚠️ Direnv not installed (auto-load .envrc per project)"
  fi

  # 12. ATLAS_ROOT env var
  max=$((max + 1))
  if [ -n "${ATLAS_ROOT:-}" ]; then
    echo "  ✅ ATLAS_ROOT set: $ATLAS_ROOT"
    score=$((score + 1))
  else
    echo "  ❌ ATLAS_ROOT not set"
  fi

  echo ""
  echo "   Score: ${score}/${max}"
  echo ""

  if [ $score -lt $max ]; then
    echo "   Run: ./setup-terminal.sh --install  (to fix missing items)"
  else
    echo "   All checks passed!"
  fi
}

# ═══════════════════════════════════════════════════════════════
# COMPLETION GENERATION — ATLAS command completion for zsh/bash
# ═══════════════════════════════════════════════════════════════

generate_zsh_completion() {
  # Generate _atlas completion function for zsh
  local commands_dir="${PLUGIN_ROOT}/commands"
  local commands=""
  if [ -d "$commands_dir" ]; then
    commands=$(ls "$commands_dir"/*.md 2>/dev/null | xargs -I{} basename {} .md | sort)
  fi

  cat <<'COMP_HEADER'
#compdef atlas atlas-synapse atlas-w atlas-synapse-w

# ATLAS Claude Code session launcher completions
# Generated by: atlas-plugin/scripts/setup-terminal.sh

_atlas_topics() {
  # Common session topics
  local topics=(
    "hub:Enterprise Hub development"
    "frontend:Frontend React/TypeScript work"
    "backend:Backend Python/FastAPI work"
    "api:API endpoint development"
    "tests:Test writing and debugging"
    "docs:Documentation and plans"
    "infra:Infrastructure and DevOps"
    "review:Code review session"
    "debug:Debugging session"
    "feature:New feature development"
  )
  _describe 'topic' topics
}

_atlas_commands() {
  local commands=(
COMP_HEADER

  # Generate command list from plugin commands directory
  while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    local desc=""
    local cmd_file="${commands_dir}/${cmd}.md"
    if [ -f "$cmd_file" ]; then
      desc=$(head -1 "$cmd_file" | sed 's/^Invoke the `\([^`]*\)`.*/\1 skill/' | head -c 50)
    fi
    echo "    \"${cmd}:${desc:-$cmd command}\""
  done <<< "$commands"

  cat <<'COMP_FOOTER'
  )
  _describe 'command' commands
}

# atlas [topic] — Launch CC session with optional topic name
_atlas() {
  _arguments \
    '1:topic:_atlas_topics' \
    '*:flags:->flags'
}

# atlas-synapse [topic] — Launch Synapse CC session
_atlas-synapse() {
  _arguments \
    '1:topic:_atlas_topics' \
    '*:flags:->flags'
}

# atlas-w [topic] — Launch CC session with worktree
_atlas-w() {
  _arguments \
    '1:topic:_atlas_topics' \
    '*:flags:->flags'
}

# atlas-synapse-w [topic] — Launch Synapse CC session with worktree
_atlas-synapse-w() {
  _arguments \
    '1:topic:_atlas_topics' \
    '*:flags:->flags'
}

# Register completions
compdef _atlas atlas
compdef _atlas-synapse atlas-synapse
compdef _atlas-w atlas-w
compdef _atlas-synapse-w atlas-synapse-w
COMP_FOOTER
}

generate_bash_completion() {
  cat <<'BASH_COMP'
# ATLAS bash completion
# Generated by: atlas-plugin/scripts/setup-terminal.sh

_atlas_complete() {
  local topics="hub frontend backend api tests docs infra review debug feature"
  COMPREPLY=($(compgen -W "$topics" -- "${COMP_WORDS[COMP_CWORD]}"))
}

complete -F _atlas_complete atlas
complete -F _atlas_complete atlas-synapse
complete -F _atlas_complete atlas-w
complete -F _atlas_complete atlas-synapse-w
BASH_COMP
}

# ═══════════════════════════════════════════════════════════════
# INSTALL MODE — Configure everything with user confirmation
# ═══════════════════════════════════════════════════════════════

install_completions() {
  echo "🏛️ ATLAS │ 🖥️ TERMINAL SETUP │ Installing completions..."
  echo ""

  case "$SHELL_NAME" in
    zsh)
      local comp_dir="${HOME}/.oh-my-zsh/custom/plugins/atlas"
      mkdir -p "$comp_dir"
      generate_zsh_completion > "${comp_dir}/_atlas"
      echo "  ✅ Wrote ${comp_dir}/_atlas"

      # Check if 'atlas' is in plugins list
      if ! grep -q "plugins=.*atlas" "$RC_FILE" 2>/dev/null; then
        echo "  ⚠️ Add 'atlas' to your plugins=(...) in ${RC_FILE}"
        echo "     Or run: sed -i 's/plugins=(/plugins=(atlas /' ${RC_FILE}"
      fi

      # Claude Code completion (if available)
      if claude completion --shell zsh >/dev/null 2>&1; then
        local claude_comp_dir="${HOME}/.oh-my-zsh/custom/plugins/claude"
        mkdir -p "$claude_comp_dir"
        claude completion --shell zsh > "${claude_comp_dir}/_claude" 2>/dev/null || true
        echo "  ✅ Wrote ${claude_comp_dir}/_claude"
        echo "  ⚠️ Add 'claude' to your plugins=(...) in ${RC_FILE}"
      fi
      ;;
    bash)
      local comp_file="${HOME}/.local/share/bash-completion/completions/atlas"
      mkdir -p "$(dirname "$comp_file")"
      generate_bash_completion > "$comp_file"
      echo "  ✅ Wrote ${comp_file}"

      if claude completion --shell bash >/dev/null 2>&1; then
        claude completion --shell bash > "${HOME}/.local/share/bash-completion/completions/claude" 2>/dev/null || true
        echo "  ✅ Wrote claude bash completion"
      fi
      ;;
    *)
      echo "  ⚠️ Shell '${SHELL_NAME}' — manual completion setup needed"
      ;;
  esac
  echo ""
}

install_missing_tools() {
  echo "🏛️ ATLAS │ 🔧 TOOLS │ Checking recommended tools..."
  echo ""

  local install_cmd=""
  case "$OS" in
    linux|wsl)
      if command -v apt &>/dev/null; then
        install_cmd="sudo apt install -y"
      elif command -v dnf &>/dev/null; then
        install_cmd="sudo dnf install -y"
      elif command -v pacman &>/dev/null; then
        install_cmd="sudo pacman -S --noconfirm"
      fi
      ;;
    macos)
      if command -v brew &>/dev/null; then
        install_cmd="brew install"
      fi
      ;;
  esac

  if [ -z "$install_cmd" ]; then
    echo "  ⚠️ No package manager detected — install tools manually"
    return
  fi

  # Check and suggest missing tools
  local missing=()
  command -v fzf &>/dev/null || missing+=("fzf")
  command -v bat &>/dev/null || command -v batcat &>/dev/null || missing+=("bat")
  command -v zoxide &>/dev/null || missing+=("zoxide")
  command -v delta &>/dev/null || missing+=("git-delta")
  command -v fd &>/dev/null || missing+=("fd-find")
  command -v jq &>/dev/null || missing+=("jq")
  command -v direnv &>/dev/null || missing+=("direnv")

  if [ ${#missing[@]} -eq 0 ]; then
    echo "  ✅ All recommended tools installed"
  else
    echo "  Missing: ${missing[*]}"
    echo "  Install: ${install_cmd} ${missing[*]}"
  fi
  echo ""
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

case "$MODE" in
  --check)
    check_terminal
    ;;
  --install)
    check_terminal
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    install_completions
    install_missing_tools
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Done. Run 'source ${RC_FILE}' or restart terminal to apply."
    ;;
  --completions-only)
    install_completions
    ;;
  *)
    echo "Usage: $0 [--check|--install|--completions-only]"
    ;;
esac
