#!/usr/bin/env bats
# SP-DAIMON P2 Task 2.4 — structural tests for agents/pattern-signal-detector/AGENT.md
# Note: agent behavior (actual signal detection) is tested via integration in test-daimon-p2-lifecycle.sh
# This file validates: frontmatter structure, required sections, output schema documentation.

load helper.bash

AGENT_MD="$PLUGIN_ROOT/agents/pattern-signal-detector/AGENT.md"

@test "AGENT.md exists" {
  [ -f "$AGENT_MD" ]
}

@test "has valid YAML frontmatter (--- delimiters)" {
  run head -1 "$AGENT_MD"
  [ "$status" -eq 0 ]
  [[ "$output" == "---" ]]
}

@test "frontmatter has name=pattern-signal-detector" {
  run grep -E "^name:\s*pattern-signal-detector$" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "frontmatter has description" {
  run grep -E "^description:" "$AGENT_MD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cognitive pattern"* ]] || [[ "$output" == *"DAIMON"* ]]
}

@test "frontmatter declares model=haiku" {
  run grep -E "^model:\s*haiku$" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "frontmatter declares effort=low" {
  run grep -E "^effort:\s*low$" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "disallowedTools prevents file writes" {
  run grep -E "^\s*-\s+Write$" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "disallowedTools prevents edits" {
  run grep -E "^\s*-\s+Edit$" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "disallowedTools prevents bash (read-only agent)" {
  run grep -E "^\s*-\s+Bash$" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

# ───────── Body structure ─────────

@test "body has 'Your Role' section" {
  run grep -E "^## Your Role" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "body has 'Workflow' section" {
  run grep -E "^## Workflow" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "body has 'Output Schema' section" {
  run grep -E "^## Output Schema" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "body has 'Tools' section listing Allowed/NOT Allowed" {
  run grep -E "^## Tools" "$AGENT_MD"
  [ "$status" -eq 0 ]
  run grep -c -E "Allowed|NOT Allowed" "$AGENT_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

# ───────── Signal coverage ─────────

@test "mentions chronic_dissatisfaction signal" {
  run grep -c "chronic_dissatisfaction" "$AGENT_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "mentions verification_loops signal" {
  run grep -c "verification_loops" "$AGENT_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "mentions social_drift signal" {
  run grep -c "social_drift" "$AGENT_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ───────── Output contract ─────────

@test "output schema documents signals array" {
  run grep -E '"signals"' "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "output schema documents ts field (ISO-8601)" {
  run grep -E '"ts"' "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "output schema documents severity field" {
  run grep -E '"severity"' "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "empty signals output format is documented" {
  # Accept either single-line or multi-line JSON
  run grep -c '"signals": \[\]\|"signals":\[\]' "$AGENT_MD"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ───────── Read-only invariant ─────────

@test "declares never-write invariant in body" {
  run grep -i -E "never (modify|write|touch) files|read-only" "$AGENT_MD"
  [ "$status" -eq 0 ]
}

@test "documents dispatcher handles side effects" {
  run grep -i "pattern-signal-dispatcher\|dispatcher" "$AGENT_MD"
  [ "$status" -eq 0 ]
}
