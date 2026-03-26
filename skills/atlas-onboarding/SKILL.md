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
| 5.5 🖥️ Workspace & Multi-Session | *(inline — see below)* | tmux, split-screen, Agent Teams, session-spawn |
| 6. ⚙️ Optional | `phases/phase-6-optional.md` | Forgejo SSH, Headscale, Coder, Ollama |

Read the phase file BEFORE executing that phase. Do NOT guess — the details matter.

## Phase 5.5: Workspace & Multi-Session (inline)

After StatusLine setup, verify multi-session readiness:

```bash
# 1. tmux installed + version >= 3.0
command -v tmux && tmux -V

# 2. ~/.tmux.conf has ATLAS config
grep "ATLAS tmux" ~/.tmux.conf 2>/dev/null

# 3. Agent Teams enabled in settings.json
grep CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS .claude/settings.json 2>/dev/null

# 4. Spawn backend = tmux
grep CLAUDE_CODE_SPAWN_BACKEND .claude/settings.json 2>/dev/null

# 5. .atlas/sessions.yaml exists
cat .atlas/sessions.yaml 2>/dev/null

# 6. Split-screen spawn test
tmux new-session -d -s onboard-test
tmux split-window -h -t onboard-test
tmux send-keys -t onboard-test:0.0 "echo OK0" Enter
tmux send-keys -t onboard-test:0.1 "echo OK1" Enter
sleep 2
tmux capture-pane -t onboard-test:0.0 -p | grep OK0 && echo "PANE0 PASS"
tmux capture-pane -t onboard-test:0.1 -p | grep OK1 && echo "PANE1 PASS"
tmux kill-session -t onboard-test
```

**If any check fails** → run `/atlas workspace-setup` to auto-fix, then re-verify.

Present results as table. All 6 checks must pass for multi-session readiness.

## Completion

After all phases (or skipped phases), write final profile:
```bash
# Update onboarding state
python3 -c "
import json
with open('$HOME/.atlas/profile.json') as f: p = json.load(f)
p['onboarding']['completed_at'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
p['onboarding']['phases_completed'] = ['profile','credentials','environment','terminal','context','statusline','workspace','optional']
with open('$HOME/.atlas/profile.json','w') as f: json.dump(p, f, indent=2)
"
```

Display completion message:
```
🏛️ ATLAS │ ✅ ONBOARDING COMPLETE
   └─ Profile: ~/.atlas/profile.json
   └─ Run /atlas doctor to verify full system health
```
