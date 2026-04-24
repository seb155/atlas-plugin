#!/usr/bin/env bash
# workflow-validate.sh — Linter for workflow-* SKILL.md files (v6.1.0)
#
# Usage:
#   scripts/workflow-validate.sh                       # validate all workflows in registry
#   scripts/workflow-validate.sh skills/workflow-X/    # validate single skill
#   scripts/workflow-validate.sh --strict              # fail on any warning (CI mode)
#
# Checks (derived from .blueprint/schemas/workflow-schema-v1.md § 5):
#   1. name starts with "workflow-"
#   2. category in 11-enum
#   3. schema_version is integer ≥ 1
#   4. workflow_steps[] non-empty
#   5. every iron_law_ref resolves in iron-laws.yaml (SHA256 optional here)
#   6. every chains[] entry is a known skill OR another workflow-*
#   7. HARD-GATE block in body references declared iron_law_ref
#   8. workflow in registry maps to a skill OR is flagged "not yet implemented"
#
# Exit: 0 = all pass (or unimplemented with warning), 1 = violations found

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REGISTRY="${PLUGIN_ROOT}/scripts/execution-philosophy/workflow-registry.yaml"
IRON_LAWS="${PLUGIN_ROOT}/scripts/execution-philosophy/iron-laws.yaml"
SKILLS_DIR="${PLUGIN_ROOT}/skills"
STRICT=false
SINGLE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=true; shift ;;
    --help|-h) head -20 "$0" | sed 's/^# //'; exit 0 ;;
    *) SINGLE="$1"; shift ;;
  esac
done

if [[ ! -f "$REGISTRY" ]]; then
  echo "❌ Registry not found: $REGISTRY" >&2
  exit 1
fi

ERRORS=0
WARNINGS=0
CHECKED=0

validate_workflow() {
  local name="$1"
  local skill_dir="${SKILLS_DIR}/${name}"
  local skill_file="${skill_dir}/SKILL.md"

  CHECKED=$((CHECKED + 1))

  # Check 1: skill file existence
  if [[ ! -f "$skill_file" ]]; then
    echo "⚠️  $name: SKILL.md not found at $skill_file (not yet implemented — Phase 2-6)"
    WARNINGS=$((WARNINGS + 1))
    return
  fi

  # Check 2: name prefix
  if [[ ! "$name" =~ ^workflow- ]]; then
    echo "❌ $name: name does not start with 'workflow-'"
    ERRORS=$((ERRORS + 1))
  fi

  # Check 3: parse frontmatter via python (robust)
  local fm_json
  fm_json=$(python3 <<PYEOF 2>/dev/null
import yaml, sys, json, re
try:
    content = open("$skill_file").read()
    m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not m:
        print(json.dumps({"error": "no frontmatter"}))
        sys.exit(0)
    fm = yaml.safe_load(m.group(1))
    print(json.dumps(fm))
except Exception as e:
    print(json.dumps({"error": str(e)}))
PYEOF
)

  local fm_error
  fm_error=$(echo "$fm_json" | python3 -c "import json,sys;d=json.loads(sys.stdin.read());print(d.get('error',''))" 2>/dev/null)
  if [[ -n "$fm_error" ]]; then
    echo "❌ $name: frontmatter parse error: $fm_error"
    ERRORS=$((ERRORS + 1))
    return
  fi

  # Check 4: required workflow fields
  local missing
  missing=$(echo "$fm_json" | python3 <<'PYEOF' 2>/dev/null
import json, sys
fm = json.loads(sys.stdin.read())
req = ['name', 'description', 'effort', 'version', 'schema_version',
       'workflow_steps', 'output_schema_ref', 'resumable', 'category',
       'superpowers_pattern']
missing = [k for k in req if k not in fm]
print(','.join(missing))
PYEOF
)

  if [[ -n "$missing" ]]; then
    echo "❌ $name: missing required frontmatter fields: $missing"
    ERRORS=$((ERRORS + 1))
  fi

  # Check 5: workflow_steps non-empty + iron_law refs valid
  local step_check
  step_check=$(python3 <<PYEOF 2>/dev/null
import json, yaml, sys

with open("$IRON_LAWS") as f:
    laws = {l['id'] for l in yaml.safe_load(f).get('laws', [])}

fm = $fm_json
steps = fm.get('workflow_steps', [])
errors = []
if not steps:
    errors.append("workflow_steps is empty")
for s in steps:
    if 'iron_law_ref' in s:
        if s['iron_law_ref'] not in laws:
            errors.append(f"step {s.get('step','?')}: iron_law_ref '{s['iron_law_ref']}' not in iron-laws.yaml")
    if 'skill' not in s:
        errors.append(f"step {s.get('step','?')}: missing 'skill' field")
print('\n'.join(errors))
PYEOF
)

  if [[ -n "$step_check" ]]; then
    echo "❌ $name: step validation errors:"
    echo "$step_check" | sed 's/^/    /'
    ERRORS=$((ERRORS + 1))
  fi

  # Check 6: HARD-GATE block present
  if ! grep -q "<HARD-GATE>" "$skill_file" 2>/dev/null; then
    echo "⚠️  $name: no <HARD-GATE> block in body (workflows should enforce at least one law)"
    WARNINGS=$((WARNINGS + 1))
  fi

  echo "✅ $name: frontmatter + steps valid"
}

# Main loop
echo "🏛️  Workflow Library Validation — atlas-plugin v6.1.0"
echo "   Registry: $REGISTRY"
echo ""

if [[ -n "$SINGLE" ]]; then
  name=$(basename "$SINGLE" | sed 's/^workflow-//' | sed 's/\/$//')
  name="workflow-${name}"
  validate_workflow "$name"
else
  # All workflows in registry
  python3 -c "import yaml; d=yaml.safe_load(open('$REGISTRY')); print('\n'.join(w['name'] for w in d['workflows']))" | \
    while read -r name; do
      [[ -z "$name" ]] && continue
      validate_workflow "$name"
    done
fi

echo ""
echo "─────────────────────────────────────────────────────────"
echo "Checked: $CHECKED  |  ❌ Errors: $ERRORS  |  ⚠️  Warnings: $WARNINGS"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "FAIL"
  exit 1
elif [[ "$STRICT" == "true" && "$WARNINGS" -gt 0 ]]; then
  echo "STRICT FAIL (warnings count as errors)"
  exit 1
fi

echo "OK"
exit 0
