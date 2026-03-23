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

## Phase Details

Each phase is documented in a separate file. Read the relevant file when executing:

| Phase | File | Lines |
|-------|------|-------|
| 1. 👤 Profile | `phases/phase-1-profile.md` | Role, expertise, language, model |
| 2. 🔑 Credentials | `phases/phase-2-credentials.md` | Token validation (Synapse, Forgejo, Authentik) |
| 3. 🔧 Environment | `phases/phase-3-environment.md` | OS detection, tools, terminal, aliases, DX tools |
| 4. 📄 Project Context | `phases/phase-4-context.md` | CLAUDE.md, rules, blueprint structure |
| 5. 📊 StatusLine & Settings | `phases/phase-5-settings.md` | CShip, Starship, CC settings, MCP servers |
| 6. ⚙️ Optional | `phases/phase-6-optional.md` | Forgejo SSH, Headscale, Coder, Ollama |

Read the phase file BEFORE executing that phase. Do NOT guess — the details matter.

## Completion

After all phases (or skipped phases), write final profile:
```bash
# Update onboarding state
python3 -c "
import json
with open('$HOME/.atlas/profile.json') as f: p = json.load(f)
p['onboarding']['completed_at'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
p['onboarding']['phases_completed'] = ['profile','credentials','environment','terminal','context','statusline','optional']
with open('$HOME/.atlas/profile.json','w') as f: json.dump(p, f, indent=2)
"
```

Display completion message:
```
🏛️ ATLAS │ ✅ ONBOARDING COMPLETE
   └─ Profile: ~/.atlas/profile.json
   └─ Run /atlas doctor to verify full system health
```
