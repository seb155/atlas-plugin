---
description: "Activate ATLAS unified assistant — adaptive master entry point"
user-invocable: true
---

# /atlas — Activate ATLAS Master

Explicitly invoke the **adaptive master skill** (`atlas-assist`) — useful when:

- ATLAS didn't auto-load at SessionStart (rare)
- You want to **force re-detection** of installed addons
- After installing a new addon (`/plugin install atlas-dev`)
- You explicitly need ATLAS context (otherwise auto-loaded)

## What it does

1. Runs `~/.claude/plugins/cache/atlas-marketplace/atlas-core/<version>/scripts/atlas-discover-addons.sh`
2. Updates `~/.atlas/runtime/capabilities.json` with detected tier/persona/pipeline
3. Invokes the `atlas-assist` skill (master)
4. Master adapts to detected tier (core / dev / admin) and shows the session banner

## Subcommands (Sonnet hint, not strict)

When called without arguments → activate master.

When called with arguments → route via auto-orchestrator (admin tier only):
- `/atlas dream` → memory consolidation
- `/atlas morning` → daily brief
- `/atlas doctor` → system health
- `/atlas onboard` → setup wizard

## Routing

The master detects tier from `capabilities.json` and adapts:

| Detected Tier | Persona | Pipeline |
|---|---|---|
| **core** | helpful assistant | DISCOVER → ASSIST |
| **dev** | senior engineering architect | DISCOVER → PLAN → STRATEGY → IMPLEMENT → VERIFY → SHIP |
| **admin** | infrastructure architect | DISCOVER → ... → SHIP → DEPLOY → INFRA |

## Stop

To deactivate ATLAS persona for the rest of the session:
- Say "stop atlas" or "normal mode"

## See also

- `discovery` skill — inspect/refresh capability detection
- `atlas-doctor` skill — system health audit
