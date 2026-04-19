---
name: agent-visibility
description: "Subagent visibility surfacing. This skill should be used when the user asks to 'show agent output', 'tail the agent', 'agent status', 'what are agents doing', '/atlas agents', or needs real-time visibility into background subagent work."
tier: core
category: observability
emoji: "👁️"
---

# agent-visibility — Subagent Visibility (SP-AGENT-VIS)

> **Goal**: See what background subagents are doing in real-time.
> **Plan**: `.blueprint/plans/keen-nibbling-umbrella.md` (v1.0 FINAL, ATLAS v5.2.0 target).

## When to Invoke

This skill applies when the user asks any of:

- "What are my agents doing?"
- "Show agent output" / "tail the agent"
- "Agent status?" / "atlas agents"
- "Where did that subagent go?" / "is the plan-reviewer still running?"
- Any mention of "background agent" visibility, output_file, JSONL transcripts
- Before/after dispatching a long-running background `Agent({run_in_background: true})`

Also proactively use when the user seems frustrated about silent agents or asks about ATLAS visibility features.

## The 4-Layer Visibility Stack

```
Layer 1 — Telemetry     │ ~/.atlas/runtime/agents.json (PostToolUse:Agent hook)
Layer 2 — Statusline     │ 🤖 2▶ 1✓  (CShip custom module + native CC statusline)
Layer 3 — Auto-tail      │ tmux split / wt.exe tab / graceful hint fallback
Layer 4 — CLI            │ `atlas agents [list|tail|stop|replay|stats|clean|env]`
```

## Architecture Invariant

**Layers 1+2+4 always work everywhere.** Layer 3 amplifies visibility when the environment supports it (tmux or Windows Terminal), gracefully falls back to a one-time hint message otherwise. No environment produces a hard error — worst case is no auto-pane, and the CLI remains.

## CLI Quick Reference

```bash
atlas agents                 # List running + recent agents (table)
atlas agents list            # Same as above (explicit)
atlas agents tail <id>       # Tail transcript (new tmux pane or raw)
atlas agents stop <id>       # SIGTERM the agent's process
atlas agents replay <id>     # Full transcript paged (formatted)
atlas agents stats           # Historical telemetry (delegates to existing _atlas_agent_stats)
atlas agents clean           # Prune completed/failed entries
atlas agents env             # Show detected visibility environment
atlas agents help            # Inline help
```

## Environment Variables

| Var | Default | Effect |
|-----|---------|--------|
| `ATLAS_AUTO_TAIL_AGENTS` | `1` (on) | Set to `0` to opt-out of Layer 3 auto-spawn |
| `ATLAS_MAX_TAIL_PANES` | `2` | Cap on auto-spawned tmux panes (prevents proliferation) |
| `ATLAS_DIR` | `$HOME/.atlas` | Runtime registry directory (`runtime/agents.json` lives here) |

## Cross-Platform Fallback Matrix

| Environment | Layer 3 behavior | Layers 1/2/4 |
|-------------|-----------------|--------------|
| Linux/macOS + tmux | ✅ Auto-spawn pane (split 65/35) | ✅ Full |
| Linux/macOS no tmux | ⚠️ Skip + stderr hint (once/session) | ✅ Full |
| Windows + WT | ✅ Auto-spawn wt.exe tab | ✅ Full |
| Windows Git Bash | ⚠️ Skip + hint | ✅ Full |
| WSL + tmux | ✅ Auto-spawn pane | ✅ Full |
| CI / SSH non-interactive | Silent skip (no stderr spam) | ✅ Registry only |
| `ATLAS_AUTO_TAIL_AGENTS=0` | Skip (user opt-out) | ✅ Full |

## Agent Entry Schema

Each entry in `~/.atlas/runtime/agents.json` has:

```typescript
{
  agent_id: string;           // e.g., "a46042d9e2f8300b2"
  agent_type: string;         // e.g., "team-engineer"
  output_file: string | null; // symlink path: /tmp/claude-UID/.../tasks/ID.output
  started_at: string;         // ISO timestamp
  finished_at: string | null;
  status: "spawning" | "running" | "completed" | "failed";
  duration_ms: number | null;
  success: boolean | null;
  tmux_pane: string | null;   // set if Layer 3 spawned pane
  wt_tab: string | null;      // set if Windows Terminal tab spawned
  visibility_mode: "tmux" | "wt" | "none";
  session_id: string;         // parent CC session
}
```

## How It Works (implementation detail)

1. User (or Claude) invokes `Agent({run_in_background: true, ...})`.
2. CC spawns child process, returns `output_file` symlink path.
3. **PostToolUse:Agent** hook (`subagent-output-capture.ts`) extracts `agent_id` + `output_file` → writes registry entry via `lib/agent-registry.ts` atomic R/W.
4. Statusline (next UserPromptSubmit) reads registry → shows `🤖 X▶ Y✓`.
5. CShip custom module `atlas-agents-module.sh` does the same for Starship.
6. Layer 3 (Phase 4, not yet shipped): detects env cascade (tmux → WT → fallback) and spawns side pane tailing the JSONL.
7. On SubagentStop, hook marks entry `completed`/`failed` + cleans up pane.

## JSONL Transcript Format

The `output_file` is a live symlink to `~/.claude/projects/.../subagents/agent-<id>.jsonl`. Events:

```jsonc
// User message (role="user"): either string content or tool_result blocks
{ "type": "user", "message": { "role": "user", "content": "..." } }
{ "type": "user", "message": { "role": "user", "content": [{ "type": "tool_result", "tool_use_id": "...", "content": "..." }] } }

// Assistant response: array of text + tool_use blocks
{ "type": "assistant", "message": { "role": "assistant", "content": [
  { "type": "text", "text": "..." },
  { "type": "tool_use", "id": "toolu_...", "name": "Bash", "input": { "command": "..." } }
]}}
```

This schema was validated empirically during Phase 1.0 (see plan Section C).

## Troubleshooting

**"No agents tracked" but I spawned one**
- Verify Phase 1 hook is active: `cat ~/.claude/hook-log.jsonl | grep subagent-output-capture | tail`
- Ensure `make dev` was run from `~/workspace_atlas/projects/atlas-dev-plugin/` to sync source to cache.
- Check registry file: `ls -la ~/.atlas/runtime/agents.json`

**Statusline doesn't show 🤖 indicator**
- The Python inline reader needs python3. Without it, jq fallback shows running count only.
- CShip integration needs `~/.local/share/atlas-statusline/atlas-agents-module.sh` deployed.
- Force refresh: type any prompt → statusline regenerates on UserPromptSubmit.

**Tmux pane not auto-spawning**
- Check env: `atlas agents env`
- Verify `$TMUX` is set: `echo $TMUX`
- Check Phase 4 is deployed: `ls ~/workspace_atlas/projects/atlas-dev-plugin/scripts/atlas-agent-tail.sh`
- Opt-out? `echo $ATLAS_AUTO_TAIL_AGENTS`

## Related Skills / Components

- `atlas-team` — spawns worker teams (each worker tracked here)
- `subagent-dispatch` — dispatches subagents with manifest (tracked here)
- `statusline-setup` — installs CShip + modules
- `session-spawn` — tmux session orchestration (related pattern)

## Plan Status

| Phase | Layer | Status |
|-------|-------|--------|
| 1 | Layer 1 telemetry | ✅ Shipped (commit `2eaff7d`) |
| 2 | Layer 2 statusline | ✅ Shipped (commit `64bec53`) |
| 3 | Layer 4 CLI | ✅ Shipped (this commit) |
| 4 | Layer 3 auto-tail | ⏳ Pending (tmux/WT spawn + JSONL formatter) |
| 5 | Polish + tests | ⏳ Pending |

Target release: **ATLAS v5.2.0** (minor bump, new features, non-breaking).
