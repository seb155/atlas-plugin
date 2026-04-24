# ADR-018: wiki-aggregate Skill — Agentic N-Source Aggregation Protocol

**Status**: Accepted
**Date**: 2026-04-19
**Deciders**: Seb Gagnon
**Source**: Benchmark 2026-04-19 (plan `joyful-hare`, Batch 2)
**Source repo**: LichAmnesia/lich-skills (Shen Huang)
**Related**: ADR-013 (skill-lint security baseline — same author)

---

## Context

ATLAS has `atlas-core:deep-research` for **web-based multi-query research from scratch**. But ATLAS has no pattern for **aggregating N pre-existing local sources** (memory files, benchmark outputs, handoffs, plan versions) into a structured pack.

Current anti-patterns observed in ATLAS sessions:
1. **Concat-and-summarize**: Opus given 30 memory files → produces 200-word summary that drops 90% of signal
2. **Sequential-read-and-forget**: Claude reads files one-by-one, forgets earlier content as context fills
3. **LLM-picks-best**: Claude selects 1 "authoritative" source, silently discards N-1 alternatives with their unique findings

All three failure modes observed in Seb's recent work:
- Saturday PM intensive (2026-04-18) produced 50 artefacts → retrospective summary missed 30% of commits
- Plan staleness pattern (2026-04-18) emerged because Claude trusted recent context over filesystem grep
- Benchmark 2026-04-19 (this plan) itself risks the same failure mode if synthesis phase concats all 23 per-repo sections

LichAmnesia's **wiki-aggregate** skill (lich-skills repo) inverts this: treats N sources as a **navigable environment**, dispatches a lite aggregator agent with `inspect / search / synthesize` tools, builds notes scratchpad with `path:line` provenance, outputs structured pack (brief / findings / sources / aggregation log).

Evidence of superiority per lich-skills README:
- Cost ≈ single rollout (vs N separate summaries)
- Recall materially higher (cross-source contradictions surfaced explicitly)
- Pure markdown protocol — "any harness with Read + Grep can execute"
- No Python, no MCP, no LLM SDK dependency

## Decision

ATLAS adopts the wiki-aggregate protocol as **`atlas-core:wiki-aggregate` skill**. Companion to `atlas-core:deep-research`:

| Skill | Use case |
|-------|----------|
| `deep-research` | Research a topic FROM SCRATCH via web search (decompose → search → fetch → synthesize) |
| `wiki-aggregate` (new) | Aggregate N EXISTING local sources into structured pack (inspect → search → synthesize with path:line provenance) |

Both have decompose+synthesize phases but act on different inputs (web vs local files).

## Rationale

1. **ATLAS has explicit N-source aggregation needs**:
   - Benchmark synthesis (23 repos → cross-repo patterns)
   - Memory consolidation (50+ feedback files → themes)
   - Plan rollup (81 active plans → programme status)
   - Handoff aggregation (N session handoffs → current state)

2. **Attribution and provenance matter**:
   - ATLAS frequently references past sessions, decisions, files
   - Currently provenance is lost in compaction
   - path:line references survive compaction as they point to durable disk

3. **Zero new dependencies**:
   - Pure markdown protocol
   - Uses existing Read + Grep tools
   - No Python/Node/MCP addition

4. **Composes with existing skills**:
   - `memory-dream` could invoke wiki-aggregate on memory files
   - `deep-research` could invoke wiki-aggregate on fetched documents
   - `programme-manager` could aggregate N plans

## Consequences

### Positive

- ATLAS gains structured aggregation capability without scope expansion
- Memory consolidation improves (less drift across compactions)
- Benchmark/audit patterns become reusable (this very plan validates)
- Attribution to lich-skills acknowledged in skill frontmatter sources[]

### Negative

- Additional skill in atlas-core (28 → 29) — modest context bump
- Protocol complexity: users must understand "environment" mental model
- Pattern most valuable for N≥3 — overhead for smaller aggregations

### Risks

- **Conceptual overlap confusion**: users may not know when to pick deep-research vs wiki-aggregate
  - *Mitigation*: clear description field ("research from web" vs "aggregate existing sources"), explicit `When NOT to Use` table
- **Budget explosion on large N**: 50+ sources could burn inspect budget
  - *Mitigation*: protocol includes budget cap (default 25 inspect calls), skill documents scaling strategy

## Alternatives considered

### A1 — Extend deep-research with aggregate mode

Rejected: different input surface (web vs local), different tool set (WebSearch vs Read/Grep), different output shape (summary vs structured pack). Mode toggle within one skill adds complexity without clarity benefit.

### A2 — Use wiki-aggregate from lich-skills directly (skill dependency)

Rejected: ATLAS marketplace doesn't yet support cross-plugin skill references as hard dependencies. Adoption by inspired-copy with attribution (in sources[]) is current practice.

### A3 — Custom in-house protocol (not based on lich-skills)

Rejected: lich-skills protocol is evidence-based and well-documented. Reinventing adds effort without differentiation.

## Implementation path

- [x] **Phase 1 (this ADR)**: decision documented
- [ ] **Phase 2**: `atlas-core/skills/wiki-aggregate/SKILL.md` — protocol adapted for ATLAS context
- [ ] **Phase 3**: validate on THIS benchmark (23 repos) — demo pack for cross-repo synthesis
- [ ] **Phase 4**: update `memory-dream` to invoke wiki-aggregate when N≥3 memory themes detected
- [ ] **Phase 5**: update `programme-manager` to invoke wiki-aggregate on N≥3 sub-plans for rollup

## References

- lich-skills: `skills/wiki-aggregate/SKILL.md` (LichAmnesia/lich-skills@main)
- Benchmark report: `synapse/.blueprint/reports/atlas-benchmark-report-2026-04-19.md` §Per-repo #7 (lich-skills Force 1)
- Related ADR-013 (same author) — confirms lich-skills' reliability as adoption source
- ATLAS incident 2026-04-18 plan staleness pattern — this protocol is the remediation

---

*ADR-018 authored 2026-04-19 by ATLAS (Opus 4.7) as plan `joyful-hare` Batch 2 REC-030.*
