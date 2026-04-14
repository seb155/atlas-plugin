#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# ATLAS Developer Environment Bootstrap
# Sets up the ATLAS plugin ecosystem on a fresh machine (WSL2 or Linux)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/seb155/atlas-plugin/main/scripts/atlas-bootstrap.sh | bash
#   ./atlas-bootstrap.sh [--non-interactive] [--skip-wsl-conf] [--skip-cship] [--skip-plugin]
#
# Requirements: bash 4+, curl, git
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

ATLAS_BOOTSTRAP_VERSION="1.0.0"
ATLAS_PLUGIN_REPO="seb155/atlas-plugin"
ATLAS_PLUGIN_GIT="https://github.com/${ATLAS_PLUGIN_REPO}.git"
LOG_FILE="$HOME/.atlas/bootstrap.log"

# ── Flags ────────────────────────────────────────────────────────────
NON_INTERACTIVE=false
SKIP_WSL_CONF=false
SKIP_CSHIP=false
SKIP_PLUGIN=false

for arg in "$@"; do
  case "$arg" in
    --non-interactive) NON_INTERACTIVE=true ;;
    --skip-wsl-conf)   SKIP_WSL_CONF=true ;;
    --skip-cship)      SKIP_CSHIP=true ;;
    --skip-plugin)     SKIP_PLUGIN=true ;;
    --help|-h)
      echo "Usage: atlas-bootstrap.sh [--non-interactive] [--skip-wsl-conf] [--skip-cship] [--skip-plugin]"
      exit 0 ;;
  esac
done

# ── Helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${BLUE}[ATLAS]${NC} $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${GREEN}  ✅${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}  ⚠️${NC}  $*" | tee -a "$LOG_FILE"; }
fail() { echo -e "${RED}  ❌${NC} $*" | tee -a "$LOG_FILE"; }
skip() { echo -e "${YELLOW}  ⏭️${NC}  $*" | tee -a "$LOG_FILE"; }

prompt_yn() {
  # Usage: prompt_yn "Question?" [default_y|default_n]
  if $NON_INTERACTIVE; then
    [[ "${2:-default_y}" == "default_y" ]] && return 0 || return 1
  fi
  local prompt="$1"
  [[ "${2:-default_y}" == "default_y" ]] && prompt="$prompt [Y/n]" || prompt="$prompt [y/N]"
  read -rp "$(echo -e "${BLUE}[ATLAS]${NC} $prompt ") " answer
  case "${answer,,}" in
    y|yes|"") [[ "${2:-default_y}" == "default_y" ]] && return 0 || return 1 ;;
    n|no)     return 1 ;;
    *)        [[ "${2:-default_y}" == "default_y" ]] && return 0 || return 1 ;;
  esac
}

# ── Init ─────────────────────────────────────────────────────────────
mkdir -p "$HOME/.atlas"
echo "=== ATLAS Bootstrap v${ATLAS_BOOTSTRAP_VERSION} — $(date -Iseconds) ===" >> "$LOG_FILE"

IS_WSL2=false
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL2=true
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  🏛️  ATLAS Developer Environment Bootstrap v${ATLAS_BOOTSTRAP_VERSION}        ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}                                                           ${BLUE}║${NC}"
if $IS_WSL2; then
echo -e "${BLUE}║${NC}  Platform: WSL2 ($(lsb_release -ds 2>/dev/null || echo 'Linux'))   ${BLUE}║${NC}"
else
echo -e "${BLUE}║${NC}  Platform: Linux ($(lsb_release -ds 2>/dev/null || echo 'Native'))  ${BLUE}║${NC}"
fi
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═════════════════════════════════════════════════════════════════════
# PHASE 1: Prerequisites — mise + runtimes
# ═════════════════════════════════════════════════════════════════════
log "Phase 1: Prerequisites (mise + runtimes)"

# 1a. Install mise if missing
if command -v mise &>/dev/null; then
  MISE_VERSION=$(mise --version 2>/dev/null | head -1)
  ok "mise already installed ($MISE_VERSION)"
  # Update if older than 30 days
  if prompt_yn "Update mise to latest?" "default_y"; then
    mise self-update 2>>"$LOG_FILE" && ok "mise updated" || warn "mise update failed (non-critical)"
  fi
elif [[ -f "$HOME/.local/bin/mise" ]]; then
  ok "mise found at ~/.local/bin/mise (not in PATH yet)"
  export PATH="$HOME/.local/bin:$PATH"
else
  log "Installing mise..."
  curl -fsSL https://mise.run | sh 2>>"$LOG_FILE"
  export PATH="$HOME/.local/bin:$PATH"
  ok "mise installed ($(mise --version 2>/dev/null | head -1))"
fi

# 1b. Configure mise
MISE_CONFIG="$HOME/.config/mise/config.toml"
if [[ -f "$MISE_CONFIG" ]]; then
  ok "mise config exists at $MISE_CONFIG"
else
  log "Creating mise config..."
  mkdir -p "$HOME/.config/mise"
  cat > "$MISE_CONFIG" << 'MISE_EOF'
[tools]
node = "24"
bun = "latest"
yq = "latest"

[settings]
experimental = true
MISE_EOF
  ok "mise config created"
fi

# 1c. Install runtimes
log "Installing runtimes via mise..."
mise install 2>>"$LOG_FILE" && ok "Runtimes installed" || warn "Some runtimes failed to install"

# Verify
for tool in bun node yq; do
  if mise which "$tool" &>/dev/null; then
    ok "$tool $(mise exec -- $tool --version 2>/dev/null | head -1)"
  else
    fail "$tool not installed via mise"
  fi
done

# 1d. Symlink shims to /usr/local/bin (for CC hook subprocesses)
SHIMS_DIR="$HOME/.local/share/mise/shims"
if [[ -d "$SHIMS_DIR" ]]; then
  NEEDS_SYMLINK=false
  for tool in bun node npx npm yq; do
    if [[ ! -L "/usr/local/bin/$tool" ]] || [[ "$(readlink /usr/local/bin/$tool 2>/dev/null)" != "$SHIMS_DIR/$tool" ]]; then
      NEEDS_SYMLINK=true
      break
    fi
  done

  if $NEEDS_SYMLINK; then
    log "Creating /usr/local/bin symlinks (requires sudo)..."
    for tool in bun node npx npm yq; do
      if [[ -f "$SHIMS_DIR/$tool" ]]; then
        sudo ln -sf "$SHIMS_DIR/$tool" "/usr/local/bin/$tool" 2>>"$LOG_FILE" && ok "symlink: /usr/local/bin/$tool" || warn "symlink failed: $tool"
      fi
    done
  else
    ok "Symlinks already correct in /usr/local/bin"
  fi
else
  warn "mise shims directory not found — skipping symlinks"
fi

# ═════════════════════════════════════════════════════════════════════
# PHASE 2: WSL2 Hardening (WSL2 only, optional)
# ═════════════════════════════════════════════════════════════════════
if $IS_WSL2 && ! $SKIP_WSL_CONF; then
  log "Phase 2: WSL2 Hardening"

  if [[ -f /etc/wsl.conf ]] && grep -q 'appendWindowsPath.*=.*false' /etc/wsl.conf 2>/dev/null; then
    ok "wsl.conf already configured (appendWindowsPath=false)"
  elif prompt_yn "Disable Windows PATH pollution? (recommended, requires wsl --shutdown)" "default_y"; then
    log "Creating /etc/wsl.conf..."
    sudo tee /etc/wsl.conf > /dev/null << 'WSL_EOF'
[interop]
appendWindowsPath = false

[boot]
systemd = true
WSL_EOF
    ok "wsl.conf created — run 'wsl --shutdown' from PowerShell to apply"
    warn "After restart, only /usr/local/bin paths will be in PATH"

    # Prepare selective Windows tool re-add
    BASHRC_WINDOWS_BLOCK='
# Windows tools (selective re-add after appendWindowsPath=false)
if [[ -d "/mnt/c/Windows/system32" ]]; then
  export PATH="$PATH:/mnt/c/Windows/system32"
fi
if [[ -d "/mnt/c/Users" ]]; then
  # VS Code — adjust username if needed
  for vscode_bin in /mnt/c/Users/*/AppData/Local/Programs/Microsoft\ VS\ Code/bin; do
    [[ -d "$vscode_bin" ]] && export PATH="$PATH:$vscode_bin" && break
  done
fi'
    if ! grep -q 'appendWindowsPath' "$HOME/.bashrc" 2>/dev/null; then
      echo "$BASHRC_WINDOWS_BLOCK" >> "$HOME/.bashrc"
      ok "Added selective Windows PATH to .bashrc"
    fi
  else
    skip "WSL2 hardening skipped"
  fi
else
  [[ "$IS_WSL2" == "false" ]] && skip "Phase 2: Not WSL2 — skipping"
fi

# ═════════════════════════════════════════════════════════════════════
# PHASE 3: ATLAS Plugin (marketplace registration + install)
# ═════════════════════════════════════════════════════════════════════
if ! $SKIP_PLUGIN; then
  log "Phase 3: ATLAS Plugin"

  # Check if Claude Code is installed
  if ! command -v claude &>/dev/null; then
    fail "Claude Code CLI not found — install it first (https://claude.ai/download)"
    fail "Skipping plugin installation"
  else
    CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1)
    ok "Claude Code found ($CLAUDE_VERSION)"

    # Check if plugin already installed
    PLUGIN_CACHE="$HOME/.claude/plugins/cache/atlas-admin-marketplace"
    if [[ -d "$PLUGIN_CACHE/atlas-admin" ]]; then
      INSTALLED_VERSION=$(cat "$PLUGIN_CACHE/atlas-admin"/*/VERSION 2>/dev/null | sort -V | tail -1)
      ok "ATLAS plugin already installed (v${INSTALLED_VERSION:-unknown})"
      if prompt_yn "Refresh plugin to latest?" "default_n"; then
        log "Refreshing plugins..."
        claude plugin refresh 2>>"$LOG_FILE" && ok "Plugin refreshed" || warn "Plugin refresh failed"
      fi
    else
      # Check GITHUB_TOKEN
      if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        warn "GITHUB_TOKEN not set — required for private plugin repo"
        if ! $NON_INTERACTIVE; then
          read -rp "$(echo -e "${BLUE}[ATLAS]${NC} Enter GitHub token (or press Enter to skip): ")" GITHUB_TOKEN
          [[ -n "$GITHUB_TOKEN" ]] && export GITHUB_TOKEN
        fi
      fi

      if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        log "Registering marketplace..."
        claude plugin marketplace add "${ATLAS_PLUGIN_REPO}" 2>>"$LOG_FILE" \
          && ok "Marketplace registered" \
          || warn "Marketplace registration failed — try manually: /plugin marketplace add ${ATLAS_PLUGIN_REPO}"

        log "Installing atlas-admin plugin..."
        claude plugin install "atlas-admin@atlas-admin-marketplace" 2>>"$LOG_FILE" \
          && ok "Plugin installed" \
          || warn "Plugin install failed — try manually in CC: /plugin install atlas-admin@atlas-admin-marketplace"
      else
        warn "No GITHUB_TOKEN — skipping plugin marketplace setup"
        warn "Set GITHUB_TOKEN and re-run, or install manually in CC"
      fi
    fi
  fi
else
  skip "Phase 3: Plugin installation skipped"
fi

# ═════════════════════════════════════════════════════════════════════
# PHASE 4: ATLAS CLI (shell function + modules)
# ═════════════════════════════════════════════════════════════════════
log "Phase 4: ATLAS CLI"

ATLAS_SHELL_DIR="$HOME/.atlas/shell"
ATLAS_MODULES_DIR="$ATLAS_SHELL_DIR/modules"
CLI_SOURCE=""

# Find CLI source: plugin cache first, then GitHub clone
PLUGIN_CACHE="$HOME/.claude/plugins/cache/atlas-admin-marketplace"
LATEST_ADMIN=$(ls -d "$PLUGIN_CACHE/atlas-admin"/*/ 2>/dev/null | sort -V | tail -1)
if [[ -n "$LATEST_ADMIN" ]] && [[ -f "${LATEST_ADMIN}scripts/atlas-cli.sh" ]]; then
  CLI_SOURCE="${LATEST_ADMIN}scripts"
  ok "CLI source: plugin cache (${LATEST_ADMIN})"
elif [[ -d "$HOME/workspace_atlas/projects/atlas-dev-plugin/scripts" ]]; then
  CLI_SOURCE="$HOME/workspace_atlas/projects/atlas-dev-plugin/scripts"
  ok "CLI source: dev repo"
else
  # Clone from GitHub as last resort
  TEMP_CLONE=$(mktemp -d)
  log "Cloning plugin repo for CLI files..."
  if git clone --depth 1 "$ATLAS_PLUGIN_GIT" "$TEMP_CLONE" 2>>"$LOG_FILE"; then
    CLI_SOURCE="$TEMP_CLONE/scripts"
    ok "CLI source: GitHub clone"
  else
    fail "Cannot find CLI source — install plugin first or set GITHUB_TOKEN"
  fi
fi

if [[ -n "$CLI_SOURCE" ]]; then
  mkdir -p "$ATLAS_SHELL_DIR" "$ATLAS_MODULES_DIR"

  # Deploy atlas.sh
  if [[ -f "$CLI_SOURCE/atlas-cli.sh" ]]; then
    cp "$CLI_SOURCE/atlas-cli.sh" "$ATLAS_SHELL_DIR/atlas.sh"
    chmod +x "$ATLAS_SHELL_DIR/atlas.sh"
    ok "Deployed: ~/.atlas/shell/atlas.sh"
  fi

  # Deploy modules
  if [[ -d "$CLI_SOURCE/atlas-modules" ]]; then
    for mod in "$CLI_SOURCE/atlas-modules/"*.sh; do
      [[ -f "$mod" ]] && cp "$mod" "$ATLAS_MODULES_DIR/"
    done
    MOD_COUNT=$(ls "$ATLAS_MODULES_DIR/"*.sh 2>/dev/null | wc -l)
    ok "Deployed: $MOD_COUNT CLI modules to ~/.atlas/shell/modules/"
  fi

  # Cleanup temp clone
  [[ -n "${TEMP_CLONE:-}" ]] && rm -rf "$TEMP_CLONE"
fi

# ═════════════════════════════════════════════════════════════════════
# PHASE 5: Shell Integration
# ═════════════════════════════════════════════════════════════════════
log "Phase 5: Shell Integration"

# Detect primary shell
USER_SHELL=$(basename "${SHELL:-/bin/bash}")
RC_FILE="$HOME/.bashrc"
[[ "$USER_SHELL" == "zsh" ]] && RC_FILE="$HOME/.zshrc"

# mise activate (interactive shell)
if ! grep -q 'mise activate' "$RC_FILE" 2>/dev/null; then
  echo '' >> "$RC_FILE"
  echo '# mise (runtime version manager — manages node, bun, yq)' >> "$RC_FILE"
  echo 'eval "$(mise activate '"$USER_SHELL"')"' >> "$RC_FILE"
  ok "Added mise activate to $RC_FILE"
else
  ok "mise activate already in $RC_FILE"
fi

# mise shims in .profile (non-interactive/login shells)
PROFILE_FILE="$HOME/.profile"
[[ -f "$HOME/.bash_profile" ]] && PROFILE_FILE="$HOME/.bash_profile"
if ! grep -q 'mise activate.*--shims' "$PROFILE_FILE" 2>/dev/null; then
  echo '' >> "$PROFILE_FILE"
  echo '# mise shims (non-interactive PATH for CC hooks)' >> "$PROFILE_FILE"
  echo 'eval "$($HOME/.local/bin/mise activate bash --shims)"' >> "$PROFILE_FILE"
  ok "Added mise shims to $PROFILE_FILE"
else
  ok "mise shims already in $PROFILE_FILE"
fi

# ATLAS CLI sourcing
if ! grep -q 'atlas/shell/atlas.sh' "$RC_FILE" 2>/dev/null; then
  echo '' >> "$RC_FILE"
  echo '# ATLAS CLI' >> "$RC_FILE"
  echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> "$RC_FILE"
  ok "Added ATLAS CLI source to $RC_FILE"
else
  ok "ATLAS CLI already sourced in $RC_FILE"
fi

# ═════════════════════════════════════════════════════════════════════
# PHASE 6: CShip Status Line (optional)
# ═════════════════════════════════════════════════════════════════════
if ! $SKIP_CSHIP; then
  log "Phase 6: CShip Status Line"

  if command -v cship &>/dev/null; then
    ok "CShip already installed ($(cship --version 2>/dev/null | head -1))"
  elif prompt_yn "Install CShip status line? (enhances terminal UI)" "default_n"; then
    if command -v cargo &>/dev/null; then
      log "Installing CShip via cargo..."
      cargo install cship 2>>"$LOG_FILE" && ok "CShip installed via cargo" || warn "CShip cargo install failed"
    else
      # Try pre-built binary
      log "Installing CShip pre-built binary..."
      CSHIP_URL="https://github.com/seb155/cship/releases/latest/download/cship-linux-x86_64"
      if curl -fsSL "$CSHIP_URL" -o "$HOME/.local/bin/cship" 2>>"$LOG_FILE"; then
        chmod +x "$HOME/.local/bin/cship"
        ok "CShip installed to ~/.local/bin/cship"
      else
        warn "CShip install failed — install manually later"
      fi
    fi
  else
    skip "CShip installation skipped"
  fi
else
  skip "Phase 6: CShip skipped"
fi

# ═════════════════════════════════════════════════════════════════════
# PHASE 7: Validation
# ═════════════════════════════════════════════════════════════════════
log "Phase 7: Validation"
echo ""

PASS=0; FAIL_COUNT=0; WARN_COUNT=0

check() {
  local name="$1" cmd="$2"
  # bash -c isolates the command (no side effects on this shell) — safer than eval.
  if bash -c "$cmd" >/dev/null 2>&1; then
    ok "$name"; ((PASS++))
  else
    fail "$name"; ((FAIL_COUNT++))
  fi
}

check_warn() {
  local name="$1" cmd="$2"
  if bash -c "$cmd" >/dev/null 2>&1; then
    ok "$name"; ((PASS++))
  else
    warn "$name (optional)"; ((WARN_COUNT++))
  fi
}

check "mise"              "command -v mise"
check "bun"               "/usr/local/bin/bun --version"
check "node"              "/usr/local/bin/node --version"
check "yq"                "command -v yq"
check "git"               "command -v git"
check "ATLAS CLI"         "test -f $HOME/.atlas/shell/atlas.sh"
check "CLI modules"       "test -d $HOME/.atlas/shell/modules && ls $HOME/.atlas/shell/modules/*.sh"
check_warn "Claude Code"  "command -v claude"
check_warn "ATLAS plugin" "test -d $HOME/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin"
check_warn "CShip"        "command -v cship"
check_warn "tmux"         "command -v tmux"
check_warn "jq"           "command -v jq"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL_COUNT failed${NC}, ${YELLOW}$WARN_COUNT warnings${NC}          ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  log "🎉 ATLAS environment ready!"
  echo ""
  echo "  Next steps:"
  echo "    1. Source your shell:  source $RC_FILE"
  echo "    2. Launch ATLAS:      atlas"
  echo "    3. Run onboarding:    /atlas setup"
  echo ""
  if $IS_WSL2 && grep -q 'appendWindowsPath.*=.*false' /etc/wsl.conf 2>/dev/null; then
    warn "Remember: run 'wsl --shutdown' from PowerShell to apply wsl.conf changes"
  fi
else
  log "Some components failed — check $LOG_FILE for details"
  log "Re-run this script after fixing issues: ./atlas-bootstrap.sh"
fi

# Write validation report
cat > "$HOME/.atlas/bootstrap-report.json" << REPORT_EOF
{
  "version": "$ATLAS_BOOTSTRAP_VERSION",
  "timestamp": "$(date -Iseconds)",
  "platform": "$( $IS_WSL2 && echo 'wsl2' || echo 'linux' )",
  "results": { "pass": $PASS, "fail": $FAIL_COUNT, "warn": $WARN_COUNT },
  "log": "$LOG_FILE"
}
REPORT_EOF

exit $FAIL_COUNT
