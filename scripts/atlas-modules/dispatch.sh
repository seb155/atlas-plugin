#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: Sourced by scripts/atlas-cli.sh (no set -euo pipefail at file level).
# ATLAS CLI Module: Agent Dispatch (lightweight fire-and-forget)
# Sourced by atlas-cli.sh — do not execute directly
# SP-EVOLUTION P7.4 — atlas dispatch "task" [--model sonnet]
# Plan v6.0 Sprint 5.5 — 6-level effort routing + AGENT.md frontmatter inspection

# ── v6.0: 6-level effort → model routing ────────────────────────
# Valid effort levels (ordered low→max; "auto" = fallback)
_ATLAS_VALID_EFFORTS="low medium high xhigh max auto"

# Validate effort level
_atlas_validate_effort() {
  local effort="$1"
  case " $_ATLAS_VALID_EFFORTS " in
    *" $effort "*) return 0 ;;
    *) return 1 ;;
  esac
}

# Parse `effort:` from AGENT.md YAML frontmatter
# Usage: _atlas_get_agent_effort <agent_name>
# Returns: effort string (low|medium|high|xhigh|max) or "auto" if not found
_atlas_get_agent_effort() {
  local agent_name="$1"
  local plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  local agent_md="${plugin_root}/agents/${agent_name}/AGENT.md"
  [ -f "$agent_md" ] || { echo "auto"; return 0; }

  python3 -c "
import sys
try:
    import yaml
except ImportError:
    print('auto'); sys.exit(0)
try:
    with open('$agent_md') as f:
        content = f.read()
    parts = content.split('---')
    if len(parts) >= 3:
        fm = yaml.safe_load(parts[1]) or {}
        eff = str(fm.get('effort', 'auto')).lower().strip()
        valid = {'low','medium','high','xhigh','max','auto'}
        print(eff if eff in valid else 'auto')
    else:
        print('auto')
except Exception:
    print('auto')
" 2>/dev/null || echo "auto"
}

# Map a 6-level effort to a model tier (Opus/Sonnet/Haiku)
# Usage: _atlas_effort_to_model <effort>
# Returns: opus|sonnet|haiku
_atlas_effort_to_model() {
  case "$1" in
    max|xhigh)    echo "opus" ;;
    high|medium)  echo "sonnet" ;;
    low)          echo "haiku" ;;
    *)            echo "sonnet" ;;  # auto/unknown → sonnet default
  esac
}

_atlas_dispatch() {
  local desc=""
  local model=""
  local mode="auto"
  local effort=""

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model) model="$2"; shift 2 ;;
      --mode) mode="$2"; shift 2 ;;
      --effort=*) effort="${1#--effort=}"; shift ;;
      --effort) effort="$2"; shift 2 ;;
      *) desc="$desc $1"; shift ;;
    esac
  done
  desc="${desc## }"  # trim leading space

  if [ -z "$desc" ]; then
    echo "Usage: atlas dispatch \"task description\" [--model sonnet|opus|haiku] [--effort low|medium|high|xhigh|max|auto]"
    return 1
  fi

  # v6.0: Validate --effort if provided; reject invalid values early
  if [ -n "$effort" ]; then
    if ! _atlas_validate_effort "$effort"; then
      echo "❌ Invalid --effort '$effort'. Valid: low, medium, high, xhigh, max, auto"
      return 1
    fi
    # effort=auto means "fall back to complexity detection" — clear it
    [ "$effort" = "auto" ] && effort=""
  fi

  # v6.0: If --effort set and no --model, route via effort tier map
  if [ -n "$effort" ] && [ -z "$model" ]; then
    model=$(_atlas_effort_to_model "$effort")
    echo "🎚️  Effort: ${effort} → model: ${model}"
  fi

  # Auto-detect model if not specified
  if [ -z "$model" ]; then
    local complexity_script="${ATLAS_SHELL_DIR}/../scripts/task-complexity.sh"
    [ -f "$complexity_script" ] || complexity_script="$(dirname "$(dirname "$ATLAS_SHELL_DIR")")/scripts/task-complexity.sh"
    if [ -f "$complexity_script" ]; then
      local result
      result=$(bash "$complexity_script" "$desc")
      model=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['model'])" 2>/dev/null || echo "sonnet")
      local level
      level=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['level'])" 2>/dev/null || echo "moderate")
      echo "🎯 Complexity: ${level} → model: ${model}"
    else
      model="sonnet"
    fi
  fi

  # Map model name to full model ID
  local model_id=""
  case "$model" in
    opus)   model_id="claude-opus-4-7" ;;
    sonnet) model_id="claude-sonnet-4-6" ;;
    haiku)  model_id="claude-haiku-4-5-20251001" ;;
    *)      model_id="$model" ;;
  esac

  echo "🚀 Dispatching: \"${desc}\""
  echo "   Model: ${model} (${model_id})"
  echo ""

  # Log dispatch
  local log_file="${HOME}/.claude/agent-stats.jsonl"
  printf '{"ts":"%s","task":"%s","model":"%s","status":"dispatched"}\n' \
    "$(/usr/bin/date -Iseconds)" "$desc" "$model" >> "$log_file" 2>/dev/null

  # Find claude binary
  local claude_bin
  claude_bin=$(command -v claude 2>/dev/null || echo "/usr/local/bin/claude")
  if [ ! -x "$claude_bin" ]; then
    echo "❌ claude binary not found"
    return 1
  fi

  # ── P7.6: Auto-escalation ──────────────────────────────────
  local max_retries=2
  local attempt=0
  local models_ladder=("$model")

  # Build escalation ladder if mode is auto
  if [ "$mode" = "auto" ]; then
    case "$model" in
      haiku)  models_ladder=(haiku sonnet opus) ;;
      sonnet) models_ladder=(sonnet opus) ;;
      opus)   models_ladder=(opus) ;;
    esac
  fi

  local success=false
  for escalated_model in "${models_ladder[@]}"; do
    attempt=$((attempt + 1))
    [ "$attempt" -gt 1 ] && echo "   🔄 Escalating to ${escalated_model} (attempt ${attempt}/${#models_ladder[@]})"

    # Map model name to full ID
    case "$escalated_model" in
      opus)   model_id="claude-opus-4-7" ;;
      sonnet) model_id="claude-sonnet-4-6" ;;
      haiku)  model_id="claude-haiku-4-5-20251001" ;;
    esac

    echo "   Running (${escalated_model})..."
    local start_ts
    start_ts=$(/usr/bin/date +%s)
    local output
    output=$($claude_bin --print --model "$model_id" "$desc" 2>&1)
    local exit_code=$?
    local end_ts
    end_ts=$(/usr/bin/date +%s)
    local duration
    duration=$((end_ts - start_ts))

    if [ "$exit_code" -eq 0 ] && [ -n "$output" ] && ! echo "$output" | grep -qi "error\|failed\|exception" | /usr/bin/head -1 >/dev/null 2>&1; then
      success=true
      printf '{"ts":"%s","task":"%s","model":"%s","status":"completed","duration_s":%d,"attempt":%d}\n' \
        "$(/usr/bin/date -Iseconds)" "$desc" "$escalated_model" "$duration" "$attempt" >> "$log_file" 2>/dev/null

      echo ""
      echo "─── Result (${duration}s, ${escalated_model}) ───"
      echo "$output" | /usr/bin/head -50
      [ $(echo "$output" | /usr/bin/wc -l) -gt 50 ] && echo "... (truncated, $(echo "$output" | /usr/bin/wc -l) lines total)"
      echo ""
      [ "$attempt" -gt 1 ] && echo "✅ Done in ${duration}s (escalated: ${model} → ${escalated_model})" \
                            || echo "✅ Done in ${duration}s (model: ${escalated_model})"
      break
    else
      printf '{"ts":"%s","task":"%s","model":"%s","status":"failed","duration_s":%d,"attempt":%d}\n' \
        "$(/usr/bin/date -Iseconds)" "$desc" "$escalated_model" "$duration" "$attempt" >> "$log_file" 2>/dev/null
      echo "   ⚠️  ${escalated_model} failed (${duration}s)"
    fi
  done

  if ! $success; then
    echo "   ❌ All models failed after ${attempt} attempts. Escalate to human."
  fi
}

# atlas agents stats — Show agent performance metrics
_atlas_agent_stats() {
  local log_file="${HOME}/.claude/agent-stats.jsonl"
  if [ ! -f "$log_file" ]; then
    echo "No agent stats yet. Run 'atlas dispatch' first."
    return 0
  fi

  _atlas_header
  printf "  ${ATLAS_BOLD}Agent Performance Stats${ATLAS_RESET}\n\n"

  python3 -c "
import json, sys
from collections import defaultdict

stats = defaultdict(lambda: {'count': 0, 'total_s': 0, 'success': 0, 'fail': 0})

with open('${log_file}') as f:
    for line in f:
        try:
            e = json.loads(line)
            model = e.get('model', '?')
            if e.get('status') == 'completed':
                stats[model]['count'] += 1
                stats[model]['total_s'] += e.get('duration_s', 0)
                stats[model]['success'] += 1
            elif e.get('status') == 'failed':
                stats[model]['fail'] += 1
        except:
            pass

if not stats:
    print('  No completed dispatches yet.')
    sys.exit(0)

print(f'  {\"Model\":<10} {\"Tasks\":<8} {\"Avg\":<8} {\"Success\":<10}')
print(f'  {\"─\"*10} {\"─\"*8} {\"─\"*8} {\"─\"*10}')
for model, s in sorted(stats.items()):
    avg = f'{s[\"total_s\"]/s[\"count\"]:.0f}s' if s['count'] > 0 else '—'
    rate = f'{s[\"success\"]/(s[\"success\"]+s[\"fail\"])*100:.0f}%' if (s['success']+s['fail']) > 0 else '—'
    print(f'  {model:<10} {s[\"count\"]:<8} {avg:<8} {rate:<10}')
" 2>/dev/null

  _atlas_footer
}

# ── P7.3: Agent Blueprints Library ──────────────────────────

_atlas_team_blueprint() {
  local blueprint="${1:-help}"

  # Blueprint definitions
  case "$blueprint" in
    solo)
      echo "📋 Blueprint: solo (1 agent)"
      echo "   Use: Simple tasks, quick fixes, one-file changes"
      echo "   Model: auto (complexity-based)"
      echo ""
      echo "   atlas dispatch \"your task here\""
      ;;
    pair)
      echo "📋 Blueprint: pair (2 agents)"
      echo "   Use: Feature with tests — one implements, one verifies"
      echo "   Models: Sonnet (implement) + Haiku (verify)"
      echo ""
      echo "   Pattern:"
      echo "     atlas dispatch \"implement: {task}\" --model sonnet"
      echo "     atlas dispatch \"verify: run tests for {task}\" --model haiku"
      ;;
    squad)
      echo "📋 Blueprint: squad (3-5 agents)"
      echo "   Use: Multi-file feature — architect + engineers + reviewer"
      echo "   Models: Opus (architect) + Sonnet×2 (implement) + Haiku (review)"
      echo ""
      echo "   Pattern:"
      echo "     1. atlas dispatch \"architect: design {feature}\" --model opus"
      echo "     2. atlas dispatch \"implement backend: {task}\" --model sonnet"
      echo "     3. atlas dispatch \"implement frontend: {task}\" --model sonnet"
      echo "     4. atlas dispatch \"review: check code quality\" --model haiku"
      ;;
    swarm)
      echo "📋 Blueprint: swarm (5+ agents)"
      echo "   Use: Large refactor, plan execution, multi-repo"
      echo "   Models: Opus (lead) + Sonnet×N (workers) + Haiku (validators)"
      echo "   ⚠️  Requires tmux + agent teams for coordination"
      echo ""
      echo "   Pattern: Use /atlas team feature --plan {plan-file}"
      ;;
    list)
      echo "📋 Agent Blueprints"
      echo ""
      printf "  %-10s %-8s %-45s\n" "NAME" "AGENTS" "USE CASE"
      printf "  %-10s %-8s %-45s\n" "──────────" "────────" "─────────────────────────────────────────────"
      printf "  %-10s %-8s %-45s\n" "solo"  "1"    "Quick tasks, fixes, one-file changes"
      printf "  %-10s %-8s %-45s\n" "pair"  "2"    "Feature + tests (implement + verify)"
      printf "  %-10s %-8s %-45s\n" "squad" "3-5"  "Multi-file feature (arch + eng + review)"
      printf "  %-10s %-8s %-45s\n" "swarm" "5+"   "Large refactor, plan exec, multi-repo"
      ;;
    *)
      echo "Usage: atlas team {solo|pair|squad|swarm|list}"
      echo "   Show pre-built team configurations for agent dispatch."
      ;;
  esac
}

# ── P7.7: Execution Manifest Generator ──────────────────────

_atlas_manifest() {
  local plan_file="${1:-}"
  [ -z "$plan_file" ] && { echo "Usage: atlas manifest <plan-file.md>"; return 1; }
  [ -f "$plan_file" ] || { echo "ERROR: File not found: $plan_file"; return 1; }

  python3 -c "
import json, re, os, sys

plan_path = '$plan_file'
with open(plan_path) as f:
    content = f.read()

plan_name = os.path.basename(plan_path).replace('.md', '')

# Extract phases and tasks from table format:  | N.N | Task | Effort | Deliverable |
manifest = {
    'plan': plan_name,
    'generated': '$(/usr/bin/date -Iseconds)',
    'phases': []
}

# Find phase headers
phase_pattern = r'###\s*Phase\s*(\d+)[:\s]*(.+?)(?:\(|—|\n)'
phases = re.finditer(phase_pattern, content)

for phase_match in phases:
    phase_num = phase_match.group(1)
    phase_name = phase_match.group(2).strip()

    # Find tasks after this phase header
    phase_start = phase_match.end()
    next_phase = re.search(r'###\s*Phase\s*\d+', content[phase_start:])
    phase_end = phase_start + next_phase.start() if next_phase else len(content)
    phase_content = content[phase_start:phase_end]

    tasks = []
    # Match table rows: | N.N | Task description | Effort | Deliverable |
    task_pattern = r'\|\s*(\d+\.\d+)\s*\|\s*\*?\*?(.+?)\*?\*?\s*\|\s*(\d+)h?\s*\|'
    for task_match in re.finditer(task_pattern, phase_content):
        task_id = task_match.group(1)
        task_desc = task_match.group(2).strip().strip('*')
        task_effort = int(task_match.group(3))

        # Auto-assign model based on effort and keywords
        model = 'sonnet'  # default
        desc_lower = task_desc.lower()
        if task_effort >= 4 or any(w in desc_lower for w in ['architect', 'design', 'strategy', 'review']):
            model = 'opus'
        elif task_effort <= 1 or any(w in desc_lower for w in ['rename', 'fix', 'simple', 'lint', 'cleanup']):
            model = 'haiku'

        # Determine mode
        mode = 'auto'
        if any(w in desc_lower for w in ['test', 'verify', 'validate']):
            mode = 'verify'
        elif any(w in desc_lower for w in ['implement', 'create', 'build', 'add']):
            mode = 'implement'

        tasks.append({
            'id': task_id,
            'description': task_desc[:80],
            'effort_h': task_effort,
            'model': model,
            'mode': mode
        })

    if tasks:
        manifest['phases'].append({
            'phase': int(phase_num),
            'name': phase_name,
            'tasks': tasks,
            'total_effort_h': sum(t['effort_h'] for t in tasks)
        })

# Summary
total_tasks = sum(len(p['tasks']) for p in manifest['phases'])
total_effort = sum(p['total_effort_h'] for p in manifest['phases'])
manifest['summary'] = {
    'total_phases': len(manifest['phases']),
    'total_tasks': total_tasks,
    'total_effort_h': total_effort,
    'model_distribution': {}
}

# Count model allocation
from collections import Counter
models = Counter(t['model'] for p in manifest['phases'] for t in p['tasks'])
manifest['summary']['model_distribution'] = dict(models)

# Output
print(json.dumps(manifest, indent=2))

# Also print human-readable summary
print(f'\n📋 Manifest: {plan_name}', file=sys.stderr)
print(f'   Phases: {len(manifest[\"phases\"])} | Tasks: {total_tasks} | Effort: {total_effort}h', file=sys.stderr)
for m, c in models.most_common():
    print(f'   {m}: {c} tasks', file=sys.stderr)
" 2>&1

  # Optionally save to file
  local manifest_dir=".atlas/manifests"
  if [ -d ".atlas" ] || [ -d ".blueprint" ]; then
    mkdir -p "$manifest_dir"
    local out_file="${manifest_dir}/${plan_file##*/}"
    out_file="${out_file%.md}.json"
    # Re-run python only outputting JSON (no stderr)
    python3 -c "
import json, re, os

plan_path = '$plan_file'
with open(plan_path) as f:
    content = f.read()

plan_name = os.path.basename(plan_path).replace('.md', '')
manifest = {'plan': plan_name, 'generated': '$(/usr/bin/date -Iseconds)', 'phases': []}

phase_pattern = r'###\s*Phase\s*(\d+)[:\s]*(.+?)(?:\(|—|\n)'
for phase_match in re.finditer(phase_pattern, content):
    phase_num = phase_match.group(1)
    phase_name = phase_match.group(2).strip()
    phase_start = phase_match.end()
    next_phase = re.search(r'###\s*Phase\s*\d+', content[phase_start:])
    phase_end = phase_start + next_phase.start() if next_phase else len(content)
    phase_content = content[phase_start:phase_end]
    tasks = []
    for task_match in re.finditer(r'\|\s*(\d+\.\d+)\s*\|\s*\*?\*?(.+?)\*?\*?\s*\|\s*(\d+)h?\s*\|', phase_content):
        task_id = task_match.group(1)
        task_desc = task_match.group(2).strip().strip('*')
        task_effort = int(task_match.group(3))
        model = 'sonnet'
        desc_lower = task_desc.lower()
        if task_effort >= 4 or any(w in desc_lower for w in ['architect','design','strategy','review']): model = 'opus'
        elif task_effort <= 1 or any(w in desc_lower for w in ['rename','fix','simple','lint']): model = 'haiku'
        tasks.append({'id':task_id,'description':task_desc[:80],'effort_h':task_effort,'model':model,'mode':'auto'})
    if tasks:
        manifest['phases'].append({'phase':int(phase_num),'name':phase_name,'tasks':tasks,'total_effort_h':sum(t['effort_h'] for t in tasks)})

with open('$out_file','w') as f:
    json.dump(manifest, f, indent=2)
print(f'   💾 Saved: $out_file')
" 2>/dev/null
  fi
}
