#!/usr/bin/env bats
# test_red_flags.bats — validates Philosophy Engine Red Flags corpus (Sprint 2.1).
# Ref: .blueprint/schemas/philosophy-engine-schema.md (Section 3) + plan Section E.
# Corpus: scripts/execution-philosophy/red-flags-corpus.yaml (20 flags, 4 categories).

load helpers

CORPUS="$PLUGIN_ROOT/scripts/execution-philosophy/red-flags-corpus.yaml"

@test "red-flags-corpus.yaml exists and is readable" {
  [ -f "$CORPUS" ]
  [ -r "$CORPUS" ]
}

@test "red-flags-corpus.yaml parses as valid YAML" {
  run python3 -c "import yaml; yaml.safe_load(open('$CORPUS'))"
  [ "$status" -eq 0 ]
}

@test "red-flags-corpus.yaml has at least 20 flags" {
  local count
  count=$(python3 -c "import yaml; print(len(yaml.safe_load(open('$CORPUS'))['flags']))")
  [ "$count" -ge 20 ]
}

@test "every flag has required keys (id, thought, reality, counter_action, severity, applicable_skills)" {
  run python3 - <<PY
import sys, yaml
flags = yaml.safe_load(open("$CORPUS"))["flags"]
required = {"id", "thought", "reality", "counter_action", "severity", "applicable_skills"}
for flag in flags:
    missing = required - set(flag.keys())
    if missing:
        sys.exit(f"{flag.get('id', '?')}: missing {missing}")
PY
  [ "$status" -eq 0 ]
}

@test "severity is in {low, medium, high, critical}" {
  run python3 - <<PY
import sys, yaml
flags = yaml.safe_load(open("$CORPUS"))["flags"]
allowed = {"low", "medium", "high", "critical"}
for flag in flags:
    sev = flag.get("severity")
    if sev not in allowed:
        sys.exit(f"{flag['id']}: severity='{sev}' (must be in {allowed})")
PY
  [ "$status" -eq 0 ]
}

@test "counter_action starts with an actionable verb" {
  # Accepts common imperatives actually used in the corpus (capitalized).
  run python3 - <<PY
import re, sys, yaml
flags = yaml.safe_load(open("$CORPUS"))["flags"]
pattern = re.compile(
    r"^(STOP|Write|Run|Verify|Commit|Convert|List|Identify|Spend|Treat|Check|Ask|Delete|Fix|If)"
)
for flag in flags:
    action = flag.get("counter_action", "").strip()
    if not pattern.match(action):
        sys.exit(f"{flag['id']}: counter_action does not start with actionable verb: '{action[:60]}...'")
PY
  [ "$status" -eq 0 ]
}

@test "every flag has non-empty thought and reality (>=10 chars each)" {
  run python3 - <<PY
import sys, yaml
flags = yaml.safe_load(open("$CORPUS"))["flags"]
for flag in flags:
    thought = flag.get("thought", "").strip()
    reality = flag.get("reality", "").strip()
    if len(thought) < 10:
        sys.exit(f"{flag['id']}: thought too short ({len(thought)} chars)")
    if len(reality) < 10:
        sys.exit(f"{flag['id']}: reality too short ({len(reality)} chars)")
PY
  [ "$status" -eq 0 ]
}

@test "linked_law references (when present) match LAW-* pattern" {
  run python3 - <<PY
import re, sys, yaml
flags = yaml.safe_load(open("$CORPUS"))["flags"]
pattern = re.compile(r"^LAW-[A-Z]+-\d{3}$")
for flag in flags:
    linked = flag.get("linked_law")
    if linked is not None and not pattern.match(linked):
        sys.exit(f"{flag['id']}: linked_law='{linked}' (must match LAW-XXX-NNN)")
PY
  [ "$status" -eq 0 ]
}
