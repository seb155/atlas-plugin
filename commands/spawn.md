# /spawn — Parallel CC Session with Worktree

Launch an isolated CC session for a parallel task. Uses git worktree for file isolation.
Each session runs in its own tmux window. Max 5 concurrent. Plan-based (no API key).

**Usage**: `/atlas spawn "task description"`

Invoke Skill 'session-spawn'.

ARGUMENTS: spawn $ARGUMENTS

Examples:
- `/atlas spawn "run /atlas health full scan"` — health audit in parallel
- `/atlas spawn "fix FEAT-002 rule engine tests"` — isolated feature work
- `/atlas spawn "research ParadeDB FTS patterns"` — exploration task
