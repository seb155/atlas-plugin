---
name: deep-research
description: "Deep research with multi-query decomposition. Decompose question into 2-3 angles, search + fetch + triangulate, synthesize structured summary (500w max). Sonnet for research, Opus for synthesis."
---

# Deep Research

## Overview

Structured research pipeline: decompose a question into 2-3 focused sub-questions,
search each angle independently, triangulate findings across sources, then synthesize
a concise summary. Optimized for technical decisions, library comparisons, and trend analysis.

**Model strategy:** Sonnet for research agent (search + fetch), Opus for final synthesis.

## Process

### 1. Decompose the Query

Before searching, break the user's question into 2-3 specific sub-questions:

| Angle | Focus |
|:------|:------|
| Technical implementation | How is it built? Benchmarks, code examples |
| Current state & trends | Recent developments, adoption, ecosystem |
| Alternatives & trade-offs | What else exists? Community opinion |

Pick the 2-3 most relevant angles for the question. Not every question needs all three.

### 2. Research (Sonnet Agent)

Launch ONE background researcher agent with all sub-questions:

- Use **WebSearch** for discovery (broad queries, recent results)
- Use **WebFetch** for deep content extraction (specific pages, docs)
- Use **Context7** for library documentation when researching specific packages
- **Triangulate**: confirm key facts across 2-3 independent sources
- Report extraction confidence: High / Medium / Low per finding

### 3. Collect Results

Wait for the agent to complete (timeout: 120s). If it times out, use partial results.

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
[URLs with relevance notes]
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
