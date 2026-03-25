---
name: cc-native-features
description: "Claude Code v2.1.83 native features reference — effort system, session management, auto-memory, worktrees, task management, hooks, agent frontmatter, plugin settings, keyboard shortcuts, statusline. SSoT for CC capabilities that ATLAS leverages."
---

# Claude Code Native Features Reference (v2.1.83)

> SSoT for CC features that ATLAS leverages. Updated: 2026-03-25.
> Self-improving: update this file when CC releases new features via `/atlas platform-update`.

## Effort System (v2.1.72 — simplified)

| Level | Symbol | Use Case | API |
|-------|--------|----------|-----|
| `low` | ○ | Simple tasks, routine commands | `/effort low` |
| `medium` | ◐ | Default for Max/Team (v2.1.68) | `/effort medium` |
| `high` | ● | Deep reasoning, complex tasks | `/effort high` |
| `auto` | varies | Reset to plan default | `/effort auto` |

**Per-turn override**: `ultrathink` keyword = max effort for one turn only (v2.1.68).

**Frontmatter**: `effort: low|medium|high` in AGENT.md (v2.1.78) and SKILL.md (v2.1.80).

**Rule**: Opus = high by default. Sonnet = medium. Haiku = low.

## Session Management

| Command | Version | Purpose |
|---------|---------|---------|
| `/rename [name]` | v2.0.64 | Name session (auto-generates from context if no arg, v2.1.72) |
| `/color [color]` | v2.1.75 | Set prompt-bar color. `/color default` to reset |
| `/resume [name]` | v2.0.93 | Resume by name, ID, or pick from list |
| `/branch` | v2.1.77 | Fork conversation (alias: `/fork`) |
| `-n "name"` | v2.1.76 | Name session at CLI launch |
| `--session-id` | v2.0.73 | Custom session ID for forking |
| `--from-pr` | v2.1.27 | Resume session linked to a PR |

**Auto-naming**: Sessions auto-named from plan content (v2.1.77) or first prompt.

## Task Management (v2.1.16)

| Tool | Purpose |
|------|---------|
| `TaskCreate` | Create task with subject, description, activeForm |
| `TaskUpdate` | Update status, owner, dependencies, or delete |
| `TaskGet` | Get full task details by ID |
| `TaskList` | List all tasks with status |

**Dependency tracking**: `addBlocks`, `addBlockedBy` fields.
**Delete**: `status: "deleted"` in TaskUpdate.
**Statuses**: `pending` → `in_progress` → `completed`.

## Auto-Memory (v2.1.32/v2.1.59)

- Claude auto-saves useful context to `~/.claude/projects/{project}/memory/`
- Manage with `/memory` command
- `autoMemoryDirectory` setting for custom location (v2.1.74)
- `MEMORY.md` = index (max 200 lines / 25KB)
- Individual topic files with frontmatter (name, description, type)
- Last-modified timestamps added to memory files (v2.1.75)
- Memory shared across git worktrees of same repo (v2.1.63)

**ATLAS integration**: `memory-dream` skill implements CC auto-dream pattern.

## Worktrees (v2.1.49+)

| Feature | Version | Purpose |
|---------|---------|---------|
| `claude -w name` | v2.1.49 | Start in isolated git worktree |
| `EnterWorktree` tool | v2.1.49 | Create worktree mid-session |
| `ExitWorktree` tool | v2.1.72 | Leave worktree (keep or remove) |
| `isolation: "worktree"` | v2.1.49 | Agent frontmatter for worktree isolation |
| `worktree.sparsePaths` | v2.1.76 | Partial checkout for monorepos |

**Field in statusline**: `worktree` object with name, path, branch, original_dir (v2.1.69).

## Plan Mode

| Feature | Version | Notes |
|---------|---------|-------|
| `EnterPlanMode` | v1.0.33 | Read-only exploration + design |
| `ExitPlanMode` | v1.0.33 | Present plan for approval |
| `/plan [description]` | v2.1.72 | Shortcut with optional prompt |
| `plansDirectory` | v2.1.9 | Custom plan file location |
| `showClearContextOnPlanAccept` | v2.1.69 | Show "clear context" after plan approval |

**ATLAS integration**: `plan-builder` skill generates 15-section plans (A-O format).

## Compaction

- Auto-compacts at configurable % (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, default 80%)
- `PreCompact` hook: inject context to preserve (v1.0.48)
- `PostCompact` hook: restore critical state (v2.1.76)
- Images survive compaction (v2.1.72+)
- Text nuances may be lost — use memory files for critical info
- `/compact` manual trigger
- "Summarize from here" for partial compaction (v2.1.32)

**1M optimization**: Set autocompact to 92% (920K/1M) for maximum context before compact.

## Context Window

| Model | Window | Max Output | Notes |
|-------|--------|------------|-------|
| Opus 4.6 | 1M tokens | 128K | Default for Max (v2.1.75) |
| Sonnet 4.6 | 1M tokens | 128K | Same window, faster |
| Haiku 4.5 | 200K tokens | 64K | Smaller, cheapest |

**Rule**: With 1M context, NEVER suggest session handoff for context reasons.

## Extended Thinking

- Opus 4.6: thinking enabled by default (v2.0.67)
- `ultrathink` = max effort for one turn
- Budget scales with `/effort` setting
- Toggle: Alt+T (v2.0.72), or `/config`
- `CLAUDE_CODE_MAX_THINKING_TOKENS` env var for custom limit

## Plugin Settings (v2.1.49)

- Plugins ship `settings.json` at root for CC defaults
- Priority: managed > user > project > plugin (lowest)
- Plugin settings auto-applied on install/update
- `${CLAUDE_PLUGIN_ROOT}` = absolute path to plugin
- `${CLAUDE_PLUGIN_DATA}` = persistent state dir (v2.1.78)
- `${CLAUDE_SKILL_DIR}` = skill's own directory (v2.1.69)

## Agent Frontmatter (v2.1.78+)

```yaml
---
name: agent-name
model: haiku|sonnet|opus
effort: low|medium|high
maxTurns: 15
disallowedTools:
  - Edit
  - Write
isolation: "worktree"
background: true
initialPrompt: "Start by checking CI status"
memory: user|project|local
permissionMode: default|plan|acceptEdits
---
```

## Structured Questions (AskUserQuestion)

- Up to 4 questions per call
- Each with 2-4 options + auto "Other"
- `multiSelect: true` for checkboxes
- `preview` field for code/mockup comparison
- `header` for short label (max 12 chars)

**ATLAS rule**: ALWAYS use AskUserQuestion, never free-text questions.

## Keyboard Shortcuts (v2.1.18)

**File**: `~/.claude/keybindings.json`

| Action | Default | Rebindable |
|--------|---------|------------|
| `chat:fastMode` | — | v2.1.83 |
| `chat:killAgents` | Ctrl+X Ctrl+K | v2.1.83 |
| `voice:pushToTalk` | Space | v2.1.71 |
| `chat:newline` | Shift+Enter | v2.1.47 |

## Statusline

**Input JSON fields** (available to statusline scripts):

| Field | Version | Type |
|-------|---------|------|
| `workspace.current_dir` | v1.0.71 | string |
| `model.id` | v1.0.71 | string |
| `session_name` | v2.0.64 | string |
| `context_window.used_percentage` | v2.1.6 | number |
| `context_window.remaining_percentage` | v2.1.6 | number |
| `current_usage` | v2.0.70 | number |
| `rate_limits["5h"].used_percentage` | v2.1.80 | number |
| `rate_limits["5h"].resets_at` | v2.1.80 | string |
| `rate_limits["7d"].used_percentage` | v2.1.80 | number |
| `effort` | v2.1.72 | string |
| `worktree` | v2.1.69 | object |
| `exceeds_200k_tokens` | v1.0.88 | boolean |

## Scheduled Execution

| Feature | Scope | Persistence |
|---------|-------|-------------|
| `CronCreate` | Session | Dies when Claude exits (7-day auto-expire) |
| `CronDelete` | Session | Remove by job ID |
| `CronList` | Session | List all scheduled jobs |
| `/loop interval cmd` | Session | Recurring slash command execution (v2.1.71) |
| Remote Triggers | Cloud | Persists across sessions (v2.0.48) |

## Hook Events (v2.1.83 complete — 22 events)

| Event | Version | Trigger |
|-------|---------|---------|
| `SessionStart` | v1.0.62 | New/resumed/cleared session |
| `SessionEnd` | v1.0.85 | Session close |
| `Setup` | v2.1.10 | `--init` or `--maintenance` flags |
| `PreToolUse` | v1.0.38 | Before any tool execution |
| `PostToolUse` | v1.0.38 | After any tool execution |
| `PreCompact` | v1.0.48 | Before context compaction |
| `PostCompact` | v2.1.76 | After context compaction |
| `UserPromptSubmit` | v1.0.54 | User sends a message |
| `PermissionRequest` | v2.1.45 | Tool needs permission |
| `Notification` | v1.0.41 | System notification |
| `SubagentStart` | v2.0.43 | Subagent spawned |
| `SubagentStop` | v1.0.41 | Subagent completed |
| `Stop` | v1.0.38 | Turn ends normally |
| `StopFailure` | v2.1.78 | Turn ends due to API error |
| `InstructionsLoaded` | v2.1.69 | CLAUDE.md/rules loaded |
| `ConfigChange` | v2.1.41 | Settings file changed |
| `CwdChanged` | v2.1.81 | Working directory changed |
| `FileChanged` | v2.1.81 | Watched file modified |
| `TeammateIdle` | v2.1.33 | Agent team member idle |
| `TaskCompleted` | v2.1.33 | Background task done |
| `WorktreeCreate` | v2.1.50 | Worktree created |
| `WorktreeRemove` | v2.1.50 | Worktree removed |

## Bundled Commands

| Command | Version | Purpose |
|---------|---------|---------|
| `/simplify` | v2.1.63 | Review and simplify code |
| `/batch` | v2.1.63 | Batch processing |
| `/copy [N]` | v2.1.59 | Copy code blocks or full response |
| `/debug` | v2.1.30 | Troubleshoot current session |
| `/context` | v1.0.86 | Show context usage with tips (v2.1.74) |
| `/stats` | v2.0.64 | Usage stats with date range filter (v2.1.6) |
| `/export` | v1.0.44 | Export conversation for sharing |

## Self-Improvement Integration

ATLAS leverages these CC features for self-improvement:

1. **Version detection**: `session-start` hook compares CC version with `KNOWN_CC_VERSION`
2. **Platform update**: `/atlas platform-update` parses `/release-notes` → identifies gaps
3. **Memory dream**: `/atlas dream` consolidates session lessons into memory
4. **Feedback loop**: PostToolUse hooks detect anti-patterns → inject corrections
5. **Recursive learning**: Each audit enriches this reference → next audit is better
