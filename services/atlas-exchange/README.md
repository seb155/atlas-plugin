# atlas-exchange — Microservice for Phase B.2.c

**Status**: Skeleton shipped 2026-04-20, **NOT DEPLOYED**. Needs a dedicated
deploy session with supervised testing.

**Purpose**: Bridge Authentik OIDC device flow (user-facing) to Cloudflare
Access Service Tokens (m2m-facing). Called by `scripts/atlas-setup.sh`
after the user completes OAuth device authorization in their browser.

**Plan reference**: `.blueprint/plans/aujourdhui-su-rmon-ordinateur-clever-blum.md` Phase B.2.c
**ADR**: ADR-021 Device Flow OAuth bootstrap.

## Flow

```
User types: curl -fsSL https://plugins.axoiq.com/atlas.sh | bash
    │
    ▼ (atlas-setup.sh starts device flow)
    │
    Authentik Device Authorization endpoint
    /application/o/device_authorize/
    │
    ▼ user opens URL in browser, approves
    │
    atlas-setup.sh polls /token endpoint → access_token (Authentik)
    │
    ▼ POST with Authorization: Bearer <access_token>
    │
    https://auth.axoiq.com/atlas/exchange (THIS SERVICE)
    │  1. validates Authentik JWT (signature, audience, expiry)
    │  2. issues CF Access Service Token via CF API (1-year expiry)
    │  3. appends token_id to P2 policy include list
    │  4. returns {client_id, client_secret, expires_at}
    │
    ▼ atlas-setup.sh writes to ~/.claude/settings.json
    │
    claude plugin install atlas-core@atlas-axoiq works ✓
```

## Deployment runbook (when ready)

### 1. Authentik OIDC provider setup (UI — ~10 min)

Navigate: `https://auth.axoiq.com/if/admin/#/core/providers` → Créer → OAuth2/OpenID Provider.

Fields:
- Name: `atlas-cli-device`
- Authorization flow: default-provider-authorization-explicit-consent
- Invalidation flow: default-provider-invalidation-flow
- Client type: Public
- Client ID: `atlas-cli-device` (set explicitly, atlas-setup.sh uses this)
- Allowed redirect URIs: not applicable (device flow)
- Property mappings: default-oauth2-openid-userinfo

Under "Flow Settings" → enable Device Code flow:
- Device Authorization Endpoint: check "Enabled"

Then Applications → Créer:
- Name: `ATLAS CLI Device`
- Slug: `atlas-cli-device`
- Provider: atlas-cli-device (from above)
- Policies: who can use ATLAS CLI (default: all logged-in AXOIQ users)

Capture the `AUTHENTIK_ISSUER` URL: `https://auth.axoiq.com/application/o/atlas-cli-device/`
Capture the `AUTHENTIK_JWKS_URL`: `https://auth.axoiq.com/application/o/atlas-cli-device/jwks/`

### 2. Deploy this microservice (Docker Compose)

Target host: likely `srv-ctrl` (PVE1) in a new container LXC or VM, on the
internal network reachable by Caddy.

```bash
# 2a. Build image
cd ~/workspace_atlas/projects/atlas-plugin/services/atlas-exchange
docker build -t atlas-exchange:0.1.0 .

# 2b. Create docker-compose.yml on the target host
cat > /srv/atlas-exchange/docker-compose.yml <<'EOF'
services:
  atlas-exchange:
    image: atlas-exchange:0.1.0
    container_name: atlas-exchange
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
    env_file: /srv/atlas-exchange/.env
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()"]
      interval: 30s
      timeout: 5s
EOF

# 2c. Create .env (chmod 600) on target host
cat > /srv/atlas-exchange/.env <<'EOF'
AUTHENTIK_ISSUER=https://auth.axoiq.com/application/o/atlas-cli-device/
AUTHENTIK_AUDIENCE=atlas-cli-device
AUTHENTIK_JWKS_URL=https://auth.axoiq.com/application/o/atlas-cli-device/jwks/
CF_EMAIL=sebastiengagnon155@gmail.com
CF_GLOBAL_API_KEY=<from Bitwarden "cloudflare.com" item custom field "API">
CF_ACCOUNT_ID=418120b9e6fa67cbddcb4a03aafb7e11
CF_ACCESS_APP_ID=29135f06-ca88-4e1b-9e2b-23a141cfe6d2
CF_POLICY_ID=0fe85847-d583-41e5-a689-598a107b700f
TOKEN_DURATION_HOURS=8760
LOG_LEVEL=INFO
EOF
chmod 600 /srv/atlas-exchange/.env

# 2d. Bring up
cd /srv/atlas-exchange && docker compose up -d
curl -fsS http://localhost:8000/health  # Should return {"status":"ok"}
```

### 3. Caddy route (add to homelab-iac Caddyfile)

```caddy
auth.axoiq.com {
  # ... existing Authentik proxy ...

  # Phase B.2.c — atlas-exchange sidecar route
  @atlas_exchange path /atlas/exchange
  handle @atlas_exchange {
    reverse_proxy <atlas_exchange_host>:8000
  }

  # Existing Authentik catch-all stays below
}
```

### 4. End-to-end test

```bash
# From a fresh VM (no existing atlas config):
curl -fsSL https://plugins.axoiq.com/atlas.sh | bash
# Follow the device flow → browser Google login → approve → wait
# Expected: atlas-setup.sh completes + writes ~/.claude/settings.json + installs atlas-core
```

## Security notes

- CF Global API Key is sensitive (full CF account access). Store ONLY in
  the atlas-exchange container env, not in app code or logs.
- Each call to `/atlas/exchange` creates a new CF service token + appends
  to P2 policy. This can grow unbounded. Mitigation: rotate old tokens
  monthly via cron (Phase B.5 scope).
- Rate limiting: upstream Caddy should limit to 10 req/min per IP to
  prevent token exhaustion attacks.
- Audit log: structlog JSON output, ship to Loki (Phase B.5).

## Local dev

```bash
cd services/atlas-exchange
uv venv
uv pip install -e ".[dev]"
cp .env.example .env  # TODO: create .env.example with dummy values
uvicorn main:app --reload --port 8000
# Curl test:
curl -X POST http://localhost:8000/health
```

## Dependencies

- Python 3.13
- FastAPI + uvicorn (HTTP server)
- python-jose (JWT validation)
- httpx (async HTTP client for CF API)
- structlog (structured logging)

## Future enhancements (out of scope for Phase B.2.c MVP)

- Rate limiting middleware (e.g., slowapi)
- Prometheus metrics endpoint (/metrics)
- Ops dashboard showing recent token issuances
- Revoke-by-email endpoint (for offboarding users)
- Webhook to Matrix on each new token issued (audit notification)
