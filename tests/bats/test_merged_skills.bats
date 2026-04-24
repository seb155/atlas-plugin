#!/usr/bin/env bats
# test_merged_skills.bats — regression tests for v6.0 dedup Phase 2 merges
#
# Scope:
#   - knowledge skill (merged from knowledge-engine + knowledge-manager, alpha.3)
#     10 subcommands preserved: ask, ingest, status, discover, gaps, search,
#                                rules, scope, vault-list, vault-upload
#
#   - gms-mgmt skill (merged from 4 gms-* skills, alpha.3)
#     16 subcommands preserved across 4 sections (cockpit/profiler/onboard/insights)
#     Collision resolution: --deep for profiler, --quick for insights
#
#   - Cross-ref integrity (no orphan references to old skill names)
#
# Plan ref: .blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md (P1-2)
# Sprint: v6.0.0-alpha.9+ Sprint 1 P1 quality item
# SOTA review: memory/atlas-v6-sota-review-2026-04-23.md Agent C

load helpers

# ── Merged skills presence ───────────────────────────────────────────

@test "knowledge skill SKILL.md exists" {
  [ -f skills/knowledge/SKILL.md ]
}

@test "knowledge skill has valid frontmatter" {
  run python3 -c "
import re
with open('skills/knowledge/SKILL.md') as f:
    content = f.read()
m = re.match(r'^---\\s*\\n(.*?)\\n---\\s*\\n', content, re.DOTALL)
if not m:
    raise SystemExit(1)
import yaml
yaml.safe_load(m.group(1))
"
  [ "$status" -eq 0 ]
}

@test "gms-mgmt skill SKILL.md exists" {
  [ -f skills/gms-mgmt/SKILL.md ]
}

@test "gms-mgmt skill has valid frontmatter" {
  run python3 -c "
import re
with open('skills/gms-mgmt/SKILL.md') as f:
    content = f.read()
m = re.match(r'^---\\s*\\n(.*?)\\n---\\s*\\n', content, re.DOTALL)
if not m:
    raise SystemExit(1)
import yaml
yaml.safe_load(m.group(1))
"
  [ "$status" -eq 0 ]
}

# ── Old skills deleted (dedup wins) ──────────────────────────────────

@test "knowledge-engine skill is DELETED (merged into knowledge)" {
  [ ! -f skills/knowledge-engine/SKILL.md ]
}

@test "knowledge-manager skill is DELETED (merged into knowledge)" {
  [ ! -f skills/knowledge-manager/SKILL.md ]
}

@test "gms-cockpit skill is DELETED (merged into gms-mgmt)" {
  [ ! -f skills/gms-cockpit/SKILL.md ]
}

@test "gms-profiler skill is DELETED (merged into gms-mgmt)" {
  [ ! -f skills/gms-profiler/SKILL.md ]
}

@test "gms-onboard skill is DELETED (merged into gms-mgmt)" {
  [ ! -f skills/gms-onboard/SKILL.md ]
}

@test "gms-insights skill is DELETED (merged into gms-mgmt)" {
  [ ! -f skills/gms-insights/SKILL.md ]
}

# ── knowledge subcommands preserved (10 total) ───────────────────────

@test "knowledge skill documents 'ask' subcommand" {
  run grep -E "^###.*ask|Subcommand.*ask|/atlas knowledge ask" skills/knowledge/SKILL.md
  [ "$status" -eq 0 ]
}

@test "knowledge skill documents 'ingest' subcommand" {
  run grep -E "^###.*ingest|Subcommand.*ingest|/atlas knowledge ingest" skills/knowledge/SKILL.md
  [ "$status" -eq 0 ]
}

@test "knowledge skill documents 'search' subcommand" {
  run grep -E "^###.*search|Subcommand.*search|/atlas knowledge search" skills/knowledge/SKILL.md
  [ "$status" -eq 0 ]
}

@test "knowledge skill documents 'status' subcommand" {
  run grep -E "^###.*status|Subcommand.*status|/atlas knowledge status" skills/knowledge/SKILL.md
  [ "$status" -eq 0 ]
}

@test "knowledge skill documents 'vault-list' subcommand" {
  run grep -E "vault-list" skills/knowledge/SKILL.md
  [ "$status" -eq 0 ]
}

@test "knowledge skill documents 'vault-upload' subcommand" {
  run grep -E "vault-upload" skills/knowledge/SKILL.md
  [ "$status" -eq 0 ]
}

# ── gms-mgmt subcommands + collision routing ─────────────────────────

@test "gms-mgmt skill documents 'team' subcommand (cockpit default)" {
  run grep -E "team" skills/gms-mgmt/SKILL.md
  [ "$status" -eq 0 ]
}

@test "gms-mgmt skill documents '--deep' flag (routes to profiler)" {
  run grep -E "\\-\\-deep" skills/gms-mgmt/SKILL.md
  [ "$status" -eq 0 ]
}

@test "gms-mgmt skill documents '--quick' flag (routes to cockpit mini)" {
  run grep -E "\\-\\-quick" skills/gms-mgmt/SKILL.md
  [ "$status" -eq 0 ]
}

@test "gms-mgmt skill documents 'insights' subcommand" {
  run grep -E "insights" skills/gms-mgmt/SKILL.md
  [ "$status" -eq 0 ]
}

@test "gms-mgmt skill documents 'onboard' subcommand" {
  run grep -E "onboard" skills/gms-mgmt/SKILL.md
  [ "$status" -eq 0 ]
}

@test "gms-mgmt skill documents 'profile' subcommand" {
  run grep -E "profile|profiler" skills/gms-mgmt/SKILL.md
  [ "$status" -eq 0 ]
}

# ── Cross-ref integrity (no orphan references) ───────────────────────

@test "no source skill references old 'knowledge-engine' name" {
  run grep -rl "knowledge-engine" skills/ 2>/dev/null
  # If status 0 (match found), should only be in historical docs (allowed)
  # We check via grep -v of known allowed files
  if [ "$status" -eq 0 ]; then
    # Filter out allowed: the merged knowledge skill itself mentions history
    bad=$(echo "$output" | grep -v "skills/knowledge/SKILL.md" || true)
    [ -z "$bad" ]
  fi
}

@test "no source skill references old 'gms-cockpit' name (except migration notes)" {
  run grep -rl "gms-cockpit" skills/ 2>/dev/null
  if [ "$status" -eq 0 ]; then
    bad=$(echo "$output" | grep -v "skills/gms-mgmt/SKILL.md" || true)
    [ -z "$bad" ]
  fi
}

@test "_metadata.yaml does NOT declare deleted skills" {
  run python3 -c "
import yaml
with open('skills/_metadata.yaml') as f:
    d = yaml.safe_load(f)
skills = d.get('skills', {}) or {}
deleted = ['knowledge-engine', 'knowledge-manager', 'gms-cockpit',
           'gms-profiler', 'gms-onboard', 'gms-insights']
remaining = [s for s in deleted if s in skills]
if remaining:
    print('FAIL: still in metadata:', remaining)
    raise SystemExit(1)
"
  [ "$status" -eq 0 ]
}

@test "_metadata.yaml declares merged skills" {
  run python3 -c "
import yaml
with open('skills/_metadata.yaml') as f:
    d = yaml.safe_load(f)
skills = d.get('skills', {}) or {}
required = ['knowledge', 'gms-mgmt']
missing = [s for s in required if s not in skills]
if missing:
    print('FAIL: missing from metadata:', missing)
    raise SystemExit(1)
"
  [ "$status" -eq 0 ]
}

# ── ADR-0004 exists (P1-7 requirement — knowledge dedup rationale) ───

@test "ADR-0004 knowledge-dedup-rationale exists" {
  [ -f .blueprint/adrs/0004-knowledge-dedup-rationale.md ]
}

@test "ADR-0004 has Status APPROVED" {
  run grep "Status.*APPROVED" .blueprint/adrs/0004-knowledge-dedup-rationale.md
  [ "$status" -eq 0 ]
}

# ── Build integrity (merged skills build cleanly) ────────────────────

@test "knowledge skill appears in atlas-admin-addon dist build" {
  # Dist rebuilt during build.sh, check skill present
  # (not strict — dist may not exist in fresh clone)
  if [ -d dist/atlas-admin-addon/skills ]; then
    [ -f dist/atlas-admin-addon/skills/knowledge/SKILL.md ]
  fi
}

@test "gms-mgmt skill appears in atlas-admin-addon dist build" {
  if [ -d dist/atlas-admin-addon/skills ]; then
    [ -f dist/atlas-admin-addon/skills/gms-mgmt/SKILL.md ]
  fi
}
