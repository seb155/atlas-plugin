# ADR-004 — Profile-First Architecture for ATLAS CLI

**Status**: ACCEPTED (2026-04-18)
**Context**: ATLAS CLI SOTA Refactor (v5.28.0)
**Decision-makers**: Seb Gagnon
**Related**: ADR-005 Distribution Sovereignty

## Context

ATLAS CLI had grown to 15+ flags (tier, permission_mode, effort, worktree, fork_session, bare, mcp_profile, wifi_trust, etc.). Users needed to remember and combine these per-project per-task. This created:

- **Cognitive overload** — especially acute for users with HID pattern (high-intensity development) who benefit from externalized decision frameworks
- **Repetition** — same flag combos per project (e.g. `atlas synapse -w -e high --permission-mode plan --mcp chrome`)
- **Inconsistency** — users forget flags, get unexpected behavior
- **Documentation burden** — CLAUDE.md aliases (`cs/csw/csc`) were fantom references to flag combos that never materialized

## Decision

**Adopt profile-first architecture**: YAML profile files bundle configuration. Flags become override shortcuts, not primary interface.

### Key design choices

1. **YAML over JSON/TOML** — Readable, commentable, native inheritance via `extends`. Parser `yq` v4+ already available.
2. **Inheritance chain** — `extends: base` → max 3 depth. Load order: base → leaf, later overrides earlier.
3. **Auto-detection** — Resolution order: `.atlas/project.json` manifest > cwd glob match > interactive prompt.
4. **Contextual overlays** — WiFi trust, git branch, time-based hooks modify profile fields AFTER base load.
5. **Override composability** — `--override key=value` allows ad-hoc tweaks without editing profile file.
6. **Precedence order** — config defaults → profile → overlays → --override → explicit flags (last wins).
7. **Feature flag rollout** — `ATLAS_AUTO_DETECT_PROFILE=true` opt-in prevents surprise for existing users.

### Profile example

```yaml
name: dev-synapse
extends: base
tier: dev
permission_mode: plan
effort: high
worktree: true
fork_session: auto
mcp_profile: chrome-playwright
cwd_match:
  - "/home/user/projects/synapse/**"
git_branch_hook:
  "feature/*": { fork_session: true }
```

### Usage after profile-first

Before:
```bash
atlas synapse --tier dev --permission-mode plan --effort high -w --mcp chrome
```

After:
```bash
atlas synapse                           # Auto-detect dev-synapse from cwd
atlas synapse --override effort=max     # Single-field override
```

## Alternatives Considered

### A. Flag flag flag (status quo)
**Pros**: Explicit, no magic.
**Cons**: Cognitive overload. Repetition. Users forget flags.

### B. Config profiles as flat JSON (like `~/.atlas/config.json`)
**Pros**: Zero new deps, matches existing config.
**Cons**: No inheritance. No comments. Multiple profiles per file = awkward.

### C. Environment files (.env-style)
**Pros**: Familiar UNIX pattern.
**Cons**: No structure beyond key=value. No nested fields (git_branch_hook = map-of-maps).

### D. Profile-first YAML (chosen)
**Pros**: Readable, nested, inheritance, composable, tool support (yq).
**Cons**: New abstraction layer (mitigated by feature flag rollout).

## Consequences

### Positive
- **Zero-config daily flow** — type `atlas` in a project dir, everything loads
- **DRY configuration** — profiles inherit from base, overlays cover context
- **Discoverable** — `atlas profile list` shows all, `atlas profile show X` dumps YAML
- **Debug-friendly** — `atlas --detect-only` and `--print-command` show resolved state
- **Aligns with HID cognitive pattern** — framework delegates routine decisions

### Negative
- **Learning curve** — new users must understand profile schema
- **New file format** — yq dependency (mostly already installed)
- **Conflict with existing ATLAS_PROFILE** — user preset "axoiq" vs launch profiles. Mitigated via ATLAS_LAUNCH_PROFILE env var naming.
- **Migration** — existing flag users need docs for transition (covered in MIGRATION-GUIDE.md)

### Neutral
- **Backward compat preserved** — explicit flags still work. Profile opt-in via `--profile <name>`.
- **2-release deprecation** — old flags → warn → remove in v5.30.0.

## Rollout Plan

- **v5.28.0** (this release): profile system shipped, opt-in via `--profile` or `ATLAS_AUTO_DETECT_PROFILE=true`
- **v5.29.0**: default `ATLAS_AUTO_DETECT_PROFILE=true` (if feedback positive)
- **v5.30.0**: remove deprecated `-y/--yolo` (replaced by `--override mode=dontAsk`)
- **v6.0.0**: consider flag → override shortcut migration (breaking change)

## References

- Plan: `.blueprint/plans/regarde-cest-quoi-atlas-snoopy-unicorn.md` (C.1 Profile-First Primitive)
- Decision log: D1, D2, D3 (2026-04-18)
- User context: HID cognitive pattern (externalized frameworks for decision delegation)
- Implementation: `scripts/atlas-modules/platform.sh` (`_atlas_load_profile`, `_atlas_detect_profile`, 3 overlays)
- Docs: [PROFILE-SYSTEM.md](../PROFILE-SYSTEM.md)
