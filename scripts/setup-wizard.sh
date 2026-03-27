#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════
# ATLAS Setup Wizard — Sectioned Configuration Manager
# © 2026 AXOIQ Inc. | Proprietary Software
#
# Usage:
#   atlas setup              Interactive section picker
#   atlas setup all          Run all sections
#   atlas setup cc           Claude Code sections only
#   atlas setup terminal     Terminal sections only
#   atlas setup projects     Projects section only
#   atlas setup <section>    Single section (identity, model, permissions, etc.)
# ═══════════════════════════════════════════════════════════════

# ─── Helpers ──────────────────────────────────────────────────
_setup_gum_check() {
  if ! command -v gum &>/dev/null; then
    echo "  gum is required for the setup wizard."
    echo "  Install: curl -sL github.com/charmbracelet/gum/releases/latest | bash"
    echo "  Or: go install github.com/charmbracelet/gum@latest"
    return 1
  fi
  return 0
}

_setup_write_config() {
  # Merge key=value into ~/.atlas/config.json using python
  local key="$1" value="$2"
  python3 -c "
import json, os
path = os.path.expanduser('${ATLAS_CONFIG}')
try:
    with open(path) as f: config = json.load(f)
except: config = {}
# Navigate dotted key path
keys = '$key'.split('.')
obj = config
for k in keys[:-1]:
    obj = obj.setdefault(k, {})
# Handle type conversion
val = '$value'
if val in ('true', 'True'): val = True
elif val in ('false', 'False'): val = False
elif val.isdigit(): val = int(val)
obj[keys[-1]] = val
with open(path, 'w') as f: json.dump(config, f, indent=2)
" 2>/dev/null
}

_setup_read_config() {
  _atlas_read_config "$1" "$2"
}

_setup_section_header() {
  local num="$1" total="$2" title="$3" icon="$4"
  echo ""
  gum style --foreground 214 --bold "${icon} Section ${num}/${total} — ${title}"
  echo ""
}

_setup_success() {
  gum style --foreground 46 "  ✓ $1"
}

_setup_info() {
  gum style --foreground 111 "  ℹ $1"
}

_setup_warn() {
  gum style --foreground 214 "  ⚠ $1"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 1: Identity (Forgejo API + Vault auto-detect)
# ═══════════════════════════════════════════════════════════════
_setup_identity() {
  _setup_section_header 1 9 "Identity" "👤"

  local name="" email="" org="" forgejo_login="" vault_path=""

  # Auto-detect from Forgejo
  source "${HOME}/.env" 2>/dev/null || true
  if [ -n "${FORGEJO_TOKEN:-}" ]; then
    local forgejo_api="${ATLAS_FORGEJO_API:-http://192.168.10.75:3000/api/v1}"
    local data=$(curl -sf --connect-timeout 3 "${forgejo_api}/user" \
      -H "Authorization: token ${FORGEJO_TOKEN}" 2>/dev/null || echo "")

    if [ -n "$data" ]; then
      forgejo_login=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('login',''))" 2>/dev/null)
      name=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('full_name',''))" 2>/dev/null)
      email=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('email',''))" 2>/dev/null)
      local is_admin=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('is_admin',False))" 2>/dev/null)

      _setup_success "Forgejo: ${name} (${forgejo_login})${is_admin:+ [admin]}"
    fi
  else
    _setup_info "No FORGEJO_TOKEN — skipping Forgejo lookup"
  fi

  # Auto-detect vault
  local ws="${ATLAS_WORKSPACE_ROOT:-$HOME/workspace_atlas}"
  for vdir in "${ws}/vaults"/*/ ; do
    if [ -f "${vdir}kernel/manifest.json" ]; then
      vault_path="${vdir%/}"
      _setup_success "Vault: $(basename "$vdir") at ${vdir}"
      break
    fi
  done

  # Confirm/edit
  name=$(gum input --header "Full name:" --placeholder "Your name" --value "${name:-$USER}" --width 50)
  email=$(gum input --header "Email:" --placeholder "you@company.com" --value "${email:-}" --width 50)
  org=$(gum input --header "Organization:" --placeholder "Company" --value "$(_setup_read_config organization "AXOIQ Inc.")" --width 50)

  # Save
  _setup_write_config "identity.name" "$name"
  _setup_write_config "identity.email" "$email"
  _setup_write_config "organization" "$org"
  [ -n "$forgejo_login" ] && _setup_write_config "forgejo.login" "$forgejo_login"
  [ -n "$vault_path" ] && _setup_write_config "vault.path" "$vault_path"

  _setup_success "Identity saved"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 2: AI Model & Reasoning
# ═══════════════════════════════════════════════════════════════
_setup_model() {
  _setup_section_header 2 9 "AI Model & Reasoning" "🧠"

  local current_effort=$(_setup_read_config "launcher.effort" "max")
  local current_compact=$(_setup_read_config "" "85")  # from env

  # 1. Default model
  _setup_info "Claude Code uses your subscription model by default."
  _setup_info "Override only if you want a specific model per-project."
  local model=$(printf 'opus (Claude Opus 4.6 — most capable)\nsonnet (Claude Sonnet 4.6 — fast + capable)\nhaiku (Claude Haiku 4.5 — fastest)\ndefault (use subscription default)' | \
    gum choose --header "Default AI model:")
  model="${model%% *}"  # extract first word

  # 2. Effort level
  local effort=$(printf 'max — Ultrathink (deepest reasoning, slowest)\nhigh — Deep analysis (recommended)\nmedium — Balanced speed/quality\nlow — Quick responses' | \
    gum choose --header "Default effort level:" --selected "max")
  effort="${effort%% *}"

  # 3. Thinking tokens budget
  local thinking=$(printf '250000 — Maximum (current, best for architecture)\n128000 — High (good for implementation)\n64000 — Standard (good for simple tasks)\n32000 — Minimal (fastest)' | \
    gum choose --header "Max thinking tokens:")
  thinking="${thinking%% *}"

  # 4. Output tokens
  local output=$(printf '128000 — Extended (current, best for code generation)\n64000 — Standard\n32000 — Compact\n16000 — Minimal' | \
    gum choose --header "Max output tokens:")
  output="${output%% *}"

  # 5. Auto-compaction threshold
  local compact=$(printf '92 — Late (more context, risk of degradation)\n85 — Balanced (current, recommended)\n75 — Early (preserves quality, more compactions)\n60 — Aggressive (many compactions)' | \
    gum choose --header "Auto-compaction threshold (% context used):")
  compact="${compact%% *}"

  # 6. Auto-updates
  local updates=$(printf 'latest — Always newest features\nstable — Proven releases only\ndisabled — Manual updates only' | \
    gum choose --header "Auto-update channel:")
  updates="${updates%% *}"

  # Save to appropriate config files
  _setup_write_config "launcher.effort" "$effort"

  # These go into CC settings.json (not atlas config)
  python3 -c "
import json, os
path = os.path.expanduser('~/.claude/settings.json')
with open(path) as f: s = json.load(f)
if '$model' != 'default':
    s['model'] = 'claude-${model}-4-6' if '$model' in ('opus','sonnet') else 'claude-haiku-4-5-20251001'
s['effortLevel'] = '$effort'
s['autoUpdatesChannel'] = '$updates'
s['env']['CLAUDE_AUTOCOMPACT_PCT_OVERRIDE'] = '$compact'
s['env']['CLAUDE_CODE_MAX_OUTPUT_TOKENS'] = '$output'
s['env']['CLAUDE_CODE_MAX_THINKING_TOKENS'] = '$thinking'
with open(path, 'w') as f: json.dump(s, f, indent=2)
" 2>/dev/null

  _setup_success "AI config: model=${model} effort=${effort} thinking=${thinking} output=${output}"
  _setup_success "Compaction: ${compact}% | Updates: ${updates}"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 3: Permissions & Security
# ═══════════════════════════════════════════════════════════════
_setup_permissions() {
  _setup_section_header 3 9 "Permissions & Security" "🔒"

  _setup_info "Permission presets control what Claude Code can do automatically."
  echo ""

  local preset=$(printf 'power-user — All tools auto-approved, deny destructive only (current)\ntrusted-dev — Bash + Read + Edit auto-approved, MCP prompts\nrestricted — Only Read auto-approved, everything else prompts\ncustom — Configure manually' | \
    gum choose --header "Permission preset:")
  preset="${preset%% *}"

  local default_mode="default"
  case "$preset" in
    power-user)
      _setup_info "All tools allowed. Destructive commands blocked."
      default_mode="default"
      ;;
    trusted-dev)
      _setup_info "Bash, Read, Edit allowed. MCP and sudo prompt."
      default_mode="default"
      ;;
    restricted)
      _setup_info "Only Read allowed. Everything else needs approval."
      default_mode="default"
      ;;
    custom)
      _setup_info "You'll configure allow/deny lists manually."
      ;;
  esac

  # Auto mode configuration
  echo ""
  local use_auto=$(gum confirm "Enable Auto Mode? (Sonnet classifier auto-approves safe actions)" && echo true || echo false)

  if [ "$use_auto" = "true" ]; then
    _setup_info "Auto mode uses a Sonnet classifier to approve/block actions."
    _setup_info "Configure trusted repos and services for lighter checks."

    local trusted_repos=$(gum input --header "Trusted repos (glob, comma-separated):" \
      --placeholder "~/workspace_atlas/**" \
      --value "~/workspace_atlas/**" --width 60)

    local trusted_services=$(gum input --header "Trusted services (comma-separated):" \
      --placeholder "localhost, 192.168.10.*, *.axoiq.com" \
      --value "localhost, 192.168.10.*, *.axoiq.com, *.home.axoiq.com" --width 60)
  fi

  # Save
  python3 -c "
import json, os
path = os.path.expanduser('~/.claude/settings.json')
with open(path) as f: s = json.load(f)

preset = '$preset'
if preset == 'power-user':
    s['permissions']['allow'] = ['Bash', 'Bash(sudo *)', 'Read', 'Write', 'Edit', 'Glob', 'Grep', 'WebSearch', 'WebFetch', 'Skill(*)', 'mcp__*', 'Task(*)']
    s['permissions']['deny'] = ['Bash(rm -rf /)', 'Bash(sudo rm -rf /)', 'Bash(mkfs *)', 'Bash(dd if=/dev/zero of=/dev/ *)']
elif preset == 'trusted-dev':
    s['permissions']['allow'] = ['Bash', 'Read', 'Write', 'Edit', 'Glob', 'Grep', 'WebSearch', 'WebFetch', 'Skill(*)', 'Task(*)']
    s['permissions']['deny'] = ['Bash(rm -rf /)', 'Bash(sudo *)', 'Bash(mkfs *)', 'Bash(dd if=/dev/zero of=/dev/ *)']
elif preset == 'restricted':
    s['permissions']['allow'] = ['Read', 'Glob', 'Grep', 'Task(*)']
    s['permissions']['deny'] = ['Bash(rm -rf /)', 'Bash(mkfs *)']

if $use_auto:
    repos = [r.strip() for r in '$trusted_repos'.split(',')]
    svcs = [s_.strip() for s_ in '$trusted_services'.split(',')]
    s['autoMode'] = {'environment': {'trustedRepos': repos, 'trustedServices': svcs}}

with open(path, 'w') as f: json.dump(s, f, indent=2)
" 2>/dev/null

  _setup_success "Permissions: ${preset} | Auto mode: ${use_auto}"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 4: Shell & Terminal
# ═══════════════════════════════════════════════════════════════
_setup_shell() {
  _setup_section_header 4 9 "Shell & Terminal" "🐚"

  # Detect current state
  _setup_info "OS: ${ATLAS_OS} | Arch: ${ATLAS_ARCH} | Shell: ${SHELL##*/} | Term: ${ATLAS_TERM}"

  # Zsh plugins
  echo ""
  gum style --foreground 111 --bold "  Zsh Plugins (Oh-My-Zsh)"
  local current_plugins="git docker kubectl fzf zsh-autosuggestions zsh-syntax-highlighting"
  _setup_info "Current: ${current_plugins}"

  local available_plugins="git\ndocker\nkubectl\nfzf\nzsh-autosuggestions\nzsh-syntax-highlighting\nzsh-history-substring-search\nalias-finder\ncommon-aliases\ncolored-man-pages\ncopypath\ncopyfile\njsontools\nurltools"

  local selected_plugins=$(printf "$available_plugins" | \
    gum choose --header "Select plugins (space to toggle):" \
    --no-limit \
    --selected "git,docker,kubectl,fzf,zsh-autosuggestions,zsh-syntax-highlighting")

  # Smart tools
  echo ""
  gum style --foreground 111 --bold "  Smart Tools"

  local use_zoxide=$(command -v zoxide &>/dev/null && echo "installed" || echo "not installed")
  local use_direnv=$(command -v direnv &>/dev/null && echo "installed" || echo "not installed")
  local use_fzf=$(command -v fzf &>/dev/null && echo "installed" || echo "not installed")

  _setup_info "zoxide (smart cd): ${use_zoxide}"
  _setup_info "direnv (auto .envrc): ${use_direnv}"
  _setup_info "fzf (fuzzy finder): ${use_fzf}"

  local install_missing=false
  if [ "$use_zoxide" = "not installed" ] || [ "$use_direnv" = "not installed" ]; then
    install_missing=$(gum confirm "Install missing tools?" && echo true || echo false)
  fi

  if [ "$install_missing" = "true" ]; then
    local _pkg="sudo apt-get install -y"
    [[ "$ATLAS_OS" == "macos" ]] && _pkg="brew install"

    if [ "$use_zoxide" = "not installed" ]; then
      gum spin --spinner dot --title "Installing zoxide..." -- \
        bash -c "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash" 2>/dev/null
      _setup_success "zoxide installed"
    fi
    if [ "$use_direnv" = "not installed" ]; then
      gum spin --spinner dot --title "Installing direnv..." -- \
        bash -c "$_pkg direnv" 2>/dev/null
      _setup_success "direnv installed"
    fi
  fi

  # Zsh completion for atlas
  echo ""
  gum style --foreground 111 --bold "  Atlas Completion"
  _setup_success "Zsh completion for 'atlas' is already configured (built-in)"

  # Apply zsh plugins (update .zshrc plugins line)
  if [ -n "$selected_plugins" ]; then
    local plugins_str=$(echo "$selected_plugins" | tr '\n' ' ' | sed 's/ $//')
    # Only update if changed
    local current=$(grep -oP 'plugins=\(\K[^)]+' ~/.zshrc 2>/dev/null | tr -d '\n' | sed 's/  */ /g')
    if [ "$plugins_str" != "$current" ]; then
      _setup_info "Updating .zshrc plugins: ${plugins_str}"
      python3 -c "
import re
with open('$HOME/.zshrc') as f: content = f.read()
new_plugins = '''plugins=(
    ${plugins_str// /\\n    }
)'''
content = re.sub(r'plugins=\([^)]*\)', new_plugins, content)
with open('$HOME/.zshrc', 'w') as f: f.write(content)
print('OK')
" 2>/dev/null
      _setup_success "Zsh plugins updated (reload with: source ~/.zshrc)"
    else
      _setup_info "Plugins unchanged"
    fi
  fi

  _setup_success "Shell configuration complete"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 5: Secrets & Tokens
# ═══════════════════════════════════════════════════════════════
_setup_secrets() {
  _setup_section_header 5 9 "Secrets & Tokens" "🔑"

  # Detect available providers
  local has_bw=$(command -v bw &>/dev/null && echo true || echo false)
  local has_keyring=$(command -v secret-tool &>/dev/null && echo true || echo false)
  local has_env=$([ -f "${HOME}/.env" ] && echo true || echo false)

  $has_bw && _setup_success "Bitwarden CLI detected" || _setup_info "Bitwarden CLI not found"
  $has_keyring && _setup_success "GNOME Keyring detected" || _setup_info "GNOME Keyring not found"
  $has_env && _setup_success "~/.env file found" || _setup_info "No ~/.env file"

  echo ""
  local options="env-file — Use ~/.env files (simplest)"
  $has_keyring && options="keyring — GNOME/KDE Keyring (system-native)\n${options}"
  $has_bw && options="vaultwarden — Bitwarden/Vaultwarden (most secure)\n${options}"
  options="${options}\nnone — No automatic secret loading"

  local provider=$(printf "$options" | gum choose --header "Secrets provider:")
  provider="${provider%% *}"

  # Validate
  echo ""
  if [ "$provider" != "none" ]; then
    gum spin --spinner dot --title "Testing secret access..." -- \
      bash -c "source ${HOME}/.atlas/scripts/load-secrets.sh 2>/dev/null"

    source "${HOME}/.atlas/scripts/load-secrets.sh" 2>/dev/null
    [ -n "${FORGEJO_TOKEN:-}" ] && _setup_success "FORGEJO_TOKEN ✓" || _setup_warn "FORGEJO_TOKEN missing"
    [ -n "${SYNAPSE_TOKEN:-}" ] && _setup_success "SYNAPSE_TOKEN ✓" || _setup_info "SYNAPSE_TOKEN not set (optional)"
  fi

  _setup_write_config "secrets.provider" "$provider"
  _setup_success "Secrets provider: ${provider}"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 6: Projects & Defaults
# ═══════════════════════════════════════════════════════════════
_setup_projects() {
  _setup_section_header 6 9 "Projects & Defaults" "📁"

  # Workspace root
  local ws=$(_setup_read_config "launcher.workspace_root" "$HOME/workspace_atlas")
  ws="${ws/#\~/$HOME}"
  ws=$(gum input --header "Workspace root:" --value "$ws" --width 60)

  # Scan projects
  local project_count=$(ls -d "${ws}"/*/.git "${ws}"/projects/*/.git "${ws}"/projects/atlas/*/.git 2>/dev/null | wc -l)
  _setup_info "Found ${project_count} projects in ${ws}"

  # Default project
  local projects=($(_atlas_known_projects))
  local default=$(_setup_read_config "launcher.default_project" "synapse")
  if [ ${#projects[@]} -gt 0 ]; then
    default=$(printf '%s\n' "${projects[@]}" | gum choose --header "Default project:" --selected "$default")
  fi

  # Launch defaults
  echo ""
  gum style --foreground 111 --bold "  Launch Defaults"
  local use_worktree=$(gum confirm "Worktree by default? (git isolation)" --default=yes && echo true || echo false)
  local use_split=$(gum confirm "Tmux split by default? (Agent Teams)" --default=yes && echo true || echo false)
  local use_chrome=$(gum confirm "Chrome MCP by default? (browser tools)" --default=yes && echo true || echo false)

  # Save
  _setup_write_config "launcher.workspace_root" "$ws"
  _setup_write_config "launcher.default_project" "$default"
  _setup_write_config "launcher.worktree" "$use_worktree"
  _setup_write_config "launcher.split" "$use_split"
  _setup_write_config "launcher.chrome" "$use_chrome"

  _setup_success "Default: atlas ${default} (wt=${use_worktree} split=${use_split} chrome=${use_chrome})"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 7 (Advanced): Status Line & Prompt
# ═══════════════════════════════════════════════════════════════
_setup_statusline() {
  _setup_section_header 7 9 "Status Line & Prompt" "📊"

  local has_starship=$(command -v starship &>/dev/null && echo true || echo false)
  local has_cship=$(command -v cship &>/dev/null && echo true || echo false)

  $has_starship && _setup_success "Starship prompt: installed" || _setup_info "Starship not installed"
  $has_cship && _setup_success "CShip status line: installed" || _setup_info "CShip not installed"

  # CC Status Line
  echo ""
  gum style --foreground 111 --bold "  Claude Code Status Line"
  local sl_type=$(printf 'cship — ATLAS branded status bar (recommended)\nstarship — Uses starship command\nscript — Custom bash script\nnone — Disable status line' | \
    gum choose --header "Status line renderer:")
  sl_type="${sl_type%% *}"

  case "$sl_type" in
    cship)
      if ! $has_cship; then
        _setup_warn "CShip not installed. Install via: cargo install cship"
        _setup_info "Falling back to script mode"
        sl_type="script"
      fi
      ;;
    none)
      _setup_info "Status line disabled"
      ;;
  esac

  # Save to CC settings
  python3 -c "
import json, os
for path in ['$HOME/.claude/settings.json', '$HOME/workspace_atlas/projects/atlas/synapse/.claude/settings.local.json']:
    try:
        path = os.path.expanduser(path)
        if not os.path.exists(path): continue
        with open(path) as f: s = json.load(f)
        if '$sl_type' == 'cship':
            s['statusLine'] = {'type': 'command', 'command': 'cship'}
        elif '$sl_type' == 'script':
            s['statusLine'] = {'type': 'command', 'command': '\$HOME/.claude/statusline-command.sh'}
        elif '$sl_type' == 'none':
            s.pop('statusLine', None)
        with open(path, 'w') as f: json.dump(s, f, indent=2)
    except: pass
" 2>/dev/null

  _setup_success "Status line: ${sl_type}"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 8 (Advanced): Performance & Limits
# ═══════════════════════════════════════════════════════════════
_setup_performance() {
  _setup_section_header 8 9 "Performance & Limits" "⚡"

  _setup_info "These settings affect Claude Code's resource usage."
  echo ""

  # Node.js memory
  local node_mem=$(printf '8192 — 8GB (current, recommended for Opus)\n4096 — 4GB (lighter)\n16384 — 16GB (for very large codebases)' | \
    gum choose --header "Node.js memory (MB):")
  node_mem="${node_mem%% *}"

  # Bash timeout
  local bash_timeout=$(printf '600000 — 10 min (current, recommended)\n300000 — 5 min (faster feedback)\n900000 — 15 min (complex builds)\n1800000 — 30 min (max)' | \
    gum choose --header "Default bash timeout (ms):")
  bash_timeout="${bash_timeout%% *}"

  # MCP timeout
  local mcp_timeout=$(printf '60000 — 1 min (current)\n30000 — 30 sec (faster)\n120000 — 2 min (slow servers)' | \
    gum choose --header "MCP server timeout (ms):")
  mcp_timeout="${mcp_timeout%% *}"

  # Bash output limit
  local output_limit=$(printf '30000 — 30K lines (current)\n15000 — 15K lines (saves context)\n50000 — 50K lines (verbose builds)' | \
    gum choose --header "Max bash output length:")
  output_limit="${output_limit%% *}"

  # Save
  python3 -c "
import json, os
path = os.path.expanduser('~/.claude/settings.json')
with open(path) as f: s = json.load(f)
s['env']['NODE_OPTIONS'] = '--max-old-space-size=${node_mem}'
s['env']['BASH_DEFAULT_TIMEOUT_MS'] = '${bash_timeout}'
s['env']['MCP_TIMEOUT'] = '${mcp_timeout}'
s['env']['MCP_TOOL_TIMEOUT'] = '${mcp_timeout}'
s['env']['BASH_MAX_OUTPUT_LENGTH'] = '${output_limit}'
with open(path, 'w') as f: json.dump(s, f, indent=2)
" 2>/dev/null

  _setup_success "Memory: ${node_mem}MB | Bash: ${bash_timeout}ms | MCP: ${mcp_timeout}ms | Output: ${output_limit}"
}

# ═══════════════════════════════════════════════════════════════
# SECTION 9 (Advanced): Plugins & MCP
# ═══════════════════════════════════════════════════════════════
_setup_plugins() {
  _setup_section_header 9 9 "Plugins & MCP" "🧩"

  # Detect installed plugins
  local plugin_dir="${HOME}/.claude/plugins/cache"
  _setup_info "Scanning installed plugins..."

  if [ -d "$plugin_dir" ]; then
    for marketplace_dir in "$plugin_dir"/*/; do
      for plugin_dir_inner in "$marketplace_dir"/*/; do
        local pname=$(basename "$plugin_dir_inner")
        local pver=$(ls -v "$plugin_dir_inner" 2>/dev/null | tail -1)
        [ -n "$pver" ] && _setup_success "${pname} v${pver}"
      done
    done
  fi

  # ATLAS plugin check
  echo ""
  local atlas_ver=$(_atlas_plugin_version)
  if [ "$atlas_ver" != "?.?.?" ]; then
    local skill_count=$(find "${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/${atlas_ver}/skills" -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
    local agent_count=$(find "${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/${atlas_ver}/agents" -name "AGENT.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
    _setup_success "ATLAS plugin v${atlas_ver}: ${skill_count} skills, ${agent_count} agents"
  else
    _setup_warn "ATLAS plugin not found"
    _setup_info "Install in Claude Code: /plugin install atlas-admin@atlas-admin-marketplace"
  fi

  # MCP servers
  echo ""
  gum style --foreground 111 --bold "  MCP Servers"
  _setup_info "MCP servers are configured per-project in .claude/settings.local.json"
  _setup_info "Common: playwright, context7, stitch, chrome-devtools"

  _setup_success "Plugin configuration complete"
}

# ═══════════════════════════════════════════════════════════════
# MAIN WIZARD ROUTER
# ═══════════════════════════════════════════════════════════════
_atlas_setup() {
  _setup_gum_check || return 1
  _atlas_header

  local subcmd="${1:-}"

  # Direct section routing
  case "$subcmd" in
    identity)    _setup_identity; _atlas_footer; return ;;
    model)       _setup_model; _atlas_footer; return ;;
    permissions) _setup_permissions; _atlas_footer; return ;;
    shell)       _setup_shell; _atlas_footer; return ;;
    secrets)     _setup_secrets; _atlas_footer; return ;;
    projects)    _setup_projects; _atlas_footer; return ;;
    statusline)  _setup_statusline; _atlas_footer; return ;;
    performance) _setup_performance; _atlas_footer; return ;;
    plugins)     _setup_plugins; _atlas_footer; return ;;
    all)         _setup_run_all; _atlas_footer; return ;;
    cc)          _setup_run_cc; _atlas_footer; return ;;
    terminal)    _setup_run_terminal; _atlas_footer; return ;;
    proj)        _setup_projects; _atlas_footer; return ;;
  esac

  # Interactive section picker
  echo ""
  local choice=$(printf '🚀 Quick Setup (Identity + Model + Projects)\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n🤖 CLAUDE CODE\n  👤 1. Identity — Forgejo/vault auto-detect\n  🧠 2. AI Model — model, effort, thinking budget\n  🔒 3. Permissions — presets, auto mode\n  🔑 5. Secrets — Vaultwarden, keyring, tokens\n🐚 TERMINAL\n  🐚 4. Shell — zsh plugins, tools, completion\n📁 PROJECTS\n  📁 6. Projects — workspace, defaults, worktree\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n⚙️  ADVANCED\n  📊 7. Status Line — Starship, CShip\n  ⚡ 8. Performance — memory, timeouts\n  🧩 9. Plugins — CC plugins, MCP\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n🌟 Full Setup (all 9 sections)' | \
    gum choose --header "ATLAS Setup — Select what to configure:" \
    --cursor "→ " --cursor.foreground 214 --height 22)

  [ -z "$choice" ] && return 0

  case "$choice" in
    *"Quick Setup"*)  _setup_identity; _setup_model; _setup_projects ;;
    *"Full Setup"*)   _setup_run_all ;;
    *"1. Identity"*)  _setup_identity ;;
    *"2. AI Model"*)  _setup_model ;;
    *"3. Permissions"*) _setup_permissions ;;
    *"4. Shell"*)     _setup_shell ;;
    *"5. Secrets"*)   _setup_secrets ;;
    *"6. Projects"*)  _setup_projects ;;
    *"7. Status"*)    _setup_statusline ;;
    *"8. Performance"*) _setup_performance ;;
    *"9. Plugins"*)   _setup_plugins ;;
    *"CLAUDE CODE"*)  _setup_run_cc ;;
    *"TERMINAL"*)     _setup_run_terminal ;;
    *"PROJECTS"*)     _setup_projects ;;
  esac

  echo ""
  gum style --foreground 46 --bold "  ✓ Setup complete!"
  _setup_info "Run 'atlas setup <section>' to reconfigure any section."
  _atlas_footer
}

_setup_run_all() {
  _setup_identity
  _setup_model
  _setup_permissions
  _setup_shell
  _setup_secrets
  _setup_projects
  _setup_statusline
  _setup_performance
  _setup_plugins
}

_setup_run_cc() {
  _setup_identity
  _setup_model
  _setup_permissions
  _setup_secrets
}

_setup_run_terminal() {
  _setup_shell
  _setup_statusline
}
