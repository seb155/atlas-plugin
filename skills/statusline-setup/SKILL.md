---
name: statusline-setup
description: "Status line configurator (CShip + Starship + ATLAS). This skill should be used when the user asks to 'setup statusline', 'configure cship', 'starship modules', '/atlas statusline', or installs the visual status line cross-platform."
effort: low
---

# ATLAS Status Line Setup

Interactive setup for the ATLAS-enhanced Claude Code status line using CShip (Rust) + Starship passthrough.

## Layout (v6 — v5.7.0+)

```
Row 1: 🏛️ ATLAS 5.7.0 👑admin  🟣 opus (1M)  📁 dir  🌿 git  🌳 wt  📋 session  🤖 2▶
Row 2: ████░░░░░ 21%  📊 high  💰 $0.24  📈 +42/-8  ⏱ 5h:2% | 7d:0%  ⚠️ 200K+ (cond)
Row 3: ⚠️ alerts (conditional — CI fail, context >75%, Docker down)
```

### Fields (v5.7.0 adoption — CC 2.1.x natives)

| Field | CShip var | JSON source | Added |
|-------|-----------|-------------|-------|
| Version | `$custom.atlas_version` | (script) | — |
| Tier | `$custom.atlas_tier` | session-state | — |
| Model | `$cship.model` | `model.id` | — |
| Context size | `$custom.atlas_context_size` | `context_window.size` | — |
| Directory | `$directory` | `workspace.current_dir` | — |
| Git branch | `$git_branch` + `$git_status` | filesystem | — |
| Worktree | `$cship.worktree` | `workspace.git_worktree` (v2.1.97) | — |
| Session | `$cship.session` | `session_name` | — |
| Agents | `$custom.atlas_agents` | agent tracking | v5.5 |
| Context bar | `$cship.context_bar` | `context_window.used_percentage` | — |
| **Effort** | `$custom.atlas_effort` | `effort` (v2.1.84) | **v5.7.0** |
| **Cost USD** | `$custom.atlas_cost_usd` | `cost.total_cost_usd` | **v5.7.0** |
| Lines diff | `$cship.cost.total_lines_{added,removed}` | cost fields | — |
| Rate limits | `$cship.usage_limits` | `rate_limits` (v2.1.80) | — |
| **200K badge** | `$custom.atlas_200k_badge` | `exceeds_200k_tokens` (v2.1.87) | **v5.7.0** |
| Alerts | `$custom.atlas_alert` | (script) | — |

### Auto-refresh

v5.7.0 sets `refresh_interval = 10` in `[cship]` section → rate limits and cost
update live every 10 seconds without requiring a keystroke.



## Setup Steps

### Step 1: Pre-flight Checks

Detect platform first, then run checks:

```bash
# Platform detection
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) _PLATFORM="windows" ;;
  Darwin)               _PLATFORM="macos" ;;
  *)                    _PLATFORM="linux" ;;
esac

# CShip installed?
command -v cship && cship help 2>&1 | head -1

# Starship installed?
command -v starship && starship --version

# jq installed?
command -v jq && jq --version

# Hostname
hostname -s 2>/dev/null || hostname

# Current statusline config
cat ~/.claude/settings.json | grep -A2 statusLine

# Session state file exists?
ls -la ${CLAUDE_PLUGIN_DATA:-$HOME/.claude}/session-state.json 2>/dev/null
```

Present results via AskUserQuestion. If CShip missing, proceed to Step 2. If present, skip to Step 3.

### Step 2: Install Dependencies + CShip

Platform-specific installation. Present options via AskUserQuestion with HITL gate.

#### Windows (Git Bash)

**jq** (required for CShip custom modules):
```bash
winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
```

**Starship** (optional, for prompt outside CC):
```bash
winget install --id Starship.Starship --accept-source-agreements --accept-package-agreements
```
> Note: MSI installer may show a UAC elevation prompt. User must accept it manually.

**CShip** (the status line binary):
```powershell
# Use the official PowerShell installer — downloads pre-compiled binary
# This avoids needing Rust/Cargo + MSVC Build Tools
powershell.exe -NoProfile -Command "irm https://cship.dev/install.ps1 | iex"
```
> Installs to `~/.local/bin/cship.exe`, writes default config to `~/.config/cship.toml`,
> and updates `~/.claude/settings.json` with `statusLine.command = "cship"`.

**IMPORTANT — Windows cargo compilation pitfall**: `cargo install cship` will likely FAIL
on Windows without Visual Studio Build Tools because Git Bash's `/usr/bin/link` shadows
MSVC's `link.exe` linker. The PowerShell installer downloads a pre-compiled binary instead.

#### macOS

```bash
# jq
brew install jq

# Starship (optional)
brew install starship

# CShip (via installer)
curl -fsSL https://cship.dev/install.sh | bash
# OR with Homebrew: brew install cship (if available)
# OR with cargo: cargo install cship
```

#### Linux

```bash
# jq
sudo apt install -y jq  # Debian/Ubuntu
# OR: sudo dnf install jq  # Fedora/RHEL

# Starship (optional)
curl -sS https://starship.rs/install.sh | sh

# CShip
curl -fsSL https://cship.dev/install.sh | bash
# OR: cargo install cship
```

Wait for user confirmation before installing.

### Step 3: Deploy Starship Module Scripts

```bash
# Create module directory
mkdir -p ~/.local/share/atlas-statusline/

# Copy scripts from plugin
PLUGIN_SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"
cp "$PLUGIN_SCRIPTS/atlas-alert-module.sh" ~/.local/share/atlas-statusline/
cp "$PLUGIN_SCRIPTS/atlas-context-size-module.sh" ~/.local/share/atlas-statusline/
cp "$PLUGIN_SCRIPTS/atlas-resolve-version.sh" ~/.local/share/atlas-statusline/
chmod +x ~/.local/share/atlas-statusline/*.sh
```

### Step 4: Configure Starship

Read existing `~/.config/starship.toml`. Append the `[custom.atlas]`, `[custom.atlas_alert]`, and `[custom.atlas_version]` sections from the fragment template.

**HITL gate**: Show the diff of what will be appended. Wait for user approval via AskUserQuestion before writing.

Fragment source: `${CLAUDE_PLUGIN_ROOT}/scripts/starship-atlas-fragment.toml`

### Step 5: Configure CShip

The CShip installer may have already written a default config. Deploy the ATLAS-specific layout:

```bash
mkdir -p ~/.config

if [ ! -f ~/.config/cship.toml ]; then
  # No config — deploy ATLAS v5 layout
  cp "${CLAUDE_PLUGIN_ROOT}/scripts/cship-atlas.toml" ~/.config/cship.toml
elif ! grep -q "ATLAS" ~/.config/cship.toml 2>/dev/null; then
  # Config exists but isn't ATLAS — HITL gate: ask before overwriting
  echo "Existing non-ATLAS cship.toml found"
fi
```

**HITL gate**: If existing config found, show merge preview via AskUserQuestion.

### Step 6: Update Claude Code settings.json

Change `statusLine.command` to point to `cship`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "cship"
  }
}
```

> Note: On Windows, the CShip PowerShell installer already does this automatically.
> Verify and correct if needed.

**HITL gate**: Show before/after via AskUserQuestion.

### Step 7: Configure Shell PATH (Windows only)

On Windows, newly installed tools may not be in the current shell's PATH. Add to `~/.bashrc`:

```bash
# CShip / Cargo binaries
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"

# jq (winget installs to a versioned package directory)
_jq_dir=$(find "$HOME/AppData/Local/Microsoft/WinGet/Packages" -maxdepth 1 -name "jqlang.jq*" -type d 2>/dev/null | head -1)
[ -n "$_jq_dir" ] && export PATH="$_jq_dir:$PATH"
unset _jq_dir

# Starship (winget MSI installs to Program Files)
[ -d "/c/Program Files/starship/bin" ] && export PATH="/c/Program Files/starship/bin:$PATH"
```

### Step 8: Verification

```bash
# Test tools
command -v cship && echo "CShip: OK"
command -v jq && echo "jq: $(jq --version)"
command -v starship && echo "Starship: $(starship --version 2>&1 | head -1)"

# Test CShip pipeline with mock data
echo '{"model":{"id":"claude-opus-4-7","display_name":"Opus"},"context_window":{"used_percentage":42,"remaining_percentage":58,"size":1000000},"cost":{"total_lines_added":42,"total_lines_removed":8,"total_cost_usd":0.05},"usage_limits":{"5h":{"used_percentage":12}}}' | cship

# Test CShip explain
cship explain

# Test statusline scripts
ls -la ~/.local/share/atlas-statusline/

# Verify settings.json
grep -A2 statusLine ~/.claude/settings.json
```

Present results via AskUserQuestion for visual confirmation.

## Platform Reference

| Step | Linux | macOS | Windows |
|------|-------|-------|---------|
| jq | `apt install jq` | `brew install jq` | `winget install jqlang.jq` |
| Starship | `curl starship.rs` | `brew install starship` | `winget install Starship.Starship` |
| CShip | `curl cship.dev` or `cargo install` | same | `irm cship.dev/install.ps1 \| iex` |
| Config path | `~/.config/cship.toml` | same | same (Git Bash `~`) |
| PATH setup | Not needed (system pkg) | Not needed (Homebrew) | Required in `~/.bashrc` |

## Troubleshooting

| Issue | Platform | Fix |
|-------|----------|-----|
| CShip not found | All | See install commands above per platform |
| `cargo install cship` fails with `link.exe` error | Windows | Use PowerShell installer instead: `irm cship.dev/install.ps1 \| iex` |
| Starship MSI cancelled (error 1602) | Windows | UAC prompt was declined — re-run and accept the elevation dialog |
| jq not found after winget install | Windows | Shell PATH not refreshed — add winget package dir to `~/.bashrc` PATH |
| Starship not found after winget install | Windows | Add `/c/Program Files/starship/bin` to PATH in `~/.bashrc` |
| Empty status line | All | Check `cship explain` for missing modules |
| No ATLAS row | All | Verify session-state.json exists |
| Stale data | All | Check atlas-status-writer hook in hooks.json |
| Stale version | All | Run: `~/.local/share/atlas-statusline/atlas-resolve-version.sh` to verify |
| VM 560 no Docker | Linux | Expected — Docker segment auto-hides |

## Uninstall

```bash
# Remove Starship custom modules
rm -rf ~/.local/share/atlas-statusline/
# Remove [custom.atlas*] sections from starship.toml
# Restore original statusLine config in settings.json
# Windows: remove CShip binary
rm -f ~/.local/bin/cship.exe  # Windows
rm -f ~/.local/bin/cship      # Linux/macOS
```
