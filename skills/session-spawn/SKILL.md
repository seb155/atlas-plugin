---
name: session-spawn
description: "Session spawner with tmux and worktree isolation. This skill should be used when the user asks to '/atlas continue', '/atlas spawn', '/atlas sessions', 'new session', 'spawn fresh CC', or needs a handoff-driven isolated Claude Code child session."
effort: medium
---

# Session Spawn — CC Multi-Session Orchestrator

Launch fresh Claude Code sessions in visible tmux windows. Each uses your Max plan (no API key), gets its own worktree (file isolation), fully interactive.

## When to Use

- "continue fresh", "new session", "flush context", "restart fresh"
- "spawn", "parallel task", "separate window", "another CC"
- "sessions", "what's running", "list agents"
- Explicit `/atlas continue`
- Multi-task simultaneously
- After `/atlas end` or `/atlas handoff` — offer to auto-continue

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas continue` | Handoff current → spawn fresh CC → auto `/pickup` |
| `/atlas spawn "task"` | Spawn isolated CC with worktree → auto-type task |
| `/atlas sessions` | List active CC tmux windows with status |
| `/atlas kill [name]` | Close spawned session (HITL confirm) |

## Prerequisites

```bash
[ -n "$TMUX" ] || echo "ERROR: Not in tmux. Run inside tmux first."          # 1. tmux running
command -v claude >/dev/null || echo "ERROR: claude CLI not found"            # 2. CC available
tmux list-windows -F "#{window_name}" | grep -c "^atlas-" || true             # 3. Count atlas-* windows (max 5)
```

If not in tmux: suggest `tmux new-session -s atlas` then retry.

## /atlas continue — Fresh Session with Full Context

**Purpose**: Flush current context window, resume in clean session.

### Pipeline

```
HANDOFF → SPAWN → INJECT → EXIT
```

### Process

1. **Generate handoff** — Invoke `session-retrospective` to create `.claude/handoffs/{name}-{date}.md` (decisions, files modified, current task, next steps).

2. **Detect session name**:
   ```bash
   BRANCH=$(git branch --show-current)
   SESSION_NAME="atlas-fresh-${BRANCH##*/}"
   ```

3. **Check session limit** (max 5):
   ```bash
   ACTIVE=$(tmux list-windows -F "#{window_name}" 2>/dev/null | grep -c "^atlas-")
   if [ "$ACTIVE" -ge 5 ]; then
     echo "ERROR: Max 5 reached. Close one with /atlas kill [name]"
     exit 1
   fi
   ```

4. **Spawn new tmux window** with fresh CC (NO `-w` flag — same repo, fresh context):
   ```bash
   PROJECT_DIR=$(pwd)
   tmux new-window -n "$SESSION_NAME" "cd '$PROJECT_DIR' && claude -n '$SESSION_NAME'"
   ```
   The handoff provides continuity, not a separate branch.

5. **Auto-type pickup**:
   ```bash
   sleep 4  # CC startup + plugin load
   tmux send-keys -t "$SESSION_NAME" "/pickup" Enter
   ```

6. **Report**:
   ```
   ✅ Fresh session spawned: {SESSION_NAME}
   📋 Handoff: .claude/handoffs/{file}.md
   🔀 Switch: Ctrl-b n (next) or Ctrl-b p (previous)

   You can now /exit this session or keep it for reference.
   ```

### AskUserQuestion Gate

Before spawning: "Spawn fresh session and continue via /pickup?" → "Yes, continue fresh" / "Just handoff (no spawn)" / "Cancel".

## /atlas spawn "task" — Isolated Parallel Task

**Purpose**: Launch separate CC for independent task, isolated by git worktree.

### Pipeline

```
VALIDATE → WORKTREE → SPAWN → INJECT
```

### Process

1. **Parse task**: e.g., `/atlas spawn "run the full health check"` → task = "run the full health check", window = `atlas-health` (slugified first 2 words).

2. **Slug generation**:
   ```bash
   SLUG=$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | awk '{print $1"-"$2}' | head -c 20)
   WINDOW_NAME="atlas-${SLUG}"
   ```

3. **Check session limit** (same as continue — max 5)

4. **Spawn with worktree isolation** (`-w` creates isolated git worktree → files separate, no edit conflicts):
   ```bash
   PROJECT_DIR=$(pwd)
   tmux new-window -n "$WINDOW_NAME" "cd '$PROJECT_DIR' && claude -w '$WINDOW_NAME' -n '$WINDOW_NAME'"
   ```

5. **Auto-type task**:
   ```bash
   sleep 4
   ESCAPED_TASK=$(echo "$TASK" | sed "s/'/\\\\'/g")
   tmux send-keys -t "$WINDOW_NAME" "$ESCAPED_TASK" Enter
   ```

6. **Report**:
   ```
   ✅ Spawned: {WINDOW_NAME} (worktree isolated)
   📋 Task: {description}
   🌿 Branch: .claude/worktrees/{name}
   🔀 Switch: Ctrl-b n/p or Ctrl-b w (list)
   ```

### When to Use Spawn vs Continue vs Agent Teams

| Scenario | Use |
|----------|-----|
| Context exhausted, same task | `/atlas continue` |
| Unrelated parallel task | `/atlas spawn "task"` |
| Sub-tasks of SAME feature | Agent Teams (`claude --agent-teams`) |
| Long-running audit/test | `/atlas spawn "/atlas health"` |
| Exploration while coding | `/atlas spawn "research X pattern"` |

## /atlas sessions — List Active CC Windows

```bash
tmux list-windows -F "#{window_index}:#{window_name}:#{window_active}:#{pane_current_command}" 2>/dev/null
```

### Output Format

```
🏛️ ATLAS │ Active Sessions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| # | Window | Status | Worktree | Task |
|---|--------|--------|----------|------|
| 1 | atlas-fresh-dev | 🟢 Active | No (same repo) | /pickup — continuing SP-16 |
| 2 | atlas-health | 🟢 Active | Yes (.claude/worktrees/) | /atlas health full scan |
| 3 | atlas-tests | 🟡 Idle | Yes | pytest run complete |

📊 3/5 sessions active │ 2 slots available

💡 Commands:
  Ctrl-b n     → Next window
  Ctrl-b p     → Previous window
  Ctrl-b w     → List all
  Ctrl-b 2     → Jump to window #2
  /atlas kill health → Close health session
```

### Detection Logic

1. List tmux windows matching `atlas-*`
2. Check if process in pane is `claude` (running) or shell (idle/exited)
3. Detect current task from window name or last command

## /atlas kill [name] — Close a Spawned Session

1. **Find window** by name pattern
2. **Check uncommitted changes** in worktree:
   ```bash
   WORKTREE_PATH=$(git worktree list | grep "$WINDOW_NAME" | awk '{print $1}')
   [ -n "$WORKTREE_PATH" ] && cd "$WORKTREE_PATH" && git status --short
   ```
3. **AskUserQuestion** if changes exist: "Session {name} has uncommitted changes. What do?" → "Commit + merge to dev" / "Keep worktree (close window)" / "Discard all" / "Cancel"
4. **Close**: `tmux kill-window -t "$WINDOW_NAME"`
5. **Clean worktree** if discarding: `git worktree remove "$WORKTREE_PATH" --force`

## Integration with Existing Skills

### session-retrospective

When `/atlas end` invoked, AFTER retrospective:
```
🎯 Session complete. What next?
  1. Just exit (save handoff)
  2. → /atlas continue (fresh, auto-pickup)
  3. → /atlas spawn "next task"
```

### atlas-assist (main skill)

Add to "Red Flags":
| Thought | Reality |
|---------|---------|
| "Context getting long" | Use `/atlas continue` |
| "Need to work on something else too" | Use `/atlas spawn` |

### feature-board

After `/atlas board wip`, suggest:
```
💡 Tip: Use `/atlas spawn "fix FEAT-NNN"` to work on a feature in isolation.
```

## Agent Teams (When to Suggest)

CC-native for CONNECTED sub-tasks. Suggest when task involves multiple sub-tasks on SAME feature, FE+BE simultaneously, or test writing while implementing:

```
💡 This task has connected sub-tasks. Consider Agent Teams:
   Set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in settings.
   Claude coordinates lead + teammates with shared task list.

   Use /atlas spawn only for UNRELATED parallel work.
```

## Safety & Limits

### Session Limit: Max 5

Each CC session: ~1-2 GB RAM (node + context), API quota from Max plan, FS access (worktrees isolate). 5 concurrent = practical limit for dev laptop.

### Conflict Prevention

- `/atlas continue` = NO worktree (same repo, fresh context only)
- `/atlas spawn` = ALWAYS worktree (file isolation guaranteed)
- 2+ spawned: warn about merge conflicts when killing

### tmux Required

If not in tmux, MUST: explain why → suggest `tmux new-session -s atlas && claude` → NOT attempt spawn (fails silently).

### Session Resume

**CC v2.1.101**: `--resume <name>` accepts session titles set via `/rename` or `--name`, not just session IDs.

### Plan-Based (No API Key)

All spawned sessions use `claude` CLI authenticating via Max plan. No `ANTHROPIC_API_KEY`. No per-token billing.

## Configuration

Optional `.atlas/sessions.yaml`:

```yaml
max_sessions: 5
default_worktree: true        # Always -w for /atlas spawn
startup_delay: 4              # Seconds before send-keys
auto_continue_on_end: false   # Auto-suggest /atlas continue after /atlas end
tmux_prefix: "atlas-"         # Window name prefix
```

If no config: defaults above.
