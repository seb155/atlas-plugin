---
name: memory-dream
description: "Memory consolidation (CC auto-dream pattern). 4-phase cycle: orient, gather signal, consolidate, prune. Use when 'dream', 'consolidate memory', 'clean memory', 'memory audit', 'memory health', 'memory cleanup'."
effort: medium
---

# Memory Dream — Consolidation Skill

> Implements CC's auto-dream pattern: a 4-phase memory consolidation cycle inspired by
> sleep-time compute (UC Berkeley + Letta, 2025). Enriched with ATLAS-specific infra
> health and feedback audit.

## When to Use

- MEMORY.md is growing past 150 lines
- Many sessions since last consolidation (5+)
- User says "dream", "clean memory", "consolidate", "memory audit"
- End of sprint or major feature work
- Before starting a fresh planning session (clean slate)

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas dream` | Full 4-phase cycle with HITL gates |
| `/atlas dream --dry-run` | Report only — zero writes |
| `/atlas dream --infra` | Include infrastructure health snapshot |
| `/atlas dream report` | Quick staleness + orphan report only |
| `/atlas dream --schedule` | Schedule recurring dream via CronCreate |

## Phase 1 — Orient (Read-Only)

Scan the memory directory and build a mental map.

### Steps

1. **Detect memory directory**:
   ```bash
   MEMORY_DIR=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | head -1)
   ```
   If multiple projects, use the one matching the current working directory.

2. **Read MEMORY.md**: Count lines, extract `## Section` headers, build section→line map.

3. **List all topic files**:
   ```bash
   ls "$MEMORY_DIR"/*.md | grep -v MEMORY.md | wc -l
   ```

4. **Detect orphans**: Files in memory dir NOT referenced anywhere in MEMORY.md.
   ```bash
   for f in "$MEMORY_DIR"/*.md; do
     base=$(basename "$f")
     [ "$base" = "MEMORY.md" ] && continue
     grep -q "$base" "$MEMORY_DIR/MEMORY.md" || echo "ORPHAN: $base"
   done
   ```

5. **Check consolidation lock**:
   ```bash
   [ -f "$MEMORY_DIR/.consolidate-lock" ] && echo "LOCKED — another consolidation in progress"
   ```

6. **Output orient summary**:
   ```
   📊 Memory Orient
   ├─ MEMORY.md: {N} lines (limit: 200)
   ├─ Topic files: {N} total
   ├─ Orphans: {N} (not referenced in MEMORY.md)
   ├─ Lock: {free|locked}
   └─ Last modified: {date}
   ```

## Phase 2 — Gather Signal

Identify what needs attention without making changes.

### Steps

1. **Staleness report** — categorize files by last modification date:
   ```bash
   for f in "$MEMORY_DIR"/*.md; do
     age_days=$(( ($(date +%s) - $(stat -c %Y "$f")) / 86400 ))
     echo "$age_days $f"
   done | sort -n
   ```
   Buckets: `<7d` (fresh) | `7-14d` (aging) | `14-30d` (stale) | `>30d` (archive candidate)

2. **Feedback audit** — count and categorize:
   ```bash
   ls "$MEMORY_DIR"/feedback_*.md | wc -l
   ```
   Check for near-duplicates by comparing filenames (Levenshtein distance ≤ 3).

3. **Duplicate detection** — basic word overlap between files:
   - For each pair of non-feedback files, compute Jaccard similarity on word sets
   - Flag pairs with >70% overlap as merge candidates
   - Skip files under 100 words (too small to be meaningful duplicates)

4. **Relative date detection** — find dates that will become meaningless:
   ```bash
   grep -rn "yesterday\|last week\|today\|this morning\|ce matin\|hier\|la semaine dernière" "$MEMORY_DIR"/*.md
   ```
   These need conversion to absolute dates (YYYY-MM-DD).

5. **Memory type distribution**:
   - Count by frontmatter `type:` field (user, feedback, project, reference)
   - Files without frontmatter = "untyped" (flag for categorization)

6. **Optional: Infrastructure health** (with `--infra` flag):
   ```bash
   docker compose ps --format "{{.Name}}\t{{.Status}}" 2>/dev/null
   curl -s http://localhost:8001/health 2>/dev/null
   curl -s https://synapse.home.axoiq.com/api/v1/health 2>/dev/null
   df -h / | tail -1
   git status --short
   ```

7. **Output gather summary** — dashboard table:
   ```
   📊 Memory Gather Signal
   ┌──────────────┬────────┬────────┐
   │ Metric       │ Value  │ Status │
   ├──────────────┼────────┼────────┤
   │ Total files  │ {N}    │ ✅/⚠️  │
   │ MEMORY.md    │ {N}L   │ ✅/⚠️  │
   │ Orphans      │ {N}    │ ✅/🔴  │
   │ Stale (>14d) │ {N}    │ ✅/⚠️  │
   │ Feedback     │ {N}    │ ✅     │
   │ Duplicates   │ {N}    │ ✅/⚠️  │
   │ Rel. dates   │ {N}    │ ✅/⚠️  │
   └──────────────┴────────┴────────┘
   ```

If `--dry-run` or `report` subcommand: **STOP HERE**. Display report and exit.

## Phase 3 — Consolidate (HITL Required)

Make changes with explicit user approval at every step.

### Steps

1. **Merge duplicates** — for each pair flagged in Phase 2:
   - Show both file contents side by side via AskUserQuestion preview
   - Options: "Merge into file A", "Merge into file B", "Keep both", "Skip"
   - If merge approved: combine content, delete the other, update MEMORY.md references

2. **Normalize dates** — for each relative date found:
   - Show the line with context (file + line number)
   - Propose absolute date based on file modification date
   - Apply via Edit tool after approval

3. **Flag contradictions** — when two files say opposite things:
   - Show both statements
   - Ask which is current truth
   - Update/delete the stale one

4. **Categorize orphans** — for each file not in MEMORY.md:
   - Read first 10 lines to determine topic
   - Propose: add to MEMORY.md section, or archive (delete from index)
   - Use AskUserQuestion with file preview

5. **Type missing frontmatter** — for untyped memory files:
   - Suggest frontmatter (name, description, type) based on content
   - Apply if approved

## Phase 4 — Prune & Index

Regenerate MEMORY.md to be a clean, compact index.

### Steps

1. **Generate proposed MEMORY.md**:
   - Group files by category (use existing section structure or improve)
   - Use tables for compact representation (pattern from current MEMORY.md)
   - Each file = 1 line with status + pointer
   - Enforce 200-line hard limit (180-line soft target)

2. **Show proposed structure** via AskUserQuestion:
   - Preview the new MEMORY.md content
   - Options: "Write as-is", "Adjust before writing", "Cancel"

3. **Write MEMORY.md** if approved.

4. **Generate dream report**:
   Write `dream-report-{YYYY-MM-DD}.md` to memory dir with:
   ```markdown
   # Dream Report — {YYYY-MM-DD}

   ## Metrics
   | Metric | Before | After | Delta |
   |--------|--------|-------|-------|
   | MEMORY.md lines | {N} | {N} | {±N} |
   | Total files | {N} | {N} | {±N} |
   | Orphans | {N} | {N} | {±N} |
   | Duplicates resolved | — | {N} | — |
   | Dates normalized | — | {N} | — |
   | Contradictions resolved | — | {N} | — |

   ## Actions Taken
   - {list of changes made}

   ## Recommendations
   - {remaining issues for next dream}
   ```

5. **Release lock**: Remove `.consolidate-lock` if we created one.

## Schedule Mode

When invoked with `--schedule`:

```python
# Create a CronCreate job for recurring dreams
# Default: weekdays at 5:57 PM (off-minute to avoid load spikes)
# Session-only — dies when Claude exits
CronCreate(cron="57 17 * * 1-5", prompt="/atlas dream --dry-run", recurring=True)
```

Display the job ID and remind user that scheduled jobs are session-scoped (7-day max, dies on exit).

## Safety Rules

- **NEVER auto-delete** memory files. Always propose archive, never permanent delete.
- **NEVER write** without HITL approval (AskUserQuestion before every Write/Edit).
- **Lock protection**: Create `.consolidate-lock` at start, remove at end.
- **Backup MEMORY.md**: Read current content before overwriting. If write fails, restore.
- **Read-only on `--dry-run`**: Absolutely zero writes, only reporting.

## Model Strategy

| Phase | Model | Reason |
|-------|-------|--------|
| Phase 1 (Orient) | Sonnet | Simple scanning, counting |
| Phase 2 (Gather) | Sonnet | Pattern matching, classification |
| Phase 3 (Consolidate) | Opus | Merge decisions need deep understanding |
| Phase 4 (Prune) | Opus | Index design needs holistic view |
