#!/usr/bin/env bats
# SP-DAIMON P1 Task 1.7 — tests for hooks/daimon-context-injector

load helper.bash

setup() {
  setup_isolated_home
}

teardown() {
  teardown_isolated_home
}

# ───────── Basic sanity ─────────

@test "daimon-context-injector exists and is executable" {
  [ -f "$PLUGIN_ROOT/hooks/daimon-context-injector" ]
  [ -x "$PLUGIN_ROOT/hooks/daimon-context-injector" ]
}

@test "daimon-context-injector bash syntax valid" {
  run bash -n "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
}

# ───────── Silent exit path ─────────

@test "exits 0 silently when no calibration cache" {
  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
  # stdout should be empty
  [ -z "$output" ]
}

@test "exits 0 silently when calibration cache is invalid JSON" {
  echo "not valid json" > "$HOME/.atlas/runtime/session-calibration.json"
  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
}

# ───────── Happy path ─────────

@test "emits daimon-calibration block when cache present" {
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<'EOF'
{
  "schema_version": "1.0",
  "computed_at": "2026-04-15T08:00:00Z",
  "trust_level": "high",
  "user": {
    "name": "Test User",
    "short_name": "Test",
    "persona_type": "5w4_derived",
    "cognitive_pattern": "HID_7_layers",
    "deep_telos": "Test the unknown",
    "big_five": {"O": 3.5, "C": 4.0, "E": 2.5, "A": 3.0, "N": 2.8},
    "enneagram": {"type": 5, "wing": "5w4", "score_primary": 0.72},
    "core_values": ["Curiosity", "Autonomy", "Rigor"]
  },
  "calibration_rules_count": 0,
  "calibration_rules_ref": "vault/daimon/calibration-rules.md",
  "risk_signals": {
    "test_signal": {"indicator": "test indicator", "action": "flag"}
  },
  "experiential_context": {
    "last_episode": "2026-04-14",
    "last_energy": 7,
    "active_plans": ["test-plan.md"]
  },
  "active_memory_refs": []
}
EOF

  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<daimon-calibration"* ]]
  [[ "$output" == *"</daimon-calibration>"* ]]
}

@test "output contains user name and short_name" {
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<'EOF'
{
  "schema_version": "1.0",
  "user": {"name": "Sebastien", "short_name": "Seb"},
  "calibration_rules_count": 0,
  "calibration_rules_ref": "vault/daimon/calibration-rules.md",
  "risk_signals": {},
  "experiential_context": {}
}
EOF
  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sebastien"* ]]
  [[ "$output" == *"Seb"* ]]
}

@test "output contains cognitive pattern and deep telos when present" {
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<'EOF'
{
  "schema_version": "1.0",
  "user": {
    "short_name": "X",
    "cognitive_pattern": "HID_5_layers",
    "deep_telos": "A very specific test telos"
  },
  "calibration_rules_count": 0,
  "risk_signals": {},
  "experiential_context": {}
}
EOF
  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
  [[ "$output" == *"HID_5_layers"* ]]
  [[ "$output" == *"very specific test telos"* ]]
}

@test "output contains big_five scores when present" {
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<'EOF'
{
  "schema_version": "1.0",
  "user": {
    "short_name": "X",
    "big_five": {"O": 3.33, "C": 4.50, "E": 2.00, "A": 3.10, "N": 2.80}
  },
  "calibration_rules_count": 0,
  "risk_signals": {},
  "experiential_context": {}
}
EOF
  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
  [[ "$output" == *"O=3.33"* ]]
  [[ "$output" == *"C=4.5"* ]]
}

@test "output contains risk signals when present" {
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<'EOF'
{
  "schema_version": "1.0",
  "user": {"short_name": "X"},
  "calibration_rules_count": 0,
  "risk_signals": {
    "chronic_dissatisfaction": {"indicator": "3 ships in 7d"},
    "verification_loops": {"indicator": "proof requests > 3"}
  },
  "experiential_context": {}
}
EOF
  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chronic_dissatisfaction"* ]]
  [[ "$output" == *"verification_loops"* ]]
}

@test "output includes trust level attribute" {
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<'EOF'
{
  "schema_version": "1.0",
  "trust_level": "standard",
  "user": {"short_name": "X"},
  "calibration_rules_count": 0,
  "risk_signals": {},
  "experiential_context": {}
}
EOF
  run "$PLUGIN_ROOT/hooks/daimon-context-injector"
  [ "$status" -eq 0 ]
  [[ "$output" == *'trust="standard"'* ]]
}

@test "output is reasonable size (<2KB)" {
  cat > "$HOME/.atlas/runtime/session-calibration.json" <<'EOF'
{
  "schema_version": "1.0",
  "user": {
    "name": "Sebastien Gagnon",
    "short_name": "Seb",
    "persona_type": "1w2_perfectionniste",
    "cognitive_pattern": "HID_5_layers",
    "deep_telos": "Build frameworks for hyperactive cognitive systems to participate in the world",
    "big_five": {"O": 3.33, "C": 3.63, "E": 2.71, "A": 2.96, "N": 2.96, "key_facets": {"intellect": 4.0, "achievement_striving": 4.25}},
    "enneagram": {"type": 1, "wing": "1w2", "score_primary": 0.69},
    "core_values": ["Autonomy", "Sovereignty", "Excellence", "Learning", "Efficiency", "Transparency", "Quality"]
  },
  "calibration_rules_count": 12,
  "calibration_rules_ref": "vault/daimon/calibration-rules.md",
  "risk_signals": {
    "chronic_dissatisfaction": {"indicator": "3 ships in 7 days"},
    "verification_loops": {"indicator": "proof requests > 3"},
    "social_drift": {"indicator": "relationships stale > 21d"}
  },
  "experiential_context": {
    "last_episode": "2026-04-14 NIGHT-3",
    "last_energy": 7,
    "active_plans": ["plan-a.md", "plan-b.md"]
  }
}
EOF
  output=$("$PLUGIN_ROOT/hooks/daimon-context-injector")
  size=${#output}
  [ "$size" -lt 2048 ]
  [ "$size" -gt 200 ]  # has real content
}
