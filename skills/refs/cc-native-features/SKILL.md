---
name: cc-native-features
description: "Claude Code v2.1.111 native features reference — effort system, session management, auto-memory, worktrees, task management, hooks, agent frontmatter, plugin settings, keyboard shortcuts, statusline. SSoT for CC capabilities that ATLAS leverages."
---

# Claude Code Native Features Reference (v2.1.111)

> SSoT for CC features that ATLAS leverages. Updated: 2026-04-16 (Opus 4.7 GA).
> Self-improving: update this file when CC releases new features via `/atlas platform-update`.

## Effort System (v2.1.72+ / xhigh v2.1.111)

| Level | Symbol | Use Case | API |
|-------|--------|----------|-----|
| `low` | ○ | Simple tasks, routine commands | `/effort low` |
| `medium` | ◐ | Default for Max/Team (v2.1.68) | `/effort medium` |
| `high` | ● | Deep reasoning, complex tasks | `/effort high` |
| `xhigh` | ●● | Between `high` and `max` (Opus 4.7 only, v2.1.111+) | `/effort xhigh` |
| `max` | ◉ | No thinking constraint (Opus only) | `/effort max` |
| `auto` | varies | Reset to plan default | `/effort auto` |

**`/effort` interactive slider** (v2.1.111): Call with no arguments → arrow-key navigation + Enter to confirm.

**Per-turn override**: `ultrathink` keyword = max effort for one turn only (v2.1.68).

**Frontmatter**: `effort: low|medium|high|xhigh` in AGENT.md (v2.1.78) and SKILL.md (v2.1.80).

**Rule**: Opus = high/xhigh by default. Sonnet = medium. Haiku = low. Non-Opus fallback `xhigh` → `high`.

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
| Opus 4.7 | 1M tokens | 128K | Default for Max (v2.1.111+) |
| Sonnet 4.6 | 1M tokens | 128K | Same window, faster |
| Haiku 4.5 | 200K tokens | 64K | Smaller, cheapest |

**Rule**: With 1M context, NEVER suggest session handoff for context reasons.

## Adaptive Thinking (formerly Extended Thinking)

- **API change 2026-04**: Opus 4.7 deprecated explicit thinking-enabled mode with token budgets. Only adaptive mode is supported (`{"type": "adaptive"}` or via effort level).
- Opus 4.7: adaptive thinking enabled by default (v2.0.67); new `xhigh` effort tier (v2.1.111+, between `high` and `max`)
- `ultrathink` = max effort for one turn
- Budget scales with `/effort` setting (Claude Code layer, not API)
- Toggle: Alt+T (v2.0.72), or `/config`
- `CLAUDE_CODE_MAX_THINKING_TOKENS` env var for custom limit (CC client hint, not API budget)
- Sonnet 4.6 still supports legacy extended thinking API, but ATLAS standardizes on adaptive

## Plugin Settings (v2.1.49)

- Plugins ship `settings.json` at root for CC defaults
- Priority: managed > user > project > plugin (lowest)
- Plugin settings auto-applied on install/update
| Variable | Purpose | Since |
|----------|---------|-------|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to plugin | v2.1.x |
| `${CLAUDE_PLUGIN_DATA}` | Persistent state dir | v2.1.78 |
| `${CLAUDE_SKILL_DIR}` | Skill's own directory | v2.1.69 |

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

**File**: `~/.claude/keybindings.json` — auto-detected on change, no restart needed.

**Format**: context-based binding blocks (NOT `{ key, command }` objects):
```json
{
  "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
  "bindings": [
    { "context": "Chat", "bindings": { "ctrl+shift+f": "chat:fastMode" } }
  ]
}
```

**Contexts**: `Global`, `Chat`, `Autocomplete`, `Confirmation`, `Transcript`, `HistorySearch`, `Task`, `ThemePicker`, `Attachments`, `Footer`, `MessageSelector`, `DiffDialog`, `ModelPicker`, `Select`, `Plugin`, `Settings`, `Help`, `Tabs`

**Key rebindable actions**:

| Action | Context | Default | Since |
|--------|---------|---------|-------|
| `chat:fastMode` | Chat | — | v2.1.83 |
| `chat:killAgents` | Chat | Ctrl+X Ctrl+K | v2.1.83 |
| `voice:pushToTalk` | Chat | Space | v2.1.71 |
| `chat:newline` | Chat | Shift+Enter | v2.1.47 |
| `chat:submit` | Chat | Enter | v2.1.18 |
| `chat:externalEditor` | Chat | Ctrl+G | v2.1.18 |
| `app:toggleTodos` | Global | Ctrl+T | v2.1.18 |
| `app:toggleTranscript` | Global | Ctrl+O | v2.1.18 |

Set to `null` to unbind. Chords: `"ctrl+k ctrl+s"` (space-separated). Reserved: Ctrl+C, Ctrl+D, Ctrl+M.

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

## v2.1.111 (2026-04-16) — Opus 4.7 Era

| Feature | Impact |
|---------|--------|
| **Opus 4.7 xhigh effort** | NEW effort tier between `high` and `max` — `/effort xhigh`, or `--effort xhigh`; other models fallback to `high` |
| **Auto mode native** | No more `--enable-auto-mode` flag — auto mode is now first-class for Max subscribers on Opus 4.7 |
| `/less-permission-prompts` | NEW skill — scans transcripts for common read-only Bash/MCP calls, proposes prioritized allowlist |
| `/ultrareview` | NEW cloud parallel multi-agent code review — `/ultrareview` (current branch) or `/ultrareview <PR#>` (GitHub PR) |
| `/effort` slider | Interactive mode when called without args (arrow keys + Enter) |
| "Auto (match terminal)" theme | Auto dark/light matches terminal — select from `/theme` |
| PowerShell tool | Progressively rolling out on Windows; opt-in via `CLAUDE_CODE_USE_POWERSHELL_TOOL` |
| Read-only bash globs | `ls *.ts` and `cd <proj> && ...` no longer prompt for permission |
| Named plan files | Plan files named after prompt (e.g. `fix-auth-race-snug-otter.md`) instead of random |
| `/skills` sort by tokens | Press `t` in menu to toggle sort by estimated token count |
| `Ctrl+U` behavior | Now clears entire input buffer (was: delete to line start); `Ctrl+Y` restores |
| `Ctrl+L` | Forces full screen redraw + input clear |
| `OTEL_LOG_RAW_API_BODIES` | NEW env var — emit full API request/response as OTel log events (debugging) |

## v2.1.110 (2026-04-15)

| Feature | Impact |
|---------|--------|
| `/tui` command + `tui` setting | `/tui fullscreen` switches to flicker-free rendering in same conversation |
| **Push notification tool** | NEW — Claude sends mobile push notifs when Remote Control + "Push when Claude decides" enabled |
| `Ctrl+O` behavior change | Now toggles normal/verbose transcript only (focus view split to new `/focus` command) |
| `autoScrollEnabled` config | Disable conversation auto-scroll in fullscreen mode |
| `Ctrl+G` editor with context | Option to show Claude's last response as commented context in external editor |
| `/doctor` | Warns when MCP server defined in multiple scopes with different endpoints |
| `--resume`/`--continue` | Resurrects unexpired scheduled tasks |
| `/context`, `/exit`, `/reload-plugins` | Now work from Remote Control (mobile/web) |

## v2.1.108 (2026-04-13)

| Feature | Impact |
|---------|--------|
| `ENABLE_PROMPT_CACHING_1H` | NEW env var — opt into 1-hour prompt cache TTL (API key, Bedrock, Vertex, Foundry). `FORCE_PROMPT_CACHING_5M` to force 5min |
| `/recap` + recap feature | NEW — context when returning to session, configurable via `/config`. `CLAUDE_CODE_ENABLE_AWAY_SUMMARY` for telemetry-disabled users |
| **Skill → built-in slash commands** | Model can now discover/invoke `/init`, `/review`, `/security-review` via Skill tool |
| `/undo` alias for `/rewind` | Mnemonic alias |
| `/model` warning | Warns before switching mid-conversation (next response re-reads full history uncached) |
| `/resume` picker default | Sessions from current directory shown first; `Ctrl+A` to show all projects |

## v2.1.105 (2026-04-12)

| Feature | Impact |
|---------|--------|
| `EnterWorktree path` param | Switch into existing worktree of current repo (not just create new) |
| **PreCompact hook block** | PreCompact hooks can now block compaction via exit code 2 or `{"decision":"block"}` |
| **Plugin `monitors` manifest** | NEW top-level key — background monitors auto-arm at session start or on skill invoke |
| `/proactive` alias for `/loop` | Mnemonic alias |
| Stalled stream abort | API streams abort after 5min no data, retry non-streaming instead of hanging |
| `/doctor` status icons | Press `f` to have Claude fix reported issues |
| Skill description cap raised | 250 → 1,536 chars; startup warning if truncated |
| `WebFetch` `<style>/<script>` strip | CSS-heavy pages no longer exhaust content budget |
| Stale agent worktree cleanup | Removes worktrees of squash-merged PRs (was: kept indefinitely) |

## v2.1.101 (2026-04-11)

| Feature | Impact |
|---------|--------|
| `/team-onboarding` | New — generate teammate ramp-up guide from local CC usage |
| OS CA cert trust | Enterprise TLS proxies work by default (`CLAUDE_CODE_CERT_STORE=bundled` for bundled only) |
| `/ultraplan` auto-env | Auto-creates cloud env, no web setup needed |
| `OTEL_LOG_*` env vars | Beta tracing: `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_TOOL_CONTENT` |
| `API_TIMEOUT_MS` fix | No longer hardcoded 5min — respects env var |
| `context: fork` fix | **Plugin skills can now fork to subagent** |
| `agent` frontmatter fix | **Skill → agent delegation works in plugins** |
| `disallowedTools` enforcement | Better tool-not-available error messages |
| `--resume <name>` | Accepts session titles set via `/rename` or `--name` |
| Settings resilience | Unrecognized hook event in settings.json no longer breaks entire file |
| `allowManagedHooksOnly` | Plugin hooks from force-enabled plugins now run |
| Subagent MCP inheritance | **Subagents inherit MCP tools from dynamic servers** |
| Subagent worktree access | **Read/Edit access in isolated worktrees fixed** |
| `permissions.deny` priority | Deny rules properly override hook `permissionDecision: "ask"` |
| Memory leak fix | Long sessions no longer retain historical message copies |
| Security: POSIX `which` | Command injection vulnerability patched |
| Plugin fixes | `context: fork` and `agent` frontmatter fields honored; duplicate `name:` resolved |

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
