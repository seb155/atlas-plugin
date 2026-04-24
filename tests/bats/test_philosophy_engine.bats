#!/usr/bin/env bats
# test_philosophy_engine.bats — regression tests for v6.0 Philosophy Engine
#
# Scope:
#   - hard-gate-linter.sh (L1-L10 rules, SHA256 byte-exact + fuzzy fallback)
#   - effort-heuristic.sh (6-bucket classification)
#   - iron-laws.yaml (9 laws presence)
#   - red-flags-corpus.yaml (25 red flags across 5 categories)
#   - autonomy-gate.sh (3 modes, immutable actions)
#
# Plan ref: .blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md (P1-10)
# Sprint: v6.0.0-alpha.8+ Sprint 1 P1 quality item

load helpers

# ── Philosophy Engine core files ─────────────────────────────────────

@test "iron-laws.yaml exists and is valid YAML" {
  [ -f scripts/execution-philosophy/iron-laws.yaml ]
  run python3 -c "import yaml; yaml.safe_load(open('scripts/execution-philosophy/iron-laws.yaml'))"
  [ "$status" -eq 0 ]
}

@test "iron-laws.yaml declares at least 9 laws (Sprint 2 baseline)" {
  run python3 -c "import yaml; d=yaml.safe_load(open('scripts/execution-philosophy/iron-laws.yaml')); print(len(d.get('laws',[])))"
  [ "$status" -eq 0 ]
  [ "$output" -ge 9 ]
}

@test "red-flags-corpus.yaml exists and is valid YAML" {
  [ -f scripts/execution-philosophy/red-flags-corpus.yaml ]
  run python3 -c "import yaml; yaml.safe_load(open('scripts/execution-philosophy/red-flags-corpus.yaml'))"
  [ "$status" -eq 0 ]
}

# ── Hard-gate-linter tests ───────────────────────────────────────────

@test "hard-gate-linter.sh is executable" {
  [ -x scripts/execution-philosophy/hard-gate-linter.sh ]
}

@test "hard-gate-linter.sh --help returns usage" {
  run scripts/execution-philosophy/hard-gate-linter.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Philosophy Engine v6.0 validator" ]]
}

@test "hard-gate-linter.sh all passes on current state (10/10 Tier-1 skills)" {
  run scripts/execution-philosophy/hard-gate-linter.sh all
  [ "$status" -eq 0 ]
  [[ "$output" =~ "10/10 skills passed" ]]
}

@test "hard-gate-linter.sh L8 uses SHA256 byte-exact (v6.0.0-alpha.7 P1-6)" {
  run scripts/execution-philosophy/hard-gate-linter.sh all
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SHA256 byte-exact" ]]
}

# ── Effort-heuristic tests ───────────────────────────────────────────

@test "effort-heuristic.sh is executable" {
  [ -x scripts/execution-philosophy/effort-heuristic.sh ]
}

@test "effort-heuristic.sh returns valid bucket for architectural task" {
  run scripts/execution-philosophy/effort-heuristic.sh "design a new microservices architecture with event sourcing"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^(low|medium|high|xhigh|max|auto)$ ]]
}

@test "effort-heuristic.sh returns valid bucket for trivial task" {
  run scripts/execution-philosophy/effort-heuristic.sh "fix typo in README"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^(low|medium|high|xhigh|max|auto)$ ]]
}

# ── Autonomy-gate tests (Phase 5 foundation) ─────────────────────────

@test "autonomy-gate.sh is executable" {
  [ -x hooks/autonomy-gate.sh ]
}

@test "autonomy-gate.sh help returns usage" {
  run hooks/autonomy-gate.sh help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ATLAS Autonomy Gate Helper" ]]
}

@test "autonomy-gate.sh init creates session-state.json" {
  tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" init
  [ -f .claude/session-state.json ]
  popd >/dev/null
  rm -rf "$tmp"
}

@test "autonomy-gate.sh strict mode (default) fires AskUserQuestion" {
  tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" init
  run "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" check test-gate CODED
  [ "$status" -eq 1 ]
  popd >/dev/null
  rm -rf "$tmp"
}

@test "autonomy-gate.sh approved mode + approved gate skips" {
  tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" init
  "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" approve test-gate session >/dev/null
  run "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" check test-gate CODED
  [ "$status" -eq 0 ]
  popd >/dev/null
  rm -rf "$tmp"
}

@test "autonomy-gate.sh immutable action (deploy:production) always fires" {
  tmp=$(mktemp -d)
  pushd "$tmp" >/dev/null
  "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" init
  "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" approve test-gate session >/dev/null
  run "$BATS_TEST_DIRNAME/../../hooks/autonomy-gate.sh" check test-gate CODED "deploy:production"
  [ "$status" -eq 1 ]
  popd >/dev/null
  rm -rf "$tmp"
}

# ── Integration: build.sh pipeline ───────────────────────────────────

@test "build.sh integrates hard-gate-linter in pipeline (P0-4)" {
  run grep -c "hard-gate-linter.sh" build.sh
  [ "$status" -eq 0 ]
  [ "$output" -ge 2 ]
}

@test "build.sh has --skip-hard-gate flag (P0-4)" {
  run grep "skip-hard-gate" build.sh
  [ "$status" -eq 0 ]
}

@test "build.sh has MODULAR_PLUGINS for 'all' tier (5bb3a20)" {
  run grep "MODULAR_PLUGINS" build.sh
  [ "$status" -eq 0 ]
}
