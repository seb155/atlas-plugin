---
name: knowledge
description: "Unified knowledge layer (engine + manager merged 2026-04-17). Query and ingest project knowledge (TEG timeline, FTS5, cross-repo, entities) plus enterprise UKL orchestration (coverage, discovery, gaps, search, rules, vault). Triggers: ask, search, timeline, why, what happened, who worked on, ingest, absorb, digitize, knowledge, coverage, gaps, cross-project, enterprise search, ISA classification, rule inheritance. Subcommands: ask, ingest, status, discover, gaps, search, rules, scope, vault-list, vault-upload."
effort: medium
thinking_mode: adaptive
superpowers_pattern: [none]
see_also: [atlas-vault, knowledge-builder]
tier: admin
version: 6.0.0-alpha.3
---

# knowledge — Unified Knowledge Layer

> **Note (2026-04-17)** : Merged from knowledge-engine + knowledge-manager (Sprint 4 dedup HITL approved Seb 21:40 EDT). All 10 subcommands preserved.

## Part 1 — TEG Engine (formerly knowledge-engine)

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
🏛️ ATLAS │ ASSIST › 🧠 knowledge › {query|ingest}
```

For query results, format as:
```
Found {N} results for "{query}"

| Date | Type | Repo | Message |
|------|------|------|---------|
| ... | ... | ... | ... |

Source: TEG index ({total} events, last updated {date})
```

## Part 2 — UKL Manager (formerly knowledge-manager)

# Knowledge Manager

Orchestrate the Unified Knowledge Layer — coverage metrics, cross-project discovery, gap detection, unified search, ISA rule inspection, and document vault operations.

## Triggers

- User says "knowledge", "coverage", "gaps", "cross-project", "enterprise search"
- User asks about ISA classification or rule inheritance
- User wants to ingest or process documents
- User asks "what's the knowledge coverage?"

## API

**Base**: `http://localhost:8001/api/v1` | **Auth**: `Bearer $SYNAPSE_TOKEN`

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/knowledge/stats` | GET | Quick stats (docs, cross-refs, rel types, vault docs) |
| `/knowledge/coverage` | GET | Enterprise-wide coverage metrics |
| `/knowledge/coverage/{scope}/{id}` | GET | Per-scope coverage (project/client/department) |
| `/knowledge/gaps` | GET | Detected knowledge gaps with severity |
| `/knowledge/trends` | GET | Coverage trend over time |
| `/knowledge/cross-references` | GET | Cross-project entity links (filterable) |
| `/knowledge/discover` | POST | Trigger cross-project discovery pipeline |
| `/knowledge/sources` | GET | Data sources with document counts |
| `/search/unified` | GET | Unified search (BM25 + RAG + Rules + CrossRefs) |
| `/documents/` | GET | List vault documents |
| `/documents/upload` | POST | Request presigned upload URL |
| `/documents/{id}/process` | POST | Trigger document processing |

## Subcommands

### `/atlas knowledge status`
Show enterprise coverage dashboard: total docs, cross-refs, coverage %, gap count.
```bash
curl -s "$BASE/knowledge/stats" -H "Authorization: Bearer $TOKEN" | jq
curl -s "$BASE/knowledge/coverage" -H "Authorization: Bearer $TOKEN" | jq '{total: .total_documents, coverage: .coverage_pct, sources: .by_source_type}'
```

### `/atlas knowledge discover`
Run cross-project discovery pipeline. Returns new relationships found.
```bash
curl -s -X POST "$BASE/knowledge/discover" -H "Authorization: Bearer $TOKEN" | jq
```

### `/atlas knowledge gaps`
Show uncovered areas with severity levels and recommendations.
```bash
curl -s "$BASE/knowledge/gaps" -H "Authorization: Bearer $TOKEN" | jq '.[] | "\(.severity) | \(.area): \(.description)"'
```

### `/atlas knowledge search <query>`
Unified search across BM25 entities + RAG documents + engineering rules + cross-project refs.
```bash
curl -s "$BASE/search/unified?q=FIT&project_id=thm-012&scope=project" -H "Authorization: Bearer $TOKEN" | jq '.results[] | "\(.source) | \(.title)"'
```

### `/atlas knowledge rules <type_code>`
Show ISA classification + 3-tier rule overrides for a specific type code.
```bash
curl -s "$BASE/search/unified?q=FIT&project_id=thm-012&sources=rules" -H "Authorization: Bearer $TOKEN" | jq '.results[] | select(.source == "rules")'
```

### `/atlas knowledge scope <level>`
Show current search scope and available levels.
Levels: personal | project | client | department | enterprise

### `/atlas knowledge vault list`
List documents in the S3 vault with processing status.
```bash
curl -s "$BASE/documents/" -H "Authorization: Bearer $TOKEN" | jq '.[] | "\(.status) | \(.filename) | \(.chunk_count) chunks"'
```

### `/atlas knowledge vault upload <file>`
Upload a document to the vault for AI processing (Docling + auto-classify + embed).

## Output Format

Present results as tables when multiple items, details when single. Use severity indicators for gaps:
- HIGH = action needed immediately
- MEDIUM = should be addressed soon
- LOW = informational

## Architecture Reference

The UKL fuses 3 existing systems via UnifiedKnowledgeResolver:
1. **BM25** (ParadeDB): 13 entity tables, structural search
2. **RAG** (pgvector 1024d): copilot_documents, semantic search
3. **Rules** (RuleKnowledgeAdapter): synapse_rules (3-tier), ISA classifications (2-tier), FRM, material_catalog

Zero table duplication — all queries are LIVE SQL on existing tables.

## Migration Notes

Existing user invocations route through unified entry:
- `/atlas knowledge ask <q>` → Part 1 TEG
- `/atlas knowledge ingest` → Part 1 TEG
- `/atlas knowledge status` → Part 2 UKL
- `/atlas knowledge discover` → Part 2 UKL
- `/atlas knowledge gaps` → Part 2 UKL
- `/atlas knowledge search <q>` → Part 2 UKL
- `/atlas knowledge rules <type_code>` → Part 2 UKL
- `/atlas knowledge scope <level>` → Part 2 UKL
- `/atlas knowledge vault list` → Part 2 UKL
- `/atlas knowledge vault upload <file>` → Part 2 UKL

No flag changes needed. Backward compatible.
