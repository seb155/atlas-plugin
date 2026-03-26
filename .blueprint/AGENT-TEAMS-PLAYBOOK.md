# Agent Teams & Tmux — Onboarding Playbook

> **Audience**: ATLAS admin-tier users | **Prereq**: CC v2.1.84+, tmux 3.x
> **Last validated**: 2026-03-26 (35/35 tests PASS on PC-S16)

## What Are Agent Teams?

Agent Teams let CC spawn **coordinated AI workers** that:
- Share a **task list** (TaskCreate/TaskUpdate visible to all)
- **Communicate** via SendMessage (bidirectional)
- Run in **visible tmux panes** (when SPAWN_BACKEND=tmux)
- **Shutdown gracefully** and clean up after themselves

## The 3 Execution Modes

```
┌──────────────────┬──────────────────┬───────────────────────────┐
│  IN-PROCESS      │  BACKGROUND      │  TMUX PANES              │
│  (default)       │  (run_in_bg)     │  (SPAWN_BACKEND=tmux)    │
├──────────────────┼──────────────────┼───────────────────────────┤
│  Invisible       │  Invisible       │  VISIBLE                 │
│  Blocks lead     │  Non-blocking    │  Non-blocking            │
│  Eats context    │  No live view    │  Live view + resizable   │
│  No communication│  One-way result  │  Bidirectional messages  │
└──────────────────┴──────────────────┴───────────────────────────┘
```

**Tmux panes** = the only mode where you see agents working in real time.

## Solo Agents vs Agent Teams

```
SOLO (Agent tool, no team_name):
  Lead → spawn → result → done.  Fire-and-forget.

TEAM (Agent tool WITH team_name):
  Lead ←→ Worker 1   Bidirectional messaging
       ←→ Worker 2   Shared task list
       ←→ Worker 3   Graceful shutdown + cleanup
```

## Setup (One-Time)

### 1. Project settings.json

Add these env vars to `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_SPAWN_BACKEND": "tmux",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### 2. Launch from tmux

```bash
# ALWAYS start CC from an attached tmux session:
tmux new-session -s atlas
claude

# DOES NOT WORK from:
#   - CC Desktop app (no tmux client)
#   - Detached tmux (tmux -d)
#   - Plain terminal without tmux
```

### 3. Verify

```bash
# Inside CC, check env:
echo $TMUX                              # Should show path
echo $CLAUDE_CODE_SPAWN_BACKEND         # Should show "tmux"
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS  # Should show "1"
```

## Lifecycle (Step-by-Step)

### Step 1: Create Team

```
TeamCreate → { team_name: "my-team", lead_agent_id: "team-lead@my-team" }
```

This creates:
- `~/.claude/teams/my-team/config.json` — team membership
- `~/.claude/tasks/my-team/` — shared task list

### Step 2: Spawn Workers

```
Agent(
  name: "worker-1",
  team_name: "my-team",
  subagent_type: "general-purpose",   # ALWAYS general-purpose
  prompt: "Your task...",
  run_in_background: true
)
```

In tmux mode: a new pane appears with worker-1 running a full CC session.

### Step 3: Communicate

```
# Lead → Worker:
SendMessage(to: "worker-1", message: "Check the Docker status")

# Worker → Lead (automatic):
Workers send results back via SendMessage when done.
```

### Step 4: Manage Panes

```bash
# Resize lead pane (default split is 30/70, too narrow):
tmux resize-pane -t :1.1 -x 120

# Read worker output:
tmux capture-pane -t :1.2 -p | tail -20

# List all panes:
tmux list-panes -a
```

### Step 5: Cleanup

```
# 1. Shutdown each worker:
SendMessage(to: "worker-1", message: { type: "shutdown_request" })
SendMessage(to: "worker-2", message: { type: "shutdown_request" })

# 2. Wait for panes to close (2-5 seconds)

# 3. Delete team:
TeamDelete → removes team files + task list
```

## Team Blueprints

### /atlas team jarvis — Personal Co-Pilot

| Role | Model | Purpose |
|------|-------|---------|
| Lead | Opus | Orchestration + user profile + full project context |
| researcher | Haiku | Web search, docs lookup, prior art |
| engineer | Sonnet | Code changes, fixes, implementations |
| analyst | Sonnet | Data analysis, estimation, metrics |
| coordinator | Haiku | PRs, CI status, emails, scheduling |

**Capabilities**: Morning brief, priority AI, context-aware drafting, proactive alerts, onboarding buddy, meeting prep.

### /atlas team feature — Feature Development

| Role | Model | Purpose |
|------|-------|---------|
| Lead (architect) | Opus | Plan, review, coordinate |
| backend | Sonnet | API, services, DB migrations |
| frontend | Sonnet | Components, hooks, pages |
| tester | Sonnet | Tests (unit, integration, E2E) |

### /atlas team debug — Bug Hunt

| Role | Model | Purpose |
|------|-------|---------|
| Lead (debugger) | Opus | Hypothesis, root cause analysis |
| researcher | Sonnet | Log analysis, git bisect, repro |
| fixer | Sonnet | Code fix implementation |
| tester | Sonnet | Regression tests, verification |

### /atlas team review — Code Quality

| Role | Model | Purpose |
|------|-------|---------|
| Lead (reviewer) | Opus | Architecture, consolidation |
| code-reviewer | Sonnet | Patterns, bugs, style |
| security-auditor | Sonnet | OWASP, secrets, RBAC |

### /atlas team audit — Infrastructure Health

| Role | Model | Purpose |
|------|-------|---------|
| Lead (auditor) | Opus | Coordination, report synthesis |
| docker-checker | Sonnet | Container status, logs, health |
| api-tester | Sonnet | Endpoint validation, latency |
| log-analyzer | Sonnet | Error patterns, anomalies |

## Gotchas (11 Known Issues)

| # | Issue | Mitigation |
|---|-------|------------|
| 1 | Explore agents can't SendMessage | ALWAYS use `general-purpose` subagent_type |
| 2 | Task IDs reset per team | Create tasks AFTER TeamCreate |
| 3 | TeamDelete blocked if agents active | Shutdown ALL agents BEFORE TeamDelete |
| 4 | Panes only in attached tmux | Check `$TMUX` env var first |
| 5 | Default pane split is 30/70 | `tmux resize-pane -x 120` after spawn |
| 6 | Agents load full ATLAS plugin | Good — they have all skills available |
| 7 | `-r "name"` fails in `--print` mode | Use session UUID, not display name |
| 8 | Worktree branches accumulate | Monthly cleanup: `git branch \| grep worktree- \| xargs git branch -D` |
| 9 | Cron jobs die with session | Use `durable: true` for persistence |
| 10 | `watch` with `{{}}` in tmux | Use wrapper script, not inline |
| 11 | Max ~5 sessions = 5-10 GB RAM | Monitor with `docker-monitor` or `htop` |

## Environment Detection (For Skill Authors)

Skills should detect the execution environment before spawning agents:

```bash
# Check at session start:
if [ -n "$TMUX" ] && [ "$CLAUDE_CODE_SPAWN_BACKEND" = "tmux" ]; then
  # TMUX MODE: agents get visible panes
  # Auto-resize lead pane after spawn
  # Suggest team blueprints for complex tasks
else
  # IN-PROCESS MODE: agents run hidden
  # Note: "Run from tmux for visible agent panes"
fi
```

## Quick Reference

```bash
# Start a CC session with Agent Teams:
tmux new-session -s atlas && claude

# Resize panes:
tmux resize-pane -t :1.1 -x 120          # Lead wider
tmux resize-pane -t :1.2 -y 30           # Worker taller

# Read worker output:
tmux capture-pane -t :1.2 -p | tail -20

# List everything:
tmux list-panes -a -F "#{pane_id} #{pane_width}x#{pane_height}"

# Emergency cleanup (if TeamDelete fails):
rm -rf ~/.claude/teams/{team-name}
rm -rf ~/.claude/tasks/{team-name}
```

---
*Playbook v1.0 | Validated 2026-03-26 | CC v2.1.84 + ATLAS v3.28.0*
