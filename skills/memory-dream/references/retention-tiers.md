# Memory Retention Tiers — Active Forgetting (SP-COGNITION Gap #6)

> Inspired by human memory consolidation: not all memories deserve permanent storage.
> Files that outlive their usefulness create noise for future AI sessions.

## 4 Tiers

| Tier | Label | TTL | Auto-Action | Examples |
|------|-------|-----|-------------|----------|
| **0** | **Permanent** | ∞ | None | feedback_*.md, user_*.md, relationship_*.md, self-model.md |
| **1** | **Long-term** | 180 days | Warn at 150d, propose archive at 180d | project decisions, architecture docs, strategic plans |
| **2** | **Medium-term** | 60 days | Warn at 45d, propose archive at 60d | handoffs, session logs, episodes, sprint checkpoints |
| **3** | **Short-term** | 14 days | Warn at 10d, auto-archive at 14d | debug notes, temporary status, experiment results |

## Type → Tier Inference Map

When a memory file has no explicit `retention_tier:` in frontmatter, infer from the `type:` field:

```yaml
# Tier 0 — Permanent
feedback: 0
user: 0
reference: 0

# Tier 1 — Long-term (180 days)
project: 1

# Tier 2 — Medium-term (60 days)
# Default for files without type
```

### Filename Pattern Overrides

Some filenames imply a specific tier regardless of type:

```yaml
# Tier 0 (always keep)
- "feedback_*.md"
- "feedback-*.md"
- "user_*.md"
- "relationship_*.md"
- "self-model.md"
- "MEMORY.md"
- "lessons*.md"

# Tier 1 (long-term)
- "sp-*.md"           # Sub-plan summaries
- "sp[0-9]*.md"       # Sub-plan references
- "*-vision.md"       # Vision documents
- "mega-plan-*.md"    # Mega plans
- "stack-*.md"        # Stack documentation

# Tier 2 (medium-term)
- "handoff-*.md"      # Session handoffs
- "episode-*.md"      # Experiential episodes
- "checkpoint-*.md"   # Phase checkpoints
- "session-*.md"      # Session logs
- "dream-report-*.md" # Dream reports
- "archive-*.md"      # Archive bundles

# Tier 3 (short-term)
- "debug-*.md"        # Debug notes
- "temp-*.md"         # Temporary files
- "scratch-*.md"      # Scratch pads
- "experiment-*.md"   # Experiment logs
```

## Frontmatter Declaration

Memory files CAN declare their retention tier explicitly:

```yaml
---
name: Handoff — Sprint E Complete
type: project
retention_tier: 2
---
```

Explicit `retention_tier:` always takes priority over inference.

## Expiry Scanning (Dream Phase Integration)

During Dream consolidation, Phase 3 checks each memory file:

1. Determine tier (explicit → type inference → filename pattern → default Tier 2)
2. Compute age in days from file modification time
3. Compare age vs tier TTL
4. Classify: FRESH | WARNING | EXPIRED

### Actions by State

| State | Tier 0 | Tier 1 | Tier 2 | Tier 3 |
|-------|--------|--------|--------|--------|
| FRESH | — | — | — | — |
| WARNING | — | Note in report | Suggest review | Auto-warn |
| EXPIRED | — | Propose archive (HITL) | Propose archive (HITL) | Auto-archive |

### Auto-Archive Process

1. Read file content
2. Extract key facts (first 5 lines after frontmatter)
3. Move to archive bundle: `archive-expired-{year}-{month}.md`
4. Remove original file
5. Update MEMORY.md index
6. Log action to dream report

### HITL Gates

- **Tier 1 EXPIRED**: Always ask before archiving (may still be relevant)
- **Tier 2 EXPIRED**: Ask unless `--auto` flag (batch archiving)
- **Tier 3 EXPIRED**: Auto-archive, report in dream summary
- **Tier 0**: NEVER touch. If a Tier 0 file is somehow flagged, log a warning and skip.

## Metrics

Track in dream health scoring:
- **D18**: Retention health = (non-expired files / total files) × 10
- Fresh: all Tier 2-3 files within TTL
- Degraded: 1-5 expired files
- Critical: 6+ expired files
