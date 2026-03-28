# Pre-Publish Validation Checklist

Comprehensive checklist for validating a Claude Code plugin before publishing.

---

## Structure

- [ ] Plugin root contains `.claude-plugin/` directory
- [ ] `.claude-plugin/plugin.json` exists and is valid JSON
- [ ] Components (`commands/`, `skills/`, `agents/`, `hooks/`) are at plugin root, NOT inside `.claude-plugin/`
- [ ] No orphaned files outside expected directories
- [ ] `README.md` exists at plugin root with usage instructions
- [ ] Directory names use kebab-case
- [ ] No `.env` files or secrets committed to the repository
- [ ] `.gitignore` excludes `node_modules/`, `.env`, OS files, plugin data

## plugin.json

- [ ] `name` field present and kebab-case (required)
- [ ] `version` follows semver (`X.Y.Z`, no `v` prefix)
- [ ] `description` is present and clear (1-2 sentences)
- [ ] `author` has at least `name`
- [ ] `license` is a valid SPDX identifier
- [ ] `keywords` array contains relevant discovery terms
- [ ] Custom component paths (if any) resolve to existing directories
- [ ] No unknown/unsupported fields
- [ ] Component path values use `./` relative paths (not absolute)

## Skills

- [ ] Each skill has its own directory under `skills/`
- [ ] Each skill directory contains a `SKILL.md` file
- [ ] SKILL.md has valid YAML frontmatter between `---` delimiters
- [ ] `name` field is kebab-case, max 64 characters
- [ ] `description` includes specific trigger phrases in quotes
- [ ] Body is under 5000 words (ideally 1500-2000)
- [ ] Long content moved to `references/` subdirectory
- [ ] String substitutions (`$ARGUMENTS`, `$0`, etc.) used correctly
- [ ] `model` field (if set) uses valid value: `sonnet`, `opus`, `haiku`, `inherit`, or full model ID
- [ ] `allowed-tools` (if set) lists only valid tool names
- [ ] `context: fork` has a corresponding `agent` field (if applicable)
- [ ] No duplicate skill names across the plugin
- [ ] Reference files actually exist where the body references them

## Agents

- [ ] Each agent has its own directory under `agents/`
- [ ] Each agent directory contains an `AGENT.md` file
- [ ] AGENT.md has valid YAML frontmatter between `---` delimiters
- [ ] `name` field is present and kebab-case (required)
- [ ] `description` field is present and descriptive (required)
- [ ] `tools` and `disallowedTools` are not both set (mutually exclusive)
- [ ] `model` field (if set) uses valid value
- [ ] `permissionMode` (if set) is one of: `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan`
- [ ] `maxTurns` (if set) is a reasonable number (not too high for safety)
- [ ] `skills` (if set) references skill names that exist in the plugin
- [ ] `mcpServers` (if set) references server names defined in `.mcp.json`
- [ ] `Agent()` tool restrictions (if used) reference valid agent names
- [ ] `bypassPermissions` mode is only used with restricted tool access
- [ ] No duplicate agent names across the plugin

## Hooks

- [ ] `hooks/hooks.json` exists and is valid JSON
- [ ] All referenced script files exist in `hooks/` directory
- [ ] All hook scripts are executable (`chmod +x`)
- [ ] Hook scripts have proper shebang line (`#!/usr/bin/env bash`, `#!/usr/bin/env node`, etc.)
- [ ] Scripts use `${CLAUDE_PLUGIN_ROOT}` for paths (no hardcoded absolute paths)
- [ ] Event names are valid (check against the 20+ supported events)
- [ ] `matcher` values match actual tool names (case-sensitive)
- [ ] Blocking hooks (exit code 2) only used with `PreToolUse` or `WorktreeCreate`
- [ ] Scripts read stdin for event data (not command-line args)
- [ ] Scripts handle missing/malformed input gracefully
- [ ] No interactive commands in scripts (no `read`, no prompts)
- [ ] Scripts complete quickly (< 5 seconds) to avoid blocking
- [ ] Prompt hooks have clear, focused instructions (not novels)
- [ ] HTTP hooks point to valid, accessible URLs
- [ ] Agent hooks reference agents that exist in the plugin

## MCP Servers

- [ ] `.mcp.json` exists and is valid JSON (if using MCP)
- [ ] Server names are unique and kebab-case
- [ ] `command` field points to an installed/available executable
- [ ] `args` array contains valid arguments for the command
- [ ] `env` variables use `${VAR}` syntax for expansion
- [ ] `cwd` (if set) uses `${CLAUDE_PLUGIN_ROOT}`
- [ ] Server dependencies are documented in README (e.g., `npm install`)
- [ ] Server starts and responds correctly when tested locally

## LSP Servers

- [ ] `.lsp.json` exists and is valid JSON (if using LSP)
- [ ] Server names are unique and kebab-case
- [ ] `command` field points to an installed LSP server binary
- [ ] `extensionToLanguage` maps all relevant file extensions
- [ ] Language IDs are standard LSP language identifiers
- [ ] `initializationOptions` (if set) match the server's expected schema
- [ ] `settings` (if set) are valid for the target LSP server
- [ ] Server starts and responds correctly when tested locally

## Security

- [ ] No secrets, API keys, or tokens in any committed file
- [ ] Hook scripts validate input before acting on it
- [ ] Destructive operations (delete, overwrite) have safety checks
- [ ] `bypassPermissions` is not used without restricted tool access
- [ ] HTTP hook URLs use HTTPS (not plain HTTP)
- [ ] No `eval()` or equivalent in hook scripts
- [ ] File operations stay within expected directories (no path traversal)
- [ ] MCP/LSP env vars don't expose secrets in logs

## Testing

- [ ] Plugin loads without errors: `claude --plugin-dir ./my-plugin`
- [ ] `claude plugin validate ./my-plugin` passes with no errors
- [ ] Each skill can be invoked: `/plugin-name:skill-name`
- [ ] Skill auto-invocation works (test trigger phrases from descriptions)
- [ ] Hot reload works: edit a file, run `/reload-plugins`, verify changes
- [ ] Hook scripts execute correctly (test with mock stdin data)
- [ ] MCP servers start and provide tools (check `--debug` output)
- [ ] LSP servers activate for the correct file types
- [ ] Plugin works on a clean machine (no local-only dependencies)
- [ ] Test with `claude --debug` to verify all components load

## Publishing

- [ ] `marketplace.json` has only `name`, `owner`, `plugins` at root (no `description` at root)
- [ ] `marketplace.json` `owner` has both `name` and `email`
- [ ] Plugin `source` paths in marketplace.json resolve correctly
- [ ] Plugin versions match between `plugin.json` and `marketplace.json`
- [ ] Repository is pushed to a publicly accessible Git host
- [ ] README includes installation instructions
- [ ] README includes usage examples for each skill/command
- [ ] CHANGELOG or release notes document the current version
- [ ] License file exists if `license` is set in plugin.json
- [ ] Version bumped from previous release

---

## Quick Validation Commands

```bash
# Structural validation
claude plugin validate ./my-plugin

# Load test
claude --plugin-dir ./my-plugin --debug

# Hook script permissions
find hooks/ -type f -name "*.sh" ! -perm -111 -print  # Should output nothing

# JSON validation
python3 -m json.tool .claude-plugin/plugin.json > /dev/null
python3 -m json.tool hooks/hooks.json > /dev/null
python3 -m json.tool .mcp.json > /dev/null 2>&1 || true
python3 -m json.tool .lsp.json > /dev/null 2>&1 || true

# Check for secrets
grep -rn "sk-\|api_key\|password\|secret\|token" --include="*.json" --include="*.sh" --include="*.md" .
```
