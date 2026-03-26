# /ingest — Ingest & Digitize Knowledge into the AXOIQ Knowledge Engine

Extract, classify, and index knowledge from git repos, memory files, plans, and documents.
Keeps the TEG (Temporal Event Graph) up to date.

**Usage**: `/atlas ingest [subcommand]`

Invoke Skill 'knowledge-engine'.

ARGUMENTS: ingest $ARGUMENTS

Subcommands:
- `/atlas ingest` — Full re-extraction: all 7 repos + knowledge sources → JSONL → SQLite → PG
- `/atlas ingest git` — Git-only: extract new commits from all repos
- `/atlas ingest knowledge` — Knowledge-only: parse memory, plans, decisions, lessons, features
- `/atlas ingest sync` — Sync local JSONL to PostgreSQL (cursor-based, incremental)
- `/atlas ingest rebuild` — Rebuild SQLite index from JSONL (no extraction)
- `/atlas ingest entities` — Re-extract Knowledge Graph entities from TEG events
- `/atlas ingest status` — Show ingestion stats (last run, event count, cursor position)
