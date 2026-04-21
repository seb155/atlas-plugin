# ADR-020: Zero-Trust auth for plugins.axoiq.com via Cloudflare Access Service Tokens

**Status**: Accepted (2026-04-20)
**Authors**: Sebastien Gagnon (with ATLAS)
**Supersedes**: none
**Related**: ADR-021 (marketplace device flow), ADR-022 (HITL auto-update), ADR-023 (registry access control)
**Phase**: B.1 of aujourdhui-su-rmon-ordinateur-clever-blum.md Zero-Trust pyramid

## Context

Prior to Phase A (2026-04-20), `plugins.axoiq.com` was exposed publicly without
authentication. Anyone on the internet could `curl https://plugins.axoiq.com/marketplace.json`
+ `git clone https://plugins.axoiq.com/` and obtain the full plugin source (131
skills, 24 agents, 41+ hooks including `hooks/lib/auto-update.sh` which
auto-executes `git pull + make dev` at every Claude Code SessionStart).

This created three compounding risks:
1. **Supply-chain attack**: MITM or DNS hijack → attacker pushes malicious
   hooks/skills → RCE in every CC session of every consumer.
2. **IP leak**: 7 internal URLs (forgejo.axoiq.com, vaultwarden.s-gagnon.com, ...),
   client codenames (THM-012, BRTZ, G Mining), proprietary MSE 4-layer schema
   scrapable by competitors.
3. **No audit trail**: no way to know who downloaded the plugin, when, or how
   many times. Compliance / NDA violation risk for G Mining pilot (mai 2026).

Phase A (shipped 2026-04-20 20:54 EDT, homelab-iac PR #11) closed the
browser/scraper gap via Authentik ForwardAuth on non-manifest/non-git paths.
Phase B requires full Zero-Trust for both humans and the CC CLI.

## Decision

Use **Cloudflare Access Service Tokens** as the machine-to-machine (m2m)
authentication mechanism for Claude Code and CI agents consuming
`plugins.axoiq.com`, combined with **Authentik OIDC** for humans browsing the UI.

Architecture:

```
Humans (browser)  ──► Authentik SSO (Google upstream IdP)
                        │
                        ▼
CC CLI + CI      ──► CF Access Service Token (per-user, rotatable)
                        │
                        ▼
                    Cloudflare Access (ZTNA gate)
                        │ CF-Access-Jwt-Assertion
                        ▼
                    CF Tunnel Homelab_Prod_01
                        │
                        ▼
                    Caddy LXC 103 (trusts CF Access)
                        │
                        ▼
                    Forgejo VM 750 (axoiq/atlas-plugin)
```

Three initial service tokens (90-day expiry, per-identity):
- `cc-client-seb` — Seb's 3 machines (laptop, VM 560, homelab nodes)
- `cc-client-axoiq-team` — AXOIQ team (2-3 devs)
- `ci-agents` — Woodpecker runners

Pilot G Mining users (mai 2026) receive individually-named tokens (1 per user)
under CF Access policy P3 (email allowlist from signed NDA roster).

## Alternatives considered

| Option | Verdict | Why rejected |
|---|---|---|
| **Bearer token (static) in settings.json** | ❌ | CC supports `"headers"` but tokens are not audited, not rotated per-user, no revocation UX |
| **Authentik ForwardAuth only** | ❌ | Works for humans but CC CLI cannot do OAuth2 redirect flow → would break bootstrap |
| **mTLS client certificates** | ❌ | CC does not support client certs in marketplace config |
| **Pre-signed URLs** | ❌ | CC does not parse URL parameter schemes |
| **SSH key via `git+ssh://` source** | ❌ | CC marketplace does not accept SSH URLs for `git-subdir` source type |
| **npm-style private registry (@axoiq scope)** | ❌ | CC marketplace protocol is git-based, not npm-based |
| **CF Access Service Tokens (CHOSEN)** | ✅ | Natively compatible with CC `"headers"` config; rotable via CF dashboard; audit log built-in; least-privilege per-user tokens; reuses 50 apps AXOIQ CF Access stack |

## Consequences

### Positive
- **Audit trail** : every m2m request logged in CF dashboard (who, when, outcome)
- **Revocation** : if a user leaves / token leaks, revoke 1 token in 30s via CF dashboard
- **Least privilege** : service tokens are scoped to this app only (not whole CF zone)
- **Pattern reuse** : 50 apps AXOIQ already use CF Access (`cf-access-backup-2026-03-25.json`)
- **Compliance-friendly** : explicit token per identity = SOC2 / ISO27001 defensible

### Negative
- **CF dependency** : if Cloudflare is down, plugins.axoiq.com becomes unreachable
  (acceptable; CF has 99.99% SLA and we have 50 apps already gated by CF)
- **User-side friction** : each user must manually configure `~/.claude/settings.json`
  with `CF-Access-Client-Id` + `CF-Access-Client-Secret` (mitigated by
  `atlas-setup.sh` device flow bootstrap — see ADR-021)
- **Token rotation operational load** : tokens expire at 90d, need bi-weekly rotation
  pattern (ADR-020 Phase B.5: cron + Vaultwarden + `cloudflared access service-token rotate`)
- **Coupling to Forgejo PAT token** : `FORGEJO_PROXY_TOKEN` on Caddy side still
  needs rotation (independent of CF Service Tokens) — Phase B.5 cron handles both

## Implementation

Phase B.1 steps (mai 2026-04-25 → 04-26):

1. Create CF Access app `plugins.axoiq.com` (self_hosted, 24h human session / 1h service)
2. Policies (precedence ordered):
   - P1 `Service — CC/CI clients` (decision: non_identity, include service_token list)
   - P2 `Humans — AXOIQ team` (decision: allow, Authentik OIDC IdP + emails)
   - P3 `Humans — G Mining pilot` (decision: allow, emails from NDA roster)
3. Generate 3 initial service tokens (cc-client-seb, cc-client-axoiq-team, ci-agents)
4. Store tokens in Vaultwarden collection `AXOIQ/Marketplace Tokens` with metadata
5. Update Caddyfile `plugins.axoiq.com` block to trust CF Access JWT
   (remove Authentik ForwardAuth from UI route — CF does the gating now)
6. Add `access_log { output file /var/log/caddy/plugins.log }` for Phase B.5 audit

Reference config pattern: `/home/sgagnon/workspace_atlas/homelab-iac/cf-access-backup-2026-03-25.json`
token_id `7e3dda81-7f5b-42e9-a3e9-c219e7acbbbd` (Forgejo Git Service Auth — analogue).

## Rollback plan

Revert Caddyfile to Phase A state (SSO + public git paths) via
`/etc/caddy/Caddyfile.bak.2026-04-20`. Disable CF Access app in dashboard
(`cloudflared access app delete plugins.axoiq.com`). 30s revert, zero-downtime.

CC clients with configured tokens would get HTTP 200 on both paths during
rollback (tokens ignored when CF gate is disabled) — no UX break for them.
Public scrapers would regain access — accepted for rollback duration (target: <1h).

## Cross-references

- Plan: `projects/atlas/synapse/.blueprint/plans/aujourdhui-su-rmon-ordinateur-clever-blum.md`
- Phase A shipped: homelab-iac PR #11 (commits `dd6b292` + `ce14762`)
- Checkpoint: `memory/checkpoint-phase-a-plugins-axoiq-zero-trust.md`
- Related ADR-023: Forgejo Registry Access Control (pattern analogue)
- Lesson: `lesson_2026-04-19_token_rotation_patterns.md`
