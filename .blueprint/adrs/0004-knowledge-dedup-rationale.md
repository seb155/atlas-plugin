# ADR 0004 — Knowledge Skill Dedup Rationale (knowledge-engine + knowledge-manager → knowledge)

**Status**: APPROVED (retroactive documentation)
**Date**: 2026-04-17 (merge shipped) → 2026-04-23 (ADR documented)
**Approver**: Seb Gagnon (HITL approved original dedup in alpha.3, 2026-04-17 21:40 EDT; ADR retroactively captured during Sprint 0 P0 fixes on 2026-04-23)
**Supersedes**: none
**Related**: ADR-0002 (Routines vs CronCreate), ADR-0003 (Session Recap vs pickup)

## Context

During v6.0 Sprint 6 feature deduplication audit (dedup-recommendations.md, 2026-04-16), two knowledge-management skills were identified as candidates for consolidation:

1. **`knowledge-engine`** (156L source) — Query operations:
   - `ask` — search and reason over knowledge corpus
   - `search` — plain-text search
   - `status` — corpus health + coverage
   - `rules` — list active knowledge rules
   - `scope` — scope queries to specific projects/vaults
   - `gaps` — identify missing knowledge areas

2. **`knowledge-manager`** (98L source) — Mutation operations:
   - `ingest` — add documents to corpus
   - `discover` — find new sources (files, URLs, repos)
   - `vault-list` — list available vaults
   - `vault-upload` — upload to specific vault

**Combined surface**: 10 subcommands across 2 skills. Users conceptually viewed them as "knowledge management" but tactically had to choose between engine (query) vs manager (mutate) based on intent.

## Decision

**MERGE into single `knowledge` skill** (274 lines unified) preserving all 10 subcommands verbatim.

### Rationale

1. **Bounded context coherence** — Both skills serve the same domain (knowledge management). Split was operational (read/write) not conceptual. Users don't think "I need to use the query engine"; they think "I need to find X in my knowledge".

2. **Discoverability** — Single skill name reduces cognitive load. `/atlas knowledge <verb>` more intuitive than navigating between engine and manager.

3. **Cross-command orchestration** — Some workflows combine query + mutate (ingest → search → verify). Unified skill removes context-switch friction.

4. **Zero functionality loss** — All 10 subcommands preserved via verb-based routing. `ingest` routes to mutation path, `ask`/`search` to query path, internally same as before.

5. **Symmetry with gms-mgmt consolidation** — Parallel dedup case (alpha.3) proved multi-subcommand merges work well when domain is coherent.

## Alternatives Considered

### Alternative A — Keep split (status quo)
- **Pros**: Zero migration cost, clear read/write separation
- **Cons**: Cognitive overhead (2 skills for 1 domain), poor discoverability, no cross-workflow orchestration
- **Rejected**: Cost of split outweighs clarity benefit

### Alternative B — Three-way split (query/ingest/admin)
- **Pros**: Very fine-grained
- **Cons**: Explodes skill count, no user demand for finer split
- **Rejected**: Over-engineering

### Alternative C — Merge with flag-based routing (`/atlas knowledge --mode=query|mutate|admin`)
- **Pros**: Explicit mode switching
- **Cons**: Adds command-line ceremony for no benefit; subcommands already express intent clearly
- **Rejected**: Subcommand-as-verb pattern (like `git`) is proven more ergonomic

## Consequences

### Positive
- ✅ 10 subcommands preserved (zero breaking change from user perspective)
- ✅ Skill count: 117 → 116 → eventually 113 (combined with gms-mgmt merge)
- ✅ Cross-refs migrated: atlas-assist L319, auto-orchestrator L152, atlas-assist-master L135, `_metadata.yaml`
- ✅ Unified discovery path: `/atlas knowledge *` for all knowledge operations
- ✅ Backward compat: v5.x aliases `/atlas ask` + `/atlas ingest` route correctly to new unified skill

### Negative
- ⚠️ No ADR at time of shipping (alpha.3) — audit trail gap. This ADR-0004 retroactively closes that gap (flagged by SOTA review 2026-04-23).
- ⚠️ Migration for custom skill consumers with `invokes: knowledge-engine` hardcoded — one-time update needed.

### Neutral
- Delta documentation in `skills/knowledge/SKILL.md` L14 (brief rationale inline). This ADR provides the full architectural reasoning.

## Verification

```bash
# Skill exists + line count matches
wc -l skills/knowledge/SKILL.md       # expect ~274

# Original skills deleted
ls skills/knowledge-engine/ skills/knowledge-manager/ 2>&1 | grep -i "no such"

# Subcommands preserved (sample)
grep -E "^### Subcommand:" skills/knowledge/SKILL.md | wc -l   # expect 10

# Cross-refs updated
grep -rn "knowledge-engine\|knowledge-manager" skills/ auto-orchestrator.md 2>/dev/null | head -5
# Expect: zero results (all migrated to "knowledge")
```

## HITL Decision Record

**Original approval** (2026-04-17 21:40 EDT):
- Seb Gagnon approved dedup during alpha.3 release cycle
- Batch approval covered both `knowledge` AND `gms-mgmt` merges
- Referenced in CHANGELOG v6.0.0-alpha.3

**ADR retroactive stamp** (2026-04-23 20:45 EDT):
- ADR created during Sprint 0 P0 fixes to close audit trail gap
- Flagged by SOTA review 2026-04-23 Agent C: "No ADR for knowledge dedup rationale"
- Response: this document

## Revisit Triggers

This ADR should be revisited if:
- User feedback indicates confusion about verb-based routing
- New knowledge operations emerge that don't fit verb pattern
- Performance degradation appears (unified skill larger context)
- Ecosystem evolution makes splitting valuable again (unlikely)

**Revisit calendar**: v6.5 planning (Q2 2027) — align with ADR-0001 review.

## References

- `skills/knowledge/SKILL.md` — implementation
- `memory/dedup-recommendations.md` — original dedup proposal
- `.blueprint/adrs/0002-routines-vs-croncreate.md` — parallel complementary tools pattern
- CHANGELOG v6.0.0-alpha.3 (2026-04-17) — ship notes
- `memory/atlas-v6-sota-review-2026-04-23.md` — SOTA review flagging audit trail gap
