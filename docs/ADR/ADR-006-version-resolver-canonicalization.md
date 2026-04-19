# ADR-006 — Version Resolver Canonicalization via `claude plugin list --json`

**Status**: ACCEPTED (2026-04-19)
**Context**: ATLAS Plugin v5.30.0 — status line drift fix
**Decision-makers**: Seb Gagnon
**Related**: ADR-004 (Profile-First Architecture), ADR-005 (Distribution Sovereignty)

## Context

The ATLAS status line (starship/cship) displays the plugin version by reading `~/.atlas/runtime/capabilities.json`, written at `SessionStart` by `scripts/atlas-discover-addons.sh`. Two bugs surfaced on 2026-04-19:

1. **Stale snapshot after `/reload-plugins`**: Claude Code does NOT re-trigger `SessionStart` on plugin install/upgrade/reload. `capabilities.json` stays frozen until the next `startup|resume|clear|compact` matcher fires.

2. **Fragile filesystem parsing**: The discover script used `ls -1d | sort -V | tail -1` over `~/.claude/plugins/cache/atlas-marketplace/<plugin>/`. With 35 orphan versions in the cache (5.0.2 → 5.29.1), a race between `SessionStart` (at 13:07:55Z) and CC's registry write (at 13:08:02Z) caused the scan to resolve `5.28.0` moments before `5.29.0` landed.

Observable symptom: status line showed `ATLAS v5.28.0` while `claude plugin list --json` returned `version: 5.29.1`. User expectation: status line should always show the **active** version.

## Options evaluated

| # | Option | Pros | Cons |
|---|---|---|---|
| 1 | **Use `claude plugin list --json` as Tier 1 SSoT** | Canonical; no race; CC handles enabled/scope logic | ~1.5s CLI fork cost — requires cache |
| 2 | Timestamp drift detector (auto-rerun discover if `cache_mtime > capabilities.computed_at`) | Zero new dependency | Doesn't solve `/reload-plugins` case; polling-based |
| 3 | Custom event subscription (`/plugin install` hook via CC API) | Precise trigger | CC does NOT expose PluginReload event; requires upstream patch |
| 4 | Pin discover to single known path per plugin | Eliminates filesystem scan fragility | Still race-prone; loses multi-version support |
| 5 | Status quo (filesystem parsing) | No change | The bug that motivated this ADR |

## Decision

**Primary: Option 1 (`claude plugin list --json` as canonical Tier 1)**
**Supporting: drift sentinel pattern for `/reload-plugins` recovery**

### Architecture

```
Tier 0: ~/.atlas/runtime/.resolve-version.cache   (mtime < 5s → return)
Tier 1: claude plugin list --json                 (canonical SSoT)
Tier 2: ~/.atlas/runtime/capabilities.json        (SessionStart snapshot)
Tier 3: filesystem scan                           (zero-dep fallback)
  ↓
"?" literal if all fail
```

**Drift sentinel (event-agnostic refresh)**:

```
  resolve-version.sh detects Tier-1 ≠ capabilities.version
     → touch ~/.atlas/runtime/.capabilities.stale
  next UserPromptSubmit
     → capabilities-refresh hook sees sentinel
     → rerun atlas-discover-addons.sh
     → rm sentinel
```

Max 1 refresh per user turn. Idempotent. No dependency on `/reload-plugins` matcher.

### Why NOT Option 2 (timestamp detector)

Timestamp-based drift detection works for the race-condition case but not for `/reload-plugins` on an already-up-to-date cache (timestamps don't change). Also polling-only.

### Why NOT Option 3 (PluginReload event)

Claude Code does not expose such an event matcher as of 2026-04. Adding upstream support would gate this fix on external release. The sentinel pattern achieves the same outcome with existing hooks.

### Why NOT Option 4 (single-path pin)

Loses the defense-in-depth of a fallback chain. If CC changes cache layout, we'd need a plugin release to follow.

## Consequences

**Positive**:
- Status line always in sync with CC's notion of the active plugin (within 5s).
- New `.source` field in `capabilities.json` (`cli|fs|mixed|empty`) gives observability.
- `atlas-doctor --prune-plugin-cache` subcommand added (reduces cache from 35 → 5 versions typically).
- 17 bats tests lock the behavior.

**Negative**:
- Cold-path now costs ~300ms (CLI fork + jq) instead of ~50ms (fs scan). Masked by 5s TTL cache.
- 1 new hook (`capabilities-refresh`) on `UserPromptSubmit` — adds ~5ms per prompt (async, timeout 5s).

**Reversal cost**: low. Filesystem fallback is preserved (Tier 3). Rolling back to v5.29.x restores pre-v5.30 behavior with zero data migration.

## Implementation

Commits in `feature/statusline-sota-resolver`:

| Commit | Task | Files |
|---|---|---|
| `e0f4fe7` | T1 refactor discover | `scripts/atlas-discover-addons.sh` |
| `074d6c8` | T2 refactor resolver + 5s TTL | `scripts/atlas-resolve-version.sh` + dist |
| `d8bfc2b` | T3 capabilities-refresh hook | `hooks/capabilities-refresh` + `hooks.json` + `profiles/core.yaml` |
| `bba136b` | T4 doctor prune | `scripts/doctor-prune.sh` + `SKILL.md` |
| `9e06e89` | T5 bats tests | `tests/bats/*.bats` (17 tests) |

Schema bump: `capabilities.json` v1.0 → v1.1 (additive: `.source`, `.resolved_at_unix`, `.cc_cli_available`, per-addon `.source`). Consumers unaffected.

## Verification

```bash
# Manual
claude plugin list --json | jq '.[] | select(.id=="atlas-core@atlas-marketplace") | .version'
bash ~/.local/share/atlas-statusline/atlas-resolve-version.sh
jq '.version, .source' ~/.atlas/runtime/capabilities.json

# Automated
cd atlas-plugin && bats tests/bats/
# Expected: 17/17 PASS
```

## References

- Plan: `.blueprint/plans/la-status-line-affiche-radiant-horizon.md` (Synapse repo)
- Related commits: v5.29.1 (auto-release 2026-04-19), ADR-005 distribution
- Rule: `.claude/rules/plugin-cache.md` (NEVER edit cache directly)
- Rule: `.claude/rules/compaction-protocol.md` (capabilities.json is cache, not SSoT)
