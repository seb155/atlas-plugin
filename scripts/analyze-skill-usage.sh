#!/usr/bin/env bash
# analyze-skill-usage.sh — Analyze skill invocation data from skill-usage-tracker hook
# Usage: atlas plugin usage [--days N] [--json]
set -euo pipefail

USAGE_FILE="${HOME}/.atlas/skill-usage.jsonl"
DAYS="${1:-30}"
JSON="${2:-}"

if [ ! -f "$USAGE_FILE" ]; then
  echo "📊 No skill usage data yet."
  echo "   The skill-usage-tracker hook collects data on each /skill invocation."
  echo "   Use Claude Code normally for a few days, then re-run."
  exit 0
fi

TOTAL=$(wc -l < "$USAGE_FILE")
CUTOFF=$(date -d "-${DAYS} days" -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -v-${DAYS}d -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)
RECENT=$(awk -v cutoff="$CUTOFF" -F'"' '{for(i=1;i<=NF;i++) if($(i-1)~/:$/ && $i=="ts") {ts=$(i+2); if(ts>=cutoff) print}}' "$USAGE_FILE" | wc -l)

if [ "$JSON" = "--json" ]; then
  jq -r '.skill' "$USAGE_FILE" | sort | uniq -c | sort -rn | \
    awk '{printf "{\"skill\":\"%s\",\"count\":%d}\n", $2, $1}'
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🏛️ ATLAS │ Skill Usage Analytics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total invocations: $TOTAL | Period: last ${DAYS} days"
echo ""

echo "📊 Top Skills (by frequency):"
echo "┌─────────────────────────────────┬───────┬─────────────┐"
echo "│ Skill                           │ Count │ Bar         │"
echo "├─────────────────────────────────┼───────┼─────────────┤"
jq -r '.skill' "$USAGE_FILE" | sort | uniq -c | sort -rn | head -15 | \
  awk '{
    count=$1; skill=$2;
    bar="";
    for(i=0;i<count && i<10;i++) bar=bar"█";
    printf "│ %-31s │ %5d │ %-11s │\n", skill, count, bar
  }'
echo "└─────────────────────────────────┴───────┴─────────────┘"

echo ""
echo "📅 Usage by Day:"
jq -r '.ts[:10]' "$USAGE_FILE" | sort | uniq -c | tail -7 | \
  awk '{printf "  %s: %d invocations\n", $2, $1}'

echo ""

# Count installed skills (from profiles)
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLED=$(find "$PLUGIN_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l)
USED=$(jq -r '.skill' "$USAGE_FILE" | sort -u | wc -l)
UNUSED=$((INSTALLED - USED))

echo "📈 Coverage: $USED/$INSTALLED skills used ($UNUSED potentially unused)"
echo ""

if [ "$UNUSED" -gt 0 ]; then
  echo "💤 Unused skills (never invoked):"
  # Get list of all skill names
  ALL_SKILLS=$(find "$PLUGIN_DIR/skills" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)
  USED_SKILLS=$(jq -r '.skill' "$USAGE_FILE" | sort -u)
  comm -23 <(echo "$ALL_SKILLS") <(echo "$USED_SKILLS") | head -20 | while read s; do
    echo "  - $s"
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
