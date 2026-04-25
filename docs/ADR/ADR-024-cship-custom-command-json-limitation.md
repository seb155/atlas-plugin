# ADR-024: CShip Custom Command JSON Limitation

- **Status**: Accepted (descriptive, documenting an upstream constraint)
- **Date**: 2026-04-25
- **Discovered in**: SP-STATUSLINE-SOTA-V3 Sprint B investigation
- **Related**: ADR-019 (StatusLine wrapper), SP-STATUSLINE-V3 deliverables L11/L12

## Context

CShip (https://cship.dev/, https://github.com/stephenleo/cship) is a Rust statusline renderer for Claude Code. It accepts a TOML config file (`~/.config/cship.toml`) with both built-in modules (`$cship.model`, `$cship.cost`, `$cship.context_bar`, etc.) and `[custom.X]` modules whose values are produced by shell commands.

ATLAS shipped six custom modules in v5.x:
- `atlas-context-size-module.sh` — emits "1M" or "200K"
- `atlas-200k-badge-module.sh` — emits ⚠️ when token count exceeds 200K
- `atlas-effort-module.sh` — emits effort symbol
- `atlas-cost-usd-module.sh` — emits session cost
- `atlas-agents-module.sh` — emits running subagent count
- `atlas-alert-module.sh` — conditional alert

Each module reads `CSHIP_*` environment variables (e.g., `CSHIP_CONTEXT_SIZE`, `CSHIP_MODEL_ID`, `CSHIP_EXCEEDS_200K_TOKENS`) and emits a short string.

**The problem**: those environment variables are never set.

## Investigation (2026-04-25)

### Probe 1 — env dump from a custom command

A test custom module dumped `env` to disk while CShip rendered:

```bash
[custom.envdump]
command = "/tmp/dump-env.sh"
```

Result: zero `CSHIP_*` variables present. The only non-shell env vars were Claude Code's own (`CLAUDE_CODE_*`) and `PATH`.

### Probe 2 — direct CShip with --config

`cship --config /tmp/cship-probe.toml` ran but never executed the custom command (the dump file remained from a stale run; cship exited 0 with empty rendered output).

### Probe 3 — Starship pass-through

`starship explain` with the same `[custom.X]` block correctly executed the command and rendered "PROBED" — but the command's stdin was empty and `env` showed no JSON-derived variables.

### Conclusion

CShip and Starship both invoke `[custom.X]` commands as subprocesses with **empty stdin and no JSON-derived environment variables**. The `command` field supports template substitution for built-in CShip variables (`$cship.model.id`, `$cship.context_window.size`), but those substitutions happen in the *config* layer — they never become `CSHIP_*` env vars at command-execution time.

Public documentation at cship.dev and the GitHub README do not document any `CSHIP_*` env var contract. The atlas-*-module.sh assumption was either:

1. Speculative future-proofing that never matched real CShip behavior, or
2. Imported from an earlier statusline tool that *did* expose env vars and the convention was carried over without verification.

Either way, the modules have been silently no-ops since they shipped: every `CSHIP_*` read returns empty, every fallback path is taken, and the custom segments add no information to the rendered statusline.

## Decision

We accept this as an upstream constraint and adapt:

1. **Pure-bash `statusline-command.sh` is the canonical render path.** It receives the official CC JSON via stdin (per the documented statusLine contract) and renders all fields directly. Sprint A's L9/L10 patches address the field-name bugs in this script.

2. **CShip stays installable but is no longer authoritative.** Users with `cship.toml` configurations continue to work — built-in CShip modules render fine, they just don't pull values from our custom modules. The `cship.toml` we ship references the custom modules for visual symmetry; their absence is harmless.

3. **The custom modules are kept in `~/.local/share/atlas-statusline/modules/`** for backward-compat. Old user configs that reference them by path continue to find them. No new module is added.

4. **L11 and L12 (rate_limits + exceeds_200k field-name fixes for the modules) are formally cancelled.** The fix would have changed which env var the module reads; since no env var is set, the fix has no observable effect. They are not blocking deliverables.

5. **Future work to communicate values to custom modules (if ever needed):**
   - Ship a JSON dump file (`/tmp/cc-statusline-$session_id.json`) written by `statusline-command.sh` that custom modules can read.
   - Add a CShip upstream PR to expose CC JSON via env vars or stdin to custom commands.
   - Track as separate plan SP-STATUSLINE-CSHIP-CONTRACT (not committed, exploratory only).

## Consequences

### Positive

- We stop pretending the modules transport JSON they don't actually receive.
- The pure-bash render path is the single source of truth — easier to test, easier to debug.
- Sprint A's official-schema fixes (L9, L10) cover the rendering surface that actually displays to the user.

### Negative

- Users who explicitly configured CShip thinking the modules added information get the same empty values they were already getting. Doctor warns about this in `cship.toml` check by noting modules are "legacy".
- We retain ~6 KB of dead-code shell scripts in the deploy. Not a meaningful storage cost; the tradeoff is keeping users' references intact.

## References

- CShip homepage: https://cship.dev
- CShip repo: https://github.com/stephenleo/cship
- Starship custom modules: https://starship.rs/config/#custom-commands (notes that custom commands run as subprocesses with no special env)
- Investigation notes: SP-STATUSLINE-V3 Sprint B (2026-04-25), commits in `feature/statusline-sota-v3`
