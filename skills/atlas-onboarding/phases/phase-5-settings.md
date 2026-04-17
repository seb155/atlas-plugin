# Phase 5: 📊 StatusLine & CC Settings

## 5A: StatusLine Deployment

Check if CShip + Starship are configured:
```bash
CSHIP_OK=$(command -v cship &>/dev/null && echo "✅" || echo "❌")
STARSHIP_OK=$(command -v starship &>/dev/null && echo "✅" || echo "❌")
SCRIPTS_OK=$([ -x "${HOME}/.local/share/atlas-statusline/atlas-starship-module.sh" ] && echo "✅" || echo "❌")
```

Present status table:
```
| Component         | Status | Detail                     |
|-------------------|--------|----------------------------|
| CShip binary      | {ok}   | Rust-based status renderer |
| Starship prompt   | {ok}   | Terminal prompt framework   |
| ATLAS scripts     | {ok}   | Module scripts deployed     |
| settings.json     | {ok}   | statusLine.command wired    |
```

If any ❌ → AskUserQuestion:
```
"StatusLine gives you a rich ATLAS dashboard in your terminal:
 Row 1: plugin version, model, branch
 Row 2: tier, Docker, CI, features
 Row 3: context usage bar

 Set up StatusLine now?"
 Options: ["Yes, full setup", "Skip for now"]
```

If yes → invoke `statusline-setup` skill (7-step interactive wizard with HITL gates).

## 5B: CC Settings Validation

Check Claude Code global + project settings:
```bash
GLOBAL="${HOME}/.claude/settings.json"
PROJECT=".claude/settings.json"
```

Required global settings:
| Setting | Check | Auto-fix |
|---------|-------|----------|
| `permissions.allow` includes Bash,Read,Write,Edit,Skill(*) | parse JSON | Add missing perms |
| `permissions.deny` includes `Read(~/.ssh/**)`, `Read(/etc/shadow)` | parse JSON | Add missing deny rules |
| `language` set | check key exists | Add `"language": "francais"` |
| `includeGitInstructions` = false | check key+value | Set to `false` (ATLAS manages git via skills) |
| `showClearContextOnPlanAccept` = true | check key+value | Set to `true` |
| `hooks.UserPromptSubmit` exists | check key | Copy from ATLAS template |
| `hooks.PreToolUse` exists | check key | Copy validate-bash.sh |
| `hooks.PostCompact` exists | check key | Wire `$HOME/.claude/hooks/post-compact.sh` |
| `hooks.StopFailure` exists | check key | Add API error logging hook |
| `env.CLAUDE_CODE_MAX_OUTPUT_TOKENS` = "128000" | check key+value | Set for Opus 4.7 128K output |
| `env.CLAUDE_CODE_MAX_THINKING_TOKENS` = "250000" | check key+value | Set for Opus 4.7 1M context |
| `env.CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS` = "50000" | check key+value | Set for large file reads |
| Global commands `~/.claude/commands/a-*.md` | count files | Warn if missing |
| `~/.claude/CLAUDE.md` exists | file check | Generate from template |

Required project settings:
| Setting | Check | Auto-fix |
|---------|-------|----------|
| ATLAS plugin enabled | check enabledPlugins | Add entry |
| `env.CLAUDE_CODE_MAX_OUTPUT_TOKENS` | check key | Add default "128000" |
| `env.CLAUDE_CODE_SPAWN_BACKEND` = "tmux" | check value | Set to "tmux" |
| `plansDirectory` = ".blueprint/plans" | check value | Set it |

For each issue: AskUserQuestion with before/after preview.
NEVER auto-modify settings without HITL approval.

## 5C: MCP Servers

Check `.mcp.json` for required servers:
```bash
MCP_FILE=".mcp.json"
[ -f "$MCP_FILE" ] || echo "No .mcp.json found"
```

Required MCP servers:
| Server | Required? | Check |
|--------|-----------|-------|
| context7 | ✅ Yes | Key in mcpServers |
| playwright | ✅ Yes (dev+) | Key in mcpServers |
| figma | ⚠️ Optional | Key in mcpServers |
| claude-in-chrome | ⚠️ Optional | --chrome flag support |

For missing required servers → AskUserQuestion to add config entry.
