---
name: atlas-onboarding
description: "Guided setup wizard for new ATLAS users. 5-phase onboarding: profile creation, credential validation, environment checks, project context, optional integrations. Use when 'setup', 'configure', 'onboard', 'first time', or 'getting started'."
effort: high
---

# ATLAS Onboarding Wizard

Interactive 5-phase setup for new users or environment reconfiguration. Each phase uses AskUserQuestion for HITL approval.

## Storage

- **Profile**: `~/.atlas/profile.json` — SSoT for onboarding state
- **State**: `~/.atlas/onboarding-state.json` — progress if interrupted

Create storage on first run:
```bash
mkdir -p ~/.atlas
```

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas setup` | Full 5-phase wizard |
| `/atlas setup profile` | Phase 1 only |
| `/atlas setup credentials` | Phase 2 only |
| `/atlas setup environment` | Phase 3 only |
| `/atlas setup context` | Phase 4 only |
| `/atlas setup optional` | Phase 5 only |
| `/atlas setup status` | Show completion status |

## Phase 1: 👤 Profile

Gather user identity via AskUserQuestion:

**Question 1** — Role:
```
header: "Role"
options: ["I&C Engineer", "Electrical Engineer", "Project Manager", "Software Developer", "Admin/DevOps"]
```

**Question 2** — Expertise (multi-select):
```
header: "Expertise"
multiSelect: true
options: ["I&C", "Electrical", "Mechanical", "Process", "Software", "DevOps", "Mining/Resources"]
```

**Question 3** — Language:
```
header: "Language"
options: ["Français (Recommended)", "English"]
```

**Question 4** — Default model:
```
header: "Model"
options: [
  "Opus 4.6 (Recommended) — deep reasoning, architecture, plans",
  "Sonnet 4.6 — fast, 98% coding quality, lower cost"
]
```

After collecting answers, ask for name and team via free-form AskUserQuestion.

Write `~/.atlas/profile.json`:
```bash
cat > ~/.atlas/profile.json <<EOF
{
  "version": 1,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": {
    "name": "{name}",
    "role": "{role}",
    "team": "{team}",
    "expertise": [{expertise}],
    "preferences": { "language": "{lang}", "model": "{model}" }
  },
  "onboarding": {
    "phases_completed": ["profile"]
  }
}
EOF
```

## Phase 2: 🔑 Credentials

Check each token via bash, then present results:

```bash
# Config helper — read from ~/.atlas/config.json with fallback
atlas_config() {
  local key="$1" fallback="${2:-}"
  python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.atlas/config.json')) as f:
        d = json.load(f)
    keys = '$key'.split('.')
    v = d
    for k in keys: v = v[k]
    if isinstance(v, list): print(' '.join(v))
    else: print(v)
except: print('$fallback')
" 2>/dev/null || echo "$fallback"
}

# Check existence + API validity
SYNAPSE_URL=$(atlas_config "services.synapse.url" "http://localhost:8001")
SYNAPSE_OK="❌"
[ -n "${SYNAPSE_TOKEN:-}" ] && curl -sf -m 3 -H "Authorization: Bearer $SYNAPSE_TOKEN" "${SYNAPSE_URL}/api/v1/health" >/dev/null 2>&1 && SYNAPSE_OK="✅"

FORGEJO_OK="❌"
FORGEJO_URL=$(atlas_config "services.forgejo.local_url" "")
FORGEJO_API_PATH=$(atlas_config "services.forgejo.api_path" "/api/v1")
[ -n "${FORGEJO_TOKEN:-}" ] && [ -n "$FORGEJO_URL" ] && \
  curl -sf -m 3 -H "Authorization: token $FORGEJO_TOKEN" "${FORGEJO_URL}${FORGEJO_API_PATH}/user" >/dev/null 2>&1 && FORGEJO_OK="✅"

AUTHENTIK_OK="⏭️ optional"
AUTHENTIK_URL_CFG=$(atlas_config "services.authentik.url" "")
[ -n "${AUTHENTIK_TOKEN:-}" ] && [ -n "$AUTHENTIK_URL_CFG" ] && \
  curl -sf -m 3 -H "Authorization: Bearer $AUTHENTIK_TOKEN" "${AUTHENTIK_URL:-$AUTHENTIK_URL_CFG}/api/v3/core/users/me/" >/dev/null 2>&1 && AUTHENTIK_OK="✅"

GEMINI_OK="❌"
[ -n "${GEMINI_API_KEY:-}" ] && GEMINI_OK="✅"
```

Present as table:
```
| Token          | Status | Purpose                              |
|----------------|--------|--------------------------------------|
| SYNAPSE_TOKEN  | {status} | Backend API (profile, knowledge, notes) |
| FORGEJO_TOKEN  | {status} | Git hosting (PRs, CI, deploy)          |
| AUTHENTIK_TOKEN| {status} | SSO role detection (optional)          |
| GEMINI_API_KEY | {status} | AI model access (optional)             |
```

For each ❌ token:
1. Explain what it's for and why it matters
2. Show generation instructions:
   - SYNAPSE_TOKEN: "In Synapse → Admin → API Tokens → Create"
   - FORGEJO_TOKEN: "In Forgejo → Settings → Applications → Generate Token"
   - AUTHENTIK_TOKEN: "In Authentik → Admin → Tokens → Create API Token"
3. Ask user: "Add to ~/.env: `export TOKEN_NAME=xxx` then `source ~/.env`"
4. NEVER store the token value — only validate and record true/false

Update `~/.atlas/profile.json` credentials section.

## Phase 3: 🔧 Environment

Auto-detect via bash (no user input needed for most):

```bash
# OS
OS_NAME=$(uname -s)
OS_VERSION=$(uname -r)
HOSTNAME=$(hostname -s)
SHELL_NAME=$(basename "$SHELL")

# Tools
declare -A TOOLS=(
  [bash]="$(command -v bash 2>/dev/null && echo ✅ || echo ❌)"
  [yq]="$(command -v yq 2>/dev/null && echo ✅ || echo ❌)"
  [python3]="$(command -v python3 2>/dev/null && echo ✅ || echo ❌)"
  [bun]="$(command -v bun 2>/dev/null && echo ✅ || echo ❌)"
  [docker]="$(command -v docker 2>/dev/null && echo ✅ || echo ❌)"
  [git]="$(command -v git 2>/dev/null && echo ✅ || echo ❌)"
  [jq]="$(command -v jq 2>/dev/null && echo ✅ || echo ❌)"
  [curl]="$(command -v curl 2>/dev/null && echo ✅ || echo ❌)"
)
```

Present table. For missing tools, offer installation commands:
- yq: `sudo snap install yq` (Ubuntu) or `brew install yq` (macOS)
- bun: `curl -fsSL https://bun.sh/install | bash`
- jq: `sudo apt install jq` or `brew install jq`

AskUserQuestion for each missing tool: "Install {tool}?"

## Phase 3.5: 🖥️ Terminal & Aliases

Auto-detect platform:
```bash
PLATFORM_JSON=$("${PLUGIN_ROOT}/scripts/detect-platform.sh" 2>/dev/null || echo '{}')
```

Present detected info as table:
```
| Property     | Value                    |
|--------------|--------------------------|
| OS           | {os} {os_version}        |
| Architecture | {arch}                   |
| Shell        | {shell}                  |
| Terminal     | {terminal}               |
| Hostname     | {hostname}               |
```

Platform-specific notes:
- **WSL**: Warn about Docker Desktop integration, path differences
- **macOS**: Note Homebrew for tool installation, no snap
- **Linux**: Standard flow
- **Windows (MSYS/Cygwin)**: Experimental, recommend WSL

Check if ATLAS aliases exist:
```bash
RC_FILE="${HOME}/.$(basename $SHELL)rc"
grep -q "atlas()" "$RC_FILE" 2>/dev/null
```

If aliases missing → AskUserQuestion:
```
"ATLAS terminal aliases not found in your shell config.
 These give you quick session launchers:
 - atlas [topic] → CC session in atlas repo
 - atlas-synapse [topic] → CC session in synapse repo
 - atlas-w / atlas-synapse-w → worktree variants

 Install aliases to {RC_FILE}?"
 Options: ["Yes, install aliases", "No, I'll configure manually"]
```

If approved:
```bash
${PLUGIN_ROOT}/scripts/shell-aliases.sh ${ATLAS_ROOT:-$HOME/workspace_atlas} >> "$RC_FILE"
```
Remind user: `source ~/.zshrc` (or restart terminal) to activate.

Also check `ATLAS_ROOT` env var:
```bash
grep -q "ATLAS_ROOT" "$RC_FILE" 2>/dev/null
```
If missing → suggest adding: `export ATLAS_ROOT=$HOME/workspace_atlas`

## Phase 3.6: ⌨️ Shell Completions & DX Tools

Run the terminal setup check:
```bash
${PLUGIN_ROOT}/scripts/setup-terminal.sh --check
```

This checks 12 items: completions, aliases, prompt, fuzzy finder, autosuggestions,
syntax highlighting, smart cd, diff viewer, bat, direnv, ATLAS_ROOT.

If score < 12 → AskUserQuestion:
```
"Terminal DX check: {score}/12. Missing items detected.
 Install shell completions + recommended tools?"
 Options: ["Yes, install everything", "Just completions", "Skip"]
```

If approved → run:
```bash
${PLUGIN_ROOT}/scripts/setup-terminal.sh --install
```

Recommended DX tools (platform-aware installation):
| Tool | Purpose | Linux (apt) | macOS (brew) |
|------|---------|-------------|--------------|
| fzf | Ctrl+R history, Ctrl+T files | `apt install fzf` | `brew install fzf` |
| bat | Syntax highlighted cat | `apt install bat` | `brew install bat` |
| zoxide | Frecency-based cd | `apt install zoxide` | `brew install zoxide` |
| delta | Pretty git diffs | `apt install git-delta` | `brew install git-delta` |
| fd | Fast file finder | `apt install fd-find` | `brew install fd` |
| direnv | Auto-load .envrc | `apt install direnv` | `brew install direnv` |
| jq | JSON processor | `apt install jq` | `brew install jq` |

For zsh users, also check oh-my-zsh plugins:
- `zsh-autosuggestions` — fish-like autosuggestions
- `zsh-syntax-highlighting` — command syntax coloring

## Phase 4: 📄 Project Context

Check current project directory:

```bash
[ -f CLAUDE.md ]                    # Project CLAUDE.md
[ -d .claude/rules ]                # Rules directory
[ -d .blueprint ]                   # Blueprint directory
[ -f .blueprint/FEATURES.md ]       # Feature registry
```

For each gap, AskUserQuestion:
- Missing CLAUDE.md → "Generate from project scan? (uses W3H format, ~100 lines)"
- Missing .claude/rules/ → "Create basic rules (code-quality, testing)?"
- Missing .blueprint/ → "Create blueprint structure (INDEX.md, plans/)?"

If approved, invoke the relevant generation:
- CLAUDE.md: scan package.json/requirements.txt/docker-compose, generate W3H template
- Rules: extract conventions from existing code patterns
- Blueprint: create minimal directory structure

## Phase 5: 📊 StatusLine & CC Settings

### 5A: StatusLine Deployment

Check if CShip + Starship are configured:
```bash
CSHIP_OK=$(command -v cship &>/dev/null && echo "✅" || echo "❌")
STARSHIP_OK=$(command -v starship &>/dev/null && echo "✅" || echo "❌")
SCRIPTS_OK=$([ -x "${HOME}/.local/share/atlas-statusline/atlas-starship-module.sh" ] && echo "✅" || echo "❌")
```

Present status table:
```
| Component         | Status | Detail                     |
|-------------------|--------|----------------------------|
| CShip binary      | {ok}   | Rust-based status renderer |
| Starship prompt   | {ok}   | Terminal prompt framework   |
| ATLAS scripts     | {ok}   | Module scripts deployed     |
| settings.json     | {ok}   | statusLine.command wired    |
```

If any ❌ → AskUserQuestion:
```
"StatusLine gives you a rich ATLAS dashboard in your terminal:
 Row 1: plugin version, model, branch
 Row 2: tier, Docker, CI, features
 Row 3: context usage bar

 Set up StatusLine now?"
 Options: ["Yes, full setup", "Skip for now"]
```

If yes → invoke `statusline-setup` skill (7-step interactive wizard with HITL gates).

### 5B: CC Settings Validation

Check Claude Code global + project settings:
```bash
GLOBAL="${HOME}/.claude/settings.json"
PROJECT=".claude/settings.json"
```

Required global settings:
| Setting | Check | Auto-fix |
|---------|-------|----------|
| `permissions.allow` includes Bash,Read,Write,Edit,Skill(*) | parse JSON | Add missing perms |
| `language` set | check key exists | Add `"language": "francais"` |
| `hooks.UserPromptSubmit` exists | check key | Copy from ATLAS template |
| `hooks.PreToolUse` exists | check key | Copy validate-bash.sh |
| `showClearContextOnPlanAccept` = true | check key+value | Set to `true` |
| Global commands `~/.claude/commands/a-*.md` | count files | Warn if missing |
| `~/.claude/CLAUDE.md` exists | file check | Generate from template |

Required project settings:
| Setting | Check | Auto-fix |
|---------|-------|----------|
| ATLAS plugin enabled | check enabledPlugins | Add entry |
| `env.CLAUDE_CODE_MAX_OUTPUT_TOKENS` | check key | Add default "128000" |
| `env.CLAUDE_CODE_SPAWN_BACKEND` = "tmux" | check value | Set to "tmux" |
| `plansDirectory` = ".blueprint/plans" | check value | Set it |

For each issue: AskUserQuestion with before/after preview.
NEVER auto-modify settings without HITL approval.

### 5C: MCP Servers

Check `.mcp.json` for required servers:
```bash
MCP_FILE=".mcp.json"
[ -f "$MCP_FILE" ] || echo "No .mcp.json found"
```

Required MCP servers:
| Server | Required? | Check |
|--------|-----------|-------|
| context7 | ✅ Yes | Key in mcpServers |
| playwright | ✅ Yes (dev+) | Key in mcpServers |
| figma | ⚠️ Optional | Key in mcpServers |
| claude-in-chrome | ⚠️ Optional | --chrome flag support |

For missing required servers → AskUserQuestion to add config entry.

## Phase 6: ⚙️ Optional Integrations

AskUserQuestion with multi-select:

```
header: "Optional"
multiSelect: true
options:
  - "Forgejo SSH — Git SSH access verification"
  - "Headscale/Tailscale — mesh networking"
  - "Coder workspace — remote dev environment"
  - "Ollama local models — offline AI (qwen2.5, deepseek-r1)"
```

For each selected:
- Forgejo SSH → verify `~/.ssh/config` has Forgejo host entry
- Headscale → run `tailscale status` and report
- Coder → check `coder agents` status
- Ollama → check local Ollama API: `curl http://localhost:11434/api/tags` and show available models

## Completion

After all phases (or skipped phases), write final profile:
```bash
# Update onboarding state
python3 -c "
import json
with open('$HOME/.atlas/profile.json') as f: p = json.load(f)
p['onboarding']['completed_at'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
p['onboarding']['phases_completed'] = ['profile','credentials','environment','terminal','context','statusline','optional']
with open('$HOME/.atlas/profile.json','w') as f: json.dump(p, f, indent=2)
"
```

Display completion message:
```
🏛️ ATLAS │ ✅ ONBOARDING COMPLETE
   └─ Profile: ~/.atlas/profile.json
   └─ Run /atlas doctor to verify full system health
```
