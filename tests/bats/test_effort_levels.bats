#!/usr/bin/env bats
# test_effort_levels.bats — validates v6.0 effort enum + SOTA allocation table.
# Ref: plan section D (SOTA agent effort table) + schema A4/A8 rules.
# Sprint 1.3 gating: tests 3-5 will SKIP until per-agent effort has been written.

load helpers

@test "every AGENT.md with effort: key has a valid enum value" {
  local agent_files bad=0
  agent_files=$(list_agent_files)
  [ -n "$agent_files" ] || skip "no agents/*/AGENT.md found"
  for f in $agent_files; do
    if has_yaml_key "$f" "effort"; then
      local v
      v=$(extract_yaml_value "$f" "effort")
      if ! [[ "$v" =~ ^($EFFORT_ENUM)$ ]]; then
        echo "BAD: $f has effort='$v' (must be one of: $EFFORT_ENUM)" >&2
        bad=$((bad + 1))
      fi
    fi
  done
  [ "$bad" -eq 0 ]
}

@test "every SKILL.md with effort: key has a valid enum value" {
  local skill_files bad=0
  skill_files=$(list_skill_files)
  [ -n "$skill_files" ] || skip "no skills/*/SKILL.md found"
  for f in $skill_files; do
    if has_yaml_key "$f" "effort"; then
      local v
      v=$(extract_yaml_value "$f" "effort")
      if ! [[ "$v" =~ ^($EFFORT_ENUM)$ ]]; then
        echo "BAD: $f has effort='$v' (must be one of: $EFFORT_ENUM)" >&2
        bad=$((bad + 1))
      fi
    fi
  done
  [ "$bad" -eq 0 ]
}

@test "plan-architect AGENT.md has effort: max (SOTA table — Opus architecture)" {
  local f="$PLUGIN_ROOT/agents/plan-architect/AGENT.md"
  [ -f "$f" ] || skip "plan-architect AGENT.md not present"
  has_yaml_key "$f" "effort" || skip "plan-architect effort not yet written (Sprint 1.3)"
  local v
  v=$(extract_yaml_value "$f" "effort")
  [[ "$v" == "max" ]] || {
    echo "plan-architect has effort='$v', spec requires 'max'" >&2
    return 1
  }
}

@test "code-reviewer AGENT.md has effort: xhigh (SOTA table)" {
  local f="$PLUGIN_ROOT/agents/code-reviewer/AGENT.md"
  [ -f "$f" ] || skip "code-reviewer AGENT.md not present"
  has_yaml_key "$f" "effort" || skip "code-reviewer effort not yet written (Sprint 1.3)"
  local v
  v=$(extract_yaml_value "$f" "effort")
  [[ "$v" == "xhigh" ]] || {
    echo "code-reviewer has effort='$v', spec requires 'xhigh'" >&2
    return 1
  }
}

@test "team-researcher AGENT.md has effort in {low, medium} (SOTA table — Haiku)" {
  local f="$PLUGIN_ROOT/agents/team-researcher/AGENT.md"
  [ -f "$f" ] || skip "team-researcher AGENT.md not present"
  has_yaml_key "$f" "effort" || skip "team-researcher effort not yet written (Sprint 1.3)"
  local v
  v=$(extract_yaml_value "$f" "effort")
  [[ "$v" == "low" || "$v" == "medium" ]] || {
    echo "team-researcher has effort='$v', spec allows only {low, medium}" >&2
    return 1
  }
}
