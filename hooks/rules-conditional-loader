#!/usr/bin/env bash
# ATLAS Rules Conditional Loader (v6.0 Phase 4)
# SessionStart hook: detects project context, injects only relevant .claude/rules/
# files via _meta.yaml triggers. Reduces SessionStart token injection by ~60%.
#
# Plan ref: .blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md (Phase 4)
# Target: 33K → <15K tokens at SessionStart
set -euo pipefail

# ── Config ───────────────────────────────────────────────────────────

RULES_DIR=".claude/rules"
META_FILE="$RULES_DIR/_meta.yaml"
MAX_SELECTED=10  # Budget: max rules injected per session

# Exit early if no rules dir
if [ ! -d "$RULES_DIR" ]; then
  echo '{"continue": true}'
  exit 0
fi

# ── Context detection ────────────────────────────────────────────────

# Collect signals: cwd path components, recent file mods, branch name
cwd="$(pwd)"
branch=""
if git rev-parse --git-dir &>/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "")
fi

# Recent file modifications (last 60 min) as path hints
recent_paths=""
if command -v find &>/dev/null; then
  recent_paths=$(find . -type f -mmin -60 2>/dev/null \
    | head -50 | tr '\n' ' ')
fi

# ── Rule selection via _meta.yaml triggers ───────────────────────────

selected_rules=""
if [ -f "$META_FILE" ] && command -v python3 &>/dev/null; then
  # _meta.yaml schema:
  # rules:
  #   rule-file.md:
  #     auto_include: always | conditional | never
  #     triggers:
  #       cwd_contains: [backend, frontend]
  #       file_patterns: ["*.py", "*test*"]
  #       branch_patterns: ["feat/*"]
  #     priority: 1-10 (higher = included first)
  selected_rules=$(export CWD="$cwd" BRANCH="$branch" RECENT="$recent_paths" MAX="$MAX_SELECTED" METAFILE="$META_FILE"
    python3 <<'PYEOF'
import os, yaml, fnmatch
from pathlib import Path

meta_file = os.environ.get("METAFILE")
cwd = os.environ.get("CWD", "")
branch = os.environ.get("BRANCH", "")
recent = os.environ.get("RECENT", "")
max_sel = int(os.environ.get("MAX", "10"))

try:
    with open(meta_file) as f:
        meta = yaml.safe_load(f) or {}
except Exception:
    print("")
    raise SystemExit(0)

rules = (meta or {}).get("rules", {})
if not isinstance(rules, dict):
    print("")
    raise SystemExit(0)

scored = []
for fname, spec in rules.items():
    spec = spec or {}
    mode = spec.get("auto_include", "conditional")
    if mode == "never":
        continue
    priority = int(spec.get("priority", 5))
    if mode == "always":
        scored.append((100 + priority, fname))
        continue
    # conditional: check triggers
    triggers = spec.get("triggers", {}) or {}
    score = 0
    for needle in triggers.get("cwd_contains", []) or []:
        if needle in cwd:
            score += 10
    for pat in triggers.get("branch_patterns", []) or []:
        if branch and fnmatch.fnmatch(branch, pat):
            score += 5
    for pat in triggers.get("file_patterns", []) or []:
        # check if any recent path matches
        for path in recent.split():
            if fnmatch.fnmatch(path, pat) or fnmatch.fnmatch(os.path.basename(path), pat):
                score += 3
                break
    if score > 0:
        scored.append((score + priority, fname))

# Top N by score
scored.sort(key=lambda x: -x[0])
print("\n".join(fn for _, fn in scored[:max_sel]))
PYEOF
  )
fi

# Fallback: if no _meta.yaml or zero selected, emit minimal signal
if [ -z "$selected_rules" ]; then
  # Conservative fallback: include `code-quality.md` + `dod.md` if they exist
  for f in code-quality.md dod.md; do
    [ -f "$RULES_DIR/$f" ] && selected_rules+="$f"$'\n'
  done
fi

# ── Build reminder with selected rules ───────────────────────────────

if [ -z "$selected_rules" ]; then
  echo '{"continue": true}'
  exit 0
fi

# Count lines for telemetry
rule_count=$(echo "$selected_rules" | grep -c '.' || echo 0)

# Build structured reminder (pointers, not full content — model reads on demand)
reminder="# Rules Context (v6.0 conditional loader)

Loaded $rule_count rule(s) relevant to this session context:
"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  rule_path="$RULES_DIR/$f"
  [ ! -f "$rule_path" ] && continue
  # Extract first description line or h1
  desc=$(head -20 "$rule_path" | grep -E '^>|^# ' | head -1 | sed 's/^[#> ]*//')
  reminder+="
- \`$rule_path\` — ${desc:-rules}"
done <<< "$selected_rules"

reminder+="

Read a rule file when its topic becomes relevant. Don't proactively read unrelated rules — this reduces token budget (v6.0 Phase 4 goal: 33K → <15K SessionStart)."

# Emit via env-var passthrough
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
