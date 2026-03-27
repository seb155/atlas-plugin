# ATLAS CLI Launcher — Operational Playbook

> Source: `scripts/atlas-cli.sh` → Installed: `~/.atlas/shell/atlas.sh`
> Updated: 2026-03-27

## Overview

The ATLAS CLI launcher is a shell function (`atlas()`) that wraps Claude Code with project discovery, tmux session management, and secret loading. It's sourced from `~/.zshrc` via `~/.atlas/shell/atlas.sh`.

## Session Lifecycle

```
┌─────────────┐    ┌──────────────────┐    ┌───────────────────┐
│ atlas <proj> │───▸│ resolve project  │───▸│ tmux split launch │
└─────────────┘    │ path + direnv    │    │ or inline mode    │
                   └──────────────────┘    └───────┬───────────┘
                                                   │
                                           ┌───────▼───────────┐
                                           │ claude session     │
                                           │ (CC REPL active)   │
                                           └───────┬───────────┘
                                                   │ /exit
                                           ┌───────▼───────────┐
                                           │ "; exit" closes    │
                                           │ tmux shell + pane  │
                                           └───────────────────┘
```

## tmux Integration — Key Design Decisions

### 1. Nested tmux detection (2026-03-27)

**Problem**: `atlas synapse` fails with "sessions should be nested with care" when already inside tmux.

**Solution** (line ~699):
```bash
if [ -n "$TMUX" ]; then
  # Inside tmux → create detached, switch to it
  tmux new-session -d -s "$name" -n "$project" -c "$path"
  tmux send-keys -t "$name" "$full_cmd" C-m
  tmux switch-client -t "$name"
else
  # Outside tmux → create + attach directly
  tmux new-session -s "$name" -n "$project" -c "$path" \; \
    send-keys "$full_cmd" C-m
fi
```

**Why**: `tmux new-session` creates AND attaches — impossible when already attached. `-d` creates detached, `switch-client` moves the current client to the new session without nesting.

### 2. Auto-close on /exit (2026-03-27)

**Problem**: After `/exit` in CC, the tmux session stays alive with an empty shell.

**Solution** (line ~697):
```bash
local full_cmd="${path_export} && ${cmd_str}; exit"
```

**Why**: `send-keys` runs `claude` inside a bash subshell. When `claude` exits, the shell continues. Appending `; exit` tells bash to exit after claude, which closes the tmux pane/session.

### 3. Collision handling — Attach (line ~671)

When a named session already exists and user picks "Attach":
```bash
if [ -n "$TMUX" ]; then
  tmux switch-client -t "$session_name"   # Inside tmux
else
  tmux attach-session -t "$session_name"  # Outside tmux
fi
```

Same nested-tmux principle as above.

## Modes

| Flag | Effect | Default |
|------|--------|---------|
| `-s` / `--split` | tmux session per project | `true` (config: `launcher.split`) |
| `-i` / `--inline` | No tmux, run in current shell | `false` |
| `-w` / `--worktree` | git worktree isolation | `false` |
| `-b` / `--bare` | Skip tmux + chrome + gum | `false` |
| `-y` / `--yolo` | Skip permissions | `false` |
| `-a` / `--auto` | Auto mode | `false` |
| `-c` / `--continue` | Resume last conversation | `false` |

## Install Pipeline

```
scripts/atlas-cli.sh  (source)
        ↓  make dev / dev-install.sh
~/.atlas/shell/atlas.sh  (installed)
        ↓  source ~/.zshrc
atlas() function available in shell
```

**Critical**: `make dev` now syncs the shell script automatically (added 2026-03-27). Previously, edits to `atlas-cli.sh` required manual copy.

## Key Functions

| Function | Purpose | Line |
|----------|---------|------|
| `atlas()` | Main entry point, arg parsing | ~698 |
| `_atlas_split_launch()` | tmux session creator | ~649 |
| `_atlas_interactive_menu()` | gum-based project selector | ~200 |
| `_atlas_resolve_project()` | Path resolution from name | ~300 |
| `_cc_session_name()` | Generate session name from repo+branch | ~500 |
| `_atlas_record_history()` | Usage tracking | ~550 |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "sessions should be nested with care" | Old launcher without `$TMUX` detection | `make dev && source ~/.zshrc` |
| tmux zombie after /exit | Missing `; exit` suffix | Same fix |
| "nothing selected" on `atlas` | No project arg, interactive menu cancelled | Normal behavior |
| Session name collision | Another CC running with same name | Choose "Attach", "Kill", or "Rename" |
| Shell not updated after make dev | Old dev-install.sh without shell sync | Update dev-install.sh |

## Testing Changes

```bash
# 1. Edit source
vim ~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-cli.sh

# 2. Build + install
cd ~/workspace_atlas/projects/atlas-dev-plugin && make dev

# 3. Reload shell
source ~/.zshrc

# 4. Test
atlas synapse   # Should work inside or outside tmux
```
