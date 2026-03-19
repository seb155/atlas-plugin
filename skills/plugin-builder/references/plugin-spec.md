# Plugin & Marketplace Manifest Specification

Complete schema reference for `plugin.json` and `marketplace.json`.

---

## plugin.json

Location: `.claude-plugin/plugin.json` (REQUIRED)

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Plugin identifier. Must be kebab-case, lowercase, no spaces. Example: `"my-awesome-plugin"` |

### Metadata Fields (Recommended)

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `version` | `string` | Recommended | Semver version | `"1.0.0"` |
| `description` | `string` | Recommended | What this plugin does (1-2 sentences) | `"Engineering toolbox for I&C design"` |
| `author` | `object` | Recommended | Author info (see below) | See Author Object |
| `homepage` | `string` | Optional | URL to plugin homepage | `"https://example.com/my-plugin"` |
| `repository` | `string` | Optional | URL to source repository | `"https://github.com/user/my-plugin"` |
| `license` | `string` | Optional | SPDX license identifier | `"MIT"` |
| `keywords` | `string[]` | Optional | Discovery tags | `["engineering", "testing"]` |

### Author Object

```json
{
  "author": {
    "name": "Jane Doe",
    "email": "jane@example.com",
    "url": "https://janedoe.dev"
  }
}
```

All author sub-fields are optional. Can also be a simple string: `"author": "Jane Doe <jane@example.com>"`.

### Component Path Fields

These fields point to directories or files containing plugin components. Paths are **relative** to the plugin root (use `./` prefix). Custom paths **supplement** defaults — they do NOT replace the standard directories.

| Field | Type | Default Location | Description |
|-------|------|-----------------|-------------|
| `commands` | `string \| string[]` | `commands/` | Slash command markdown files |
| `skills` | `string \| string[]` | `skills/` | Skill directories (each with SKILL.md) |
| `agents` | `string \| string[]` | `agents/` | Agent directories (each with AGENT.md) |
| `hooks` | `string \| string[]` | `hooks/` | Hook scripts + hooks.json |
| `mcpServers` | `string \| string[]` | `.mcp.json` | MCP server configurations |
| `lspServers` | `string \| string[]` | `.lsp.json` | LSP server configurations |
| `outputStyles` | `string \| string[]` | N/A | Custom output style definitions |

**String vs Array**: Use a string for a single path, an array for multiple paths.

```json
{
  "skills": "./skills",
  "commands": ["./commands", "./extra-commands"]
}
```

### Environment Variables

Available in hook scripts, MCP configs, and LSP configs:

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the installed plugin directory | `/home/user/.claude/plugins/my-plugin` |
| `${CLAUDE_PLUGIN_DATA}` | Persistent data directory for this plugin | `/home/user/.claude/plugins/data/my-plugin-abc123/` |

**CRITICAL**: Always use `${CLAUDE_PLUGIN_ROOT}` for paths in hooks and configs. Never use absolute paths — they break when the plugin is installed on another machine.

### Complete Example

```json
{
  "name": "engineering-toolkit",
  "version": "2.1.0",
  "description": "I&C engineering tools for mining capital projects",
  "author": {
    "name": "AXOIQ",
    "email": "dev@axoiq.com",
    "url": "https://axoiq.com"
  },
  "homepage": "https://github.com/axoiq/engineering-toolkit",
  "repository": "https://github.com/axoiq/engineering-toolkit",
  "license": "MIT",
  "keywords": ["engineering", "i&c", "mining", "instrumentation"],
  "commands": "./commands",
  "skills": "./skills",
  "agents": "./agents",
  "hooks": "./hooks",
  "mcpServers": "./.mcp.json"
}
```

### Minimal Example

```json
{
  "name": "my-plugin"
}
```

This works. Claude Code auto-discovers `commands/`, `skills/`, `agents/`, and `hooks/` at the plugin root.

---

## marketplace.json

Location: `.claude-plugin/marketplace.json` (for marketplace distribution)

A marketplace is a registry of one or more plugins hosted in a Git repository.

### Root-Level Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | **Required** | Marketplace identifier (kebab-case) |
| `owner` | `object` | **Required** | Marketplace owner info |
| `plugins` | `array` | **Required** | Array of plugin entries |

**CRITICAL**: The marketplace.json root CANNOT have `description`. Only `name`, `owner`, and `plugins` are allowed at root level. Adding `description` at root will cause validation errors.

### Owner Object

```json
{
  "owner": {
    "name": "AXOIQ",
    "email": "dev@axoiq.com"
  }
}
```

Both `name` and `email` are required.

### Plugin Entry Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | Required | Plugin name (must match plugin.json `name`) |
| `description` | `string` | Recommended | What the plugin does |
| `version` | `string` | Recommended | Semver version |
| `source` | `string` | Required | Relative path to plugin directory |
| `author` | `string \| object` | Optional | Plugin-level author (overrides marketplace owner) |

### Complete Example

```json
{
  "name": "axoiq-marketplace",
  "owner": {
    "name": "AXOIQ",
    "email": "dev@axoiq.com"
  },
  "plugins": [
    {
      "name": "engineering-toolkit",
      "description": "I&C engineering tools for mining capital projects",
      "version": "2.1.0",
      "source": "./plugins/engineering-toolkit"
    },
    {
      "name": "code-reviewer",
      "description": "Automated code review with domain expertise",
      "version": "1.0.0",
      "source": "./plugins/code-reviewer",
      "author": "Jane Doe"
    }
  ]
}
```

### Multi-Plugin Marketplace Layout

```
my-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   ├── plugin-a/
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   └── plugin-b/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── commands/
```

---

## Distribution Methods

### 1. Marketplace (recommended for multi-plugin repos)

```bash
# Add a marketplace
claude plugin marketplace add https://github.com/org/my-marketplace

# Install a plugin from it
claude plugin install my-plugin@my-marketplace

# Update
claude plugin update my-plugin
```

### 2. GitHub / Git Repo (single plugin)

```bash
claude plugin install https://github.com/user/my-plugin
```

### 3. Local Path (development)

```bash
# Load for testing (session only)
claude --plugin-dir ./my-plugin

# Install permanently from local path
claude plugin install ./my-plugin
```

### 4. npm Package

```bash
claude plugin install npm:my-plugin-package
```

### 5. Official Marketplace Submission

Submit at [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit). Goes through Anthropic review.

---

## Validation

```bash
# Validate plugin structure and manifest
claude plugin validate ./my-plugin
```

Common validation errors:

| Error | Cause | Fix |
|-------|-------|-----|
| `Missing required field: name` | No `name` in plugin.json | Add `"name": "my-plugin"` |
| `Invalid name format` | Name has spaces or uppercase | Use kebab-case: `my-plugin` |
| `Unknown field at marketplace root` | Extra fields in marketplace.json root | Only `name`, `owner`, `plugins` allowed |
| `Component path not found` | Custom path in plugin.json doesn't exist | Create the directory or fix the path |
| `Version not valid semver` | Version like `1.0` or `v1.0.0` | Use `1.0.0` (no `v` prefix) |
