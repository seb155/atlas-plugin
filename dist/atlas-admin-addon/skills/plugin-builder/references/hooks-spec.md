# Hook Events & Configuration Reference

Complete specification for all hook events, types, and I/O.

---

## Overview

Hooks allow plugins to react to lifecycle events in Claude Code. They can inspect, modify, or block operations. Hooks are defined in `hooks/hooks.json` and reference executable scripts in the `hooks/` directory.

---

## Hook Events

### Session Lifecycle

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `SessionStart` | Session begins | No | Runs when a new Claude Code session starts. Use for setup, loading configs, greeting. |
| `SessionEnd` | Session ends | No | Runs when the session is closing. Use for cleanup, saving state, summary. |
| `Stop` | Agent stops (normal) | No | Runs when the agent completes its response normally. |
| `StopFailure` | Agent stops (error) | No | Runs when the agent stops due to an error or failure. |

### User Input

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `UserPromptSubmit` | User sends a message | No | Runs after the user submits a prompt but before processing. Can inject context (timestamps, metadata). |
| `Elicitation` | Agent asks user a question | No | Runs when the agent presents a question to the user. |
| `ElicitationResult` | User answers a question | No | Runs when the user responds to an elicitation. |

### Tool Lifecycle

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `PreToolUse` | Before a tool executes | **Yes** | Runs before any tool call. Can BLOCK the tool from executing (exit code 2). Use for validation, safety checks, approval gates. |
| `PostToolUse` | After a tool succeeds | No | Runs after a tool call completes successfully. Use for logging, auditing, post-processing. |
| `PostToolUseFailure` | After a tool fails | No | Runs after a tool call fails. Use for error tracking, fallback logic. |
| `PermissionRequest` | Permission prompt shown | No | Runs when Claude requests permission from the user (e.g., to write a file). |

### Subagent Lifecycle

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `SubagentStart` | Subagent spawned | No | Runs when a subagent (forked skill, delegated agent) begins execution. |
| `SubagentStop` | Subagent finishes | No | Runs when a subagent completes its work. |

### Configuration & Memory

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `ConfigChange` | Settings changed | No | Runs when Claude Code configuration changes during a session. |
| `InstructionsLoaded` | CLAUDE.md or rules loaded | No | Runs when instruction files are loaded or reloaded. |

### Tasks

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `TaskCompleted` | A task is marked complete | No | Runs when a task in the task list is marked as completed. |
| `TeammateIdle` | A teammate agent becomes idle | No | Runs when a teammate agent finishes work and becomes available. |

### Context Management

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `PreCompact` | Before context compaction | No | Runs before the context window is compacted. Use to save critical state. |
| `PostCompact` | After context compaction | No | Runs after compaction. Use to re-inject critical context that may have been lost. |

### Git Worktrees

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `WorktreeCreate` | Before worktree creation | **Yes** | Runs before a Git worktree is created. Can BLOCK creation (exit code 2). Use for validation, naming conventions. |
| `WorktreeRemove` | Before worktree removal | No | Runs before a Git worktree is removed. Use for cleanup. |

### Notifications

| Event | Trigger | Can Block? | Description |
|-------|---------|------------|-------------|
| `Notification` | System notification | No | Runs when Claude Code generates a notification (e.g., task complete, error). |

---

## Hook Types

### 1. Command Hook

Executes a shell command or script.

```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/my-script.sh"
}
```

The script receives event data via **stdin** as JSON. Exit codes control behavior:
- `0` — Allow (success)
- `2` — Block (only for `PreToolUse` and `WorktreeCreate`)
- Any other — Error (logged, does not block)

### 2. HTTP Hook

Sends a POST request to a URL.

```json
{
  "type": "http",
  "url": "https://api.example.com/hooks/claude",
  "headers": {
    "Authorization": "Bearer ${MY_API_KEY}"
  }
}
```

The event data is sent as the JSON request body. Response status 200 = allow, 403 = block.

### 3. Prompt Hook

Injects a prompt into Claude's context. Does not execute external code.

```json
{
  "type": "prompt",
  "prompt": "Before running any bash command, verify it does not delete files or modify system configuration."
}
```

Prompt hooks are the simplest type — they add instructions to Claude's context when the event fires.

### 4. Agent Hook

Delegates to a named agent.

```json
{
  "type": "agent",
  "agent": "safety-reviewer"
}
```

The specified agent processes the event and can provide feedback or make decisions.

---

## Matcher (Filtering)

The `matcher` field filters which specific instances of an event trigger the hook. Most commonly used with `PreToolUse` and `PostToolUse`.

```json
{
  "matcher": "Bash",
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-bash.sh"
}
```

| Event | Matcher Value | Description |
|-------|---------------|-------------|
| `PreToolUse` | Tool name (`Bash`, `Write`, `Edit`) | Only fires for that specific tool |
| `PostToolUse` | Tool name | Same as above |
| `PostToolUseFailure` | Tool name | Same as above |
| Other events | — | Matcher not typically used |

---

## hooks.json Format

Location: `hooks/hooks.json`

The file is a JSON object where keys are event names and values are arrays of hook definitions.

```json
{
  "SessionStart": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Bash",
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-bash.sh"
    },
    {
      "matcher": "Write",
      "type": "prompt",
      "prompt": "Ensure the file being written follows project conventions."
    }
  ],
  "PostToolUse": [
    {
      "matcher": "Bash",
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/log-bash.sh"
    }
  ],
  "SessionEnd": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/cleanup.sh"
    }
  ]
}
```

Multiple hooks can be registered for the same event. They execute in order.

---

## Hook I/O (Command Type)

### Input (stdin)

Command hooks receive a JSON object on stdin with event-specific data:

#### PreToolUse / PostToolUse

```json
{
  "event": "PreToolUse",
  "tool": "Bash",
  "parameters": {
    "command": "rm -rf /tmp/test",
    "description": "Remove temporary directory"
  },
  "sessionId": "abc123",
  "timestamp": "2026-03-18T14:30:00Z"
}
```

#### SessionStart

```json
{
  "event": "SessionStart",
  "sessionId": "abc123",
  "workingDirectory": "/home/user/project",
  "timestamp": "2026-03-18T14:30:00Z"
}
```

#### UserPromptSubmit

```json
{
  "event": "UserPromptSubmit",
  "prompt": "Fix the login bug",
  "sessionId": "abc123",
  "timestamp": "2026-03-18T14:30:00Z"
}
```

### Output (Exit Codes)

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| `0` | Allow / Success | Operation proceeds normally |
| `2` | Block | **Only for `PreToolUse` and `WorktreeCreate`**. Prevents the operation. |
| Other | Error | Logged as a hook error. Operation proceeds. |

### Structured Output (stdout)

Command hooks can write JSON to stdout to provide additional context:

```json
{
  "message": "Blocked: command attempts to delete system files",
  "metadata": {
    "reason": "safety",
    "rule": "no-system-delete"
  }
}
```

For `PreToolUse` with exit code 2, the `message` field is shown to the user explaining why the tool call was blocked.

---

## Complete Example: Safety-First Plugin

```
hooks/
├── hooks.json
├── session-start.sh
├── validate-bash.sh
└── log-activity.sh
```

**hooks.json**:
```json
{
  "SessionStart": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"
    },
    {
      "type": "prompt",
      "prompt": "This project uses strict safety controls. All destructive operations require explicit confirmation."
    }
  ],
  "PreToolUse": [
    {
      "matcher": "Bash",
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-bash.sh"
    }
  ],
  "PostToolUse": [
    {
      "type": "command",
      "command": "${CLAUDE_PLUGIN_ROOT}/hooks/log-activity.sh"
    }
  ],
  "UserPromptSubmit": [
    {
      "type": "prompt",
      "prompt": "Timestamp: $(date '+%Y-%m-%d %H:%M %Z')"
    }
  ],
  "PreCompact": [
    {
      "type": "prompt",
      "prompt": "CRITICAL: Preserve all modified file paths, current branch, and test commands used."
    }
  ]
}
```

**hooks/validate-bash.sh**:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Read event data from stdin
EVENT=$(cat)
COMMAND=$(echo "$EVENT" | jq -r '.parameters.command // ""')

# Block dangerous commands
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "mkfs"
  "dd if="
  "> /dev/sda"
  "chmod -R 777"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if [[ "$COMMAND" == *"$pattern"* ]]; then
    echo '{"message": "Blocked: command matches dangerous pattern '\"$pattern\"'"}'
    exit 2
  fi
done

exit 0
```

**hooks/session-start.sh**:
```bash
#!/usr/bin/env bash
echo '{"message": "Session initialized with safety controls active."}'
exit 0
```

**hooks/log-activity.sh**:
```bash
#!/usr/bin/env bash
EVENT=$(cat)
TOOL=$(echo "$EVENT" | jq -r '.tool // "unknown"')
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Append to activity log
echo "{\"tool\": \"$TOOL\", \"timestamp\": \"$TIMESTAMP\"}" >> "${CLAUDE_PLUGIN_DATA}/activity.log"
exit 0
```

**IMPORTANT**: All hook scripts must be executable (`chmod +x hooks/*.sh`).

---

## Skill-Scoped vs Global Hooks

| Scope | Location | Fires When |
|-------|----------|------------|
| **Global** | `hooks/hooks.json` | Always, for all operations |
| **Skill-scoped** | `hooks:` in SKILL.md frontmatter | Only when that skill is active |
| **Agent-scoped** | `hooks:` in AGENT.md frontmatter | Only when that agent is active |

Skill and agent-scoped hooks use the same syntax as global hooks but are defined inline in the frontmatter YAML.
