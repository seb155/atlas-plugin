# /board — Feature Board Dashboard

Show features with status, validation matrix, sprint suggestions, and dependency graph.
Parses `.blueprint/FEATURES.md`, `.blueprint/THEMES.md`, `.blueprint/EPICS.md`.

**Usage**: `/atlas board [subcommand]`

Invoke Skill 'feature-board'.

ARGUMENTS: $ARGUMENTS

Subcommands:
- `/atlas board` — Chronological view (default): features by last activity date, most recent first
- `/atlas board themes` — Theme > Epic hierarchy with progress bars + grouped kanban
- `/atlas board kanban` — Flat kanban by status (BACKLOG → DONE)
- `/atlas board matrix` — Validation matrix (all features × all layers)
- `/atlas board FEAT-NNN` — Detail for specific feature
- `/atlas board suggest` — Sprint packs + dependency graph only
- `/atlas board wip` — WIP audit: categorize IN_PROGRESS features → KEEP / DEMOTE / DECIDE
- `/atlas board reset` — Apply WIP demotions with HITL confirmation gates
