# ATLAS Plugin -- Deployment Guide

> Step-by-step deployment for **any platform** (Linux, macOS, Windows, WSL2).
>
> Updated: 2026-04-07

---

## Table of Contents

1. [What You Get](#1-what-you-get)
2. [Prerequisites](#2-prerequisites)
3. [Install the Claude Code Plugin](#3-install-the-claude-code-plugin)
4. [Install the ATLAS CLI](#4-install-the-atlas-cli)
5. [Configuration](#5-configuration)
6. [Verification](#6-verification)
7. [Updating](#7-updating)
8. [Troubleshooting](#8-troubleshooting)
9. [Uninstalling](#9-uninstalling)
10. [Developer Setup (From Source)](#10-developer-setup-from-source)

---

## 1. What You Get

| Component | Description |
|-----------|-------------|
| **Claude Code Plugin** | 72+ skills, 15 agents, 50+ hooks injected into every CC session |
| **ATLAS CLI** | `atlas` shell command for launching CC with worktrees, tmux splits, topics |
| **Hooks** | Session management, code quality gates, safety validators, statusline |
| **Skills** | TDD, planning, debugging, code review, deploy, infrastructure, research |

### Install Options

| Option | What | Best For |
|--------|------|----------|
| **Monolith** (`atlas-admin`) | All 72 skills + all hooks in 1 plugin | Simple setup, full experience |
| **Modular** (`atlas-core` + pick domains) | Foundation + domain-specific skills | Lighter install, pick what you need |

**Recommendation**: Start with the **monolith** (`atlas-admin`). Switch to modular later if needed.

---

## 2. Prerequisites

### All Platforms

| Requirement | Why | Install |
|-------------|-----|---------|
| **Claude Code** (v2.1.80+) | The AI CLI tool | See per-platform below |
| **Git** | Plugin distribution is git-based | See per-platform below |
| **Python 3.8+** | Hooks use Python for JSON processing | See per-platform below |
| **GitHub account** | Plugin is on a private GitHub repo | [github.com](https://github.com) |
| **GITHUB_TOKEN** | Access to the private plugin repo | [Create PAT](https://github.com/settings/tokens) |

### Optional (Enhanced Experience)

| Tool | Why | Without It |
|------|-----|------------|
| **Bun** | Runs TypeScript hooks (13 hooks) | TS hooks silently skipped |
| **tmux** | Split-screen sessions via `atlas -s` | No split mode, CC still works |
| **gum** | Pretty CLI menus in `atlas setup` | Falls back to basic text mode |
| **fzf** | Fuzzy search in `atlas` subcommands | Falls back to basic selection |

---

### Linux (Ubuntu/Debian)

```bash
# 1. Claude Code
curl -fsSL https://claude.ai/install.sh | sh

# 2. Python 3 (usually pre-installed)
sudo apt install -y python3

# 3. Optional: Bun (for TS hooks)
curl -fsSL https://bun.sh/install | bash

# 4. Optional: tmux + gum
sudo apt install -y tmux
# gum: https://github.com/charmbracelet/gum#installation
```

### macOS

```bash
# 1. Claude Code
brew install claude-code
# OR: curl -fsSL https://claude.ai/install.sh | sh

# 2. Python 3 (usually pre-installed with Xcode tools)
python3 --version  # verify

# 3. Optional: Bun + tmux + gum
brew install oven-sh/bun/bun tmux gum
```

### Windows (Native CLI)

```powershell
# 1. Git for Windows (REQUIRED FIRST)
# Download from https://gitforwindows.org or:
winget install Git.Git

# 2. Claude Code
irm https://claude.ai/install.ps1 | iex

# 3. Python 3
# Download from https://python.org or:
winget install Python.Python.3.13
# IMPORTANT: Check "Add to PATH" during install

# 4. Verify Git Bash path (CC uses this for hooks)
# If claude can't find bash, set this in ~/.claude/settings.json:
# { "env": { "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe" } }
```

### WSL2

```bash
# 1. Install WSL2 distro (from PowerShell as admin)
wsl --install -d Ubuntu

# 2. Inside WSL2, follow Linux steps above
curl -fsSL https://claude.ai/install.sh | sh
sudo apt install -y python3
```

---

## 3. Install the Claude Code Plugin

### Step 3.1: Configure GitHub Token

The plugin repo is **private**. You need a GitHub Personal Access Token.

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Create a **Fine-grained token** with:
   - Repository access: `seb155/atlas-plugin`
   - Permissions: `Contents: Read-only`
3. Set the token:

**Linux / macOS / WSL2**:
```bash
# Option A: Environment variable (recommended)
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc

# Option B: Claude Code settings
# Add to ~/.claude/settings.json:
# { "env": { "GITHUB_TOKEN": "ghp_your_token_here" } }
```

**Windows (PowerShell)**:
```powershell
# Option A: System environment variable (persists across reboots)
[Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "ghp_your_token_here", "User")

# Option B: Claude Code settings
# Add to %USERPROFILE%\.claude\settings.json:
# { "env": { "GITHUB_TOKEN": "ghp_your_token_here" } }
```

### Step 3.2: Add the ATLAS Marketplace

Open a terminal and run Claude Code:

```bash
claude
```

Inside Claude Code, run:

```
/plugin marketplace add seb155/atlas-plugin
```

Claude Code will clone the marketplace manifest and discover 7 available plugins.

### Step 3.3: Install the Plugin

**Monolith (recommended)**:
```
/plugin install atlas-admin@atlas-admin-marketplace
```

**Modular (pick what you need)**:
```
/plugin install atlas-core@atlas-admin-marketplace           # Required: foundation
/plugin install atlas-dev@atlas-admin-marketplace            # Optional: TDD, planning, debugging
/plugin install atlas-frontend@atlas-admin-marketplace       # Optional: UI/UX, browser automation
/plugin install atlas-infra@atlas-admin-marketplace          # Optional: infrastructure ops
/plugin install atlas-enterprise@atlas-admin-marketplace     # Optional: governance, teams
```

### Step 3.4: Restart Claude Code

Exit and restart Claude Code. You should see the ATLAS banner:

```
🏛️ ATLAS │ ✅ SESSION │ v4.26.3 admin
🏛️ ATLAS │ 🧩 72 skills | 🤖 15 agents
```

If you see this banner, the plugin is loaded and working.

---

## 4. Install the ATLAS CLI

The ATLAS CLI adds the `atlas` command to your shell for launching Claude Code sessions with
worktrees, tmux splits, topics, and more. This step is **optional** but recommended.

### Linux / macOS / WSL2

```bash
# 1. Clone the plugin repo (reuses your GITHUB_TOKEN)
git clone https://github.com/seb155/atlas-plugin.git ~/.atlas/plugin

# 2. Deploy CLI scripts
mkdir -p ~/.atlas/shell/modules
cp ~/.atlas/plugin/scripts/atlas-cli.sh ~/.atlas/shell/atlas.sh
cp ~/.atlas/plugin/scripts/atlas-modules/*.sh ~/.atlas/shell/modules/

# 3. Source in your shell profile
# For zsh:
echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> ~/.zshrc
source ~/.zshrc

# For bash:
echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> ~/.bashrc
source ~/.bashrc
```

### Windows (Git Bash)

Open **Git Bash** (installed with Git for Windows):

```bash
# 1. Clone the plugin repo
git clone https://github.com/seb155/atlas-plugin.git ~/.atlas/plugin

# 2. Deploy CLI scripts
mkdir -p ~/.atlas/shell/modules
cp ~/.atlas/plugin/scripts/atlas-cli.sh ~/.atlas/shell/atlas.sh
cp ~/.atlas/plugin/scripts/atlas-modules/*.sh ~/.atlas/shell/modules/

# 3. Source in Git Bash profile
echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> ~/.bashrc
source ~/.bashrc
```

### Verify CLI

```bash
atlas version    # Should print the version number
atlas help       # Should list available commands
atlas doctor     # Should run health checks
```

---

## 5. Configuration

### 5.1 ATLAS Config File (Optional)

Create `~/.atlas/config.json` to customize behavior:

```json
{
  "launcher": {
    "workspace_root": "~/projects",
    "worktree": true,
    "split": true,
    "effort": "max",
    "chrome": false
  }
}
```

| Key | Default | Description |
|-----|---------|-------------|
| `workspace_root` | `~/workspace_atlas` | Root directory for project discovery |
| `worktree` | `true` | Auto-create git worktree per session |
| `split` | `true` | Auto-split tmux pane for parallel work |
| `effort` | `max` | Default reasoning effort (`low`, `medium`, `high`, `max`) |
| `chrome` | `true` | Launch with Chrome MCP browser automation |

### 5.2 Homelab Integration (Optional)

If you have access to the AXOIQ homelab infrastructure, add:

```json
{
  "launcher": { "..." : "..." },
  "infrastructure": {
    "forgejo_api": "http://192.168.10.75:3000/api/v1",
    "forgejo_url": "https://forgejo.axoiq.com"
  },
  "secrets": {
    "provider": "vaultwarden"
  }
}
```

Without this section, all homelab features are **silently skipped** -- no errors.

### 5.3 Status Line (CShip)

ATLAS uses [CShip](https://cship.dev) for a rich 3-row status line in Claude Code showing model, context %, git status, rate limits, and alerts.

#### Linux / macOS

```bash
# Option A: Official installer (recommended — downloads pre-compiled binary)
curl -fsSL https://cship.dev/install.sh | bash

# Option B: Cargo (requires Rust toolchain)
cargo install cship

# Install jq (required for CShip custom modules)
sudo apt install -y jq   # Debian/Ubuntu
brew install jq           # macOS
```

#### Windows (Git Bash)

```bash
# 1. Install jq (required)
winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements

# 2. Install Starship (optional, for shell prompt outside CC)
winget install --id Starship.Starship --accept-source-agreements --accept-package-agreements

# 3. Install CShip (use PowerShell installer — NOT cargo)
powershell.exe -NoProfile -Command "irm https://cship.dev/install.ps1 | iex"
```

> **Why not `cargo install cship` on Windows?** Git Bash's `/usr/bin/link` shadows MSVC's
> `link.exe` linker, causing compilation to fail with "extra operand" errors. The PowerShell
> installer downloads a pre-compiled `cship-x86_64-pc-windows-msvc.exe` binary directly.

#### Deploy ATLAS CShip Config

```bash
# Copy the ATLAS v5 layout config (3 rows: model+git, context bar, alerts)
cp ~/.atlas/plugin/scripts/cship-atlas.toml ~/.config/cship.toml

# Deploy statusline helper scripts
mkdir -p ~/.local/share/atlas-statusline/
cp ~/.atlas/plugin/scripts/atlas-alert-module.sh ~/.local/share/atlas-statusline/
cp ~/.atlas/plugin/scripts/atlas-context-size-module.sh ~/.local/share/atlas-statusline/
cp ~/.atlas/plugin/scripts/atlas-resolve-version.sh ~/.local/share/atlas-statusline/
chmod +x ~/.local/share/atlas-statusline/*.sh
```

#### Windows PATH Setup

Winget installs tools to non-standard locations. Add to `~/.bashrc`:

```bash
# CShip binary
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# jq (winget package directory)
_jq_dir=$(find "$HOME/AppData/Local/Microsoft/WinGet/Packages" -maxdepth 1 -name "jqlang.jq*" -type d 2>/dev/null | head -1)
[ -n "$_jq_dir" ] && export PATH="$_jq_dir:$PATH"
unset _jq_dir

# Starship (MSI installs to Program Files)
[ -d "/c/Program Files/starship/bin" ] && export PATH="/c/Program Files/starship/bin:$PATH"
```

#### Verify

```bash
# Should render 3-row ATLAS status line with ANSI colors
echo '{"model":{"id":"claude-opus-4-6","display_name":"Opus"},"context_window":{"used_percentage":42}}' | cship
```

Restart Claude Code for the new status line to take effect.

### 5.4 Claude Code Settings (Windows-specific)

If hooks fail on Windows, verify Git Bash is accessible:

```json
// ~/.claude/settings.json (or %USERPROFILE%\.claude\settings.json)
{
  "env": {
    "GITHUB_TOKEN": "ghp_your_token_here",
    "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe"
  }
}
```

### 5.4 Shell Profile (ATLAS_ROLE)

Override the detected tier/role by setting an environment variable:

```bash
# In ~/.bashrc or ~/.zshrc
export ATLAS_ROLE="admin"    # admin | dev | user
```

---

## 6. Verification

Run these checks after installation to confirm everything works:

### 6.1 Plugin Check

```bash
claude
# Expected: ATLAS banner appears at session start
# 🏛️ ATLAS │ ✅ SESSION │ v4.26.3 admin
```

### 6.2 Skill Check

Inside Claude Code:
```
/atlas doctor
# Expected: Health check runs, shows system status
# Items requiring homelab access will show as "skip" (not "error")
```

### 6.3 CLI Check

```bash
atlas version          # Expected: 4.26.3
atlas help             # Expected: Command list
atlas -w my-feature    # Expected: Launches CC in a git worktree (if git repo)
```

### 6.4 Platform-Specific Checks

| Check | Command | Expected |
|-------|---------|----------|
| Python 3 available | `python3 --version` or `python --version` | `Python 3.x.x` |
| Git available | `git --version` | `git version 2.x.x` |
| Plugin cache exists | `ls ~/.claude/plugins/cache/atlas-admin-marketplace/` | Plugin directories |
| CLI loaded | `type atlas` | `atlas is a shell function` |
| Hooks work | Start `claude`, check for timestamp in first response | `📅 2026-...` timestamp |

---

## 7. Updating

### Plugin Updates

Claude Code auto-updates plugins in the background. To force an update:

```
# Inside Claude Code:
/plugin update atlas-admin@atlas-admin-marketplace
```

### CLI Updates

```bash
cd ~/.atlas/plugin && git pull
cp scripts/atlas-cli.sh ~/.atlas/shell/atlas.sh
cp scripts/atlas-modules/*.sh ~/.atlas/shell/modules/
source ~/.bashrc  # or ~/.zshrc
```

### Check Current Version

```bash
atlas version                                    # CLI version
cat ~/.claude/plugins/cache/atlas-admin-marketplace/atlas-admin/*/VERSION  # Plugin version
```

---

## 8. Troubleshooting

### No ATLAS Banner at Session Start

| Symptom | Cause | Fix |
|---------|-------|-----|
| No banner at all | Plugin not installed | Run `/plugin install atlas-admin@atlas-admin-marketplace` |
| `command not found: python3` | Python 3 not in PATH | Install Python 3, or alias `python` to `python3` |
| Hook timeout errors | Network call hanging | Set `ATLAS_NO_VERSION_CHECK=1` in env |

### Plugin Install Fails

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Authentication failed` | GITHUB_TOKEN missing or expired | Create new token, set in env |
| `Repository not found` | Token doesn't have repo access | Create fine-grained token for `seb155/atlas-plugin` |
| `git: command not found` | Git not installed | Install Git for your platform |

### Hooks Failing on Windows

| Symptom | Cause | Fix |
|---------|-------|-----|
| All hooks fail | Git Bash not found by CC | Set `CLAUDE_CODE_GIT_BASH_PATH` in settings.json |
| TS hooks fail | Bun not installed | Install Bun, or ignore (TS hooks are optional) |
| `python3: command not found` | Windows uses `python` not `python3` | Install Python 3 and add to PATH |
| `stat: invalid option -- 'c'` | macOS uses BSD stat | Update to latest plugin version (fixed) |

### Status Line (CShip) Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `cargo install cship` fails with `link.exe` errors | Git Bash `link` shadows MSVC linker | Use PowerShell installer: `irm cship.dev/install.ps1 \| iex` |
| Starship install cancelled (error 1602) | UAC elevation was declined | Re-run `winget install Starship.Starship` and accept the UAC prompt |
| `jq: command not found` after winget install | PATH not refreshed in current shell | Add winget package dir to `~/.bashrc` (see section 5.3) |
| Empty status line in CC | CShip not in PATH or not configured | Verify `~/.claude/settings.json` has `statusLine.command: "cship"` |
| Status line shows raw ANSI codes | Terminal doesn't support ANSI | Use Windows Terminal (not cmd.exe) |

### CLI Not Working

| Symptom | Cause | Fix |
|---------|-------|-----|
| `atlas: command not found` | Shell profile not sourced | Add source line to `.bashrc` or `.zshrc` |
| `atlas: command not found` (Windows) | Using PowerShell instead of Git Bash | Use Git Bash, or add to `.bashrc` |
| `atlas -s` does nothing | tmux not installed | Install tmux (Linux/macOS/WSL2 only) |
| `atlas -w` fails | Not in a git repository | Run from inside a git repo |

### Performance

| Symptom | Cause | Fix |
|---------|-------|-----|
| Session start slow (>5s) | Version check timing out | Set `ATLAS_NO_VERSION_CHECK=1` |
| Many hook warnings | Optional tools missing | Install Bun for TS hooks, or ignore warnings |

---

## 9. Uninstalling

### Remove Plugin

Inside Claude Code:
```
/plugin uninstall atlas-admin@atlas-admin-marketplace
```

### Remove CLI

```bash
# 1. Remove CLI files
rm -rf ~/.atlas/shell ~/.atlas/plugin

# 2. Remove source line from shell profile
# Edit ~/.bashrc or ~/.zshrc and remove the atlas.sh source line

# 3. Remove config (optional)
rm -f ~/.atlas/config.json
```

### Remove Everything

```bash
rm -rf ~/.atlas
rm -rf ~/.claude/plugins/cache/atlas-admin-marketplace
rm -f ~/.claude/session-state.json
rm -f ~/.claude/atlas-audit.log
```

---

## 10. Developer Setup (From Source)

For contributors developing the ATLAS plugin itself:

### Prerequisites

- Everything from [Section 2](#2-prerequisites)
- **Bun** (required for build + tests)
- **yq** (YAML processor, required for build)
- **make** (GNU Make)

### Clone & Build

```bash
# Clone the source repo (Forgejo or GitHub)
git clone ssh://forgejo/axoiq/atlas-plugin.git ~/workspace_atlas/projects/atlas-dev-plugin
cd ~/workspace_atlas/projects/atlas-dev-plugin

# Install dependencies
bun install  # if package.json exists

# Build + install to Claude Code (all tiers)
make dev

# Build domain plugins
make dev-domains

# Run tests
make test

# Quick iteration (admin tier only)
make dev-admin
```

### Build Targets

| Target | What |
|--------|------|
| `make dev` | Build all 3 tiers + install to CC cache |
| `make dev-admin` | Build admin only (fast iteration) |
| `make dev-domains` | Build 6 domain plugins + install |
| `make test` | Run pytest suite (frontmatter, hooks, build) |
| `make lint` | Validate structure, cross-refs, coverage |
| `make publish-patch` | Bump patch version + build + test + tag + push |
| `make publish-minor` | Bump minor version + release |

### Dev Workflow

```
Edit skill/hook/agent → make dev-admin → launch claude → test → commit
```

### Release Workflow

```
make publish-patch
# Forgejo CI: build → test → package → upload to registry → mirror to GitHub
# GitHub mirror triggers CC auto-update for external users
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│  ATLAS Plugin Deployment -- Quick Reference             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  INSTALL PLUGIN:                                        │
│    /plugin marketplace add seb155/atlas-plugin          │
│    /plugin install atlas-admin@atlas-admin-marketplace  │
│                                                         │
│  INSTALL CLI:                                           │
│    git clone https://github.com/seb155/atlas-plugin     │
│       ~/.atlas/plugin                                   │
│    cp ~/.atlas/plugin/scripts/atlas-cli.sh              │
│       ~/.atlas/shell/atlas.sh                           │
│    cp ~/.atlas/plugin/scripts/atlas-modules/*.sh        │
│       ~/.atlas/shell/modules/                           │
│    echo 'source ~/.atlas/shell/atlas.sh' >> ~/.bashrc   │
│                                                         │
│  VERIFY:                                                │
│    claude        → ATLAS banner should appear           │
│    atlas version → version number                       │
│    atlas doctor  → health check                         │
│                                                         │
│  UPDATE:                                                │
│    /plugin update atlas-admin@atlas-admin-marketplace   │
│    cd ~/.atlas/plugin && git pull && cp scripts/...     │
│                                                         │
│  CONFIG:  ~/.atlas/config.json                          │
│  TOKENS:  GITHUB_TOKEN (required for private repo)      │
│  LOGS:    ~/.claude/atlas-audit.log                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```
