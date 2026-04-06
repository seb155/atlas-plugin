#!/usr/bin/env bash
# plugin-tools.sh — Plugin & CLI expansion tools (SP-EVOLUTION P9)
# Usage:
#   plugin-tools.sh repos                — Multi-repo awareness (P9.1)
#   plugin-tools.sh cost [--reset]       — Cost tracker (P9.3)
#   plugin-tools.sh deps [plans_dir]     — Dependency graph (P9.4)
#   plugin-tools.sh init <template> [dir]— Project scaffolding (P9.2)
set -euo pipefail

# ── P9.1: Multi-Repo Awareness ───────────────────────────────

cmd_repos() {
  local workspace="${ATLAS_WORKSPACE:-${HOME}/workspace_atlas}"
  [ -d "$workspace" ] || { echo "Workspace not found: $workspace"; exit 1; }

  echo "📦 Workspace Repos"
  echo "   Root: $workspace"
  echo ""
  printf "  %-30s %-20s %-8s %-25s\n" "REPO" "BRANCH" "STATUS" "LAST COMMIT"
  printf "  %-30s %-20s %-8s %-25s\n" "──────────────────────────────" "────────────────────" "────────" "─────────────────────────"

  # Scan for git repos (max 2 levels deep)
  find "$workspace" -maxdepth 3 -name ".git" -type d 2>/dev/null | sort | while read -r gitdir; do
    local repo_dir=$(dirname "$gitdir")
    local repo_name="${repo_dir#$workspace/}"

    # Skip worktrees and hidden dirs
    [[ "$repo_name" == *".claude/worktrees"* ]] && continue
    [[ "$repo_name" == *".worktrees"* ]] && continue
    [[ "$repo_name" == *"node_modules"* ]] && continue

    # Git info
    local branch=$(git -C "$repo_dir" branch --show-current 2>/dev/null || echo "?")
    local dirty=""
    git -C "$repo_dir" diff --quiet 2>/dev/null || dirty="*"
    local staged=""
    git -C "$repo_dir" diff --cached --quiet 2>/dev/null || staged="+"

    local status_icon="✅"
    [ -n "$dirty" ] && status_icon="🟡"
    [ -n "$staged" ] && status_icon="🟠"

    local last_commit=$(git -C "$repo_dir" log -1 --format='%ar' 2>/dev/null || echo "?")
    local last_msg=$(git -C "$repo_dir" log -1 --format='%s' 2>/dev/null | head -c 30 || echo "?")

    # Truncate
    [ ${#repo_name} -gt 28 ] && repo_name="${repo_name:0:25}..."
    [ ${#branch} -gt 18 ] && branch="${branch:0:15}..."

    printf "  %-30s %-20s %s%-6s  %-25s\n" "$repo_name" "$branch" "$status_icon" "${dirty}${staged}" "$last_commit"
  done

  echo ""
  echo "  Legend: ✅ clean | 🟡 dirty | 🟠 staged | * uncommitted | + staged"
}

# ── P9.3: Cost Tracker ───────────────────────────────────────

cmd_cost() {
  local reset="${1:-}"
  local stats_file="${HOME}/.claude/agent-stats.jsonl"
  local cost_file="${HOME}/.claude/cost-tracker.jsonl"

  if [ "$reset" = "--reset" ]; then
    > "$cost_file" 2>/dev/null
    echo "✅ Cost tracker reset."
    return
  fi

  echo "💰 Session Cost Estimates"
  echo ""

  # Model pricing (approximate $/1K output tokens, 2026 rates)
  # These are rough estimates for tracking purposes only
  python3 -c "
import json, os, sys
from collections import defaultdict
from datetime import datetime, timedelta

RATES = {
    'opus': {'input': 15.0, 'output': 75.0},    # per 1M tokens
    'sonnet': {'input': 3.0, 'output': 15.0},
    'haiku': {'input': 0.25, 'output': 1.25},
}

# Estimate tokens from duration (rough: ~100 tokens/sec output for Sonnet)
TOKEN_RATES = {
    'opus': 50,     # tokens/sec output
    'sonnet': 100,
    'haiku': 200,
}

stats_file = '${stats_file}'
if not os.path.exists(stats_file):
    print('  No dispatch data yet. Run atlas dispatch first.')
    sys.exit(0)

sessions = defaultdict(lambda: {'tasks': 0, 'duration_s': 0, 'cost_usd': 0.0, 'models': defaultdict(int)})

with open(stats_file) as f:
    for line in f:
        try:
            e = json.loads(line)
            # Support both formats: subagent-result-capture (success/timestamp/duration_ms)
            # and legacy dispatch format (status/ts/duration_s)
            if not (e.get('success', False) or e.get('status') == 'completed'):
                continue
            model = e.get('model', 'sonnet')
            duration = e.get('duration_s', e.get('duration_ms', 0) / 1000)
            date = (e.get('ts', '') or e.get('timestamp', ''))[:10]

            # Estimate tokens
            out_tokens = duration * TOKEN_RATES.get(model, 100)
            in_tokens = out_tokens * 2  # rough: 2x input vs output

            rate = RATES.get(model, RATES['sonnet'])
            cost = (in_tokens * rate['input'] + out_tokens * rate['output']) / 1_000_000

            sessions[date]['tasks'] += 1
            sessions[date]['duration_s'] += duration
            sessions[date]['cost_usd'] += cost
            sessions[date]['models'][model] += 1
        except:
            pass

if not sessions:
    print('  No completed dispatches found.')
    sys.exit(0)

total_cost = 0
total_tasks = 0
total_duration = 0

print(f'  {\"Date\":<12} {\"Tasks\":<8} {\"Duration\":<10} {\"Est. Cost\":<12} {\"Models\":<30}')
print(f'  {\"─\"*12} {\"─\"*8} {\"─\"*10} {\"─\"*12} {\"─\"*30}')

for date in sorted(sessions.keys()):
    s = sessions[date]
    models_str = ', '.join(f'{m}:{c}' for m, c in sorted(s['models'].items()))
    dur = f'{s[\"duration_s\"]//60}m{s[\"duration_s\"]%60}s'
    print(f'  {date:<12} {s[\"tasks\"]:<8} {dur:<10} \${s[\"cost_usd\"]:<11.4f} {models_str:<30}')
    total_cost += s['cost_usd']
    total_tasks += s['tasks']
    total_duration += s['duration_s']

print(f'  {\"─\"*12} {\"─\"*8} {\"─\"*10} {\"─\"*12}')
print(f'  {\"Total\":<12} {total_tasks:<8} {total_duration//60}m      \${total_cost:.4f}')
print()
print(f'  ⚠️  Estimates only (token count approximated from duration)')
"
}

# ── P9.4: Dependency Graph ────────────────────────────────────

cmd_deps() {
  local plans_dir="${1:-.blueprint/plans}"
  [ -d "$plans_dir" ] || { echo "ERROR: $plans_dir not found" >&2; exit 1; }

  echo "🔗 Plan Dependency Graph"
  echo ""

  python3 -c "
import re, os, sys

plans_dir = '$plans_dir'
deps = {}  # plan -> [dependency list]
statuses = {}

for f in sorted(os.listdir(plans_dir)):
    if not f.endswith('.md') or f == 'INDEX.md' or '-agent-' in f:
        continue
    name = f.replace('.md', '')
    filepath = os.path.join(plans_dir, f)

    with open(filepath) as fh:
        content = fh.read()

    # Extract status
    status_match = re.search(r'(DRAFT|APPROVED|EXECUTING|COMPLETE|ARCHIVED|PLANNING|SHIPPED)', content)
    statuses[name] = status_match.group(1) if status_match else 'UNKNOWN'

    # Extract dependencies from companion/blocked/depends lines
    dep_list = []
    for line in content.split('\n'):
        if re.match(r'.*(?:Companion to|Blocked by|Depends on|Requires|blocked by)', line, re.I):
            refs = re.findall(r'\x60(sp-[^\x60]+)\x60|\x60([^\x60]+\.md)\x60', line)
            for r in refs:
                ref = (r[0] or r[1]).replace('.md', '')
                if ref != name:
                    dep_list.append(ref)
    deps[name] = dep_list

# Filter to plans with deps or that are depended upon
involved = set()
for p, d in deps.items():
    if d:
        involved.add(p)
        involved.update(d)

if not involved:
    print('  No inter-plan dependencies found.')
    print('  (Plans reference each other via Companion to/Blocked by)')
    sys.exit(0)

# ASCII graph
STATUS_ICON = {
    'EXECUTING': '⚡', 'APPROVED': '📋', 'DRAFT': '📝',
    'COMPLETE': '✅', 'ARCHIVED': '🗄️', 'UNKNOWN': '❓', 'PLANNING': '📝'
}

print('  Dependencies (A → B means A depends on B):')
print()
for p in sorted(involved):
    if p in deps and deps[p]:
        icon = STATUS_ICON.get(statuses.get(p, 'UNKNOWN'), '❓')
        dep_strs = []
        for d in deps[p]:
            d_icon = STATUS_ICON.get(statuses.get(d, 'UNKNOWN'), '❓')
            dep_strs.append(f'{d_icon} {d}')
        print(f'  {icon} {p}')
        for ds in dep_strs:
            print(f'     └──→ {ds}')
        print()

# Mermaid output
print('  Mermaid graph (copy to markdown):')
print()
print('  \x60\x60\x60mermaid')
print('  graph LR')
for p in sorted(involved):
    if p in deps and deps[p]:
        for d in deps[p]:
            p_short = p[:25]
            d_short = d[:25]
            print(f'    {p_short.replace(\"-\",\"_\")}[\"{p_short}\"] --> {d_short.replace(\"-\",\"_\")}[\"{d_short}\"]')
# Style nodes by status
for p in sorted(involved):
    s = statuses.get(p, 'UNKNOWN')
    node = p[:25].replace('-','_')
    if s == 'EXECUTING':
        print(f'    style {node} fill:#f9a825,stroke:#f57f17')
    elif s == 'COMPLETE':
        print(f'    style {node} fill:#66bb6a,stroke:#388e3c')
print('  \x60\x60\x60')
"
}

# ── P9.2: Project Scaffolding ─────────────────────────────────

cmd_init() {
  local template="${1:-default}"
  local target="${2:-.}"

  local template_dir="${HOME}/workspace_atlas/atlas/.atlas/templates/project-context-kit"
  if [ ! -d "$template_dir" ]; then
    template_dir="${HOME}/workspace_atlas/atlas/.atlas/templates"
  fi

  echo "🏗️  Project Scaffolding: $template → $target"
  echo ""

  # Create structure
  mkdir -p "$target/.blueprint/plans"
  mkdir -p "$target/.claude/rules"
  mkdir -p "$target/.forgejo/workflows"

  # CLAUDE.md
  if [ ! -f "$target/CLAUDE.md" ]; then
    local project_name=$(basename "$(cd "$target" && pwd)")
    cat > "$target/CLAUDE.md" << 'HEREDOC'
# CLAUDE.md — PROJECT_NAME

> **Stack**: TODO
> **Owner**: Seb Gagnon

## Commands

```bash
# TODO: Add dev commands
```

## Conventions

- Package manager: bun
- TypeScript strict mode
- Tests before code (TDD)
- Files: kebab-case, components: PascalCase

## Documentation

- `.blueprint/` — Architecture docs
- `.claude/rules/` — AI behavior rules
HEREDOC
    sed -i "s/PROJECT_NAME/$project_name/g" "$target/CLAUDE.md"
    echo "  ✅ CLAUDE.md created"
  else
    echo "  ⏭️  CLAUDE.md already exists"
  fi

  # .blueprint/INDEX.md
  if [ ! -f "$target/.blueprint/INDEX.md" ]; then
    echo "# Blueprint Index" > "$target/.blueprint/INDEX.md"
    echo "" >> "$target/.blueprint/INDEX.md"
    echo "| Document | Purpose |" >> "$target/.blueprint/INDEX.md"
    echo "|----------|---------|" >> "$target/.blueprint/INDEX.md"
    echo "| plans/ | Implementation plans |" >> "$target/.blueprint/INDEX.md"
    echo "  ✅ .blueprint/INDEX.md created"
  fi

  # .forgejo/workflows/ci.yml (minimal)
  if [ ! -f "$target/.forgejo/workflows/ci.yml" ]; then
    cat > "$target/.forgejo/workflows/ci.yml" << 'HEREDOC'
name: CI
on:
  push:
    branches: ["**"]
  pull_request:
    branches: ["**"]

jobs:
  lint:
    name: Lint + Type Check
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: TODO — Add lint steps
        run: echo "Add your lint/test commands here"
HEREDOC
    echo "  ✅ .forgejo/workflows/ci.yml created"
  fi

  # .claude/rules/code-quality.md
  if [ ! -f "$target/.claude/rules/code-quality.md" ]; then
    cat > "$target/.claude/rules/code-quality.md" << 'HEREDOC'
# Code Quality Rules

- Files: kebab-case. Components: PascalCase. Hooks: use* prefix
- Hooks < 50 lines, components < 300 lines
- TypeScript strict mode always
- Extract repeated patterns to named hooks/utils
HEREDOC
    echo "  ✅ .claude/rules/code-quality.md created"
  fi

  echo ""
  echo "  📦 Scaffolding complete. Next:"
  echo "     1. Edit CLAUDE.md with your stack details"
  echo "     2. Add plans to .blueprint/plans/"
  echo "     3. Configure CI in .forgejo/workflows/ci.yml"
}

# ── Main ──────────────────────────────────────────────────────

case "${1:-help}" in
  repos)  cmd_repos ;;
  cost)   shift 2>/dev/null || true; cmd_cost "$@" ;;
  deps)   shift 2>/dev/null || true; cmd_deps "$@" ;;
  init)   shift; cmd_init "$@" ;;
  *)      echo "Usage: plugin-tools.sh {repos|cost|deps|init} [args]"; exit 1 ;;
esac
