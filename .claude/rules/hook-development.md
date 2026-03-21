# Hook Development Rules

## hooks.json Schema
```json
{
  "hooks": {
    "EventType": [
      {
        "matcher": "regex pattern (optional)",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/script-name\"",
            "async": true,
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Supported Events
| Event | When | Sync? | Input |
|-------|------|-------|-------|
| SessionStart | Session opens | sync | JSON with trigger reason |
| SessionEnd | Session closes | async | JSON with session_id |
| PreCompact | Before compaction | sync | — |
| PostCompact | After compaction | sync | JSON with trigger |
| PostToolUse | After Write/Edit | async | JSON with file_path |
| UserPromptSubmit | User sends prompt | async | JSON with prompt |
| PermissionRequest | Before dangerous cmd | sync | JSON with command |

## Script Rules
1. `#!/usr/bin/env bash` + `set -euo pipefail` (sync hooks) or `set -o pipefail` + `trap 'exit 0' ERR` (async hooks — resilience over strictness)
2. Use `${CLAUDE_PLUGIN_ROOT}` for path resolution (with fallback)
3. Read input from stdin: `INPUT=$(cat)`
4. Parse JSON with python3 one-liners (portable)
5. Output branded: `🏛️ ATLAS │ {emoji}{severity} {CATEGORY} │ {message}`
6. Async hooks: `exit 0` on non-critical failure (never block user)
7. Sync hooks: can block (SessionStart returns JSON, PermissionRequest warns)
8. Timeout: 3-10s max. Never exceed 10s.

## Build Integration
- `build.sh` copies ALL executable scripts from `hooks/` (wildcard)
- No manual hook list to maintain
- New hooks are auto-included in dist/ builds
- Test with `bash -n hooks/{name}` for syntax validation

## Visual Identity (NON-NEGOTIABLE)
Every hook that produces chat output MUST use:
```
🏛️ ATLAS │ {function_emoji}{severity_emoji} {CATEGORY} │ {message}
   └─ {detail line}
```
See `skills/refs/atlas-visual-identity/SKILL.md` for the complete emoji map.
