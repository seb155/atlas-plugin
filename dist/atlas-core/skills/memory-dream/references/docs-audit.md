# Phase 1.5 — Docs & Ecosystem Audit

> Reference for the `memory-dream` skill. Runs with `--deep` (always) or standalone via `--docs`.
> Scans the entire documentation ecosystem, not just `memory/`.

---

## Overview

Phase 1.5 audits 6 sources beyond memory files to detect staleness, orphans, broken links, version drift, and claim inaccuracies across the full project documentation surface.

| Step | Source | What | Gate |
|------|--------|------|------|
| D1 | `.blueprint/` | Orphan docs, INDEX.md integrity, staleness | — |
| D2 | `.blueprint/plans/` | Plan health, mega plan links, age | — |
| D3 | `.blueprint/handoffs/` | Insight extraction, lessons.md gaps | H1 |
| D4 | `FEATURES.md` | Feature count sync, tier drift | H2 |
| D5 | ATLAS plugin | Version, skills, agents, commands count | — |
| D6 | Tech stack (`--tech`) | Versions, ports, IPs, Docker state | — |

---

## D1 — .blueprint/ Audit

### Purpose

Verify INDEX.md is accurate, detect orphan docs, flag stale files.

### Steps

1. **Count files**:
```bash
find .blueprint -name "*.md" | wc -l
```

2. **Read INDEX.md** and extract all referenced file paths:
```bash
grep -oP '`[^`]*\.md`' .blueprint/INDEX.md | tr -d '`' | sort -u > /tmp/dream-index-refs.txt
```

3. **Verify each referenced file exists**:
```bash
while IFS= read -r f; do
  [ -f ".blueprint/$f" ] || [ -f "$f" ] || echo "MISSING: $f"
done < /tmp/dream-index-refs.txt
```

4. **Detect orphan docs** (in `.blueprint/` but NOT in INDEX.md):
```bash
find .blueprint -maxdepth 1 -name "*.md" ! -name "INDEX.md" -printf "%f\n" | sort > /tmp/dream-actual.txt
comm -23 /tmp/dream-actual.txt /tmp/dream-index-refs.txt
```

5. **Staleness check** (files > 30 days without modification):
```bash
find .blueprint -name "*.md" -mtime +30 -printf "%f\t%T+\n" | sort -t$'\t' -k2
```

### Output Template

```
D1 — .blueprint/ Audit
┌────────────────────┬───────┬────────┬────────────────────────────┐
│ Metric             │ Count │ Status │ Detail                     │
├────────────────────┼───────┼────────┼────────────────────────────┤
│ Total files        │ {N}   │ —      │                            │
│ INDEX.md refs      │ {N}   │ —      │                            │
│ Missing refs       │ {N}   │ ✅/⚠️  │ {list if > 0}              │
│ Orphan docs        │ {N}   │ ✅/⚠️  │ {list if > 0}              │
│ Stale (>30d)       │ {N}   │ ✅/⚠️  │ {count} files not updated  │
│ INDEX.md age       │ {N}d  │ ✅/⚠️  │ Last modified: {date}      │
└────────────────────┴───────┴────────┴────────────────────────────┘
```

### Scoring (feeds D9 — Docs Freshness)
- 10: 0 orphans, 0 missing refs, INDEX.md < 14 days old
- 7-9: < 3 orphans OR INDEX.md 14-30 days old
- 4-6: 3-10 orphans OR > 5 missing refs
- 0-3: > 10 orphans AND > 10 missing refs AND INDEX.md > 60 days

---

## D2 — Plans Audit

### Purpose

Verify plan health: existence, MEMORY.md links, mega plan bidirectional refs, age.

### Steps

1. **List all plans**:
```bash
find .blueprint/plans -name "*.md" -printf "%f\t%T+\n" | sort -t$'\t' -k2r
```

2. **Verify MEMORY.md references**:
```bash
# Extract plan names referenced in MEMORY.md
grep -oP '[a-z]+-[a-z]+-[a-z]+\.md' memory/MEMORY.md | sort -u > /tmp/dream-memory-plans.txt

# Compare with actual plans
ls .blueprint/plans/*.md | xargs -n1 basename | sort > /tmp/dream-actual-plans.txt

# Plans in memory but missing from disk
comm -23 /tmp/dream-memory-plans.txt /tmp/dream-actual-plans.txt

# Plans on disk but not in memory
comm -13 /tmp/dream-memory-plans.txt /tmp/dream-actual-plans.txt
```

3. **Mega plan bidirectional check**:
```bash
# Find the mega plan (usually the largest or explicitly named)
MEGA=$(ls -S .blueprint/plans/*.md | head -1)

# Extract sub-plan references from mega plan
grep -oP 'sp\d+-[a-z-]+\.md' "$MEGA" | sort -u > /tmp/dream-mega-refs.txt

# For each sub-plan, verify it back-references the mega plan
for sp in $(cat /tmp/dream-mega-refs.txt); do
  SPF=".blueprint/plans/$sp"
  [ -f "$SPF" ] && grep -q "$(basename $MEGA .md)" "$SPF" || echo "NO BACKLINK: $sp"
done
```

4. **Flag old plans** (> 6 months without update):
```bash
find .blueprint/plans -name "*.md" -mtime +180 -printf "OLD: %f (%Td/%Tm/%TY)\n"
```

### Output Template

```
D2 — Plans Audit
┌────────────────────┬───────┬────────┬────────────────────────────┐
│ Metric             │ Count │ Status │ Detail                     │
├────────────────────┼───────┼────────┼────────────────────────────┤
│ Total plans        │ {N}   │ —      │                            │
│ In MEMORY.md       │ {N}   │ —      │                            │
│ Dead refs (memory) │ {N}   │ ✅/⚠️  │ Plans in memory, not disk  │
│ Unlinked plans     │ {N}   │ ✅/⚠️  │ On disk, not in memory     │
│ Mega→sub links     │ {N}   │ ✅/⚠️  │ Bidirectional check        │
│ Old (>6mo)         │ {N}   │ ✅/⚠️  │ Plans without recent edits │
└────────────────────┴───────┴────────┴────────────────────────────┘
```

---

## D3 — Handoffs Ingestion

### Purpose

Extract actionable insights from recent handoffs that are not yet captured in memory files or lessons.md.

### Steps

1. **Scan handoff files**:
```bash
find .blueprint/handoffs -name "handoff-*.md" -printf "%f\t%T+\n" | sort -t$'\t' -k2r
```

2. **Identify recent handoffs** (< 7 days):
```bash
find .blueprint/handoffs -name "handoff-*.md" -mtime -7 -printf "%f\n"
```

3. **Extract KEY DECISIONS** from each recent handoff:
```bash
for f in $(find .blueprint/handoffs -name "handoff-*.md" -mtime -7); do
  echo "=== $(basename $f) ==="
  sed -n '/KEY DECISIONS/,/^##/p' "$f" | head -20
done
```

4. **Extract GOTCHAS / dead-ends**:
```bash
for f in $(find .blueprint/handoffs -name "handoff-*.md" -mtime -7); do
  echo "=== $(basename $f) ==="
  sed -n '/GOTCHA\|DEAD.END\|BLOCKER\|WARNING/,/^##/p' "$f" | head -20
done
```

5. **Extract QUICK START commands**:
```bash
for f in $(find .blueprint/handoffs -name "handoff-*.md" -mtime -7); do
  echo "=== $(basename $f) ==="
  sed -n '/QUICK START\|TO RESUME/,/^##/p' "$f" | head -20
done
```

6. **Cross-reference gotchas vs lessons.md**:
   - Read `memory/lessons.md` (or the numbered lessons entries)
   - For each gotcha extracted from handoffs, fuzzy-match against existing lessons
   - Unmatched gotchas = uncaptured insights

7. **Identify unsynced insights**:
   - Decisions in handoffs but not in `decisions.jsonl`
   - Gotchas in handoffs but not in `lessons.md`
   - New patterns / architectures not yet in any memory file

### Output Template

```
D3 — Handoffs Ingestion
Recent handoffs (< 7d): {N}

Unsynced Insights:
┌────┬─────────────────────┬──────────────────┬────────────────────┬────────┐
│ #  │ Insight             │ Source Handoff    │ Missing From       │ Action │
├────┼─────────────────────┼──────────────────┼────────────────────┼────────┤
│ 1  │ {decision/gotcha}   │ handoff-XXXX.md  │ lessons.md         │ HITL   │
│ 2  │ {pattern}           │ handoff-XXXX.md  │ memory/{topic}.md  │ HITL   │
└────┴─────────────────────┴──────────────────┴────────────────────┴────────┘
```

### HITL Gate H1

For each unsynced insight, present to user via AskUserQuestion:
- "Create memory file `{topic}.md` from handoff insight?"
- "Add lesson #{NNN} to lessons.md?"
- Options: Create / Skip / Defer

---

## D4 — FEATURES.md Sync

### Purpose

Verify that FEATURES.md counts match MEMORY.md claims, detect tier drift.

### Steps

1. **Count features by DoD tier**:
```bash
# Count features per tier in FEATURES.md
grep -c 'CODED' .blueprint/FEATURES.md
grep -c 'VALIDATING' .blueprint/FEATURES.md
grep -c 'VALIDATED' .blueprint/FEATURES.md
grep -c 'SHIPPED' .blueprint/FEATURES.md
```

2. **Total feature count**:
```bash
grep -cP '^\|.*FEAT-' .blueprint/FEATURES.md
```

3. **Compare with MEMORY.md claims**:
   - Read MEMORY.md, find lines like "96 features tracked" or "45% DONE"
   - Compare with actual counts from step 1-2
   - Flag discrepancies

4. **Detect SHIPPED features still in ACTIVE WORK**:
   - Extract feature IDs marked SHIPPED in FEATURES.md
   - Search MEMORY.md ACTIVE WORK table for those same IDs or names
   - Flag any matches (should have been removed from ACTIVE WORK)

### Output Template

```
D4 — FEATURES.md Sync
┌─────────────────────┬─────────┬──────────┬────────┐
│ Metric              │ Memory  │ Actual   │ Match  │
├─────────────────────┼─────────┼──────────┼────────┤
│ Total features      │ {N}     │ {N}      │ ✅/⚠️  │
│ CODED               │ —       │ {N}      │ —      │
│ VALIDATING          │ —       │ {N}      │ —      │
│ VALIDATED           │ —       │ {N}      │ —      │
│ SHIPPED             │ —       │ {N}      │ —      │
│ "X% DONE" claim     │ {X}%    │ {Y}%     │ ✅/⚠️  │
│ SHIPPED in ACTIVE   │ —       │ {N}      │ ✅/⚠️  │
└─────────────────────┴─────────┴──────────┴────────┘
```

### HITL Gate H2

If discrepancies found:
- "Update MEMORY.md feature count from {old} to {new}?"
- "Remove {N} SHIPPED features from ACTIVE WORK table?"

---

## D5 — ATLAS Plugin State

### Purpose

Verify plugin version, skill/agent/command counts match memory claims.

### Steps

1. **Read current version**:
```bash
# From plugin.json (if available)
cat atlas-dev-plugin/plugin.json 2>/dev/null | grep -oP '"version":\s*"\K[^"]+'

# Or from git tags
cd atlas-dev-plugin && git describe --tags --abbrev=0 2>/dev/null
```

2. **Compare with MEMORY.md version**:
   - Extract version string from MEMORY.md (e.g., "v3.23.0")
   - Compare with actual version from step 1

3. **Count skills, agents, commands**:
```bash
# Skills
ls -d atlas-dev-plugin/skills/*/SKILL.md 2>/dev/null | wc -l

# Agents (if in separate dir)
ls -d atlas-dev-plugin/agents/*/AGENT.md 2>/dev/null | wc -l

# Commands
ls atlas-dev-plugin/commands/*.md 2>/dev/null | wc -l
```

4. **Detect removed skills** referenced in memory:
   - Extract skill names from MEMORY.md
   - Check each against `atlas-dev-plugin/skills/`
   - Flag any that no longer exist

### Output Template

```
D5 — ATLAS Plugin State
┌─────────────────────┬─────────┬──────────┬────────┐
│ Metric              │ Memory  │ Actual   │ Match  │
├─────────────────────┼─────────┼──────────┼────────┤
│ Plugin version      │ {v}     │ {v}      │ ✅/⚠️  │
│ Skills count        │ {N}     │ {N}      │ ✅/⚠️  │
│ Agents count        │ {N}     │ {N}      │ ✅/⚠️  │
│ Commands count      │ {N}     │ {N}      │ ✅/⚠️  │
│ Removed skills      │ —       │ {N}      │ ✅/⚠️  │
└─────────────────────┴─────────┴──────────┴────────┘
```

---

## D6 — Technical State Validation (`--tech`)

### Purpose

Verify that stack versions, ports, IPs, Docker state, and infrastructure claims in memory files match current reality. Technical claims have the highest staleness risk.

### Steps

1. **Stack versions**:
```bash
echo "=== Stack Versions ==="
echo "Python: $(python3 --version 2>&1 | awk '{print $2}')"
echo "Bun: $(bun --version 2>/dev/null || echo 'N/A')"
echo "Node: $(node --version 2>/dev/null || echo 'N/A')"
echo "PostgreSQL: $(psql --version 2>/dev/null | awk '{print $3}' || echo 'N/A')"
echo "Docker: $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo 'N/A')"
```

2. **Docker state**:
```bash
echo "=== Docker Containers ==="
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
echo "Total: $(docker compose ps -q 2>/dev/null | wc -l)"
```

3. **Port mapping**:
```bash
echo "=== Listening Ports ==="
ss -tlnp 2>/dev/null | grep -E '(5433|8001|4000|3000|8080)' || echo "No matching ports"
```

4. **IP / hostname verification**:
```bash
echo "=== Network ==="
echo "Hostname: $(hostname)"
# Verify IPs mentioned in memory are resolvable
for ip in 192.168.10.75; do
  ping -c1 -W2 "$ip" >/dev/null 2>&1 && echo "$ip: reachable" || echo "$ip: UNREACHABLE"
done
```

5. **Compare with memory claims**:
   - Extract all version/port/IP claims from memory files
   - Compare each with the actual values from steps 1-4
   - Flag mismatches

### Output Template

```
D6 — Tech Claims vs Reality
┌──────────────────────────┬───────────┬───────────┬────────┐
│ Claim                    │ Memory    │ Actual    │ Match  │
├──────────────────────────┼───────────┼───────────┼────────┤
│ Python version           │ 3.13      │ {actual}  │ ✅/⚠️  │
│ Bun version              │ —         │ {actual}  │ —      │
│ PostgreSQL version       │ 17        │ {actual}  │ ✅/⚠️  │
│ Plugin version           │ v3.23.0   │ {actual}  │ ✅/⚠️  │
│ Docker containers        │ {N}       │ {N}       │ ✅/⚠️  │
│ Backend port             │ 8001      │ {actual}  │ ✅/⚠️  │
│ Frontend port            │ 4000      │ {actual}  │ ✅/⚠️  │
│ DB port                  │ 5433      │ {actual}  │ ✅/⚠️  │
│ Forgejo IP               │ .10.75    │ {actual}  │ ✅/⚠️  │
│ Hostname                 │ {claim}   │ {actual}  │ ✅/⚠️  │
└──────────────────────────┴───────────┴───────────┴────────┘
```

### Scoring (feeds D10 — Tech Accuracy)
- 10: All claims match reality
- 7-9: 1-2 minor version mismatches (e.g., 3.13 vs 3.13.2)
- 4-6: 1-2 major mismatches (wrong port, dead IP)
- 0-3: > 3 major mismatches or critical claims wrong

---

## Aggregate Output

After all 6 steps, produce the ecosystem summary:

```
📊 Ecosystem Audit — 📅 YYYY-MM-DD HH:MM TZ
┌──────────────────────┬───────┬────────┬────────┐
│ Source               │ Files │ Stale  │ Status │
├──────────────────────┼───────┼────────┼────────┤
│ .blueprint/          │ {N}   │ {N}    │ ✅/⚠️  │
│ .blueprint/plans/    │ {N}   │ {N}    │ ✅/⚠️  │
│ .blueprint/handoffs/ │ {N}   │ {N}    │ ✅/⚠️  │
│ FEATURES.md          │ {N}   │ {N}    │ ✅/⚠️  │
│ ATLAS plugin         │ {ver} │ —      │ ✅/⚠️  │
│ Tech stack           │ —     │ {N}    │ ✅/⚠️  │
└──────────────────────┴───────┴────────┴────────┘
```

This table feeds into the Health Dashboard (dimensions D9 Docs Freshness and D10 Tech Accuracy).

---

## Invocation Modes

| Command | Steps Run | Time |
|---------|-----------|------|
| `/atlas dream --docs` | D1-D5 | ~3 min |
| `/atlas dream --tech` | D6 only | ~2 min |
| `/atlas dream --docs --tech` | D1-D6 | ~5 min |
| `/atlas dream --deep` | D1-D6 (as part of full cycle) | included |

---

## Safety Rules

1. **Read-only** — Phase 1.5 never writes files. All fixes happen in Phase 3/3.5 with HITL gates.
2. **No /tmp persistence** — temp files used for `comm`/`sort` are ephemeral, never persisted.
3. **Branch awareness** — A missing file may exist on another branch. Note git context before flagging.
4. **Feedback immutability** — Never flag `feedback_*.md` files as orphans or suggest deletion.
5. **Timestamps** — All output headers include `HH:MM TZ`, never date alone.

---

*Reference: docs-audit.md | Phase: 1.5 | Plan: humming-brewing-melody | Updated: 2026-03-25*
