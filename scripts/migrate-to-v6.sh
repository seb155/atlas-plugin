#!/usr/bin/env bash
# ATLAS Migration Helper v5.x -> v6.0
# -----------------------------------
# Audits a user's ATLAS install and reports per-step migration status.
# NON-DESTRUCTIVE: never modifies files. Suggestions only.
#
# Usage:
#   ./scripts/migrate-to-v6.sh           # default audit
#   ./scripts/migrate-to-v6.sh --verbose # show every offender
#   ./scripts/migrate-to-v6.sh --help    # show this help
#
# Exit codes:
#   0  audit complete (no required failures)
#   1  required step failed (extended thinking refs detected)
#   2  bad usage
#
# See: MIGRATION-V5-TO-V6.md for the full guide.

set -uo pipefail   # NOTE: no -e (we want to keep going on per-step failures)

# ── Constants ───────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$PLUGIN_ROOT/VERSION"
SETTINGS="$HOME/.claude/settings.json"
TARGET_VERSION="6.0.0-alpha.1"

CURRENT_VERSION="unknown"
[ -f "$VERSION_FILE" ] && CURRENT_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")

VERBOSE=false

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────────────────
banner() { printf "\n${BOLD}${CYAN}%s${NC}\n" "$*"; }
info()   { printf "${CYAN}i${NC}  %s\n" "$*"; }
ok()     { printf "  ${GREEN}OK${NC}    %s\n" "$*"; }
warn()   { printf "  ${YELLOW}WARN${NC}  %s\n" "$*"; }
fail()   { printf "  ${RED}FAIL${NC}  %s\n" "$*"; }
hint()   { printf "  ${DIM}->${NC}    %s\n" "$*"; }

usage() {
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

# ── Args ────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=true ;;
    -h|--help)    usage 0 ;;
    *) printf "Unknown arg: %s\n\n" "$arg" >&2; usage 2 ;;
  esac
done

# ── Header ──────────────────────────────────────────────────────────
banner "ATLAS Migration Audit  (v5.x -> ${TARGET_VERSION})"
info "Plugin root  : $PLUGIN_ROOT"
info "Current ver  : $CURRENT_VERSION"
info "Target ver   : $TARGET_VERSION"
info "Settings.json: $SETTINGS"

# Track required-failure to set exit code at the end
REQUIRED_FAIL=0

# ── Step 1: Extended thinking deprecation (REQUIRED) ────────────────
banner "Step 1: Extended thinking deprecation (REQUIRED, BREAKING)"

# Search hooks/, skills/, scripts/, agents/ for live references.
# Patterns to flag:
#   - thinking with type=enabled (API client config)
#   - budget_tokens (extended-thinking-only key)
#   - thinking_mode: extended (frontmatter v5.x artifact)
SEARCH_DIRS=()
for d in hooks skills scripts agents commands; do
  [ -d "$PLUGIN_ROOT/$d" ] && SEARCH_DIRS+=("$PLUGIN_ROOT/$d")
done

if [ ${#SEARCH_DIRS[@]} -eq 0 ]; then
  warn "No search directories found under $PLUGIN_ROOT"
else
  HITS=$(grep -rEn 'thinking[^[:alnum:]_].{0,40}type[^[:alnum:]_].{0,12}enabled|budget_tokens|thinking_mode:[[:space:]]*extended' \
            "${SEARCH_DIRS[@]}" 2>/dev/null \
            | grep -v 'MIGRATION-V5-TO-V6' \
            | grep -v 'migrate-to-v6.sh' \
            | grep -v 'CHANGELOG' || true)

  if [ -z "$HITS" ]; then
    ok "Zero extended-thinking references in user code"
  else
    COUNT=$(printf "%s\n" "$HITS" | wc -l | tr -d ' ')
    fail "Found $COUNT extended-thinking reference(s)"
    REQUIRED_FAIL=1
    if $VERBOSE; then
      printf "%s\n" "$HITS" | sed 's/^/        /'
    else
      printf "%s\n" "$HITS" | head -5 | sed 's/^/        /'
      [ "$COUNT" -gt 5 ] && hint "(${COUNT} total — rerun with --verbose to see all)"
    fi
    hint "Replace with thinking_mode: adaptive in frontmatter, OR delete the API config block"
    hint "See MIGRATION-V5-TO-V6.md Step 1"
  fi
fi

# ── Step 2: Agent visibility env vars (RECOMMENDED) ─────────────────
banner "Step 2: Agent visibility env vars (RECOMMENDED)"

if [ ! -f "$SETTINGS" ]; then
  warn "settings.json not found at $SETTINGS"
  hint "Create it with the env block below"
  SETTINGS_PRESENT=false
else
  SETTINGS_PRESENT=true
fi

EXPECTED_VARS=(ATLAS_AUTO_TAIL_AGENTS ATLAS_MAX_TAIL_PANES ATLAS_AGENT_STATUS_INTERVAL)
MISSING_VARS=()

for v in "${EXPECTED_VARS[@]}"; do
  if $SETTINGS_PRESENT && grep -q "\"$v\"" "$SETTINGS" 2>/dev/null; then
    ok "$v present"
  else
    MISSING_VARS+=("$v")
  fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  warn "Missing ${#MISSING_VARS[@]} env var(s) in settings.json"
  hint "Add to the \"env\" block in $SETTINGS:"
  cat <<'PATCH' | sed 's/^/        /'
"ATLAS_AUTO_TAIL_AGENTS": "1",
"ATLAS_MAX_TAIL_PANES": "2",
"ATLAS_AGENT_STATUS_INTERVAL": "2"
PATCH
fi

# ── Step 3: Frontmatter v6 audit (RECOMMENDED) ──────────────────────
banner "Step 3: Frontmatter v6 schema (RECOMMENDED)"

# Lightweight YAML check via grep — counts skills missing v6 keys.
SKILLS_DIR="$PLUGIN_ROOT/skills"
if [ ! -d "$SKILLS_DIR" ]; then
  warn "No skills/ directory under $PLUGIN_ROOT — skipping"
else
  TOTAL=$(find "$SKILLS_DIR" -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' ')
  MISS_THINK=0
  MISS_PATTERN=0
  MISS_VERSION=0

  while IFS= read -r f; do
    head -50 "$f" 2>/dev/null | grep -q '^thinking_mode:' || MISS_THINK=$((MISS_THINK+1))
    head -50 "$f" 2>/dev/null | grep -q '^superpowers_pattern:' || MISS_PATTERN=$((MISS_PATTERN+1))
    head -50 "$f" 2>/dev/null | grep -q '^version:' || MISS_VERSION=$((MISS_VERSION+1))
  done < <(find "$SKILLS_DIR" -name SKILL.md -type f 2>/dev/null)

  info "Audited $TOTAL SKILL.md files"
  if [ "$MISS_THINK" -eq 0 ] && [ "$MISS_PATTERN" -eq 0 ] && [ "$MISS_VERSION" -eq 0 ]; then
    ok "All skills have v6 frontmatter keys"
  else
    [ "$MISS_THINK"   -gt 0 ] && warn "$MISS_THINK/$TOTAL skills missing 'thinking_mode:'"
    [ "$MISS_PATTERN" -gt 0 ] && warn "$MISS_PATTERN/$TOTAL skills missing 'superpowers_pattern:'"
    [ "$MISS_VERSION" -gt 0 ] && warn "$MISS_VERSION/$TOTAL skills missing 'version:'"
    hint "Backward compat: defaults preserved. Add keys for explicit v6 conformance."
    hint "See MIGRATION-V5-TO-V6.md Step 3a"
  fi
fi

# ── Step 4: Philosophy Engine adoption (OPTIONAL) ───────────────────
banner "Step 4: Philosophy Engine adoption (OPTIONAL)"

PHILO_DIR="$PLUGIN_ROOT/scripts/execution-philosophy"
LINTER="$PHILO_DIR/hard-gate-linter.sh"
IRON_LAWS="$PHILO_DIR/iron-laws.yaml"

if [ ! -f "$IRON_LAWS" ]; then
  warn "Iron Laws corpus not found at $IRON_LAWS"
  hint "Reinstall v6.0.0-alpha.1 plugin to get scripts/execution-philosophy/"
else
  ok "Iron Laws corpus present ($(grep -c '^  - id:' "$IRON_LAWS" 2>/dev/null || echo 0) laws)"
fi

if [ ! -x "$LINTER" ]; then
  warn "hard-gate-linter.sh not found or not executable"
  hint "chmod +x $LINTER"
else
  ok "hard-gate-linter.sh ready"
fi

# Count Tier-1 skills with HARD-GATE blocks
HARD_GATE_COUNT=0
if [ -d "$SKILLS_DIR" ]; then
  HARD_GATE_COUNT=$(grep -rl '<HARD-GATE' "$SKILLS_DIR"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
fi
info "Skills with <HARD-GATE> blocks: $HARD_GATE_COUNT"
[ "$HARD_GATE_COUNT" -lt 5 ] && hint "Recommend Tier-1 skills (tdd, debugging, code-review, planning, verification) adopt HARD-GATE — see MIGRATION-V5-TO-V6.md Step 4"

# ── Step 5: Effort + task budget audit (OPTIONAL) ───────────────────
banner "Step 5: Effort + task budgets (OPTIONAL)"

AGENTS_DIR="$PLUGIN_ROOT/agents"
if [ ! -d "$AGENTS_DIR" ]; then
  info "No agents/ directory — skipping"
else
  AGENT_TOTAL=$(find "$AGENTS_DIR" -name AGENT.md -type f 2>/dev/null | wc -l | tr -d ' ')
  MISS_EFFORT=0
  MISS_BUDGET=0
  while IFS= read -r f; do
    head -30 "$f" 2>/dev/null | grep -q '^effort:' || MISS_EFFORT=$((MISS_EFFORT+1))
    head -30 "$f" 2>/dev/null | grep -q '^task_budget:' || MISS_BUDGET=$((MISS_BUDGET+1))
  done < <(find "$AGENTS_DIR" -name AGENT.md -type f 2>/dev/null)

  info "Audited $AGENT_TOTAL AGENT.md files"
  if [ "$MISS_EFFORT" -eq 0 ]; then
    ok "All agents have explicit 'effort:' key"
  else
    warn "$MISS_EFFORT/$AGENT_TOTAL agents missing 'effort:' (will default per CLI router)"
  fi
  info "$MISS_BUDGET/$AGENT_TOTAL agents have no 'task_budget:' (no advisory cap — fine if intentional)"
fi

# Check for new v6 hooks installed
banner "Bonus: SOTA hooks check (v6.0 new)"
for hook in inject-meta-skill pre-compact-sota-context session-end-retro effort-router; do
  if [ -x "$PLUGIN_ROOT/hooks/$hook" ]; then
    ok "hooks/$hook installed + executable"
  else
    warn "hooks/$hook missing or not executable"
  fi
done

# ── Summary ─────────────────────────────────────────────────────────
banner "Migration Summary"
if [ "$REQUIRED_FAIL" -eq 1 ]; then
  fail "Required step(s) failed — fix before upgrading to v6.0"
  printf "${RED}%s${NC}\n" "Exit code: 1"
  exit 1
fi

ok "All required steps passed"
hint "Recommended steps: address WARN entries above for full v6.0 conformance"
hint "Optional steps: adopt Philosophy Engine + tune effort/budgets at your pace"
hint "Full guide: MIGRATION-V5-TO-V6.md"
exit 0
