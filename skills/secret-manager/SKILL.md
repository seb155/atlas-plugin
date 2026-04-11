---
name: secret-manager
description: "Manage infrastructure secrets via Infisical (primary) with .env fallback. Check secret status, rotate tokens, add new secrets. Use when 'secrets', 'tokens', 'env vars', 'credentials', 'atlas-env', 'infisical', 'secret status'."
effort: low
---

# Secret Manager — Infisical + .env Fallback

Unified secret management for AXOIQ infrastructure. Loads secrets from Infisical self-hosted (`secrets.axoiq.com`) with automatic `.env` fallback for users without Infisical.

## Provider Cascade

```
1. Infisical API (secrets.axoiq.com) — primary, audited, versioned
2. ~/.env plaintext — fallback for offline/no-infisical users
```

Provider configured in `~/.atlas/config.json` → `secrets.provider`:
- `"infisical"` — Universal Auth via `atlas-env` CLI
- `"vaultwarden"` — BW CLI unlock + token fetch (legacy)
- `"env"` — direct `~/.env` source (simplest)

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas secrets` or `/atlas secrets status` | Show loaded secrets (masked) and provider |
| `/atlas secrets reload` | Re-fetch from Infisical and export |
| `/atlas secrets add KEY VALUE` | Add a new secret to Infisical dev environment |
| `/atlas secrets list` | List all secret keys (no values) from Infisical API |
| `/atlas secrets rotate KEY` | Generate new value and update in Infisical |
| `/atlas secrets provider [name]` | Show or switch provider (infisical/vaultwarden/env) |

## Process

### Status Check

```bash
atlas-env status
```

Shows 14 managed keys with masked values and source indicator.

### Reload Secrets

```bash
eval "$(atlas-env load)"
atlas-env status
```

### Add New Secret

```bash
# Via Infisical API
INFISICAL_TOKEN=$(curl -sf -X POST "${INFISICAL_URL}/api/v1/auth/universal-auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"clientId\":\"${CLIENT_ID}\",\"clientSecret\":\"$(cat ~/.config/infisical/client-secret)\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

curl -sf -X POST "${INFISICAL_URL}/api/v3/secrets/raw/${KEY}" \
  -H "Authorization: Bearer ${INFISICAL_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"workspaceId\":\"${PROJECT_ID}\",\"environment\":\"dev\",\"secretPath\":\"/\",\"secretValue\":\"${VALUE}\",\"type\":\"shared\"}"
```

### For Users Without Infisical (Fallback)

Users who don't have a homelab or Infisical instance:

1. Set `secrets.provider` to `"env"` in `~/.atlas/config.json`
2. Create `~/.env` with their tokens:
   ```bash
   FORGEJO_TOKEN=xxx
   GEMINI_API_KEY=xxx
   ```
3. The SessionStart hook will `source ~/.env` automatically
4. No Infisical setup needed — everything works via plaintext env file

## Architecture

```
┌─────────────────────────────────────────┐
│ SessionStart Hook                       │
│                                         │
│ config.json → secrets.provider          │
│   ├─ "infisical" → atlas-env load      │
│   │     ├─ Universal Auth → API token  │
│   │     ├─ GET /secrets/raw → 14 vars  │
│   │     └─ fallback → source ~/.env    │
│   ├─ "vaultwarden" → bw unlock + get   │
│   └─ "env" → source ~/.env            │
│                                         │
│ Result: env vars exported to session    │
└─────────────────────────────────────────┘
```

## Infrastructure

| Component | Location | Details |
|-----------|----------|---------|
| Infisical Server | LXC 108 on PVE1 | `192.168.10.77:8082` → `secrets.axoiq.com` |
| Machine Identity | `atlas-cli` | Universal Auth, Admin role |
| Client Secret | `~/.config/infisical/client-secret` | chmod 600, never in git |
| CLI Wrapper | `~/.local/bin/atlas-env` | load/status/clear/setup |
| Config | `~/.atlas/config.json` | `secrets.provider: "infisical"` |

## Security Rules

- NEVER log secret values — only masked (first 4 + last 4 chars)
- NEVER commit `~/.config/infisical/client-secret` or `~/.env` to git
- Client secret file MUST be chmod 600
- Infisical dashboard: `https://secrets.axoiq.com` (audit logs available)
- Rotate client secret if compromised: Infisical UI → Access Control → Identities → atlas-cli
