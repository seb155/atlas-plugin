# AGENT.md Frontmatter Reference

Complete specification for all AGENT.md frontmatter fields and configuration.

---

## File Location

```
agents/{agent-name}/AGENT.md
```

Each agent lives in its own directory under `agents/`. The directory name is used as a fallback identifier, but the `name` field in frontmatter is authoritative.

---

## Frontmatter Fields

All fields are specified in YAML frontmatter between `---` delimiters.

### Identity (Required)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | **Required** | Agent identifier. Kebab-case. Must be unique within the plugin. |
| `description` | `string` | **Required** | When and why to use this agent. Used by the orchestrator to decide delegation. |

### Tool Control

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `tools` | `string` | All tools | Comma-separated allowlist of tool names this agent can use. Only these tools are available. Example: `"Bash, Read, Write, Edit, Grep, Glob"` |
| `disallowedTools` | `string` | — | Comma-separated denylist of tool names. Agent can use all tools EXCEPT these. Mutually exclusive with `tools`. Example: `"WebSearch, WebFetch"` |

**Rule**: Use `tools` (allowlist) OR `disallowedTools` (denylist), never both. If neither is set, the agent has access to all tools.

### Subagent Delegation

```yaml
tools: "Agent(reviewer, deployer), Bash, Read"
```

The `Agent(name1, name2)` syntax restricts which subagents this agent can delegate to. Without this restriction, an agent can delegate to any available agent.

### Model & Execution

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `model` | `string` | `inherit` | Which model runs this agent. Values: `sonnet`, `opus`, `haiku`, `inherit`, or a full model ID like `claude-sonnet-4-20250514`. |
| `maxTurns` | `number` | — | Maximum number of tool-use turns before the agent stops. Safety limit to prevent runaway agents. |
| `permissionMode` | `string` | `default` | How the agent handles permission prompts (see Permission Modes below). |
| `thinking_mode` | `string` | `adaptive` | Thinking mode for the agent. Opus 4.7+ requires `adaptive` (extended thinking API deprecated 2026-04). Sonnet 4.6 still supports `extended` but ATLAS standardizes on `adaptive`. |
| `background` | `boolean` | `false` | When `true`, the agent runs in the background. User can continue working while the agent processes. |

### Permission Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `default` | Normal permission prompts for sensitive operations | General purpose agents |
| `acceptEdits` | Auto-accepts file edits without prompting | Code generation agents |
| `dontAsk` | Skips permission prompts (reads/writes) | Trusted automation agents |
| `bypassPermissions` | Bypasses all permission checks | Fully automated pipelines (use with caution) |
| `plan` | Plan mode — agent can only read and plan, no mutations | Research/analysis agents |

**Security note**: `bypassPermissions` should only be used for well-tested, trusted agents with restricted tool access.

### Context & Memory

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `skills` | `array` | — | Skill names to preload into the agent's context. Example: `["code-review", "testing"]` |
| `mcpServers` | `array` | — | MCP server names to make available to this agent. |
| `memory` | `string` | — | Memory scope. Values: `user` (user-level memory), `project` (project-level), `local` (session-only). |

### Isolation

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `isolation` | `string` | — | Set to `worktree` to run the agent in an isolated Git worktree. Changes are isolated from the main branch. |

### Appearance

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `color` | `string` | — | Badge color for the agent in the UI. CSS color value. Example: `"#4CAF50"`, `"blue"` |

### Hooks (Agent-Scoped)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `hooks` | `object` | — | Lifecycle hooks scoped to this agent. Same format as global hooks but only fire when this agent is active. |

---

## Body Content

Below the frontmatter, write the agent's system instructions in markdown. This is the agent's persona and behavioral guidelines.

### Structure Recommendations

1. **Role statement** — Who is this agent? What expertise does it have?
2. **Responsibilities** — What does it do?
3. **Constraints** — What must it avoid?
4. **Process** — Step-by-step workflow
5. **Output format** — How to present results

---

## Complete Examples

### Code Review Agent

```yaml
---
name: reviewer
description: "Review code changes for bugs, security issues, and best practices. Delegated to by the main agent when code review is needed."
model: sonnet
tools: "Read, Glob, Grep, Bash"
permissionMode: plan
maxTurns: 20
color: "#FF9800"
---

# Code Reviewer

You are an expert code reviewer. Analyze code changes for:

## Checklist

1. **Correctness** — Logic errors, edge cases, null handling
2. **Security** — Injection, auth bypass, data exposure
3. **Performance** — N+1 queries, unnecessary allocations, missing indexes
4. **Maintainability** — Naming, complexity, DRY violations
5. **Testing** — Missing test cases, untested branches

## Process

1. Read the changed files using Glob and Read
2. Understand the context (what problem is being solved)
3. Analyze each file against the checklist
4. Present findings in a structured table

## Output

| Severity | File:Line | Issue | Suggestion |
|----------|-----------|-------|------------|

Severity: CRITICAL > HIGH > MEDIUM > LOW > INFO
```

### Deployment Agent

```yaml
---
name: deployer
description: "Handle deployment operations. Use for staging and production deployments."
model: sonnet
tools: "Bash, Read, Grep"
permissionMode: default
maxTurns: 30
isolation: worktree
skills: ["deploy-checklist"]
hooks:
  PreToolUse:
    - matcher: Bash
      type: prompt
      prompt: "This agent is about to run a bash command in a deployment context. Verify it is safe and targets the correct environment."
color: "#F44336"
---

# Deployment Agent

You handle deployments to staging and production environments.

## Safety Rules (NON-NEGOTIABLE)

- NEVER deploy to production without explicit user confirmation
- ALWAYS run health checks after deployment
- ALWAYS verify the target environment before executing commands
- Roll back immediately if health checks fail

## Process

1. Identify target environment (staging/production)
2. Run pre-deploy checks (tests green, version bumped)
3. Execute deployment commands
4. Run health checks
5. Report status
```

### Research Agent (Background)

```yaml
---
name: researcher
description: "Conduct background research on technical topics. Runs asynchronously while the user continues working."
model: opus
tools: "WebSearch, WebFetch, Read, Write"
disallowedTools: "Edit, Bash"
background: true
maxTurns: 50
thinking_mode: adaptive  # Opus 4.7+ requires adaptive mode (extended thinking API deprecated)
memory: project
color: "#2196F3"
---

# Research Agent

You are a thorough technical researcher. When given a topic:

1. Decompose into 3-5 sub-questions
2. Search each with multiple queries
3. Cross-reference sources
4. Write a comprehensive report

Save output to `.research/{topic-slug}.md`.
```

### Minimal Agent

```yaml
---
name: formatter
description: "Format code files according to project standards."
tools: "Read, Write, Edit, Bash"
permissionMode: acceptEdits
maxTurns: 10
---

Format the specified files according to the project's linting and formatting rules. Run the project's formatter if available, otherwise apply standard formatting.
```

---

## Agent vs Skill: When to Use Which

| Feature | Agent | Skill |
|---------|-------|-------|
| Own model selection | Yes | Yes |
| Tool restrictions | Allowlist + denylist | Allowlist only |
| Permission control | 5 modes | No |
| Background execution | Yes | No |
| Git isolation (worktree) | Yes | No |
| Turn limits | Yes | No |
| Preload other skills | Yes | No |
| Memory scope | Yes | No |
| Subagent delegation | Yes (via `Agent()`) | No |
| Best for | Autonomous multi-step workflows | Focused instruction sets |

**Rule of thumb**: Use a **skill** for instructions that augment the main agent. Use an **agent** for autonomous workflows that need their own model, tools, or isolation.
