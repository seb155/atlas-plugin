---
name: knowledge-manager
description: "Enterprise knowledge layer orchestration — coverage, discovery, gaps, search, rules, vault. Powers the Unified Knowledge Layer (UKL)."
effort: medium
---

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
