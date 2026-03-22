# Performance Rules (ATLAS Plugin)

## Hook Constraints
- Async hooks: max 5s execution, exit 0 on error (non-blocking)
- Sync hooks: max 10s, can block Claude Code
- SessionStart total: target < 3s (all hooks combined)
- Hook output: keep under 500 chars (injected into context)

## Skill Context Budget
- Each skill adds ~100-300 tokens to session context (when loaded)
- Admin tier atlas-assist: ~7K tokens. User tier: ~3K tokens
- Skills are loaded on-demand via slash commands, not all at once
- Keep SKILL.md content focused — move details to .blueprint/ docs

## Build Performance
- `./build.sh all`: target < 30s for all 3 tiers
- `make test`: target < 60s for full 16-file suite
- `make dev`: target < 15s (build admin + install)

## Script Performance
- `get-secret.sh`: cache lookups in keyring (avoid repeated bw calls)
- `atlas-e2e-validate.sh`: parallelize independent checks where possible
- `detect-platform.sh`, `detect-network.sh`: cache results per session

## Anti-Patterns
- NEVER add `sleep` in hooks (blocks session startup)
- NEVER make network calls in SessionStart hooks (flaky on poor connections)
- NEVER load entire SKILL.md when a summary would suffice
- NEVER duplicate logic between hooks — extract to shared script
