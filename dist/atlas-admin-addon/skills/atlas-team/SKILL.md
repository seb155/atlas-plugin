---
name: atlas-team
description: "Agent Teams blueprint spawner. This skill should be used when the user asks to 'spawn a team', 'agent teams', 'jarvis', '/atlas team', or needs a coordinated multi-pane tmux squad (feature/debug/review/audit/jarvis)."
effort: medium
---

# Agent Teams — Coordinated Worker Squads

Spawn pre-configured AI agent teams collaborating via shared task lists + visible tmux panes.

**Commands**: `/atlas team jarvis|feature|debug|review|audit|session|status|stop`

## Environment Detection (FIRST — Before Any Spawn)

```bash
echo "TMUX=$TMUX SPAWN=$CLAUDE_CODE_SPAWN_BACKEND TEAMS=$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"
```

| Condition | Mode | Behavior |
|-----------|------|----------|
| `$TMUX` + `SPAWN_BACKEND=tmux` + `AGENT_TEAMS=1` | **TMUX** | Visible panes, full experience |
| `AGENT_TEAMS=1`, no `$TMUX` | **In-Process** | Agents work, no panes |
| Neither | **Unavailable** | Tell user → `/atlas workspace-setup teams` |

**TMUX mode**: After spawning agents, `tmux resize-pane -t :1.1 -x 120` (lead 55-60% width).

## Team Lifecycle (NON-NEGOTIABLE)

```
1. DETECT   → Check tmux/env
2. CREATE   → TeamCreate(team_name: "{blueprint}-{timestamp}")
3. TASK     → TaskCreate per worker (AFTER TeamCreate — scope resets)
4. SPAWN    → Agent per worker (team_name, name, general-purpose, run_in_background: true)
5. RESIZE   → tmux resize-pane (if tmux mode)
6. MONITOR  → SendMessage from workers as they complete
7. COLLECT  → Aggregate worker results
8. SHUTDOWN → SendMessage shutdown_request to EACH
9. WAIT     → 3-5s for panes to close
10. DELETE  → TeamDelete to clean up
11. REPORT  → Present consolidated results
```

### Critical Rules

- **ALWAYS** use named `subagent_type` when available (e.g., `"atlas-admin:team-engineer"`)
- **ALWAYS** pass `model:` explicitly — AGENT.md frontmatter NOT respected by CC
- **ALWAYS** `run_in_background: true` — don't block lead
- **ALWAYS** create tasks AFTER TeamCreate (scope resets per team)
- **ALWAYS** shutdown ALL workers BEFORE TeamDelete
- **NEVER** use Explore-type agents (can't SendMessage)
- **NEVER** spawn more than 4 workers (~1-2 GB RAM/agent)

### Named Agent Mapping (Model + Effort Matrix)

| Agent | Model | Effort | Capabilities |
|-------|-------|--------|-------------|
| `atlas-admin:team-researcher` | haiku | low | Read-only: web, docs, git, memory |
| `atlas-admin:team-engineer` | sonnet | medium | Full: code, tests, fixes |
| `atlas-admin:team-tester` | sonnet | medium | Full: test writing + running |
| `atlas-admin:team-reviewer` | sonnet | high | Read-only: diff review, quality |
| `atlas-admin:team-coordinator` | haiku | low | Read-only: CI, Docker, ops |
| `atlas-admin:team-security` | sonnet | high | Read-only: OWASP, secrets, RBAC |
| `atlas-admin:plan-architect` | opus | max | Plans: 15-section, ultrathink |
| `atlas-admin:code-reviewer` | sonnet | high | Standalone code review |
| `atlas-admin:plan-reviewer` | sonnet | high | Quality gate 12/15 scoring |
| `atlas-admin:context-scanner` | haiku | low | CLAUDE.md drift detection |
| `atlas-admin:infra-expert` | sonnet | medium | Infra: Proxmox, Docker, IaC, GPU, networking |
| `atlas-admin:data-engineer` | sonnet | medium | DB: PG admin, migrations, query opt |
| `atlas-admin:devops-engineer` | sonnet | medium | CI/CD: Forgejo Actions, Docker, deploy |
| `atlas-enterprise:domain-analyst` | haiku | low | Domain: ISA 5.1, MBSE, WBS, mining (RO) |

**Effort levels** (CC API): `low` (lookups, status) | `medium` (impl, coding, tests) | `high` (reviews, audits, gates) | `max` (architecture, planning — Opus 4.7) | `xhigh` (CC 2.1.111+, Opus 4.7 only — tuned reasoning/speed).

Fallback: if named agent missing → `subagent_type: "general-purpose"` with same prompt.

### Model ID Reference (Updated 2026-04-04)

CC 2.1.75+ (Max subscription): Shorthand resolves to 1M natively.

| Model | Shorthand | Resolves to | Context | Max Out |
|-------|-----------|-------------|---------|---------|
| Opus 4.7 | `"opus"` | `claude-opus-4-7[1m]` | 1M | 128K |
| Sonnet 4.6 | `"sonnet"` | `claude-sonnet-4-6` | 1M | 64K |
| Haiku 4.5 | `"haiku"` | `claude-haiku-4-5-20251001` | 200K | 64K |

**Rules**:
- Shorthand `"opus"`/`"sonnet"` give 1M context on CC 2.1.75+ (Max). No workaround.
- Omit `model:` → inherit from parent (1M if parent Opus 4.7 / Sonnet 4.6)
- AGENT.md `model:` IS respected for spawning
- Safety net: `ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-7[1m]'` in settings.json

## Blueprints

All blueprints share the same spawn pattern (TeamCreate → 1+ Agent calls in parallel with `run_in_background: true`). Workers SendMessage results to lead.

### /atlas team jarvis — Personal Co-Pilot

**When**: Morning brief, "what should I work on?", meeting prep, monitoring.

| Name | Model | Role |
|------|-------|------|
| Lead (you) | Opus | Orchestrate + synthesize, full user profile |
| researcher | Haiku | Web search, docs, memory files, git log |
| engineer | Sonnet | Read codebase, identify issues, suggest fixes |
| analyst | Sonnet | Feature board, test coverage, DoD, estimation |
| coordinator | Haiku | docker ps, git status, CI pipeline |

```
TeamCreate(team_name: "jarvis")

# Spawn 4 workers in ONE message (parallel):
Agent(name: "researcher", subagent_type: "atlas-admin:team-researcher", team_name: "jarvis", model: "haiku", run_in_background: true,
      prompt: "Research: {question}. Read memory, search web, check git. SendMessage to lead.")
Agent(name: "engineer", subagent_type: "atlas-admin:team-engineer", team_name: "jarvis", model: "sonnet", run_in_background: true,
      prompt: "Analyze: {area}. Read files, identify patterns. SendMessage findings to lead.")
Agent(name: "analyst", subagent_type: "atlas-admin:team-engineer", team_name: "jarvis", model: "sonnet", run_in_background: true,
      prompt: "Metrics: Read .blueprint/FEATURES.md, coverage, DoD. SendMessage summary to lead.")
Agent(name: "coordinator", subagent_type: "atlas-admin:team-coordinator", team_name: "jarvis", model: "haiku", run_in_background: true,
      prompt: "Status: docker ps, git status, CI. SendMessage report to lead.")
```

**Integrations**: morning-brief data sources, feature-board WIP, product-health, user-profiler context.

### /atlas team feature — Feature Development Squad

**When**: New feature or sub-plan phase with BE + FE + tests.

**Usage**: `/atlas team feature "SP-XX Phase N: {description}"`

| Name | Model | Role |
|------|-------|------|
| Lead | Opus | Architecture + review, plan, coordinate |
| backend | Sonnet | API + services + DB per plan |
| frontend | Sonnet | Components + hooks + pages per plan |
| tester | Sonnet | Tests (unit + integration + E2E) for both |

```
TeamCreate(team_name: "feature-{name}")
Agent(name: "backend", subagent_type: "atlas-admin:team-engineer", team_name: "feature-{name}", model: "sonnet", run_in_background: true,
      prompt: "Backend: {task}. Read plan + existing code. Implement API/service/DB. SendMessage to lead.")
Agent(name: "frontend", subagent_type: "atlas-admin:team-engineer", team_name: "feature-{name}", model: "sonnet", run_in_background: true,
      prompt: "Frontend: {task}. Read plan + existing components. Implement UI. SendMessage to lead.")
Agent(name: "tester", subagent_type: "atlas-admin:team-tester", team_name: "feature-{name}", model: "sonnet", run_in_background: true,
      prompt: "Tests: {scope}. Write unit + integration for BE + FE. SendMessage to lead.")
```

**Lead**: Read plan phase → TaskCreate per deliverable → assign BE/FE/tests (tests AFTER impl) → review each output.

### /atlas team debug — Bug Hunt Squad

**When**: Complex bug spanning multiple files/services.

**Usage**: `/atlas team debug "Bug: {desc}. Steps: {steps}"`

| Name | Model | Role |
|------|-------|------|
| Lead | Opus | Hypothesis + root cause |
| researcher | Sonnet | Logs + git bisect, find when introduced |
| fixer | Sonnet | Minimal targeted fix |
| tester | Sonnet | Regression test that reproduces + verifies fix |

```
TeamCreate(team_name: "debug-{bug-id}")
Agent(name: "researcher", subagent_type: "atlas-admin:team-researcher", team_name: "debug-{bug-id}", model: "sonnet", run_in_background: true,
      prompt: "Investigate: {bug}. git log, error logs, related code. Find when/where introduced. SendMessage to lead.")
Agent(name: "fixer", subagent_type: "atlas-admin:team-engineer", team_name: "debug-{bug-id}", model: "sonnet", run_in_background: true,
      prompt: "Fix: {bug}. Minimal targeted fix per lead's hypothesis. SendMessage changes to lead.")
Agent(name: "tester", subagent_type: "atlas-admin:team-tester", team_name: "debug-{bug-id}", model: "sonnet", run_in_background: true,
      prompt: "Test: {bug}. Regression test reproducing bug, verify fix. SendMessage to lead.")
```

**Cycle**: hypothesis → investigate → refine → fix → test → review.

### /atlas team review — Code Quality Squad

**When**: PR review or pre-merge. **Usage**: `/atlas team review` (working tree) | `/atlas team review PR#42`

| Name | Model | Role |
|------|-------|------|
| Lead | Opus | Architecture + final report |
| code-reviewer | Sonnet | Patterns, bugs, style, CLAUDE.md compliance |
| security-auditor | Sonnet | OWASP, secrets, RBAC |

```
TeamCreate(team_name: "review")
Agent(name: "code-reviewer", subagent_type: "atlas-admin:team-reviewer", team_name: "review", model: "sonnet", run_in_background: true,
      prompt: "Review: diff for bugs, patterns, CLAUDE.md compliance. SendMessage to lead.")
Agent(name: "security-auditor", subagent_type: "atlas-admin:team-security", team_name: "review", model: "sonnet", run_in_background: true,
      prompt: "Security: OWASP, secrets, RBAC. SendMessage findings to lead.")
```

### /atlas team audit — Infrastructure Health Squad

**When**: System health, post-deploy, periodic. **Usage**: `/atlas team audit`

| Name | Model | Effort | Role |
|------|-------|--------|------|
| Lead | Opus | high | Synthesize health report |
| docker-checker | Haiku | low | docker ps, logs, health, resources |
| api-tester | Sonnet | medium | Health endpoints, response times, errors |
| log-analyzer | Haiku | low | Error patterns, anomalies, warnings |

```
TeamCreate(team_name: "audit")
Agent(name: "docker-checker", subagent_type: "atlas-admin:team-coordinator", team_name: "audit", model: "haiku", run_in_background: true,
      prompt: "Docker: status, health, resources, stale images. SendMessage to lead.")
Agent(name: "api-tester", subagent_type: "atlas-admin:team-engineer", team_name: "audit", model: "sonnet", run_in_background: true,
      prompt: "API: endpoints, response times, errors. SendMessage to lead.")
Agent(name: "log-analyzer", subagent_type: "atlas-admin:team-researcher", team_name: "audit", model: "haiku", run_in_background: true,
      prompt: "Logs: error patterns, anomalies. SendMessage to lead.")
```

## Pre-Spawn Complexity Routing

| Complexity | Signal | Action |
|------------|--------|--------|
| **Trivial** | <2 files, single concern | Skip team — do it yourself |
| **Moderate** | 2-5 files, BE-only or FE-only | 2 workers max (engineer + tester) |
| **Complex** | BE+FE+tests, multi-service, >5 files | Full blueprint (3-4 workers) |

**Rule**: NEVER spawn 4-worker team for 1-file fix. Ask: "Faster alone?"

## Scratchpad Bus (Session Teams)

Shared file-based coordination layer. Workers write structured outputs, Lead reads for synthesis.

### Directory Structure

```bash
SCRATCHPAD=".claude/scratchpad/${TEAM_NAME}"
mkdir -p "$SCRATCHPAD/tasks" "$SCRATCHPAD/relay"
```

```
.claude/scratchpad/{team-name}/
├── context.md         # Lead writes: focus, project context
├── decisions.jsonl    # Append-only architectural decisions (all)
├── tasks/             # task-001.md, task-002.md, ... worker outputs
├── relay/             # role.md relay checkpoints
└── errors.md          # Known errors/gotchas
```

### Worker Output Format

Workers MUST write to `$SCRATCHPAD/tasks/task-{NNN}.md`:

```markdown
## Task: {description}
**Worker**: {name} | **Model**: {model} | **Status**: done

### Changes
- `path/to/file.py` — {what changed and why}

### Decisions
- {non-obvious decision with rationale}

### For Next Worker
- {context that would help follow-up}

### Tests
- {commands run + pass/fail}
```

### Lead Protocol

After each worker completes:
1. Read `$SCRATCHPAD/tasks/task-{N}.md`
2. Present results to user
3. Next related task: include `"Read .claude/scratchpad/{team}/tasks/task-{N}.md for prior context"` in worker prompt

On team stop: `rm -rf .claude/scratchpad/{team-name}/`

### Batch Mode (lightweight)

```bash
SCRATCHPAD="/tmp/atlas-team-${TEAM_NAME}-scratchpad.md"
# Workers APPEND: echo "## {worker}\n{findings}\n---" >> $SCRATCHPAD
# Lead reads: cat $SCRATCHPAD
# Auto-deleted on session end
```

## Context Management (Session Teams)

### Proactive Compaction (every 5 tasks/worker)

```
if worker.task_count % 5 == 0:
  SendMessage(to: worker.name, message:
    "You've completed {N} tasks. Compact context now.
     KEEP: file locations, import patterns, module architecture, test fixtures.
     DROP: old task details, error traces, file contents already committed.
     Reply 'compacted' and wait for next task.")
```

**Why 5?** Each task ~20K tokens → 100K accumulated by task 5. 200K window fills by task 7-8 without compaction.

### Relay Handoff (>70% context capacity)

```
estimated_context = base_overhead (140K) + (task_count × 20K)
threshold = 140K usable → triggers ~7 tasks (no compact) / ~12 (with compact)
```

**Flow**:
1. Lead detects threshold
2. SendMessage relay instruction → worker writes `.claude/scratchpad/{team}/relay/{role}.md` (≤500 words: files touched, patterns learned, decisions, current state, gotchas)
3. Worker confirms
4. Shutdown old worker (15s wait, verify pane closed)
5. Spawn fresh worker with: `"You replace previous worker. Read relay file at .claude/scratchpad/{team}/relay/{role}.md, then execute: {next_task}"`
6. Reset POOL `task_count = 0`

**Decision matrix**:
```
task_count % 5 == 0 AND task_count < threshold → COMPACT (cheaper)
task_count >= threshold → RELAY (fresh context, clean state)
worker unresponsive 30s → RELAY (crash recovery, respawn with relay if exists)
```

### Relay File Format

```markdown
## Relay: {role} Worker — {date}
**Tasks**: {N} | **Reason**: {threshold / crash}

### Files Touched
- `path/to/file.py` — {what + why}

### Patterns Learned
- {codebase patterns: DI, fixtures, conventions}

### Decisions
- {non-obvious choices + rationale}

### Current State
- {done / in-progress / not started per workstream}

### Gotchas
- {avoid / constraints / quirks}
```

## Session Teams (Persistent Workers)

When invoked as `/atlas team session {blueprint}`, workers persist for entire session. Spawned **on demand** (warm pool), reused via SendMessage.

**Usage**: `/atlas team session feature|debug|jarvis`

### Session Lifecycle

```
1. DETECT   → tmux/env
2. CREATE   → TeamCreate("session-{blueprint}-{date}")
3. SCRATCH  → mkdir scratchpad dirs
4. LOOP     → User task → Classify → Route
   4a. Classify by domain keywords
   4b. Worker alive for role? → REUSE via SendMessage
   4c. No worker? → SPAWN (on demand)
   4d. Worker executes + writes scratchpad/tasks/task-{N}.md
   4e. Reports back → Lead reads → present to user
5. MANAGE   → Every 5 tasks/worker: suggest compact
6. RELAY    → Context >70%: write relay → respawn
7. STOP     → User "done" / `/atlas team stop` → shutdown all
8. CLEANUP  → TeamDelete + rm -rf scratchpad
```

### Task Classification (Lead-side routing)

| Domain | Keywords | Worker |
|--------|----------|--------|
| backend | api, endpoint, service, model, migration, route, db, sql, fastapi | team-engineer |
| frontend | component, hook, page, ui, form, grid, chart, react, tsx | team-engineer |
| test | test, spec, e2e, assertion, coverage, fixture, pytest, vitest | team-tester |
| research | search, find, investigate, docs, analyze, audit | team-researcher |
| ops | docker, ci, deploy, health, status, logs | team-coordinator |

**Trivial** (<2 files): Lead handles directly — no spawn.

### Worker Reuse Protocol

```
POOL = {}
on_task(task):
  role = classify(task)
  if role in POOL and POOL[role].alive:
    SendMessage(to: POOL[role].name, message: task_prompt)  # REUSE
    POOL[role].task_count += 1
  else:
    worker = Agent(name: role_name, subagent_type: role_agent, ...)  # SPAWN
    POOL[role] = {name: worker, alive: true, task_count: 1}
```

### Session vs Batch

| | **Batch** (`/atlas team feature`) | **Session** (`/atlas team session feature`) |
|---|---|---|
| Workers | Spawn all → task → shutdown | Spawn on demand → reuse → shutdown at end |
| Lifetime | Single batch (~5 min) | Entire session (~1-2h) |
| Cost/task | ~140K spawn overhead each | ~0 after first spawn |
| Best for | One-off parallel tasks | Sprint of 5-15 related tasks |
| Context | Fresh each time | Accumulates (compact/relay) |

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas team jarvis` | Personal co-pilot (batch) |
| `/atlas team feature "desc"` | Feature dev (batch) |
| `/atlas team debug "desc"` | Bug hunt (batch) |
| `/atlas team review` | Code review (batch) |
| `/atlas team audit` | Infra audit (batch) |
| `/atlas team session feature/debug/jarvis` | Persistent (session) |
| `/atlas team status` | Active team: members, tasks, panes |
| `/atlas team stop` | Graceful shutdown → TeamDelete |

## Pane Management (Tmux Mode)

Layout: Lead (left, 55-60% width) | Workers stacked vertically (right).

```bash
tmux resize-pane -t :1.1 -x 120          # Lead ~55% of 214-col
tmux capture-pane -t :1.2 -p | tail -20  # Read worker 1
tmux capture-pane -t :1.3 -p | tail -20  # Read worker 2
```

## Shutdown Sequence (CRITICAL — exact order)

Tmux panes can outlive agent processes. This prevents stuck teams:

```
1. SendMessage shutdown_request to EACH (parallel OK)
2. Wait 15s (agents need time to wake + shutdown)
3. tmux list-panes -a:
   → Only lead remains → TeamDelete ✅
   → Worker panes linger (idle ❯) → wait 10s more
   → Still lingering after 25s → force cleanup (step 4)
4. Force cleanup (step 3 failed):
   a. tmux kill-pane -t %{pane_id} (each stuck)
   b. rm -rf ~/.claude/teams/{name} ~/.claude/tasks/{name}
   c. SKIP TeamDelete (manual replaces it)
5. TeamDelete (only if step 3 succeeded)
```

**Why panes linger**: CC creates a shell inside each pane. Agent runs in shell. Agent exits but shell may stay alive 5-15s, occasionally persists.

## Session Status Dashboard

`/atlas team status` shows:

```
🏛️ SESSION TEAM: {team-name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

| Worker     | Model  | Status | Tasks | Est. Ctx | Compacts | Relays |
|------------|--------|--------|-------|----------|----------|--------|
| engineer   | Sonnet | idle   | 7     | ~62%     | 1        | 0      |
| tester     | Sonnet | busy   | 3     | ~35%     | 0        | 0      |
| researcher | Haiku  | idle   | 2     | ~22%     | 0        | 0      |
| (frontend) | —      | cold   | 0     | —        | —        | —      |

📊 Session: 12 tasks routed, 1 compact, 0 relays
📁 Scratchpad: .claude/scratchpad/{team}/ (12 task files)
⏱️  Uptime: 47 min
```

**Fields**: `Status`: busy/idle/cold | `Est. Ctx`: `base_overhead + (tasks × 20K) - (compacts × 40K)` as % of 200K | `Compacts`/`Relays` counts.

Lead tracks in memory (no persistent file):
```
POOL = {
  "backend": {name: "engineer", model: "sonnet", status: "idle", tasks: 7, compacts: 1, relays: 0, spawned_at: "17:05"},
  "test":    {name: "tester", model: "sonnet", status: "busy", tasks: 3, compacts: 0, relays: 0, spawned_at: "17:20"},
}
```

## Error Recovery

### Batch Teams

| Situation | Action |
|-----------|--------|
| Worker not responding | `SendMessage(to: "worker-name", message: "status?")` |
| Worker stuck | Shutdown + spawn replacement |
| TeamDelete blocked | Panes killed before agents exited. `rm -rf ~/.claude/teams/{name} ~/.claude/tasks/{name}` |
| Panes linger | Wait 15-25s. Else `tmux kill-pane -t %{id}` + manual cleanup |
| Too many panes | Max 4 workers. `tmux kill-pane -t :1.N` emergency |
| OOM | Stop team, reduce workers, use Haiku for simple tasks |

### Session Teams (additional)

| Situation | Action |
|-----------|--------|
| Worker crashed (no response 30s) | Check relay/ → respawn with relay file. No relay → fresh respawn with scratchpad context |
| Context bloated (slow) | Trigger relay immediately (don't wait threshold) |
| Wrong worker got task | SendMessage "Cancel current. Wait." → re-route correct worker |
| Add new role mid-session | Spawn worker, add to pool. No restart. |
| Switch focus | Compact all, update scratchpad/context.md |
| Session too long (2h+) | Relay all, clean scratchpad/tasks/ (keep relay/) |

## MCP Server Inheritance (CC v2.1.101+)

Subagents auto-inherit MCP tools from project's dynamically-injected servers (`.mcp.json`: gms-knowledge, stitch, context7).

**Exclusion**: `disallowedTools` in AGENT.md frontmatter, glob patterns (e.g., `mcp__claude-in-chrome__*`).

## Worktree Isolation (CC v2.1.101+)

Read/Edit access fixed for subagents in isolated worktrees. Isolation is **runtime parameter** of `Agent()` — NOT in AGENT.md.

```
Agent({ subagent_type: "team-engineer", isolation: "worktree", prompt: "..." })
```

## Playbook Reference

- Full onboarding: `.blueprint/AGENT-TEAMS-PLAYBOOK.md`
- Session orchestration gotchas: `memory/feedback_session_orchestration.md`
- Session architecture: `.blueprint/plans/cosmic-mapping-flame.md`
