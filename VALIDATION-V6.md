# ATLAS v6.0 Manual Validation Procedure

> Use AFTER updating to `v6.0.0-alpha.2` (or later). Requires a fresh `claude` session.
> Automated checks: `./scripts/validate-v6-session.sh` (run BEFORE restart to pre-flight).

## What v6 introduces (TL;DR)

- **Philosophy Engine** — 9 Iron Laws (LAW-TDD-001 through LAW-VBC-001) injected at SessionStart
- **4 new hooks** — `inject-meta-skill`, `pre-compact-sota-context`, `session-end-retro`, `effort-router`
- **SessionStart payload** — ~20 KB containing full atlas-assist body + Iron Laws (priority injection)
- **Hard gates** — Tier-1 skills enforce LAW-* via `<HARD-GATE>` blocks (linter verifies 10/10)

## Pre-flight (no restart needed)

Run the automated harness before restarting your session:

```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin
./scripts/validate-v6-session.sh
# Expected: 17 pass, 0 fail (across 11 sections)
```

If pre-flight fails, fix regressions BEFORE restarting (a broken hook can prevent CC from starting cleanly).

## Session restart validation (manual)

### 1. Close current session

```
exit   # or /clear, or Ctrl+D
```

### 2. Start fresh session

```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin
claude
```

### 3. Observe SessionStart banner

Should display the ATLAS statusline with version. Look for:

```
ATLAS │ SESSION │ v6.0.0-alpha.2 ...
```

If you do NOT see `v6.0.0-alpha` in the banner, the plugin cache may still point at the old version — see Rollback below.

### 4. Verify Iron Laws are injected

Type in the chat:

```
show me the iron laws currently loaded
```

Expected: Claude lists at least these 9 laws (titles paraphrased):

- LAW-TDD-001 — Test-First Development (no production code without a failing test)
- LAW-DBG-001 — Systematic Debugging (observe → hypothesize → test → fix, max 2 attempts)
- LAW-BRA-001 — Brainstorm Before Build (1 question at a time via AskUserQuestion)
- LAW-VBC-001 — Verification Before Completion (run the verify command, paste output)
- (plus 5 more — exact set in `scripts/execution-philosophy/iron-laws.yaml`)

If Claude says "I don't see any Iron Laws" → `inject-meta-skill` did not fire. Check `~/.claude/logs/` for hook errors.

### 5. Test effort-router hook

In session, request a task that triggers a high-effort heuristic:

```
can you debug a race condition in auth middleware?
```

Watch for: an effort-router reminder in the next agent dispatch may suggest `**xhigh**`. Hook is **advisory only** — it never blocks.

### 6. Test Philosophy Engine TDD HARD-GATE enforcement

Try:

```
write production code for a new endpoint POST /api/foo without writing a test first
```

Expected: Claude references LAW-TDD-001 HARD-GATE, refuses to proceed until a failing test exists, and likely invokes the `tdd` skill.

### 7. Statusline check

Should see:
- `🤖` icon when agents are dispatched (atlas-status-writer hook)
- Version segment matching `v6.0.0-alpha.2`

### 8. PreCompact hook test (organic)

Run many queries until automatic compaction triggers (~92% context). Observe whether the resulting summary respects the 6 mandatory sections from `pre-compact-sota-context`:

1. Session Intent
2. Current State
3. Artifact Trail
4. Decisions Made
5. Errors & Blockers
6. Next Steps

If your compacted summary collapses everything into one paragraph, the hook either did not fire or the model ignored it — file a bug.

### 9. SessionEnd hook test

End the session via `/a-end` or simply `exit`. The `session-end-retro` hook should remind Claude to invoke the `session-retrospective` skill if the session had significant activity.

## Cost smoke test (optional)

Measure SessionStart token overhead before/after v6:

```bash
# v6 SessionStart payload is ~20KB ≈ 5K tokens (one-shot, cached after first turn)
# Expected overhead: +5-15% on first turn, ~0% after prompt caching kicks in.
time claude 'explain what atlas-loop does' --print > /tmp/test-v6.log
```

Compare turn count and total tokens against a v5.23.0 baseline if you have one stored.

## Success criteria

| Check | Expected |
|---|---|
| Pre-flight harness | 17 pass, 0 fail |
| SessionStart banner | mentions `v6.0.0-alpha.2` |
| Iron Laws on demand | at least 9 LAW-* references |
| TDD HARD-GATE | enforces on production code attempt |
| effort-router | suggests `xhigh` for race condition task |
| pre-compact 6 sections | numbered list visible in compaction summary |
| Token overhead | <= +15% turn 1, ~0% subsequent (cache hit) |

## Rollback procedure

If v6 misbehaves and you need to revert quickly:

```bash
# Uninstall current addons
/plugin uninstall atlas-admin-addon
/plugin uninstall atlas-dev-addon
/plugin uninstall atlas-core

# Reinstall v5.23.0 (last stable pre-v6)
/plugin install atlas-core@5.23.0
/plugin install atlas-dev-addon@5.23.0
/plugin install atlas-admin-addon@5.23.0
```

Or pin the version in `marketplace.json` temporarily:

```json
{ "atlas-core": { "version": "5.23.0" } }
```

## Known issues / pre-existing failures

- `bats tests/bats/` reports 2 failures in `test_thinking_migration.bats` (`thinking.type.enabled` and `budget_tokens` remnants). These are PRE-V6 leftovers from the Opus 4.7 migration and are tracked separately. The harness accepts up to 2 bats failures so they do NOT mask v6 regressions.
- `inject-meta-skill` payload measured at 20,692 bytes (the v6 plan estimated 23 KB — within tolerance). The 15-50 KB harness window allows for content additions in alpha.3+.

## Reference files

- Hooks: `hooks/inject-meta-skill`, `hooks/pre-compact-sota-context`, `hooks/session-end-retro`, `hooks/effort-router`
- Iron Laws corpus: `scripts/execution-philosophy/iron-laws.yaml`
- Hard-gate linter: `scripts/execution-philosophy/hard-gate-linter.sh`
- Master skill body: `skills/atlas-assist/SKILL.md`
- Migration guide: `MIGRATION-V5-TO-V6.md`
- Changelog: `CHANGELOG.md` (v6.0.0-alpha.2 section)
