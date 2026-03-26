---
name: knowledge-engine
description: "AXOIQ Knowledge Engine — query and ingest project knowledge. TEG timeline, FTS5 search, cross-repo correlation, entity extraction. SP-19."
effort: low
---

# Knowledge Engine (SP-19)

Query and maintain the AXOIQ temporal knowledge base. 3,800+ events across 7 repos,
memory files, plans, decisions, lessons. SQLite FTS5 local + PostgreSQL remote.

## Triggers

- User says "ask", "search", "timeline", "why", "what happened", "who worked on"
- User says "ingest", "absorb", "digitize", "update knowledge", "refresh"
- `/atlas ask <question>`
- `/atlas ingest [subcommand]`

## Architecture

```
LOCAL (offline-capable)              REMOTE (Synapse PG)
─────────────────────                ───────────────────
.claude/temporal/                    teg_events table
├── events/*.jsonl  (SSoT)           (JSONB + GIN indexes)
├── index.db        (SQLite+FTS5)    teg_sessions table
├── graph/          (KG entities)    teg_sync_cursor table
├── summaries/      (markdown)
├── rebuild.py
└── query.py
```

## QUERY MODE (`/atlas ask`)

### Natural Language Questions

When the user asks a natural language question, use this strategy:

1. **Identify query type** from the question:
   - "Why..." / "How did we decide..." → decision reconstruction
   - "What happened..." / "Show timeline..." → temporal query
   - "Who worked on..." / "Which repos..." → cross-repo correlation
   - "How many..." / "Stats..." → statistics

2. **Run the appropriate query** via Bash:

```bash
# Project root detection
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
QUERY="$PROJECT_ROOT/scripts/atlas-teg-query.sh"

# Timeline (recent events)
$QUERY timeline --since 2026-03-20 --limit 30

# Full-text search
$QUERY search "authentik sso" --limit 20

# Statistics
$QUERY stats

# Themes
$QUERY themes

# Cross-repo activity for a date
$QUERY cross-repo 2026-03-25

# Repo-specific
$QUERY repo synapse --since 2026-03-01 --limit 30
```

3. **Synthesize the results** into a clear, visual answer:
   - Use tables for lists of events
   - Use ASCII diagrams for timelines
   - Use cross-references for decision chains
   - Always cite the source event (ULID, date, repo)

### Pre-built Summaries

For architecture/evolution questions, read the summaries directly:

```bash
cat $PROJECT_ROOT/.claude/temporal/summaries/architecture-evolution.md
cat $PROJECT_ROOT/.claude/temporal/summaries/cross-repo-map.md
cat $PROJECT_ROOT/.claude/temporal/summaries/theme-timeline.md
```

### FTS5 Search Tips

- Simple words work best: `"sso"`, `"docker"`, `"security"`
- Multi-word: `"process simulation"` (AND by default)
- OR: `"authentik OR authelia"`
- Prefix: `"auth*"` (matches authentik, authelia, auth)

## INGEST MODE (`/atlas ingest`)

### Full Ingest (default)

```bash
$QUERY ingest
# Equivalent to:
cd $PROJECT_ROOT
python3 -m toolkit.knowledge_ingestion full --all
python3 .claude/temporal/rebuild.py --stats
python3 -m toolkit.knowledge_ingestion.extract_entities
DATABASE_URL="postgresql://synapse:synapse_v2_dev@localhost:5433/synapse_db" \
  python3 -m toolkit.knowledge_ingestion.pg_sync
```

### Subcommands

| Subcommand | Script | What it does |
|------------|--------|--------------|
| `git` | `python3 -m toolkit.knowledge_ingestion extract-git --all` | Extract commits from 7 repos |
| `knowledge` | `python3 -m toolkit.knowledge_ingestion parse-knowledge --all` | Parse memory/plans/decisions/lessons/features |
| `rebuild` | `python3 .claude/temporal/rebuild.py --stats` | Rebuild SQLite from JSONL |
| `sync` | `python3 -m toolkit.knowledge_ingestion.pg_sync` | Push JSONL → PostgreSQL |
| `entities` | `python3 -m toolkit.knowledge_ingestion.extract_entities` | Extract KG entities+relations |
| `status` | `$QUERY stats` + cursor check | Show event counts + last sync |

### When to Ingest

- **After a sprint**: Run full ingest to capture new commits + knowledge
- **After editing memory files**: Run `knowledge` to pick up changes
- **After pushing to PG**: Run `sync` to update remote
- **After schema changes**: Run `rebuild` to regenerate SQLite

## Inventory

| File | Location | Purpose |
|------|----------|---------|
| `scripts/atlas-teg-query.sh` | Synapse repo | CLI wrapper |
| `toolkit/knowledge_ingestion/` | Synapse repo | Extraction scripts |
| `.claude/temporal/query.py` | Synapse repo | SQLite query engine |
| `.claude/temporal/rebuild.py` | Synapse repo | JSONL → SQLite rebuilder |
| `.claude/temporal/schema.sql` | Synapse repo | SQLite schema |
| `toolkit/knowledge_ingestion/pg_sync.py` | Synapse repo | PG sync script |
| `toolkit/knowledge_ingestion/prompts/` | Synapse repo | SGLang prompt templates |

## Response Format

Always use the ATLAS persona header:
```
🏛️ ATLAS │ ASSIST › 🧠 knowledge-engine › {query|ingest}
```

For query results, format as:
```
Found {N} results for "{query}"

| Date | Type | Repo | Message |
|------|------|------|---------|
| ... | ... | ... | ... |

Source: TEG index ({total} events, last updated {date})
```
