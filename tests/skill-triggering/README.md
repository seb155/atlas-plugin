# ATLAS Skill-Triggering Eval Framework

> **Version**: 0.1.0 | **Created**: 2026-04-19
> **Source**: Ported from [obra/superpowers `tests/skill-triggering/`](https://github.com/obra/superpowers) (MIT, Jesse Vincent)
> **Reference**: [docs/ADR/ADR-007-skill-triggering-eval-framework.md](../../docs/ADR/ADR-007-skill-triggering-eval-framework.md)

---

## What this does

Tests whether ATLAS **skills trigger** on naive user prompts (natural language, no explicit skill-name mention). Catches description drift before users encounter it.

---

## Quick start

### Run all evals

```bash
cd tests/skill-triggering
./run-all.sh                    # verbose: per-skill output
./run-all.sh --quiet            # compact: just pass/fail icons
./run-all.sh --fail-under 80    # exit 1 if pass rate < 80%
```

### Run single skill

```bash
./run-test.sh plan-builder ./prompts/plan-builder.txt
# Exit: 0=PASS, 1=FAIL, 2=ERROR
```

### Filter subset

```bash
./run-all.sh --skill plan-builder,tdd,code-review
```

---

## Directory structure

```
tests/skill-triggering/
├── README.md              (this file)
├── run-test.sh            (single-skill eval)
├── run-all.sh             (batch runner with threshold)
├── generate-prompts.sh    (bootstrap: auto-generate placeholders)
└── prompts/
    ├── <skill-name>.txt   (106 prompts, one per skill)
    └── ...
```

---

## Prompt format

Each `prompts/<skill-name>.txt` contains:
- **Naive user prompt** (no skill name mention)
- Or: first line `# EVAL-EXEMPT: <reason>` marks skill as skip (meta/programmatic skills)

### Good prompt (naive)

```txt
The test `test_parse_nested_json` is failing:

  FAIL src/parser.test.ts
  TypeError: Cannot read property 'items' of undefined

Can you figure out what's going wrong and fix it?
```

Expected: triggers `systematic-debugging` skill.

### Bad prompt (not naive)

```txt
Use systematic-debugging to debug this error.
```

This tests nothing — mentioning skill name guarantees invocation. Always write as a real user would.

---

## Exempt skills (6 currently)

Skills invoked programmatically, without natural language triggers:
- `atlas-assist` (master orchestrator, always loaded)
- `discovery` (capability inspector, manual CLI)
- `atlas-doctor` (diagnostic)
- `statusline-setup` (config)
- `hookify` (meta — hooks editor)
- `atlas-dev-self` (self-development)

Edit `generate-prompts.sh::EVAL_EXEMPT_SKILLS` to modify the list.

---

## Pass rate interpretation

| Rate | Meaning |
|------|---------|
| ≥ 90% | Excellent — descriptions are discoverable |
| 80-89% | Good — most skills trigger reliably |
| 70-79% | Warning — several descriptions need CSO audit |
| < 70% | Regression — something broke, investigate |

**Current baseline**: TBD (will be established after first run).

**Improvement path**: REC-002 CSO audit (30-40h, separate plan) should lift pass rate by ~10-15% via description rewrites.

---

## How it works

1. `run-test.sh <skill> <prompt>`:
   - Invokes `claude -p "$PROMPT" --plugin-dir $PLUGIN_DIR --max-turns 3 --output-format stream-json`
   - Captures stream JSON to log
   - Greps for `"name":"Skill"` + skill identifier
   - Reports PASS/FAIL

2. `run-all.sh`:
   - Iterates all `prompts/*.txt`
   - Skips empty files or `# EVAL-EXEMPT:` marked
   - Aggregates pass rate, supports `--fail-under` threshold

3. Nightly CI (`.woodpecker/skill-eval.yml`):
   - Runs at 03:00 UTC daily
   - Fails build if pass rate < 80%
   - Note: requires claude CLI available in runner (currently scaffolding only)

---

## Adding a new skill

When you add a new skill, add its prompt too:

```bash
# 1. Create your skill
vim skills/my-new-skill/SKILL.md

# 2. Generate placeholder prompt
bash tests/skill-triggering/generate-prompts.sh

# 3. Curate the prompt (replace placeholder with naive user phrasing)
vim tests/skill-triggering/prompts/my-new-skill.txt

# 4. Run single eval to verify it triggers
bash tests/skill-triggering/run-test.sh my-new-skill tests/skill-triggering/prompts/my-new-skill.txt

# 5. Commit both files together
git add skills/my-new-skill/ tests/skill-triggering/prompts/my-new-skill.txt
```

---

## Attribution

Framework adapted from **obra/superpowers** (MIT, Jesse Vincent / Prime Radiant).
Original: `tests/skill-triggering/run-test.sh`, `run-all.sh`, and prompt convention.
ATLAS adaptations: exempt list, threshold config, Woodpecker CI integration, README.

---

*README v1.0 — authored 2026-04-19 as plan `joyful-hare` Path B item #2.*
