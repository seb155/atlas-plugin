Invoke the `atlas-vault` skill with the following arguments: $ARGUMENTS

Private vault management — ingest user profile, behavior rules, and personality
from Forgejo private vault repo. Respects sharing.json privacy boundaries.

Subcommands:
- `/atlas vault` — Show vault status (path, freshness, what's loaded)
- `/atlas vault ingest` — Full re-ingestion with HITL summary
- `/atlas vault sync` — Git pull vault + refresh session context
- `/atlas vault init` — Scaffold new vault for current user
- `/atlas vault path [path]` — Show or set vault path

If no subcommand given, show status.
Privacy: credentials NEVER copied. Read from vault at runtime on trusted networks only.
