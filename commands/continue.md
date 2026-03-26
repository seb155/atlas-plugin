# /continue — Fresh Session with Context

Flush current context and spawn a fresh CC session in a new tmux window.
Generates handoff, opens new CC, auto-types /pickup. Plan-based (no API key).

**Usage**: `/atlas continue`

Invoke Skill 'session-spawn'.

ARGUMENTS: continue

Steps:
1. Generate handoff.md (decisions, files, next steps)
2. Open new tmux window with `claude -n "atlas-fresh-{branch}"`
3. Auto-type `/pickup` after startup
4. Current session can /exit safely
