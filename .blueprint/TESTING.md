# ATLAS Plugin Test Strategy

> 16 test files validate structure, behavior, and correctness.
> Run: `python3 -m pytest tests/ -x -q --tb=short`

---

## Test Pyramid

```
         ┌─────────┐
         │  E2E    │  2 files — full pipeline validation
         │ (slow)  │  test_hook_e2e, test_scripts_e2e
         ├─────────┤
         │Behavior │  2 files — runtime hook execution
         │         │  test_hook_behavior, test_regression_gate
         ├─────────┤
         │Structure│  12 files — static validation (fast)
         │ (fast)  │  frontmatter, coverage, profiles, build...
         └─────────┘
```

---

## All 16 Test Files

### Structural (12 files, fast)

| Test File | What It Validates | Fails When |
|-----------|-------------------|------------|
| `test_skill_frontmatter` | name, description, effort in every SKILL.md | Missing/invalid frontmatter fields |
| `test_skill_coverage` | No orphan skills (except atlas-assist) | Skill dir exists but not in any profile |
| `test_skill_quality` | Documentation quality standards | Skill content too short or missing sections |
| `test_command_structure` | Command routing validity | Command references non-existent skill |
| `test_profiles` | YAML inheritance chain integrity | Profile references non-existent parent |
| `test_build_output` | dist/ artifact completeness | Build output missing expected files |
| `test_version_sync` | VERSION matches all JSON manifests | Version mismatch between files |
| `test_cross_references` | skills ↔ commands ↔ profiles aligned | Broken cross-references |
| `test_hooks_schema` | hooks.json schema validity | Invalid hook entry format |
| `test_agent_frontmatter` | Agent spec completeness (name, model) | Missing agent metadata |
| `test_manifest` | plugin.json + marketplace.json validity | Invalid JSON or missing fields |
| `test_no_hardcoded_paths` | Portability — no absolute paths | Hardcoded /home/user paths found |

### Behavioral (2 files, medium)

| Test File | What It Validates | Fails When |
|-----------|-------------------|------------|
| `test_hook_behavior` | Hook script execution + output format | Hook crashes or wrong output format |
| `test_regression_gate` | Previous fixes stay fixed | Known bug regression detected |

### E2E (2 files, slow)

| Test File | What It Validates | Fails When |
|-----------|-------------------|------------|
| `test_hook_e2e` | Full hook lifecycle (event → script → output) | Hook integration failure |
| `test_scripts_e2e` | Runtime script execution | Script crashes in real env |

---

## Running Tests

```bash
# Full suite (recommended before commit)
python3 -m pytest tests/ -x -q --tb=short

# Single file (debugging)
python3 -m pytest tests/test_skill_frontmatter.py -x -q --tb=short

# Structural only (fastest)
python3 -m pytest tests/ -x -q --tb=short -k "not e2e and not behavior"

# Via Makefile
make test       # full suite
make lint       # structural checks only
```

**Rules** (from global CLAUDE.md):
- ALWAYS `-x` (stop on first failure)
- ALWAYS `--tb=short` (never `--tb=long/full`)
- NEVER `--pdb`, `-s`, `--watch` (interactive modes = hang)

---

## Test Fixtures (`conftest.py`)

Key fixtures available to all tests:
- `PLUGIN_ROOT` — absolute path to repo root
- `SKILLS_DIR` — path to skills/
- `AGENTS_DIR` — path to agents/
- `PROFILES_DIR` — path to profiles/
- Profile data loaded and parsed

---

## Coverage Goals

| Layer | Current | Target |
|-------|---------|--------|
| Skill frontmatter validation | 100% | 100% |
| Skill coverage (no orphans) | ~94% (3 unassigned) | 100% |
| Command routing validation | 100% | 100% |
| Profile integrity | 100% | 100% |
| Hook schema + behavior | 100% | 100% |
| Build output completeness | 100% | 100% |
| E2E hook lifecycle | Partial | Full |

---

## Adding Tests

1. Create `tests/test_{name}.py`
2. Use fixtures from `conftest.py`
3. Follow naming: `test_{category}_{what}()`
4. Add to structural or behavioral category
5. Verify: `make test`

---

*Updated: 2026-03-22 | Maintain when: test file added or test strategy changes*
