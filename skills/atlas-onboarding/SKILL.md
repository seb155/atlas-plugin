---
name: atlas-onboarding
description: "Guided setup wizard for new ATLAS users. 5-phase onboarding: profile creation, credential validation, environment checks, project context, optional integrations. Use when 'setup', 'configure', 'onboard', 'first time', or 'getting started'."
effort: high
---

# ATLAS Onboarding Wizard

Interactive 5-phase setup for new users or environment reconfiguration. Each phase uses AskUserQuestion for HITL approval.

## Storage

- **Profile**: `~/.atlas/profile.json` — SSoT for onboarding state
- **State**: `~/.atlas/onboarding-state.json` — progress if interrupted

Create storage on first run:
```bash
mkdir -p ~/.atlas
```

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas setup` | Full 5-phase wizard |
| `/atlas setup profile` | Phase 1 only |
| `/atlas setup credentials` | Phase 2 only |
| `/atlas setup environment` | Phase 3 only |
| `/atlas setup context` | Phase 4 only |
| `/atlas setup optional` | Phase 5 only |
| `/atlas setup status` | Show completion status |

## Phase 1: 👤 Profile

Gather user identity via AskUserQuestion:

**Question 1** — Role:
```
header: "Role"
options: ["I&C Engineer", "Electrical Engineer", "Project Manager", "Software Developer", "Admin/DevOps"]
```

**Question 2** — Expertise (multi-select):
```
header: "Expertise"
multiSelect: true
options: ["I&C", "Electrical", "Mechanical", "Process", "Software", "DevOps", "Mining/Resources"]
```

**Question 3** — Language:
```
header: "Language"
options: ["Français (Recommended)", "English"]
```

**Question 4** — Default model:
```
header: "Model"
options: [
  "Opus 4.6 (Recommended) — deep reasoning, architecture, plans",
  "Sonnet 4.6 — fast, 98% coding quality, lower cost"
]
```

After collecting answers, ask for name and team via free-form AskUserQuestion.

Write `~/.atlas/profile.json`:
```bash
cat > ~/.atlas/profile.json <<EOF
{
  "version": 1,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": {
    "name": "{name}",
    "role": "{role}",
    "team": "{team}",
    "expertise": [{expertise}],
    "preferences": { "language": "{lang}", "model": "{model}" }
  },
  "onboarding": {
    "phases_completed": ["profile"]
  }
}
EOF
```

## Phase 2: 🔑 Credentials

Check each token via bash, then present results:

```bash
# Check existence + API validity
SYNAPSE_OK="❌"
[ -n "${SYNAPSE_TOKEN:-}" ] && curl -sf -m 3 -H "Authorization: Bearer $SYNAPSE_TOKEN" http://localhost:8001/api/v1/health >/dev/null 2>&1 && SYNAPSE_OK="✅"

FORGEJO_OK="❌"
[ -n "${FORGEJO_TOKEN:-}" ] && curl -sf -m 3 -H "Authorization: token $FORGEJO_TOKEN" http://192.168.10.75:3000/api/v1/user >/dev/null 2>&1 && FORGEJO_OK="✅"

AUTHENTIK_OK="⏭️ optional"
[ -n "${AUTHENTIK_TOKEN:-}" ] && curl -sf -m 3 -H "Authorization: Bearer $AUTHENTIK_TOKEN" "${AUTHENTIK_URL:-https://auth.home.axoiq.com}/api/v3/core/users/me/" >/dev/null 2>&1 && AUTHENTIK_OK="✅"

GEMINI_OK="❌"
[ -n "${GEMINI_API_KEY:-}" ] && GEMINI_OK="✅"
```

Present as table:
```
| Token          | Status | Purpose                              |
|----------------|--------|--------------------------------------|
| SYNAPSE_TOKEN  | {status} | Backend API (profile, knowledge, notes) |
| FORGEJO_TOKEN  | {status} | Git hosting (PRs, CI, deploy)          |
| AUTHENTIK_TOKEN| {status} | SSO role detection (optional)          |
| GEMINI_API_KEY | {status} | AI model access (optional)             |
```

For each ❌ token:
1. Explain what it's for and why it matters
2. Show generation instructions:
   - SYNAPSE_TOKEN: "In Synapse → Admin → API Tokens → Create"
   - FORGEJO_TOKEN: "In Forgejo → Settings → Applications → Generate Token"
   - AUTHENTIK_TOKEN: "In Authentik → Admin → Tokens → Create API Token"
3. Ask user: "Add to ~/.env: `export TOKEN_NAME=xxx` then `source ~/.env`"
4. NEVER store the token value — only validate and record true/false

Update `~/.atlas/profile.json` credentials section.

## Phase 3: 🔧 Environment

Auto-detect via bash (no user input needed for most):

```bash
# OS
OS_NAME=$(uname -s)
OS_VERSION=$(uname -r)
HOSTNAME=$(hostname -s)
SHELL_NAME=$(basename "$SHELL")

# Tools
declare -A TOOLS=(
  [bash]="$(command -v bash 2>/dev/null && echo ✅ || echo ❌)"
  [yq]="$(command -v yq 2>/dev/null && echo ✅ || echo ❌)"
  [python3]="$(command -v python3 2>/dev/null && echo ✅ || echo ❌)"
  [bun]="$(command -v bun 2>/dev/null && echo ✅ || echo ❌)"
  [docker]="$(command -v docker 2>/dev/null && echo ✅ || echo ❌)"
  [git]="$(command -v git 2>/dev/null && echo ✅ || echo ❌)"
  [jq]="$(command -v jq 2>/dev/null && echo ✅ || echo ❌)"
  [curl]="$(command -v curl 2>/dev/null && echo ✅ || echo ❌)"
)
```

Present table. For missing tools, offer installation commands:
- yq: `sudo snap install yq` (Ubuntu) or `brew install yq` (macOS)
- bun: `curl -fsSL https://bun.sh/install | bash`
- jq: `sudo apt install jq` or `brew install jq`

AskUserQuestion for each missing tool: "Install {tool}?"

## Phase 4: 📄 Project Context

Check current project directory:

```bash
[ -f CLAUDE.md ]                    # Project CLAUDE.md
[ -d .claude/rules ]                # Rules directory
[ -d .blueprint ]                   # Blueprint directory
[ -f .blueprint/FEATURES.md ]       # Feature registry
```

For each gap, AskUserQuestion:
- Missing CLAUDE.md → "Generate from project scan? (uses W3H format, ~100 lines)"
- Missing .claude/rules/ → "Create basic rules (code-quality, testing)?"
- Missing .blueprint/ → "Create blueprint structure (INDEX.md, plans/)?"

If approved, invoke the relevant generation:
- CLAUDE.md: scan package.json/requirements.txt/docker-compose, generate W3H template
- Rules: extract conventions from existing code patterns
- Blueprint: create minimal directory structure

## Phase 5: ⚙️ Optional Setup

AskUserQuestion with multi-select:

```
header: "Optional"
multiSelect: true
options:
  - "CShip/Starship status line — terminal integration"
  - "Browser automation — Chrome MCP or agent-browser"
  - "Forgejo SSH — Git SSH access verification"
  - "Headscale/Tailscale — mesh networking"
```

For each selected:
- CShip → invoke `statusline-setup` skill
- Browser → show installation guide for Chrome MCP extension
- Forgejo SSH → verify `~/.ssh/config` has Forgejo host entry
- Headscale → run `tailscale status` and report

## Completion

After all phases (or skipped phases), write final profile:
```bash
# Update onboarding state
python3 -c "
import json
with open('$HOME/.atlas/profile.json') as f: p = json.load(f)
p['onboarding']['completed_at'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
p['onboarding']['phases_completed'] = ['profile','credentials','environment','context','optional']
with open('$HOME/.atlas/profile.json','w') as f: json.dump(p, f, indent=2)
"
```

Display completion message:
```
🏛️ ATLAS │ ✅ ONBOARDING COMPLETE
   └─ Profile: ~/.atlas/profile.json
   └─ Run /atlas doctor to verify full system health
```
