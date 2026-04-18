# ADR 0003 — Claude Code Session Recap vs ATLAS session-pickup

**Status**: PROPOSED (HITL Seb)
**Date**: 2026-04-17
**Context**: ATLAS v6.0 Sprint 6 — feature deduplication audit

## Context

Two competing capabilities for session resumption:

1. **CC Session Recap** (Anthropic native, 2026)
   - Built-in summary of last session on resume
   - Auto-generated from CC's own context tracking
   - No user action required

2. **ATLAS session-pickup** (atlas-core skill — `skills/session-pickup/SKILL.md`)
   - Loads explicit handoff files from `memory/handoff-*.md`, `.blueprint/handoffs/`, `.claude/topics/<topic>/handoffs/`
   - Reloads project context, active tasks, branch state, vault profile
   - Triggers via `/pickup` command, `/atlas pickup`, or natural language ("resume", "continue where I left off")
   - Customized for ATLAS workflows (Blueprint plans, topic memory, multi-project disambiguation)

## Overlap Analysis

| Capability | CC Recap | ATLAS pickup |
|---|---|---|
| Auto on resume | yes | no (requires command/hook) |
| Customizable | no | yes (handoff format, project rules) |
| Persistent storage | Internal | `memory/handoff-*.md` files |
| Cross-project | no (per-session) | yes (vault profiles, topic memory) |
| Detail granularity | Summary only | Full context reload |
| ATLAS-specific (Blueprint, Iron Laws) | no | yes |
| Plan mode gate (scope-locked drill-in) | no | yes |
| Native session resume (`claude --resume <name>`) | n/a | wrapper via `atlas resume` (v5.7.0+) |

**Estimated overlap**: ~25% (both surface "what happened last"). The remaining 75% is ATLAS-specific (handoff parsing, vault loading, topic memory, Blueprint awareness).

**Conclusion**: Some overlap, but session-pickup is **strictly more capable** for ATLAS workflows.

## Decision

**Keep both, distinct roles**:

- **CC Session Recap**: automatic, one-line summary on every session start (default Anthropic behavior, do not disable)
- **ATLAS session-pickup**: opt-in `/pickup` command or hook trigger, full context reload from handoff file

### Clarification

- session-pickup STAYS as ATLAS-specific tool (Blueprint awareness, multi-project, vault, topic memory)
- Document that session-pickup is **complementary** (not replacement) to CC Recap
- Update SKILL.md to mention "Use after CC's auto Recap if you need full context (handoff file)" (follow-up Sprint 7)

## Why NOT merge?

- CC Recap is non-customizable (Anthropic-controlled)
- session-pickup needs custom logic (handoff parsing, vault loading, plan reload, topic-aware lookup)
- Different purposes: Recap = "what happened" / pickup = "where am I now + what's next"

## Why NOT deprecate?

- session-pickup is invoked 2-3x daily by Seb (per memory pattern)
- Vault auto-load + handoff format + topic memory = unique value, no Anthropic equivalent
- Plan v6.0 Sprint 0.5 added agent-visibility integration in session-pickup flow
- Topic-aware pickup (SP-ECO v4) reads `.claude/topics/<topic>/{handoffs,decisions,lessons,context}` — orthogonal to CC Recap

## Implementation Status

- CC Session Recap — active (Anthropic 2026, no action required)
- ATLAS session-pickup — shipped v5.x (`skills/session-pickup/SKILL.md`), no changes needed for v6
- Doc update — add "Note" section to SKILL.md (NOT in this ADR scope, follow-up Sprint 7)

## HITL Questions for Seb

1. Confirm "keep both, distinct roles" decision?
2. Update session-pickup SKILL.md description to mention complementarity with CC Recap?
3. Hook to auto-trigger session-pickup on resume (after CC Recap) — desirable, or keep opt-in?

## Sources

- ATLAS session-pickup: `skills/session-pickup/SKILL.md` (atlas-core)
- Anthropic Session Recap (CC docs 2026)
- Memory pattern: `memory/handoff-*.md`, `.blueprint/handoffs/handoff-*.md`, `.claude/topics/<topic>/handoffs/`
- Plan v6.0 Section A.2 — feature deduplication audit
- Related ADR: `0001-mcp-browser-consolidation.md` (companion dedup decision)
