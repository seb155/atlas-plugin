# Claude Code Setup Guide (paired with ATLAS CLI)

Quick reference for installing and configuring Claude Code, including MCP servers and health diagnostics.

## Install Claude Code

**Native binary** (recommended, matches AXOIQ setup):
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Installs to `~/.local/share/claude/versions/<version>`, symlinks `~/.local/bin/claude`.

**NPM alternative** (if you prefer):
```bash
npm install -g @anthropic-ai/claude-code
```

Note: `@anthropic-ai/claude-code` is a pointer package; platform binaries split across `@anthropic-ai/claude-code-{linux,darwin}-{x64,arm64}`.

## First-Run Setup

```bash
claude                             # First run triggers OAuth flow
# → opens browser to claude.ai for login
```

Or use API key:
```bash
claude auth login --api-key <your-anthropic-api-key>
```

## Health Diagnostics — `claude doctor`

```bash
claude doctor
```

Checks:
- Auto-updater health
- MCP server connectivity
- Auth token validity
- Shell integration

## Managing MCP Servers

### List configured servers
```bash
claude mcp list
```

Typical output:
```
claude.ai Excalidraw: https://mcp.excalidraw.com/mcp - ✓ Connected
claude.ai Google Drive: ... - ! Needs authentication
context7: https://mcp.context7.com/mcp - ✓ Connected
```

### Add a server

```bash
# HTTP transport
claude mcp add context7 https://mcp.context7.com/mcp

# HTTP with auth header
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp --header "Authorization: Bearer $TOKEN"

# stdio (local process)
claude mcp add my-server -- npx my-mcp-server

# With env vars
claude mcp add -e API_KEY=xxx my-server -- npx my-mcp-server
```

### Remove / get details
```bash
claude mcp remove <name>
claude mcp get <name>               # show server config
```

### ATLAS MCP Wrapper

Once ATLAS CLI installed, use:
```bash
atlas mcp list                     # Same as claude mcp list, ATLAS-formatted
atlas mcp doctor                   # Health summary with counts
atlas mcp profile chrome-playwright  # Show MCP bundle YAML
```

## Claude Code Settings

Main config: `~/.claude/settings.json`

Key settings for power users:
```json
{
  "env": {
    "NODE_OPTIONS": "--max-old-space-size=8192",
    "MAX_MCP_OUTPUT_TOKENS": "25000",
    "BASH_DEFAULT_TIMEOUT_MS": "600000",
    "BASH_MAX_TIMEOUT_MS": "1800000"
  },
  "permissions": {
    "allow": ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
  },
  "hooks": {
    "UserPromptSubmit": [...],
    "PreToolUse": [...]
  }
}
```

**Warning**: avoid `permissions.allow: ["*"]` — use specific tool allowlist for security.

## Permission Modes

Claude Code launches with a permission mode that controls prompt frequency:

| Mode | Behavior | Use case |
|------|----------|----------|
| `default` | Prompts for risky ops | Interactive daily work |
| `plan` | Plan mode (preview before execute) | Sensitive changes |
| `auto` | Auto-approve safe ops, prompt for risky | Balanced productivity |
| `dontAsk` | Skip prompts (trusted automation) | CI, controlled scripts |
| `acceptEdits` | Auto-accept file edits only | Refactoring sessions |
| `bypassPermissions` | **ZERO** permission checks | ⚠️ Tests only, dangerous |

Pass via `claude --permission-mode <mode>`. ATLAS CLI auto-applies from profiles.

## Troubleshooting

### `claude doctor` reports "update available"
```bash
# Auto-update:
claude doctor --fix               # If available
# OR manual:
curl -fsSL https://claude.ai/install.sh | bash
```

### MCP server won't connect
1. Check auth: `claude mcp get <name>` — verify token/URL
2. Test connectivity: `curl -I <server-url>` (for HTTP MCPs)
3. Remove + re-add: `claude mcp remove <name> && claude mcp add ...`

### Claude hanging on Bash commands
Likely a tool with interactive mode (`--pdb`, `vim`, `nmon`, `docker exec -it`).
Solutions:
- Avoid `-it` or interactive flags in Bash tool calls
- Set `BASH_DEFAULT_TIMEOUT_MS` to reasonable value (e.g. 300000 = 5 min)
- Use `run_in_background: true` for long-running commands

### Session hang / lost context
```bash
claude --resume          # native picker across sessions
# OR
claude -c                # continue last session
# OR via ATLAS:
atlas resume --picker
```

## See Also

- [INSTALL.md](./INSTALL.md) — ATLAS CLI install
- [PROFILE-SYSTEM.md](./PROFILE-SYSTEM.md) — profile schema
- Claude Code docs: <https://docs.claude.com/claude-code>
- MCP specification: <https://modelcontextprotocol.io>
