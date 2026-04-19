#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# ATLAS — validate-plugin-json.sh (REC-008)
# Lints .claude-plugin/plugin.json and marketplace.json against the
# canonical Anthropic schema (docs: plugin-dev/skills/plugin-structure/
# references/manifest-reference.md).
#
# Usage:
#   ./validate-plugin-json.sh               # scan default paths
#   ./validate-plugin-json.sh <file.json>   # check a specific file
#   ./validate-plugin-json.sh --fix         # interactive fix mode (future)
#
# Exit codes:
#   0 = all valid
#   1 = warnings only (style issues, non-blocking)
#   2 = errors found (schema violations, blocking)
#   3 = tool error (missing jq, python3, etc.)
#
# Checks (Anthropic canonical — manifest-reference.md):
#   name       → kebab-case regex /^[a-z][a-z0-9]*(-[a-z0-9]+)*$/
#   version    → SemVer MAJOR.MINOR.PATCH with optional pre-release
#   description → length 50-200 chars recommended
#   author     → object {name, email?} OR string (both accepted)
#   license    → present (any SPDX identifier OR "UNLICENSED")
#
# Reference: ADR-011 (description convention), ADR-013 (security)
# Source: .blueprint/reports/atlas-benchmark-matrix-2026-04-19.md (REC-008)
# ─────────────────────────────────────────────────────────────────────

set -uo pipefail

# ── Colors ──
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  RED=''; YEL=''; GRN=''; BLD=''; RST=''
else
  RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; BLD=$'\033[1m'; RST=$'\033[0m'
fi

# ── Counters ──
ERRORS=0
WARNINGS=0
CHECKED=0

# ── Tools ──
if ! command -v jq >/dev/null 2>&1; then
  echo "${RED}[error]${RST} jq not found. Install via: apt install jq" >&2
  exit 3
fi

# ── Regexes ──
NAME_RE='^[a-z][a-z0-9]*(-[a-z0-9]+)*$'
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$'

# ── Check single plugin.json-style object ──
# Arg 1: file path (for reporting)
# Arg 2: jq filter to extract object (e.g., ".", or ".plugins[0]")
check_plugin_object() {
  local file="$1"
  local jq_path="$2"
  local obj_label="${3:-$file}"

  local name version description author license
  name=$(jq -r "${jq_path}.name // empty" "$file" 2>/dev/null)
  version=$(jq -r "${jq_path}.version // empty" "$file" 2>/dev/null)
  description=$(jq -r "${jq_path}.description // empty" "$file" 2>/dev/null)
  author=$(jq -r "${jq_path}.author // empty | if type == \"string\" then . else (.name // \"\") + \" <\" + (.email // \"\") + \">\" end" "$file" 2>/dev/null)
  license=$(jq -r "${jq_path}.license // empty" "$file" 2>/dev/null)

  echo ""
  echo "${BLD}→ ${obj_label}${RST}"
  ((CHECKED++))

  # name
  if [[ -z "$name" ]]; then
    echo "  ${RED}❌ name:${RST} missing (required)"
    ((ERRORS++))
  elif ! [[ "$name" =~ $NAME_RE ]]; then
    echo "  ${RED}❌ name:${RST} \"$name\" does not match kebab-case regex $NAME_RE"
    ((ERRORS++))
  else
    echo "  ${GRN}✓ name:${RST} \"$name\""
  fi

  # version (not required for marketplace.json top-level, only per-plugin entry)
  if [[ -n "$version" ]]; then
    if ! [[ "$version" =~ $SEMVER_RE ]]; then
      echo "  ${RED}❌ version:${RST} \"$version\" not SemVer (expected MAJOR.MINOR.PATCH[-prerelease])"
      ((ERRORS++))
    else
      echo "  ${GRN}✓ version:${RST} \"$version\""
    fi
  fi

  # description — 50-200 chars recommended
  if [[ -z "$description" ]]; then
    echo "  ${RED}❌ description:${RST} missing (required)"
    ((ERRORS++))
  else
    local desc_len=${#description}
    if [[ "$desc_len" -lt 50 ]]; then
      echo "  ${YEL}⚠ description:${RST} ${desc_len} chars (recommend 50-200). \"$description\""
      ((WARNINGS++))
    elif [[ "$desc_len" -gt 200 ]]; then
      echo "  ${YEL}⚠ description:${RST} ${desc_len} chars (recommend 50-200)."
      ((WARNINGS++))
    else
      echo "  ${GRN}✓ description:${RST} ${desc_len} chars"
    fi
  fi

  # author
  if [[ -z "$author" ]] || [[ "$author" == " <>" ]]; then
    echo "  ${YEL}⚠ author:${RST} missing or empty (recommended)"
    ((WARNINGS++))
  else
    echo "  ${GRN}✓ author:${RST} $author"
  fi

  # license (optional but recommended for clarity)
  if [[ -z "$license" ]]; then
    echo "  ${YEL}⚠ license:${RST} missing (recommended — use SPDX id or 'UNLICENSED')"
    ((WARNINGS++))
  else
    echo "  ${GRN}✓ license:${RST} $license"
  fi
}

# ── Check marketplace.json (has top-level + plugins[] array) ──
check_marketplace() {
  local file="$1"
  echo ""
  echo "${BLD}Marketplace: ${file}${RST}"

  # Top-level: name, description, owner (not author)
  local name description owner_name
  name=$(jq -r '.name // empty' "$file")
  description=$(jq -r '.description // empty' "$file")
  owner_name=$(jq -r '.owner.name // empty' "$file")

  ((CHECKED++))
  echo "  Top-level:"
  if [[ -z "$name" ]]; then
    echo "    ${RED}❌ name:${RST} missing"
    ((ERRORS++))
  elif ! [[ "$name" =~ $NAME_RE ]]; then
    echo "    ${RED}❌ name:${RST} \"$name\" not kebab-case"
    ((ERRORS++))
  else
    echo "    ${GRN}✓ name:${RST} \"$name\""
  fi

  if [[ -z "$description" ]]; then
    echo "    ${YEL}⚠ description:${RST} missing"
    ((WARNINGS++))
  else
    local desc_len=${#description}
    if [[ "$desc_len" -lt 50 ]] || [[ "$desc_len" -gt 200 ]]; then
      echo "    ${YEL}⚠ description:${RST} ${desc_len} chars (recommend 50-200)"
      ((WARNINGS++))
    else
      echo "    ${GRN}✓ description:${RST} ${desc_len} chars"
    fi
  fi

  if [[ -z "$owner_name" ]]; then
    echo "    ${YEL}⚠ owner.name:${RST} missing"
    ((WARNINGS++))
  else
    echo "    ${GRN}✓ owner.name:${RST} \"$owner_name\""
  fi

  # Each plugin in plugins[]
  local plugin_count
  plugin_count=$(jq -r '.plugins | length' "$file" 2>/dev/null || echo "0")
  echo "  Plugins declared: $plugin_count"

  for ((i=0; i<plugin_count; i++)); do
    local plugin_name
    plugin_name=$(jq -r ".plugins[$i].name // \"<unnamed>\"" "$file")
    check_plugin_object "$file" ".plugins[$i]" "plugin[$i]: $plugin_name"
  done
}

# ── Determine targets ──
if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  # Default: scan .claude-plugin/ source + dist/
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mapfile -t TARGETS < <(find "$REPO_ROOT/.claude-plugin" "$REPO_ROOT/dist" -type f \( -name "plugin.json" -o -name "marketplace.json" \) 2>/dev/null | sort)
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "${YEL}[warn]${RST} no plugin.json/marketplace.json found under $REPO_ROOT/.claude-plugin or $REPO_ROOT/dist"
    exit 0
  fi
fi

echo "${BLD}ATLAS plugin.json/marketplace.json Validator${RST}"
echo "Reference: ADR-011 (description conv), Anthropic manifest-reference.md"

for target in "${TARGETS[@]}"; do
  if [[ ! -f "$target" ]]; then
    echo "${RED}[error]${RST} not a file: $target" >&2
    ((ERRORS++))
    continue
  fi

  # Validate JSON syntax first
  if ! jq empty "$target" 2>/dev/null; then
    echo ""
    echo "${BLD}${target}${RST}"
    echo "  ${RED}❌ invalid JSON syntax${RST}"
    ((ERRORS++))
    continue
  fi

  # Route by filename
  if [[ "$target" == *marketplace.json ]]; then
    check_marketplace "$target"
  else
    check_plugin_object "$target" "." "$target"
  fi
done

# ── Summary ──
echo ""
echo "${BLD}Summary:${RST} $CHECKED objects checked, ${ERRORS} errors, ${WARNINGS} warnings"

if [[ "$ERRORS" -gt 0 ]]; then
  echo "${RED}❌ FAIL${RST} — fix errors above."
  exit 2
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo "${YEL}⚠ PASS (with warnings)${RST} — consider addressing style issues."
  exit 1
else
  echo "${GRN}✅ PASS${RST} — all objects conform to canonical schema."
  exit 0
fi
