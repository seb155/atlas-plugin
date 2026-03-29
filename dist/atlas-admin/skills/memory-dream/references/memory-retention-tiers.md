# Memory Retention Tiers

> SP-COGNITION Gap 6: Active Forgetting
> Inspired by human memory: working → long-term → permanent.
> Dream Phase 3.8 uses these tiers for consolidation + cleanup.

## Tier Classification

| Tier | Name | TTL | Auto-Action | Examples |
|------|------|-----|-------------|----------|
| 0 | **Ephemeral** | Session only | Deleted on session end | signals.json, tone-state.json, tom-signals.json |
| 1 | **Working** | < 7 days | Consolidate → lessons/decisions | handoff-*.md, session-log entries, dream-report-*.md |
| 2 | **Active** | 7-90 days | Revalidate quarterly | intuitions, relationships, plans, patterns-weekly |
| 3 | **Permanent** | Forever | Never touch | feedback_*.md, user_profile.md, self-model.md |

## Classification Rules

### Automatic Classification (by filename pattern)

```python
TIER_RULES = {
    # Tier 0: Ephemeral (session-scoped, not in memory/)
    0: [
        "~/.claude/atlas-experiential-signals.json",
        "~/.claude/atlas-tone-state.json",
        "~/.claude/atlas-tom-signals.json",
        "~/.claude/atlas-prediction-log.json",
        "~/.claude/atlas-curiosity-signals.json",
    ],

    # Tier 1: Working Memory (consolidate after 7 days)
    1: [
        "handoff-*.md",           # Session handoffs
        "dream-report-*.md",      # Dream reports (insights → self-model)
        "checkpoint-*.md",        # Phase checkpoints
        "session-log.md",         # Entries > 60 days → archive
        "agent-teams-*.md",       # Agent team results
        "domain-cleanup-*.md",    # One-time cleanup records
    ],

    # Tier 2: Active Long-Term (revalidate quarterly)
    2: [
        "intuition-*.md",         # Until validated or archived
        "relationship-*.md",      # Until stale > 90 days
        "patterns-*.md",          # Until replaced by newer patterns
        "sp-*-*.md",              # Sub-plan status (until shipped/archived)
        "plan-*.md",              # Plan context (until executed)
        "handoff-*-complete.md",  # Completion handoffs (longer relevance)
        "*-audit-*.md",           # Audit results (until superseded)
        "episode-*.md",           # Episodic memory (for pattern extraction)
        "lessons-*.md",           # Accumulated lessons
    ],

    # Tier 3: Permanent (never auto-delete)
    3: [
        "feedback_*.md",          # IMMUTABLE — behavioral corrections
        "feedback-*.md",          # IMMUTABLE — consolidated feedback
        "user_profile.md",        # User identity
        "self-model.md",          # ATLAS identity
        "MEMORY.md",              # Index (always regenerated)
        "dream-history.jsonl",    # Trend data (append-only)
        "stack-2026.md",          # Stack reference
        "*-vision*.md",           # Vision documents
    ],
}
```

### Override Classification

Some files don't match patterns. Use frontmatter:
```yaml
---
retention_tier: 2  # Explicit override
---
```

## Dream Phase 3.8 — Active Forgetting

> HITL required for every deletion. Never auto-delete.

### Process

```
FOR each file in Tier 1 where age > 7 days:
  1. Read the file
  2. Extract uncaptured insights:
     - Decisions not in decisions.jsonl
     - Lessons not in lessons-*.md
     - Gotchas not in feedback files
  3. IF uncaptured insights found:
     → Propose merging into lessons/decisions (HITL H25)
  4. IF all insights already captured:
     → Propose deletion (HITL H26)
  5. IF user rejects deletion:
     → Reclassify to Tier 2

FOR each file in Tier 2 where age > 90 days:
  1. Read the file
  2. Check: is this file still referenced in ACTIVE WORK?
  3. IF not referenced AND not updated in 90 days:
     → Propose archival (not deletion) to memory/archive/ (HITL H27)
  4. IF referenced:
     → Keep, flag for review
```

### Safety Rules

1. **NEVER auto-delete** — HITL gate on every deletion
2. **NEVER touch Tier 3** — feedback files, self-model, vision docs
3. **Extract before delete** — always consolidate insights first
4. **Reclassify up, never down** — if uncertain, promote to higher tier
5. **Keep count** — track deleted files in dream report for audit trail

## Metrics

| Metric | Current | Target (after 3 months) |
|--------|---------|------------------------|
| Total files | 206 | < 180 (denser, less noise) |
| Tier 1 files > 7d | ? | 0 (consolidated or deleted) |
| Tier 2 files > 90d | ? | < 10 (reviewed quarterly) |
| Signal-to-noise ratio | Unknown | Improving trend in health score |

---
*SP-COGNITION Gap 6. Created: 2026-03-29 00:15 EDT*
