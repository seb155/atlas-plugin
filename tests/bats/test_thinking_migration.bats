#!/usr/bin/env bats
# test_thinking_migration.bats — validates Sprint 1.1/1.2 extended-thinking purge.
# Ref: plan regarde-comment-adapter-atlas-compressed-wave.md section J (R4).
# Scope: hooks/ skills/ agents/ scripts/ — excludes tests/audit (it documents the patterns).

load helpers

@test "no 'thinking.type.enabled' remnants (extended-thinking API artifact)" {
  run grep_count_matches 'thinking.*type.*enabled'
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "no 'budget_tokens' remnants (deprecated Opus 4.7 API key)" {
  run grep_count_matches 'budget_tokens'
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "no 'CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING' env references" {
  run grep_count_matches 'CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING'
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "no 'thinking_tokens' remnants" {
  run grep_count_matches 'thinking_tokens'
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "every SKILL.md with thinking_mode has value 'adaptive'" {
  local skill_files bad=0
  skill_files=$(list_skill_files)
  for f in $skill_files; do
    if has_yaml_key "$f" "thinking_mode"; then
      local v
      v=$(extract_yaml_value "$f" "thinking_mode")
      if [[ "$v" != "adaptive" ]]; then
        echo "BAD: $f has thinking_mode='$v' (must be 'adaptive')" >&2
        bad=$((bad + 1))
      fi
    fi
  done
  [ "$bad" -eq 0 ]
}

@test "every AGENT.md with thinking_mode has value 'adaptive'" {
  local agent_files bad=0
  agent_files=$(list_agent_files)
  for f in $agent_files; do
    if has_yaml_key "$f" "thinking_mode"; then
      local v
      v=$(extract_yaml_value "$f" "thinking_mode")
      if [[ "$v" != "adaptive" ]]; then
        echo "BAD: $f has thinking_mode='$v' (must be 'adaptive')" >&2
        bad=$((bad + 1))
      fi
    fi
  done
  [ "$bad" -eq 0 ]
}
