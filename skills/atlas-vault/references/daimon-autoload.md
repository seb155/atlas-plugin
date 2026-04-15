# DAIMON Auto-Calibration Hooks (SP-DAIMON P1)

Two SessionStart hooks that read a user's DAIMON profile from their vault
and inject session-tailored context into Claude's system prompt.

## Components

| Hook | Event | Role |
|------|-------|------|
| `vault-profile-auto-load` | SessionStart (sync, 10s) | Reads vault → writes `~/.atlas/runtime/session-calibration.json` |
| `daimon-context-injector` | SessionStart (sync, 3s) | Reads cache → emits `<daimon-calibration>` block to stdout |

Order matters: `vault-profile-auto-load` must run BEFORE `daimon-context-injector`.
Both are sync to avoid race conditions.

## User Setup (one-time)

1. Ensure your vault has DAIMON structure:
   ```
   vault/
   ├── daimon/
   │   ├── <user>.daimon.md       # Big Five, Enneagram, Values
   │   └── <user>.telos-profond.md (optional) # Cognitive pattern, deep telos
   ├── profile/user-profile.json
   ├── kernel/config.json         # NEW (this feature)
   └── sharing.json               # NEW/extended (ACL)
   ```

2. Enable the feature in `vault/kernel/config.json`:
   ```json
   {
     "schema_version": "1.0",
     "daimon_auto_load": true
   }
   ```

3. Define ACL in `vault/sharing.json`:
   ```json
   {
     "daimon/<user>.daimon.md": {
       "auto_load": true,
       "trust_levels": ["high"],
       "fields": ["big_five", "enneagram", "core_values"]
     },
     "daimon/<user>.telos-profond.md": {
       "auto_load": true,
       "trust_levels": ["high"],
       "fields": ["cognitive_pattern", "deep_telos"]
     }
   }
   ```

4. Point `~/.atlas/profile.json` at your vault:
   ```json
   {"vault_path": "/path/to/your/vault"}
   ```
   (OR place vault at `$ATLAS_ROOT/vaults/<name>` for auto-detection.)

5. Start a new Claude Code session. The `<daimon-calibration>` block
   will appear in Claude's context automatically.

## Runtime Behavior

```
SessionStart (CC fires hooks)
  ↓
vault-profile-auto-load (sync, 10s timeout)
  ├── Resolve vault path (~/.atlas/profile.json > $ATLAS_ROOT/vaults/*)
  ├── Check opt-in flag (kernel/config.json: daimon_auto_load)
  ├── Check fingerprint cache (1h TTL)
  ├── Parse daimon/*.daimon.md + *.telos-profond.md
  ├── Respect sharing.json ACL (per-file + per-field)
  └── Write ~/.atlas/runtime/session-calibration.json (mode 0600)
  ↓
daimon-context-injector (sync, 3s timeout)
  ├── Read session-calibration.json
  └── Emit <daimon-calibration> block to stdout (goes into system prompt)
```

## Silent Failure Invariant

Both hooks MUST exit 0 cleanly on ANY error path. NEVER break Claude Code.

Guarantees:
- No vault found → exit 0
- Vault exists but no config.json → exit 0
- config.json but `daimon_auto_load: false` → exit 0
- Malformed JSON in cache → context-injector exits 0 (logs to stderr)
- Python unavailable → exit 0
- Parse error on daimon file → continues with partial data, logs warn

## Performance

| Scenario | Time |
|----------|------|
| Cold run (full parse) | ~80ms |
| Cache hit (fingerprint match, <1h) | ~50ms |
| Cache file size | ~2 KB |
| Context block size | ~400-700 tokens |

## Disable

- Per-vault: set `daimon_auto_load: false` in `vault/kernel/config.json`
- Force-off: delete `~/.atlas/runtime/session-calibration.json`
- Full rollback: remove hook entries from `hooks/hooks.json`

## Tests

```bash
bats tests/shell/test_vault_profile_auto_load.bats
bats tests/shell/test_daimon_context_injector.bats
```

29 tests covering happy path, silent failure, privacy ACL, caching, schema.

## Related

- Plan: `synapse/.blueprint/plans/sp-daimon-calibration.md`
- Upstream skill: `skills/atlas-assist/SKILL.md` (reads calibration for dynamic persona)
- P2 follow-up: `keyword-aware-calibration` hook + `pattern-signal-detector` agent
- P3 follow-up: feedback loop Episode → DAIMON evolution-log
