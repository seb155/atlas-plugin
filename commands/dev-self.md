Invoke the `atlas-dev-self` skill with the following arguments: $ARGUMENTS

Self-development workflow for the ATLAS plugin itself. Use when modifying
the plugin's own skills, agents, hooks, or commands.

Subcommands:
- `/atlas dev-self add-skill <name>` — Guided workflow to add a new skill
- `/atlas dev-self add-agent <name>` — Guided workflow to add a new agent
- `/atlas dev-self add-hook <name>` — Guided workflow to add a new hook
- `/atlas dev-self release [patch|minor]` — Version bump + build + test + tag
- `/atlas dev-self audit` — Validate plugin structure + test suite
- `/atlas dev-self bootstrap` — Create missing context files (CLAUDE.md, rules, memory)

If no subcommand given, run `audit`.
