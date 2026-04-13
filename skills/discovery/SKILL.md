---
name: discovery
description: "Display and refresh ATLAS capability discovery — shows installed addons, tier, persona, pipeline. Use to debug master atlas-assist routing or after installing/uninstalling addons."
user-invocable: true
---

# ATLAS Capability Discovery

Master `atlas-assist` adapts its behavior (persona, pipeline, active skills) based on which ATLAS addons are installed. This skill lets you **inspect** and **refresh** that detection.

## When to use

- After installing or uninstalling an addon (`/plugin install atlas-dev`)
- Master atlas-assist seems to use wrong persona or pipeline
- Status bar shows wrong tier
- Debugging plugin issues

## What it does

1. Reads `~/.atlas/runtime/capabilities.json` (written by SessionStart hook)
2. Shows installed addons, tier, persona, pipeline
3. If `--refresh` is requested, re-runs the scanner

## Capability JSON Schema

```json
{
  "version": "5.1.0",
  "tier": "admin",          // highest installed tier (core/dev/admin)
  "addons": [               // all detected ATLAS addons
    {"name": "atlas-core",  "tier": "core",  "version": "5.1.0", "skills": 25, "agents": 1},
    {"name": "atlas-admin-addon", "tier": "admin", ...}
  ],
  "skills_total": 88,
  "agents_total": 16,
  "persona": "infrastructure architect",
  "pipeline": "DISCOVER → PLAN → STRATEGY → IMPLEMENT → VERIFY → SHIP → DEPLOY → INFRA",
  "banner_label": "Admin"
}
```

## Workflow

When invoked:

1. Read `~/.atlas/runtime/capabilities.json`
2. Render summary in markdown table format:
   ```
   🔍 ATLAS Capability Discovery
   ─────────────────────────────
   Tier:     admin (priority 3)
   Version:  5.1.0
   Persona:  infrastructure architect
   Pipeline: DISCOVER → PLAN → STRATEGY → ...

   Installed Addons:
   | Name | Tier | Version | Skills | Agents |
   |------|------|---------|--------|--------|
   | atlas-core | core | 5.1.0 | 25 | 1 |
   | atlas-dev-addon | dev | 5.1.0 | 29 | 7 |
   | atlas-admin-addon | admin | 5.1.0 | 63 | 16 |

   Total: 117 skills · 24 agents
   ```
3. If user requested refresh: run `${CLAUDE_PLUGIN_ROOT}/scripts/atlas-discover-addons.sh` then re-read

## Refresh

User can request a fresh scan:
- "discovery refresh"
- "rescan addons"
- "what addons do I have"

Run the scanner explicitly:
```bash
~/.claude/plugins/cache/atlas-marketplace/atlas-core/<version>/scripts/atlas-discover-addons.sh
```

Then re-read the JSON.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `marketplace_found: false` | Cache dir missing | Check `~/.claude/plugins/cache/atlas-marketplace/` exists |
| `tier: "unknown"` for an addon | Missing `_addon-manifest.yaml` in addon root | Reinstall via `/plugin install` |
| `version: "?"` | Missing VERSION file | Plugin malformed — reinstall |
| Wrong persona/pipeline | Tier max calculation wrong | Verify priorities in manifests (1=core, 2=dev, 3=admin) |
