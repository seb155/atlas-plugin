#!/usr/bin/env bash
# hard-gate-linter.sh — Philosophy Engine v6.0 skill validator
#
# Purpose:
#   Validates Tier-1 skills against the <HARD-GATE> + <red-flags> contract
#   defined in .blueprint/schemas/philosophy-engine-schema.md.
#
# Integration:
#   - build.sh: call during validate_frontmatter_v6 phase OR new validation step.
#     Example: ./scripts/execution-philosophy/hard-gate-linter.sh all || exit 1
#   - hooks/pre-commit-lint (future Sprint 2+): invoke on staged SKILL.md files.
#
# Usage:
#   hard-gate-linter.sh <skill_path>      Check single skill file
#   hard-gate-linter.sh all               Check all Tier-1 skills
#   hard-gate-linter.sh --list-tier-1     List Tier-1 skills from plan v6.0
#   hard-gate-linter.sh --help            Print usage
#
# Exit codes:
#   0 = all checks passed
#   1 = violation(s) detected (details to stderr)
#   2 = usage error
#
# Validation layers (L1-L10):
#   L1  File exists + readable
#   L2  Valid YAML frontmatter (--- delimiters)
#   L3  superpowers_pattern key present with valid values
#   L4  hard_gate in pattern => <HARD-GATE> open+close tags present
#   L5  <HARD-GATE> content >= 20 chars non-empty
#   L6  red_flags in pattern => <red-flags> block with Thought|Reality headers
#   L7  <red-flags> table has >=3 rows
#   L8  HARD-GATE statement matches iron-laws.yaml law statement (fuzzy 80%+)
#   L9  HARD-GATE avoids ambiguous tokens (should/consider/maybe) — warn only
#   L10 File line count < 500 — warn only
#
set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
readonly IRON_LAWS_YAML="${SCRIPT_DIR}/iron-laws.yaml"

# Tier-1 skills: logical_name|relative_path (colon-separated pairs)
# verification-before-completion is aliased to skills/verification/SKILL.md
# (see plan v6.0 Sprint 2 Task 2.4 list).
readonly TIER1_SKILLS=(
  "tdd:skills/tdd/SKILL.md"
  "systematic-debugging:skills/systematic-debugging/SKILL.md"
  "plan-builder:skills/plan-builder/SKILL.md"
  "verification-before-completion:skills/verification/SKILL.md"
  "code-review:skills/code-review/SKILL.md"
  "brainstorming:skills/brainstorming/SKILL.md"
  "context-discovery:skills/context-discovery/SKILL.md"
  "scope-check:skills/scope-check/SKILL.md"
  "subagent-dispatch:skills/subagent-dispatch/SKILL.md"
  "enterprise-audit:skills/enterprise-audit/SKILL.md"
)

# Color helpers (only if stdout is a TTY)
if [[ -t 1 ]]; then
  readonly RED=$'\033[0;31m'
  readonly GREEN=$'\033[0;32m'
  readonly YELLOW=$'\033[0;33m'
  readonly CYAN=$'\033[0;36m'
  readonly RESET=$'\033[0m'
else
  readonly RED="" GREEN="" YELLOW="" CYAN="" RESET=""
fi

# Accumulators (globals set inside lint_skill / print_summary)
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0
FAILED_SKILLS=()

usage() {
  cat <<EOF
hard-gate-linter.sh — Philosophy Engine v6.0 validator

Usage:
  ${0##*/} <skill_path>       Check one SKILL.md (absolute or repo-relative)
  ${0##*/} all                Check all Tier-1 skills (plan v6.0 Sprint 2)
  ${0##*/} --list-tier-1      Print Tier-1 skill names + paths
  ${0##*/} --help             Show this help

Exit codes:
  0  all lint checks passed
  1  at least one violation detected
  2  usage error (bad args, file not found in single-skill mode)

Tier-1 skills validated by 'all' mode:
  tdd, systematic-debugging, plan-builder, verification-before-completion,
  code-review, brainstorming, context-discovery, scope-check,
  subagent-dispatch, enterprise-audit

Validation layers: L1 (file readable), L2 (YAML frontmatter),
L3 (superpowers_pattern), L4 (<HARD-GATE> tags), L5 (content length),
L6 (<red-flags> table), L7 (>=3 rows), L8 (iron-laws match),
L9 (ambiguous language — warn), L10 (line count <500 — warn).

See .blueprint/schemas/philosophy-engine-schema.md for full contract.
EOF
}

list_tier1() {
  printf "%s\n" "${CYAN}Tier-1 Skills (plan v6.0 Sprint 2 Task 2.4):${RESET}"
  for entry in "${TIER1_SKILLS[@]}"; do
    local name="${entry%%:*}"
    local path="${entry#*:}"
    printf "  - %-35s -> %s\n" "$name" "$path"
  done
}

# Extract frontmatter block (between first two '---' lines) to stdout.
# Exit 0 if frontmatter found, 1 otherwise.
extract_frontmatter() {
  local file="$1"
  awk '
    BEGIN { state=0 }
    /^---[[:space:]]*$/ {
      if (state==0) { state=1; next }
      else if (state==1) { state=2; exit }
    }
    state==1 { print }
  ' "$file"
}

# Extract skill body (content after closing frontmatter ---) to stdout.
extract_body() {
  local file="$1"
  awk '
    BEGIN { state=0 }
    /^---[[:space:]]*$/ {
      if (state==0) { state=1; next }
      else if (state==1) { state=2; next }
    }
    state==2 { print }
  ' "$file"
}

# Lowercase helper (portable, no ${var,,} dependence)
to_lower() {
  printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

# Fuzzy similarity between two strings — percent of shared words (>=3 chars).
# Returns integer 0-100 on stdout. Used by L8.
fuzzy_match_pct() {
  local a="$1"
  local b="$2"
  local words_a words_b total shared pct
  words_a=$(printf "%s" "$a" | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]' '\n' | awk 'length($0)>=3' | sort -u)
  words_b=$(printf "%s" "$b" | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]' '\n' | awk 'length($0)>=3' | sort -u)
  if [[ -z "$words_a" || -z "$words_b" ]]; then
    printf "0"
    return
  fi
  total=$(printf "%s\n%s\n" "$words_a" "$words_b" | sort -u | wc -l)
  shared=$(comm -12 <(printf "%s\n" "$words_a") <(printf "%s\n" "$words_b") | wc -l)
  if [[ "$total" -eq 0 ]]; then
    printf "0"
  else
    pct=$(( shared * 100 / total ))
    printf "%d" "$pct"
  fi
}

# Extract all law statements from iron-laws.yaml as newline-separated blocks
# (one statement per line, pipes collapsed). Returns empty if file missing.
load_iron_law_statements() {
  [[ -f "$IRON_LAWS_YAML" ]] || return 0
  awk '
    /^[[:space:]]*statement:[[:space:]]*\|/  { collecting=1; indent=""; next }
    /^[[:space:]]*signature:[[:space:]]*\|/  { collecting=1; indent=""; next }
    collecting==1 {
      if ($0 ~ /^[[:space:]]*[a-z_]+:/) { collecting=0; printf "\n"; next }
      if (indent=="") { match($0, /^[[:space:]]*/); indent=substr($0, RSTART, RLENGTH) }
      line=$0
      sub("^"indent, "", line)
      printf "%s ", line
    }
    END { if (collecting) printf "\n" }
  ' "$IRON_LAWS_YAML"
}

# Lint one skill file. Globals: TOTAL/PASSED/FAILED/WARNINGS/FAILED_SKILLS.
# $1 = logical name (for display)
# $2 = skill file path (absolute)
# Returns 0 if skill passes all errors (warnings still OK), 1 otherwise.
lint_skill() {
  # $1 = logical skill name (reserved for future messaging — currently unused)
  local _logical="$1"
  local file="$2"
  local rel="${file#"$REPO_ROOT"/}"
  local errors=0
  local warns_local=0

  TOTAL=$((TOTAL + 1))
  printf "%s Linting: %s%s%s\n" "🔍" "$CYAN" "$rel" "$RESET"

  # ---- L1: file exists + readable
  if [[ ! -f "$file" || ! -r "$file" ]]; then
    printf "  %s✗ L1 FAIL:%s file missing or unreadable\n" "$RED" "$RESET" >&2
    FAILED=$((FAILED + 1))
    FAILED_SKILLS+=("${rel}: L1 file unreadable")
    return 1
  fi

  local frontmatter body
  frontmatter=$(extract_frontmatter "$file" 2>/dev/null || true)
  body=$(extract_body "$file" 2>/dev/null || true)

  # ---- L2: valid YAML frontmatter present
  if [[ -z "$frontmatter" ]]; then
    printf "  %s✗ L2 FAIL:%s missing or empty YAML frontmatter (no --- delimiters)\n" \
      "$RED" "$RESET" >&2
    errors=$((errors + 1))
  fi

  # ---- L3: superpowers_pattern key presence + values
  local pattern_line pattern_value=""
  pattern_line=$(printf "%s\n" "$frontmatter" | grep -E '^superpowers_pattern:' | head -1 || true)
  if [[ -z "$pattern_line" ]]; then
    printf "  %s✗ L3 FAIL:%s frontmatter missing 'superpowers_pattern:' key\n" \
      "$RED" "$RESET" >&2
    errors=$((errors + 1))
  else
    pattern_value="${pattern_line#superpowers_pattern:}"
    pattern_value=$(printf "%s" "$pattern_value" | tr -d '[]"' | tr ',' ' ')
  fi

  local pattern_lower
  pattern_lower=$(to_lower "$pattern_value")

  local needs_hard_gate=0 needs_red_flags=0
  [[ "$pattern_lower" =~ hard_gate ]] && needs_hard_gate=1
  [[ "$pattern_lower" =~ red_flags ]] && needs_red_flags=1

  # ---- L4: <HARD-GATE> open + close tags required if declared
  local hg_open=0 hg_close=0
  hg_open=$(printf "%s\n" "$body" | grep -c '^<HARD-GATE>' || true)
  hg_close=$(printf "%s\n" "$body" | grep -c '^</HARD-GATE>' || true)
  if [[ "$needs_hard_gate" -eq 1 ]]; then
    if [[ "$hg_open" -lt 1 || "$hg_close" -lt 1 ]]; then
      printf "  %s✗ L4 FAIL:%s superpowers_pattern declares hard_gate but <HARD-GATE> tags missing (open=%d, close=%d)\n" \
        "$RED" "$RESET" "$hg_open" "$hg_close" >&2
      errors=$((errors + 1))
    fi
  else
    if [[ "$hg_open" -gt 0 || "$hg_close" -gt 0 ]]; then
      printf "  %s✗ L4 FAIL:%s <HARD-GATE> tags present but superpowers_pattern does not declare hard_gate\n" \
        "$RED" "$RESET" >&2
      errors=$((errors + 1))
    fi
  fi

  # ---- L5: HARD-GATE content length >= 20 chars (non-whitespace)
  # hg_content keeps the original text with spaces/newlines (used by L8 fuzzy match + L9).
  # hg_content_stripped drops all whitespace — used for the length gate only.
  local hg_content="" hg_content_stripped=""
  if [[ "$hg_open" -ge 1 && "$hg_close" -ge 1 ]]; then
    hg_content=$(printf "%s\n" "$body" \
      | awk '/^<HARD-GATE>/{flag=1; next} /^<\/HARD-GATE>/{flag=0} flag')
    hg_content_stripped=$(printf "%s" "$hg_content" | tr -d '\n\r\t ')
    if [[ "${#hg_content_stripped}" -lt 20 ]]; then
      printf "  %s✗ L5 FAIL:%s <HARD-GATE> content is %d chars (need >=20 non-whitespace)\n" \
        "$RED" "$RESET" "${#hg_content_stripped}" >&2
      errors=$((errors + 1))
    fi
  fi

  # ---- L6: <red-flags> block with Thought|Reality headers when declared
  local rf_open rf_close header_ok=0
  rf_open=$(printf "%s\n" "$body" | grep -c '^<red-flags>' || true)
  rf_close=$(printf "%s\n" "$body" | grep -c '^</red-flags>' || true)
  if [[ "$needs_red_flags" -eq 1 ]]; then
    if [[ "$rf_open" -lt 1 || "$rf_close" -lt 1 ]]; then
      printf "  %s✗ L6 FAIL:%s pattern declares red_flags but <red-flags> block missing (open=%d, close=%d)\n" \
        "$RED" "$RESET" "$rf_open" "$rf_close" >&2
      errors=$((errors + 1))
    else
      if printf "%s\n" "$body" \
        | awk '/^<red-flags>/{flag=1; next} /^<\/red-flags>/{flag=0} flag' \
        | grep -Eq '^\|[[:space:]]*Thought[[:space:]]*\|[[:space:]]*Reality[[:space:]]*\|'; then
        header_ok=1
      else
        printf "  %s✗ L6 FAIL:%s <red-flags> missing header row '| Thought | Reality |'\n" \
          "$RED" "$RESET" >&2
        errors=$((errors + 1))
      fi
    fi
  fi

  # ---- L7: >=3 data rows in red-flags table
  if [[ "$needs_red_flags" -eq 1 && "$header_ok" -eq 1 ]]; then
    local row_count
    row_count=$(printf "%s\n" "$body" \
      | awk '/^<red-flags>/{flag=1; next} /^<\/red-flags>/{flag=0} flag' \
      | grep -E '^\|' | grep -Ev '^\|[[:space:]]*Thought' | grep -cEv '^\|[-: |]+\|')
    if [[ "$row_count" -lt 3 ]]; then
      printf "  %s✗ L7 FAIL:%s <red-flags> table has %d rows (need >=3)\n" \
        "$RED" "$RESET" "$row_count" >&2
      errors=$((errors + 1))
    fi
  fi

  # ---- L8: HARD-GATE statement matches an iron-laws.yaml law (fuzzy >=80%)
  if [[ "$needs_hard_gate" -eq 1 && -n "$hg_content" && -f "$IRON_LAWS_YAML" ]]; then
    local statements best_pct=0
    statements=$(load_iron_law_statements)
    if [[ -n "$statements" ]]; then
      while IFS= read -r stmt; do
        [[ -z "$stmt" ]] && continue
        local pct
        pct=$(fuzzy_match_pct "$hg_content" "$stmt")
        (( pct > best_pct )) && best_pct=$pct
      done <<< "$statements"
      if (( best_pct >= 80 )); then
        printf "  %s✓ L8 match:%s iron-laws.yaml (%d%% similarity)\n" \
          "$GREEN" "$RESET" "$best_pct"
      else
        printf "  %s⚠ L8 warning:%s HARD-GATE best fuzzy match to iron-laws.yaml = %d%% (target >=80%%)\n" \
          "$YELLOW" "$RESET" "$best_pct" >&2
        warns_local=$((warns_local + 1))
      fi
    fi
  elif [[ "$needs_hard_gate" -eq 1 && ! -f "$IRON_LAWS_YAML" ]]; then
    printf "  %s⚠ L8 skipped:%s iron-laws.yaml not found (Task 2.1 pending)\n" \
      "$YELLOW" "$RESET"
    warns_local=$((warns_local + 1))
  fi

  # ---- L9: ambiguous language inside HARD-GATE — warn only
  if [[ -n "$hg_content" ]]; then
    local ambiguous_hits
    ambiguous_hits=$(printf "%s\n" "$body" \
      | awk '/^<HARD-GATE>/{flag=1; next} /^<\/HARD-GATE>/{flag=0} flag' \
      | grep -Eoi '\b(should|consider|maybe|perhaps|might)\b' | sort -u | tr '\n' ',' | sed 's/,$//')
    if [[ -n "$ambiguous_hits" ]]; then
      printf "  %s⚠ L9 warning:%s <HARD-GATE> contains ambiguous tokens: %s\n" \
        "$YELLOW" "$RESET" "$ambiguous_hits"
      warns_local=$((warns_local + 1))
    fi
  fi

  # ---- L10: file line count < 500 — warn only
  local line_count
  line_count=$(wc -l < "$file")
  if (( line_count >= 500 )); then
    printf "  %s⚠ L10 warning:%s %d lines (target <500 for v6)\n" \
      "$YELLOW" "$RESET" "$line_count"
    warns_local=$((warns_local + 1))
  fi

  WARNINGS=$((WARNINGS + warns_local))

  if (( errors == 0 )); then
    printf "  %s✓ L1-L7 passed%s" "$GREEN" "$RESET"
    (( warns_local > 0 )) && printf " (%d warning(s))" "$warns_local"
    printf "\n"
    PASSED=$((PASSED + 1))
    return 0
  else
    printf "  %s✗ %d error(s)%s\n" "$RED" "$errors" "$RESET" >&2
    FAILED=$((FAILED + 1))
    FAILED_SKILLS+=("${rel}: ${errors} error(s)")
    return 1
  fi
}

# Print summary across all lints. Returns 0 if all green, 1 otherwise.
print_summary() {
  printf "\n"
  printf "%s📊 Summary:%s %d/%d skills passed" "$CYAN" "$RESET" "$PASSED" "$TOTAL"
  (( FAILED > 0 )) && printf ", %s%d failed%s" "$RED" "$FAILED" "$RESET"
  (( WARNINGS > 0 )) && printf ", %s%d warning(s)%s" "$YELLOW" "$WARNINGS" "$RESET"
  printf "\n"

  if (( ${#FAILED_SKILLS[@]} > 0 )); then
    printf "\n%sFailed skills:%s\n" "$RED" "$RESET"
    local s
    for s in "${FAILED_SKILLS[@]}"; do
      printf "  %s❌%s %s\n" "$RED" "$RESET" "$s"
    done
  fi

  (( FAILED == 0 ))
}

main() {
  if [[ $# -eq 0 ]]; then
    usage >&2
    return 2
  fi

  case "${1:-}" in
    --help|-h)
      usage
      return 0
      ;;
    --list-tier-1)
      list_tier1
      return 0
      ;;
    all)
      local entry name rel abs
      for entry in "${TIER1_SKILLS[@]}"; do
        name="${entry%%:*}"
        rel="${entry#*:}"
        abs="${REPO_ROOT}/${rel}"
        lint_skill "$name" "$abs" || true
      done
      if print_summary; then
        return 0
      else
        return 1
      fi
      ;;
    -*)
      printf "Unknown flag: %s\n\n" "$1" >&2
      usage >&2
      return 2
      ;;
    *)
      # Single skill mode
      local arg="$1"
      local abs
      if [[ -f "$arg" ]]; then
        abs="$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"
      elif [[ -f "${REPO_ROOT}/${arg}" ]]; then
        abs="${REPO_ROOT}/${arg}"
      else
        printf "Error: skill file not found: %s\n" "$arg" >&2
        return 2
      fi
      lint_skill "$(basename "$(dirname "$abs")")" "$abs" || true
      if print_summary; then
        return 0
      else
        return 1
      fi
      ;;
  esac
}

main "$@"
