Invoke the `atlas-doctor` skill with the following arguments: $ARGUMENTS

System health diagnostic for the ATLAS ecosystem. 8-category check with scored
dashboard and optional auto-fix with HITL approval.

Subcommands:
- `/atlas doctor` — Full health dashboard (read-only, 45 checks across 8 categories)
- `/atlas doctor --fix` — Dashboard + propose auto-fixes for each issue
- `/atlas doctor tokens` — Check tokens only (SYNAPSE, FORGEJO, AUTHENTIK, GEMINI)
- `/atlas doctor tools` — Check tools only (bash, yq, python3, bun, docker, git, jq, curl)
- `/atlas doctor services` — Check services only (Synapse, Docker, PostgreSQL, Valkey, Forgejo)
- `/atlas doctor project` — Check project context only (CLAUDE.md, rules, blueprint, memory)

If no subcommand given, run full dashboard.
Report saved to: `~/.atlas/doctor-report.json`
