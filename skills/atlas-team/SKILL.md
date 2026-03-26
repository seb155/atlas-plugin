---
name: atlas-team
description: "Agent Teams blueprints — spawn coordinated worker squads in tmux panes. 5 blueprints: jarvis, feature, debug, review, audit. Auto-detects tmux mode."
effort: medium
---

# Agent Teams — Coordinated Worker Squads

Spawn pre-configured teams of AI agents that collaborate via shared task lists and visible tmux panes.

**Commands**: `/atlas team jarvis|feature|debug|review|audit|session|status|stop`

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

- **ALWAYS** use named `subagent_type` when available (e.g., `"atlas-admin:team-engineer"`)
- **ALWAYS** pass `model:` explicitly — AGENT.md frontmatter is NOT respected by CC
- **ALWAYS** `run_in_background: true` — don't block the lead
- **ALWAYS** create tasks AFTER TeamCreate (task scope resets per team)
- **ALWAYS** shutdown ALL workers BEFORE TeamDelete
- **NEVER** use Explore-type agents as team members (can't SendMessage)
- **NEVER** spawn more than 4 workers (RAM: ~1-2 GB per agent)

### Named Agent Mapping

| Agent Definition | Model | Capabilities |
|-----------------|-------|-------------|
| `atlas-admin:team-researcher` | haiku | Read-only: web, docs, git, memory |
| `atlas-admin:team-engineer` | sonnet | Full: code, tests, fixes |
| `atlas-admin:team-tester` | sonnet | Full: test writing + running |
| `atlas-admin:team-reviewer` | sonnet | Read-only: diff review, quality |
| `atlas-admin:team-coordinator` | haiku | Read-only: CI, Docker, ops status |
| `atlas-admin:team-security` | sonnet | Read-only: OWASP, secrets, RBAC |

Fallback: if named agent not found, use `subagent_type: "general-purpose"` with the same prompt.

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
Agent(name: "researcher", subagent_type: "atlas-admin:team-researcher",
      team_name: "jarvis", model: "haiku", run_in_background: true,
      prompt: "Research: {user's question}. Read memory files, search web, check git log. SendMessage results to team lead.")
Agent(name: "engineer", subagent_type: "atlas-admin:team-engineer",
      team_name: "jarvis", model: "sonnet", run_in_background: true,
      prompt: "Analyze: {codebase area}. Read relevant files, identify patterns. SendMessage findings to team lead.")
Agent(name: "analyst", subagent_type: "atlas-admin:team-engineer",
      team_name: "jarvis", model: "sonnet", run_in_background: true,
      prompt: "Metrics: Read .blueprint/FEATURES.md, check test coverage, DoD status. SendMessage summary to team lead.")
Agent(name: "coordinator", subagent_type: "atlas-admin:team-coordinator",
      team_name: "jarvis", model: "haiku", run_in_background: true,
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

**Spawn pattern**:
```
TeamCreate(team_name: "feature-{name}")

Agent(name: "backend", subagent_type: "atlas-admin:team-engineer",
      team_name: "feature-{name}", model: "sonnet", run_in_background: true,
      prompt: "Backend: {task}. Read plan file + existing code. Implement API/service/DB changes. SendMessage results to team lead.")
Agent(name: "frontend", subagent_type: "atlas-admin:team-engineer",
      team_name: "feature-{name}", model: "sonnet", run_in_background: true,
      prompt: "Frontend: {task}. Read plan file + existing components. Implement UI changes. SendMessage results to team lead.")
Agent(name: "tester", subagent_type: "atlas-admin:team-tester",
      team_name: "feature-{name}", model: "sonnet", run_in_background: true,
      prompt: "Tests: {scope}. Write unit + integration tests for BE + FE changes. SendMessage results to team lead.")
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

**Spawn pattern**:
```
TeamCreate(team_name: "debug-{bug-id}")

Agent(name: "researcher", subagent_type: "atlas-admin:team-researcher",
      team_name: "debug-{bug-id}", model: "sonnet", run_in_background: true,
      prompt: "Investigate: {bug}. Check git log, error logs, related code. Find when/where bug was introduced. SendMessage findings to team lead.")
Agent(name: "fixer", subagent_type: "atlas-admin:team-engineer",
      team_name: "debug-{bug-id}", model: "sonnet", run_in_background: true,
      prompt: "Fix: {bug}. Implement minimal targeted fix based on lead's hypothesis. SendMessage changes to team lead.")
Agent(name: "tester", subagent_type: "atlas-admin:team-tester",
      team_name: "debug-{bug-id}", model: "sonnet", run_in_background: true,
      prompt: "Test: {bug}. Write regression test that reproduces the bug, verify fix passes. SendMessage results to team lead.")
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

**Spawn pattern**:
```
TeamCreate(team_name: "review")

Agent(name: "code-reviewer", subagent_type: "atlas-admin:team-reviewer",
      team_name: "review", model: "sonnet", run_in_background: true,
      prompt: "Review: Check diff for bugs, patterns, CLAUDE.md compliance. SendMessage findings to team lead.")
Agent(name: "security-auditor", subagent_type: "atlas-admin:team-security",
      team_name: "review", model: "sonnet", run_in_background: true,
      prompt: "Security: Scan diff for OWASP vulnerabilities, secrets, RBAC issues. SendMessage findings to team lead.")
```

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

**Spawn pattern**:
```
TeamCreate(team_name: "audit")

Agent(name: "docker-checker", subagent_type: "atlas-admin:team-coordinator",
      team_name: "audit", model: "sonnet", run_in_background: true,
      prompt: "Docker: Check container status, health, resource usage, stale images. SendMessage report to team lead.")
Agent(name: "api-tester", subagent_type: "atlas-admin:team-engineer",
      team_name: "audit", model: "sonnet", run_in_background: true,
      prompt: "API: Test health endpoints, response times, error rates. SendMessage report to team lead.")
Agent(name: "log-analyzer", subagent_type: "atlas-admin:team-researcher",
      team_name: "audit", model: "sonnet", run_in_background: true,
      prompt: "Logs: Analyze error patterns, anomalies, warnings in docker logs and system logs. SendMessage report to team lead.")
```

**Usage**:
```
/atlas team audit              # Full infrastructure audit
```

## Pre-Spawn Complexity Routing

Before spawning a full team, assess task complexity:

| Complexity | Signal | Action |
|------------|--------|--------|
| **Trivial** | < 2 files, single concern, quick fix | Skip team — do it yourself |
| **Moderate** | 2-5 files, BE only or FE only | 2 workers max (engineer + tester) |
| **Complex** | BE + FE + tests, multi-service, > 5 files | Full blueprint (3-4 workers) |

**Rule**: NEVER spawn a 4-worker team for a 1-file fix. Ask yourself: "Would I finish this faster alone?"

## Scratchpad Protocol

Workers record findings in a shared scratchpad to avoid re-work and enable cross-worker awareness:

```bash
SCRATCHPAD="/tmp/atlas-team-${TEAM_NAME}-scratchpad.md"
```

**Rules**:
- Workers APPEND findings (never overwrite): `echo "## {worker-name}\n{findings}\n---" >> $SCRATCHPAD`
- Lead reads scratchpad before synthesizing final report: `cat $SCRATCHPAD`
- Scratchpad is ephemeral — auto-deleted after TeamDelete or session end
- Keep entries concise (< 200 words per worker)

## Session Teams (Persistent Workers)

When invoked as `/atlas team session {blueprint}`, workers persist for the entire session instead of shutting down after one task batch. Workers are spawned **on demand** (warm pool) and reused via SendMessage.

**Usage**: `/atlas team session feature|debug|jarvis`

### Session Lifecycle

```
1. DETECT   → Check tmux/env
2. CREATE   → TeamCreate("session-{blueprint}-{date}")
3. LOOP     → Receive user tasks → Classify → Route
   3a. Classify task by domain keywords
   3b. Worker alive for role? → REUSE via SendMessage
   3c. No worker? → SPAWN new (on demand)
   3d. Worker reports back → Present to user
   3e. Repeat for each user task
4. MANAGE   → Every 5 tasks per worker: suggest compact
5. RELAY    → Context > 70%: worker writes relay file → respawn
6. STOP     → User: "done" or /atlas team stop → Shutdown all
7. DELETE   → TeamDelete + scratchpad cleanup
```

### Task Classification (Lead-side routing)

Classify each user task by keywords to pick the right worker:

| Domain | Keywords | Worker Agent |
|--------|----------|-------------|
| **backend** | api, endpoint, service, model, migration, route, db, sql, fastapi | team-engineer |
| **frontend** | component, hook, page, ui, form, grid, chart, react, tsx | team-engineer |
| **test** | test, spec, e2e, assertion, coverage, fixture, pytest, vitest | team-tester |
| **research** | search, find, investigate, docs, analyze, audit | team-researcher |
| **ops** | docker, ci, deploy, health, status, logs | team-coordinator |

**Trivial tasks** (< 2 files, quick answer): Lead handles directly — no worker spawn.

### Worker Reuse Protocol

```
# Lead maintains in-memory routing:
POOL = {}

on_task(task):
  role = classify(task)
  if role in POOL and POOL[role].alive:
    # REUSE: send task to existing worker
    SendMessage(to: POOL[role].name, message: task_prompt)
    POOL[role].task_count += 1
  else:
    # SPAWN: create new worker
    worker = Agent(name: role_name, subagent_type: role_agent, ...)
    POOL[role] = {name: worker, alive: true, task_count: 1}
```

### Context Management

```
Every 5 tasks per worker:
  SendMessage(to: worker, message: "Compact context. KEEP: file locations,
  patterns, current state. DROP: old task details, error traces.")

When estimated context > 70% (heuristic: > 7 tasks without compact):
  1. SendMessage relay instruction → worker writes relay/role.md
  2. Shutdown old worker
  3. Spawn new worker with: "Read .claude/scratchpad/relay/{role}.md for context."
  4. Update POOL with new worker reference
```

### Session vs Batch (when to use which)

| | **Batch** (`/atlas team feature`) | **Session** (`/atlas team session feature`) |
|---|---|---|
| Workers | Spawn all → task → shutdown | Spawn on demand → reuse → shutdown at end |
| Lifetime | Single task batch (~5 min) | Entire session (~1-2h) |
| Cost per task | ~140K spawn overhead each | ~0 after first spawn |
| Best for | One-off parallel tasks | Sprint of 5-15 related tasks |
| Context | Fresh each time | Accumulates (managed by compact/relay) |

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas team jarvis` | Spawn personal co-pilot team (batch) |
| `/atlas team feature "desc"` | Spawn feature dev team (batch) |
| `/atlas team debug "desc"` | Spawn bug hunt team (batch) |
| `/atlas team review` | Spawn code review team (batch) |
| `/atlas team audit` | Spawn infrastructure audit team (batch) |
| `/atlas team session feature` | Start persistent feature team (session) |
| `/atlas team session debug` | Start persistent debug team (session) |
| `/atlas team session jarvis` | Start persistent co-pilot (session) |
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
