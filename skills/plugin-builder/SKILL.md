---
name: plugin-builder
description: "Build Claude Code plugins from scratch with correct structure, validation, and publishing. This skill should be used when the user asks to 'create a plugin', 'build a plugin', 'scaffold a plugin', 'make a Claude Code plugin', 'package a plugin', 'publish a plugin', or needs help with plugin.json, marketplace.json, hooks.json, SKILL.md frontmatter, AGENT.md frontmatter, or plugin validation errors."
---

# Plugin Builder

Build production-grade Claude Code plugins. Covers the full lifecycle from scaffold to publish.

## Workflow

```
SCAFFOLD → DEFINE → IMPLEMENT → TEST → VALIDATE → PUBLISH
```

## Directory Structure (CRITICAL)

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json              # REQUIRED — plugin manifest
├── commands/                     # Slash commands (.md files)
├── skills/                       # Reusable skills (dirs with SKILL.md)
│   └── my-skill/
│       ├── SKILL.md
│       └── references/
├── agents/                       # Specialized agents (AGENT.md)
│   └── my-agent/
│       └── AGENT.md
├── hooks/                        # Hook scripts + hooks.json
│   ├── hooks.json
│   └── session-start
├── .mcp.json                     # MCP server configs (optional)
├── .lsp.json                     # LSP server configs (optional)
├── settings.json                 # Default settings (optional)
└── README.md
```

**CRITICAL**: Components (`commands/`, `skills/`, `agents/`, `hooks/`) go at the plugin ROOT, NOT inside `.claude-plugin/`. Only `plugin.json` goes in `.claude-plugin/`.

## Quick Start (Minimal Viable Plugin)

### Step 1 — Scaffold

```bash
mkdir -p my-plugin/.claude-plugin my-plugin/skills/hello
```

### Step 2 — plugin.json

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "What this plugin does"
}
```

Only `name` is required. `version` and `description` are strongly recommended.

### Step 3 — First Skill

`skills/hello/SKILL.md`:
```yaml
---
name: hello
description: "Greet the user. Use when user says 'hello', 'hi', 'hey'."
---

Greet the user warmly and ask how to help today.
```

### Step 4 — Test

```bash
claude --plugin-dir ./my-plugin
# Then: /my-plugin:hello
```

### Step 5 — Validate

```bash
claude plugin validate ./my-plugin
```

## Component Types

| Type | Location | Purpose | Spec |
|------|----------|---------|------|
| **Skills** | `skills/{name}/SKILL.md` | Reusable instruction sets | [skill-spec.md](references/skill-spec.md) |
| **Agents** | `agents/{name}/AGENT.md` | Specialized subagents with model control | [agent-spec.md](references/agent-spec.md) |
| **Commands** | `commands/{name}.md` | Slash command shortcuts | Simple markdown |
| **Hooks** | `hooks/hooks.json` + scripts | Lifecycle event handlers | [hooks-spec.md](references/hooks-spec.md) |
| **MCP** | `.mcp.json` | Model Context Protocol servers | [mcp-lsp-spec.md](references/mcp-lsp-spec.md) |
| **LSP** | `.lsp.json` | Language Server Protocol servers | [mcp-lsp-spec.md](references/mcp-lsp-spec.md) |

### Skills vs Commands

| Feature | Skill (`SKILL.md`) | Command (`.md`) |
|---------|---------------------|-----------------|
| Supporting files | Yes (references/, scripts/, examples/) | No |
| Frontmatter fields | 20+ (model, context, agent, hooks...) | Limited (description, argument-hint) |
| Progressive disclosure | 3 levels (metadata → body → references) | 1 level |
| Recommendation | **Preferred** | Legacy / simple routing |

## Key Variables

| Variable | Scope | Description |
|----------|-------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | Hooks, MCP, LSP | Absolute path to plugin install dir |
| `${CLAUDE_PLUGIN_DATA}` | Hooks, MCP, LSP | Persistent data dir (`~/.claude/plugins/data/{id}/`) |
| `$ARGUMENTS` | Skills, Commands | User's arguments |
| `$ARGUMENTS[N]` / `$N` | Skills, Commands | Nth argument (0-based) |
| `${CLAUDE_SESSION_ID}` | Skills | Current session ID |
| `${CLAUDE_SKILL_DIR}` | Skills | Directory containing SKILL.md |

## plugin.json Deep Dive

See [plugin-spec.md](references/plugin-spec.md) for all fields.

**Required**: `name`
**Recommended**: `version`, `description`, `author`
**Optional**: `homepage`, `repository`, `license`, `keywords`, `commands`, `agents`, `skills`, `hooks`, `mcpServers`, `outputStyles`, `lspServers`

Custom component paths **supplement** defaults — they don't replace them.

## Testing

| Method | Command | Use Case |
|--------|---------|----------|
| Load local plugin | `claude --plugin-dir ./my-plugin` | Development |
| Hot reload | `/reload-plugins` | After editing files |
| Debug mode | `claude --debug` | See loading details |
| Validate structure | `claude plugin validate ./my-plugin` | Pre-publish check |

## Publishing

### Via Marketplace

1. Create `marketplace.json` at `.claude-plugin/marketplace.json`:

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Author", "email": "dev@example.com" },
  "plugins": [
    {
      "name": "my-plugin",
      "description": "What it does",
      "version": "1.0.0",
      "source": "./"
    }
  ]
}
```

2. Push to Git repo
3. Others install: `claude plugin marketplace add <repo-url>`
4. Then: `claude plugin install my-plugin@my-marketplace`

### Via Official Submission

Submit at [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit)

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Components inside `.claude-plugin/` | Move `commands/`, `skills/`, `agents/`, `hooks/` to plugin root |
| Missing `name` in plugin.json | Add `"name": "my-plugin"` |
| Hook script not executable | `chmod +x hooks/my-hook` |
| Absolute paths in hooks | Use `${CLAUDE_PLUGIN_ROOT}` |
| Vague skill description | Add specific trigger phrases in quotes |
| SKILL.md over 5000 words | Move detail to `references/` subdirectory |
| marketplace.json has extra keys | Only `name`, `owner`, `plugins` at root level |
| Forgot to bump version | Update `version` in plugin.json before publishing |
| `"description"` at marketplace root | Not allowed — only in `plugins[].description` |

## Reference Files

For detailed specifications, load on demand:

| File | Content |
|------|---------|
| [plugin-spec.md](references/plugin-spec.md) | plugin.json + marketplace.json full schema |
| [skill-spec.md](references/skill-spec.md) | SKILL.md 20+ frontmatter fields |
| [agent-spec.md](references/agent-spec.md) | AGENT.md 15+ frontmatter fields |
| [hooks-spec.md](references/hooks-spec.md) | 20+ hook events, types, I/O |
| [mcp-lsp-spec.md](references/mcp-lsp-spec.md) | MCP and LSP server configuration |
| [checklist.md](references/checklist.md) | Pre-publish validation checklist |

## HITL Gates

- Before scaffolding → confirm plugin purpose and component needs via AskUserQuestion
- After creating SKILL.md → present for review
- Before publishing → run validation checklist
