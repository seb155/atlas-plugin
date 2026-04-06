---
name: infra-health
description: "Infrastructure health audit — 57 endpoints, LAN + WAN, SSO + SSL. Self-healing with auto-fix recipes. /atlas health infra for full audit, --fix for auto-repair. Uses endpoints.yml SSoT from homelab-iac repo."
effort: high
---

# Infrastructure Health — Reconciliation Loop Audit

Verify all AXOIQ internet-facing services are accessible with SSO working.
Checks 3 paths: LAN direct → LAN via Caddy/SSO → WAN via CF Tunnel.
Auto-fixes known failure patterns (Caddy reload, CF Tunnel route, Docker restart).

## When to Use

- User says "health infra", "check infrastructure", "are services up", "SSO working"
- User says "everything accessible?", "test all apps", "audit services"
- After infrastructure changes (Caddy, Authentik, CF Tunnel, DNS)
- After VM migrations or Docker stack restarts
- Periodically (recommended: daily via server cron)

## Subcommands

| Command | Mode | Scope |
|---------|------|-------|
| `/atlas health infra` | **Full LAN** | All 57 endpoints via Caddy + direct |
| `/atlas health infra --wan` | **Full + WAN** | Add Oracle VPS external validation |
| `/atlas health infra --fix` | **Auto-repair** | Fix known patterns with HITL gate |
| `/atlas health infra --tier 1` | **Critical only** | 10 Tier 1 services |
| `/atlas health infra --ssl` | **SSL only** | Certificate expiry check |
| `/atlas health infra --json` | **JSON** | Machine-readable output |

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ DESIRED     │     │ OBSERVE     │     │ RECONCILE   │
│ STATE       │────▶│ ACTUAL      │────▶│ (auto-fix)  │
│ (YAML SSoT) │     │ STATE       │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       │
       └──── endpoints.yml (homelab-iac) ──────┘
```

**SSoT Config**: `infrastructure/services/health/endpoints.yml`
**Health Script**: `infrastructure/services/health/health-checker.py`
**Server Cron**: VM 550 every 4h + Oracle VPS relay for WAN

## Execution Steps

### Step 1: Load Config

Read `endpoints.yml` from the infrastructure repo (or use the local copy):
```bash
cat ~/workspace_atlas/infrastructure/services/health/endpoints.yml
```

### Step 2: Check Identity Infrastructure (prerequisite)

```bash
# Authentik server + outposts must be UP for SSO to work
curl -sf http://192.168.10.90:9005/-/health/live/   # Authentik
curl -sf http://192.168.10.90:9800/outpost.goauthentik.io/ping  # AXOIQ outpost
curl -sf http://192.168.10.90:9801/outpost.goauthentik.io/ping  # S-Gagnon outpost
```

### Step 3: LAN Checks (via split DNS → Caddy → ForwardAuth)

For each endpoint in `endpoints.yml`:
- `curl --max-redirs 0 https://{hostname}` → check expected status code
- SSO services should return **302** (redirect to auth.axoiq.com)
- Public services should return **200**
- Native auth services should return **!= 302**

### Step 4: LAN Direct Checks (bypass SSO)

For endpoints with `lan_direct` config:
- `curl http://{ip}:{port}/{health_path}` → check backend is alive
- Verifies the service itself is running, independent of SSO/Caddy

### Step 5: WAN Checks (if --wan)

Single SSH session to Oracle VPS (151.145.51.234):
```bash
ssh ubuntu@151.145.51.234 'for url in ...; do
  curl -s -w "%{http_code}|%{time_total}" --max-redirs 0 "https://$url"
done'
```
Tests the full path: Internet → CF Edge → CF Tunnel → Caddy → service

### Step 6: SSL Checks

```bash
echo | openssl s_client -connect {hostname}:443 -servername {hostname} | openssl x509 -noout -enddate
```
Verify all certs have > 30 days remaining.

### Step 7: Auto-Fix (if --fix)

When a check fails, match against fix recipes in `endpoints.yml`:

| Failure Pattern | Auto-Fix |
|----------------|----------|
| `lan_caddy == 502` | `ssh root@192.168.5.103 systemctl reload caddy` |
| `wan == 404` (tunnel) | CF API: add public hostname route |
| `lan_direct != 200` | `docker restart {service}` on target VM |
| `identity_fail` | Alert only — never auto-restart Authentik |

**HITL Gate**: Always show the proposed fix and ask for confirmation before executing.

### Step 8: Report

Produce the formatted ASCII table:

```
═══════════════════════════════════════════════════════
  AXOIQ Health Check — 2026-04-06 18:26
═══════════════════════════════════════════════════════

  Identity: ✅ Authentik + outposts
  Tier 1:    ✅ 10/10
  Tier 2:    ✅ 21/21
  Tier 3:    ✅ 20/20
  Tier 4:    ✅ 3/3

  Score: 100/100 | Total: 57/57 | Fixed: 0
═══════════════════════════════════════════════════════
```

## Quick Mode (use health-checker.py directly)

If the Python script is available, prefer running it directly for speed:

```bash
python3 ~/workspace_atlas/infrastructure/services/health/health-checker.py --wan
python3 ~/workspace_atlas/infrastructure/services/health/health-checker.py --wan --fix
python3 ~/workspace_atlas/infrastructure/services/health/health-checker.py --tier 1 --json
```

## Endpoint Tiers

| Tier | Services | Examples |
|------|----------|---------|
| 1 | 10 critical | synapse, hub, cloud, coder, dev, auth, demo, openwebui, ollama |
| 2 | 21 internal | forgejo, observe, prometheus, logs, status, mcp, netbird, vault |
| 3 | 20 personal | paperless, immich, pve1-3, truenas, budget, stirling |
| 4 | 3 native-auth | vaultwarden, ha, immich (SSO bypass) |

## Server-Side Cron

The health-checker.py runs on VM 550 every 4 hours:
```cron
7 */4 * * * /opt/health/health-checker.py --fix --wan --quiet
```

Sends Telegram alerts on failure. Logs to `/opt/health/results.jsonl`.
