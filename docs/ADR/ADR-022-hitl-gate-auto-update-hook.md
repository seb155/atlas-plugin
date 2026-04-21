# ADR-022: HITL confirmation gate on `atlas_auto_update_plugins` hook

**Status**: Accepted (2026-04-20) — implemented in commit `5b5e647` on
`feature/phase-b-zero-trust` (atlas-plugin repo)
**Authors**: Sebastien Gagnon (with ATLAS)
**Supersedes**: none
**Related**: ADR-020 (CF Access), ADR-021 (device flow bootstrap)
**Phase**: B.3 of aujourdhui-su-rmon-ordinateur-clever-blum.md Zero-Trust pyramid

## Context

The `hooks/lib/auto-update.sh` helper (function `atlas_auto_update_plugins`)
runs at every Claude Code SessionStart. When it detects that the marketplace
advertises a newer plugin version than installed, it silently executes:

```bash
git fetch origin main
git pull --ff-only origin main
make dev
```

…and then copies `dist/atlas-*/` into the user's `~/.claude/plugins/cache/`.

This behavior optimizes for **convenience** (users always on latest ATLAS
without manual action) but at the cost of **supply-chain safety**: anyone
who compromises `plugins.axoiq.com` (DNS hijack, CF misconfig, Forgejo
credential theft, MITM on WAN hop) can push malicious hooks/skills that
auto-execute in every CC session of every consumer — with the same
permissions as the user.

Phase A (shipped 2026-04-20 20:54 EDT) closed the external exposure of
`plugins.axoiq.com` (SSO gate on non-manifest/non-git paths). But the
auto-update mechanism remains a trusted-channel attack vector even if the
channel is authenticated: a legitimate CF Access token holder can still push
malicious commits to `axoiq/atlas-plugin` (e.g., compromised Woodpecker
CI runner → malicious commit → auto-release → every user downloads at
next SessionStart → RCE).

## Decision

Modify `atlas_auto_update_plugins` to **require explicit user confirmation**
before executing `git pull + make dev`. The gate fires unless one of:

- `ATLAS_AUTO_UPDATE_CONFIRMED=1` — user has explicitly opted in this session
- `CI=1` — non-interactive automation context (Woodpecker runners)
- `ATLAS_UPGRADE_FORCE=1` — `atlas upgrade --force` user-initiated command

Default behavior when gate fires:

```
🆙 ATLAS v5.41.0 disponible (installed v5.40.0) — HITL gate (Phase B.3)
   Preview (top 5 commits):
     abc123 feat(atlas-core): add foo skill
     def456 fix(hooks): bar
     789fed feat(atlas-dev): baz agent
     ...
   To apply: run `/atlas update` OR `ATLAS_AUTO_UPDATE_CONFIRMED=1 claude`
   To silence: `export ATLAS_NO_AUTO_UPDATE=1` in ~/.zshrc
```

The user:
- **Reviews** the preview (git log HEAD..origin/main)
- **Decides** : apply now, defer, or opt-out permanently
- **Confirms** via the stated env var or slash command

## Alternatives considered

| Option | Verdict | Why rejected |
|---|---|---|
| **Keep silent auto-update** (status quo) | ❌ | Supply-chain attack vector remains — not compatible with G Mining pilot mai 2026 |
| **Disable auto-update entirely** | ❌ | Regresses ops UX; users will be on stale versions; security fixes don't reach them |
| **Show diff in `less` pager** | ⚠️ | UX improvement but still blocking → bad for short sessions; also kills headless CI |
| **Prompt with y/n** | ❌ | Hooks cannot read TTY reliably (no guaranteed stdin in SessionStart hook context) |
| **Slash command `/atlas update`** | ✅ | Discoverable, reversible, typed explicit intent |
| **Env var `ATLAS_AUTO_UPDATE_CONFIRMED=1`** | ✅ | Power-user override; survives shell session; CI-friendly |
| **Sigstore/cosign signature verification** | ⚠️ | Longer-term goal (Phase C.5); complementary, not alternative |

## Consequences

### Positive
- **Supply-chain attack mitigation** : attacker must either (a) know the user's
  mental model to trick them into typing `/atlas update` when they shouldn't,
  or (b) compromise Authentik + CF Access to push + auto-run — much harder.
- **Preview = informed consent** : user sees what changed before accepting.
- **Opt-out respected** : `ATLAS_NO_AUTO_UPDATE=1` still silences entirely
  (existing behavior).
- **CI-compatible** : `CI=1` bypass preserves Woodpecker auto-release flow.
- **Zero UX regression for explicit opt-in users** : `export
  ATLAS_AUTO_UPDATE_CONFIRMED=1` in `~/.zshrc` = same as current default.

### Negative
- **Friction for average user** : SessionStart shows a nag until they
  either confirm or opt out. Mitigation: clear message with both paths.
- **Drift risk** : users who ignore the prompt end up on stale versions,
  missing security patches. Mitigation: message highlights what's new +
  links to CHANGELOG.
- **Added env var surface** : `ATLAS_AUTO_UPDATE_CONFIRMED` is a new
  magic variable users must know. Mitigation: message always includes
  the exact command to set it.

## Implementation

Commit `5b5e647` on `feature/phase-b-zero-trust` (atlas-plugin repo)
adds a 34-line block between the clean-state guard (L121) and the pull+build
block (L122 old, L156 new). Diff summary:

```bash
# BEFORE L122 (silent pull+build):
_atlas_au_log "start: upgrading inst=$inst_version → mp=$mp_version"
if ! (
    cd "$source_repo" || exit 1
    git fetch origin main --quiet 2>&1
    git pull --ff-only origin main --quiet 2>&1
    make dev 2>&1
) >"$build_log" 2>&1; then

# AFTER (gate then pull+build):
if [ "${ATLAS_AUTO_UPDATE_CONFIRMED:-}" != "1" ] \
   && [ -z "${CI:-}" ] \
   && [ "$force" != "1" ]; then
  git -C "$source_repo" fetch origin main --quiet 2>/dev/null || true
  local preview
  preview=$(git -C "$source_repo" log --oneline HEAD..origin/main | head -5)
  _atlas_au_log "hitl-gate: confirmation required..."
  printf '🆙 ATLAS v%s disponible...\n' ...
  return 0
fi
_atlas_au_log "start: upgrading ..."
if ! (
    ...  # same as before
) >"$build_log" 2>&1; then
```

Ships with:
- bash -n passes
- Manual simulation with `atlas_auto_update_plugins` call verified gate fires
- Existing tests in `tests/bats/` unaffected (no test coverage for this
  function yet — Phase C.5 scope)

### Docs updates

- `docs/SECURITY.md` : add Phase B.3 HITL gate as mitigation for supply-chain.
- `ONBOARDING-EXTERNAL.md` : document `ATLAS_AUTO_UPDATE_CONFIRMED` for
  new users who want to preserve the old UX.
- `CHANGELOG.md` : BREAKING-POTENTIAL: users who rely on silent auto-update
  must explicitly opt in via env var.

## Rollback plan

Revert commit `5b5e647`. The change is additive (34-line block inserted),
revert is non-conflicting. Post-revert: users get silent auto-update again
(Phase A hardening still in place — attacker must breach Phase A first).

## Cross-references

- Plan: `projects/atlas/synapse/.blueprint/plans/aujourdhui-su-rmon-ordinateur-clever-blum.md`
- Implementation commit: `5b5e647` on `feature/phase-b-zero-trust`
- Companion ADR-020: CF Access Service Tokens (trust layer)
- Companion ADR-021: Device flow bootstrap (credential acquisition)
- Lesson: `lesson_statusline_deployment_pipeline.md` (analogue: audit deploy
  pipeline, not just code)
