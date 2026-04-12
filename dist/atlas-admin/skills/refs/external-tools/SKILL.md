---
name: external-tools
description: Reference docs for non-ATLAS MCP/LSP tools discovered at session start
trigger: auto (SessionStart hook)
---

# External Tools Reference

Auto-discovered MCP servers, LSP servers, and Claude Code plugins.

## Usage

See individual tool files in this directory for usage protocols.
Routing table in `atlas-assist` maps user intent → primary tool → fallback.

## Discovery

The `hooks/external-capabilities` bash hook runs at SessionStart:
1. Reads `~/.claude/plugins/installed_plugins.json`
2. Scans plugin cache `.mcp.json` files
3. Reads project `.mcp.json` / `.claude/settings.local.json`
4. Outputs compact banner: `🔌 EXTERNAL │ N plugins │ N MCP │ N LSP`
