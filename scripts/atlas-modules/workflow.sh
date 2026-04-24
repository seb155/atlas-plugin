#!/usr/bin/env bash
# ATLAS workflow CLI module (v6.1.0)
#
# Subcommands:
#   atlas workflow list [--category <id>] [--priority <P0|P1|P2>]
#   atlas workflow show <name>
#   atlas workflow validate [<skill-dir>]   — runs workflow-validate.sh
#   atlas workflow suggest "<natural language>"  — basic intent match (Phase 7 extension)
#
# Reads: scripts/execution-philosophy/workflow-registry.yaml
# Plan ref: .blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md Section O.1 + P

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REGISTRY="${PLUGIN_ROOT}/scripts/execution-philosophy/workflow-registry.yaml"
VALIDATOR="${PLUGIN_ROOT}/scripts/workflow-validate.sh"

workflow_list() {
  local category_filter=""
  local priority_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --category) category_filter="$2"; shift 2 ;;
      --priority) priority_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ ! -f "$REGISTRY" ]]; then
    echo "Error: registry not found at $REGISTRY" >&2
    return 1
  fi

  python3 <<PYEOF
import yaml, sys
with open("$REGISTRY") as f:
    d = yaml.safe_load(f)

cat_filter = "$category_filter"
prio_filter = "$priority_filter"

# Header
print("\033[1m🏛️  ATLAS Workflow Library v1.0 — " + str(d['metadata']['total_workflows']) + " workflows / " + str(len(d['categories'])) + " categories\033[0m")
print("")

# Group by category
by_cat = {}
for w in d['workflows']:
    if cat_filter and w['category'] != cat_filter: continue
    if prio_filter and w.get('priority') != prio_filter: continue
    by_cat.setdefault(w['category'], []).append(w)

# Render categories in registry order
cat_order = {c['id']: c for c in d['categories']}
for cid in cat_order:
    if cid not in by_cat: continue
    c = cat_order[cid]
    print(f"\033[1m{c['emoji']} {c['name']}\033[0m  ({len(by_cat[cid])} workflows)")
    for w in by_cat[cid]:
        prio = w.get('priority', '  ')
        triggers = w.get('triggers', [])
        trig_str = f" — \033[2m\"{triggers[0]}\"\033[0m" if triggers else ""
        print(f"  [{prio}] {w['name']:<35} {w['description'][:60]}{trig_str}")
    print("")

total = sum(len(v) for v in by_cat.values())
print(f"\033[2m{total} matching workflow(s). Use 'atlas workflow show <name>' for details.\033[0m")
PYEOF
}

workflow_show() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    echo "Usage: atlas workflow show <name>" >&2
    return 1
  fi

  python3 <<PYEOF
import yaml, sys
with open("$REGISTRY") as f:
    d = yaml.safe_load(f)

match = None
for w in d['workflows']:
    if w['name'] == "$name" or w['name'] == "workflow-$name":
        match = w
        break

if not match:
    print(f"Workflow '{"$name"}' not found. Run 'atlas workflow list' to see all.")
    sys.exit(1)

print(f"\n\033[1m{match['name']}\033[0m  [{match.get('priority', '?')}]  ({match['category']})\n")
print(match['description'])
print("")
print(f"  Duration (nominal):  {match.get('estimated_duration_min', '?')} min")
print(f"  Persona tags:        {', '.join(match.get('persona_tags', []))}")
print(f"  HITL required:       {match.get('requires_hitl', False)}")
if match.get('iron_laws'):
    print(f"  Iron Laws:           {', '.join(match['iron_laws'])}")
if match.get('chains'):
    print(f"  Chains skills:       {', '.join(match['chains'])}")
if match.get('triggers'):
    print(f"  Triggers:            {', '.join(f'\"{{t}}\"'.format(t=t) for t in match['triggers'])}")
print(f"  Plan phase:          {match.get('phase', '?')}")
print("")

skill_file = "$PLUGIN_ROOT/skills/" + match['name'] + "/SKILL.md"
import os
if os.path.exists(skill_file):
    print(f"\033[2mSkill file: {skill_file}\033[0m")
else:
    print(f"\033[2m[not yet implemented — see plan phase {match.get('phase', '?')}]\033[0m")
PYEOF
}

workflow_validate() {
  if [[ -x "$VALIDATOR" ]]; then
    "$VALIDATOR" "$@"
  else
    echo "Validator not yet installed at $VALIDATOR — Phase 1 Task 1.10" >&2
    return 1
  fi
}

# Entry point
case "${1:-list}" in
  list) shift; workflow_list "$@" ;;
  show) shift; workflow_show "$@" ;;
  validate) shift; workflow_validate "$@" ;;
  suggest) shift; echo "TODO: intent detection coming in Phase 7 Task 7.9" ;;
  --help|-h|help)
    cat <<'EOF'
atlas workflow — SOTA workflow library

Usage:
  atlas workflow list [--category <id>] [--priority <P0|P1|P2>]
  atlas workflow show <name>
  atlas workflow validate [<skill-dir>]
  atlas workflow suggest "<natural language>"

Categories: programming, product, uxui, collab, architecture, planning,
            infrastructure, research, documentation, analytics, meta

Examples:
  atlas workflow list
  atlas workflow list --category programming
  atlas workflow list --priority P0
  atlas workflow show workflow-feature
  atlas workflow show feature
EOF
    ;;
  *)
    echo "Unknown subcommand: $1. Try 'atlas workflow help'." >&2
    exit 1
    ;;
esac
