---
name: atlas-doctor
description: "System health check with auto-fix for the ATLAS ecosystem. 8-category diagnostic: OS, permissions, tools, tokens, services, Claude Code, plugin, project context. Use when 'doctor', 'diagnose', 'health check', 'verify installation', 'system status', or 'troubleshoot'."
effort: medium
---

# ATLAS Doctor — System Health Dashboard

Comprehensive diagnostic of the entire ATLAS ecosystem. Runs bash checks across 8 categories, produces a scored health dashboard, and optionally proposes auto-fixes with HITL approval.

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas doctor` | Full health dashboard (read-only) |
| `/atlas doctor --fix` | Dashboard + propose auto-fixes for each issue |
| `/atlas doctor tokens` | Check tokens only |
| `/atlas doctor tools` | Check tools only |
| `/atlas doctor services` | Check services only |
| `/atlas doctor project` | Check project context only |

## Output Format

```
🏛️ ATLAS │ 🩺 DOCTOR │ System Health Check

| #  | Category         | Score | Status | Issues                  |
|----|------------------|-------|--------|-------------------------|
| 1  | OS & Shell       | 5/5   | ✅     |                         |
| 2  | Permissions      | 5/5   | ✅     |                         |
| 3  | Tools            | 7/8   | ⚠️     | Missing: yq             |
| 4  | Tokens           | 2/4   | ⚠️     | No SYNAPSE, AUTHENTIK   |
| 5  | Services         | 3/5   | ⚠️     | Valkey offline          |
| 6  | Claude Code      | 5/5   | ✅     |                         |
| 7  | ATLAS Plugin     | 8/8   | ✅     |                         |
| 8  | Project Context  | 3/5   | ⚠️     | No rules, memory        |
| 9  | Terminal & Launch | 6/8   | ⚠️     | No completions, ROOT    |
| 10 | StatusLine       | 4/5   | ⚠️     | Scripts not deployed    |
| 11 | CC Settings      | 7/8   | ⚠️     | Missing language config |
| 12 | MCP & Plugins    | 5/6   | ⚠️     | Figma optional          |

OVERALL: 61/72 (85%) ⚠️
```

Status thresholds: ✅ = 100%, ⚠️ = 50-99%, ❌ = <50%

## Checks by Category

### Cat 1: OS & Shell (5 checks)

```bash
uname -s                           # 1. OS type (Linux/Darwin)
uname -r                           # 2. Kernel version
basename "$SHELL"                  # 3. Shell (zsh/bash)
locale 2>/dev/null | grep -q "UTF-8"  # 4. UTF-8 locale
hostname -s                        # 5. Hostname (detect VM vs laptop)
```

### Cat 2: Permissions (5 checks)

```bash
[ -w "${HOME}/.claude" ]           # 1. Claude dir writable
[ -w "${HOME}/.atlas" ] || mkdir -p "${HOME}/.atlas"  # 2. Atlas dir writable
git config user.name >/dev/null 2>&1   # 3. Git configured
[ -f "${HOME}/.ssh/id_ed25519" ] || [ -f "${HOME}/.ssh/id_rsa" ]  # 4. SSH key exists
groups 2>/dev/null | grep -q docker    # 5. Docker group
```

### Cat 3: Tools (8 checks)

```bash
command -v bash     # 1. bash
command -v yq       # 2. yq (YAML processor for build.sh)
command -v python3  # 3. python3 (tests + hooks)
command -v bun      # 4. bun (frontend package manager)
command -v docker   # 5. docker
command -v git      # 6. git
command -v jq       # 7. jq (JSON processor)
command -v curl     # 8. curl (API checks)
```

Auto-fix suggestions:
| Tool | Ubuntu/Debian | macOS |
|------|---------------|-------|
| yq | `sudo snap install yq` | `brew install yq` |
| bun | `curl -fsSL https://bun.sh/install \| bash` | same |
| jq | `sudo apt install jq` | `brew install jq` |
| docker | `sudo apt install docker.io` | Docker Desktop |

### Cat 4: Tokens (4 checks)

For each token, check existence AND API validity:

```bash
# Config helper — read from ~/.atlas/config.json with fallback
atlas_config() {
  local key="$1" fallback="${2:-}"
  python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.atlas/config.json')) as f:
        d = json.load(f)
    keys = '$key'.split('.')
    v = d
    for k in keys: v = v[k]
    if isinstance(v, list): print(' '.join(v))
    else: print(v)
except: print('$fallback')
" 2>/dev/null || echo "$fallback"
}

SYNAPSE_URL=$(atlas_config "services.synapse.url" "http://localhost:8001")
FORGEJO_URL=$(atlas_config "services.forgejo.local_url" "")
FORGEJO_API_PATH=$(atlas_config "services.forgejo.api_path" "/api/v1")
AUTHENTIK_URL_CFG=$(atlas_config "services.authentik.url" "")

# SYNAPSE_TOKEN — Backend API access
[ -n "${SYNAPSE_TOKEN:-}" ] && \
  curl -sf -m 3 -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  "${SYNAPSE_URL}/api/v1/health" >/dev/null 2>&1

# FORGEJO_TOKEN — Git hosting API
[ -n "${FORGEJO_TOKEN:-}" ] && [ -n "$FORGEJO_URL" ] && \
  curl -sf -m 3 -H "Authorization: token $FORGEJO_TOKEN" \
  "${FORGEJO_URL}${FORGEJO_API_PATH}/user" >/dev/null 2>&1

# AUTHENTIK_TOKEN — SSO (optional)
[ -n "${AUTHENTIK_TOKEN:-}" ] && [ -n "$AUTHENTIK_URL_CFG" ] && \
  curl -sf -m 3 -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  "${AUTHENTIK_URL:-$AUTHENTIK_URL_CFG}/api/v3/core/users/me/" >/dev/null 2>&1

# GEMINI_API_KEY — existence only
[ -n "${GEMINI_API_KEY:-}" ]
```

Token states: ✅ = present + API valid, ⚠️ = present but API failed, ❌ = missing
AUTHENTIK_TOKEN: ⏭️ optional if missing

Auto-fix: guide user to add to `~/.env` with `export TOKEN=value` then `source ~/.env`.

### Cat 5: Services (5 checks)

```bash
curl -sf -m 3 http://localhost:8001/health             # 1. Synapse backend
docker ps --filter name=synapse -q 2>/dev/null | wc -l  # 2. Synapse containers (>0)
pg_isready -h localhost -p 5433 2>/dev/null             # 3. PostgreSQL
docker exec synapse-valkey redis-cli ping 2>/dev/null   # 4. Valkey
curl -sf -m 3 "${FORGEJO_URL}${FORGEJO_API_PATH}/version" # 5. Forgejo (URL from config)
```

Skip Docker checks if `hostname -s` = `ATL-dev` (VM has no Docker).

Auto-fix:
- Backend offline → `docker compose up -d` (if compose.yml found)
- Container down → `docker restart synapse-{name}`
- Forgejo unreachable → check VPN/network

### Cat 6: Claude Code (5 checks)

```bash
claude --version 2>/dev/null                             # 1. CC installed + version
ls ~/.claude/plugins/cache/atlas-* 2>/dev/null | head -1 # 2. Plugin installed
cat ~/.claude/settings.json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin); print('valid')"  # 3. Settings valid
ls ~/.claude/commands/a-*.md 2>/dev/null | wc -l         # 4. Global commands (>0)
[ -f ~/.claude/CLAUDE.md ]                               # 5. Global CLAUDE.md
```

### Cat 7: ATLAS Plugin (8 checks)

Detect plugin root:
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -z "$PLUGIN_ROOT" ] && PLUGIN_ROOT=$(find ~/.claude/plugins/cache -name "plugin.json" -path "*/atlas-*" -exec dirname {} \; 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
```

```bash
cat "${PLUGIN_ROOT}/VERSION" 2>/dev/null                # 1. Version readable
ls "${PLUGIN_ROOT}"/skills/*/SKILL.md 2>/dev/null | wc -l  # 2. Skills (>30)
ls "${PLUGIN_ROOT}"/agents/*/AGENT.md 2>/dev/null | wc -l  # 3. Agents (>0)
ls "${PLUGIN_ROOT}"/commands/*.md 2>/dev/null | wc -l      # 4. Commands (>20)
cat "${PLUGIN_ROOT}"/hooks/hooks.json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin); print('valid')"  # 5. hooks.json valid
ls "${PLUGIN_ROOT}"/hooks/ 2>/dev/null | grep -v hooks.json | wc -l  # 6. Hook scripts (>5)
[ -f "${PLUGIN_ROOT}/CLAUDE.md" ]                          # 7. Plugin CLAUDE.md
grep -rl "^effort:" "${PLUGIN_ROOT}"/skills/*/SKILL.md 2>/dev/null | wc -l  # 8. Effort metadata
```

### Cat 8: Project Context (5 checks)

```bash
[ -f CLAUDE.md ]                                          # 1. Project CLAUDE.md
[ -d .claude/rules ] && ls .claude/rules/*.md 2>/dev/null | wc -l  # 2. Rules (>0)
[ -f .blueprint/FEATURES.md ]                             # 3. Feature registry
MEMORY_DIR=$(find ~/.claude/projects -name "MEMORY.md" -path "*$(basename $(pwd))*" 2>/dev/null | head -1)
[ -n "$MEMORY_DIR" ]                                      # 4. Memory index
[ -d .blueprint/plans ]                                   # 5. Plans directory
```

Auto-fix: dispatch to `/atlas setup context` for CLAUDE.md/rules generation.

## Auto-Fix Mode (`--fix`)

When `--fix` is passed:

1. Run all checks (same as read-only mode)
2. Collect all failures
3. Sort by priority: ❌ (critical) before ⚠️ (warning)
4. For each issue, present via AskUserQuestion:
   ```
   "Valkey is offline. Fix by running: docker restart synapse-valkey?"
   Options: ["Yes, fix it", "Skip this one", "Stop fixing"]
   ```
5. If approved → execute fix command
6. Re-run the specific check to verify
7. Show updated status (✅ or still ❌)
8. Continue to next issue

### Cat 9: Terminal & Launch (8 checks)

Run full terminal check via helper script:
```bash
${PLUGIN_ROOT}/scripts/setup-terminal.sh --check
```

Individual checks:
```bash
# 1. Claude Code installed
command -v claude

# 2. Claude Code version is recent (2.x)
claude --version 2>/dev/null | grep -qP '2\.\d+\.\d+'

# 3. Shell RC file exists
[ -f "${HOME}/.$(basename ${SHELL})rc" ]

# 4. ATLAS aliases configured
grep -q "atlas()" "${HOME}/.$(basename ${SHELL})rc" 2>/dev/null

# 5. ATLAS zsh/bash completions installed
[ -f "${HOME}/.oh-my-zsh/custom/plugins/atlas/_atlas" ] 2>/dev/null || \
[ -f "${HOME}/.local/share/bash-completion/completions/atlas" ] 2>/dev/null

# 6. ATLAS_ROOT env var set
[ -n "${ATLAS_ROOT:-}" ]

# 7. Workspace directory exists
[ -d "${ATLAS_ROOT:-$HOME/workspace_atlas}" ]

# 8. DX tools (fzf + zoxide + bat minimum)
command -v fzf && command -v zoxide && (command -v bat || command -v batcat)
```

Platform-aware auto-fix suggestions:
| Issue | Linux/WSL | macOS |
|-------|-----------|-------|
| CC missing | `curl -fsSL https://claude.ai/install \| sh` | same |
| Aliases missing | `/atlas setup` or `scripts/shell-aliases.sh >> ~/.zshrc` | `>> ~/.zshrc` |
| ATLAS_ROOT missing | `echo 'export ATLAS_ROOT=...' >> ~/.zshrc` | same |
| Workspace missing | `mkdir -p ~/workspace_atlas` | same |

Display platform summary:
```
🏛️ ATLAS │ 🖥️ PLATFORM │ {os} {version} │ {shell} │ {terminal}
   └─ Arch: {arch} │ Docker: {bool} │ Starship: {bool} │ CShip: {bool}
```

### Cat 10: StatusLine (5 checks)

```bash
# 1. CShip binary installed
command -v cship && cship --version

# 2. Starship installed
command -v starship && starship --version

# 3. ATLAS Starship module scripts deployed
[ -x "${HOME}/.local/share/atlas-statusline/atlas-starship-module.sh" ]

# 4. session-state.json exists and is valid JSON
cat "${CLAUDE_PLUGIN_DATA:-$HOME/.claude}/session-state.json" 2>/dev/null | \
  python3 -c "import sys,json; json.load(sys.stdin); print('valid')"

# 5. settings.json statusLine configured
cat "${HOME}/.claude/settings.json" 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('statusLine',{}).get('command','MISSING'))" | \
  grep -qv "MISSING"
```

Auto-fix: dispatch to `/atlas statusline-setup` skill for full interactive setup.

Display:
```
🏛️ ATLAS │ 📊 STATUSLINE │ CShip: {version} │ Starship: {version}
   └─ Scripts: {deployed?} │ State: {valid?} │ Config: {wired?}
```

### Cat 11: CC Settings (8 checks)

Check Claude Code global + project settings for ATLAS-required configuration:

```bash
GLOBAL="${HOME}/.claude/settings.json"
PROJECT=".claude/settings.json"

# 1. Global settings.json exists and is valid
cat "$GLOBAL" 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin); print('valid')"

# 2. ATLAS plugin enabled in project settings
cat "$PROJECT" 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
p=d.get('enabledPlugins',{})
print('enabled' if any('atlas' in k for k in p) else 'MISSING')
"

# 3. Global permissions include Bash, Read, Write, Edit, Skill(*)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
perms=d.get('permissions',{}).get('allow',[])
required={'Bash','Read','Write','Edit'}
missing=required - set(p.split('(')[0] for p in perms)
print('ok' if not missing else f'MISSING: {missing}')
"

# 4. Language set to francais (user preference)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(d.get('language','NOT SET'))
"

# 5. Global hooks configured (UserPromptSubmit for timestamp)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
hooks=d.get('hooks',{})
print('ok' if 'UserPromptSubmit' in hooks else 'MISSING UserPromptSubmit hook')
"

# 6. Project env vars set (CLAUDE_CODE_SPAWN_BACKEND, output tokens)
cat "$PROJECT" 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
env=d.get('env',{})
print('ok' if 'CLAUDE_CODE_MAX_OUTPUT_TOKENS' in env else 'MISSING output token config')
" 2>/dev/null || echo "no project settings"

# 7. Global commands directory has a-* commands
ls "${HOME}/.claude/commands/a-"*.md 2>/dev/null | wc -l

# 8. Global CLAUDE.md exists
[ -f "${HOME}/.claude/CLAUDE.md" ]
```

Auto-fix suggestions:
| Issue | Fix |
|-------|-----|
| Plugin not enabled | Add to project `.claude/settings.json` enabledPlugins |
| Missing permissions | Add required permissions to global settings |
| Missing hooks | Copy hook templates from ATLAS plugin |
| Missing global commands | Copy from `~/.claude/commands/` templates |
| Missing language | Add `"language": "francais"` to global settings |

### Cat 12: MCP Servers & Plugins (6 checks)

```bash
PROJECT=".claude/settings.json"

# 1. Context7 MCP configured
cat .mcp.json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
s=d.get('mcpServers',{})
print('ok' if 'context7' in s else 'MISSING')
" 2>/dev/null || echo "no .mcp.json"

# 2. Playwright MCP configured
cat .mcp.json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('ok' if 'playwright' in d.get('mcpServers',{}) else 'MISSING')
" 2>/dev/null || echo "no .mcp.json"

# 3. Official plugins installed (from project settings enabledPlugins)
cat "$PROJECT" 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
p=d.get('enabledPlugins',{})
expected=['context7','playwright','pr-review-toolkit','commit-commands','plugin-dev']
installed=[k.split('@')[0] for k in p if p[k]]
missing=[e for e in expected if e not in installed]
print(f'{len(installed)} installed' + (f', MISSING: {missing}' if missing else ''))
"

# 4. Figma MCP (optional)
cat .mcp.json 2>/dev/null | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('ok' if 'figma' in d.get('mcpServers',{}) else 'optional: not configured')
" 2>/dev/null || echo "optional"

# 5. Chrome MCP (claude-in-chrome) responding
# Can't test directly — check if --chrome flag is available
claude --help 2>/dev/null | grep -q "chrome" && echo "ok" || echo "MISSING chrome support"

# 6. .mcp.json is valid JSON
cat .mcp.json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin); print('valid')" 2>/dev/null || echo "no .mcp.json"
```

Display:
```
🏛️ ATLAS │ 🔌 PLUGINS │ {N} MCP servers │ {N} plugins
   └─ Context7: {ok} │ Playwright: {ok} │ Figma: {ok} │ Chrome: {ok}
```

## Report Persistence

After running doctor, save report to `~/.atlas/doctor-report.json`:
```json
{
  "timestamp": "2026-03-21T12:00:00Z",
  "overall_score": 59,
  "overall_max": 70,
  "categories": {
    "os_shell": { "score": 5, "max": 5, "issues": [] },
    "permissions": { "score": 5, "max": 5, "issues": [] },
    "tools": { "score": 7, "max": 8, "issues": ["yq"] },
    ...
  }
}
```

Update `~/.atlas/profile.json`:
```json
"onboarding": {
  "doctor_last_run": "2026-03-21T12:00:00Z",
  "doctor_score": 84
}
```

## Severity Rules

- ✅ 100% in category → green
- ⚠️ 50-99% → yellow, show issues
- ❌ <50% → red, show issues + auto-fix prompt

OVERALL threshold: ≥90% = healthy, 70-89% = needs attention, <70% = critical setup needed
