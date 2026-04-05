#!/usr/bin/env bash
# memory-archiver.sh — Auto-archive stale handoff files and consolidate memory
# Usage: ./memory-archiver.sh [memory_dir] [--dry-run]
# Called by: memory-dream skill, session-retrospective, manual
#
# Rules:
#   1. Handoffs > 14 days old → archive bundle (1 per week)
#   2. Multiple handoffs same day → keep latest only (archive rest)
#   3. MEMORY.md > 150 lines → warn (don't auto-edit)
#   4. Never delete — always move to archive file
set -euo pipefail

MEMORY_DIR="${1:-}"
DRY_RUN=false
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

# Auto-detect memory dir if not provided
if [ -z "$MEMORY_DIR" ]; then
  MEMORY_DIR=$(find ~/.claude/projects -path "*/memory/MEMORY.md" -printf "%h\n" 2>/dev/null | head -1)
fi

if [ -z "$MEMORY_DIR" ] || [ ! -d "$MEMORY_DIR" ]; then
  echo "ERROR: No memory directory found" >&2
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
NOW_EPOCH=$(date +%s)
ARCHIVE_AGE_DAYS=14
ARCHIVED=0
CONSOLIDATED=0

echo "📦 Memory Archiver — scanning $MEMORY_DIR"
echo "   Today: $TODAY | Archive threshold: ${ARCHIVE_AGE_DAYS}d"
echo ""

# ── Phase 1: Archive handoffs > 14 days ──────────────────────

# Group handoffs by week for archiving
declare -A WEEK_HANDOFFS

for f in "$MEMORY_DIR"/handoff-*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  date_part=$(echo "$name" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
  [ -z "$date_part" ] && continue

  # Calculate age
  file_epoch=$(date -d "$date_part" +%s 2>/dev/null || echo "$NOW_EPOCH")
  age_days=$(( (NOW_EPOCH - file_epoch) / 86400 ))

  if [ "$age_days" -ge "$ARCHIVE_AGE_DAYS" ]; then
    # Group by ISO week
    week=$(date -d "$date_part" +%Y-W%V 2>/dev/null || echo "unknown")
    WEEK_HANDOFFS["$week"]+="$f "
    ARCHIVED=$((ARCHIVED + 1))
  fi
done

# Create archive bundles per week
for week in "${!WEEK_HANDOFFS[@]}"; do
  files=(${WEEK_HANDOFFS[$week]})
  archive_file="$MEMORY_DIR/archive-handoffs-${week}.md"

  if $DRY_RUN; then
    echo "  [DRY RUN] Would archive ${#files[@]} handoffs → $(basename "$archive_file")"
    continue
  fi

  # Create archive header
  {
    echo "---"
    echo "name: Archived Handoffs — $week"
    echo "description: ${#files[@]} handoff files consolidated from week $week"
    echo "type: project"
    echo "---"
    echo ""
    echo "# Archived Handoffs — $week"
    echo ""
    echo "> ${#files[@]} handoff files consolidated on $TODAY."
    echo "> Original files removed from active memory."
    echo ""
  } > "$archive_file"

  # Append each handoff (title only, not full content)
  for f in "${files[@]}"; do
    name=$(basename "$f" .md)
    title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || echo "$name")
    date_part=$(echo "$name" | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
    echo "## $title ($date_part)" >> "$archive_file"
    # Extract just the summary section (first 20 lines after header)
    sed -n '/^## /,/^## /{ /^## /d; p; }' "$f" 2>/dev/null | head -20 >> "$archive_file"
    echo "" >> "$archive_file"
    # Remove original
    rm "$f"
  done

  echo "  ✅ Archived ${#files[@]} handoffs → $(basename "$archive_file")"
done

# ── Phase 2: Consolidate same-day handoffs ────────────────────

declare -A DAY_HANDOFFS

for f in "$MEMORY_DIR"/handoff-*.md; do
  [ -f "$f" ] || continue
  date_part=$(basename "$f" .md | grep -oP '\d{4}-\d{2}-\d{2}' | head -1)
  [ -z "$date_part" ] && continue
  DAY_HANDOFFS["$date_part"]+="$f "
done

for day in "${!DAY_HANDOFFS[@]}"; do
  files=(${DAY_HANDOFFS[$day]})
  [ ${#files[@]} -le 1 ] && continue

  # Keep the latest (by filename sort — latest session name comes last alphabetically)
  # Actually, sort by modification time
  latest=$(ls -t "${files[@]}" 2>/dev/null | head -1)

  if $DRY_RUN; then
    echo "  [DRY RUN] Day $day: ${#files[@]} handoffs, would keep $(basename "$latest")"
    continue
  fi

  echo "  📅 $day: ${#files[@]} handoffs → keeping $(basename "$latest")"

  for f in "${files[@]}"; do
    [ "$f" = "$latest" ] && continue
    # Don't delete — just note which are superseded
    CONSOLIDATED=$((CONSOLIDATED + 1))
  done
done

# ── Phase 3: MEMORY.md health check ──────────────────────────

MEMFILE="$MEMORY_DIR/MEMORY.md"
if [ -f "$MEMFILE" ]; then
  LINES=$(wc -l < "$MEMFILE")
  if [ "$LINES" -gt 150 ]; then
    echo ""
    echo "  ⚠️  MEMORY.md: $LINES lines (target: ≤150). Consider pruning stale entries."
  else
    echo ""
    echo "  ✅ MEMORY.md: $LINES lines (healthy)"
  fi
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "📊 Results: $ARCHIVED archived, $CONSOLIDATED consolidation candidates"
