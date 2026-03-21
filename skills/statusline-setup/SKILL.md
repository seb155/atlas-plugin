---
name: statusline-setup
description: "Configure CShip + Starship + ATLAS status line for Claude Code. Installs CShip binary, deploys Starship custom modules, wires settings.json. HITL at each step."
effort: low
---

# ATLAS Status Line Setup

Interactive setup for the ATLAS-enhanced Claude Code status line using CShip (Rust) + Starship passthrough.

## Layout

```
Row 1: 🏛️ ATLAS 3.2  🟣 opus  📁 atlas/synapse  🌿 dev !+
Row 2: 👑 admin  🐳 6/6  ✅ CI  🎯 7/13
Row 3: 📊 ███████░░░░░ 42%  📈 +42/-8
Row 4: ⚠️ alerts (conditional — CI fail, context >75%, Docker down)
```

## Setup Steps

### Step 1: Pre-flight Checks

Run these checks and report results:

```bash
# CShip installed?
which cship && cship --version

# Starship installed?
which starship && starship --version

# Hostname (laptop vs VM 560)
hostname -s

# jq installed?
which jq

# Current statusline config
cat ~/.claude/settings.json | jq '.statusLine'

# Session state file exists?
ls -la ${CLAUDE_PLUGIN_DATA:-$HOME/.claude}/session-state.json 2>/dev/null
```

Present results via AskUserQuestion. If CShip missing, proceed to Step 2. If present, skip to Step 3.

### Step 2: Install CShip (if missing)

Present options via AskUserQuestion:
- `cargo install cship` (if Rust toolchain available)
- `curl -fsSL https://cship.dev/install.sh | bash` (auto-installer)

Wait for user confirmation before installing.

### Step 3: Deploy Starship Module Scripts

```bash
# Create module directory
mkdir -p ~/.local/share/atlas-statusline/

# Copy scripts from plugin
PLUGIN_SCRIPTS="${CLAUDE_PLUGIN_ROOT}/scripts"
cp "$PLUGIN_SCRIPTS/atlas-starship-module.sh" ~/.local/share/atlas-statusline/
cp "$PLUGIN_SCRIPTS/atlas-alert-module.sh" ~/.local/share/atlas-statusline/
chmod +x ~/.local/share/atlas-statusline/*.sh
```

### Step 4: Configure Starship

Read existing `~/.config/starship.toml`. Append the `[custom.atlas]`, `[custom.atlas_alert]`, and `[custom.atlas_version]` sections from the fragment template.

**HITL gate**: Show the diff of what will be appended. Wait for user approval via AskUserQuestion before writing.

Fragment source: `${CLAUDE_PLUGIN_ROOT}/scripts/starship-atlas-fragment.toml`

### Step 5: Configure CShip

Copy or merge the CShip config template:

```bash
# If no existing config, copy template
if [ ! -f ~/.config/cship.toml ]; then
  mkdir -p ~/.config
  cp "${CLAUDE_PLUGIN_ROOT}/scripts/cship-atlas.toml" ~/.config/cship.toml
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

**HITL gate**: Show before/after via AskUserQuestion.

### Step 7: Verification

```bash
# Test session-state.json exists and is valid
cat ${CLAUDE_PLUGIN_DATA:-$HOME/.claude}/session-state.json | python3 -m json.tool

# Test Starship module
~/.local/share/atlas-statusline/atlas-starship-module.sh

# Test alert module (should be empty if no alerts)
~/.local/share/atlas-statusline/atlas-alert-module.sh

# Test CShip pipeline with mock data
echo '{"model":{"display_name":"Opus"},"context_window":{"used_percentage":42},"cost":{"total_lines_added":42,"total_lines_removed":8}}' | cship

# Explain CShip modules
cship explain
```

Present results via AskUserQuestion for visual confirmation.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| CShip not found | `cargo install cship` or curl installer |
| Starship not found | `curl -sS https://starship.rs/install.sh \| sh` |
| Empty status line | Check `cship explain` for missing modules |
| No ATLAS row | Verify session-state.json exists |
| Stale data | Check atlas-status-writer hook in hooks.json |
| VM 560 no Docker | Expected — Docker segment auto-hides |

## Uninstall

```bash
# Remove Starship custom modules
rm -rf ~/.local/share/atlas-statusline/
# Remove [custom.atlas*] sections from starship.toml
# Restore original statusLine config in settings.json
```
