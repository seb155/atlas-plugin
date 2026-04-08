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

# ── P9.3: Cost Tracker (v2 — real token data via ccusage) ────

cmd_cost() {
  local subcmd="${1:-today}"
  shift 2>/dev/null || true

  # Check if the modular cost.sh exists and delegate
  local cost_module
  for p in \
    "${BASH_SOURCE[0]%/*}/atlas-modules/cost.sh" \
    "${HOME}/.atlas/shell/modules/../scripts/atlas-modules/cost.sh" \
    "$(find "${HOME}/.claude/plugins/cache" -maxdepth 5 -name "cost.sh" -path "*/atlas-modules/*" 2>/dev/null | head -1)"; do
    [ -f "$p" ] && { cost_module="$p"; break; }
  done

  if [ -n "${cost_module:-}" ]; then
    bash "$cost_module" "$subcmd" "$@"
    return
  fi

  # Inline fallback: use ccusage directly if bun available
  if command -v bun &>/dev/null; then
    local since_flag=""
    case "$subcmd" in
      today)   since_flag="--since $(date '+%Y%m%d')" ;;
      daily)   since_flag="--since $(date -d '-7 days' '+%Y%m%d' 2>/dev/null || date -v-7d '+%Y%m%d')" ;;
      weekly)  since_flag="--since $(date -d '-30 days' '+%Y%m%d' 2>/dev/null || date -v-30d '+%Y%m%d')" ;;
      sprint)  since_flag="--since $(date -d '-5 days' '+%Y%m%d' 2>/dev/null || date -v-5d '+%Y%m%d')" ;;
      session) since_flag="--since $(date -d '-3 days' '+%Y%m%d' 2>/dev/null || date -v-3d '+%Y%m%d')" ;;
      monthly) since_flag="" ;;
      status)
        local today_cost
        today_cost=$(bun x ccusage@latest daily --since "$(date '+%Y%m%d')" --json 2>/dev/null | \
          python3 -c "import json,sys; d=json.load(sys.stdin); print(f'{sum(e[\"totalCost\"] for e in d.get(\"daily\",[])):.2f}')" 2>/dev/null || echo "?")
        echo "\$${today_cost} today"
        return
        ;;
      help|--help|-h)
        echo "atlas cost — Claude Code API cost analytics (reads session JSONL files)"
        echo ""
        echo "Subcommands: today | daily | weekly | monthly | session | sprint | status"
        echo "Options: --since YYYYMMDD | --json | --no-breakdown"
        echo ""
        echo "Data: $(find "${HOME}/.claude/projects/" -name '*.jsonl' 2>/dev/null | wc -l) session files"
        echo "Engine: ccusage (bun x ccusage@latest)"
        return
        ;;
      *) echo "Unknown: $subcmd. Use: today|daily|weekly|monthly|session|sprint|status|help"; return 1 ;;
    esac

    local mode="daily"
    [ "$subcmd" = "weekly" ] && mode="weekly"
    [ "$subcmd" = "monthly" ] && mode="monthly"
    [ "$subcmd" = "session" ] && mode="session"

    # shellcheck disable=SC2086
    bun x ccusage@latest "$mode" --breakdown $since_flag "$@" 2>/dev/null
  else
    echo "Cost tracking requires bun. Install: curl -fsSL https://bun.sh/install | bash"
    echo ""
    echo "Session files available: $(find "${HOME}/.claude/projects/" -name '*.jsonl' 2>/dev/null | wc -l)"
  fi
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
