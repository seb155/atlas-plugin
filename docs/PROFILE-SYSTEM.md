# ATLAS Launch Profile System (v5.28.0+)

Profile-first architecture for configuring `atlas` launches. Bundle `tier + permission_mode + effort + MCPs + env + hooks` into a single YAML file. Auto-detect from `cwd`, `git branch`, `WiFi`, or `time`.

## Schema

Profile files live in `~/.atlas/profiles/<name>.yaml`. Schema documented in [`base.yaml`](../templates/profiles/base.yaml).

### Core Fields

```yaml
name: <string>                          # Profile identifier (filename must match)
description: <string>                   # Human description
extends: <profile-name>                 # Optional inheritance (max depth 3)

# Claude Code launch flags
tier: core|dev|admin|none               # Plugin tier (→ --plugin-dir)
permission_mode: default|plan|auto|dontAsk|acceptEdits|bypassPermissions
effort: low|medium|high|xhigh|max       # → --effort
worktree: true|false                    # → --worktree auto-name
fork_session: true|false|auto           # auto = detect feature/fix branch
bare: true|false                        # → --bare (skip hooks+plugins)

# MCP composition
mcp_profile: <mcp-profile-name>         # Refs ~/.atlas/mcp-profiles/<name>.yaml

# Env overrides (exported before claude launch)
env:
  KEY: value
```

### Auto-Detection Fields

```yaml
# cwd patterns that activate this profile (first match wins)
cwd_match:
  - "/path/pattern/**"

# WiFi trust requirement (requires atlas-location skill + nmcli)
wifi_trust_required: none|low|medium|high

# Per-branch overlays (applied AFTER main profile fields)
git_branch_hook:
  "feature/*": { fork_session: true }
  "main":      { permission_mode: plan }

# Time-based overlays (tokens: weekend, weekday, weekday-morning, etc.)
time_hook:
  "weekend": { effort: low }
```

## Inheritance

Profiles can `extend` another profile for DRY configuration:

```yaml
# base.yaml
name: base
tier: admin
effort: high
worktree: true

# dev-synapse.yaml
name: dev-synapse
extends: base               # inherits tier, effort, worktree
tier: dev                   # override
permission_mode: plan       # additional
mcp_profile: chrome-playwright
```

**Resolution order**: base fields loaded first, leaf fields override. Max depth 3 prevents cycles.

Check chain: `atlas profile validate <name>` shows errors if enum values invalid.

## Resolution Order (Full)

When `atlas` launches, fields resolve in priority (last wins):

1. **Config defaults** (`~/.atlas/config.json` → ATLAS_DEFAULT_*)
2. **Profile fields** (via `--profile <name>` OR auto-detect)
3. **Overlays** (WiFi → git branch → time)
4. **--override key=value** (composable user flags)
5. **Explicit CLI flags** (`-y`, `-a`, `-p`, `-e`, etc.)

Debug: `atlas --detect-only` prints the final resolved state + source profile.

## Auto-Detection

When `ATLAS_AUTO_DETECT_PROFILE=true` (recommended) AND no explicit `--profile`:

1. **`.atlas/project.json` manifest** — walk cwd up, find nearest:
   ```json
   { "profile": "dev-synapse" }
   ```
2. **cwd_match glob** — scan `~/.atlas/profiles/*.yaml` for matching pattern
3. **Fallback** — interactive prompt (if `gum`/`fzf` available) or default

## Overlays (Contextual Modifications)

Applied AFTER profile load, BEFORE user overrides. Modify `ATLAS_LP_*` env vars.

### WiFi Trust Overlay

If `wifi_trust_required` > current WiFi trust → downgrade `permission_mode=plan`.

WiFi trust lookup:
- Current BSSID via `nmcli` (fallback no-op if unavailable)
- Look up in `~/.atlas/wifi-locations.json` (atlas-location skill format)
- Rank: `none/public=0 < low=1 < known/medium=2 < trusted/high=3`

### Git Branch Overlay

Match current branch against `git_branch_hook` patterns. Apply hook fields (fork_session, permission_mode, effort, worktree).

Example: on `feature/*`, force `fork_session: true` (new session ID, no context contamination).

### Time Overlay

Match current day/hour to `time_hook` tokens. Supported:
- `weekend` (Saturday, Sunday)
- `weekday` (Monday-Friday)
- `weekday-morning` (Mon-Fri, hour < 12)
- `weekday-afternoon` (Mon-Fri, 12-17)
- `weekday-evening` (Mon-Fri, hour ≥ 18)

## Commands

### List / show

```bash
atlas profile list                     # Tabular view
atlas profile show dev-synapse         # Full YAML
atlas profile validate dev-synapse     # Schema check
```

### Create / edit

```bash
atlas profile create my-project --from dev-synapse  # Copy template
atlas profile edit my-project                        # Open in $EDITOR
atlas profile validate my-project                    # Verify
```

### Launch with profile

```bash
atlas --profile dev-synapse synapse                 # Explicit
atlas synapse                                        # Auto-detect (if enabled)
atlas synapse --no-profile                           # Force no profile
```

### Override individual fields

```bash
atlas synapse --profile dev-synapse --override effort=max
atlas synapse --profile research --override mode=plan --override tier=admin
```

### Debug resolution

```bash
atlas --detect-only                                  # Show resolved state, exit
atlas synapse --print-command                        # Show built claude cmd, exit
```

## Profile Examples

### `dev-synapse.yaml` — Synapse engineering
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
  - "/home/sgagnon/workspace_atlas/projects/atlas/synapse/**"
git_branch_hook:
  "feature/*": { fork_session: true }
  "main":      { permission_mode: plan }
```

### `admin-infra.yaml` — Infrastructure work
```yaml
name: admin-infra
extends: base
tier: admin
permission_mode: plan      # Always cautious for infra
effort: xhigh
worktree: false            # Direct, not isolated
mcp_profile: minimal
cwd_match:
  - "/home/sgagnon/workspace_atlas/infrastructure/**"
wifi_trust_required: medium  # Prefer trusted networks
```

### `research.yaml` — Exploration mode
```yaml
name: research
extends: base
tier: core                 # Minimal plugin footprint
permission_mode: default
effort: medium
worktree: false
mcp_profile: minimal       # Just context7 for docs
```

## Environment Variables (set by profile load)

After `_atlas_load_profile` resolves:

| Var | Source | Example |
|-----|--------|---------|
| `ATLAS_LAUNCH_PROFILE` | active profile name | `dev-synapse` |
| `ATLAS_LP_CHAIN` | inheritance chain | `base dev-synapse` |
| `ATLAS_LP_TIER` | profile.tier | `dev` |
| `ATLAS_LP_PERMISSION_MODE` | profile.permission_mode | `plan` |
| `ATLAS_LP_EFFORT` | profile.effort | `high` |
| `ATLAS_LP_WORKTREE` | profile.worktree | `true` |
| `ATLAS_LP_FORK_SESSION` | profile.fork_session | `auto` |
| `ATLAS_LP_BARE` | profile.bare | `false` |
| `ATLAS_LP_MCP_PROFILE` | profile.mcp_profile | `chrome-playwright` |
| `ATLAS_LP_WIFI_TRUST_REQUIRED` | profile.wifi_trust_required | `low` |

These are consumed by `launcher.sh` during cmd array build.

## See Also

- [INSTALL.md](./INSTALL.md) — install
- [CLAUDE-CODE-SETUP.md](./CLAUDE-CODE-SETUP.md) — Claude Code itself
- `templates/profiles/*.yaml` — seed profiles (templates/)
- `scripts/atlas-modules/platform.sh` — `_atlas_load_profile` + overlays implementation
