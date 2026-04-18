---
name: atlas-doctor
description: "System health check with auto-fix for the ATLAS ecosystem. 8-category diagnostic: OS, permissions, tools, tokens, services, Claude Code, plugin, project context. Use when 'doctor', 'diagnose', 'health check', 'verify installation', 'system status', 'troubleshoot', 'doctor plugins', 'check plugins', 'external tools health', or 'plugin health'."
effort: medium
---

# ATLAS Doctor — System Health Dashboard

Comprehensive ATLAS ecosystem diagnostic across 14 categories. Bash checks, scored dashboard, optional auto-fixes with HITL approval.

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas doctor` | Full health dashboard (read-only) |
| `/atlas doctor plugins` | External tools health only (Cat 12) — fast + auto-fix |
| `/atlas doctor --fix` | Dashboard + per-issue HITL review and fix |
| `/atlas doctor --fix-all` | Dashboard + apply all fixes batch (no per-issue HITL) |
| `/atlas doctor tokens|tools|services|project` | Subset only |

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
| 9  | Terminal & Launch| 6/8   | ⚠️     | No completions, ROOT    |
| 10 | StatusLine       | 4/5   | ⚠️     | Scripts not deployed    |
| 11 | CC Settings      | 13/15 | ⚠️     | Missing language config |
| 12 | MCP & Plugins    | 5/6   | ⚠️     | Figma optional          |
| 13 | Domain Plugins   | 4/4   | ✅     |                         |
| 14 | Observability    | 5/5   | ✅     |                         |

OVERALL: 70/81 (86%) ⚠️
```

Status: ✅ 100% | ⚠️ 50-99% | ❌ <50%

## Per-Category Scoring Summary (v2)

Append letter-grade table after all checks (per-row format: `Category | Grade | Issues`, with footer `OVERALL | <grade> | <total>` and `Dream Health: <grade> <score>/10 (<date>)` line below).

**Per-category grade**: A=0 issues | B=1 (80-99%) | C=2 (60-79%) | D=3+ (40-59%) | F=critical (<40% or ❌)

**OVERALL grade**: A+ all-A/0 issues | A=0-1 issues | B+=2-4, no F | B=5-7, no F | C=8-12 or 1F | D=13+ or 2+F | F=≥3F or critical fail

## Checks by Category

### Cat 1: OS & Shell (5 checks)

```bash
uname -s                              # 1. OS type (Linux/Darwin)
uname -r                              # 2. Kernel
basename "$SHELL"                     # 3. Shell (zsh/bash)
locale 2>/dev/null | grep -q "UTF-8"  # 4. UTF-8 locale
hostname -s                           # 5. Hostname
```

### Cat 2: Permissions (5 checks)

```bash
[ -w "${HOME}/.claude" ]                                        # 1. Claude dir
[ -w "${HOME}/.atlas" ] || mkdir -p "${HOME}/.atlas"            # 2. Atlas dir
git config user.name >/dev/null 2>&1                            # 3. Git
[ -f "${HOME}/.ssh/id_ed25519" ] || [ -f "${HOME}/.ssh/id_rsa" ] # 4. SSH key
groups | grep -q docker                                         # 5. Docker group
```

### Cat 3: Tools (8 checks)

```bash
for t in bash yq python3 bun docker git jq curl; do command -v $t; done
```

Auto-fix:
| Tool | Ubuntu/Debian | macOS |
|------|---------------|-------|
| yq | `sudo snap install yq` | `brew install yq` |
| bun | `curl -fsSL https://bun.sh/install \| bash` | same |
| jq | `sudo apt install jq` | `brew install jq` |
| docker | `sudo apt install docker.io` | Docker Desktop |

### Cat 4: Tokens (4 checks)

Check existence + API validity. Read config from `~/.atlas/config.json`:

```bash
atlas_config() {
  python3 -c "
import json, os
try:
    d = json.load(open(os.path.expanduser('~/.atlas/config.json')))
    v = d
    for k in '$1'.split('.'): v = v[k]
    print(' '.join(v) if isinstance(v, list) else v)
except: print('${2:-}')
" 2>/dev/null
}

SYNAPSE_URL=$(atlas_config "services.synapse.url" "http://localhost:8001")
FORGEJO_URL=$(atlas_config "services.forgejo.local_url" "")
FORGEJO_API_PATH=$(atlas_config "services.forgejo.api_path" "/api/v1")
AUTHENTIK_URL_CFG=$(atlas_config "services.authentik.url" "")

# SYNAPSE_TOKEN — Backend API
[ -n "${SYNAPSE_TOKEN:-}" ] && curl -sf -m 3 -H "Authorization: Bearer $SYNAPSE_TOKEN" "${SYNAPSE_URL}/api/v1/health" >/dev/null
# FORGEJO_TOKEN — Git API
[ -n "${FORGEJO_TOKEN:-}" ] && [ -n "$FORGEJO_URL" ] && curl -sf -m 3 -H "Authorization: token $FORGEJO_TOKEN" "${FORGEJO_URL}${FORGEJO_API_PATH}/user" >/dev/null
# AUTHENTIK_TOKEN — SSO (optional)
[ -n "${AUTHENTIK_TOKEN:-}" ] && [ -n "$AUTHENTIK_URL_CFG" ] && curl -sf -m 3 -H "Authorization: Bearer $AUTHENTIK_TOKEN" "${AUTHENTIK_URL:-$AUTHENTIK_URL_CFG}/api/v3/core/users/me/" >/dev/null
# GEMINI_API_KEY — existence only
[ -n "${GEMINI_API_KEY:-}" ]
```

States: ✅ present + valid | ⚠️ present but failed | ❌ missing | ⏭️ AUTHENTIK optional

Auto-fix: guide user to add to `~/.env`, then `source ~/.env`.

### Cat 5: Services (5 checks)

**Environment detection first**:
```bash
HOSTNAME=$(hostname -s)
```

- `ATL-dev`/`dev` → Skip Docker + localhost. Check Forgejo only. Show "⏭️ Remote env — Docker skipped"
- `sgagnon` (laptop) → All checks with localhost
- Otherwise → warn "Unknown environment"

```bash
if [ "$HOSTNAME" = "ATL-dev" ] || [ "$HOSTNAME" = "dev" ]; then
  echo "⏭️ Remote environment — Docker checks skipped"
  curl -sf -m 3 -H "Authorization: token ${FORGEJO_TOKEN:-}" "${FORGEJO_URL}${FORGEJO_API_PATH}/user" 2>/dev/null || \
    curl -sf -m 3 "${FORGEJO_URL}${FORGEJO_API_PATH}/version" 2>/dev/null
else
  curl -sf -m 3 http://localhost:8001/health                                                      # 1. Synapse backend
  docker ps --filter name=synapse -q 2>/dev/null | wc -l                                          # 2. Synapse containers
  docker exec synapse-db pg_isready 2>/dev/null || pg_isready -h localhost -p 5433 2>/dev/null   # 3. PostgreSQL
  docker exec synapse-valkey redis-cli ping 2>/dev/null                                          # 4. Valkey
  curl -sf -m 3 -H "Authorization: token ${FORGEJO_TOKEN:-}" "${FORGEJO_URL}${FORGEJO_API_PATH}/user" 2>/dev/null || \
    curl -sf -m 3 "${FORGEJO_URL}${FORGEJO_API_PATH}/version" 2>/dev/null                       # 5. Forgejo
  [ "$HOSTNAME" != "sgagnon" ] && echo "⚠️ Unknown environment ($HOSTNAME)"
fi
```

Auto-fix: Backend offline → `docker compose up -d` | Container down → `docker restart synapse-{name}` | Forgejo unreachable → check VPN.

### Cat 6: Claude Code (5 checks)

```bash
claude --version                                                # 1. CC + version
ls ~/.claude/plugins/cache/atlas-* 2>/dev/null | head -1        # 2. Plugin installed
cat ~/.claude/settings.json | python3 -c "import sys,json; json.load(sys.stdin)"  # 3. Settings valid
ls ~/.claude/commands/a-*.md 2>/dev/null | wc -l                # 4. Global commands
[ -f ~/.claude/CLAUDE.md ]                                      # 5. Global CLAUDE.md
```

### Cat 7: ATLAS Plugin (8 checks)

Detect plugin root (supports cache + source repo):
```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ]; then
  PLUGIN_JSON=$(find ~/.claude/plugins/cache -name "plugin.json" -path "*/atlas-*" 2>/dev/null | head -1)
  if [ -n "$PLUGIN_JSON" ]; then
    PLUGIN_ROOT=$(dirname "$PLUGIN_JSON")
    PLUGIN_PARENT=$(dirname "$PLUGIN_ROOT")
    [ -d "${PLUGIN_PARENT}/skills" ] && PLUGIN_ROOT="$PLUGIN_PARENT"
  fi
fi
```

```bash
# 1. Version (works in cache + source)
python3 -c "import json,os; p='${PLUGIN_ROOT}/plugin.json' if os.path.isfile('${PLUGIN_ROOT}/plugin.json') else '${PLUGIN_ROOT}/.claude-plugin/plugin.json'; print(json.load(open(p)).get('version','?'))" 2>/dev/null || cat "${PLUGIN_ROOT}/VERSION"

# 2-4. Skills/Agents/Commands counts
ls "${PLUGIN_ROOT}"/skills/*/SKILL.md 2>/dev/null | wc -l
ls "${PLUGIN_ROOT}"/agents/*/AGENT.md 2>/dev/null | wc -l
ls "${PLUGIN_ROOT}"/commands/*.md 2>/dev/null | wc -l

# 5. hooks.json valid
cat "${PLUGIN_ROOT}"/hooks/hooks.json 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin)"

# 6. Hook scripts (>5)
ls "${PLUGIN_ROOT}"/hooks/ 2>/dev/null | grep -v hooks.json | wc -l

# 7. Plugin CLAUDE.md
[ -f "${PLUGIN_ROOT}/CLAUDE.md" ]

# 8. Effort metadata in skills
grep -rl "^effort:" "${PLUGIN_ROOT}"/skills/*/SKILL.md 2>/dev/null | wc -l
```

#### 7b. Version Skew Detection (v2)

Compare versions across all installed tiers:

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
LATEST=$(for v in "${tier_versions[@]}"; do echo "$v"; done | sort -V | tail -1)
SKEW=0
for tier in $(echo "${!tier_versions[@]}" | tr ' ' '\n' | sort); do
  ver="${tier_versions[$tier]}"
  if [ "$ver" = "$LATEST" ]; then echo "  $tier: v$ver ✅"
  else echo "  $tier: v$ver ⚠️ SKEW"; SKEW=1; fi
done
[ $SKEW -eq 1 ] && echo "⚠️ Plugin version skew detected. [FIX] cd atlas-dev-plugin/ && make dev"
```

**NOTE**: Marketplace-cached plugins may store ONLY `plugin.json` + `marketplace.json` in `.claude-plugin/`.

#### 7c. Token Budget & Skill Usage (v3)

```bash
SKILL_COUNT=$(find "$PLUGIN_ROOT" -path "*/skills/*/SKILL.md" 2>/dev/null | wc -l)
ESTIMATED_TOKENS=$((SKILL_COUNT * 2000))
echo "📊 Token Budget: ~${ESTIMATED_TOKENS} tokens (${SKILL_COUNT} skills × ~2K)"
[ $ESTIMATED_TOKENS -gt 150000 ] && echo "⚠️ HIGH — consider 'make dev-slim' (~35K tokens)"

USAGE_FILE="$HOME/.atlas/skill-usage.jsonl"
if [ -f "$USAGE_FILE" ]; then
  TOTAL=$(wc -l < "$USAGE_FILE")
  UNIQUE=$(jq -r '.skill' "$USAGE_FILE" 2>/dev/null | sort -u | wc -l)
  echo "📈 Skill Usage: $TOTAL invocations, $UNIQUE unique"
  jq -r '.skill' "$USAGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -5 | awk '{printf "     %s (%d)\n", $2, $1}'
  UNUSED=$((SKILL_COUNT - UNIQUE))
  [ $UNUSED -gt 10 ] && echo "   💤 $UNUSED skills never invoked — run: atlas plugin usage"
else
  echo "📈 Skill Usage: no data yet"
fi
```

Skills/agents/hooks/commands loaded at runtime by CC. Marketplace plugins: trust loader for runtime checks.

### Cat 8: Project Context (5 checks)

```bash
[ -f CLAUDE.md ]                                                                              # 1. Project CLAUDE.md
[ -d .claude/rules ] && ls .claude/rules/*.md 2>/dev/null | wc -l                             # 2. Rules
[ -f .blueprint/FEATURES.md ]                                                                 # 3. Feature registry
MEMORY_DIR=$(find ~/.claude/projects -name "MEMORY.md" -path "*$(basename $(pwd))*" | head -1)
[ -n "$MEMORY_DIR" ]                                                                          # 4. Memory
[ -d .blueprint/plans ]                                                                       # 5. Plans
```

Auto-fix: dispatch `/atlas setup context`.

## Auto-Fix Mode

### `--fix` (HITL — recommended)

Per-issue review: collect failures → sort ❌ first → AskUserQuestion per issue (problem + impact + proposed fix → `["Oui, fixer", "Skip", "Arrêter"]`) → if approved, execute + re-run + show ✅/❌.

### [FIX] Tag Format (v2)

Append `[FIX]` hint inline (read-only = hint; `--fix` = proposed command):

```
⚠️ Plugin version skew → [FIX] cd atlas-dev-plugin/ && make dev
⚠️ Missing yq → [FIX] sudo snap install yq (Ubuntu) | brew install yq (macOS)
⚠️ SYNAPSE_TOKEN missing → [FIX] Add to ~/.env: export SYNAPSE_TOKEN=<token>; source ~/.env
❌ Docker not in PATH → [FIX] sudo apt install docker.io && sudo usermod -aG docker $USER
⚠️ CC Settings deny rules → [FIX] /atlas update-config add-deny-rules
⚠️ StatusLine not deployed → [FIX] /atlas statusline-setup
⚠️ CLAUDE.md missing → [FIX] /atlas setup context
```

### `--fix-all` (batch)

Run checks → collect failures → AskUserQuestion ("X issues. Appliquer tous?") → execute all in priority order → re-run → before/after comparison.

### Cat 9: Terminal & Launch (8 checks)

Quick: `${PLUGIN_ROOT}/scripts/setup-terminal.sh --check`

```bash
command -v claude                                                                             # 1. CC installed
claude --version 2>/dev/null | grep -qP '2\.\d+\.\d+'                                         # 2. Recent (2.x)
[ -f "${HOME}/.$(basename ${SHELL})rc" ]                                                      # 3. RC file
grep -q "atlas()" "${HOME}/.$(basename ${SHELL})rc" 2>/dev/null                               # 4. Aliases
[ -f "${HOME}/.oh-my-zsh/custom/plugins/atlas/_atlas" ] || [ -f "${HOME}/.local/share/bash-completion/completions/atlas" ]  # 5. Completions
[ -n "${ATLAS_ROOT:-}" ]                                                                      # 6. ATLAS_ROOT env
[ -d "${ATLAS_ROOT:-}" ] || [ -n "${ATLAS_ROOT:-}" ]                                          # 7. Workspace dir
command -v fzf && command -v zoxide && (command -v bat || command -v batcat)                  # 8. DX tools
```

Auto-fix:
| Issue | Linux/WSL | macOS |
|-------|-----------|-------|
| CC missing | `curl -fsSL https://claude.ai/install \| sh` | same |
| Aliases | `/atlas setup` or `scripts/shell-aliases.sh >> ~/.zshrc` | same |
| ATLAS_ROOT | `echo 'export ATLAS_ROOT=...' >> ~/.zshrc` | same |
| Workspace | `mkdir -p $ATLAS_ROOT` | same |

Display:
```
🏛️ ATLAS │ 🖥️ PLATFORM │ {os} {version} │ {shell} │ {terminal}
   └─ Arch: {arch} │ Docker: {bool} │ Starship: {bool} │ CShip: {bool}
```

### Cat 10: StatusLine (5 checks)

```bash
command -v cship && cship --version                                                           # 1. CShip
command -v starship && starship --version                                                     # 2. Starship
[ -x "${HOME}/.local/share/atlas-statusline/atlas-alert-module.sh" ] && \
  [ -x "${HOME}/.local/share/atlas-statusline/atlas-resolve-version.sh" ]                     # 3. Helper scripts deployed
cat "${CLAUDE_PLUGIN_DATA:-$HOME/.claude}/session-state.json" 2>/dev/null | python3 -c "import sys,json; json.load(sys.stdin)"  # 4. session-state valid
cat "${HOME}/.claude/settings.json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('statusLine',{}).get('command','MISSING'))" | grep -qv "MISSING"  # 5. wired
```

Auto-fix: `/atlas statusline-setup`.

```
🏛️ ATLAS │ 📊 STATUSLINE │ CShip: {ver} │ Starship: {ver}
   └─ Scripts: {?} │ State: {?} │ Config: {?}
```

### Cat 11: CC Settings (15 checks)

Check Claude Code global + project settings for ATLAS-required config:

```bash
GLOBAL="${HOME}/.claude/settings.json"
PROJECT=".claude/settings.json"

# Helper: read JSON path from a settings file
sj() { cat "$1" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); $2"; }

# 1. Global valid JSON
sj "$GLOBAL" "print('valid')"
# 2. ATLAS plugin enabled in project
sj "$PROJECT" "p=d.get('enabledPlugins',{}); print('enabled' if any('atlas' in k for k in p) else 'MISSING')"
# 3. Required permissions: Bash, Read, Write, Edit
sj "$GLOBAL" "perms=d.get('permissions',{}).get('allow',[]); req={'Bash','Read','Write','Edit'}; missing=req-set(p.split('(')[0] for p in perms); print('ok' if not missing else f'MISSING: {missing}')"
# 4. Language = francais
sj "$GLOBAL" "print(d.get('language','NOT SET'))"
# 5. Global hooks: UserPromptSubmit
sj "$GLOBAL" "print('ok' if 'UserPromptSubmit' in d.get('hooks',{}) else 'MISSING UserPromptSubmit')"
# 6. Project env: CLAUDE_CODE_MAX_OUTPUT_TOKENS
sj "$PROJECT" "print('ok' if 'CLAUDE_CODE_MAX_OUTPUT_TOKENS' in d.get('env',{}) else 'MISSING')" 2>/dev/null || echo "no project"
# 7. Global a-* commands
ls "${HOME}/.claude/commands/a-"*.md 2>/dev/null | wc -l
# 8. Global CLAUDE.md
[ -f "${HOME}/.claude/CLAUDE.md" ]
# 9. showClearContextOnPlanAccept (CC 2.1.75+)
sj "$GLOBAL" "print('ok' if d.get('showClearContextOnPlanAccept') else 'MISSING')"
# 10. includeGitInstructions = false
sj "$GLOBAL" "print('ok' if not d.get('includeGitInstructions',True) else 'WARN should be false')"
# 11-13. Global env tokens (Opus 4.7 1M context: 128K out, 250K think, 50K file-read)
sj "$GLOBAL" "print('ok' if d.get('env',{}).get('CLAUDE_CODE_MAX_OUTPUT_TOKENS') else 'MISSING MAX_OUTPUT')"
sj "$GLOBAL" "print('ok' if d.get('env',{}).get('CLAUDE_CODE_MAX_THINKING_TOKENS') else 'MISSING MAX_THINKING')"
sj "$GLOBAL" "print('ok' if d.get('env',{}).get('CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS') else 'MISSING FILE_READ_MAX')"
# 14. Security deny rules
sj "$GLOBAL" "deny=d.get('permissions',{}).get('deny',[]); m=[r for r in ['Read(~/.ssh/**)','Read(/etc/shadow)'] if r not in deny]; print('ok' if not m else f'MISSING: {m}')"
# 15. PostCompact + StopFailure hooks
sj "$GLOBAL" "h=d.get('hooks',{}); m=[k for k in ['PostCompact','StopFailure'] if k not in h]; print('ok' if not m else f'MISSING: {m}')"
```

Auto-fix:
| Issue | Fix |
|-------|-----|
| Plugin not enabled | Add to project `enabledPlugins` |
| Missing perms | Add to global `permissions.allow` |
| Missing hooks | Copy templates from ATLAS plugin |
| Missing language | `"language": "francais"` |
| Missing showClearContext | `"showClearContextOnPlanAccept": true` |
| includeGitInstructions | `"includeGitInstructions": false` |
| MAX_OUTPUT_TOKENS | `"CLAUDE_CODE_MAX_OUTPUT_TOKENS": "128000"` |
| MAX_THINKING_TOKENS | `"CLAUDE_CODE_MAX_THINKING_TOKENS": "250000"` |
| FILE_READ_MAX | `"CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS": "50000"` |
| Missing deny | Add `Read(~/.ssh/**)` and `Read(/etc/shadow)` |
| Missing PostCompact/StopFailure | Wire from `$HOME/.claude/hooks/` |

### Cat 12: External Tools Health (dynamic, score 0-10)

**Trigger**: `/atlas doctor plugins` runs ONLY this category.

Reads `~/.atlas/data/external-tools-cache.json` (produced by `external-capabilities` SessionStart hook). Re-scans if missing/stale (>48h).

```bash
CACHE="$HOME/.atlas/data/external-tools-cache.json"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
REF_DIR="${PLUGIN_ROOT}/skills/refs/external-tools"

# Re-scan if stale
if [ ! -f "$CACHE" ] || [ $(($(date +%s) - $(stat -c '%Y' "$CACHE" 2>/dev/null || echo 0))) -gt 172800 ]; then
  "$PLUGIN_ROOT/hooks/external-capabilities" >/dev/null 2>&1 || true
fi

python3 -c "
import json, os, sys
cache_path = '$CACHE'; ref_dir = '$REF_DIR'
if not os.path.isfile(cache_path):
    print('❌ Cache missing — run: hooks/external-capabilities'); sys.exit(0)
cache = json.load(open(cache_path))
score = 10; issues = []; fixes = []

# MCP plugin without docs
for p in cache.get('plugins', []):
    name = p['name']; has_mcp = p.get('has_mcp', False)
    has_ref = os.path.isfile(os.path.join(ref_dir, f'{name}.md'))
    if has_mcp and not has_ref:
        issues.append(f'⚠️  {name}: MCP active but no usage docs')
        fixes.append(f'Create references/external-tools/{name}.md from _TEMPLATE.md')
        score -= 0.5

# Reference orphans
if os.path.isdir(ref_dir):
    installed = {p['name'] for p in cache.get('plugins', [])}
    for ref in os.listdir(ref_dir):
        if ref.startswith('_') or not ref.endswith('.md'): continue
        n = ref.replace('.md','')
        if n in ('typescript-lsp','jdtls-lsp'): continue
        if n not in installed:
            issues.append(f'⚠️  {n}.md: reference exists but plugin not installed')
            fixes.append(f'Install: /plugin install {n}  OR  remove stale ref')
            score -= 0.5

# LSP without docs
for lsp in cache.get('lsp_servers', []):
    if not os.path.isfile(os.path.join(ref_dir, f'{lsp[\"id\"]}.md')):
        issues.append(f'⚠️  {lsp[\"id\"]}: LSP installed but no usage docs'); score -= 0.5

# Project MCP disabled
for mcp in cache.get('mcp_servers', []):
    if not mcp.get('enabled', True):
        issues.append(f'❌ {mcp[\"name\"]}: project MCP disabled')
        fixes.append(f'Enable in .claude/settings.local.json enabledMcpjsonServers'); score -= 1

score = max(0, min(10, int(score)))
status = '✅' if score >= 8 else '⚠️' if score >= 5 else '❌'
total_p = len(cache.get('plugins', [])); total_m = sum(1 for p in cache.get('plugins', []) if p.get('has_mcp')); total_l = len(cache.get('lsp_servers', []))
print(f'{status} External Tools: {score}/10 — {total_p} plugins, {total_m} MCP, {total_l} LSP')
for i in issues: print(f'   {i}')
if fixes:
    print(); print('🔧 Auto-fix (HITL required):')
    for i, fx in enumerate(fixes, 1): print(f'   {i}. {fx}')
"
```

**Scoring**: 10/10 healthy + all docs | 7-9 minor (missing optional docs) | 4-6 MCP disabled | 0-3 cache missing/major issues

**Auto-fix** (HITL): Plugin missing → `/plugin install {name}` | MCP not enabled → add to `enabledMcpjsonServers` | Orphan ref → remove or install | Cache stale → re-run `hooks/external-capabilities`

### Cat 13: Domain Plugin Health (SP-ECO v4)

```bash
# 1. Legacy monolithic
[ -d "$HOME/.claude/plugins/cache/atlas-admin-marketplace" ] && echo "⚠️ Legacy detected. Run: scripts/migrate-marketplace.sh"

# 2. Core dependency
[ ! -d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core" ] && echo "❌ atlas-core required by all"

# 3. Orphan domain (each requires atlas-core)
for d in "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-"*/; do
  [ -d "$d" ] || continue
  domain=$(basename "$d"); [ "$domain" = "atlas-core" ] && continue
  [ ! -d "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core" ] && echo "⚠️ $domain orphan"
done

# 4. Plugin count
installed=$(find "$HOME/.claude/plugins/cache/atlas-marketplace" -maxdepth 1 -type d -name "atlas-*" 2>/dev/null | wc -l)
echo "ATLAS domain plugins: $installed/6 installed"
```

Domain plugins (6):
| Plugin | Purpose |
|--------|---------|
| `atlas-core` | Memory, session, context, vault (REQUIRED) |
| `atlas-dev` | Planning, TDD, debugging, code review, shipping |
| `atlas-frontend` | UI design, browser automation, visual QA |
| `atlas-infra` | Infra, deploy, security, network |
| `atlas-enterprise` | Governance, knowledge engine, agent teams |
| `atlas-experiential` | Episodes, intuitions, relationships |

Status: ✅ atlas-core + ≥1 domain | ⚠️ legacy detected OR orphan | ❌ no core, no legacy

Auto-fix: `atlas setup plugins` (interactive) or `scripts/migrate-marketplace.sh --preset dev`.

### Cat 14: Observability Stack Health

LGTM stack on VM 602 (ref: `refs/observability-api`):

```bash
LOKI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://192.168.10.56:3100/ready" 2>/dev/null)
[ "$LOKI_STATUS" = "200" ] && echo "✅ Loki ready" || echo "❌ Loki unreachable ($LOKI_STATUS)"
curl -s --max-time 5 "http://192.168.10.56:9090/-/healthy" | grep -q "Healthy" && echo "✅ Prometheus" || echo "❌ Prometheus unreachable"

ERROR_COUNT=$(curl -sG "http://192.168.10.56:3100/loki/api/v1/query" \
  --data-urlencode 'query=sum(count_over_time({container=~"synapse-prod.*"} |~ "(?i)error" [1h]))' 2>/dev/null | jq -r '.data.result[0].value[1] // "0"')
[ "${ERROR_COUNT:-0}" -lt 50 ] && echo "✅ Error rate: $ERROR_COUNT/h" || echo "⚠️ Error rate high: $ERROR_COUNT/h"

DOWN=$(curl -sG "http://192.168.10.56:9090/api/v1/query" --data-urlencode 'query=up == 0' 2>/dev/null | jq -r '.data.result | length')
[ "${DOWN:-0}" -eq 0 ] && echo "✅ All scrape targets UP" || echo "⚠️ $DOWN targets DOWN"

UNHEALTHY=$(ssh root@192.168.10.50 "docker ps --filter 'health=unhealthy' --format '{{.Names}}' | grep synapse" 2>/dev/null | wc -l)
[ "${UNHEALTHY:-0}" -eq 0 ] && echo "✅ Containers healthy" || echo "⚠️ $UNHEALTHY unhealthy"
```

Status: ✅ all 5 pass | ⚠️ errors >50/h or targets down or unhealthy | ❌ Loki/Prom unreachable

Auto-fix: `ssh sgagnon@192.168.10.56 "cd /opt/observability && docker compose restart"` for obs-* | SSH VM 550 + restart for unhealthy Synapse containers.

## Dream Health Integration (v2)

```bash
MEMORY_DIR=$(find ~/.claude/projects -name "MEMORY.md" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")
DREAM_LINE="Dream Health: ⏭️ No reports"
if [ -n "$MEMORY_DIR" ]; then
  DREAM_FILE=$(ls -t "$MEMORY_DIR"/dream-report-*.md 2>/dev/null | head -1)
  if [ -n "$DREAM_FILE" ]; then
    DATE=$(basename "$DREAM_FILE" | sed 's/dream-report-\(.*\)\.md/\1/')
    GRADE=$(grep -m1 -oP '(?i)grade[:\s]+([A-F][+\-]?)' "$DREAM_FILE" | grep -oP '[A-F][+\-]?' | head -1 || echo "?")
    SCORE=$(grep -oP '[0-9]+\.[0-9]+/10' "$DREAM_FILE" | head -1 || echo "?/10")
    DREAM_LINE="Dream Health: ${GRADE:-?} $SCORE ($DATE)"
  fi
fi
echo "$DREAM_LINE"
```

Display: `Dream Health: B+ 8.91/10 (2026-04-04)`

## Hook Performance Profiling (P2-HOOK-4)

Read `~/.claude/hook-log.jsonl`, report timing stats (24h):

```bash
HOOK_LOG="$HOME/.claude/hook-log.jsonl"
[ -f "$HOOK_LOG" ] && python3 -c "
import json
from datetime import datetime, timedelta
from collections import defaultdict
cutoff = (datetime.now() - timedelta(hours=24)).isoformat()
stats = defaultdict(list)
with open('$HOOK_LOG') as f:
    for line in f:
        try:
            e = json.loads(line.strip())
            if e.get('ts','') >= cutoff: stats[e['handler']].append(int(e.get('ms', 0)))
        except: pass
if stats:
    print('Hook Performance (24h):')
    print(f'  {\"Handler\":<30} {\"Calls\":>6} {\"Avg ms\":>8} {\"Max ms\":>8} {\"Status\":>8}')
    for h, t in sorted(stats.items(), key=lambda x: -max(x[1])):
        avg = sum(t)/len(t); mx = max(t)
        s = '⚠️ SLOW' if avg > 3000 else '✅'
        print(f'  {h:<30} {len(t):>6} {avg:>8.0f} {mx:>8} {s:>8}')
else:
    print('Hook Performance: No data in last 24h')
"
```

**Thresholds**: Avg >3000ms = ⚠️ SLOW | Max >5000ms = 🔴 CRITICAL | Score: +1 if all <3s avg, -1 per slow.

## Report Persistence

Save to `~/.atlas/doctor-report.json`:
```json
{
  "timestamp": "2026-03-21T12:00:00Z",
  "overall_score": 59,
  "overall_max": 70,
  "categories": {
    "os_shell": { "score": 5, "max": 5, "issues": [] },
    "tools": { "score": 7, "max": 8, "issues": ["yq"] }
  }
}
```

Update `~/.atlas/profile.json`:
```json
"onboarding": { "doctor_last_run": "2026-03-21T12:00:00Z", "doctor_score": 84 }
```

## Severity Rules

- ✅ 100% in category → green
- ⚠️ 50-99% → yellow + show issues
- ❌ <50% → red + show issues + auto-fix prompt

OVERALL: ≥90% healthy | 70-89% needs attention | <70% critical
