#!/usr/bin/env bats
# test_iron_laws.bats — validates Philosophy Engine Iron Laws corpus (Sprint 2.1).
# Ref: .blueprint/schemas/philosophy-engine-schema.md (Section 2) + plan Section E.
# Corpus: scripts/execution-philosophy/iron-laws.yaml (5 laws, hard_gate enforcement).

load helpers

CORPUS="$PLUGIN_ROOT/scripts/execution-philosophy/iron-laws.yaml"

@test "iron-laws.yaml exists and is readable" {
  [ -f "$CORPUS" ]
  [ -r "$CORPUS" ]
}

@test "iron-laws.yaml parses as valid YAML" {
  run python3 -c "import yaml; yaml.safe_load(open('$CORPUS'))"
  [ "$status" -eq 0 ]
}

@test "iron-laws.yaml has at least 5 laws" {
  local count
  count=$(python3 -c "import yaml; print(len(yaml.safe_load(open('$CORPUS'))['laws']))")
  [ "$count" -ge 5 ]
}

@test "every law has required keys (id, name, statement, rationale, applicable_skills, enforcement, signature_sha256)" {
  run python3 - <<PY
import sys, yaml
laws = yaml.safe_load(open("$CORPUS"))["laws"]
required = {"id", "name", "statement", "rationale", "applicable_skills", "enforcement", "signature_sha256"}
for law in laws:
    missing = required - set(law.keys())
    if missing:
        sys.exit(f"{law.get('id', '?')}: missing {missing}")
PY
  [ "$status" -eq 0 ]
}

@test "every law has non-empty statement (>=20 chars)" {
  run python3 - <<PY
import sys, yaml
laws = yaml.safe_load(open("$CORPUS"))["laws"]
for law in laws:
    stmt = law.get("statement", "").strip()
    if len(stmt) < 20:
        sys.exit(f"{law['id']}: statement too short ({len(stmt)} chars)")
PY
  [ "$status" -eq 0 ]
}

@test "enforcement is hard_gate or recommendation" {
  run python3 - <<PY
import sys, yaml
laws = yaml.safe_load(open("$CORPUS"))["laws"]
for law in laws:
    enf = law.get("enforcement")
    if enf not in ("hard_gate", "recommendation"):
        sys.exit(f"{law['id']}: enforcement='{enf}' (must be hard_gate|recommendation)")
PY
  [ "$status" -eq 0 ]
}

@test "every law has a 64-char hex signature_sha256" {
  run python3 - <<PY
import re, sys, yaml
laws = yaml.safe_load(open("$CORPUS"))["laws"]
hex64 = re.compile(r"^[0-9a-f]{64}$")
for law in laws:
    sig = law.get("signature_sha256", "")
    if not hex64.match(sig):
        sys.exit(f"{law['id']}: signature_sha256='{sig}' (must be 64 hex chars)")
PY
  [ "$status" -eq 0 ]
}

@test "applicable_skills references valid ATLAS skills" {
  # Tolerance: 80% of referenced skills must match a directory in skills/
  # (some may reference Superpowers aliases or admin-only skills).
  skip "TODO: match applicable_skills against tests/inventory/skills-audit-v5.23.csv (Sprint 2.3 delta)"
}
