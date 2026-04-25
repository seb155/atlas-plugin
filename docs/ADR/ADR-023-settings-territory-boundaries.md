# ADR-023: Settings.json Territory Boundaries

- **Status**: Accepted
- **Date**: 2026-04-25
- **Shipped in**: v6.1.0+ (SP-STATUSLINE-SOTA-V3 Sprint E)
- **Supersedes-in-part**: ADR-019 (extends the territorial principle from `~/.claude/<scripts>/` to `settings.json` itself)
- **Related**: ADR-006 (resolver), ADR-019 (StatusLine SOTA v2 wrapper)

## Context

ADR-019 (2026-04-19) introduced `statusline-wrapper.sh` deployed to `~/.local/share/atlas-statusline/`, a path that dotfile-sync tools (specifically `~/.claude-dotfiles/sync.sh`) do not touch. This protected the *renderer scripts* but left a gap: the **settings.json file itself** is still in `~/.claude/`, where dotfile-sync runs.

On 2026-04-25, the user demonstrated this gap concretely. Within minutes of editing `~/.claude/settings.json` to switch `statusLine.command` from the wrapper to `cship` directly, an external process (suspected `~/.claude-dotfiles/sync.sh` or similar) overwrote settings.json — restoring an older copy that:

1. Reverted `statusLine.command` to the wrapper path (benign, but undoes user intent)
2. **Removed every `enabledPlugins` entry for ATLAS** (`atlas-core`, `atlas-admin`, `atlas-dev`), leaving only `code-review@claude-plugins-official`

The second symptom is severe: it disables every ATLAS plugin component (skills, agents, hooks) until the user manually re-runs `/plugin install`. The wrapper itself was unaffected (ADR-019 holds), but the user-visible installation appeared completely broken because settings.json was wiped.

This is not theoretical: it has happened in production at least three times across the v4.44.0 → v6.1 timespan. Every time, the cause is the same — settings.json lives in territory we don't own.

## Unexamined assumption (ADR-019 era)

> "Protecting the *scripts* is enough. Settings.json is small and the user owns it."

False. Settings.json is **the** user-mutable surface, the highest-value attack target for any benign-but-aggressive sync tool, and the one file CC actually reads to decide what plugins are enabled and what the statusLine should run. Losing it costs more than losing scripts (which can be redeployed by hooks); losing settings.json silently disables features the user installed.

## Decision

ATLAS deploys configuration to **`~/.claude/settings.local.json`**, not `~/.claude/settings.json`.

Both files are read by Claude Code, with `settings.local.json` taking precedence per the official hierarchy (https://code.claude.com/docs/en/settings). `settings.local.json` is conventionally the user's *personal, machine-local* layer and is in most dotfile setups gitignored (and therefore not synced).

We adopt the convention and document the boundary:

| File | Owner | ATLAS writes? |
|------|-------|---------------|
| `~/.claude/settings.json` | User / team (often dotfile-synced) | **Never** |
| `~/.claude/settings.local.json` | User-machine local, ATLAS territory | **Yes** (statusLine, future ATLAS-specific keys) |
| Per-project `.claude/settings.json` | Project / team | Never (unless project explicitly opts in via `settings-template`) |
| Per-project `.claude/settings.local.json` | User local | Optional (project-scoped overrides) |

## Implementation

1. **`scripts/statusline/install.sh`** writes `statusLine` only to `~/.claude/settings.local.json`. Creates the file if absent (with `{}`), preserves all existing keys via `jq` merge, and backs up before write.
2. **`scripts/statusline/doctor.sh`** prefers `settings.local.json` for the Settings check, but warns if `settings.json` has a `statusLine` block — that block is ignored at runtime (lower precedence) but indicates an old install that should be migrated.
3. **`hooks/statusline-heal`** reads `settings.local.json` exclusively. If absent or broken, writes a `~/.atlas/runtime/.statusline-needs-install` sentinel and never auto-mutates settings (HITL boundary preserved).
4. **Skill `statusline-setup`** documents the boundary in user-facing copy.

## Consequences

### Positive

- ATLAS configuration survives any dotfile-sync run that targets `~/.claude/settings.json`.
- Users can edit their `settings.json` without fear of clobbering ATLAS state.
- Team-shared `settings.json` (committed to a project repo) does not leak machine-specific paths like `$HOME/.local/share/...`.

### Negative / mitigations

- **Users with custom `statusLine` in settings.json must migrate.** Mitigation: install.sh is idempotent and migrates automatically. doctor.sh warns if a stale block remains. We document the one-time HITL step.
- **Some dotfile setups also sync `settings.local.json`.** Mitigation: ADR-023 names the convention; aligning with it is a one-line `.gitignore` change for the user. We cannot defend against arbitrary user tooling that ignores the standard convention.
- **Backwards compatibility for fresh upgraders.** Mitigation: install.sh keeps the wrapper path identical to v5.x, so existing settings.json blocks pointing at the wrapper continue to work as a fallback (lower precedence) until the migration runs.

## Out-of-scope

- Identifying *which* dotfile-sync tool overwrites settings.json. That's the user's separate tooling concern. We make ourselves immune; we do not fix the sync.
- Settings format changes upstream (CC may evolve `settings.local.json` semantics). When that happens, we re-evaluate.

## References

- Official: https://code.claude.com/docs/en/settings (settings hierarchy + precedence)
- Forensic session log: 2026-04-25 — capabilities.json regenerates `.version="?"`, settings.json wiped of ATLAS plugins
- ADR-019 — StatusLine SOTA v2 (wrapper-in-`~/.local/share/`)
- Plan: `.blueprint/plans/sp-statusline-sota-v3.md`
