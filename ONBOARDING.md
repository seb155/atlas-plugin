# ATLAS Team Onboarding Guide

> Get a new developer productive in < 30 minutes.
> ATLAS v4.0 — Modular plugin ecosystem with topic-based sessions.

---

## Phase 1: Setup (5 minutes)

```bash
# 1. Run the setup wizard
atlas setup

# The wizard handles:
# - Plugin selection (Developer preset: core + dev)
# - SSO authentication (Authentik → Forgejo, Coder, VPN)
# - Coder workspace creation (synapse-fullstack template)
# - Golden DB provisioning (13K+ instruments)
# - VPN mesh enrollment (NetBird)
```

If `atlas` command not found: `source ~/.zshrc` or ask your lead for the shell setup.

---

## Phase 2: First Session (10 minutes)

```bash
# 1. Start your first topic
atlas synapse my-first-feature

# What happens automatically:
# - Git worktree created (isolated branch)
# - Tmux window opened
# - Claude Code launched with full context
# - ATLAS hooks inject project context

# 2. In Claude Code, run pickup to see active sprint
/pickup

# 3. You're now in the code. Start working!
```

---

## Phase 3: Daily Workflow

### Starting Work
```bash
atlas                          # See topic picker, choose what to work on
# OR
atlas synapse vault-fix        # Resume a specific topic directly
```

### During Work
- Just code normally with Claude Code
- The AI handles model selection automatically (Sonnet for code, Opus for architecture)
- Type `ultrathink` before complex questions for maximum reasoning
- Tests run with: `docker exec synapse-backend bash -c "cd /app && python -m pytest tests/ -x -q --tb=short"`

### Ending Work
```bash
/handoff                       # Saves full context for next time
# OR
/end                           # Clean close with summary
```

### Parallel Work
- Background: "lance les tests en background" → Claude backgrounds them
- Multiple topics: open another terminal → `atlas synapse other-topic`

---

## Phase 4: What the AI Does (You Don't Need to Understand This)

The ATLAS plugin runs hooks in the background that:
- **Learn your preferences** (auto-learn hook captures patterns from your prompts)
- **Track your energy** (if you say "tanné" or "pumped", it notices)
- **Remember decisions** (logged to `.claude/decisions.jsonl` and topic memory)
- **Consolidate memory** (weekly dream cycle cleans up and organizes)
- **Suggest improvements** (monthly self-propose skill reviews workflow)

All of this is **silent by default** (verbosity level 2 = max 2 notifications per session).

---

## Phase 5: Commands to Remember

| Command | When | What |
|---------|------|------|
| `atlas` | Morning | Start the day, pick a topic |
| `atlas synapse {topic}` | Anytime | Resume or start a topic |
| `atlas dashboard` | Anytime | See all active sessions |
| `/handoff` | End of work | Save context |
| `/end` | Done for the day | Clean close |
| `ultrathink` | Complex problem | Force deep reasoning |
| `/atlas episode create` | End of session | Capture how the session felt (optional) |

**That's it.** Everything else is automatic.

---

## Phase 6: Troubleshooting

| Problem | Solution |
|---------|----------|
| `atlas` not found | `source ~/.zshrc` |
| Session lost context | `/pickup` to reload from handoff |
| Tests failing | `docker compose ps` → check containers are running |
| Can't SSH to VMs | Check NetBird: `netbird status` |
| Plugin not working | `atlas doctor` for full health check |
| Need help | Ask your lead or check `.blueprint/INDEX.md` |

### Key Paths

| Path | What |
|------|------|
| `.blueprint/` | Project documentation (plans, features, handoffs) |
| `.claude/memory/` | AI memory files |
| `.claude/topics/` | Per-topic decisions and lessons |
| `~/.atlas/topics.json` | Topic registry |
| `~/.atlas/config.json` | ATLAS CLI configuration |

---

## Plugin Presets by Role

| Role | Preset | Command |
|------|--------|---------|
| Developer | core + dev | `atlas setup` → "Developer" |
| Full-stack | core + dev + frontend + infra | `atlas setup` → "Full Stack" |
| Infrastructure | core + infra | `atlas setup` → "Infra Only" |
| Admin/Lead | all 6 plugins | `atlas setup` → "Admin" |

---

*ATLAS v4.0 | AXOIQ | Updated: 2026-03-28*
