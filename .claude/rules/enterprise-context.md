# Enterprise Context Rules (ATLAS Plugin)

## Plugin Scope
- ATLAS Plugin is PUBLIC and GENERIC — works for any company
- AXOIQ = reference preset implementation (`scripts/presets/axoiq.json`)
- NEVER hardcode URLs, tokens, or company-specific values in skills/hooks
- All company-specific config goes in `~/.atlas/config.json` presets

## When Working on Skills That Touch Synapse
- Material-first philosophy: `PACKAGES → MATERIAL → ACTIVITIES → HOURS → COSTS`
- `project_id` filter on EVERY data-scoped query (multi-tenant safety)
- 3-tier rule inheritance: ISA standard (global) → Company → Project
- Part lifecycle: G→E→M→I→S-Part (never skip stages)
- MBSE 4-layer: QUOI/OÙ/COMMENT/QUI (keep layers independent)

## When Working on Enterprise Skills
- `enterprise-audit` checks 14 dimensions (multi-tenant, auth, observability, backup, etc.)
- `security-audit` covers OWASP Top 10, RBAC, SSL/TLS, container security
- HITL gates are NON-NEGOTIABLE — never auto-approve enterprise decisions

## When Working on Integration Skills
- All API endpoints come from config preset, NEVER hardcoded
- Token resolution: env → keyring → Vaultwarden → prompt user (4-tier chain)
- Internal services (Forgejo, Synapse) are NOT accessible from external networks

## Personas
- 8 engineering personas use this plugin (I&C Eng, EL, ME, Process, PM, Procurement, Admin, Client)
- Skills should be generic enough to serve all personas
- Persona-specific behavior goes in Synapse, not the plugin
