# Phase 3: 🔧 Environment

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
