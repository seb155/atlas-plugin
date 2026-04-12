---
name: atlas-doctor
description: "System health check with auto-fix for the ATLAS ecosystem. 8-category diagnostic: OS, permissions, tools, tokens, services, Claude Code, plugin, project context. Use when 'doctor', 'diagnose', 'health check', 'verify installation', 'system status', 'troubleshoot', 'doctor plugins', 'check plugins', 'external tools health', or 'plugin health'."
effort: medium
---

# ATLAS Doctor — System Health Dashboard

Comprehensive diagnostic of the entire ATLAS ecosystem. Runs bash checks across 8 categories, produces a scored health dashboard, and optionally proposes auto-fixes with HITL approval.

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas doctor` | Full health dashboard (read-only) |
| `/atlas doctor plugins` | External tools health only (Cat 12) — fast check + auto-fix |
| `/atlas doctor --fix` | Dashboard + HITL review: explain each issue, propose fix, validate one by one |
| `/atlas doctor --fix-all` | Dashboard + apply all fixes automatically (no HITL per issue) |
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
| 11 | CC Settings      | 13/15 | ⚠️     | Missing language config |
| 12 | MCP & Plugins    | 5/6   | ⚠️     | Figma optional          |
| 13 | Domain Plugins   | 4/4   | ✅     |                         |
| 14 | Observability    | 5/5   | ✅     |                         |

OVERALL: 70/81 (86%) ⚠️
```

Status thresholds: ✅ = 100%, ⚠️ = 50-99%, ❌ = <50%

## Per-Category Scoring Summary (v2)

After all categories are checked, append a letter-grade scoring table:

```
ATLAS Doctor Summary
┌──────────────────────────┬───────┬────────┐
│ Category                 │ Score │ Issues │
├──────────────────────────┼───────┼────────┤
│  1. OS & Shell           │ A     │ 0      │
│  2. Permissions          │ B     │ 1      │
│  3. Tools                │ A     │ 0      │
│  4. Tokens/Creds         │ C     │ 2      │
│  5. Services             │ A     │ 0      │
│  6. Claude Code          │ A     │ 0      │
│  7. ATLAS Plugin         │ B     │ 1      │
│  8. Project Context      │ A     │ 0      │
│  9. Terminal & Launch    │ B     │ 1      │
│ 10. StatusLine           │ A     │ 0      │
│ 11. CC Settings          │ B     │ 1      │
│ 12. MCP & Plugins        │ A     │ 0      │
│ 13. Domain Plugins       │ A     │ 0      │
│ 14. Observability        │ A     │ 0      │
├──────────────────────────┼───────┼────────┤
│ OVERALL                  │ B+    │ 6      │
└──────────────────────────┴───────┴────────┘

Dream Health: B+ 8.91/10 (2026-04-04)
```

**Letter grade rules per category:**
- **A** = 0 issues (100%)
- **B** = 1 issue (80-99%)
- **C** = 2 issues (60-79%)
- **D** = 3+ issues (40-59%)
- **F** = critical failure (<40% or ❌ category)

**OVERALL grade:**
- A+ = all A / 0 issues total
- A  = 0-1 issues total
- B+ = 2-4 issues total, no F categories
- B  = 5-7 issues total, no F categories
- C  = 8-12 issues or 1 F category
- D  = 13+ issues or 2+ F categories
- F  = ≥3 F categories or critical system failure

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

#### Environment Detection (before Cat 5)

Before running Cat 5 checks, detect environment:
```bash
HOSTNAME=$(hostname -s)
```

- If `$HOSTNAME` = `ATL-dev` or `dev` → Skip Docker + localhost checks. Show: "⏭️ Remote environment — Docker checks skipped (coding-only VM)"
- If `$HOSTNAME` = `sgagnon` (laptop) → Run all checks with localhost URLs
- Otherwise → Attempt checks, warn if they fail with "Unknown environment"

```bash
HOSTNAME=$(hostname -s)

if [ "$HOSTNAME" = "ATL-dev" ] || [ "$HOSTNAME" = "dev" ]; then
  echo "⏭️ Remote environment — Docker checks skipped (coding-only VM)"
  # Only check Forgejo (remote-accessible)
  curl -sf -m 3 -H "Authorization: token ${FORGEJO_TOKEN:-}" "${FORGEJO_URL}${FORGEJO_API_PATH}/user" 2>/dev/null || \
    curl -sf -m 3 "${FORGEJO_URL}${FORGEJO_API_PATH}/version" 2>/dev/null  # 5. Forgejo
else
  curl -sf -m 3 http://localhost:8001/health             # 1. Synapse backend
  docker ps --filter name=synapse -q 2>/dev/null | wc -l  # 2. Synapse containers (>0)
  docker exec synapse-db pg_isready 2>/dev/null || pg_isready -h localhost -p 5433 2>/dev/null  # 3. PostgreSQL (try docker first, then local)
  docker exec synapse-valkey redis-cli ping 2>/dev/null   # 4. Valkey
  curl -sf -m 3 -H "Authorization: token ${FORGEJO_TOKEN:-}" "${FORGEJO_URL}${FORGEJO_API_PATH}/user" 2>/dev/null || \
    curl -sf -m 3 "${FORGEJO_URL}${FORGEJO_API_PATH}/version" 2>/dev/null  # 5. Forgejo (try auth first, then public)

  if [ "$HOSTNAME" != "sgagnon" ]; then
    echo "⚠️ Unknown environment ($HOSTNAME) — service checks may be inaccurate"
  fi
fi
```

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

Detect plugin root — supports BOTH marketplace cache (`.claude-plugin/plugin.json` only) and source repo layouts:
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ]; then
  # Try marketplace cache first (minimal: only plugin.json + marketplace.json)
  PLUGIN_JSON=$(find ~/.claude/plugins/cache -name "plugin.json" -path "*/atlas-*" 2>/dev/null | head -1)
  if [ -n "$PLUGIN_JSON" ]; then
    PLUGIN_ROOT=$(dirname "$PLUGIN_JSON")
    # Marketplace cache may be a .claude-plugin dir with just plugin.json
    # The parent dir (version dir) has skills/agents/commands/hooks
    PLUGIN_PARENT=$(dirname "$PLUGIN_ROOT")
    if [ -d "${PLUGIN_PARENT}/skills" ]; then
      PLUGIN_ROOT="$PLUGIN_PARENT"
    fi
  fi
fi
```

```bash
# 1. Version — read from plugin.json (works in both cache and source layouts)
python3 -c "import json; d=json.load(open('${PLUGIN_ROOT}/plugin.json' if __import__('os').path.isfile('${PLUGIN_ROOT}/plugin.json') else '${PLUGIN_ROOT}/.claude-plugin/plugin.json')); print(d.get('version','?'))" 2>/dev/null || cat "${PLUGIN_ROOT}/VERSION" 2>/dev/null

# 2-4. Skills/Agents/Commands — check plugin root AND .claude-plugin subdir
SKILLS=$(ls "${PLUGIN_ROOT}"/skills/*/SKILL.md 2>/dev/null | wc -l)
AGENTS=$(ls "${PLUGIN_ROOT}"/agents/*/AGENT.md 2>/dev/null | wc -l)
CMDS=$(ls "${PLUGIN_ROOT}"/commands/*.md 2>/dev/null | wc -l)

# 5. hooks.json valid
cat "${PLUGIN_ROOT}"/hooks/hooks.json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin); print('valid')"

# 6. Hook scripts (>5)
ls "${PLUGIN_ROOT}"/hooks/ 2>/dev/null | grep -v hooks.json | wc -l

# 7. Plugin CLAUDE.md
[ -f "${PLUGIN_ROOT}/CLAUDE.md" ]

# 8. Effort metadata in skills
grep -rl "^effort:" "${PLUGIN_ROOT}"/skills/*/SKILL.md 2>/dev/null | wc -l
```

#### 7b. Version Skew Detection (v2)

After checking plugin version (check #1), compare versions across all installed tiers in cache:

```bash
CACHE_BASE="$HOME/.claude/plugins/cache"

declare -A tier_versions
for tier_dir in "$CACHE_BASE"/atlas-*/; do
  [ -d "$tier_dir" ] || continue
  tier=$(basename "$tier_dir")
  pj="${tier_dir}.claude-plugin/plugin.json"
  [ ! -f "$pj" ] && pj="${tier_dir}plugin.json"
  if [ -f "$pj" ]; then
    ver=$(python3 -c "import json; print(json.load(open('$pj'))['version'])" 2>/dev/null || echo "?")
    tier_versions[$tier]="$ver"
  fi
done

# Detect skew — all installed tiers should be at the same version
LATEST=$(for v in "${tier_versions[@]}"; do echo "$v"; done | sort -V | tail -1)
SKEW=0
for tier in $(echo "${!tier_versions[@]}" | tr ' ' '\n' | sort); do
  ver="${tier_versions[$tier]}"
  if [ "$ver" = "$LATEST" ]; then
    echo "  $tier: v$ver ✅"
  else
    echo "  $tier: v$ver ⚠️ SKEW"
    SKEW=1
  fi
done

if [ $SKEW -eq 1 ]; then
  echo ""
  echo "⚠️ Plugin version skew detected"
  echo "   [FIX] Navigate to the plugin source directory (atlas-dev-plugin/) and run: make dev"
fi
```

Display example:
```
Plugin Version Sync:
  atlas-admin: v4.16.0 ✅
  atlas-dev:   v4.16.0 ✅
  atlas-user:  v4.15.2 ⚠️ SKEW
  atlas-core:  v4.15.0 ⚠️ SKEW

⚠️ Plugin version skew detected
   [FIX] Navigate to the plugin source directory (atlas-dev-plugin/) and run: make dev
```

**NOTE**: Marketplace-cached plugins may store ONLY `plugin.json` + `marketplace.json` in `.claude-plugin/`.

#### 7c. Token Budget & Skill Usage (v3)

Estimate system prompt token cost and show skill usage analytics:

```bash
# Token budget estimation (skills contribute ~2K tokens each to system prompt)
SKILL_COUNT=$(find "$PLUGIN_ROOT" -path "*/skills/*/SKILL.md" 2>/dev/null | wc -l)
ESTIMATED_TOKENS=$((SKILL_COUNT * 2000))
echo "📊 Token Budget: ~${ESTIMATED_TOKENS} tokens (${SKILL_COUNT} skills × ~2K avg)"
if [ $ESTIMATED_TOKENS -gt 150000 ]; then
  echo "⚠️ HIGH token usage — consider 'make dev-slim' for daily work (~35K tokens)"
fi

# Skill usage analytics (from skill-usage-tracker hook)
USAGE_FILE="$HOME/.atlas/skill-usage.jsonl"
if [ -f "$USAGE_FILE" ]; then
  TOTAL=$(wc -l < "$USAGE_FILE")
  UNIQUE=$(jq -r '.skill' "$USAGE_FILE" 2>/dev/null | sort -u | wc -l)
  echo "📈 Skill Usage: $TOTAL invocations across $UNIQUE unique skills"
  echo "   Top 5:"
  jq -r '.skill' "$USAGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | \
    awk '{printf "     %s (%d)\n", $2, $1}'
  UNUSED=$((SKILL_COUNT - UNIQUE))
  if [ $UNUSED -gt 10 ]; then
    echo "   💤 $UNUSED skills never invoked — run: atlas plugin usage"
  fi
else
  echo "📈 Skill Usage: no data yet (skill-usage-tracker hook collects this)"
fi
```
Skills, agents, hooks, and commands are loaded at runtime by CC's plugin system — not as local files.
If checks 2-8 return 0 but the plugin is functional (skills load in CC), this is expected for marketplace plugins.
Score accordingly: version ✅ from plugin.json = 1pt, runtime-loaded = trust CC's plugin loader for remaining 7pts.

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

## Auto-Fix Mode

### `--fix` (HITL — recommended)

Interactive review of each issue, one by one:

1. Run all checks (same as read-only mode)
2. Collect all failures, sort by priority: ❌ (critical) before ⚠️ (warning)
3. For **each** issue, use AskUserQuestion with:
   - Detailed explanation of the problem and its impact
   - Proposed fix command
   - Options: `["Oui, fixer", "Skip", "Arrêter les fixes"]`
4. If approved → execute fix command → re-run check → show result (✅ or still ❌)
5. Continue to next issue

### [FIX] Tag Format (v2)

For common issues, append a `[FIX]` hint inline with the warning. Use this format throughout all categories:

```
⚠️ Plugin version skew detected
   [FIX] Navigate to the plugin source directory (atlas-dev-plugin/) and run: make dev

⚠️ Missing tool: yq
   [FIX] sudo snap install yq  (Ubuntu) | brew install yq (macOS)

⚠️ SYNAPSE_TOKEN missing or invalid
   [FIX] Add to ~/.env: export SYNAPSE_TOKEN=<token>  then: source ~/.env

❌ Docker not in PATH
   [FIX] sudo apt install docker.io && sudo usermod -aG docker $USER

⚠️ CC Settings: missing deny rules
   [FIX] /atlas update-config add-deny-rules

⚠️ StatusLine scripts not deployed
   [FIX] /atlas statusline-setup

⚠️ Project CLAUDE.md missing
   [FIX] /atlas setup context
```

`[FIX]` tags appear in read-only mode too (as hints). In `--fix` mode, they become the proposed command for HITL review.

### `--fix-all` (batch)

Apply all fixes without per-issue review:

1. Run all checks → collect failures
2. AskUserQuestion: "X issues trouvées. Appliquer tous les fixes automatiquement?"
3. If approved → execute all fixes in priority order
4. Re-run all checks → show before/after comparison table

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
[ -d "${ATLAS_ROOT:-}" ] || [ -n "${ATLAS_ROOT:-}" ]

# 8. DX tools (fzf + zoxide + bat minimum)
command -v fzf && command -v zoxide && (command -v bat || command -v batcat)
```

Platform-aware auto-fix suggestions:
| Issue | Linux/WSL | macOS |
|-------|-----------|-------|
| CC missing | `curl -fsSL https://claude.ai/install \| sh` | same |
| Aliases missing | `/atlas setup` or `scripts/shell-aliases.sh >> ~/.zshrc` | `>> ~/.zshrc` |
| ATLAS_ROOT missing | `echo 'export ATLAS_ROOT=...' >> ~/.zshrc` | same |
| Workspace missing | `mkdir -p $ATLAS_ROOT` (set ATLAS_ROOT first) | same |

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

# 3. ATLAS StatusLine helper scripts deployed (alert + resolve-version)
[ -x "${HOME}/.local/share/atlas-statusline/atlas-alert-module.sh" ] && \
[ -x "${HOME}/.local/share/atlas-statusline/atlas-resolve-version.sh" ]

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

### Cat 11: CC Settings (15 checks)

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

# 9. Plan mode shows clear context option (CC 2.1.75+)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
v=d.get('showClearContextOnPlanAccept', False)
print('ok' if v else 'MISSING showClearContextOnPlanAccept')
"

# 10. includeGitInstructions = false (ATLAS manages git via skills)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
v=d.get('includeGitInstructions', True)
print('ok' if not v else 'WARN includeGitInstructions should be false')
"

# 11. Global env: MAX_OUTPUT_TOKENS (Opus 4.6 = 128K)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
v=d.get('env',{}).get('CLAUDE_CODE_MAX_OUTPUT_TOKENS','')
print('ok' if v else 'MISSING CLAUDE_CODE_MAX_OUTPUT_TOKENS in global env')
"

# 12. Global env: MAX_THINKING_TOKENS (Opus 4.6 1M context)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
v=d.get('env',{}).get('CLAUDE_CODE_MAX_THINKING_TOKENS','')
print('ok' if v else 'MISSING CLAUDE_CODE_MAX_THINKING_TOKENS in global env')
"

# 13. Global env: FILE_READ_MAX_OUTPUT_TOKENS
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
v=d.get('env',{}).get('CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS','')
print('ok' if v else 'MISSING CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS in global env')
"

# 14. Security deny rules include Read(~/.ssh/**) and Read(/etc/shadow)
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
deny=d.get('permissions',{}).get('deny',[])
ssh_ok='Read(~/.ssh/**)' in deny
shadow_ok='Read(/etc/shadow)' in deny
missing=[]
if not ssh_ok: missing.append('Read(~/.ssh/**)')
if not shadow_ok: missing.append('Read(/etc/shadow)')
print('ok' if not missing else f'MISSING deny rules: {missing}')
"

# 15. PostCompact + StopFailure hooks configured
cat "$GLOBAL" | python3 -c "
import sys,json; d=json.load(sys.stdin)
hooks=d.get('hooks',{})
missing=[]
if 'PostCompact' not in hooks: missing.append('PostCompact')
if 'StopFailure' not in hooks: missing.append('StopFailure')
print('ok' if not missing else f'MISSING hooks: {missing}')
"
```

Auto-fix suggestions:
| Issue | Fix |
|-------|-----|
| Plugin not enabled | Add to project `.claude/settings.json` enabledPlugins |
| Missing permissions | Add required permissions to global settings |
| Missing hooks | Copy hook templates from ATLAS plugin |
| Missing global commands | Copy from `~/.claude/commands/` templates |
| Missing language | Add `"language": "francais"` to global settings |
| Missing showClearContextOnPlanAccept | Add `"showClearContextOnPlanAccept": true` to global settings |
| includeGitInstructions not false | Set `"includeGitInstructions": false` — ATLAS manages git via skills |
| Missing MAX_OUTPUT_TOKENS | Add `"CLAUDE_CODE_MAX_OUTPUT_TOKENS": "128000"` to global env (Opus 4.6) |
| Missing MAX_THINKING_TOKENS | Add `"CLAUDE_CODE_MAX_THINKING_TOKENS": "250000"` to global env (1M context) |
| Missing FILE_READ_MAX | Add `"CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS": "50000"` to global env |
| Missing deny Read(~/.ssh/**) | Add `"Read(~/.ssh/**)"` and `"Read(/etc/shadow)"` to permissions.deny |
| Missing PostCompact hook | Wire `$HOME/.claude/hooks/post-compact.sh` in global hooks |
| Missing StopFailure hook | Add API error logging hook to global settings |

### Cat 12: External Tools Health (dynamic, score 0-10)

**Trigger shortcut**: `/atlas doctor plugins` — runs ONLY this category for quick checks.

**How it works**: Reads the external capabilities cache (`~/.atlas/data/external-tools-cache.json`) produced by the SessionStart `external-capabilities` hook. If cache is missing or stale (>48h), re-runs the discovery hook first.

```bash
CACHE="$HOME/.atlas/data/external-tools-cache.json"
REGISTRY="$HOME/.claude/plugins/installed_plugins.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
REF_DIR="${PLUGIN_ROOT}/skills/refs/external-tools"

# Re-scan if cache missing or stale
if [ ! -f "$CACHE" ] || [ $(($(date +%s) - $(stat -c '%Y' "$CACHE" 2>/dev/null || echo 0))) -gt 172800 ]; then
  "$PLUGIN_ROOT/hooks/external-capabilities" >/dev/null 2>&1 || true
fi

# Dynamic health check
python3 -c "
import json, os, sys

cache_path = '$CACHE'
ref_dir = '$REF_DIR'
registry_path = '$REGISTRY'

if not os.path.isfile(cache_path):
    print('❌ Cache missing — run: hooks/external-capabilities')
    sys.exit(0)

with open(cache_path) as f:
    cache = json.load(f)

score = 10
issues = []
fixes = []

# Check each discovered plugin
for p in cache.get('plugins', []):
    name = p['name']
    has_mcp = p.get('has_mcp', False)
    has_ref = os.path.isfile(os.path.join(ref_dir, f'{name}.md'))

    # MCP plugin without reference doc
    if has_mcp and not has_ref:
        issues.append(f'⚠️  {name}: MCP active but no usage docs')
        fixes.append(f'Create references/external-tools/{name}.md from _TEMPLATE.md')
        score -= 0.5

# Check for reference orphans (reference file but plugin not installed)
if os.path.isdir(ref_dir):
    installed_names = {p['name'] for p in cache.get('plugins', [])}
    for ref_file in os.listdir(ref_dir):
        if ref_file.startswith('_') or not ref_file.endswith('.md'):
            continue
        ref_name = ref_file.replace('.md', '')
        # LSP refs use the LSP tool directly, not a plugin
        if ref_name in ('typescript-lsp', 'jdtls-lsp'):
            continue
        if ref_name not in installed_names:
            issues.append(f'⚠️  {ref_name}.md: reference exists but plugin not installed')
            fixes.append(f'Install: /plugin install {ref_name}  OR  remove stale ref')
            score -= 0.5

# Check LSP servers
for lsp in cache.get('lsp_servers', []):
    lsp_id = lsp['id']
    has_ref = os.path.isfile(os.path.join(ref_dir, f'{lsp_id}.md'))
    if not has_ref:
        issues.append(f'⚠️  {lsp_id}: LSP installed but no usage docs')
        score -= 0.5

# Check project MCP servers
for mcp in cache.get('mcp_servers', []):
    if not mcp.get('enabled', True):
        issues.append(f'❌ {mcp[\"name\"]}: project MCP server disabled')
        fixes.append(f'Enable in .claude/settings.local.json enabledMcpjsonServers')
        score -= 1

score = max(0, min(10, int(score)))
status = '✅' if score >= 8 else '⚠️' if score >= 5 else '❌'

# Output
total_plugins = len(cache.get('plugins', []))
total_mcp = sum(1 for p in cache.get('plugins', []) if p.get('has_mcp'))
total_lsp = len(cache.get('lsp_servers', []))

print(f'{status} External Tools: {score}/10 — {total_plugins} plugins, {total_mcp} MCP, {total_lsp} LSP')
for issue in issues:
    print(f'   {issue}')
if fixes:
    print()
    print('🔧 Auto-fix suggestions (HITL gate required):')
    for i, fix in enumerate(fixes, 1):
        print(f'   {i}. {fix}')
"
```

**Scoring**:
- 10/10: All tools healthy, all MCP-active plugins have reference docs
- 7-9: Minor issues (missing reference files for optional plugins)
- 4-6: MCP servers disabled or critical tools without docs
- 0-3: Cache missing or major configuration problems

**Auto-fix actions** (all require HITL confirmation via AskUserQuestion):
- Plugin not installed → `/plugin install {name}`
- MCP not enabled → add to `enabledMcpjsonServers` in settings
- Reference orphan → remove stale `.md` file or install missing plugin
- Cache stale → re-run `hooks/external-capabilities`

Display:
```
🏛️ ATLAS │ 🔌 PLUGINS │ {score}/10
   {N} plugins │ {N} MCP │ {N} LSP
   ⚠️ {issues if any}
   🔧 {N} fixes available
```

### Cat 13: Domain Plugin Health (SP-ECO v4)

Check domain plugin installation status for the new multi-plugin architecture:

```bash
# 1. Old monolithic marketplace detection
if [ -d "$HOME/.claude/plugins/cache/atlas-admin-marketplace" ]; then
  echo "⚠️ Legacy atlas-admin-marketplace detected. Run: scripts/migrate-marketplace.sh"
fi

# 2. Core dependency check
if [ ! -d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core" ]; then
  echo "❌ atlas-core not installed — required by all ATLAS domain plugins"
fi

# 3. Orphan domain check — each domain plugin requires atlas-core
for domain_dir in "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-"*/; do
  [ ! -d "$domain_dir" ] && continue
  domain=$(basename "$domain_dir")
  [ "$domain" = "atlas-core" ] && continue
  if [ ! -d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core" ]; then
    echo "⚠️ $domain installed without atlas-core — hooks and session management won't work"
  fi
done

# 4. Plugin count report
installed=$(find "$HOME/.claude/plugins/cache/atlas-marketplace" -maxdepth 1 -type d -name "atlas-*" 2>/dev/null | wc -l)
echo "ATLAS domain plugins: $installed/6 installed"
```

Domain plugins (6 total):
| Plugin | Purpose |
|--------|---------|
| `atlas-core` | Memory, session, context, vault (REQUIRED by all) |
| `atlas-dev` | Planning, TDD, debugging, code review, shipping |
| `atlas-frontend` | UI design, browser automation, visual QA |
| `atlas-infra` | Infrastructure, deploy, security, network |
| `atlas-enterprise` | Governance, knowledge engine, agent teams |
| `atlas-experiential` | Episode capture, intuition, relationships |

Status logic:
- ✅ = atlas-core present + ≥1 domain plugin installed
- ⚠️ = legacy monolithic detected OR orphan domain (missing core)
- ❌ = no atlas-core and no legacy plugin

Auto-fix: dispatch to `atlas setup plugins` for interactive domain selection, or run `scripts/migrate-marketplace.sh --preset dev` directly.

### Cat 14: Observability Stack Health

Check the LGTM observability stack on VM 602 (ref: `refs/observability-api`):

```bash
# 1. Loki reachable
LOKI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://192.168.10.56:3100/ready" 2>/dev/null)
[ "$LOKI_STATUS" = "200" ] && echo "✅ Loki ready" || echo "❌ Loki unreachable ($LOKI_STATUS)"

# 2. Prometheus reachable
PROM_STATUS=$(curl -s --max-time 5 "http://192.168.10.56:9090/-/healthy" 2>/dev/null)
echo "$PROM_STATUS" | grep -q "Healthy" && echo "✅ Prometheus healthy" || echo "❌ Prometheus unreachable"

# 3. Error rate acceptable (< 50 errors/h)
ERROR_COUNT=$(curl -sG "http://192.168.10.56:3100/loki/api/v1/query" \
  --data-urlencode 'query=sum(count_over_time({container=~"synapse-prod.*"} |~ "(?i)error" [1h]))' \
  2>/dev/null | jq -r '.data.result[0].value[1] // "0"')
[ "${ERROR_COUNT:-0}" -lt 50 ] && echo "✅ Error rate: $ERROR_COUNT/h" || echo "⚠️ Error rate high: $ERROR_COUNT/h"

# 4. Scrape targets all UP
DOWN_TARGETS=$(curl -sG "http://192.168.10.56:9090/api/v1/query" \
  --data-urlencode 'query=up == 0' 2>/dev/null | jq -r '.data.result | length')
[ "${DOWN_TARGETS:-0}" -eq 0 ] && echo "✅ All scrape targets UP" || echo "⚠️ $DOWN_TARGETS targets DOWN"

# 5. No unhealthy containers (SSH to prod)
UNHEALTHY=$(ssh root@192.168.10.50 "docker ps --filter 'health=unhealthy' --format '{{.Names}}' | grep synapse" 2>/dev/null | wc -l)
[ "${UNHEALTHY:-0}" -eq 0 ] && echo "✅ All Synapse containers healthy" || echo "⚠️ $UNHEALTHY unhealthy containers"
```

Status logic:
- ✅ = All 5 checks pass
- ⚠️ = Error rate > 50/h OR targets down OR unhealthy containers
- ❌ = Loki or Prometheus unreachable

Auto-fix: restart obs-* containers on VM 602 via `ssh sgagnon@192.168.10.56 "cd /opt/observability && docker compose restart"`. For unhealthy Synapse containers, SSH to VM 550 and restart the affected service.

## Dream Health Integration (v2)

Read the latest dream report from the memory directory and include in the scoring summary:

```bash
# Find the memory directory for this project
MEMORY_DIR=$(find ~/.claude/projects -name "MEMORY.md" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")

DREAM_LINE="Dream Health: ⏭️ No dream reports found"
if [ -n "$MEMORY_DIR" ]; then
  DREAM_FILE=$(ls -t "$MEMORY_DIR"/dream-report-*.md 2>/dev/null | head -1)
  if [ -n "$DREAM_FILE" ]; then
    DREAM_DATE=$(basename "$DREAM_FILE" | sed 's/dream-report-\(.*\)\.md/\1/')
    DREAM_GRADE=$(grep -m1 -oP '(?i)grade[:\s]+([A-F][+\-]?)' "$DREAM_FILE" 2>/dev/null | grep -oP '[A-F][+\-]?' | head -1 || echo "?")
    DREAM_SCORE=$(grep -oP '[0-9]+\.[0-9]+/10' "$DREAM_FILE" 2>/dev/null | head -1 || echo "?/10")
    DREAM_LINE="Dream Health: ${DREAM_GRADE:-?} ${DREAM_SCORE} ($DREAM_DATE)"
  fi
fi
echo "$DREAM_LINE"
```

Display in scoring table footer:
```
Dream Health: B+ 8.91/10 (2026-04-04)
```

## Hook Performance Profiling (P2-HOOK-4)

Read `~/.claude/hook-log.jsonl` and report hook timing statistics.

```bash
HOOK_LOG="$HOME/.claude/hook-log.jsonl"
if [ -f "$HOOK_LOG" ]; then
  python3 -c "
import json
from datetime import datetime, timedelta
from collections import defaultdict

cutoff = (datetime.now() - timedelta(hours=24)).isoformat()
stats = defaultdict(list)  # handler → [ms values]

with open('$HOOK_LOG') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
            if e.get('ts','') >= cutoff:
                stats[e['handler']].append(int(e.get('ms', 0)))
        except: pass

if stats:
    print('Hook Performance (24h):')
    print(f'  {\"Handler\":<30} {\"Calls\":>6} {\"Avg ms\":>8} {\"Max ms\":>8} {\"Status\":>8}')
    print('  ' + '─'*62)
    for handler, times in sorted(stats.items(), key=lambda x: -max(x[1])):
        avg = sum(times) / len(times)
        mx = max(times)
        status = '⚠️ SLOW' if avg > 3000 else '✅'
        print(f'  {handler:<30} {len(times):>6} {avg:>8.0f} {mx:>8} {status:>8}')
else:
    print('Hook Performance: No data in last 24h')
"
fi
```

**Warning thresholds**:
- Average > 3000ms (3s) → ⚠️ SLOW
- Max > 5000ms (5s) → 🔴 CRITICAL
- Include in doctor category `hooks` scoring: +1 if all hooks < 3s avg, -1 per slow hook

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
