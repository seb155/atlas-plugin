# Large File Strategy

> Rules and procedures for managing memory files exceeding 50KB.
> Auto-triggered in Phase 1 (Orient) when file size exceeds threshold.
> Manual trigger: `/atlas dream --split <file>`

---

## Thresholds

| Size | Classification | Action |
|------|---------------|--------|
| < 50KB | Normal | No action |
| 50-100KB | Large | Warning in Orient report. Split proposed in Phase 3.6 |
| > 100KB | Oversized | Must split. Blocks health score D6 at 0 |

Detection command:
```bash
du -k "$MEMORY_DIR"/*.md | awk '$1 > 50 {print $1 "KB\t" $2}' | sort -rn
```

---

## lessons.md Splitting (~88KB, ~800 lines)

### Step 1 — Analyze section structure

```bash
grep "^## " "$MEMORY_DIR/lessons.md"
```

### Step 2 — Proposed 5-way split by domain

| New File | Content Pattern | Est. Lines |
|----------|----------------|------------|
| `lessons-backend.md` | Toolkit, Backend, Session, API, CascadeEngine, Process Engine | ~250 |
| `lessons-frontend.md` | Frontend, React, V29, E2E Testing | ~80 |
| `lessons-infra.md` | Docker, CI, Infra, Gotchas (infra subset) | ~200 |
| `lessons-ai.md` | Claude Code, AI patterns | ~50 |
| `lessons-domain.md` | GMining, AUTOENG, THM-012, AML, SOW, BKL | ~220 |

### Step 3 — Frontmatter for each new file

```yaml
---
name: lessons-{domain}
description: "Lessons learned — {domain}. Split from lessons.md on YYYY-MM-DD HH:MM TZ."
type: reference
---
```

### Step 4 — Original becomes stub

After split, `lessons.md` becomes a ~20-line index stub:

```markdown
---
name: lessons
description: "Lessons learned — index. Split into domain files on YYYY-MM-DD HH:MM TZ."
type: reference
---

# Lessons Learned — Index

Split into domain-specific files for maintainability.

| Domain | File | Lines | Topics |
|--------|------|-------|--------|
| Backend | `lessons-backend.md` | ~250 | Toolkit, API, CascadeEngine |
| Frontend | `lessons-frontend.md` | ~80 | React, V29, E2E |
| Infrastructure | `lessons-infra.md` | ~200 | Docker, CI, Gotchas |
| AI/Claude | `lessons-ai.md` | ~50 | CC patterns, AI |
| Domain | `lessons-domain.md` | ~220 | GMining, THM-012, SOW |

*Original lessons.md split on YYYY-MM-DD HH:MM TZ. Total: ~800 entries.*
```

### Step 5 — HITL gate (H9)

Preview the split with line counts per file before executing:
```
Split lessons.md (88KB, 800 lines) into 5 files?
  lessons-backend.md   ~250 lines
  lessons-frontend.md  ~80 lines
  lessons-infra.md     ~200 lines
  lessons-ai.md        ~50 lines
  lessons-domain.md    ~220 lines
  lessons.md           ~20 lines (index stub)

[Split] / [Keep as-is] / [Custom split]
```

### Step 6 — Safety order (NON-NEGOTIABLE)

1. Create ALL new files FIRST (lessons-backend.md, etc.)
2. Verify all new files exist and have correct content
3. Update MEMORY.md to reference new files
4. LAST: Replace original lessons.md with index stub

Never modify the original before new files are confirmed written.

### Preserving cross-references

Lessons use `#NNN` numbering (e.g., Gotcha #287). The split MUST preserve:
- Original numbering within each domain file (do NOT renumber)
- A comment at top of each file: `<!-- Lesson numbers preserved from original lessons.md -->`
- If a lesson references another by number, add inline note: `(see lessons-infra.md #142)`

---

## session-log.md Archival (~60KB, ~750 lines)

### Step 1 — Determine cutoff date

Keep last 60 days of entries in `session-log.md`. Move older entries to archive.

```bash
cutoff=$(date -d "60 days ago" +%Y-%m-%d)
```

### Step 2 — Create archive file

Archive filename format: `session-log-archive-YYYY-Q.md`

```yaml
---
name: session-log-archive-2026-Q1
description: "Session log archive — 2026 Q1. Entries before YYYY-MM-DD."
type: reference
---
```

### Step 3 — Move entries

- Entries with dates before cutoff go to the archive file
- Archive files are **immutable** after creation (append-only during the dream that creates them)
- Each archive covers one quarter

### Step 4 — HITL gate

```
Archive N session-log entries before YYYY-MM-DD?
  → session-log-archive-2026-Q1.md (~400 lines)
  → session-log.md will keep ~350 lines (last 60 days)

[Archive] / [Keep all] / [Custom date]
```

### Step 5 — MEMORY.md update

Add reference to both active and archive files:
```markdown
| Session Log | Active log (last 60d) + archives | `session-log.md`, `session-log-archive-*.md` |
```

---

## General Rules for All Large Files

### What to split

- Files > 50KB with clear domain boundaries (section headers)
- Log/journal files that grow unbounded over time
- Reference files where sections are independently useful

### What NOT to split

- **Feedback files** (`feedback_*.md`) — atomic preferences, never split
- Files < 50KB — not worth the overhead
- Files without clear section boundaries
- MEMORY.md itself — use the existing prune mechanism instead

### Split execution rules

1. **Create new files FIRST** — always before modifying the original
2. **Update MEMORY.md SECOND** — reference all new files
3. **Modify original LAST** — replace with index stub
4. **Preserve cross-references** — numbering, links, section anchors
5. **Frontmatter required** — every new file gets `name`, `description`, `type`
6. **HITL gate required** — preview with line counts before every split
7. **Git-aware** — note current branch in case split needs reverting

### Health score impact

- 0 files > 50KB: D6 = 10 (perfect)
- 1 file > 50KB: D6 = 6 (warning)
- 2+ files > 50KB: D6 = 3 (poor)
- Any file > 100KB: D6 = 0 (must split)

---

*Reference: large-file-strategy | Skill: memory-dream v2 | Phase: 3.6*
