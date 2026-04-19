---
name: deep-research
description: "Deep research with multi-query decomposition. This skill should be used when the user asks to 'research', 'deep research', 'investigate', 'compare options', '/a-research-deep', or needs a triangulated summary across 2-3 angles."
effort: high
---

# Deep Research

## Overview

Structured research pipeline: decompose a question into 2-3 focused sub-questions,
search each angle independently, triangulate findings across sources, then synthesize
a concise summary. Optimized for technical decisions, library comparisons, and trend analysis.

**Model strategy:** Sonnet for research agent (search + fetch), Opus for final synthesis.

## Red Flags (rationalization check)

Before shortcutting deep research, ask yourself — are any of these thoughts running? If yes, STOP. Single-query research produces fragile decisions on one biased source.

| Thought | Reality |
|---------|---------|
| "One search is enough" | Single query = one angle. Triangulation needs 2-3 angles minimum. |
| "I'll synthesize from memory" | Memory = pre-cutoff training data. For 2026+ facts, use WebSearch with current year. |
| "Skip WebFetch, snippets are enough" | Snippets strip context. Deep-dive 1-2 URLs per angle via WebFetch. |
| "The first source looks authoritative" | That's LLM-as-judge bias. Always cross-check 2 independent sources. |
| "500-word summary is too short" | It's the CAP, not the goal. Longer = displacive summary + copyright risk. |
| "Sequential WebSearches are fine" | Sub-questions are independent — PARALLELIZE in the same message (2-3x faster). |
| "Context7 isn't needed for well-known libs" | Training data is stale on recent library versions. Always check Context7 for API specifics. |
| "No need to cite sources" | Citations = verifiable. Un-cited = hearsay. Always cite path or URL. |

## Process

### 1. Decompose the Query

Before searching, break the user's question into 2-3 specific sub-questions:

| Angle | Focus |
|:------|:------|
| Technical implementation | How is it built? Benchmarks, code examples |
| Current state & trends | Recent developments, adoption, ecosystem |
| Alternatives & trade-offs | What else exists? Community opinion |

Pick the 2-3 most relevant angles for the question. Not every question needs all three.

### 2. Parallel Research Queries

Sub-questions are independent — launch WebSearch calls **in parallel** by issuing
multiple tool calls in the **same message**. This cuts total research time by 2-3x.

```
# PARALLEL — all issued in the same message

WebSearch call 1:
  query: "{angle 1 — technical implementation, current year}"

WebSearch call 2:
  query: "{angle 2 — recent developments, ecosystem, current year}"

WebSearch call 3 (if applicable):
  query: "{angle 3 — alternatives, community opinion, benchmarks}"
```

After WebSearch results arrive, use **WebFetch** to deep-dive the 1-2 most
promising URLs per angle (sequentially — each fetch depends on search results).

Use **Context7** for any specific library/package documentation:
```
resolve-library-id → query-docs (can run in parallel with WebSearch)
```

**Triangulate**: confirm key facts across 2-3 independent sources per angle.
Report extraction confidence per finding: High / Medium / Low.

### 3. Collect Results

Wait for all parallel searches to complete. If any search times out (>30s), use
partial results from that angle and note the gap in the synthesis.

### 4. Synthesize (Opus)

Present findings to the user in this structure:

```markdown
## Research Summary: {topic}

### TL;DR
[2-3 sentences combining key findings]

### {Angle 1 Title}
[Architecture, code patterns, benchmarks — whatever fits the angle]

### {Angle 2 Title}
[Recent developments, adoption, ecosystem]

### {Angle 3 Title} (if applicable)
| Option | Pros | Cons | Best For |
|--------|------|------|----------|

### Recommendation
[What should we do? Clear, actionable.]

### Sources
[URLs with relevance notes — cite angle + confidence per source]
```

### 5. Knowledge Capture

If findings contain reusable patterns or library tips:
- Suggest saving to `.claude/references/{topic}.md` (tech references)
- Or append to `memory/lessons.md` if it's a project-relevant lesson

## Constraints

- Max **2-3 sub-queries** (memory guard)
- Max **15 tool calls** total across the research agent
- Max **500 words** in agent summary
- Total research should complete in **< 2 minutes**
- Agent runs with `run_in_background: true` (context window protection)

## HITL Gate

After synthesis, use AskUserQuestion:
- "Research complete. Want to capture key findings to references?"
- If findings change an architecture decision, log to `.claude/decisions.jsonl`

## Usage Examples

```
"best practices for AI agent orchestration 2026"
"Excel MCP servers comparison"
"ParadeDB vs Elasticsearch for BM25 search"
"Konva vs PixiJS performance for P&ID rendering"
```
