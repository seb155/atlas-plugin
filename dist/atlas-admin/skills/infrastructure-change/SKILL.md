---
name: infrastructure-change
description: "Admin-tier infrastructure change orchestration: CF Tunnel, Caddy, Authentik, DNS, NetBird. Pre-flight validation, HITL gates on destructive ops, rollback support. Prevents cascade failures like the 2026-03-30 incident."
effort: high
---

# Infrastructure Change — Safe Change Orchestration

> Every infrastructure change MUST start with pre-flight validation.
> The 2026-03-30 cascade failure (asymmetric routing + missing originRequest + outpost not in tunnel) was preventable.
> This skill encodes those lessons as non-negotiable gates.

## Pipeline

```
PRE-FLIGHT → PLAN → BACKUP → EXECUTE → VERIFY → (ROLLBACK if unhealthy)
```

## When to Use

- Adding a new service to CF Tunnel
- Modifying the Caddyfile (routes, snippets, reverse proxies)
- DNS record changes (CF API)
- NetBird routing configuration
- Authentik configuration (providers, outposts, policies)
- CF Access app creation or deletion
- Any change that touches SSO callback flows

## Pre-Flight Checklist (ALL 12 MANDATORY before any change)

```bash
# 1. Read live Caddyfile
ssh root@192.168.5.103 "cat /etc/caddy/Caddyfile"

# 2. List CF Tunnel ingress rules
curl -s "https://api.cloudflare.com/client/v4/accounts/418120b9e6fa67cbddcb4a03aafb7e11/cfd_tunnel/360e4c36-d821-4290-877e-a3124bf5218e/configurations" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL" | jq '.result.config.ingress[]'

# 3. List CF Access apps
curl -s "https://api.cloudflare.com/client/v4/accounts/418120b9e6fa67cbddcb4a03aafb7e11/access/apps" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL" | jq '.result[] | {name,domain}'

# 4. Verify DNS records
curl -s "https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL" | jq '.result[] | {name,type,content}'

# 5. Test Caddy → backend connectivity
ssh root@192.168.5.103 "ping -c1 -W2 <backend_ip>"

# 6. Check NetBird routing table on Caddy LXC
ssh root@192.168.5.103 "ip route show table netbird"

# 7. Backup CF Access apps
curl -s "https://api.cloudflare.com/client/v4/accounts/418120b9e6fa67cbddcb4a03aafb7e11/access/apps" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL" > backup-cf-access-$(date +%Y%m%d-%H%M).json

# 8. Backup CF Tunnel config
curl -s "https://api.cloudflare.com/client/v4/accounts/418120b9e6fa67cbddcb4a03aafb7e11/cfd_tunnel/360e4c36-d821-4290-877e-a3124bf5218e/configurations" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL" > backup-cf-tunnel-$(date +%Y%m%d-%H%M).json
```

**Checklist gates** (confirm before proceeding):
- [ ] Items 1-8 above complete
- [ ] New tunnel service: ALWAYS add `originRequest` with `noTLSVerify`, `httpHostHeader`, `originServerName`
- [ ] auth/outpost domains: NEVER add CF Access app (blocks OIDC/callback flow)
- [ ] NetBird routes: NEVER route subnets that are physically reachable on the Caddy LXC
- [ ] Test from both LAN AND Internet after every change

**HITL Gate**: AskUserQuestion → Approve | Modify | Abort

## CF Tunnel Rules

### API Credentials
- **Auth method**: Global Key (`X-Auth-Key` + `X-Auth-Email`) — NOT Bearer token (Bearer = DNS-only scope)
- **Account ID**: `418120b9e6fa67cbddcb4a03aafb7e11`
- **Tunnel**: `Homelab_Prod_01` (`360e4c36-d821-4290-877e-a3124bf5218e`)
- **IDP Google**: `12c8c71e-0d70-4fd8-a303-26d6f004af4d`

### New Service Template (MANDATORY — do not omit originRequest)

```json
{
  "hostname": "service.axoiq.com",
  "service": "https://192.168.5.103",
  "originRequest": {
    "noTLSVerify": true,
    "httpHostHeader": "service.axoiq.com",
    "originServerName": "service.axoiq.com"
  }
}
```

### CF Access Team Policy (4 emails)

```json
{
  "name": "AXOIQ Team",
  "include": [
    {"email": {"email": "sebastiengagnon155@gmail.com"}},
    {"email": {"email": "sgagnon@axoiq.com"}},
    {"email": {"email": "jmerciergingras@gmail.com"}},
    {"email": {"email": "philippe.lanthier.2@gmail.com"}}
  ]
}
```

### NEVER Add CF Access To

- `auth.axoiq.com` — Authentik itself
- `outpost.axoiq.com` — Authentik outpost (OIDC callback endpoint)
- Any `*.auth.*` or `*outpost*` subdomain
- Reason: CF Access intercepts the OIDC callback, causing `redirect_uri_mismatch` or `502` on login

## Caddy Management

### File Location & Deployment

```bash
# Edit locally, then deploy
scp /local/Caddyfile root@192.168.5.103:/etc/caddy/Caddyfile
ssh root@192.168.5.103 "caddy reload --config /etc/caddy/Caddyfile"

# Verify no errors
ssh root@192.168.5.103 "caddy validate --config /etc/caddy/Caddyfile"
```

### Snippet Order (CRITICAL)

In any `route` block that proxies to Authentik:
```
route {
  # 1. outpost path FIRST (before authentik catch-all)
  reverse_proxy /outpost.goauthentik.io/* outpost:9800

  # 2. authentik server after
  reverse_proxy * authentik:9000
}
```

### Two Outposts

| Outpost | Port | Domain scope |
|---------|------|-------------|
| Primary | `9800` | `*.axoiq.com` |
| Secondary | `9801` | `*.s-gagnon.com` |

### HTTP/1.1 Required for Authentik

```caddy
reverse_proxy authentik:9000 {
  transport http {
    versions 1.1
  }
}
```
Reason: HTTP/2 can cause POST body truncation with Authentik's SSO flows.

## NetBird Safety (CASCADE FAILURE PREVENTION)

### The 2026-03-30 Incident

NetBird routes were created for subnets that the Caddy LXC (192.168.5.103) was **physically connected to**.

Result:
1. `ip rule 110` sends all traffic from those subnets through the `netbird` table
2. Caddy receives packets on the physical interface
3. Replies go out through the NetBird tunnel (wrong interface)
4. When the tunnel peer is down → all responses are lost
5. **Cascade failure**: all services behind Caddy become unreachable

### NEVER Route Physically-Reachable Subnets

```bash
# Before creating ANY NetBird route, check:
ssh root@192.168.5.103 "ip route show"     # Physical routes
ssh root@192.168.5.103 "ip addr show"      # Physical interfaces

# If the subnet appears in physical routes → DO NOT create a NetBird route for it
```

### Safe NetBird Routing Patterns

| Pattern | Safe? | Notes |
|---------|-------|-------|
| Route only subnets NOT in physical routing table | ✅ | Standard approach |
| Exit node mode (full traffic) | ✅ | Different behavior, explicit |
| Route subnet with peer group exclusions | ⚠️ | Complex, verify carefully |
| Route subnet peer is physically on | ❌ | **CASCADE FAILURE** |

### Recovery from Bad NetBird Route

```bash
# 1. Delete the route via NetBird API or UI
# 2. Flush the policy routing table on affected peers
ssh root@192.168.5.103 "ip route flush table netbird"

# 3. Verify physical routing restored
ssh root@192.168.5.103 "ping -c3 192.168.10.1"
```

## Rollback Protocol

### CF Tunnel Rollback

```bash
# Restore from backup
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/418120b9e6fa67cbddcb4a03aafb7e11/cfd_tunnel/360e4c36-d821-4290-877e-a3124bf5218e/configurations" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL" \
  -H "Content-Type: application/json" \
  --data @backup-cf-tunnel-YYYYMMDD-HHMM.json
```

### CF Access Rollback

```bash
# Remove a bad CF Access app
curl -X DELETE "https://api.cloudflare.com/client/v4/accounts/418120b9e6fa67cbddcb4a03aafb7e11/access/apps/{APP_ID}" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL"
```

### Caddy Rollback

```bash
# Restore original Caddyfile from backup
scp backup-Caddyfile-YYYYMMDD root@192.168.5.103:/etc/caddy/Caddyfile
ssh root@192.168.5.103 "caddy reload --config /etc/caddy/Caddyfile"
```

### NetBird Rollback

```bash
# Delete routes via NetBird API
# Then flush policy routing table on affected peers
ssh root@<peer-ip> "ip route flush table netbird"
```

### DNS Rollback

```bash
# Revert DNS record via CF API (use backup to get original values)
curl -X PUT "https://api.cloudflare.com/client/v4/zones/{ZONE_ID}/dns_records/{RECORD_ID}" \
  -H "X-Auth-Key: $CF_API_KEY" -H "X-Auth-Email: $CF_AUTH_EMAIL" \
  -H "Content-Type: application/json" \
  --data '{"type":"CNAME","name":"service","content":"tunnel-id.cfargotunnel.com","proxied":true}'
```

## Verification Suite

Run ALL after every change:

```bash
# 1. Authentik outpost ping
curl -sI https://outpost.axoiq.com/outpost.goauthentik.io/ping
# Expected: HTTP/2 204

# 2. NetBird routing table (should be empty after removing bad routes)
ssh root@192.168.5.103 "ip route show table netbird"
# Expected: empty or only intentional non-physical routes

# 3. Caddy connectivity to backends
ssh root@192.168.5.103 "ping -c1 192.168.10.50"  # synapse backend
ssh root@192.168.5.103 "ping -c1 192.168.10.75"  # forgejo

# 4. Internal service test (LAN)
curl -sI https://synapse.axoiq.com/api/v1/health

# 5. External service test (Internet — use Oracle VPS or mobile)
# ssh user@oracle-vps "curl -sI https://synapse.axoiq.com/api/v1/health"
```

### Expected Post-Change Status

| Check | Expected |
|-------|----------|
| Outpost ping | `204 No Content` |
| NetBird table | Empty (no asymmetric routes) |
| Caddy → backends | All reachable |
| New service (LAN) | `200 OK` or correct redirect |
| New service (Internet) | `200 OK` or correct redirect |
| SSO login flow | Completes without 502 |

## HITL Gates

| Operation | Gate |
|-----------|------|
| Add CF Tunnel ingress | ⚠️ HITL — verify originRequest present |
| Add CF Access app | ⚠️ HITL — confirm NOT an auth/outpost domain |
| Modify Caddyfile | ⚠️ HITL — validate before reload |
| Create NetBird route | ⚠️ HITL — confirm NOT physically reachable subnet |
| DNS record change | ⚠️ HITL — TTL + propagation check |
| Rollback | ⚠️ HITL — confirm scope of rollback |

**Max 2 retries per step** → AskUserQuestion with error + 3 options if exceeded.

## Safety Rules (NON-NEGOTIABLE)

1. **Pre-flight ALWAYS** — never skip the 12-item checklist
2. **Backup before any CF Tunnel/Access mutation**
3. **originRequest on every tunnel service** — missing = 502
4. **No CF Access on auth/outpost** — always check the domain before creating
5. **NetBird routes only for non-physical subnets** — check `ip route show` first
6. **Test from BOTH LAN and Internet** — CF Tunnel behaves differently on each
7. **HTTP/1.1 for Authentik** — avoid POST truncation
8. **outpost-path BEFORE authentik** in Caddy route blocks
9. **Never expose API keys** in output or logs
10. **Audit trail** — log every change with timestamp and backup filename
