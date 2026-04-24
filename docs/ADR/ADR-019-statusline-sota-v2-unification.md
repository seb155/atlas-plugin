# ADR-019: StatusLine SOTA v2 Unification

- **Status**: Accepted
- **Date**: 2026-04-19
- **Shipped in**: v5.36.0
- **Supersedes-in-part**: ADR-006 (version resolver canonicalization — v5.30.0)
- **Related**: ADR-006 (resolver Tier 1/2/3), session-start hook deploy pattern

## Context

Between 2026-04-07 (v4.44.0) and 2026-04-19 AM (v5.30.1), the ATLAS plugin
version failed to display in the Claude Code status line. Three major
"fixes" shipped and all regressed:

| Attempt | Version | Approach | Failure mode |
|---------|---------|----------|--------------|
| 1 | v4.44.0 | CShip custom.atlas_version module + sed-patch | Only Starship/CShip users benefited (~20%); bash fallback stale |
| 2 | v5.0.2 → v5.5.1 | Pivot `installed_plugins.json` → `capabilities.json` + fs fallback | SessionStart writes `capabilities.json` but is NOT re-triggered by `/reload-plugins`; stale within hours |
| 3 | v5.30.0 → v5.30.1 | 3-tier resolver (CLI/caps/fs) + 5s TTL + drift sentinel on UserPromptSubmit | Unified cship path, but bash `statusline-command.sh` never migrated to resolver — still read `capabilities.json` directly |

The user reported 100+ attempts to resolve this. Each fix targeted a
different **code layer** (one of 7 version sources: `VERSION`, `plugin.json`,
`marketplace.json`, `installed_plugins.json`, `capabilities.json`,
`session-state.json`, `package.json`) but none audited the **deployment
pipeline**.

On 2026-04-19 12:58 EDT, md5 triangulation proved the true root cause:

```
ec789f12facf60abdfbbcad2db04c7c2  ~/.claude/statusline-command.sh           (active — what CC executes)
ec789f12facf60abdfbbcad2db04c7c2  ~/.claude-dotfiles/statusline-command.sh  (culprit — stale v2.1.88 source)
d406307fbbcaf4e20930c771517a25fb  atlas-core/5.35.0/scripts/statusline-command.sh  (correct — plugin-shipped)
```

The plugin-shipped `statusline-command.sh` never reached the user because
`~/.claude-dotfiles/sync.sh:22` ran independently (on developer workstations
and via cron on some systems), copying a stale 2026-02-24 file over the
plugin's deploy every time.

## Unexamined assumptions (shared by all 3 prior attempts)

1. *"A single code path exists."* False — cship (Rust binary) and bash
   fallback are two independent consumers of the resolver.
2. *"`/reload-plugins` triggers SessionStart."* False — CC does not expose
   a `PluginReload` event; SessionStart only fires on `startup|resume|clear|compact`.
3. *"The plugin controls the deploy pipeline end-to-end."* False — at
   least one external actor (dotfiles sync) can overwrite in the same
   `~/.claude/` path.
4. *"Source of version is coherent."* False — 7 sources, each refreshed
   on different schedules, with no canonical ordering until v5.30.0.
5. *"Unit tests cover the affected surface."* Technically true, but
   no test asserted the actual **rendered** status line output — all
   regressions shipped green.

## Decision

Introduce a **thin wrapper layer** (`statusline-wrapper.sh`) deployed
to `~/.local/share/atlas-statusline/`, a territory dotfiles sync does
not touch, and pivot `settings.json statusLine.command` to point at it.
The wrapper delegates rendering to the plugin-shipped
`statusline-command.sh` for the resolved version, reusing the v5.30.0
resolver (ADR-006) for version resolution.

### New architecture

```
  settings.json
    statusLine.command = "$HOME/.local/share/atlas-statusline/statusline-wrapper.sh"
                                           │
                                           │ exec (stdin/stdout/exit passthrough)
                                           ▼
  atlas-core/scripts/statusline-wrapper.sh  (≈70 lines, dotfiles-free path)
    1. Invoke atlas-resolve-version.sh (ADR-006 Tier 1/2/3)
    2. Parse version string (strip update indicator "5.5.1 ↗ 5.5.2")
    3. Build plugin path: $CACHE_ROOT/$version/scripts/statusline-command.sh
    4. exec that script (stdin/stdout/exit pass through)
    Fallback: "🏛️ ATLAS ?  (unresolvable — run /atlas doctor --statusline)"
                                           │
                                           ▼
  atlas-core/{version}/scripts/statusline-command.sh  (unchanged, 135 lines)
    — reads capabilities.json for version field
    — outputs "🏛️ ATLAS {version}  {dir} {git} {session} {agents} {ctx%} {rate%} {effort} {model}"
```

### Drift refresh (preserved from v5.30.0)

```
UserPromptSubmit hook: capabilities-refresh
  ← sentinel: ~/.atlas/runtime/.capabilities.stale
  (touched by atlas-resolve-version.sh when Tier 1 CLI version ≠ capabilities.json)
  → reruns atlas-discover-addons.sh + removes sentinel
```

This handles `/reload-plugins` (which does not re-trigger SessionStart) by
refreshing `capabilities.json` on the next user prompt.

## Consequences

### Positive

- **Dotfiles-free territory.** Sync scripts cannot race with plugin deploys
  because they operate in `~/.claude/`, not `~/.local/share/atlas-statusline/`.
- **Version-agnostic settings.json.** Users never edit `settings.json` on
  plugin upgrade; the wrapper resolves latest version at each invocation.
- **Single chain of responsibility.** cship users can (optionally) also
  invoke the wrapper if they want one resolved render; bash users get it
  by default.
- **Regression visibility.** The accompanying E2E test (`tests/statusline-e2e.sh`)
  asserts actual rendered output contains `🏛️ ATLAS {VERSION}` AND the
  model token. Any regression of the same class as v4.44.0→v5.30.1 fails
  CI immediately.

### Negative / Required migration

- **Breaking change to `settings.json`.** Existing installs have
  `statusLine.command = "$HOME/.claude/statusline-command.sh"`. This must
  be updated manually or via `/atlas statusline-setup` / `/atlas doctor --fix`.
- **Users with dotfiles that sync statusline-command.sh** must remove the
  copy from their sync script (see `~/.claude-dotfiles/sync.sh`
  commit reference in this repo's MEMORY.md lesson).
- **One extra process per status line render.** Wrapper exec's plugin
  script — measured overhead <15ms on tested systems, negligible vs the
  5s TTL cache of the resolver.

### Neutral

- `capabilities-refresh` hook (v5.30.0) is unchanged but now materially
  active, having been dormant on bash-path users until this ADR.

## Rejected alternatives

### A. Surgical patch — just fix dotfiles

Remove `statusline-command.sh` from `sync.sh:22`, redeploy from plugin at
SessionStart. Works immediately; still leaves 4 of 5 unexamined assumptions
live (dual paths, reload trigger gap, scattered version sources, no E2E).
First regression on a future CC update kills it. Rejected as a repeat of
the pattern that caused 100 failed attempts.

### B. Move to `~/.claude/plugins/...` direct reference

`settings.json statusLine.command = "$HOME/.claude/plugins/cache/atlas-marketplace/atlas-core/5.36.0/scripts/statusline-command.sh"`.
Direct and dotfiles-proof, but hardcodes version — user must edit on every
plugin upgrade. Rejected: negates the "version-agnostic" property.

### C. Inline bash in `settings.json statusLine.command`

Multi-line bash with version resolution inline. Works but ugly, unreadable,
and impossible to test in isolation. Rejected: worse DX, no test surface.

### D. Defensive watchman (periodic drift check + auto-repair)

Cron job that md5sums the deployed statusline vs plugin source and re-copies
on drift. Accepts the dual-path architecture; adds a guard rail. Rejected:
papers over the architectural debt rather than eliminating it, introduces
a new component to maintain, and makes the underlying invariant harder to
reason about.

## Validation

- `tests/bats/test-statusline-wrapper.bats` — 8 scenarios, all green
- `tests/bats/test-capabilities-refresh.bats` — 6 scenarios, all green
- `tests/bats/test-atlas-resolve-version.bats` — 17 existing resolver tests (unchanged)
- `tests/statusline-e2e.sh ci` — hermetic render assertion, passes
- `tests/statusline-e2e.sh --local` — real-system render assertion, passes
  on laptop PC-S16 at 2026-04-19 13:27 EDT

### Regression detection validated

With wrapper's `CACHE_ROOT` pointed at `/nonexistent-broken-path`:
- E2E exits 1 with clear diagnostic naming the failure mode
- Standard "🏛️ ATLAS X.Y.Z" grep passes (fallback emits marker) but
  strict assertion (marker + model token) correctly fails
- After restoring `CACHE_ROOT`, E2E exits 0

## References

- **Plan**: `synapse/.blueprint/plans/le-version-de-atlas-curried-sunset.md`
- **Evidence file**: `memory/statusline-drift-evidence-2026-04-19.md`
- **Feature branch**: `feature/statusline-sota-v2-unification`
- **Related ADRs**:
  - ADR-006 (resolver Tier 1/2/3) — preserved and materially activated by this work
- **User impact doc**: `CHANGELOG.md` v5.36.0 entry
- **Memory entry**: `lesson_statusline_deployment_pipeline.md` (to be created
  post-ship — captures the "audit the deploy pipeline when code fixes don't
  stick" heuristic for future sessions)
