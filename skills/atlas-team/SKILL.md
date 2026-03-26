---
name: atlas-team
description: "Agent Teams blueprints — spawn coordinated worker squads in tmux panes. 5 blueprints: jarvis, feature, debug, review, audit. Auto-detects tmux mode."
effort: medium
---

# Agent Teams — Coordinated Worker Squads

Spawn pre-configured teams of AI agents that collaborate via shared task lists and visible tmux panes.

**Commands**: `/atlas team jarvis|feature|debug|review|audit|status|stop`

## Environment Detection (FIRST — Before Any Spawn)

Before spawning ANY team, detect the execution mode:

```bash
# Run this check ONCE at team creation:
echo "TMUX=$TMUX SPAWN=$CLAUDE_CODE_SPAWN_BACKEND TEAMS=$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
```

| Condition | Mode | Behavior |
|-----------|------|----------|
| `$TMUX` set + `SPAWN_BACKEND=tmux` + `AGENT_TEAMS=1` | **TMUX** | Visible panes, full experience |
| `AGENT_TEAMS=1` but no `$TMUX` | **In-Process** | Agents work, no visible panes |
| Neither set | **Unavailable** | Tell user to run `/atlas workspace-setup teams` |

**If TMUX mode**: After spawning agents, auto-resize lead pane:
```bash
tmux resize-pane -t :1.1 -x 120   # Give lead 55-60% width
```

## Team Lifecycle (NON-NEGOTIABLE)

Every team follows this exact lifecycle:

```
1. DETECT   → Check tmux/env (above)
2. CREATE   → TeamCreate(team_name: "{blueprint}-{timestamp}")
3. TASK     → TaskCreate per worker assignment (AFTER TeamCreate — scope resets)
4. SPAWN    → Agent per worker (team_name, name, general-purpose, run_in_background: true)
5. RESIZE   → tmux resize-pane (if tmux mode)
6. MONITOR  → Receive SendMessage from workers as they complete
7. COLLECT  → Aggregate results from all workers
8. SHUTDOWN → SendMessage shutdown_request to EACH worker
9. WAIT     → 3-5 seconds for panes to close
10. DELETE  → TeamDelete to clean up files
11. REPORT  → Present consolidated results to user
```

### Critical Rules

- **ALWAYS** `subagent_type: "general-purpose"` — Explore agents can't SendMessage
- **ALWAYS** `run_in_background: true` — don't block the lead
- **ALWAYS** create tasks AFTER TeamCreate (task scope resets per team)
- **ALWAYS** shutdown ALL workers BEFORE TeamDelete
- **NEVER** use Explore-type agents as team members
- **NEVER** spawn more than 4 workers (RAM: ~1-2 GB per agent)

## Blueprints

### /atlas team jarvis — Personal Co-Pilot

**When**: Morning brief, "what should I work on?", meeting prep, proactive monitoring.

**Team composition**:

| Name | Model | Role | Prompt Focus |
|------|-------|------|-------------|
| Lead (you) | Opus | Orchestrate + synthesize | Full user profile + project context |
| researcher | Haiku | Information gathering | Web search, docs, memory files, git log |
| engineer | Sonnet | Code analysis | Read codebase, identify issues, suggest fixes |
| analyst | Sonnet | Data + metrics | Feature board, test coverage, DoD status, estimation |
| coordinator | Haiku | External systems | CI status, PR reviews, Docker health, deploy status |

**Spawn pattern**:
```
TeamCreate(team_name: "jarvis")

# Spawn 4 workers in ONE message (parallel):
Agent(name: "researcher", team_name: "jarvis", model: "haiku",
      prompt: "Research: {user's question}. Read memory files, search web, check git log. SendMessage results to team lead.")
Agent(name: "engineer", team_name: "jarvis", model: "sonnet",
      prompt: "Analyze: {codebase area}. Read relevant files, identify patterns. SendMessage findings to team lead.")
Agent(name: "analyst", team_name: "jarvis", model: "sonnet",
      prompt: "Metrics: Read .blueprint/FEATURES.md, check test coverage, DoD status. SendMessage summary to team lead.")
Agent(name: "coordinator", team_name: "jarvis", model: "haiku",
      prompt: "Status: Check docker ps, git status, CI pipeline. SendMessage report to team lead.")
```

**Integration with existing skills**:
- Invokes `morning-brief` data sources (calendar, tasks, emails)
- Reads `feature-board` for WIP status
- Checks `product-health` for live system status
- Loads `user-profiler` for personalized context

---

### /atlas team feature — Feature Development Squad

**When**: Implementing a new feature or sub-plan phase with BE + FE + tests.

| Name | Model | Role | Prompt Focus |
|------|-------|------|-------------|
| Lead (you) | Opus | Architecture + review | Plan, coordinate, review PRs |
| backend | Sonnet | API + services + DB | Backend implementation per plan |
| frontend | Sonnet | Components + hooks + pages | Frontend implementation per plan |
| tester | Sonnet | Tests (unit + integration + E2E) | Write tests for both BE + FE |

**Usage**:
```
/atlas team feature "SP-XX Phase N: {description}"
```

**Lead responsibilities**:
1. Read the plan file for the relevant phase
2. Create TaskCreate per deliverable
3. Assign backend tasks to `backend` worker
4. Assign frontend tasks to `frontend` worker
5. Assign test tasks to `tester` worker (AFTER impl tasks complete)
6. Review each worker's output before accepting

---

### /atlas team debug — Bug Hunt Squad

**When**: Complex bug spanning multiple files/services.

| Name | Model | Role | Prompt Focus |
|------|-------|------|-------------|
| Lead (you) | Opus | Hypothesis + root cause | Coordinate investigation |
| researcher | Sonnet | Log analysis + git bisect | Find when bug was introduced |
| fixer | Sonnet | Code fix implementation | Minimal targeted fix |
| tester | Sonnet | Regression test | Write test that reproduces + verify fix |

**Usage**:
```
/atlas team debug "Bug: {description}. Steps to reproduce: {steps}"
```

**Debug cycle**:
1. Lead forms hypothesis
2. Researcher investigates (logs, git history, related code)
3. Lead refines hypothesis based on findings
4. Fixer implements minimal fix
5. Tester writes regression test + verifies
6. Lead reviews everything

---

### /atlas team review — Code Quality Squad

**When**: PR review or pre-merge quality check.

| Name | Model | Role | Prompt Focus |
|------|-------|------|-------------|
| Lead (you) | Opus | Architecture + consolidation | Final review report |
| code-reviewer | Sonnet | Patterns, bugs, style | CLAUDE.md compliance, code quality |
| security-auditor | Sonnet | OWASP, secrets, RBAC | Security scan, vulnerability check |

**Usage**:
```
/atlas team review             # Review working tree diff
/atlas team review PR#42       # Review specific PR
```

---

### /atlas team audit — Infrastructure Health Squad

**When**: System health check, post-deploy validation, or periodic audit.

| Name | Model | Role | Prompt Focus |
|------|-------|------|-------------|
| Lead (you) | Opus | Coordination + report | Synthesize findings into health report |
| docker-checker | Sonnet | Container status | docker ps, logs, health checks, resource usage |
| api-tester | Sonnet | API endpoints | Health endpoints, response times, error rates |
| log-analyzer | Sonnet | Log patterns | Error patterns, anomalies, warnings |

**Usage**:
```
/atlas team audit              # Full infrastructure audit
```

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas team jarvis` | Spawn personal co-pilot team |
| `/atlas team feature "desc"` | Spawn feature dev team with context |
| `/atlas team debug "desc"` | Spawn bug hunt team |
| `/atlas team review` | Spawn code review team |
| `/atlas team audit` | Spawn infrastructure audit team |
| `/atlas team status` | Show active team: members, tasks, pane layout |
| `/atlas team stop` | Graceful shutdown: shutdown workers → TeamDelete |

## Pane Management (Tmux Mode Only)

After spawning workers, the tmux layout looks like:

```
┌──────────────────────┬─────────────────────────┐
│                      │       Worker 1           │
│                      │  (researcher/backend)    │
│      LEAD            ├─────────────────────────┤
│   (you / Opus)       │       Worker 2           │
│                      │  (engineer/frontend)     │
│   55-60% width       ├─────────────────────────┤
│                      │       Worker 3           │
│                      │  (analyst/tester)        │
└──────────────────────┴─────────────────────────┘
```

**Auto-resize** (run after spawn):
```bash
tmux resize-pane -t :1.1 -x 120   # Lead gets ~55% of 214-col terminal
```

**Monitor workers**:
```bash
tmux capture-pane -t :1.2 -p | tail -20   # Read worker 1 output
tmux capture-pane -t :1.3 -p | tail -20   # Read worker 2 output
```

## Shutdown Sequence (CRITICAL — follow this exact order)

Tmux panes can outlive agent processes. This sequence prevents stuck teams:

```
1. SendMessage shutdown_request to EACH worker (parallel OK)
2. Wait 15 seconds (agents need time to wake up + process shutdown)
3. Check: tmux list-panes -a
   → If only lead pane remains → proceed to TeamDelete ✅
   → If worker panes linger (idle ❯ prompt) → wait 10 more seconds
   → If still lingering after 25s total → force cleanup (step 4)
4. Force cleanup (only if step 3 failed):
   a. tmux kill-pane -t %{pane_id}  (for each stuck pane)
   b. rm -rf ~/.claude/teams/{name} ~/.claude/tasks/{name}
   c. Skip TeamDelete (manual cleanup replaces it)
5. TeamDelete (only if panes closed naturally in step 3)
```

**Why panes linger**: CC creates a shell inside each tmux pane. The agent runs inside that shell. When the agent exits, the shell may stay alive. Usually auto-closes in 5-15s, but occasionally persists.

## Error Recovery

| Situation | Action |
|-----------|--------|
| Worker not responding | `SendMessage(to: "worker-name", message: "status?")` |
| Worker stuck | `SendMessage shutdown_request` + spawn replacement |
| TeamDelete blocked | Panes killed before agents fully exited. `rm -rf ~/.claude/teams/{name} ~/.claude/tasks/{name}` |
| Panes linger after shutdown | Wait 15-25s. If still there: `tmux kill-pane -t %{id}` then manual cleanup |
| Too many panes | Max 4 workers. `tmux kill-pane -t :1.N` for emergency |
| Out of memory | Stop team, reduce worker count, use Haiku for simple tasks |

## Playbook Reference

Full onboarding guide: `.blueprint/AGENT-TEAMS-PLAYBOOK.md`
Session orchestration gotchas: `memory/feedback_session_orchestration.md`
