---
name: cc-native-features
description: "Claude Code v2.1.111 native features reference — effort system, session management, auto-memory, worktrees, task management, hooks, agent frontmatter, plugin settings, keyboard shortcuts, statusline. SSoT for CC capabilities that ATLAS leverages."
---

# Claude Code Native Features Reference (v2.1.111)

> SSoT for CC features ATLAS leverages. Updated: 2026-04-16 (Opus 4.7 GA).
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

**`/effort` interactive slider** (v2.1.111): Call with no args → arrow-key + Enter.
**Per-turn override**: `ultrathink` keyword = max effort one turn (v2.1.68).
**Frontmatter**: `effort: low|medium|high|xhigh` in AGENT.md (v2.1.78) and SKILL.md (v2.1.80).
**Rule**: Opus = high/xhigh default | Sonnet = medium | Haiku = low. Non-Opus fallback `xhigh` → `high`.

## Session Management

| Command | Version | Purpose |
|---------|---------|---------|
| `/rename [name]` | v2.0.64 | Name session (auto-generates if no arg, v2.1.72) |
| `/color [color]` | v2.1.75 | Set prompt-bar color. `/color default` to reset |
| `/resume [name]` | v2.0.93 | Resume by name, ID, or pick from list |
| `/branch` | v2.1.77 | Fork conversation (alias: `/fork`) |
| `-n "name"` | v2.1.76 | Name session at CLI launch |
| `--session-id` | v2.0.73 | Custom session ID for forking |
| `--from-pr` | v2.1.27 | Resume session linked to a PR |

**Auto-naming**: From plan content (v2.1.77) or first prompt.

## Task Management (v2.1.16)

| Tool | Purpose |
|------|---------|
| `TaskCreate` | Create with subject, description, activeForm |
| `TaskUpdate` | Update status, owner, dependencies, or delete |
| `TaskGet` | Get full details by ID |
| `TaskList` | List all with status |

**Dependencies**: `addBlocks`, `addBlockedBy` fields. **Delete**: `status: "deleted"` in TaskUpdate. **Statuses**: `pending` → `in_progress` → `completed`.

## Auto-Memory (v2.1.32/v2.1.59)

- Auto-saves to `~/.claude/projects/{project}/memory/`
- `/memory` command to manage
- `autoMemoryDirectory` setting for custom location (v2.1.74)
- `MEMORY.md` index (max 200 lines / 25KB)
- Topic files with frontmatter (name, description, type)
- Last-modified timestamps (v2.1.75)
- Memory shared across worktrees of same repo (v2.1.63)

**ATLAS integration**: `memory-dream` skill implements CC auto-dream pattern.

## Worktrees (v2.1.49+)

| Feature | Version | Purpose |
|---------|---------|---------|
| `claude -w name` | v2.1.49 | Start in isolated git worktree |
| `EnterWorktree` tool | v2.1.49 | Create mid-session |
| `ExitWorktree` tool | v2.1.72 | Leave (keep or remove) |
| `isolation: "worktree"` | v2.1.49 | Agent frontmatter for isolation |
| `worktree.sparsePaths` | v2.1.76 | Partial checkout for monorepos |

**Statusline field**: `worktree` object with name, path, branch, original_dir (v2.1.69).

## Plan Mode

| Feature | Version | Notes |
|---------|---------|-------|
| `EnterPlanMode` | v1.0.33 | Read-only exploration + design |
| `ExitPlanMode` | v1.0.33 | Present plan for approval |
| `/plan [description]` | v2.1.72 | Shortcut with optional prompt |
| `plansDirectory` | v2.1.9 | Custom plan file location |
| `showClearContextOnPlanAccept` | v2.1.69 | Show "clear context" after approval |

**ATLAS integration**: `plan-builder` skill generates 15-section plans (A-O format).

## Compaction

- Auto-compacts at configurable % (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, default 80%)
- `PreCompact` hook: inject context to preserve (v1.0.48)
- `PostCompact` hook: restore critical state (v2.1.76)
- Images survive (v2.1.72+); text nuances may be lost — use memory files for critical info
- `/compact` manual trigger; "Summarize from here" partial (v2.1.32)

**1M optimization**: Set autocompact to 92% (920K/1M) for max context before compact.

## Context Window

| Model | Window | Max Output | Notes |
|-------|--------|------------|-------|
| Opus 4.7 | 1M | 128K | Default for Max (v2.1.111+) |
| Sonnet 4.6 | 1M | 128K | Same window, faster |
| Haiku 4.5 | 200K | 64K | Smaller, cheapest |

**Rule**: With 1M context, NEVER suggest session handoff for context reasons.

## Adaptive Thinking (formerly Extended Thinking)

- **API change 2026-04**: Opus 4.7 deprecated explicit thinking-enabled mode + token budgets. Only adaptive (`{"type": "adaptive"}` or via effort).
- Opus 4.7: adaptive enabled by default (v2.0.67); new `xhigh` tier (v2.1.111+, between `high` and `max`)
- `ultrathink` = max effort for one turn
- Budget scales with `/effort` (CC layer, not API)
- Toggle: Alt+T (v2.0.72), or `/config`
- `CLAUDE_CODE_MAX_THINKING_TOKENS` env var (CC client hint, not API budget)
- Sonnet 4.6 still supports legacy extended thinking API; ATLAS standardizes on adaptive

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

- Up to 4 questions per call, each 2-4 options + auto "Other"
- `multiSelect: true` for checkboxes
- `preview` field for code/mockup comparison
- `header` for short label (max 12 chars)

**ATLAS rule**: ALWAYS use AskUserQuestion, never free-text questions.

## Keyboard Shortcuts (v2.1.18)

**File**: `~/.claude/keybindings.json` — auto-detected on change, no restart.

**Format**: context-based binding blocks (NOT `{ key, command }`):
```json
{
  "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
  "bindings": [
    { "context": "Chat", "bindings": { "ctrl+shift+f": "chat:fastMode" } }
  ]
}
```

**Contexts**: `Global` | `Chat` | `Autocomplete` | `Confirmation` | `Transcript` | `HistorySearch` | `Task` | `ThemePicker` | `Attachments` | `Footer` | `MessageSelector` | `DiffDialog` | `ModelPicker` | `Select` | `Plugin` | `Settings` | `Help` | `Tabs`

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

`null` = unbind | Chords: `"ctrl+k ctrl+s"` (space-separated) | Reserved: Ctrl+C, Ctrl+D, Ctrl+M.

## Statusline

**Input JSON fields**: `workspace.current_dir` (v1.0.71, str) | `model.id` (v1.0.71, str) | `session_name` (v2.0.64, str) | `context_window.used_percentage` / `.remaining_percentage` (v2.1.6, num) | `current_usage` (v2.0.70, num) | `rate_limits["5h"].used_percentage` / `.resets_at` (v2.1.80) | `rate_limits["7d"].used_percentage` (v2.1.80) | `effort` (v2.1.72, str) | `worktree` (v2.1.69, obj) | `exceeds_200k_tokens` (v1.0.88, bool)

## Scheduled Execution

| Feature | Scope | Persistence |
|---------|-------|-------------|
| `CronCreate` | Session | Dies on Claude exit (7-day auto-expire) |
| `CronDelete` | Session | Remove by job ID |
| `CronList` | Session | List all scheduled jobs |
| `/loop interval cmd` | Session | Recurring slash command (v2.1.71) |
| Remote Triggers | Cloud | Persists across sessions (v2.0.48) |

## Hook Events (v2.1.83 complete — 22 events)

Session: `SessionStart` (v1.0.62) | `SessionEnd` (v1.0.85) | `Setup` (v2.1.10, --init/--maintenance)
Tool: `PreToolUse` / `PostToolUse` (v1.0.38) | `PermissionRequest` (v2.1.45)
Compact: `PreCompact` (v1.0.48) | `PostCompact` (v2.1.76)
User: `UserPromptSubmit` (v1.0.54) | `Notification` (v1.0.41)
Subagent: `SubagentStart` (v2.0.43) | `SubagentStop` (v1.0.41) | `TeammateIdle` (v2.1.33)
Lifecycle: `Stop` (v1.0.38) | `StopFailure` (v2.1.78) | `TaskCompleted` (v2.1.33)
Config: `InstructionsLoaded` (v2.1.69, CLAUDE.md/rules) | `ConfigChange` (v2.1.41)
File: `CwdChanged` / `FileChanged` (v2.1.81)
Worktree: `WorktreeCreate` / `WorktreeRemove` (v2.1.50)

## Recent Releases (April 2026 — Opus 4.7 Era)

### v2.1.111 (2026-04-16)
- **Opus 4.7 `xhigh` effort** — NEW tier between `high` and `max` (other models fallback to `high`)
- **Auto mode native** — No more `--enable-auto-mode` flag, first-class for Max on Opus 4.7
- `/less-permission-prompts` — NEW skill, scans transcripts for read-only Bash/MCP
- `/ultrareview` — NEW cloud parallel multi-agent review (current branch or `<PR#>`)
- `/effort` interactive slider when called without args (arrows + Enter)
- "Auto (match terminal)" theme
- PowerShell tool (Windows rollout, opt-in `CLAUDE_CODE_USE_POWERSHELL_TOOL`)
- Read-only bash globs (`ls *.ts`, `cd <proj> && ...`) no permission prompt
- Named plan files (e.g. `fix-auth-race-snug-otter.md`)
- `/skills` sort by tokens (press `t`); `Ctrl+U` clears entire buffer (`Ctrl+Y` restores); `Ctrl+L` redraws
- `OTEL_LOG_RAW_API_BODIES` — full API req/res as OTel events

### v2.1.110 (2026-04-15)
- `/tui` + `/tui fullscreen` (flicker-free rendering)
- **Push notification tool** — mobile push when Remote Control + "Push when Claude decides"
- `Ctrl+O` toggles normal/verbose transcript (focus split to `/focus`)
- `autoScrollEnabled`, `Ctrl+G` with last response as comment context
- `/doctor` warns on MCP server in multiple scopes; `--resume`/`--continue` resurrect scheduled tasks
- `/context`, `/exit`, `/reload-plugins` work from Remote Control

### v2.1.108 (2026-04-13)
- `ENABLE_PROMPT_CACHING_1H` — 1h prompt cache TTL (API/Bedrock/Vertex/Foundry); `FORCE_PROMPT_CACHING_5M` to force 5min
- `/recap` + `CLAUDE_CODE_ENABLE_AWAY_SUMMARY`
- **Skill → built-in commands** — Model discovers `/init`, `/review`, `/security-review` via Skill tool
- `/undo` alias for `/rewind`; `/model` warns before mid-conversation switch; `/resume` picker shows current dir first

### v2.1.105 (2026-04-12)
- `EnterWorktree path` switch into existing worktree
- **PreCompact hook block** via exit 2 or `{"decision":"block"}`
- **Plugin `monitors` manifest** — auto-arm background monitors at session start or skill invoke
- `/proactive` alias for `/loop`; stalled stream abort 5min; `/doctor` press `f` to fix
- Skill description cap 250 → 1,536 chars; `WebFetch` strips `<style>/<script>`; stale agent worktree cleanup

### v2.1.101 (2026-04-11)
- `/team-onboarding`; OS CA cert trust (`CLAUDE_CODE_CERT_STORE=bundled`)
- `OTEL_LOG_*` beta tracing (USER_PROMPTS, TOOL_DETAILS, TOOL_CONTENT)
- `API_TIMEOUT_MS` no longer hardcoded; `context: fork` fix → **plugin skills can fork to subagent**
- `agent` frontmatter → **skill → agent delegation works in plugins**
- **Subagents inherit MCP tools from dynamic servers**; **Read/Edit in isolated worktrees fixed**
- `--resume <name>` accepts titles; settings resilient to unrecognized hook events
- `permissions.deny` overrides hook `permissionDecision: "ask"`
- Memory leak fix; POSIX `which` injection vuln patched

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

ATLAS leverages these for self-improvement:

1. **Version detection**: `session-start` hook compares CC version with `KNOWN_CC_VERSION`
2. **Platform update**: `/atlas platform-update` parses `/release-notes` → identifies gaps
3. **Memory dream**: `/atlas dream` consolidates session lessons into memory
4. **Feedback loop**: PostToolUse hooks detect anti-patterns → inject corrections
5. **Recursive learning**: Each audit enriches this reference → next audit is better
