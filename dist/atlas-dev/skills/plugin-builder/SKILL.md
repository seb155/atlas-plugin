---
name: plugin-builder
description: "Build Claude Code plugins from scratch with correct structure, validation, and publishing. Use when user asks to create/scaffold/build/package/publish a plugin, or needs help with plugin.json, marketplace.json, hooks.json, SKILL.md/AGENT.md frontmatter, or validation errors."
effort: medium
---

# Plugin Builder

Build production-grade Claude Code plugins: scaffold → define → implement → test → validate → publish.

## Directory Structure (CRITICAL)

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json              # REQUIRED — only manifest goes here
├── commands/                     # Slash commands (.md)
├── skills/{name}/SKILL.md        # Reusable skills
├── agents/{name}/AGENT.md        # Specialized subagents
├── hooks/hooks.json + scripts    # Lifecycle handlers
├── .mcp.json                     # MCP servers (optional)
├── .lsp.json                     # LSP servers (optional)
├── settings.json                 # Default settings (optional)
└── README.md
```

**CRITICAL**: Components (`commands/`, `skills/`, `agents/`, `hooks/`) go at plugin ROOT, NOT inside `.claude-plugin/`.

## Quick Start

```bash
mkdir -p my-plugin/.claude-plugin my-plugin/skills/hello
# plugin.json: {"name": "my-plugin", "version": "1.0.0", "description": "..."}
# skills/hello/SKILL.md: frontmatter (name, description) + instructions
claude --plugin-dir ./my-plugin    # Test
claude plugin validate ./my-plugin # Validate
```

## Component Types

| Type | Location | Spec Reference |
|------|----------|----------------|
| Skills | `skills/{name}/SKILL.md` | `references/skill-spec.md` (20+ frontmatter fields) |
| Agents | `agents/{name}/AGENT.md` | `references/agent-spec.md` (15+ frontmatter fields) |
| Commands | `commands/{name}.md` | Simple markdown (legacy, prefer skills) |
| Hooks | `hooks/hooks.json` + scripts | `references/hooks-spec.md` (20+ events) |
| MCP | `.mcp.json` | `references/mcp-lsp-spec.md` |
| LSP | `.lsp.json` | `references/mcp-lsp-spec.md` |

## Key Variables

| Variable | Scope | Description |
|----------|-------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | Hooks, MCP, LSP | Absolute path to plugin install dir |
| `${CLAUDE_PLUGIN_DATA}` | Hooks, MCP, LSP | Persistent data dir |
| `$ARGUMENTS` / `$N` | Skills, Commands | User's arguments (full / Nth) |
| `${CLAUDE_SESSION_ID}` | Skills | Current session ID |
| `${CLAUDE_SKILL_DIR}` | Skills | Directory containing SKILL.md |

## plugin.json

**Required**: `name`. **Recommended**: `version`, `description`, `author`.
**Optional**: `homepage`, `repository`, `license`, `keywords`, component path overrides.
Custom paths supplement defaults, not replace. Full schema → `references/plugin-spec.md`.

## Testing

| Method | Command |
|--------|---------|
| Load local | `claude --plugin-dir ./my-plugin` |
| Hot reload | `/reload-plugins` |
| Debug | `claude --debug` |
| Validate | `claude plugin validate ./my-plugin` |

## Publishing

**Marketplace**: Create `.claude-plugin/marketplace.json` with `{name, owner, plugins[]}` → push to Git → others install via `claude plugin marketplace add <repo-url>`.
**Official**: Submit at `claude.ai/settings/plugins/submit`.
Full schema → `references/plugin-spec.md`.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Components inside `.claude-plugin/` | Move to plugin root |
| Missing `name` in plugin.json | Add `"name"` field |
| Hook not executable | `chmod +x hooks/my-hook` |
| Absolute paths in hooks | Use `${CLAUDE_PLUGIN_ROOT}` |
| Vague skill description | Add specific trigger phrases |
| SKILL.md > 5000 words | Move detail to `references/` |
| `description` at marketplace root | Only in `plugins[].description` |

## HITL Gates

- Before scaffolding → AskUserQuestion: confirm purpose + component needs
- After creating SKILL.md → present for review
- Before publishing → run validation checklist (`references/checklist.md`)
