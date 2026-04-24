# Prompt Caching Strategy v1.0

> v6.0 Sprint 1 P1-1 — prompt caching optimization for AGENT.md + SKILL.md
> Created: 2026-04-23
> SDK: Claude API v2 (Anthropic) — `ENABLE_PROMPT_CACHING_1H` env var

## Why Prompt Caching Matters

Anthropic's Claude API supports **ephemeral prompt caching** via `cache_control: {"type": "ephemeral"}`. Claude Code uses this automatically when the `ENABLE_PROMPT_CACHING_1H` env var is set. Caching hits reduce cost by **90%** on cached portions and reduce latency by **~200ms per call**.

For ATLAS with 24 agents each invoked 10-100 times per session, the cumulative savings are **$1-5/session** at scale.

## How Claude Code Caches

```
┌─────────────────────────────────────────────────────┐
│ SYSTEM PROMPT (static)              ← cacheable    │
│ - AGENT.md body                     ← cache_control│
│ - atlas-assist injection (23KB)     ← cache_control│
│ - Iron Laws + Red Flags             ← cache_control│
├─────────────────────────────────────────────────────┤
│ USER MESSAGE 1 (static-ish)         ← cacheable    │
│ USER MESSAGE 2 (dynamic)            ← not cached   │
└─────────────────────────────────────────────────────┘
```

The SDK automatically identifies the largest stable content block and applies cache_control. **Static content at the TOP of AGENT.md gets cached first**.

## AGENT.md Structure for Optimal Caching

### ✅ GOOD structure (cache-friendly)

```markdown
---
name: code-reviewer
description: "..."
model: claude-opus-4-7[1m]
effort: xhigh
thinking_mode: adaptive
version: 6.0.0
# STATIC persona/role/tools above this line
---

# Code Reviewer Agent

You are a code review specialist for ATLAS/Synapse.    # STATIC (cached)
You review diffs against CLAUDE.md rules + conventions. # STATIC (cached)

## Your Role                                            # STATIC (cached)
- Review against CLAUDE.md rules
- Check SOLID principles
- Verify test coverage

## Output Format                                        # STATIC (cached)
```yaml
summary: high-level verdict
findings:
  - severity: high | medium | low
    category: ...
```

---  # ← cache boundary naturally ends here

<!-- Dynamic context below (varies per invocation):
     - Git diff output
     - PR description
     - Related file paths
     These are NOT part of AGENT.md but passed in at invocation time. -->
```

### ❌ BAD structure (cache-breaking)

```markdown
---
name: code-reviewer
last_invoked: 2026-04-23  # ← timestamp breaks cache every hour!
dynamic_field: {{user}}   # ← template var breaks cache
---

# Code Reviewer Agent

Session ID: abc123                   # ← BREAKS CACHE
Today's date: 2026-04-23             # ← BREAKS CACHE
Recent files: [ ... ]                # ← BREAKS CACHE
```

## Guidelines

1. **Immutable metadata only in frontmatter** — `name`, `description`, `model`, `effort`, `version` (stable across invocations)
2. **No timestamps, session IDs, or dynamic vars** in AGENT.md
3. **Static persona + role + output format** in the body
4. **Dynamic context passed via invocation** (tool_use, not AGENT.md)
5. **Length matters** — longer static content = more cache benefit per hit (>1024 tokens recommended)
6. **Ordering matters** — most-stable content FIRST (persona → role → tools → format)

## Env Var Activation

In `~/.claude/settings.json`:

```json
{
  "env": {
    "ENABLE_PROMPT_CACHING_1H": "true",
    "FORCE_PROMPT_CACHING_5M": "false"
  }
}
```

Options:
- `ENABLE_PROMPT_CACHING_1H=true` — 1-hour TTL (recommended, balances freshness + savings)
- `FORCE_PROMPT_CACHING_5M=true` — 5-min TTL (aggressive, for dev iteration)

## Cost Impact (3 Opus agents example)

| Scenario | No cache | With cache | Savings |
|----------|----------|------------|---------|
| Plan-architect 10 invocations/day | $0.50 | $0.05 | 90% ($0.45) |
| Code-reviewer 30 invocations/day | $0.75 | $0.075 | 90% ($0.675) |
| Infra-expert 5 invocations/day | $0.25 | $0.025 | 90% ($0.225) |
| **Total daily** | **$1.50** | **$0.15** | **$1.35/day** |
| **Total monthly** | **$45** | **$4.50** | **$40.50/month** |

(Estimates based on avg 2000 input tokens @ $5/MTok Opus; output not cached)

## Verification

After activating, check cache hit rate via SDK response headers:
- `cache_creation_input_tokens` — tokens written to cache (first call)
- `cache_read_input_tokens` — tokens read from cache (subsequent calls)

Target: **>70% cache hit rate** on repeat agent invocations within 1h TTL.

## Integration Checklist

- [ ] Env var `ENABLE_PROMPT_CACHING_1H=true` set in `~/.claude/settings.json`
- [ ] 3 Opus AGENT.md have static-content-first structure (code-reviewer, infra-expert, plan-architect)
- [ ] No timestamps/session-IDs/dynamic-vars in AGENT.md bodies
- [ ] Verify via cost-analytics skill: `/atlas cost` shows cache_read_input_tokens increasing

## References

- [Anthropic Prompt Caching docs](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Claude Code env vars](https://docs.claude.com/en/docs/claude-code/settings)
- `.blueprint/schemas/agent-frontmatter-v6.md` — AGENT.md schema
- `skills/refs/model-benchmarks-2026-04/SKILL.md` — model pricing + cache costs

## Version History

- **v1.0** (2026-04-23): Initial strategy doc — Sprint 1 P1-1 deliverable (v6.0.0-alpha.10+)
