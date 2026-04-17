#!/usr/bin/env bats
# test_frontmatter_v6.bats — validates v6.0 frontmatter structure (SKILL.md).
# Ref: schema skill-frontmatter-v6.md rules R1, R2, R5-R7 + Sprint 2 hard-gate hook.

load helpers

@test "every SKILL.md has a well-formed YAML frontmatter (--- ... ---)" {
  local skill_files bad=0 total=0
  skill_files=$(list_skill_files)
  [ -n "$skill_files" ] || skip "no skills/*/SKILL.md found"
  for f in $skill_files; do
    total=$((total + 1))
    local fm
    fm=$(parse_frontmatter "$f")
    if [ -z "$fm" ]; then
      echo "BAD: $f has no parseable frontmatter" >&2
      bad=$((bad + 1))
    fi
  done
  echo "checked $total SKILL.md files, $bad missing frontmatter" >&2
  [ "$bad" -eq 0 ]
}

@test "every SKILL.md has required keys: name and description" {
  local skill_files bad=0
  skill_files=$(list_skill_files)
  [ -n "$skill_files" ] || skip "no skills/*/SKILL.md found"
  for f in $skill_files; do
    if ! has_yaml_key "$f" "name"; then
      echo "BAD: $f missing required key: name" >&2
      bad=$((bad + 1))
      continue
    fi
    if ! has_yaml_key "$f" "description"; then
      echo "BAD: $f missing required key: description" >&2
      bad=$((bad + 1))
    fi
  done
  [ "$bad" -eq 0 ]
}

@test "when superpowers_pattern present, all values are in {iron_law, red_flags, hard_gate, none}" {
  local skill_files bad=0 found=0
  skill_files=$(list_skill_files)
  for f in $skill_files; do
    has_yaml_key "$f" "superpowers_pattern" || continue
    found=$((found + 1))
    # Collect values: inline list `[a, b]` OR block list (subsequent `- a` lines).
    # We use python to parse both shapes via the frontmatter text.
    local raw
    raw=$(parse_frontmatter "$f" | awk '
      BEGIN { in_list = 0 }
      /^superpowers_pattern:/ {
        line = $0
        sub(/^superpowers_pattern:[[:space:]]*/, "", line)
        # Inline list?
        if (match(line, /^\[[^]]*\]/)) {
          gsub(/[][,]/, " ", line)
          print line
          in_list = 0
          next
        }
        # Block list follows
        in_list = 1
        next
      }
      in_list {
        if (/^[[:space:]]*-[[:space:]]*/) {
          sub(/^[[:space:]]*-[[:space:]]*/, "")
          print
        } else if (/^[[:alpha:]]/) {
          in_list = 0
        }
      }
    ')
    # Validate each token
    for tok in $raw; do
      tok=$(echo "$tok" | tr -d '"'"'"' \t')
      [ -z "$tok" ] && continue
      if ! [[ "$tok" =~ ^($SP_PATTERN_ENUM)$ ]]; then
        echo "BAD: $f has superpowers_pattern token='$tok' (allowed: $SP_PATTERN_ENUM)" >&2
        bad=$((bad + 1))
      fi
    done
  done
  # Baseline audit: 0% coverage in v5.23 → if none found, skip instead of fail.
  [ "$found" -gt 0 ] || skip "no skills declare superpowers_pattern yet (Sprint 1.4/2.x delta)"
  [ "$bad" -eq 0 ]
}

@test "when see_also present, all tokens are bare skill-name strings (no paths)" {
  local skill_files bad=0 found=0
  skill_files=$(list_skill_files)
  for f in $skill_files; do
    has_yaml_key "$f" "see_also" || continue
    found=$((found + 1))
    local raw
    raw=$(parse_frontmatter "$f" | awk '
      BEGIN { in_list = 0 }
      /^see_also:/ {
        line = $0
        sub(/^see_also:[[:space:]]*/, "", line)
        if (match(line, /^\[[^]]*\]/)) {
          gsub(/[][,]/, " ", line)
          print line
          in_list = 0
          next
        }
        in_list = 1
        next
      }
      in_list {
        if (/^[[:space:]]*-[[:space:]]*/) {
          sub(/^[[:space:]]*-[[:space:]]*/, "")
          print
        } else if (/^[[:alpha:]]/) {
          in_list = 0
        }
      }
    ')
    for tok in $raw; do
      tok=$(echo "$tok" | tr -d '"'"'"' \t')
      [ -z "$tok" ] && continue
      # Must be kebab-case skill-name, NOT a path (no '/', no '.md')
      if [[ "$tok" == */* || "$tok" == *.md ]]; then
        echo "BAD: $f see_also token='$tok' is a path, must be bare skill-name" >&2
        bad=$((bad + 1))
      elif ! [[ "$tok" =~ ^[a-z0-9-]+$ ]]; then
        echo "BAD: $f see_also token='$tok' not kebab-case" >&2
        bad=$((bad + 1))
      fi
    done
  done
  [ "$found" -gt 0 ] || skip "no skills declare see_also yet (Sprint 1.4/2.x delta)"
  [ "$bad" -eq 0 ]
}

@test "hard-gate-linter.sh passes on tier-1 skills with <HARD-GATE> (Sprint 2.2)" {
  local linter="$PLUGIN_ROOT/scripts/hard-gate-linter.sh"
  if [ ! -x "$linter" ] && [ ! -f "$linter" ]; then
    skip "hard-gate-linter.sh not yet implemented (Sprint 2.2 deliverable)"
  fi
  run bash "$linter" "$PLUGIN_ROOT/skills"
  # Exit 0 = pass, 2-5 = block (see schema §5).
  [ "$status" -eq 0 ]
}
