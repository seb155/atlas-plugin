Invoke the `atlas-doctor` skill with the following arguments: $ARGUMENTS

System health diagnostic for the ATLAS ecosystem. 12-category check with scored
dashboard and optional auto-fix with HITL approval.

Subcommands:
- `/atlas doctor` — Full health dashboard (read-only, 70 checks across 12 categories)
- `/atlas doctor --fix` — Dashboard + propose auto-fixes for each issue
- `/atlas doctor tokens` — Check tokens only (SYNAPSE, FORGEJO, AUTHENTIK, GEMINI)
- `/atlas doctor tools` — Check tools only (bash, yq, python3, bun, docker, git, jq, curl)
- `/atlas doctor services` — Check services only (Synapse, Docker, PostgreSQL, Valkey, Forgejo)
- `/atlas doctor project` — Check project context only (CLAUDE.md, rules, blueprint, memory)
- `/atlas doctor terminal` — Check terminal & launch config (CC, aliases, ATLAS_ROOT)
- `/atlas doctor statusline` — Check CShip + Starship + scripts + settings
- `/atlas doctor settings` — Check CC global + project settings
- `/atlas doctor plugins` — Check MCP servers + official plugins

If no subcommand given, run full dashboard.
Report saved to: `~/.atlas/doctor-report.json`
