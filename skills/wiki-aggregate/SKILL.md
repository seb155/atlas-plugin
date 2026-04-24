---
name: wiki-aggregate
description: "Agentic aggregation of N≥3 existing local sources (memory files, handoffs, plans, benchmark outputs) into a structured pack. Use when the user asks to 'aggregate', 'synthesize', 'roll up', 'consolidate', 'compile', or 'merge findings from' multiple documents and wants path:line provenance + cross-source contradictions surfaced. Complements atlas-core:deep-research (which researches topics from scratch via web)."
effort: high
version: 0.1.0
metadata:
  category: workflow
  sources:
    - "lich-skills by LichAmnesia (https://github.com/LichAmnesia/lich-skills/blob/main/skills/wiki-aggregate/SKILL.md) — original protocol"
---

<EXTREMELY-IMPORTANT>
If N<3 sources → protocol overhead exceeds value. Use direct Read+summary instead.
If the goal is research from SCRATCH (no local sources) → use atlas-core:deep-research.
If sources are 200k+ tokens concatenated → you are already in the failure mode this skill prevents.
</EXTREMELY-IMPORTANT>

# Wiki Aggregate — N local sources → 1 structured pack

## Overview

Inverts "concat N sources → summarize" pipeline. Treats the N sources as a **queryable environment** that a lite aggregator agent navigates via `inspect / search / synthesize` tools, with `path:line` provenance on every claim.

**Core principle**: don't read everything upfront. Don't merge final answers. Navigate.

## When to Use

Activate when the user asks to:
- "aggregate findings from [N memory/handoff/plan files]"
- "consolidate [list of docs]"
- "roll up [programme, sub-plans, or benchmark batches]"
- "synthesize what we know about [topic] across [sources]"
- "compile the [intel, patterns, decisions] from last [period]"

Also appropriate when Claude notices N≥3 sources on one topic that need combining.

## When NOT to Use

- **N < 3 sources** — direct read + inline summary is cheaper
- **Research from scratch** (no existing local sources) — use `atlas-core:deep-research`
- **Single authoritative source** (e.g., canonical spec) — direct read
- **Sources exceed 500K tokens combined** — requires budget increase or two-pass extraction

## Red Flags (rationalization check)

| Thought | Reality |
|---------|---------|
| "I can just concat and Opus will handle it" | Attention collapses past ~200K. Evidence will be silently dropped. |
| "I remember what's in these files" | Memory drifts across compactions. Re-read with path:line. |
| "One source is clearly best" | That's LLM-as-judge. The N-1 others have unique findings. |
| "Summary per source is enough" | ~90% of nuance lost in summary-then-merge. |
| "This is a 2-source task" | Protocol overhead justifies itself at 3+. |

## The Three Tools

The aggregator agent has exactly three operations. That's the whole interface.

### 1. `inspect(path, [section])`
Read a file or a specific section. Returns content with line numbers.

### 2. `search(pattern, [paths])`
Grep across sources. Returns matches with `path:line:snippet`.

### 3. `synthesize(topic, [notes_slice])`
Produce structured output from accumulated notes. Only called at the end.

## Process

### Phase 1 — Discovery (lightweight, no reads)

1. List the N source paths (user provides or Claude discovers via `ls`/`find`)
2. For each: record `{path, size_bytes, last_modified}` — metadata only
3. Confirm with user: "Aggregating N={count} sources on topic '{topic}'. Budget: 25 inspect calls. Proceed?"

### Phase 2 — Navigation (budgeted inspect/search)

Initialize empty `notes = []` list.

Loop until budget exhausted OR coverage reached:

```
for each iteration (max 25):
  1. Identify information gap:
     "What do I NOT yet know about {topic} from {remaining sources}?"
  2. Choose tool:
     - If unknown structure → inspect(path)
     - If seeking specific pattern → search(pattern)
  3. Execute tool
  4. Add notes with path:line:content format
  5. Check coverage: "Have I covered all N sources OR all key questions?"
```

Coverage heuristic: each source inspected at least once (top-level scan) OR answered all key questions from Phase 1.

**Every note MUST include**: `{source_path}:{line_number(s)}:{claim or finding}`.

### Phase 3 — Synthesis (structured output)

Call `synthesize()` once. Produce 4 output files in `pack/`:

1. **brief.md** — executive summary (≤500 words), top findings, action items
2. **findings.md** — detailed per-topic findings with path:line citations
3. **sources.tsv** — one row per source: `path | size | key_topics | primary_claims_count`
4. **_aggregation_log.md** — trace of navigation: which tool called on which path, in what order, budget used

### Phase 4 — Contradiction surfacing (critical)

In `brief.md` AND `findings.md`, include section `## Cross-source contradictions`:

For each pair of sources making conflicting claims on same topic:
- Claim A (source 1, line X)
- Claim B (source 2, line Y)
- Resolution: [merge / defer to newer / flag for human]

**Never silently resolve contradictions** — user must see them.

## Budget Strategy

Default: 25 inspect+search calls. If exceeded:
- Report actual coverage to user
- Offer: extend budget (user approves next 15 calls) OR synthesize from partial (document gaps in brief)

For N>15 sources or sources >50K tokens each: request budget increase upfront (50-75 calls).

## Output Example

```
pack/
├── brief.md              # 500 words, cross-source contradictions highlighted
├── findings.md           # Full findings with path:line
├── sources.tsv           # Machine-readable index
└── _aggregation_log.md   # Tool-call trace
```

Example `brief.md` structure:

```markdown
# {Topic} — Aggregate brief
**N sources**: 7 | **Date range**: 2026-03-15 to 2026-04-18 | **Budget used**: 23/25

## Executive Summary
[≤500 words with inline path:line citations]

## Key Findings
1. Finding A (corroborated by 4 sources)
2. Finding B (unique to 1 source — `memory/handoff-2026-04-17.md:45`)

## Cross-source contradictions
- Claim X: source 1 says "yes" (`a.md:10`), source 3 says "no" (`c.md:22`)
  → Resolution: source 3 is newer, defer

## Next Actions
- [...]
```

## Common Mistakes

- **Concat mode slipping in**: rejecting the protocol and reading all files at once → defeats the purpose. Stick to inspect budget.
- **Missing path:line on claims**: vibes-based synthesis is a regression. Every claim must track back.
- **Resolving contradictions silently**: even when tempting, surface the conflict.
- **No aggregation log**: without trace, audit is impossible. Always emit `_aggregation_log.md`.

## Real-World Applications (ATLAS)

1. **Benchmark synthesis**: N=23 per-repo sections → cross-repo pattern pack
2. **Memory consolidation**: N=50 feedback files → themed insights
3. **Programme rollup**: N=8 sub-plans → executive programme status
4. **Handoff aggregation**: N=10 session handoffs → current state snapshot

## References

- `atlas-core:deep-research` — complement (web-based, from scratch)
- `atlas-core:memory-dream` — composes (may invoke this skill on N memory themes)
- `atlas-admin-addon:programme-manager` — composes (may invoke on N sub-plans)
- ADR-018: `docs/ADR/ADR-018-wiki-aggregate-protocol.md`
- Original protocol: lich-skills `skills/wiki-aggregate/SKILL.md`

---

*Skill authored 2026-04-19 as plan `joyful-hare` Batch 2 REC-030. Attributed to LichAmnesia/lich-skills (MIT) per metadata.sources[].*
