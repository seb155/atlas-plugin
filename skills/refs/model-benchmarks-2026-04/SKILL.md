---
name: model-benchmarks-2026-04
description: "Claude Opus 4.6 vs Sonnet 4.6 benchmark comparison, decision framework, pricing, and prompt caching strategy. Reference for ATLAS model allocation."
---

# Claude Model Benchmarks — April 2026

> Reference for ATLAS model allocation decisions.
> SSoT for task-to-model routing: `skills/execution-strategy/model-rules.yaml`
> Last updated: 2026-04-12

## Model Comparison

| Metric | Opus 4.6 | Sonnet 4.6 | Haiku 4.5 | Notes |
|--------|----------|-----------|-----------|-------|
| **SWE-bench Verified** | 80.8% | 79.6% | ~50% | Gap: 1.2pts (smallest in Claude history) |
| **GPQA Diamond** | 91.3% | 74.1% | ~40% | Gap: 17.2pts (PhD-level science) |
| **GDPval-AA** | 1606 Elo | **1633 Elo** | N/A | Sonnet LEADS on practical tasks |
| **Context window** | 1M tokens | 1M tokens | 200K | Both top models = 1M |
| **Max output** | 128K tokens | 64K tokens | 8K | Opus 2x for long plans |
| **Speed** | ~20-30 tok/s | ~40-60 tok/s | ~80-100 tok/s | Sonnet 2.7x faster |
| **Input price** | $15/MTok | $3/MTok | $0.25/MTok | Opus 5x more expensive |
| **Output price** | $75/MTok | $15/MTok | $1.25/MTok | Opus 5x more expensive |
| **Cache read** | $1.50/MTok | $0.30/MTok | $0.025/MTok | 90% discount on cached |

## Decision Framework

```
TASK REQUIRES...                         → MODEL
─────────────────────────────────────────────────
Architecture, multi-file design           → Opus 4.6
Extended thinking, ultrathink             → Opus 4.6
Planning (>50h effort scope)              → Opus 4.6
Complex debugging (cross-system)          → Opus 4.6
Irreversible decisions                    → Opus 4.6
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

1. **Main session = Opus 4.6 [1m]** — holds full project context, makes orchestration decisions
2. **Subagents = Sonnet 4.6** — scoped tasks with distilled context from orchestrator
3. **Validators = Haiku 4.5** — cheapest for pass/fail checks
4. **Deterministic ops = DET** — bash commands, zero AI tokens

**Why Opus for orchestration (not just context)**:
- Both models support 1M tokens — context is NOT the differentiator
- Opus's +17pt GPQA advantage means better task decomposition decisions
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

## Cost Scenarios

| Scenario | Per Session | Per Month (2/day) | Annual |
|----------|------------|-------------------|--------|
| All Opus (naive) | $8-15 | $500-900 | $6K-11K |
| Current ATLAS (mixed) | $3-6 | $180-360 | $2.2K-4.3K |
| Optimized (aggressive Sonnet) | $2-4 | $120-240 | $1.4K-2.9K |
| + SP-DEDUP + caching | $1.5-3 | $90-180 | $1.1K-2.2K |

## Sources

- Anthropic official: models overview + pricing docs (April 2026)
- SWE-bench Verified leaderboard
- Cursor internal data (Aman talk, April 2026)
- ATLAS execution-strategy production data

## When to Update This Doc

- New model release (Opus 5.0, Sonnet 5.0, etc.)
- Significant pricing changes (>20% delta)
- New benchmarks that change the decision framework
- Every 3 months as standard refresh
