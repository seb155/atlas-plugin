# Agent Visibility — User Guide

See your background subagents work in real-time via statusline counter, tmux auto-tail panes, and the `atlas agents` CLI. Works everywhere; auto-degrades gracefully.

> **SKILL.md** = agent-facing (how Claude invokes this). **This README** = human-facing (how you set it up and troubleshoot).

---

## Quick Start (3 min setup)

### 1. Add env vars (one-time)

Add these three entries to your `~/.claude/settings.json` in the `env` section:

```json
{
  "env": {
    "ATLAS_AUTO_TAIL_AGENTS": "1",
    "ATLAS_MAX_TAIL_PANES": "2",
    "ATLAS_AGENT_STATUS_INTERVAL": "2"
  }
}
```

These are **already the defaults** in code — setting them explicitly makes the intent visible and lets you opt-out later by flipping `ATLAS_AUTO_TAIL_AGENTS` to `"0"`.

### 2. Source atlas-cli (if not already)

Add to your `~/.zshrc` (or `~/.bashrc`):

```bash
[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"
```

Reload: `exec zsh` or new terminal.

### 3. Verify

```bash
atlas agents env     # should print: tmux (if inside tmux) | wt | fallback | none
atlas agents         # lists tracked agents (empty until you dispatch one)
```

Statusline will show `🤖 2▶ 1✓` next time a background agent runs.

---

## How It Works — 4 Layers

| Layer | What | Where it lives |
|-------|------|----------------|
| 1 — Telemetry | Records every background agent spawn | `~/.atlas/runtime/agents.json` (hook-managed) |
| 2 — Statusline | `🤖 N▶ M✓` indicator | CShip custom module reads registry |
| 3 — Auto-tail | Tmux split-pane tailing agent's JSONL | Hook auto-spawns on Agent tool call |
| 4 — CLI | `atlas agents` subcommands | Shell module sourced from `atlas-cli.sh` |

**Layers 1, 2, 4 always work.** Layer 3 is environment-aware:
- `tmux` → auto `split-window -h -p 35%` with live formatted tail
- Windows Terminal → `wt.exe new-tab` with live tail
- No tmux / no WT → silent skip + CLI remains usable

---

## CLI Cheat-Sheet

```bash
atlas agents            # list recent + running
atlas agents list       # (same, explicit)
atlas agents tail <id>  # stream formatted transcript (uses tmux split if available)
atlas agents stop <id>  # SIGTERM the agent process
atlas agents replay <id> # full transcript paged
atlas agents stats      # historical telemetry
atlas agents clean      # prune stale/completed entries
atlas agents env        # show detected visibility env
atlas agents help       # inline help
```

Agent IDs look like `a46042d9e2f8300b2`. Tab-completion works after sourcing atlas-cli.

---

## Visual Example (tmux layout)

```
┌─────────────────────────────┬──────────────────────┐
│ main Claude Code session    │ 🤖 agent-1 tail      │
│ (you work here)              │ [team-engineer]      │
│                              │ 🔧 Bash              │
│ > dispatch 3 agents via     │ 💬 Running bun test  │
│   /atlas team feature "X"    │ ⏱  elapsed: 2m 14s  │
│                              ├──────────────────────┤
│                              │ 🤖 agent-2 tail      │
│                              │ [team-reviewer]      │
│                              │ 💬 Reading src/...   │
└─────────────────────────────┴──────────────────────┘

Statusline: ... │ 🤖 2▶ 1✓ │ ...
```

Capped to `ATLAS_MAX_TAIL_PANES` (default 2) to prevent proliferation when many agents spawn.

---

## Troubleshooting

### "No panes appearing when I spawn agents"

Run this diagnostic:

```bash
echo "TMUX=$TMUX"
echo "ATLAS_AUTO_TAIL_AGENTS=$ATLAS_AUTO_TAIL_AGENTS"
atlas agents env
```

**Fix matrix**:

| Output | Fix |
|--------|-----|
| `TMUX=` empty | You're not inside tmux — start a tmux session first, or rely on statusline (Layer 2) |
| `ATLAS_AUTO_TAIL_AGENTS=0` | You opted out — set to `"1"` in settings.json |
| `env` returns `none` | User opted out via env var |
| `env` returns `fallback` | No tmux/WT — expected, Layer 3 skipped |
| Env correct but still no panes | Check `~/.claude/hook-log.jsonl` for hook failures |

### "Statusline doesn't show 🤖 counter"

```bash
# 1. Verify registry exists
ls -la ~/.atlas/runtime/agents.json
# Expected: file exists, JSON with agent entries

# 2. Manually render statusline module
bash ~/.claude/plugins/cache/atlas-marketplace/atlas-core/*/scripts/atlas-agents-module.sh
# Expected: emits "🤖 N▶" or empty (if no active agents)

# 3. Python vs jq fallback
python3 --version  # preferred for 30-min time filter
jq --version       # fallback
```

If module emits correctly but statusline doesn't update, your CShip config is missing `[custom.atlas_agents]`. See `skills/statusline-setup/README.md`.

### "Tmux pane opens but shows 'No output_file registered'"

This means the agent was registered but the JSONL symlink hasn't materialized yet. Causes:
- Agent is still spawning (wait 5-30s, retry)
- Agent was foreground (no background output) — this is normal
- `output_file` schema mismatch with newer CC version — file a bug

Check: `cat ~/.atlas/runtime/agents.json | jq '.'`

### "I want to disable auto-panes temporarily"

```bash
export ATLAS_AUTO_TAIL_AGENTS=0
# Layer 3 skipped for this session; Layers 1/2/4 still active
```

---

## Integration with `atlas-team`

When you run `/atlas team feature|debug|review|audit`:

1. Skill `atlas-team` dispatches N workers via `Agent({run_in_background: true, ...})`
2. Each Agent tool call triggers `PostToolUse:Agent` hook → `subagent-output-capture.ts`
3. Hook registers entry in `~/.atlas/runtime/agents.json` + calls `spawnVisibility()`
4. If tmux + env allows: `tmux split-window` → new pane running `atlas-agent-tail.sh <id>`
5. Statusline updates on next `UserPromptSubmit` → shows `🤖 N▶`

**If panes don't appear** after `/atlas team X`:
- Verify CC version ≥ 2.1.x with Agent tool support
- Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` if using CC native teams mode (conflicts with our hook-based spawn)
- Run `atlas agents list` — if entries appear here but no panes, it's a Layer 3 issue (env detection)

---

## Advanced: Custom JSONL Formatting

The tail script uses `scripts/atlas-jsonl-format.sh`. To customize the display format (e.g., add more event types, change emojis):

```bash
# Edit the formatter
$EDITOR scripts/atlas-jsonl-format.sh

# Test locally
cat some-transcript.jsonl | bash scripts/atlas-jsonl-format.sh
```

Event types currently formatted:
- `tool_name` → 🔧 Tool name
- `text` → 💬 Assistant message (first 80 chars)
- `status` → ⏱ Agent status

---

## Architecture Reference

- **Plan**: `.blueprint/plans/keen-nibbling-umbrella.md` (all 5 phases)
- **SKILL.md**: agent-facing invocation triggers and schema
- **Hook**: `hooks/ts/subagent-output-capture.ts` (Bun, async, fail-open)
- **Tail pane script**: `scripts/atlas-agent-tail.sh` (shell, 71 lines)
- **JSONL formatter**: `scripts/atlas-jsonl-format.sh`
- **Statusline module**: `scripts/atlas-agents-module.sh` (Starship/CShip)
- **CLI module**: `scripts/atlas-modules/agents.sh` (sourced by atlas-cli.sh)
- **Tests**: `tests/test_agent_visibility.py` — 31 tests, 100% green

---

## FAQ

**Q: Does this work outside tmux?**
A: Layers 1/2/4 yes; Layer 3 auto-spawn no (falls back to CLI: `atlas agents tail <id>` on-demand).

**Q: Does it survive session compaction?**
A: Registry persists to disk (`~/.atlas/runtime/agents.json`). Panes are tmux-managed and survive compaction too.

**Q: Performance overhead?**
A: `<100ms` per Agent tool call (async, fail-open). Statusline reads registry on UserPromptSubmit only.

**Q: Can I see agent output after it finished?**
A: Yes — `atlas agents replay <id>` pages the full transcript. Panes have `remain-on-exit on` so they stay visible too.

**Q: Multiple CC sessions simultaneously?**
A: Each session writes to the same registry file; atomic writes prevent races. Statusline may show agents from other sessions (by design — you see all your concurrent work).

---

*Last updated: 2026-04-17. Tests: 31/31 green. Maintained by Seb Gagnon (AXOIQ).*
