---
name: cc-native-features
description: "Claude Code native features reference — /effort, ultrathink, auto-dream, /loop, CronCreate, compaction, extended thinking. Use when configuring CC behavior, leveraging native capabilities, or explaining CC features."
---

# Claude Code Native Features Reference

> Reference document for CC features that ATLAS leverages or wraps.

## Thinking Budget Control

| Method | Budget | Use Case |
|--------|--------|----------|
| `think` keyword | ~4K tokens | Basic reflection |
| `think hard` / `megathink` | ~10K tokens | Moderate problems |
| `think harder` / `ultrathink` | ~32K tokens | Architecture, complex decisions |
| `/effort low` | Reduced | Fast responses, simple tasks |
| `/effort medium` | Default | Normal development |
| `/effort high` | Maximum | Deep reasoning, planning |

**Rule**: Use `ultrathink` for architecture decisions, plan design, and complex debugging. Use `/effort low` for routine commands and simple edits.

## Auto-Dream (Unreleased — Feature Flag)

CC has a native auto-dream feature (behind `tengu_onyx_plover` flag, not GA as of March 2026).

**4-phase cycle**:
1. **Orient**: Scan memory dir, read MEMORY.md, build knowledge graph
2. **Gather Signal**: Find corrections, recurring themes, stale entries
3. **Consolidate**: Merge duplicates, normalize dates (relative→absolute), remove contradictions
4. **Prune & Index**: Refresh MEMORY.md under 200 lines, reorder by relevance

**Trigger conditions** (when GA):
- `minHours: 24` + `minSessions: 5` (automatic)
- Manual: "dream", "auto dream", "consolidate my memory files"

**ATLAS equivalent**: `/atlas dream` (memory-dream skill) implements this pattern now.

**Paper**: UC Berkeley + Letta "Sleep-time Compute" (April 2025) — pre-computing during idle time reduces test-time compute by 5x.

## Scheduled Execution

| Feature | Scope | Persistence |
|---------|-------|-------------|
| `CronCreate` | Session | Dies when Claude exits |
| `CronDelete` | Session | Remove by job ID |
| `/loop` | Session | Recurring command execution |
| Remote Triggers | Cloud | Persists across sessions |

**ATLAS integration**: `/atlas dream --schedule` uses CronCreate for in-session recurring dreams.

## Compaction

- Auto-compacts at ~85% context (configurable via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`)
- `PreCompact` hook: inject context to preserve
- `PostCompact` hook: log event, restore critical state
- ATLAS hooks: `pre-compact.sh` (git state), `post-compact` (restore + dream suggestion)
- Images survive compaction (CC 2.1.72+)
- Text nuances may be lost — use memory files for critical info

## Context Window

| Model | Window | Notes |
|-------|--------|-------|
| Opus 4.6 | 1M tokens | Full codebase fits |
| Sonnet 4.6 | 1M tokens | Same window, faster |
| Haiku 4.5 | 200K tokens | Smaller, cheapest |

**Rule**: With 1M context, NEVER suggest session handoff for context reasons. Context budget is essentially unlimited for single-project work.

## Plan Mode

- `EnterPlanMode` → read-only exploration + design
- `ExitPlanMode` → present plan for user approval
- Plan file: auto-generated path in `.blueprint/plans/`
- In plan mode: only the plan file is writable

## Extended Thinking

- Opus only (Sonnet/Haiku don't support extended thinking)
- Set via `thinking: extended` in AGENT.md frontmatter
- Or via `ultrathink` keyword in prompts
- Budget scales with `/effort` setting
- Visible in Claude's thinking block (when enabled)
