# bats test suite — atlas-dev-plugin v6.0 frontmatter validation

Normative tests covering the v6.0 frontmatter schema and Sprint 1.x deliverables.
All tests are written in [bats-core](https://github.com/bats-core/bats-core) (Bash
Automated Testing System).

## Files

| File | Purpose | Test blocks |
|---|---|---:|
| `helpers.bash` | Shared utilities: frontmatter parsing, YAML key extraction, scan-dir greps | — |
| `test_thinking_migration.bats` | Sprint 1.1/1.2 — zero extended-thinking remnants + `thinking_mode: adaptive` only | 6 |
| `test_effort_levels.bats` | v6.0 effort enum + SOTA agent allocation (plan-architect=max, code-reviewer=xhigh, team-researcher ∈ {low,medium}) | 5 |
| `test_frontmatter_v6.bats` | YAML parseability, required keys, `superpowers_pattern` enum, `see_also` shape, hard-gate-linter hook | 5 |

Total: **16 `@test` blocks**.

## Coverage targets

| Rule | Sprint | Status |
|---|---|---|
| R4 `thinking_mode == adaptive` (never `extended`) | 1.1 / 1.2 | **Required pass** |
| Effort enum valid when present | 1.3 | **Required pass** |
| Effort default per SOTA table | 1.3 | Skips until per-agent effort written |
| `superpowers_pattern` enum | 1.4 | Skips until first skill adopts (Sprint 2+) |
| `see_also` bare-name shape | 1.4 | Skips until first skill adopts |
| `hard-gate-linter.sh` pass | 2.2 | Skips until linter script shipped |

Skipping keeps Sprint 2+ deltas from blocking Sprint 1 CI.

## Running

### Prerequisite: bats installed

- **Ubuntu / Debian**: `sudo apt install bats`
- **macOS (Homebrew)**: `brew install bats-core`
- **From source**: `git clone https://github.com/bats-core/bats-core && cd bats-core && ./install.sh /usr/local`

Verify: `bats --version` (expects `Bats 1.x`).

### Run the suite

```bash
# From plugin root
bats tests/bats/

# Count test blocks without running
bats --count tests/bats/

# Single file, verbose
bats --verbose-run tests/bats/test_thinking_migration.bats

# Tap-compatible output (CI)
bats --tap tests/bats/ > tests/bats/results.tap
```

### Integration into Woodpecker / CI

Add to `.woodpecker/ci.yaml` or Makefile:

```yaml
steps:
  - name: bats-frontmatter
    image: bash:5-alpine
    commands:
      - apk add --no-cache bats
      - bats tests/bats/
```

## Scope boundaries

- The suite scans `hooks/ skills/ agents/ scripts/` **only**. `tests/audit/` is
  excluded because the remediation report itself documents the forbidden
  patterns as string literals.
- Tests use `skip` (not `fail`) for Sprint 2+ state so CI stays green through
  the migration window.
- The suite does NOT modify files. Run `hard-gate-linter.sh --fix` separately
  for auto-repair (Sprint 2.2 deliverable).

## Adding a new test

1. Drop `test_<topic>.bats` alongside the existing files.
2. `load helpers` on the first line to inherit `$PLUGIN_ROOT`, enum constants,
   and frontmatter helpers.
3. Use `skip "<reason>"` for tests guarding a later-sprint deliverable.
4. Update the counts table at the top of this README.
