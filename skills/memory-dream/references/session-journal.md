# Phase 3.5 — Session Journal & Handoff Synthesis

> Reference for the `memory-dream` skill. Runs within `--deep` cycle or standalone via `/atlas dream journal`.
> Captures live session insights and creates bidirectional flow between handoffs and memory.

---

## Overview

Phase 3.5 bridges the gap between ephemeral session context and persistent memory. It captures decisions, blockers, and insights from the current conversation, and integrates recent handoff signals into memory files.

| Step | What | Gate | Standalone |
|------|------|------|------------|
| J1 | Session journal entry format | H13 | Yes (`/atlas dream journal`) |
| J2 | Handoff signal extraction | H12 | Yes (`--handoffs`) |
| J3 | Handoff → Memory sync | H12 | With `--handoffs` |
| J4 | Session → Handoff feed | — | Auto (in dream report v2) |

---

## J1 — Session Journal Entry Format

### Purpose

Generate a structured summary of the current session. Captures wins, blockers, decisions, technical insights, and open questions in a scannable format.

### Entry Template

```markdown
## Session Journal — 📅 YYYY-MM-DD HH:MM TZ

### ✅ What Went Well
- {wins, problems solved, insights}
- {features completed, tests passing}
- {architecture decisions validated}

### ⚠️ What Blocked / Pivots
- {errors encountered, dead-ends hit}
- {direction changes mid-session}
- {external blockers: infra, access, data}

### 📋 Key Decisions
| # | Decision | Why | Alternative Rejected |
|---|----------|-----|----------------------|
| 1 | {what was decided} | {reasoning} | {what was NOT chosen} |
| 2 | ... | ... | ... |

### 🔧 Technical Insights
- {patterns discovered, reusable approaches}
- {gotchas found, performance observations}
- {library/tool quirks worth remembering}

### ❓ Open Questions
- {unresolved questions, topics to investigate}
- {decisions deferred to next session}
- {areas needing HITL input}

### ⚡ Energy & Flow (v4 — experiential context)
- **Energy level**: {1-5} ({source: inferred from signals / explicit from user})
- **Time quality**: {deep | focused | fragmented | interrupted | recovery}
- **Flow achieved**: {yes / no / partial}
- **Energy arc**: {steady | rising | declining | peak-then-crash}

### 🎭 Emotional Context (v4 — experiential context)
- **Mood**: {primary mood: focused, frustrated, curious, elated, calm, anxious, determined}
- **Decision confidence**: {high / medium / low} — average across session decisions
- **Notable emotional transitions**: {e.g., "frustrated → relieved after fixing VLAN issue"}
```

> **v4 Note**: The Energy & Flow and Emotional Context sections are auto-populated
> from accumulated signals in `~/.claude/atlas-experiential-signals.json`. They can
> also be manually edited during the H13 gate review. These sections are OPTIONAL —
> omit if no experiential data is available.

### How to Populate

The agent synthesizes the journal entry from the conversation context:
1. Scan conversation for tool calls that succeeded (wins) vs failed (blockers)
2. Identify explicit decisions (architecture choices, pattern selections)
3. Extract technical observations (error messages resolved, workarounds found)
4. Collect unresolved threads (questions asked but not answered, deferred items)

### Rules
- Every entry MUST include `📅 YYYY-MM-DD HH:MM TZ` (never date alone)
- If timestamp unavailable: `date '+%Y-%m-%d %H:%M %Z'` via Bash
- Key Decisions table = minimum 1 row (even if trivial)
- Open Questions = honest about unknowns (no fake completeness)

---

## J2 — Handoff Signal Extraction

### Purpose

Extract actionable insights from recent handoffs (< 7 days) and cross-reference with existing memory to find uncaptured knowledge.

### Steps

1. **Find recent handoffs**:
```bash
find .blueprint/handoffs -name "handoff-*.md" -mtime -7 -printf "%f\t%T+\n" | sort -t$'\t' -k2r
```

2. **Extract KEY DECISIONS** from each:
```bash
for f in $(find .blueprint/handoffs -name "handoff-*.md" -mtime -7); do
  echo "=== $(basename $f) ==="
  # Extract content between KEY DECISIONS header and next ## header
  sed -n '/^##.*KEY DECISIONS\|^##.*Key Decisions/,/^##[^#]/p' "$f" | sed '$d'
done
```

3. **Cross-reference with decisions.jsonl**:
   - Read `.claude/decisions.jsonl` (if exists)
   - For each decision extracted from handoffs, check if already logged
   - Unmatched decisions = uncaptured

4. **Extract GOTCHAS**:
```bash
for f in $(find .blueprint/handoffs -name "handoff-*.md" -mtime -7); do
  echo "=== $(basename $f) ==="
  sed -n '/GOTCHA\|DEAD.END\|BLOCKER\|WARNING\|PITFALL/,/^##[^#]/p' "$f" | sed '$d'
done
```

5. **Cross-reference with lessons.md**:
   - Read `memory/lessons.md` (numbered entries #NNN)
   - For each gotcha from handoffs, fuzzy-match against existing lessons
   - Score match confidence: exact (>90%), partial (50-90%), none (<50%)
   - Unmatched gotchas with confidence < 50% = uncaptured insights

6. **Extract QUICK START commands**:
```bash
for f in $(find .blueprint/handoffs -name "handoff-*.md" -mtime -7); do
  echo "=== $(basename $f) ==="
  sed -n '/QUICK START\|TO RESUME\|RESUME HERE/,/^##[^#]/p' "$f" | sed '$d'
done
```

7. **Verify QUICK START commands still work**:
   - For each command extracted, check if referenced files/paths exist
   - For Docker commands: verify containers are running
   - For test commands: verify test files exist
   - Do NOT execute destructive commands — verify paths only

### Output Template

```
J2 — Handoff Signal Extraction
Recent handoffs (< 7d): {N}

Uncaptured Insights:
┌────┬─────────────────────────┬──────────────────┬────────────────────┬────────┐
│ #  │ Insight                 │ Source Handoff    │ Missing From       │ Action │
├────┼─────────────────────────┼──────────────────┼────────────────────┼────────┤
│ 1  │ {decision description}  │ handoff-XXXX.md  │ decisions.jsonl    │ HITL   │
│ 2  │ {gotcha description}    │ handoff-XXXX.md  │ lessons.md         │ HITL   │
│ 3  │ {pattern/architecture}  │ handoff-XXXX.md  │ memory/{topic}.md  │ HITL   │
└────┴─────────────────────────┴──────────────────┴────────────────────┴────────┘

Stale QUICK START Commands:
│ Handoff          │ Command                        │ Issue              │
│ handoff-XXXX.md  │ docker exec synapse-backend ... │ Container not running │
```

---

## J3 — Handoff → Memory Sync

### Purpose

For each uncaptured insight identified in J2, propose creating or updating memory files with HITL approval.

### Process

1. **For each uncaptured insight** from J2:
   - Determine target: new memory file or append to existing
   - If new file: generate filename following convention (`{topic}.md`)
   - If append: identify target file and section

2. **HITL Gate H12** — Present each insight via AskUserQuestion:
```
Uncaptured insight from handoff-2026-03-24-sso.md:
  "Authentik embedded outpost requires token endpoint override"

Options:
  A) Create memory file: feedback_outpost_token_endpoint_bug.md
  B) Add to existing: lessons.md as lesson #XXX
  C) Skip (already known, not worth persisting)
  D) Defer to next dream cycle
```

3. **If approved (A)**:
   - Create memory file with frontmatter:
```markdown
# {Topic Title}

> Source: handoff-XXXX.md (📅 YYYY-MM-DD)
> Category: feedback | lesson | reference

{Extracted insight content, reformatted for standalone readability}

---
*Synced from handoff by dream Phase 3.5 — 📅 YYYY-MM-DD HH:MM TZ*
```
   - Update MEMORY.md index (add to appropriate section)

4. **If approved (B)**:
   - Append numbered lesson to lessons.md
   - Follow existing numbering convention (#NNN)

### Safety
- NEVER auto-create files without HITL gate
- NEVER modify handoff files (read-only source)
- NEVER duplicate content already in memory (check before proposing)

---

## J4 — Session → Handoff Feed

### Purpose

The dream report v2 includes a "Handoff Context" section that enriches the next `/a-handoff` invocation with consolidated intelligence.

### Handoff Context Section (appended to dream report v2)

```markdown
## Handoff Context — 📅 YYYY-MM-DD HH:MM TZ

### Health Snapshot
- Score: {X.X}/10 (Grade: {A-F})
- Trend: {↗️ ↘️ →} vs last dream
- Critical dimensions: {list any < 5.0}

### Modified During Dream
- {list of files created/modified/archived during this dream cycle}

### Recommendations for Next Session
1. {highest-priority fix from dream findings}
2. {second priority}
3. {third priority}

### Tech State (if --tech ran)
- Stack: Python {v}, Bun {v}, PG {v}
- Docker: {N} containers, all healthy / {N} unhealthy
- Ports: {list verified ports}

### Open Items Carried Forward
- {from session journal Open Questions}
- {unresolved contradictions from dream}
```

### How This Feeds /a-handoff

When `/a-handoff` runs after a dream cycle:
1. It reads the dream report (including Handoff Context)
2. Health snapshot goes into the handoff's "Current State" section
3. Recommendations become the handoff's "Priority for Next Session"
4. Tech state snapshot becomes the handoff's infrastructure context

---

## Standalone Subcommand: `/atlas dream journal`

### Purpose

Mid-session journal capture without running the full dream cycle. Quick way to persist session context.

### Behavior

1. **Generate journal entry** (J1 format) from current conversation
2. **HITL Gate H13** — Preview before write:
```
Session Journal Preview:
─────────────────────────
## Session Journal — 📅 2026-03-25 17:38 EDT

### ✅ What Went Well
- Memory dream v2 plan scored 15/15
- 7 reference files designed in single session

### ⚠️ What Blocked / Pivots
- Initial 8D health scoring expanded to 10D after feedback

### 📋 Key Decisions
| # | Decision | Why | Alternative Rejected |
|---|----------|-----|----------------------|
| 1 | 10D health scoring | Docs + tech accuracy gaps | 8D (insufficient) |

### 🔧 Technical Insights
- dream-history.jsonl append-only = safe trend tracking

### ❓ Open Questions
- Optimal dream frequency? Weekly? Sprint-end?
─────────────────────────

Write to session-log.md? [Yes / Edit / Skip]
```

3. **If approved**: Append to `session-log.md` with format:
```
📅 YYYY-MM-DD HH:MM TZ — {1-line summary}
```
   Followed by the full journal entry.

4. **If "Edit"**: Let user modify via AskUserQuestion, then write.

### Rules
- Can be invoked MULTIPLE TIMES per session (appends, never overwrites)
- All timestamps include `HH:MM` (never date alone)
- Journal entries are append-only to session-log.md
- No other files are modified (no MEMORY.md changes, no memory file creation)
- If session-log.md does not exist, create it with a header line first

---

## Handoff ↔ Dream Bidirectional Flow

```
┌─────────────────────┐
│   /a-handoff        │
│   (end of session)  │
│   writes handoff    │
│   file              │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  .blueprint/        │
│  handoffs/          │
│  handoff-*.md       │
│  (persistent store) │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐     ┌─────────────────────┐
│  /atlas dream       │     │  Phase 3.5 — J2      │
│  --deep             │────▶│  Extract signals:    │
│  Phase 1.5 — D3     │     │  decisions, gotchas, │
│  scans handoffs     │     │  quick-start cmds    │
└─────────────────────┘     └─────────┬───────────┘
                                      │
                                      ▼
                            ┌─────────────────────┐
                            │  Phase 3.5 — J3      │
                            │  HITL: create        │
                            │  memory files from   │
                            │  uncaptured insights │
                            └─────────┬───────────┘
                                      │
                                      ▼
                            ┌─────────────────────┐
                            │  Dream Report v2     │
                            │  includes "Handoff   │
                            │  Context" section    │
                            └─────────┬───────────┘
                                      │
                                      ▼
                            ┌─────────────────────┐
                            │  Next /a-handoff     │
                            │  reads dream report  │
                            │  → enriched handoff  │
                            │  with health score,  │
                            │  tech snapshot,      │
                            │  recommendations     │
                            └─────────────────────┘
```

**Cycle**: Handoff → Dream ingestion → Memory files → Dream Report → next Handoff (enriched)

Each iteration improves context quality: handoffs capture ephemeral session knowledge, dream consolidates it into persistent memory, and the enriched dream report makes the next handoff more valuable.

---

## Invocation Modes

| Command | Steps Run | Time | Use Case |
|---------|-----------|------|----------|
| `/atlas dream journal` | J1 only | ~2 min | Mid-session capture |
| `/atlas dream --handoffs` | J2 + J3 | ~3 min | Post-handoff sync |
| `/atlas dream --deep` | J1-J4 (full cycle) | included | Sprint-end deep clean |

---

## Safety Rules

1. **HITL mandatory** — Journal write (H13) and memory file creation (H12) always require approval
2. **Append-only** — Session journal entries are appended, never overwrite existing content
3. **Handoffs read-only** — NEVER modify `.blueprint/handoffs/` files
4. **No auto-create** — Memory files from handoff insights require explicit HITL approval
5. **Timestamps** — Every entry uses `📅 YYYY-MM-DD HH:MM TZ`, never date alone
6. **Feedback immutability** — Never suggest modifying `feedback_*.md` even if handoff contradicts them
7. **Max 2 retries** — If extraction fails twice, escalate via AskUserQuestion

---

*Reference: session-journal.md | Phase: 3.5 | Plan: humming-brewing-melody | Updated: 2026-03-27 (v4: experiential sections added)*
