Invoke the `knowledge-manager` skill with the following arguments: $ARGUMENTS

Enterprise Knowledge Layer orchestration — coverage metrics, cross-project discovery,
gap detection, unified search, ISA rule inspection, and document vault operations.

Subcommands:
- `/atlas knowledge status` — Enterprise coverage dashboard
- `/atlas knowledge discover` — Run cross-project discovery pipeline
- `/atlas knowledge gaps` — Show uncovered areas with severity
- `/atlas knowledge search <query>` — Unified search (BM25 + RAG + Rules)
- `/atlas knowledge rules <type_code>` — ISA classification + rule overrides
- `/atlas knowledge vault list` — List vault documents
- `/atlas knowledge vault upload <file>` — Upload for AI processing

If no subcommand given, run `status`.
