#!/usr/bin/env bash
# ATLAS Execution Philosophy Engine — Dynamic effort-level heuristic
# ------------------------------------------------------------------
# Input : task description (argv or stdin)
# Output: single word on stdout — low | medium | high | xhigh | max | auto
# Exit  : 0 on success, 2 on usage error
#
# Contract: .blueprint/schemas/philosophy-engine-schema.md (section 6)
# Called  : hooks/effort-router (Sprint 3 — PreToolUse[Task|Agent])
# Policy  : advisory only — user may override via explicit `effort:` in agent
#           frontmatter or via CLI flag; router respects explicit > heuristic.
#
# Algorithm:
#   1. Read task text (arg or stdin), lower-case normalize
#   2. Count keyword matches per bucket (MAX|XHIGH|HIGH|MEDIUM|LOW)
#   3. Weighted score per bucket (match_count * weight)
#   4. Winner = bucket with highest score
#   5. Tie-break → bias toward higher bucket (Anthropic recommendation)
#   6. Zero matches in all buckets → `auto` (defer to CLI router)
#
# Bucket weights (Anthropic effort ladder):
#   MAX=5  XHIGH=4  HIGH=3  MEDIUM=2  LOW=1
#
# Usage:
#   effort-heuristic.sh "task description text"     # single arg
#   echo "task desc" | effort-heuristic.sh          # stdin
#   effort-heuristic.sh --help                      # usage
#   effort-heuristic.sh --explain "text"            # + stderr reasoning
#   effort-heuristic.sh --test                      # run embedded test suite

set -euo pipefail

# ----------------------------------------------------------------------------
# Keyword buckets (regex alternations — pipe-separated, case-insensitive)
# ----------------------------------------------------------------------------

# MAX (~15%) — architecture / research / novel problems / strategy
readonly KEYWORDS_MAX='architecture|design system|mega plan|ultrathink|15-section|15.section|novel problem|from scratch|greenfield|research|decision framework|tradeoff analysis|strategy|vision|roadmap'

# XHIGH (~25%) — debug / refactor / performance / security (Anthropic default for agentic/coding)
readonly KEYWORDS_XHIGH='debug|race condition|concurrent|multi-file|multi\.file|refactor|optimize|root cause|edge case|memory leak|performance|security audit|review code|migrate|migration'

# HIGH (~30%) — feature implementation / bugfix / integration (Sonnet complex default)
readonly KEYWORDS_HIGH='implement|write feature|feature|bug fix|bugfix|fix bug|fix the bug|add test|add feature|update|modify|integrate|connect|wire|build component|create component'

# MEDIUM (~20%) — review / documentation / explanation / formatting
readonly KEYWORDS_MEDIUM='review|document|explain|describe|summarize|list|rename|format|style|comment|clean up|cleanup|organize'

# LOW (~10%) — trivial / git ops / typos / simple file ops
readonly KEYWORDS_LOW='commit|push|tag release|bump version|bump|typo|whitespace|move file|delete file|archive|lint|grep|find|cat|ls '

# Weights (higher = more effort)
readonly WEIGHT_MAX=5
readonly WEIGHT_XHIGH=4
readonly WEIGHT_HIGH=3
readonly WEIGHT_MEDIUM=2
readonly WEIGHT_LOW=1

# ----------------------------------------------------------------------------
# Usage / help
# ----------------------------------------------------------------------------

usage() {
  cat <<'EOF'
effort-heuristic.sh — suggest effort level from task description

USAGE:
  effort-heuristic.sh "task description text"     Single arg
  echo "task desc" | effort-heuristic.sh          Stdin
  effort-heuristic.sh --explain "text"            Print matched keywords to stderr
  effort-heuristic.sh --test                      Run embedded test suite
  effort-heuristic.sh --help                      Show this message

OUTPUT:
  One word on stdout: low | medium | high | xhigh | max | auto

EXIT CODES:
  0  success
  2  usage error (missing input, bad flag)

EXAMPLES:
  $ effort-heuristic.sh "debug this race condition"
  xhigh
  $ echo "commit and push" | effort-heuristic.sh
  low
  $ effort-heuristic.sh --explain "design the system architecture"
  max
  [stderr] Matched: 3 MAX, 0 XHIGH, 0 HIGH, 0 MEDIUM, 0 LOW → winner=max (score=15)

INTEGRATION:
  Hook: hooks/effort-router (Sprint 3) — PreToolUse[Task|Agent]
  Schema: .blueprint/schemas/philosophy-engine-schema.md §6
EOF
}

# ----------------------------------------------------------------------------
# Core scoring
# ----------------------------------------------------------------------------

# count_matches <text_lower> <regex> → integer
# Counts each distinct match (grep -oE) of the alternation over the lower-cased text.
count_matches() {
  local text="$1"
  local regex="$2"
  local count
  # grep exits 1 when no matches — swallow via `|| true` so `set -e` doesn't trip.
  # Count distinct regex matches via `grep -oE` + `wc -l`.
  count=$(printf '%s' "$text" | grep -oiE "$regex" 2>/dev/null | wc -l | tr -d ' ' || true)
  printf '%s' "${count:-0}"
}

# classify <text> [<explain_flag>]
# Prints bucket name to stdout; if explain_flag == "1", prints reasoning to stderr.
classify() {
  local text_raw="$1"
  local explain="${2:-0}"

  # Normalize: lowercase (portable — tr works everywhere)
  local text
  text=$(printf '%s' "$text_raw" | tr '[:upper:]' '[:lower:]')

  # Count matches per bucket
  local n_max n_xhigh n_high n_medium n_low
  n_max=$(count_matches "$text" "$KEYWORDS_MAX")
  n_xhigh=$(count_matches "$text" "$KEYWORDS_XHIGH")
  n_high=$(count_matches "$text" "$KEYWORDS_HIGH")
  n_medium=$(count_matches "$text" "$KEYWORDS_MEDIUM")
  n_low=$(count_matches "$text" "$KEYWORDS_LOW")

  # Weighted scores
  local score_max=$(( n_max * WEIGHT_MAX ))
  local score_xhigh=$(( n_xhigh * WEIGHT_XHIGH ))
  local score_high=$(( n_high * WEIGHT_HIGH ))
  local score_medium=$(( n_medium * WEIGHT_MEDIUM ))
  local score_low=$(( n_low * WEIGHT_LOW ))

  # Total matches (any bucket)
  local total=$(( n_max + n_xhigh + n_high + n_medium + n_low ))

  local winner="auto"
  local win_score=0

  if [[ $total -eq 0 ]]; then
    winner="auto"
    win_score=0
  else
    # Pick bucket with highest score; tie-break → higher bucket (max > xhigh > high > medium > low)
    # Walk low → max with `>=` so equal scores from a higher bucket overwrite a lower one.
    # (total>0 here ensures at least one bucket has a positive score, so we won't stay at low:0.)
    winner="low"
    win_score=$score_low
    if (( score_medium >= win_score )); then winner="medium"; win_score=$score_medium; fi
    if (( score_high >= win_score )); then winner="high"; win_score=$score_high; fi
    if (( score_xhigh >= win_score )); then winner="xhigh"; win_score=$score_xhigh; fi
    if (( score_max >= win_score )); then winner="max"; win_score=$score_max; fi
  fi

  # Emit reasoning to stderr if requested
  if [[ "$explain" == "1" ]]; then
    {
      echo "effort-heuristic: input (truncated 120c): ${text_raw:0:120}"
      echo "Matched: ${n_max} MAX, ${n_xhigh} XHIGH, ${n_high} HIGH, ${n_medium} MEDIUM, ${n_low} LOW"
      echo "Scores : MAX=${score_max} XHIGH=${score_xhigh} HIGH=${score_high} MEDIUM=${score_medium} LOW=${score_low}"
      echo "Winner : ${winner} (score=${win_score})"
    } >&2
  fi

  printf '%s\n' "$winner"
}

# ----------------------------------------------------------------------------
# Embedded self-tests
# ----------------------------------------------------------------------------

run_tests() {
  local pass=0 fail=0
  local input expected actual

  # Test cases: input | expected
  local -a cases=(
    "debug this race condition in the auth middleware|xhigh"
    "commit and push to main|low"
    "implement new feature for user authentication|high"
    "design the system architecture for v6.0|max"
    "hello world|auto"
    # Additional edge cases
    "refactor the auth pipeline and add MFA|xhigh"
    "rename variable in the file|medium"
    "bump version and push tag|low"
    "ultrathink the decision framework and mega plan|max"
    "fix bug in the login form|high"
    "review this code for correctness|medium"
    "root cause the memory leak|xhigh"
    "greenfield architecture for new service|max"
    "lint and format the module|medium"
    "grep for TODOs|low"
  )

  echo "Running $(( ${#cases[@]} )) test cases..."
  for case in "${cases[@]}"; do
    input="${case%%|*}"
    expected="${case##*|}"
    actual=$(classify "$input" 0)
    if [[ "$actual" == "$expected" ]]; then
      pass=$(( pass + 1 ))
      printf '  PASS  %-60s → %s\n' "${input:0:58}" "$actual"
    else
      fail=$(( fail + 1 ))
      printf '  FAIL  %-60s → got=%s expected=%s\n' "${input:0:58}" "$actual" "$expected"
    fi
  done

  echo ""
  echo "Results: ${pass} PASS, ${fail} FAIL (total $(( pass + fail )))"
  if [[ $fail -eq 0 ]]; then
    return 0
  else
    return 1
  fi
}

# ----------------------------------------------------------------------------
# Main dispatch
# ----------------------------------------------------------------------------

main() {
  local explain=0
  local text=""

  # Parse flags
  case "${1:-}" in
    -h|--help)
      usage
      return 0
      ;;
    --test)
      run_tests
      return $?
      ;;
    --explain)
      explain=1
      shift
      if [[ $# -gt 0 ]]; then
        text="$*"
      elif [[ ! -t 0 ]]; then
        text=$(cat)
      else
        echo "ERROR: --explain requires text arg or stdin" >&2
        return 2
      fi
      ;;
    "")
      # No args — try stdin
      if [[ ! -t 0 ]]; then
        text=$(cat)
      else
        echo "ERROR: no input (arg or stdin required)" >&2
        usage >&2
        return 2
      fi
      ;;
    *)
      text="$*"
      ;;
  esac

  if [[ -z "${text// }" ]]; then
    echo "ERROR: empty input" >&2
    return 2
  fi

  classify "$text" "$explain"
}

main "$@"
