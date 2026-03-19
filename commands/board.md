# /board — Feature Board Dashboard

Show all features with status, validation matrix, and proactive suggestions.
Parse `.blueprint/FEATURES.md` and render the kanban dashboard.

**Usage**: `/atlas board [subcommand]`

Invoke Skill 'feature-board'.

ARGUMENTS: $ARGUMENTS

Subcommands:
- `/atlas board` — Full kanban board (default)
- `/atlas board matrix` — Validation matrix (all features × all layers)
- `/atlas board FEAT-NNN` — Detail for specific feature
- `/atlas board suggest` — Show proactive suggestions only
