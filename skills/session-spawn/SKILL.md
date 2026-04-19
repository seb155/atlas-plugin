---
name: session-spawn
description: "Session spawner with tmux and worktree isolation. This skill should be used when the user asks to '/atlas continue', '/atlas spawn', '/atlas sessions', 'new session', 'spawn fresh CC', or needs a handoff-driven isolated Claude Code child session."
effort: medium
---

# Session Spawn — CC Multi-Session Orchestrator

Launch fresh Claude Code sessions in visible tmux windows. Each session uses your
Max plan (no API key), gets its own worktree (file isolation), and is fully interactive.

## When to Use

- User says "continue fresh", "new session", "flush context", "restart fresh"
- User says "spawn", "parallel task", "separate window", "another CC"
- User says "sessions", "what's running", "list agents"
- User explicitly requests a fresh session or `/atlas continue`
- Need to work on multiple tasks simultaneously
- After `/atlas end` or `/atlas handoff` — offer to auto-continue

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas continue` | Handoff current context → spawn fresh CC → auto `/pickup` |
| `/atlas spawn "task"` | Spawn isolated CC with worktree → auto-type task |
| `/atlas sessions` | List active CC tmux windows with status |
| `/atlas kill [name]` | Close a spawned session (HITL confirm) |

---

## Prerequisites

Check BEFORE spawning:

```bash
# 1. tmux is running (we're inside a tmux session)
[ -n "$TMUX" ] || echo "ERROR: Not in tmux. Run inside tmux first."

# 2. claude CLI is available
command -v claude >/dev/null || echo "ERROR: claude CLI not found"

# 3. Count active CC windows (enforce max 5)
tmux list-windows -F "#{window_name}" | grep -c "^atlas-" || true
```

If not in tmux, suggest: `tmux new-session -s atlas` then retry.

---

## /atlas continue — Fresh Session with Full Context

**Purpose**: Flush the current context window and resume work in a clean session.

### Pipeline

```
HANDOFF → SPAWN → INJECT → EXIT
```

### Process

1. **Generate handoff** — Invoke `session-retrospective` skill to create handoff.md:
   ```
   .claude/handoffs/{name}-{date}.md
   ```
   Content: decisions made, files modified, current task, next steps.

2. **Detect session name** — Extract from current work:
   ```bash
   # Use branch name or plan name as session label
   BRANCH=$(git branch --show-current)
   SESSION_NAME="atlas-fresh-${BRANCH##*/}"
   ```

3. **Check session limit** — Count existing atlas-* tmux windows:
   ```bash
   ACTIVE=$(tmux list-windows -F "#{window_name}" 2>/dev/null | grep -c "^atlas-")
   if [ "$ACTIVE" -ge 5 ]; then
     echo "ERROR: Max 5 sessions reached. Close one with /atlas kill [name]"
     # Show active sessions and ask which to close
     exit 1
   fi
   ```

4. **Spawn new tmux window** with fresh CC:
   ```bash
   PROJECT_DIR=$(pwd)
   tmux new-window -n "$SESSION_NAME" \
     "cd '$PROJECT_DIR' && claude -n '$SESSION_NAME'"
   ```
   Note: NO `-w` flag here — we want the SAME repo, just fresh context.
   The handoff provides continuity, not a separate branch.

5. **Auto-type pickup** after CC starts:
   ```bash
   sleep 4  # Wait for CC startup + plugin load
   tmux send-keys -t "$SESSION_NAME" "/pickup" Enter
   ```

6. **Report to user** in current session:
   ```
   ✅ Fresh session spawned: {SESSION_NAME}
   📋 Handoff: .claude/handoffs/{file}.md
   🔀 Switch: Ctrl-b n (next) or Ctrl-b p (previous)

   You can now /exit this session or keep it for reference.
   ```

### AskUserQuestion Gate

Before spawning, confirm:
- "Spawn fresh session and continue via /pickup?"
- Options: "Yes, continue fresh", "Just handoff (no spawn)", "Cancel"

---

## /atlas spawn "task" — Isolated Parallel Task

**Purpose**: Launch a separate CC instance for an independent task, isolated by git worktree.

### Pipeline

```
VALIDATE → WORKTREE → SPAWN → INJECT
```

### Process

1. **Parse task description** from arguments:
   ```
   /atlas spawn "run the full health check"
   → task = "run the full health check"
   → window_name = "atlas-health"  (slugified first 2 words)
   ```

2. **Slug generation**:
   ```bash
   # "run the full health check" → "atlas-health-check"
   SLUG=$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | \
     sed 's/[^a-z0-9 ]//g' | awk '{print $1"-"$2}' | head -c 20)
   WINDOW_NAME="atlas-${SLUG}"
   ```

3. **Check session limit** (same as continue — max 5)

4. **Spawn with worktree isolation**:
   ```bash
   PROJECT_DIR=$(pwd)
   tmux new-window -n "$WINDOW_NAME" \
     "cd '$PROJECT_DIR' && claude -w '$WINDOW_NAME' -n '$WINDOW_NAME'"
   ```
   `-w` creates an isolated git worktree automatically.
   Files are separate — no edit conflicts with other sessions.

5. **Auto-type task** after CC starts:
   ```bash
   sleep 4
   # Escape quotes in task for tmux send-keys
   ESCAPED_TASK=$(echo "$TASK" | sed "s/'/\\\\'/g")
   tmux send-keys -t "$WINDOW_NAME" "$ESCAPED_TASK" Enter
   ```

6. **Report**:
   ```
   ✅ Spawned: {WINDOW_NAME} (worktree isolated)
   📋 Task: {task description}
   🌿 Branch: .claude/worktrees/{name}
   🔀 Switch: Ctrl-b n/p or Ctrl-b w (list)
   ```

### When to Use Spawn vs. Continue vs. Agent Teams

| Scenario | Use |
|----------|-----|
| Context exhausted, same task | `/atlas continue` |
| Unrelated parallel task | `/atlas spawn "task"` |
| Sub-tasks of SAME feature | Agent Teams (`claude --agent-teams`) |
| Long-running audit/test | `/atlas spawn "/atlas health"` |
| Exploration while coding | `/atlas spawn "research X pattern"` |

---

## /atlas sessions — List Active CC Windows

### Process

```bash
# List all tmux windows containing "atlas-" or running claude
tmux list-windows -F "#{window_index}:#{window_name}:#{window_active}:#{pane_current_command}" 2>/dev/null
```

### Output Format

```
🏛️ ATLAS │ Active Sessions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| # | Window | Status | Worktree | Task |
|---|--------|--------|----------|------|
| 1 | atlas-fresh-dev | 🟢 Active | No (same repo) | /pickup — continuing SP-16 |
| 2 | atlas-health | 🟢 Active | Yes (.claude/worktrees/) | /atlas health full scan |
| 3 | atlas-tests | 🟡 Idle | Yes | pytest run complete |

📊 3/5 sessions active │ 2 slots available

💡 Commands:
  Ctrl-b n     → Next window
  Ctrl-b p     → Previous window
  Ctrl-b w     → List all windows
  Ctrl-b 2     → Jump to window #2
  /atlas kill health → Close health session
```

### Detection Logic

1. List tmux windows matching `atlas-*` pattern
2. Check if process in pane is `claude` (running) or shell (idle/exited)
3. Try to detect current task from window name or last command

---

## /atlas kill [name] — Close a Spawned Session

### Process

1. **Find window** by name pattern
2. **Check for uncommitted changes** in worktree:
   ```bash
   WORKTREE_PATH=$(git worktree list | grep "$WINDOW_NAME" | awk '{print $1}')
   if [ -n "$WORKTREE_PATH" ]; then
     cd "$WORKTREE_PATH" && git status --short
   fi
   ```
3. **AskUserQuestion** if changes exist:
   - "Session {name} has uncommitted changes. What do?"
   - Options: "Commit + merge to dev", "Keep worktree (close window)", "Discard all", "Cancel"
4. **Close tmux window**:
   ```bash
   tmux kill-window -t "$WINDOW_NAME"
   ```
5. **Clean worktree** if discarding:
   ```bash
   git worktree remove "$WORKTREE_PATH" --force
   ```

---

## Integration with Existing Skills

### session-retrospective

When `/atlas end` is invoked, AFTER generating the retrospective:

```
🎯 Session complete. What next?
  1. Just exit (save handoff for later)
  2. → /atlas continue (fresh session, auto-pickup)  ← NEW
  3. → /atlas spawn "next task"                       ← NEW
```

### atlas-assist (main skill)

Add to the "Red Flags" section:

| Thought | Reality |
|---------|---------|
| "My context is getting long" | Use `/atlas continue` for a fresh session |
| "I need to work on something else too" | Use `/atlas spawn` for parallel task |

### feature-board

After `/atlas board wip` generates the WIP report, suggest:
```
💡 Tip: Use `/atlas spawn "fix FEAT-NNN"` to work on a feature in isolation.
```

---

## Agent Teams (When to Suggest)

Agent Teams is a CC-native feature for CONNECTED sub-tasks. The skill should
suggest it when appropriate instead of spawning separate windows:

### Detection Heuristic

If the user's task involves:
- Multiple sub-tasks on the SAME feature
- Frontend + Backend work simultaneously
- Test writing while implementing

Then suggest:
```
💡 This task has connected sub-tasks. Consider Agent Teams instead:
   Set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in your settings.
   Claude will coordinate lead + teammates with a shared task list.

   Use /atlas spawn only for UNRELATED parallel work.
```

---

## Safety & Limits

### Session Limit: Max 5

Each CC session consumes:
- ~1-2 GB RAM (node process + context)
- API quota from your Max plan
- File system access (but worktrees isolate)

5 concurrent sessions is the practical limit for a dev laptop.

### Conflict Prevention

- `/atlas continue` = NO worktree (same repo, fresh context only)
- `/atlas spawn` = ALWAYS worktree (file isolation guaranteed)
- If 2+ spawned sessions exist, warn about merge conflicts when killing

### tmux Required

If not in tmux, the skill MUST:
1. Explain why tmux is needed
2. Suggest: `tmux new-session -s atlas && claude`
3. NOT attempt to spawn (it will fail silently)

### Session Resume

**CC v2.1.101**: `--resume <name>` now accepts session titles set via `/rename` or `--name`, not just session IDs.

### Plan-Based (No API Key)

All spawned sessions use `claude` CLI which authenticates via your Max plan.
No `ANTHROPIC_API_KEY` needed. No per-token billing.

---

## Configuration

Optional `.atlas/sessions.yaml`:

```yaml
# Session spawn configuration
max_sessions: 5
default_worktree: true        # Always use -w for /atlas spawn
startup_delay: 4              # Seconds to wait before send-keys
auto_continue_on_end: false   # Auto-suggest /atlas continue after /atlas end
tmux_prefix: "atlas-"         # Window name prefix
```

If no config file, use defaults above.
