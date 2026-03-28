---
name: atlas-workspace-setup
description: "Configure multi-session development workspace: tmux, split-screen, Agent Teams, session-spawn. Use when 'workspace setup', 'setup tmux', 'configure split screen', 'agent teams setup', 'multi-session', or new machine onboarding."
effort: medium
model: sonnet
---

# Workspace Setup — Multi-Session Development Environment

Configure tmux split-screen, Agent Teams, and session orchestration for parallel Claude Code workflows.

**Triggers**: `/atlas workspace-setup`, `setup tmux`, `configure split screen`, `agent teams setup`, `multi-session setup`

## Subcommands

```
/atlas workspace-setup              # Full setup wizard (all steps)
/atlas workspace-setup tmux         # Install + configure tmux only
/atlas workspace-setup teams        # Enable Agent Teams only
/atlas workspace-setup verify       # Verify everything works
/atlas workspace-setup status       # Show current config status
```

## Pipeline

```
DETECT → INSTALL → CONFIGURE → VERIFY → REPORT
```

## Phase 1: DETECT

Check current environment state:

```bash
# 1. OS detection
uname -s  # Linux or Darwin

# 2. tmux installed?
command -v tmux && tmux -V

# 3. Claude Code version
claude --version  # Need >= 2.1.49 for worktrees, >= 2.1.76 for -n flag

# 4. Current tmux config
cat ~/.tmux.conf 2>/dev/null || echo "No config"

# 5. Agent Teams env
grep AGENT_TEAMS .claude/settings.json 2>/dev/null

# 6. Session spawn config
cat .atlas/sessions.yaml 2>/dev/null || echo "No config"

# 7. Terminal emulator
echo $TERM_PROGRAM  # iTerm2, vscode, etc.
```

Present results as status table via AskUserQuestion.

## Phase 2: INSTALL

### tmux (if missing)

```bash
# Linux (Ubuntu/Debian)
sudo apt install -y tmux

# macOS
brew install tmux

# Verify
tmux -V  # Should be >= 3.0
```

### .tmux.conf (ATLAS optimized)

Write `~/.tmux.conf` with:

```conf
# ATLAS tmux config — Multi-Agent Development
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g history-limit 50000
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g escape-time 10
set -g focus-events on
set -g renumber-windows on

# Mouse Scroll Speed (1 line per tick — default 3 is too fast)
bind -T copy-mode-vi WheelUpPane send-keys -X scroll-up
bind -T copy-mode-vi WheelDownPane send-keys -X scroll-down
bind -T root WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'copy-mode -et='"

# Status Bar (Synapse navy/gold)
set -g status-style 'bg=#1B3A5C fg=#E4C200'
set -g status-left '#[fg=#1B3A5C,bg=#E4C200,bold] #S #[default] '
set -g status-right '#[fg=#E4C200] %H:%M #[default]'
set -g status-left-length 30

# Pane Borders
set -g pane-border-style 'fg=#555555'
set -g pane-active-border-style 'fg=#E4C200'
set -g pane-border-lines heavy

# Easy Split Bindings
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# Quick Pane Navigation (Alt+Arrow, no prefix)
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Pane Resize (Prefix + Shift+Arrow)
bind -r S-Left resize-pane -L 5
bind -r S-Right resize-pane -R 5
bind -r S-Up resize-pane -U 3
bind -r S-Down resize-pane -D 3

# ATLAS Layouts
bind A split-window -h -c "#{pane_current_path}" \; \
     send-keys -t 1 "claude -n 'worker'" Enter
bind T split-window -h -c "#{pane_current_path}" \; \
     split-window -v -c "#{pane_current_path}" \; \
     select-pane -t 0 \; \
     split-window -v -c "#{pane_current_path}"
```

**HITL gate**: Show diff if `.tmux.conf` already exists. Ask before overwriting.

## Phase 3: CONFIGURE

### 3a. Agent Teams in settings.json

Add to project `.claude/settings.json` `env` block:

```json
{
  "env": {
    "CLAUDE_CODE_SPAWN_BACKEND": "tmux",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Check**: Read existing settings.json first. Merge, don't overwrite.

### 3b. Session Spawn Config

Create `.atlas/sessions.yaml`:

```yaml
max_sessions: 5
default_worktree: true
startup_delay: 6
auto_continue_on_end: false
tmux_prefix: "atlas-"
```

### 3c. Shell Aliases (optional)

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# ATLAS multi-session aliases
alias atlas-split='tmux new-session -s atlas \; split-window -h'
alias atlas-team='tmux new-session -s atlas \; split-window -h \; split-window -v \; select-pane -t 0 \; split-window -v'
alias cs='claude'
alias csw='claude -w'
alias cst='claude --tmux'
```

**HITL gate**: Ask before modifying shell RC files.

## Phase 4: VERIFY

Run automated verification:

```bash
# 1. tmux installed + version
tmux -V  # >= 3.0

# 2. .tmux.conf has ATLAS config
grep "ATLAS tmux" ~/.tmux.conf

# 3. Agent Teams enabled
grep AGENT_TEAMS .claude/settings.json

# 4. Spawn backend = tmux
grep SPAWN_BACKEND .claude/settings.json

# 5. sessions.yaml exists
cat .atlas/sessions.yaml

# 6. Spawn test (non-destructive)
tmux new-session -d -s verify-atlas
tmux split-window -h -t verify-atlas
tmux send-keys -t verify-atlas:0.0 "echo PANE_0_OK" Enter
tmux send-keys -t verify-atlas:0.1 "echo PANE_1_OK" Enter
sleep 2
PANE0=$(tmux capture-pane -t verify-atlas:0.0 -p | grep PANE_0_OK)
PANE1=$(tmux capture-pane -t verify-atlas:0.1 -p | grep PANE_1_OK)
tmux kill-session -t verify-atlas
[ -n "$PANE0" ] && [ -n "$PANE1" ] && echo "SPLIT TEST PASS" || echo "SPLIT TEST FAIL"
```

## Phase 5: REPORT

Present final status:

```
ATLAS Workspace Setup — Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| Component          | Status | Detail                |
|--------------------|--------|-----------------------|
| tmux               | ✅/❌  | v3.5a installed       |
| .tmux.conf         | ✅/❌  | ATLAS config applied  |
| Agent Teams        | ✅/❌  | Env var in settings   |
| Spawn Backend      | ✅/❌  | tmux configured       |
| sessions.yaml      | ✅/❌  | Defaults created      |
| Shell aliases      | ✅/⏭️  | Added / skipped       |
| Split-screen test  | ✅/❌  | 2-pane spawn works    |

Quick Reference:
  Prefix + |    Split horizontal
  Prefix + -    Split vertical
  Alt + Arrow   Switch pane (no prefix)
  Prefix + A    ATLAS 2-pane layout
  Prefix + T    ATLAS 4-pane team layout
```

## Gotchas

- `--tmux` flag requires `-w` (worktree). They're coupled.
- `--tmux` needs attached tmux client (not detached `-d`)
- Agent Teams is experimental — may change in future CC versions
- Max 5 CC sessions = ~5-10 GB RAM. Monitor with `free -h`.
- Explore-type agents can't SendMessage — use `general-purpose` for teammates
- Task list scope resets per TeamCreate (separate from main session)

## Integration

- **atlas-onboarding Phase 5.5** calls `/atlas workspace-setup verify`
- **atlas-doctor Cat 9** (Terminal) checks tmux + .tmux.conf
- **session-spawn** uses `sessions.yaml` for defaults
