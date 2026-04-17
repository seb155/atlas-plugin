---
name: model-benchmarks-2026-04
description: "Claude Opus 4.7 vs Sonnet 4.6 benchmark comparison, decision framework, pricing, and prompt caching strategy. Reference for ATLAS model allocation."
---

# Claude Model Benchmarks — April 2026

> Reference for ATLAS model allocation decisions.
> SSoT for task-to-model routing: `skills/execution-strategy/model-rules.yaml`
> Last updated: 2026-04-16 (Opus 4.7 GA)

## Model Comparison

> **Note**: SWE-bench, GPQA, and GDPval figures below are **as of Opus 4.6** (April 2026 snapshot).
> Opus 4.7 launched 2026-04-16 with same pricing; official 4.7 benchmarks pending dedicated update.
> Tokenizer change: Opus 4.7 may produce up to +35% tokens for same text vs 4.6 (effective cost impact).

| Metric | Opus 4.7 | Sonnet 4.6 | Haiku 4.5 | Notes |
|--------|----------|-----------|-----------|-------|
| **SWE-bench Verified** | 80.8% (4.6 data) | 79.6% | ~50% | Gap: 1.2pts (smallest in Claude history, 4.6 data) |
| **GPQA Diamond** | 91.3% (4.6 data) | 74.1% | ~40% | Gap: 17.2pts (PhD-level science, 4.6 data) |
| **GDPval-AA** | 1606 Elo (4.6 data) | **1633 Elo** | N/A | Sonnet LEADS on practical tasks (4.6 era) |
| **Context window** | 1M tokens | 1M tokens | 200K | Both top models = 1M |
| **Max output** | 128K tokens | 64K tokens | 8K | Opus 2x for long plans |
| **Speed** | ~20-30 tok/s | ~40-60 tok/s | ~80-100 tok/s | Sonnet 2.7x faster |
| **Input price** | $5/MTok | $3/MTok | $0.25/MTok | Opus 1.7x Sonnet |
| **Output price** | $25/MTok | $15/MTok | $1.25/MTok | Opus 1.7x Sonnet |
| **Cache read** | $0.50/MTok | $0.30/MTok | $0.025/MTok | 90% discount on cached |
| **Effort levels** | low/medium/high/xhigh/max | low/medium/high | low/medium/high | xhigh = Opus 4.7 exclusive (v2.1.111+) |

## Decision Framework

```
TASK REQUIRES...                         → MODEL
─────────────────────────────────────────────────
Architecture, multi-file design           → Opus 4.7
Extended thinking, ultrathink             → Opus 4.7 (max)
Planning (>50h effort scope)              → Opus 4.7
Complex debugging (cross-system)          → Opus 4.7 (xhigh)
Irreversible decisions                    → Opus 4.7
─────────────────────────────────────────────────
Implementation (clear spec)               → Sonnet 4.6
Code review, security audit               → Sonnet 4.6
DB migrations                             → Sonnet 4.6
Test writing                              → Sonnet 4.6
Frontend components                       → Sonnet 4.6
Bug fixes (isolated scope)                → Sonnet 4.6
Refactor (<5 files)                       → Sonnet 4.6
─────────────────────────────────────────────────
Checklist validation                      → Haiku 4.5
Simple search/grep                        → Haiku 4.5
Status checks                             → Haiku 4.5
─────────────────────────────────────────────────
Lint, format, type-check                  → DET (bash)
```

## Orchestrator Pattern (Cursor-Validated)

Based on Cursor's production experience (30% PRs from cloud agents, April 2026):

1. **Main session = Opus 4.7 [1m]** — holds full project context, makes orchestration decisions
2. **Subagents = Sonnet 4.6** — scoped tasks with distilled context from orchestrator
3. **Validators = Haiku 4.5** — cheapest for pass/fail checks
4. **Deterministic ops = DET** — bash commands, zero AI tokens

**Why Opus for orchestration (not just context)**:
- Both models support 1M tokens — context is NOT the differentiator
- Opus's reasoning advantage means better task decomposition decisions
- Fewer compactions = higher fidelity orchestration over long sessions
- Orchestrator distills relevant context → subagents get focused, smaller prompts

## Prompt Caching Strategy

Structure subagent prompts for maximum cache hits:

```
┌──────────────────────────────────────────┐
│ BLOC 1: Project Context (cacheable)      │  ~5K tokens
│ - Stack, conventions, rules              │  Shared across ALL subagents
│ - CLAUDE.md essentials                   │  Cache: $0.30/MTok (Sonnet)
├──────────────────────────────────────────┤
│ BLOC 2: Skill Instructions (cacheable)   │  ~2K tokens
│ - Task type specific guidelines          │  Shared per skill type
│ - Quality criteria                       │  Cache: $0.30/MTok (Sonnet)
├──────────────────────────────────────────┤
│ BLOC 3: Task Context (unique)            │  Variable
│ - Specific files to modify               │  Unique per task
│ - Exact requirements                     │  Full price: $3/MTok (Sonnet)
└──────────────────────────────────────────┘
```

5 subagents sharing 7K cacheable preamble = 35K tokens at cache price ($0.01) vs standard ($0.11).

**1-hour TTL cache** (Opus 4.7 era, CC 2.1.108+): Set `ENABLE_PROMPT_CACHING_1H=true` env var to extend cache from 5min → 1h. Useful for long-running sessions.

## Cost Scenarios (Opus 4.7 pricing, +35% tokenizer adjustment)

| Scenario | Per Session | Per Month (2/day) | Annual |
|----------|------------|-------------------|--------|
| All Opus 4.7 (naive) | $3-6 | $180-360 | $2.2K-4.3K |
| Current ATLAS (mixed) | $1-3 | $60-180 | $720-2.2K |
| Optimized (aggressive Sonnet) | $1-2 | $60-120 | $720-1.4K |
| + SP-DEDUP + caching | $0.50-1.50 | $30-90 | $360-1.1K |

**Savings**: Opus 4.7 pricing ($5/$25) vs 4.6 ($15/$75) = **~66% reduction** at same token volume. Partial offset by tokenizer +35% → **net ~55% cost reduction** expected.

## Sources

- Anthropic official: [Claude Opus 4.7 announcement](https://www.anthropic.com/news/claude-opus-4-7), [pricing docs](https://platform.claude.com/docs/en/about-claude/pricing)
- [BenchLM pricing April 2026](https://benchlm.ai/blog/posts/claude-api-pricing)
- SWE-bench Verified leaderboard (4.6 snapshot)
- Cursor internal data (Aman talk, April 2026)
- ATLAS execution-strategy production data
- CC 2.1.111 changelog (Opus 4.7 xhigh effort level)

## When to Update This Doc

- New model release (Opus 4.8, Sonnet 5.0, etc.)
- Significant pricing changes (>20% delta)
- New benchmarks that change the decision framework
- Official Opus 4.7 benchmarks published by Anthropic (follow-up item)
- Every 3 months as standard refresh
