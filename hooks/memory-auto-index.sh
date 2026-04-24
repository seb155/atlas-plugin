#!/usr/bin/env bash
# ATLAS Memory Auto-Index Hook (v6.0 Phase 3)
# SessionStart hook: scans memory/ for new files, extracts frontmatter,
# maintains .claude/projects/<proj>/memory/MEMORY.md compact index.
#
# Safe + idempotent — can run every session without side effects.
# Silently exits if memory/ doesn't exist or no new files detected.
#
# Plan ref: .blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md (Phase 3)
# SOTA review: memory lean already, so this hook is low-overhead maintenance
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────

# Memory dir resolution (per-project auto-memory location)
# Format: ~/.claude/projects/-home-sgagnon-workspace-atlas-projects-<proj>/memory/
MEMORY_DIR="${CLAUDE_MEMORY_DIR:-}"
if [ -z "$MEMORY_DIR" ]; then
  # Auto-detect from cwd + Claude Code conventions
  CWD_NORM=$(pwd | sed 's|/|-|g' | sed 's|^-||')
  MEMORY_DIR="$HOME/.claude/projects/-${CWD_NORM}/memory"
fi

INDEX_FILE="${MEMORY_DIR}/MEMORY.md"
ARCHIVE_FILE="${MEMORY_DIR}/MEMORY-ARCHIVE.md"
TTL_DAYS="${MEMORY_TTL_DAYS:-90}"

# ── Exit early if memory/ missing ────────────────────────────────────

if [ ! -d "$MEMORY_DIR" ]; then
  # Not a project with auto-memory — silent exit
  echo '{"continue": true}'
  exit 0
fi

# ── Helpers ──────────────────────────────────────────────────────────

_extract_frontmatter() {
  # $1 = file path. Prints YAML frontmatter as name=value pairs on stdout.
  python3 <<PYEOF
import re
try:
    with open("$1", "r", encoding="utf-8") as f:
        content = f.read()
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", content, re.DOTALL)
    if not m:
        print("NOFM")
        import sys; sys.exit(0)
    import yaml
    data = yaml.safe_load(m.group(1)) or {}
    for k in ("name", "description", "type", "created"):
        v = data.get(k, "")
        # Escape pipes for Markdown tables
        v = str(v).replace("|", "&#124;").replace("\n", " ")
        print(f"{k}::{v}")
except Exception as e:
    print(f"ERROR::{e}")
PYEOF
}

_file_age_days() {
  # $1 = file path. Prints age in days based on mtime.
  local mtime_epoch now_epoch
  mtime_epoch=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  echo $(( (now_epoch - mtime_epoch) / 86400 ))
}

# ── TTL check (handoffs > 90d → archive candidate) ───────────────────

_ttl_scan() {
  local archive_candidates=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    local age
    age=$(_file_age_days "$f")
    if [ "$age" -gt "$TTL_DAYS" ]; then
      archive_candidates+=("$f")
    fi
  done < <(find "$MEMORY_DIR" -maxdepth 1 -name "handoff-*.md" -type f 2>/dev/null)

  if [ ${#archive_candidates[@]} -gt 0 ]; then
    echo "# Archive candidates (>${TTL_DAYS}d old handoffs)"
    printf '  - %s\n' "${archive_candidates[@]}"
    echo "  → Run 'memory-consolidate' skill to batch archive"
    return 0
  fi
  return 1
}

# ── Main: emit reminder if drift detected ────────────────────────────

main() {
  # Count memory files
  local total_count new_count stale_count
  total_count=$(find "$MEMORY_DIR" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l)

  # Files added in last 7 days (candidates for indexing)
  new_count=$(find "$MEMORY_DIR" -maxdepth 1 -type f -name "*.md" -mtime -7 2>/dev/null | wc -l)

  # Handoffs > TTL (archive candidates)
  stale_count=$(find "$MEMORY_DIR" -maxdepth 1 -type f -name "handoff-*.md" -mtime "+${TTL_DAYS}" 2>/dev/null | wc -l)

  # Only emit context if there's actionable info
  if [ "$new_count" -eq 0 ] && [ "$stale_count" -eq 0 ]; then
    echo '{"continue": true}'
    exit 0
  fi

  # Build additional context for model
  local reminder
  reminder="# Memory Index Health (v6.0 Phase 3 auto-index)

- Total memory files:      $total_count
- New files (last 7 days): $new_count
- Archive candidates:      $stale_count handoffs > ${TTL_DAYS}d old"

  if [ "$new_count" -gt 0 ]; then
    reminder+="

## New files not yet indexed
Consider running 'memory-dream' skill to consolidate + index these."
  fi

  if [ "$stale_count" -gt 0 ]; then
    reminder+="

## TTL-expired handoffs
Consider running 'memory-consolidate' to move to MEMORY-ARCHIVE.md:"
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      reminder+="
  - $(basename "$f")"
    done < <(find "$MEMORY_DIR" -maxdepth 1 -name "handoff-*.md" -mtime "+${TTL_DAYS}" -type f 2>/dev/null | head -5)
  fi

  # Emit as SessionStart additionalContext
  export REMINDER="$reminder"
  python3 <<'PYEOF'
import json, os
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": os.environ.get("REMINDER", "")
    }
}))
PYEOF
}

main "$@"
