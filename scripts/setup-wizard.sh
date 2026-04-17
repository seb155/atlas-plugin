#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by user shells (zsh/.zshrc). See ~/.zshrc integration guide.
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
    local forgejo_api="${ATLAS_FORGEJO_API:-https://forgejo.axoiq.com/api/v1}"
    local data
    data=$(curl -sf --connect-timeout 3 "${forgejo_api}/user" \
      -H "Authorization: token ${FORGEJO_TOKEN}" 2>/dev/null || echo "")

    if [ -n "$data" ]; then
      forgejo_login=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('login',''))" 2>/dev/null)
      name=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('full_name',''))" 2>/dev/null)
      email=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('email',''))" 2>/dev/null)
      local is_admin
      is_admin=$(echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('is_admin',False))" 2>/dev/null)

      _setup_success "Forgejo: ${name} (${forgejo_login})${is_admin:+ [admin]}"
    fi
  else
    _setup_info "No FORGEJO_TOKEN — skipping Forgejo lookup"
  fi

  # Auto-detect vault
  local ws="${ATLAS_WORKSPACE_ROOT:-}"
  if [ -z "$ws" ]; then
    # Try config.json workspace_root, then fallback to convention
    ws=$(python3 -c "import json; print(json.load(open('$HOME/.atlas/config.json')).get('launcher',{}).get('workspace_root',''))" 2>/dev/null)
    [ -z "$ws" ] && ws="$HOME/workspace_atlas"
  fi
  if [ -d "${ws}/vaults" ]; then
    while IFS= read -r vdir; do
      # Restore trailing slash for the original logic
      vdir="${vdir}/"
      if [ -f "${vdir}kernel/manifest.json" ]; then
        vault_path="${vdir%/}"
        _setup_success "Vault: $(basename "$vdir") at ${vdir}"
        break
      fi
    done < <(find "${ws}/vaults" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  else
    _setup_info "No vaults directory at ${ws}/vaults — skipping vault auto-detect"
  fi

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

  local current_effort
  current_effort=$(_setup_read_config "launcher.effort" "max")
  local current_compact
  current_compact=$(_setup_read_config "" "85")  # from env

  # 1. Default model
  _setup_info "Claude Code uses your subscription model by default."
  _setup_info "Override only if you want a specific model per-project."
  local model
  model=$(printf 'opus (Claude Opus 4.7 — most capable)\nsonnet (Claude Sonnet 4.6 — fast + capable)\nhaiku (Claude Haiku 4.5 — fastest)\ndefault (use subscription default)' | \
    gum choose --header "Default AI model:")
  model="${model%% *}"  # extract first word

  # 2. Effort level
  local effort
  effort=$(printf 'max — Ultrathink (deepest reasoning, slowest)\nhigh — Deep analysis (recommended)\nmedium — Balanced speed/quality\nlow — Quick responses' | \
    gum choose --header "Default effort level:" --selected "max")
  effort="${effort%% *}"

  # 3. Thinking tokens budget
  local thinking
  thinking=$(printf '250000 — Maximum (current, best for architecture)\n128000 — High (good for implementation)\n64000 — Standard (good for simple tasks)\n32000 — Minimal (fastest)' | \
    gum choose --header "Max thinking tokens:")
  thinking="${thinking%% *}"

  # 4. Output tokens
  local output
  output=$(printf '128000 — Extended (current, best for code generation)\n64000 — Standard\n32000 — Compact\n16000 — Minimal' | \
    gum choose --header "Max output tokens:")
  output="${output%% *}"

  # 5. Auto-compaction threshold
  local compact
  compact=$(printf '92 — Late (more context, risk of degradation)\n85 — Balanced (current, recommended)\n75 — Early (preserves quality, more compactions)\n60 — Aggressive (many compactions)' | \
    gum choose --header "Auto-compaction threshold (% context used):")
  compact="${compact%% *}"

  # 6. Auto-updates
  local updates
  updates=$(printf 'latest — Always newest features\nstable — Proven releases only\ndisabled — Manual updates only' | \
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

  local preset
  preset=$(printf 'power-user — All tools auto-approved, deny destructive only (current)\ntrusted-dev — Bash + Read + Edit auto-approved, MCP prompts\nrestricted — Only Read auto-approved, everything else prompts\ncustom — Configure manually' | \
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
  local use_auto
  use_auto=$(gum confirm "Enable Auto Mode? (Sonnet classifier auto-approves safe actions)" && echo true || echo false)

  if [ "$use_auto" = "true" ]; then
    _setup_info "Auto mode uses a Sonnet classifier to approve/block actions."
    _setup_info "Configure trusted repos and services for lighter checks."

    local trusted_repos
    trusted_repos=$(gum input --header "Trusted repos (glob, comma-separated):" \
      --placeholder "~/workspace_atlas/**" \
      --value "~/workspace_atlas/**" --width 60)

    local trusted_services
    trusted_services=$(gum input --header "Trusted services (comma-separated):" \
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

  # Enforce safety policy (mandatory deny rules regardless of preset)
  _setup_info "Enforcing safety policy..."
  local policy_file="${ATLAS_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/presets/safety-policy.json"
  if [ -f "$policy_file" ]; then
    python3 -c "
import json, os
settings_path = os.path.expanduser('~/.claude/settings.json')
with open(settings_path) as f:
    s = json.load(f)
with open('$policy_file') as f:
    policy = json.load(f)

# Ensure all mandatory deny rules exist
current_deny = set(s.get('permissions', {}).get('deny', []))
required_deny = set(policy.get('deny_rules', []))
missing = required_deny - current_deny
if missing:
    s.setdefault('permissions', {}).setdefault('deny', [])
    s['permissions']['deny'] = list(current_deny | required_deny)
    print(f'Added {len(missing)} missing deny rules')
else:
    print('All deny rules present')

# Remove forbidden keys
for key in policy.get('forbidden_settings_keys', {}).get('keys', []):
    if key in s:
        del s[key]
        print(f'Removed forbidden key: {key}')

with open(settings_path, 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
" 2>/dev/null
    _setup_success "Safety policy enforced"
  fi
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

  local selected_plugins
  selected_plugins=$(printf "$available_plugins" | \
    gum choose --header "Select plugins (space to toggle):" \
    --no-limit \
    --selected "git,docker,kubectl,fzf,zsh-autosuggestions,zsh-syntax-highlighting")

  # Smart tools
  echo ""
  gum style --foreground 111 --bold "  Smart Tools"

  local use_zoxide
  use_zoxide=$(command -v zoxide &>/dev/null && echo "installed" || echo "not installed")
  local use_direnv
  use_direnv=$(command -v direnv &>/dev/null && echo "installed" || echo "not installed")
  local use_fzf
  use_fzf=$(command -v fzf &>/dev/null && echo "installed" || echo "not installed")

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
    local plugins_str
    plugins_str=$(echo "$selected_plugins" | tr '\n' ' ' | sed 's/ $//')
    # Only update if changed
    local current
    current=$(grep -oP 'plugins=\(\K[^)]+' ~/.zshrc 2>/dev/null | tr -d '\n' | sed 's/  */ /g')
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
  local has_bw
  has_bw=$(command -v bw &>/dev/null && echo true || echo false)
  local has_keyring
  has_keyring=$(command -v secret-tool &>/dev/null && echo true || echo false)
  local has_env
  has_env=$([ -f "${HOME}/.env" ] && echo true || echo false)

  $has_bw && _setup_success "Bitwarden CLI detected" || _setup_info "Bitwarden CLI not found"
  $has_keyring && _setup_success "GNOME Keyring detected" || _setup_info "GNOME Keyring not found"
  $has_env && _setup_success "~/.env file found" || _setup_info "No ~/.env file"

  echo ""
  local options="env-file — Use ~/.env files (simplest)"
  $has_keyring && options="keyring — GNOME/KDE Keyring (system-native)\n${options}"
  $has_bw && options="vaultwarden — Bitwarden/Vaultwarden (most secure)\n${options}"
  options="${options}\nnone — No automatic secret loading"

  local provider
  provider=$(printf "$options" | gum choose --header "Secrets provider:")
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
  local ws
  ws=$(_setup_read_config "launcher.workspace_root" "$HOME/workspace_atlas")
  ws="${ws/#\~/$HOME}"
  ws=$(gum input --header "Workspace root:" --value "$ws" --width 60)

  # Scan projects
  local project_count
  project_count=$(ls -d "${ws}"/*/.git "${ws}"/projects/*/.git "${ws}"/projects/atlas/*/.git 2>/dev/null | wc -l)
  _setup_info "Found ${project_count} projects in ${ws}"

  # Default project
  local projects=($(_atlas_known_projects))
  local default
  default=$(_setup_read_config "launcher.default_project" "synapse")
  if [ ${#projects[@]} -gt 0 ]; then
    default=$(printf '%s\n' "${projects[@]}" | gum choose --header "Default project:" --selected "$default")
  fi

  # Launch defaults
  echo ""
  gum style --foreground 111 --bold "  Launch Defaults"
  local use_worktree
  use_worktree=$(gum confirm "Worktree by default? (git isolation)" --default=yes && echo true || echo false)
  local use_split
  use_split=$(gum confirm "Tmux split by default? (Agent Teams)" --default=yes && echo true || echo false)
  local use_chrome
  use_chrome=$(gum confirm "Chrome MCP by default? (browser tools)" --default=yes && echo true || echo false)

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

  local has_starship
  has_starship=$(command -v starship &>/dev/null && echo true || echo false)
  local has_cship
  has_cship=$(command -v cship &>/dev/null && echo true || echo false)

  $has_starship && _setup_success "Starship prompt: installed" || _setup_info "Starship not installed"
  $has_cship && _setup_success "CShip status line: installed" || _setup_info "CShip not installed"

  # CC Status Line
  echo ""
  gum style --foreground 111 --bold "  Claude Code Status Line"
  local sl_type
  sl_type=$(printf 'cship — ATLAS branded status bar (recommended)\nstarship — Uses starship command\nscript — Custom bash script\nnone — Disable status line' | \
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
  local node_mem
  node_mem=$(printf '8192 — 8GB (current, recommended for Opus)\n4096 — 4GB (lighter)\n16384 — 16GB (for very large codebases)' | \
    gum choose --header "Node.js memory (MB):")
  node_mem="${node_mem%% *}"

  # Bash timeout
  local bash_timeout
  bash_timeout=$(printf '600000 — 10 min (current, recommended)\n300000 — 5 min (faster feedback)\n900000 — 15 min (complex builds)\n1800000 — 30 min (max)' | \
    gum choose --header "Default bash timeout (ms):")
  bash_timeout="${bash_timeout%% *}"

  # MCP timeout
  local mcp_timeout
  mcp_timeout=$(printf '60000 — 1 min (current)\n30000 — 30 sec (faster)\n120000 — 2 min (slow servers)' | \
    gum choose --header "MCP server timeout (ms):")
  mcp_timeout="${mcp_timeout%% *}"

  # Bash output limit
  local output_limit
  output_limit=$(printf '30000 — 30K lines (current)\n15000 — 15K lines (saves context)\n50000 — 50K lines (verbose builds)' | \
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
    while IFS= read -r marketplace_dir; do
      while IFS= read -r plugin_dir_inner; do
        local pname
        pname=$(basename "$plugin_dir_inner")
        local pver
        pver=$(ls -v "$plugin_dir_inner" 2>/dev/null | tail -1)
        [ -n "$pver" ] && _setup_success "${pname} v${pver}"
      done < <(find "$marketplace_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    done < <(find "$plugin_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  fi

  # ATLAS plugin check
  echo ""
  local atlas_ver
  atlas_ver=$(_atlas_plugin_version)
  if [ "$atlas_ver" != "?.?.?" ]; then
    local skill_count
    skill_count=$(find "${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/${atlas_ver}/skills" -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
    local agent_count
    agent_count=$(find "${HOME}/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/${atlas_ver}/agents" -name "AGENT.md" -maxdepth 2 2>/dev/null | wc -l | tr -d ' ')
    _setup_success "ATLAS plugin v${atlas_ver}: ${skill_count} skills, ${agent_count} agents"
  else
    _setup_warn "ATLAS plugin not found"
    _setup_info "Install in Claude Code: /plugin install atlas-admin@atlas-admin-marketplace"
  fi

  # ─── Domain Plugin Selection (SP-ECO v4) ─────────────────────
  _setup_plugins_domain

  # MCP servers
  echo ""
  gum style --foreground 111 --bold "  MCP Servers"
  _setup_info "MCP servers are configured per-project in .claude/settings.local.json"
  _setup_info "Common: playwright, context7, stitch, chrome-devtools"

  _setup_success "Plugin configuration complete"
}

# ─── Domain Plugin Selection (SP-ECO v4) ──────────────────────
_setup_plugins_domain() {
  echo ""
  gum style --foreground 214 --bold "  ═══ ATLAS Domain Plugins ═══"
  echo ""

  # Detect legacy monolithic plugin
  if [ -d "${HOME}/.claude/plugins/cache/atlas-admin-marketplace" ]; then
    _setup_warn "Legacy atlas-admin-marketplace detected"
    _setup_info "Migration required → scripts/migrate-marketplace.sh"
    echo ""
  fi

  # Show current domain plugin status
  local marketplace_dir="${HOME}/.claude/plugins/cache/atlas-marketplace"
  if [ -d "$marketplace_dir" ]; then
    local installed_count
    installed_count=$(find "$marketplace_dir" -maxdepth 1 -type d -name "atlas-*" 2>/dev/null | wc -l | tr -d ' ')
    _setup_info "Currently installed: ${installed_count}/6 domain plugins"
    while IFS= read -r d; do
      [ -d "$d" ] && _setup_success "  $(basename "$d")"
    done < <(find "$marketplace_dir" -mindepth 1 -maxdepth 1 -type d -name "atlas-*" 2>/dev/null)
  else
    _setup_info "No domain plugins installed yet"
  fi

  echo ""
  _setup_info "Available plugins:"
  _setup_info "  [core]         Memory, session, context, vault (REQUIRED)"
  _setup_info "  [dev]          Planning, TDD, debugging, code review, shipping"
  _setup_info "  [frontend]     UI design, browser automation, visual QA"
  _setup_info "  [infra]        Infrastructure, deploy, security, network"
  _setup_info "  [enterprise]   Governance, knowledge engine, agent teams"
  _setup_info "  [experiential] Episode capture, intuition, relationships"
  echo ""

  local DOMAINS=""

  if command -v gum &>/dev/null; then
    local choice
    choice=$(gum choose --header "Select a preset:" \
      "1) Developer (core + dev) — recommended for most devs" \
      "2) Full Stack (core + dev + frontend + infra)" \
      "3) Admin (all 6 plugins) — for Seb / lead engineer" \
      "4) Infra Only (core + infra)" \
      "5) Custom selection" \
      "6) Skip — keep current")
  else
    echo "  Presets:"
    echo "    1) Developer (core + dev)           — recommended for most devs"
    echo "    2) Full Stack (core + dev + frontend + infra)"
    echo "    3) Admin (all 6 plugins)            — for Seb / lead engineer"
    echo "    4) Infra Only (core + infra)"
    echo "    5) Custom selection"
    echo "    6) Skip — keep current"
    echo ""
    read -r "choice?  Select preset [1-6]: "
  fi

  case "$choice" in
    1*|*Developer*) DOMAINS="core dev" ;;
    2*|*Full*) DOMAINS="core dev frontend infra" ;;
    3*|*Admin*) DOMAINS="core dev frontend infra enterprise experiential" ;;
    4*|*Infra*) DOMAINS="core infra" ;;
    5*|*Custom*)
      # Interactive multi-select — core always included
      DOMAINS="core"
      for d in dev frontend infra enterprise experiential; do
        if command -v gum &>/dev/null; then
          gum confirm "Install atlas-${d}?" && DOMAINS="$DOMAINS $d"
        else
          read -r "yn?  Install atlas-${d}? [y/N]: "
          [ "$yn" = "y" ] && DOMAINS="$DOMAINS $d"
        fi
      done
      ;;
    6*|*Skip*) _setup_info "Keeping current plugin configuration"; return 0 ;;
    *) _setup_info "No selection — skipping domain plugins"; return 0 ;;
  esac

  echo ""
  _setup_info "Installing: ${DOMAINS}"

  # Run migration script with selected domains
  local script_path="${PLUGIN_ROOT:-$(dirname "$(dirname "${BASH_SOURCE[0]:-$0}")")}/scripts/migrate-marketplace.sh"
  if [ -f "$script_path" ]; then
    ATLAS_DOMAINS="$DOMAINS" bash "$script_path" --preset custom
  else
    _setup_warn "Migration script not found at ${script_path}"
    _setup_info "Run manually: ./scripts/migrate-marketplace.sh --preset dev"
  fi
}

# ═══════════════════════════════════════════════════════════════
# SECTION 10: USER CONFIG SYNC
# ═══════════════════════════════════════════════════════════════
_setup_sync() {
  _setup_header "User Config Sync"
  local synced=0

  # ─── 1. .zshrc ordering: direnv+zoxide must be AFTER atlas.sh source ───
  echo ""
  gum style --foreground 111 --bold "  1/4 — .zshrc ordering"
  if [ -f "${HOME}/.zshrc" ]; then
    local atlas_line direnv_line zoxide_line
    atlas_line=$(grep -n 'atlas/shell/atlas.sh' "${HOME}/.zshrc" 2>/dev/null | head -1 | cut -d: -f1)
    direnv_line=$(grep -n 'direnv hook' "${HOME}/.zshrc" 2>/dev/null | head -1 | cut -d: -f1)
    zoxide_line=$(grep -n 'zoxide init' "${HOME}/.zshrc" 2>/dev/null | head -1 | cut -d: -f1)

    local needs_fix=false
    [ -n "$direnv_line" ] && [ -n "$atlas_line" ] && [ "$direnv_line" -lt "$atlas_line" ] && needs_fix=true
    [ -n "$zoxide_line" ] && [ -n "$atlas_line" ] && [ "$zoxide_line" -lt "$atlas_line" ] && needs_fix=true

    if $needs_fix; then
      _setup_info "direnv/zoxide are BEFORE atlas.sh source — they must be LAST"
      _setup_info "atlas.sh: line ${atlas_line}, direnv: line ${direnv_line:-N/A}, zoxide: line ${zoxide_line:-N/A}"
      if gum confirm "Fix ordering? (backup + move direnv/zoxide to end)" 2>/dev/null; then
        cp "${HOME}/.zshrc" "${HOME}/.zshrc.atlas-backup.$(date +%s)"
        # Use Python for safe TOML-like block manipulation
        python3 -c "
import re, os
with open(os.path.expanduser('~/.zshrc'), 'r') as f:
    lines = f.readlines()
# Find and extract direnv+zoxide blocks (including surrounding comments)
direnv_block = []
zoxide_block = []
other_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    # Detect direnv block (comment + if + eval + fi)
    if 'direnv' in line and ('hook' in line or 'MUST be LAST' in line.lower()):
        block = []
        # Look back for section comment
        while other_lines and (other_lines[-1].startswith('#') or other_lines[-1].strip() == ''):
            if 'direnv' in other_lines[-1].lower() or 'zoxide' in other_lines[-1].lower() or other_lines[-1].strip() == '':
                block.insert(0, other_lines.pop())
            else:
                break
        block.append(line)
        i += 1
        # Grab the rest of the if block
        while i < len(lines) and not (lines[i].strip() == 'fi' and 'direnv' not in lines[i]):
            block.append(lines[i])
            i += 1
            if i > 0 and lines[i-1].strip() == 'fi':
                break
        direnv_block = block
        continue
    # Detect zoxide block
    elif 'zoxide' in line and ('init' in line or 'smart cd' in line.lower()):
        block = []
        while other_lines and (other_lines[-1].startswith('#') or other_lines[-1].strip() == ''):
            if 'zoxide' in other_lines[-1].lower() or other_lines[-1].strip() == '':
                block.insert(0, other_lines.pop())
            else:
                break
        block.append(line)
        i += 1
        while i < len(lines) and not (lines[i].strip() == 'fi' and 'zoxide' not in lines[i]):
            block.append(lines[i])
            i += 1
            if i > 0 and lines[i-1].strip() == 'fi':
                break
        zoxide_block = block
        continue
    else:
        other_lines.append(line)
    i += 1
# Rebuild: other lines + blank + comment + direnv + zoxide
result = other_lines
if result and result[-1].strip():
    result.append('\n')
result.append('# direnv + zoxide — MUST be LAST (after all PATH changes and plugin sources)\n')
result.extend(direnv_block)
result.extend(zoxide_block)
with open(os.path.expanduser('~/.zshrc'), 'w') as f:
    f.writelines(result)
print('OK')
" 2>/dev/null && synced=$((synced + 1)) && _setup_success ".zshrc ordering fixed" || \
          gum style --foreground 196 "  ✗ Failed to fix .zshrc ordering"
      fi
    else
      _setup_success ".zshrc ordering OK"
    fi
  else
    _setup_info "~/.zshrc not found — skipping"
  fi

  # ─── 2. Starship custom modules ───
  echo ""
  gum style --foreground 111 --bold "  2/4 — Starship ATLAS modules"
  local starship_cfg="${HOME}/.config/starship.toml"
  local starship_fragment="${HOME}/.atlas/shell/starship-atlas-fragment.toml"
  if [ -f "$starship_cfg" ]; then
    if ! grep -q 'custom.atlas_version' "$starship_cfg" 2>/dev/null; then
      if [ -f "$starship_fragment" ]; then
        _setup_info "ATLAS custom modules missing from starship.toml"
        echo ""
        gum style --foreground 245 "$(cat "$starship_fragment" | head -20)"
        echo ""
        if gum confirm "Append ATLAS modules to starship.toml?" 2>/dev/null; then
          cp "$starship_cfg" "${starship_cfg}.atlas-backup.$(date +%s)"
          echo "" >> "$starship_cfg"
          echo "# ─── ATLAS Plugin Custom Modules (managed by atlas setup sync) ───" >> "$starship_cfg"
          cat "$starship_fragment" >> "$starship_cfg"
          synced=$((synced + 1))
          _setup_success "Starship ATLAS modules added"
        fi
      else
        _setup_info "Starship fragment not deployed yet — start a CC session first"
      fi
    else
      _setup_success "Starship ATLAS modules present"
    fi
  else
    _setup_info "~/.config/starship.toml not found — skipping"
  fi

  # ─── 3. CShip config sync ───
  echo ""
  gum style --foreground 111 --bold "  3/4 — CShip config"
  local cship_cfg="${HOME}/.config/cship.toml"
  local cship_src="${HOME}/.atlas/shell/cship.toml"
  if [ -f "$cship_src" ]; then
    if [ ! -f "$cship_cfg" ] || ! diff -q "$cship_src" "$cship_cfg" &>/dev/null; then
      _setup_info "CShip config outdated or missing"
      if [ -f "$cship_cfg" ]; then
        diff --color "$cship_cfg" "$cship_src" 2>/dev/null | head -30 || true
      fi
      echo ""
      if gum confirm "Update cship.toml from plugin?" 2>/dev/null; then
        [ -f "$cship_cfg" ] && cp "$cship_cfg" "${cship_cfg}.atlas-backup.$(date +%s)"
        mkdir -p "${HOME}/.config"
        cp "$cship_src" "$cship_cfg"
        synced=$((synced + 1))
        _setup_success "CShip config updated"
      fi
    else
      _setup_success "CShip config in sync"
    fi
  else
    _setup_info "CShip source not deployed yet — start a CC session first"
  fi

  # ─── 4. Statusline scripts ───
  echo ""
  gum style --foreground 111 --bold "  4/4 — Statusline scripts"
  local sl_dir="${HOME}/.local/share/atlas-statusline"
  local sl_src="${HOME}/.atlas/shell"
  local sl_synced=0
  for mod in atlas-resolve-version.sh atlas-alert-module.sh atlas-context-size-module.sh; do
    if [ -f "${sl_src}/${mod}" ]; then
      if [ ! -f "${sl_dir}/${mod}" ] || ! diff -q "${sl_src}/${mod}" "${sl_dir}/${mod}" &>/dev/null; then
        mkdir -p "$sl_dir"
        cp "${sl_src}/${mod}" "${sl_dir}/${mod}"
        chmod +x "${sl_dir}/${mod}"
        sl_synced=$((sl_synced + 1))
      fi
    fi
  done
  if [ $sl_synced -gt 0 ]; then
    synced=$((synced + sl_synced))
    _setup_success "${sl_synced} statusline script(s) updated"
  else
    _setup_success "Statusline scripts in sync"
  fi

  # ─── Summary ───
  echo ""
  if [ $synced -gt 0 ]; then
    gum style --foreground 46 --bold "  ✓ ${synced} item(s) synced"
    gum style --foreground 214 "  → Run: source ~/.zshrc"
  else
    gum style --foreground 46 --bold "  ✓ Everything in sync — no changes needed"
  fi
}

# ═══════════════════════════════════════════════════════════════
# 11. HOOKS HEALTH CHECK
# ═══════════════════════════════════════════════════════════════
_setup_hooks() {
  _setup_section_header "🪝 Hooks Health Check"

  local settings="$HOME/.claude/settings.json"
  local issues=0
  local fixed=0

  # Check 1: settings.json should NOT contain hooks block
  _setup_info "Checking settings.json hooks isolation..."
  if [ -f "$settings" ]; then
    local has_hooks
    has_hooks=$(python3 -c "import json; d=json.load(open('$settings')); print('yes' if 'hooks' in d else 'no')" 2>/dev/null)
    if [ "$has_hooks" = "yes" ]; then
      gum style --foreground 196 "  ✗ settings.json contains hooks block — should be in plugin hooks.json only"
      local hook_count
      hook_count=$(python3 -c "import json; d=json.load(open('$settings')); print(len(d.get('hooks',{})))" 2>/dev/null)
      gum style --foreground 214 "    Found $hook_count event types in settings.json (these duplicate plugin hooks)"
      issues=$((issues + 1))

      if gum confirm "Remove hooks block from settings.json? (plugin hooks.json is the SSoT)"; then
        python3 -c "
import json
with open('$settings') as f:
    d = json.load(f)
d.pop('hooks', None)
with open('$settings', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
print('Removed hooks block')
" 2>/dev/null
        gum style --foreground 46 "  ✓ Hooks block removed from settings.json"
        fixed=$((fixed + 1))
      fi
    else
      gum style --foreground 46 "  ✓ settings.json clean (no hooks block)"
    fi
  else
    gum style --foreground 214 "  ⚠ settings.json not found"
    issues=$((issues + 1))
  fi

  # Check 2: Plugin cache has hooks.json
  _setup_info "Checking plugin hooks.json..."
  local plugin_cache="$HOME/.claude/plugins/cache/atlas-admin-marketplace"
  local found_hooks=0
  while IFS= read -r tier_dir; do
    [ -d "$tier_dir" ] || continue
    # Find the version directory
    while IFS= read -r ver_dir; do
      [ -d "$ver_dir" ] || continue
      if [ -f "$ver_dir/hooks/hooks.json" ]; then
        local tier_name
        tier_name=$(basename "$tier_dir")
        local event_count
        event_count=$(python3 -c "import json; d=json.load(open('$ver_dir/hooks/hooks.json')); print(len(d.get('hooks',{})))" 2>/dev/null)
        local hook_count
        hook_count=$(python3 -c "
import json
d=json.load(open('$ver_dir/hooks/hooks.json'))
total=sum(len(h) for entries in d.get('hooks',{}).values() for e in entries for h in [e.get('hooks',[])])
print(total)
" 2>/dev/null)
        gum style --foreground 46 "  ✓ $tier_name: $event_count events, $hook_count handlers"
        found_hooks=1
      fi
      break
    done < <(find "$tier_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  done < <(find "$plugin_cache" -mindepth 1 -maxdepth 1 -type d -name "atlas-*" 2>/dev/null)
  if [ $found_hooks -eq 0 ]; then
    gum style --foreground 196 "  ✗ No plugin hooks.json found in cache"
    issues=$((issues + 1))
  fi

  # Check 3: Stale local hook scripts
  _setup_info "Checking for stale local hooks..."
  local stale=0
  while IFS= read -r script; do
    [ -f "$script" ] || continue
    local name
    name=$(basename "$script" .sh)
    # Check if this hook exists in the plugin (use find for cross-shell safety)
    local first_match
    first_match=$(find "$plugin_cache/atlas-admin/" -mindepth 2 -maxdepth 2 -name "$name" -type f 2>/dev/null | head -1)
    if [ -n "$first_match" ] && [ -f "$first_match" ]; then
      gum style --foreground 214 "  ⚠ Stale: $name.sh (exists in plugin as $name)"
      stale=$((stale + 1))
    fi
  done < <(find "$HOME/.claude/hooks" -mindepth 1 -maxdepth 1 -type f -name "*.sh" 2>/dev/null)
  if [ $stale -gt 0 ]; then
    gum style --foreground 214 "  $stale stale local hook(s) found (duplicated by plugin)"
    issues=$((issues + stale))
  else
    gum style --foreground 46 "  ✓ No stale local hooks"
  fi

  # Summary
  echo ""
  if [ $issues -eq 0 ]; then
    gum style --foreground 46 --bold "  ✓ Hooks health: CLEAN ($fixed fixed)"
  else
    local remaining
    remaining=$((issues - fixed))
    gum style --foreground 214 --bold "  ⚠ Hooks health: $remaining issue(s) remaining"
  fi
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
    domains)     _setup_plugins_domain; _atlas_footer; return ;;
    sync)        _setup_sync; _atlas_footer; return ;;
    hooks)       _setup_hooks; _atlas_footer; return ;;
    all)         _setup_run_all; _atlas_footer; return ;;
    cc)          _setup_run_cc; _atlas_footer; return ;;
    terminal)    _setup_run_terminal; _atlas_footer; return ;;
    proj)        _setup_projects; _atlas_footer; return ;;
  esac

  # Interactive section picker
  echo ""
  local choice
  choice=$(printf '🚀 Quick Setup (Identity + Model + Projects)\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n🤖 CLAUDE CODE\n  👤 1. Identity — Forgejo/vault auto-detect\n  🧠 2. AI Model — model, effort, thinking budget\n  🔒 3. Permissions — presets, auto mode\n  🔑 5. Secrets — Vaultwarden, keyring, tokens\n🐚 TERMINAL\n  🐚 4. Shell — zsh plugins, tools, completion\n📁 PROJECTS\n  📁 6. Projects — workspace, defaults, worktree\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n⚙️  ADVANCED\n  📊 7. Status Line — Starship, CShip\n  ⚡ 8. Performance — memory, timeouts\n  🧩 9. Plugins — CC plugins, MCP\n  🔄 10. Sync — User config sync (zshrc, starship, cship)\n  🪝 11. Hooks — Health check, conflict detection\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n🌟 Full Setup (all sections)' | \
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
    *"10. Sync"*)     _setup_sync ;;
    *"11. Hooks"*)    _setup_hooks ;;
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
  _setup_hooks
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
