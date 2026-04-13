# ATLAS v5 — Quickstart Guide

> **For users** (not developers). 5-minute read. If you developed v4 of the plugin, see "What changed v4→v5" below.

ATLAS v5 is your **AI engineering co-pilot** inside Claude Code. Install once, get auto-routing across 25–88 skills depending on your role.

---

## TL;DR — 3 ways to use ATLAS

### 1. Auto (zero action) — **Recommended**
Just open Claude Code. ATLAS auto-loads via the SessionStart hook and shows a banner:
```
🏛️ ATLAS │ ✅ SESSION │ v5.1.0 Admin
   88 skills │ 16 agents │ Gate 12/15
   Auto-routing active — just tell me what you need.
```
Then write naturally — ATLAS routes to the right skill.

### 2. Slash command `/atlas`
Force-activate the master (or re-detect installed addons after `/plugin install`):
```
/atlas
```

### 3. Pattern triggers (intent-based)
Type natural language — auto-orchestrator (admin tier) finds the best skill:
- "auto" / "what should I use" / "quel skill" → recommends top 3
- "ship it" → invokes finishing-branch + ship-all chain
- "review code" → invokes code-review skill

---

## Install per role

ATLAS v5 is **3 plugins**. Pick what matches your role:

| Role | Install | Total | Use cases |
|------|---------|-------|-----------|
| **End User** | `atlas-core` | 25 skills, 1 agent | Memory, research, personal productivity |
| **Developer** | `atlas-core` + `atlas-dev` | 54 skills, 8 agents | Above + planning, TDD, code review, shipping |
| **Admin / Solo founder** | `atlas-core` + `atlas-admin` | 88 skills, 16 agents | All Dev + infra, security, governance, GMS |
| **Maximalist** | All three | 88 skills, 16 agents | Same as admin (admin ⊃ dev superset) |

Install via `/plugin`:
```
/plugin install atlas-core      # MANDATORY (base)
/plugin install atlas-admin     # Optional (or atlas-dev)
```

After install, **restart Claude Code** to trigger SessionStart hook + capability discovery.

---

## What changed v4 → v5

| Aspect | v4 (monolithic) | v5 (core + addons) |
|--------|-----------------|---------------------|
| Plugins | 1 (atlas-admin shipped everything) | 3 (atlas-core + atlas-dev + atlas-admin) |
| atlas-assist files | 1 (in atlas-admin) | 1 (unified, in atlas-core) — adapts to installed addons |
| Token cost per session | ~177K (heavy) | ~90K (49% lighter) |
| Duplication | 62% | 0% |
| Status bar version | Manual | Auto-detected (`atlas-resolve-version.sh` queries marketplace) |
| Slash `/atlas` | Existed | Restored in v5.1 (was lost in v5.0 refactor) |

### Migration checklist
- [ ] Uninstall old monolithic `atlas-admin` v4 (CC handles via `/plugin`)
- [ ] Install `atlas-core` + your role's addon
- [ ] Restart Claude Code (SessionStart hook re-detects)
- [ ] Verify status bar shows `v5.1.0` (not `v4.x` — see Troubleshooting)

---

## Capability Discovery (under the hood)

When you start a session, the SessionStart hook runs:
```
~/.claude/plugins/cache/atlas-marketplace/atlas-core/<v>/scripts/atlas-discover-addons.sh
```

This scanner:
1. Finds all installed `atlas-*` plugins in the marketplace cache
2. Reads each addon's `_addon-manifest.yaml` (tier, persona, pipeline)
3. Computes the **highest tier** installed (priority: core=1, dev=2, admin=3)
4. Writes `~/.atlas/runtime/capabilities.json`

The unified master `atlas-assist` reads this JSON and adapts:
- Persona (helpful assistant / engineering architect / infra architect)
- Pipeline phases shown in breadcrumbs
- List of available skills (only those whose addon is installed)

**To inspect** what was detected: invoke the `discovery` skill ("rescan addons" or "what addons do I have").

---

## Troubleshooting

### Status bar shows wrong version (e.g. v4.43.1 when you have v5.x)

```bash
# Force refresh
~/.local/share/atlas-statusline/atlas-resolve-version.sh
# Should output your installed version (e.g. 5.1.0)

# If still wrong, re-deploy:
cp ~/.claude/plugins/cache/atlas-marketplace/atlas-core/<v>/scripts/atlas-resolve-version.sh \
   ~/.local/share/atlas-statusline/
```

### Master atlas-assist not loading (no banner shown)

```bash
# Check capability discovery output
cat ~/.atlas/runtime/capabilities.json | jq .

# Check skill exists in cache
ls ~/.claude/plugins/cache/atlas-marketplace/atlas-core/*/skills/atlas-assist/

# Force re-detection
~/.claude/plugins/cache/atlas-marketplace/atlas-core/<v>/scripts/atlas-discover-addons.sh
```

### Wrong tier detected (you installed admin but master uses dev persona)

Check `tier_priority` in your manifests:
```bash
for d in ~/.claude/plugins/cache/atlas-marketplace/atlas-*/; do
  echo "=== $d ==="
  cat "$d"*/  _addon-manifest.yaml | grep tier
done
```

Should be: core=1, dev=2, admin=3.

### `/atlas` command not recognized

The slash command lives in `atlas-core` (always installed). Verify:
```bash
ls ~/.claude/plugins/cache/atlas-marketplace/atlas-core/*/commands/atlas.md
```

If missing, reinstall: `/plugin install atlas-core`.

---

## Power user tips

- **Multi-environment**: ATLAS works on Linux, macOS, Windows (Git Bash), WSL2.
- **Worktrees**: `claude -w feature-name` for isolated git worktree per feature.
- **Telemetry**: `~/.claude/atlas-audit.log` records role detection per session.
- **Personas**: Switch behavior with `atlas-admin-addon:persona-loadout` skill (6 roles).
- **Idle scheduler**: `atlas-admin-addon:idle-curiosity` schedules autonomous exploration.
- **Memory**: Files in `~/.claude/projects/<project-hash>/memory/` persist across sessions. ATLAS reads them automatically.

---

## See also

- `README.md` — Plugin overview
- `DEPLOYMENT.md` — Step-by-step install (Linux/macOS/Windows/WSL2)
- `ONBOARDING.md` — For new developers contributing to ATLAS
- `CHANGELOG.md` — Full release history (v4 → v5)
- `.blueprint/ARCHITECTURE.md` — Deep dive on build system + tier inheritance

---

*ATLAS v5.1+ | Updated: 2026-04-13 | Maintainer: Seb Gagnon @ AXOIQ*
