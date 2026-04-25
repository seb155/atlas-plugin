# SP-STATUSLINE-SOTA-V3 — Self-Healing & Honest Status Line

**Plan ID**: `sp-statusline-sota-v3`
**Effort**: 5-7 days (5 sprints, sequential or parallelizable)
**Branch**: `feature/statusline-sota-v3`
**Status**: DRAFT — awaiting review (HITL gate before Sprint A)
**Author**: Seb Gagnon (with Claude Opus 4.7)
**Date**: 2026-04-25
**Supersedes-in-part**: ADR-019 (StatusLine SOTA v2)
**Related**: ADR-006 (version resolver), ADR-022 (auto-update HITL)

---

## 1. Context — why we are revisiting the status line again

Between 2026-04-07 (v4.44.0) and 2026-04-19 (v5.30.1), the ATLAS plugin
shipped **three** "fixes" for the status line, all of which regressed in
production. ADR-019 (2026-04-19) introduced a thin wrapper deployed to
`~/.local/share/atlas-statusline/` (territory dotfiles do not touch) and was
believed to close the issue.

**On 2026-04-25, the issue resurfaced**. A live diagnostic run on host
`PC-S16` (sole user installation) produced these symptoms:

```
$ cat ~/.atlas/runtime/capabilities.json | jq -r .version
?

$ echo '{...mock...}' | ~/.local/share/atlas-statusline/statusline-wrapper.sh
🏛️ ATLAS ?  /tmp 🤖16▶ 42% ◐ opus
```

Forensic analysis identified **five compounding root causes**, of which
only one (#1, the original ADR-019 case) is mitigated by the v2 design.
The remaining four are independent failure modes the v2 wrapper does
not protect against.

### Root causes (forensic, 2026-04-25)

| # | Root cause | Status v2 | Surface |
|---|---|---|---|
| 1 | `~/.claude/settings.json` overwriten by external actor (suspected: `~/.claude-dotfiles/sync.sh`) — both `statusLine.command` AND `enabledPlugins` (`atlas-*` entries removed). | **Partially mitigated** (wrapper survives, settings does not) | `settings.json` |
| 2 | `yq` installed via `snap` (`/snap/bin/yq`) is AppArmor-confined and cannot read `~/.claude/**` → silent permission denied → empty result | **Not addressed** | `atlas-discover-addons.sh:29-32` |
| 3 | `yaml_get()` fallback bug: when `yq` returns empty, the function returns `default` instead of falling through to the `grep` fallback | **Not addressed** | `atlas-discover-addons.sh:26-40` |
| 4 | `TIER_MAX_VERSION` initialized empty; `priority(0) > TIER_MAX_PRIORITY(0)` is false ∀ addons (cause: #2/#3 cascade) → `capabilities.json .version = "?"` | **Not addressed** | `atlas-discover-addons.sh:95-194` |
| 5 | Skill `statusline-setup` SKILL.md hardcodes `$PLUGIN/atlas-admin/<ver>/scripts/cship-atlas.toml` — the path does not exist (atlas-admin has no `scripts/`; canonical home is atlas-core) | **Not addressed** | `skills/statusline-setup/SKILL.md` |
| 6 | `statusline-command.sh` reads `.effort` but the official CC JSON schema field is `.effort.level` (object, not string) — falls back to "auto" even when user set effort | **Not addressed** | `statusline-command.sh:14` |
| 7 | `statusline-command.sh` reads `.rate_limits["5h"]` but the official field is `.rate_limits.five_hour` (snake_case) — rate limit row is **always empty** | **Not addressed** | `statusline-command.sh:13` |
| 8 | Plugin modules read `.context_window.size` but the official field is `.context_window.context_window_size` — display likely truncated | **Not addressed** | `scripts/atlas-context-size-module.sh` |
| 9 | Plugin modules read `.context_window.exceeds_200k` but the official field is `.exceeds_200k_tokens` (top-level) — 200K badge never lights up | **Not addressed** | `scripts/atlas-200k-badge-module.sh` |

**Cascade**: (#2 → #3) → (#4) → status line displays `?`. Independently,
(#1) periodically wipes the user's settings. (#5) means a fresh host
cannot bootstrap via the documented skill path.

### Unexamined assumption from ADR-019

> "The wrapper layer in `~/.local/share/atlas-statusline/` is dotfile-immune,
> therefore the status line cannot regress from external sync."

**True for the wrapper.** **False for `settings.json`** which still lives
in `~/.claude/` and is in dotfile sync territory. The 2026-04-25 incident
proved the boundary needs to extend to settings.

---

## 2. Goals & non-goals

### Goals

- **G1.** Status line **never displays `?`** as the version under any reasonably reachable failure mode (snap-yq, dotfile overwrite, partial install, fresh machine).
- **G2.** Status line is **self-healing** — a damaged install repairs at the next session-start without user intervention.
- **G3.** **Single command** to install/repair/audit on a fresh machine: `bash $PLUGIN/scripts/statusline/install.sh`.
- **G4.** **Single observability surface**: `atlas doctor --statusline` returns a 8-level audit with diff vs source.
- **G5.** Settings.json territory boundary documented (ADR-023) so future contributors do not regress on (#1).

### Non-goals

- **NG1.** Replace cship/starship as the renderer engine (they work; the bugs are in our wrapper layer and version resolution, not in the renderers).
- **NG2.** Cross-platform installer parity (Windows/macOS) — current target is Linux/PC-S16 only. Windows/macOS instructions remain as documentation in the skill, not as automated installer paths in this sprint.
- **NG3.** Refactor `atlas-discover-addons.sh` from bash to TypeScript. Bash is the ground truth for shell-context scripts; TS hooks are the orchestration layer.

---

## 3. Design principles (5)

```
P1. Single source of truth     — scripts/statusline/ holds every artifact
P2. Single deploy mechanism    — bin/atlas-statusline-install (idempotent)
P3. Self-healing               — session-start hook validates + repairs
P4. Settings sovereignty       — settings.local.json (dotfile-immune)
P5. Honest fallbacks           — never "?", always diagnostic or fallback chain
```

Each principle maps directly to mitigation of one or more root causes:

| Principle | Mitigates |
|-----------|-----------|
| P1 | #5 (skill path drift) |
| P2 | #5 + drift between dist/local |
| P3 | #1 (settings overwrite recovery), #4 (capabilities staleness) |
| P4 | #1 (settings overwrite immunity) |
| P5 | #2, #3, #4 (snap-yq cascade) |

---

## 4. Architecture (target)

### Filesystem layout

```
PLUGIN SOURCE                              PLUGIN DIST                          USER MACHINE
projects/atlas-plugin/                     ~/.claude/plugins/cache/             ~/.local/share/atlas-statusline/
└── scripts/                               atlas-marketplace/atlas-core/<ver>/    ├── wrapper.sh           (md5-tracked)
    └── statusline/                  ▶─▶   └── scripts/                          ├── modules/             (atlas-*-module.sh)
        ├── install.sh        (NEW)              └── statusline/    ◀──┐         └── .install-manifest    (md5 + version stamp)
        ├── doctor.sh         (NEW)                 └── (mirror)        │
        ├── command.sh        (rename)                                   │       ~/.config/
        ├── wrapper.sh        (existing)                                 │         ├── cship.toml          (atlas blocks)
        ├── cship.toml        (existing)                                 │         └── starship.toml       (atlas fragment merged)
        ├── starship-fragment.toml (existing)                            │
        └── modules/                                                     │       ~/.claude/
            ├── atlas-200k-badge.sh                                       │         ├── settings.json        (untouched by us)
            ├── atlas-agents.sh                                           │         └── settings.local.json   ◀── statusLine.command
            ├── atlas-alert.sh                                            │              (dotfile-immune; OUR territory)
            ├── atlas-context-size.sh                                     │
            ├── atlas-cost-usd.sh                                         │       ~/.atlas/runtime/
            ├── atlas-effort.sh                                           │         ├── capabilities.json    (.version honest, never "?")
            ├── atlas-resolve-version.sh                                  │         └── .statusline-heal.log (auto-heal events)
            └── atlas-discover-addons.sh ◀────────── plugin's scripts/atlas-discover-addons.sh
                                                     also still here for backward compat;
                                                     statusline/ is the new canonical home.
```

### Self-healing flow (session-start)

```
session-start
   │
   ▼
hooks/ts/statusline-heal.ts
   │
   ├─ 1. Read settings.local.json — does statusLine.command exist + is path executable?
   │       NO  → restore from template, log to .statusline-heal.log
   │
   ├─ 2. Read ~/.local/share/atlas-statusline/.install-manifest
   │       md5 mismatch with plugin dist → mark for redeploy
   │       missing manifest             → mark for redeploy
   │
   ├─ 3. Read ~/.atlas/runtime/capabilities.json
   │       .version == "?"  → re-run atlas-discover-addons.sh (background)
   │
   ├─ 4. If marked for redeploy → exec scripts/statusline/install.sh --auto
   │
   └─ 5. Emit single-line status to .statusline-heal.log
            "2026-04-25T14:30:00Z  status=ok  version=6.0.0-alpha.11  drift=none"
```

### Render fallback chain (in `command.sh`)

```
1. capabilities.json .version (if not "?")
2. capabilities.json addons[max(priority)].version  ← NEW: honest fallback
3. claude plugin list --json | atlas-core .version  (if CLI present)
4. filesystem scan ~/.claude/plugins/cache/atlas-marketplace/atlas-core/  (sort -V | tail -1)
5. plugin's own VERSION file (read from $0 dirname → ../VERSION)
6. literal string "?-unresolvable"  ← only if EVERYTHING above failed
```

Rule: the status line **never** emits a bare `?` token. If we cannot resolve, we emit `?-unresolvable` so the user can see we are reporting a real failure mode and can run `atlas doctor --statusline` for diagnostics.

---

## 5. Deliverables (8)

| ID | Deliverable | File | LOC | Owner |
|----|-------------|------|-----|-------|
| L1 | Fix `yaml_get` to fall through to grep when yq returns empty + strip inline comments | `scripts/atlas-discover-addons.sh` | ±10 | Sprint A |
| L2 | Fix `TIER_MAX_VERSION` init: read VERSION file as honest default | `scripts/atlas-discover-addons.sh` | ±3 | Sprint A |
| L3 | Fix `statusline-command.sh` (renamed `command.sh`): if `.version == "?"` use highest-priority addon version | `scripts/statusline/command.sh` | ±5 | Sprint A |
| **L9** | **Fix `effort` field: read `.effort.level` (not `.effort`) per official CC JSON schema** | `scripts/statusline/command.sh` | ±2 | **Sprint A** |
| **L10** | **Fix `rate_limits` field: read `.rate_limits.five_hour.used_percentage` (not `.rate_limits["5h"]`)** | `scripts/statusline/command.sh` + modules | ±5 | **Sprint A** |
| **L11** | **Fix `context_window.size` → `.context_window.context_window_size` per official schema** | `scripts/atlas-context-size-module.sh` | ±2 | **Sprint A** |
| **L12** | **Fix `exceeds_200k` → `.exceeds_200k_tokens` (top-level, per official schema)** | `scripts/atlas-200k-badge-module.sh` | ±2 | **Sprint A** |
| L4 | New idempotent installer with HITL gate, dependency check, settings.local.json migration | `scripts/statusline/install.sh` | ±150 | Sprint B |
| L5 | New 8-level audit + mock-render assertion | `scripts/statusline/doctor.sh` | ±200 | Sprint C |
| L6 | Auto-heal session-start hook | `hooks/ts/statusline-heal.ts` | ±80 | Sprint D |
| L7 | Skill `statusline-setup` rewritten to delegate to install.sh (~50 lines instead of 250) | `skills/statusline-setup/SKILL.md` | rewrite | Sprint E |
| L8 | ADR-023 (settings.json territory) + bats E2E test asserting no `?` in render | `docs/ADR/`, `tests/statusline.bats` | ±30 + doc | Sprint E |

**Sprint A scope updated**: now contains 7 fixes (L1–L3 + L9–L12). All are <5 LOC each, total ~30 LOC — still single-day effort but addresses **all** silent JSON-schema bugs in addition to the version resolution cascade.

### L1 detailed diff (preview)

```diff
--- a/scripts/atlas-discover-addons.sh
+++ b/scripts/atlas-discover-addons.sh
@@ -26,16 +26,21 @@ yaml_get() {
   local file="$1" key="$2" default="${3:-}"
   if [ ! -f "$file" ]; then echo "$default"; return; fi
+  local v=""
   if command -v yq >/dev/null 2>&1; then
-    local v
     v=$(yq -r ".${key} // \"\"" "$file" 2>/dev/null || echo "")
-    [ -n "$v" ] && [ "$v" != "null" ] && echo "$v" || echo "$default"
-  else
-    # Fallback: simple grep (only top-level scalar keys)
-    local v
-    v=$(grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:[[:space:]]*//; s/[\"']//g")
-    echo "${v:-$default}"
+    [ "$v" = "null" ] && v=""
+  fi
+  # Fallback: grep (yq absent, AppArmor-blocked, or returned empty)
+  # Strips inline comments (# ...) — fixes "tier_priority: 3   # 1=core" parse.
+  if [ -z "$v" ]; then
+    v=$(grep "^[[:space:]]*${key}:" "$file" 2>/dev/null | head -1 \
+        | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//
+                  s/[[:space:]]*#.*$//
+                  s/^[\"']//; s/[\"']$//")
   fi
+  echo "${v:-$default}"
 }
```

### L4 installer skeleton

```bash
#!/usr/bin/env bash
# scripts/statusline/install.sh — idempotent ATLAS status line installer
# Usage:
#   bash install.sh                    # interactive (HITL gate before each phase)
#   bash install.sh --auto             # non-interactive (used by session-start auto-heal)
#   bash install.sh --doctor-after     # run doctor.sh after install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_LOCAL="$HOME/.local/share/atlas-statusline"
DEST_CONFIG="$HOME/.config"
DEST_SETTINGS="$HOME/.claude/settings.local.json"

# Phase 1: dependency check ─────────────────────────────────────────
require() { command -v "$1" >/dev/null || { echo "missing: $1"; return 1; }; }
require cship       || install_cship_or_fail
require jq          || install_jq_or_fail
require_yq_safe                # rejects snap-yq, suggests apt/binary

# Phase 2: deploy artifacts ─────────────────────────────────────────
mkdir -p "$DEST_LOCAL/modules"
sync_artifact "$SCRIPT_DIR/wrapper.sh"      "$DEST_LOCAL/wrapper.sh"
for m in "$SCRIPT_DIR"/modules/*.sh; do
  sync_artifact "$m" "$DEST_LOCAL/modules/$(basename "$m")"
done

# Phase 3: cship/starship config ────────────────────────────────────
sync_artifact "$SCRIPT_DIR/cship.toml" "$DEST_CONFIG/cship.toml"
merge_starship_fragment "$SCRIPT_DIR/starship-fragment.toml" "$DEST_CONFIG/starship.toml"

# Phase 4: settings.local.json ─────────────────────────────────────
update_settings_local "$DEST_SETTINGS"     # idempotent jq merge

# Phase 5: write manifest (md5 stamps for self-heal) ──────────────
write_install_manifest "$DEST_LOCAL/.install-manifest"

# Phase 6: discover + render test ─────────────────────────────────
"$SCRIPT_DIR/../atlas-discover-addons.sh"  # writes capabilities.json
verify_render_no_question_mark             # FAIL if render contains "?"
```

---

## 6. ASCII mockup — `atlas doctor --statusline` output

```
🏛️ ATLAS Status Line Diagnostic
─────────────────────────────────

  ✓ 1. Tools                cship 0.4.2 │ jq 1.8.1 │ starship 1.24.1 │ yq 4.49.2 (/home/sgagnon/.local/bin/yq)
  ✓ 2. Settings             ~/.claude/settings.local.json statusLine.command = ~/.local/share/atlas-statusline/wrapper.sh
  ✓ 3. Wrapper deploy       md5 matches plugin atlas-core/6.0.0-alpha.11 source
  ✓ 4. capabilities.json    .version = 6.0.0-alpha.11  (computed 2m ago, source=cli, fresh)
  ✓ 5. cship.toml           ATLAS blocks present (custom.atlas_version, atlas_alert, atlas_agents)
  ✓ 6. starship.toml        ATLAS fragment merged (4 [custom.atlas*] sections)
  ✓ 7. Mock render          🏛️ ATLAS 6.0.0-alpha.11  👑admin  🟣 Opus  ...  (no "?", no "unknown")
  ✓ 8. Drift check          0 of 9 deployed scripts diverge from plugin source

  Overall: HEALTHY ✅
```

Failure mode example:

```
  ✗ 4. capabilities.json    .version = "?"  ← UNHEALTHY
        Cause: yaml_get returned empty for tier/tier_priority on atlas-admin manifest
        Likely: yq is snap-confined (AppArmor blocks ~/.claude/*)
        Fix:    sudo snap remove yq && curl -L https://github.com/mikefarah/yq/releases/download/v4.49.2/yq_linux_amd64 -o ~/.local/bin/yq

  Overall: DEGRADED ⚠️  — status line will fall back to addons[max_priority].version (still honest)
```

---

## 7. Test strategy

### Unit (bats — `tests/statusline.bats`)

| Test | Asserts |
|------|---------|
| `yaml_get_yq_returns_empty_falls_through_to_grep` | yaml_get returns parsed value when yq emits empty (snap-yq simulation via stub PATH) |
| `yaml_get_strips_inline_comment` | `tier_priority: 3   # comment` → returns `3`, not `3   # comment` |
| `tier_max_version_init_from_version_file` | Empty discover state still produces non-empty `TIER_MAX_VERSION` |
| `command_sh_falls_back_to_max_priority_addon` | When `.version == "?"`, render reads addons[max(priority)].version |

### Integration (bats — `tests/statusline-install.bats`)

| Test | Asserts |
|------|---------|
| `install_idempotent` | Run install.sh twice → second run is no-op (manifest md5 stable) |
| `install_creates_settings_local` | settings.local.json statusLine.command set correctly |
| `install_does_not_touch_settings_json` | `~/.claude/settings.json` byte-identical before/after |
| `doctor_reports_healthy_after_install` | `doctor.sh` exit 0 + 8/8 ✓ |

### E2E (`tests/statusline-e2e.sh`)

| Scenario | Assertion |
|----------|-----------|
| Mock CC JSON → wrapper render | Output regex matches `🏛️ ATLAS [0-9]+\.[0-9]+\.[0-9]+(-alpha\.[0-9]+)?` |
| Mock with empty capabilities.json | Output does NOT contain bare `?` token |
| Mock with snap-yq simulation | Discover still resolves tier from grep fallback |
| Mock settings.json overwrite | Next session-start logs heal event + restores statusLine.command |

CI gate (`.woodpecker/test.yml`): all bats files + e2e must pass before merge.

---

## 8. Migration & rollout

### Phase 0 — Pre-flight (local PC-S16 only, manual)

```bash
# Snapshot current state (so we can compare after)
cp ~/.claude/settings.json /tmp/settings.json.snapshot
cp ~/.atlas/runtime/capabilities.json /tmp/capabilities.json.snapshot

# Identify and disable the dotfile sync that overwrites settings.json
# (root cause #1 — outside this plan's scope but blocking)
ls -la ~/.claude-dotfiles/ 2>/dev/null
crontab -l 2>/dev/null | grep -i sync
```

### Sprint sequencing

```
A. Bug fixes        ─┐
                     ├─ MERGE → cut v6.1.x patch release  (single host, instant relief)
B. Installer + L4 ──┘                  │
                                       ▼
C. Doctor (L5)        ──┬──── separate  PR: requires installer's manifest format
D. Self-heal (L6)     ──┘    PR each
                              │
                              ▼
E. Skill rewrite + ADR + tests ──── final PR (cleanup + documentation)
```

Each sprint is a separate PR. Sprint A can ship in 24h; B-E follow at their own pace. The branch `feature/statusline-sota-v3` accumulates all sprints; sprints A-E are squash-merged from sub-branches or rebased commits.

### Backward compatibility

- `scripts/statusline-command.sh` (old path) **stays as a symlink** to `scripts/statusline/command.sh` for one minor version (v6.2.0) so user installs that hardcoded the old path do not break.
- The wrapper at `~/.local/share/atlas-statusline/statusline-wrapper.sh` is renamed to `wrapper.sh` only on next install run; old installs continue to function until install.sh is re-executed.

---

## 9. Risks & mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|------------|--------|------------|
| R1 | `settings.local.json` is also synced by some dotfile tool we don't know about | Med | High | Phase 0 audit identifies the tool; if found, document it in ADR-023 and add the file to its ignore list |
| R2 | Auto-heal hook adds latency to session-start (>500ms) | Low | Med | All checks are cheap (md5, jq read, file stat); budget 50ms p95; abort hook if exceeds 200ms |
| R3 | A future plugin update changes manifest format → grep fallback breaks | Low | Med | bats test pinned to current manifest format; CI fails if manifest schema changes without updating yaml_get |
| R4 | Snap-yq is the only available yq on some hosts → users cannot install non-snap yq | Low | Low | Doctor diagnoses + suggests; install.sh can fall back to apt/binary path; users without root can use `~/.local/bin/yq` from GitHub release |
| R5 | Plan grows beyond 1 week effort | Med | Low | Sprints are independently shippable; we can stop after Sprint A and re-evaluate |
| R6 | Cross-host (when fleet expands) — these fixes assume Linux | Med | Med | Non-goal NG2; track in follow-up plan SP-STATUSLINE-CROSS-PLATFORM |

---

## 10. Decision log (living)

| Decision | Rationale | Date |
|----------|-----------|------|
| Use `settings.local.json` not new file | CC natively supports it; no new convention needed | 2026-04-25 |
| Bash, not TypeScript, for installer | Bash is the renderer language; install/render must run in same process model | 2026-04-25 |
| Keep cship + starship dual-track | Both work; users have configured both; switching engines is NG1 | 2026-04-25 |
| Honest fallback string `?-unresolvable` not `?` | Users can grep for the suffix to know we tried; bare `?` is ambiguous | 2026-04-25 |
| Sprint A ships standalone (patch release v6.1.x) | Bug fixes alone produce immediate relief; do not block on B-E | 2026-04-25 |
| Plugin `settings.json` does **not** ship `statusLine` | CC plugin reference (2026) confirms: only `agent` and `subagentStatusLine` keys are accepted in plugin settings.json. `statusLine` must live in user's `~/.claude/settings.json` (or `.local.json`) | 2026-04-25 |
| Wrapper stays in `~/.local/share/atlas-statusline/`, not `${CLAUDE_PLUGIN_DATA}` | `${CLAUDE_PLUGIN_DATA}` survives plugin updates BUT lives under `~/.claude/plugins/` which is dotfile-sync territory. `~/.local/share/` stays immune. | 2026-04-25 |
| `subagentStatusLine` ship-via-plugin opportunity = **future work**, not in this plan | CC supports it natively, but it is independent of the bug-fix scope. Track in SP-STATUSLINE-SUBAGENT for v6.2+. | 2026-04-25 |

---

## 11. ADR-023 outline (Sprint E deliverable)

```
# ADR-023: Settings.json territory boundaries

Status: Proposed
Date: 2026-04-XX (Sprint E)
Supersedes-in-part: ADR-019

## Context
ADR-019 protected scripts. Settings.json itself remained vulnerable.
2026-04-25 incident: dotfile sync wiped both statusLine.command and
enabledPlugins ATLAS entries.

## Decision
- ATLAS deploys to settings.local.json, not settings.json.
- settings.local.json is "OUR" territory; documented as such.
- ADR-019 wrapper deploy pattern remains for scripts.
- Auto-heal hook validates territorial integrity at session-start.

## Consequences
- Users with custom statusLine in settings.json must migrate (one-time HITL).
- ATLAS installer ships an idempotent migrator (settings.json → settings.local.json
  for ATLAS-related keys only).
- New convention documented in CLAUDE.md (project-level).
```

---

## 12. Acceptance criteria

Sprint A acceptance:
- [ ] `bash scripts/atlas-discover-addons.sh && jq -r .version ~/.atlas/runtime/capabilities.json` returns `6.0.0-alpha.11` (not `?`)
- [ ] Mock JSON piped to `bash scripts/statusline/command.sh` produces output with no `?` and version is real
- [ ] All 4 unit bats tests green

Sprint B acceptance:
- [ ] `bash scripts/statusline/install.sh` on a fresh `~/.local/share/atlas-statusline/` produces a working install (verified by doctor)
- [ ] Re-running install.sh is a no-op (idempotent)
- [ ] `~/.claude/settings.json` byte-identical before/after install
- [ ] `~/.claude/settings.local.json statusLine.command` set correctly

Sprint C acceptance:
- [ ] `atlas doctor --statusline` returns 8/8 ✓ on a healthy install
- [ ] `atlas doctor --statusline` correctly diagnoses each of the 5 root cause scenarios (test fixtures)

Sprint D acceptance:
- [ ] After manually corrupting settings.local.json, next session-start restores statusLine.command and logs to `.statusline-heal.log`
- [ ] Auto-heal hook completes in <200ms p95 on PC-S16

Sprint E acceptance:
- [ ] Skill SKILL.md is <80 lines and references only install.sh
- [ ] ADR-023 merged
- [ ] CI green (all bats + e2e)

---

## 13. Open questions (need user decision before Sprint A)

1. **Dotfile sync identity** — what process overwrites settings.json? Phase 0 must identify before we can claim immunity for settings.local.json. _(see issue #100 if filed)_
2. **Single-host vs fleet** — current scope is PC-S16 only. Should we plan for multi-host now, or defer to follow-up? (NG2 says defer.)
3. **Patch release cadence** — Sprint A as `v6.1.0-alpha.2` patch on the alpha track, or wait for `v6.1.0` GA?
4. **`atlas doctor` integration** — doctor.sh is standalone, but should `atlas doctor --statusline` be a subcommand of the existing `atlas doctor` skill, or a separate entry point?

---

## 14. Out-of-scope (explicit)

- Cross-platform (Windows/macOS) installer — see NG2.
- Refactor of cship/starship config schema — see NG1.
- Replacing dotfile sync — that's the user's separate tooling concern. We make ourselves immune; we do not fix the sync.
- New status line content (additional badges, layouts) — separate plan SP-STATUSLINE-CONTENT-V2 if needed later.

---

## 15. References

### Internal (atlas-plugin)
- ADR-006: Version resolver canonicalization (2026-04-19)
- ADR-019: StatusLine SOTA v2 unification (2026-04-19)
- ADR-019b: ATLAS skill lint fork
- ADR-022: HITL gate auto-update hook (2026-04-XX)
- Forensic session: 2026-04-25 (PC-S16) — capabilities.json reproduces `.version = "?"`

### Official Claude Code documentation (2026)
- [statusLine reference](https://code.claude.com/docs/en/statusline) — JSON schema, refreshInterval, padding, 300ms debounce
- [hooks-guide](https://code.claude.com/docs/en/hooks-guide) — SessionStart matchers (`startup|resume|clear|compact`), `CwdChanged`, exit codes
- [plugins-reference](https://code.claude.com/docs/en/plugins-reference) — plugin layout, `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PLUGIN_DATA}`, plugin `settings.json` accepts only `agent` + `subagentStatusLine`
- [plugin-marketplaces](https://code.claude.com/docs/en/plugin-marketplaces) — marketplace.json schema
- GitHub anthropic/claude-code#18174 — `/reload-plugins` does NOT re-trigger SessionStart (closed "not planned")

### External
- Snap AppArmor confinement: <https://snapcraft.io/docs/system-snap-and-confinement>
- [ccstatusline](https://github.com/sirmalloc/ccstatusline) — community-built statusline (reference for layout patterns)
- [starship-claude](https://github.com/martinemde/starship-claude) — reference Starship config

---

**HITL gate before Sprint A**: this plan must be reviewed and approved
(answer Section 13 questions, lock acceptance criteria) before any code
lands on `feature/statusline-sota-v3`.

**Next action after approval**: implement L1+L2+L3 in a single commit on
this branch, run bats, push to forgejo, open PR.
