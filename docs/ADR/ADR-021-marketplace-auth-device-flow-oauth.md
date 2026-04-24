# ADR-021: Bootstrap marketplace credentials via OAuth Device Flow (RFC 8628) through Authentik

**Status**: Accepted (2026-04-20)
**Authors**: Sebastien Gagnon (with ATLAS)
**Supersedes**: none
**Related**: ADR-020 (CF Access Service Tokens), ADR-022 (HITL auto-update)
**Phase**: B.2 of aujourdhui-su-rmon-ordinateur-clever-blum.md Zero-Trust pyramid

## Context

ADR-020 mandates that Claude Code CLI authenticate to `plugins.axoiq.com`
via CF Access Service Token (`CF-Access-Client-Id` + `CF-Access-Client-Secret`
headers in `~/.claude/settings.json`). This creates a **chicken-and-egg bootstrap
problem**:

1. User installs Claude Code on a fresh machine.
2. User wants to install the ATLAS plugin.
3. `claude plugin install atlas-core` fails because no service token is configured.
4. To get a service token, the user needs to authenticate → but CC CLI does not
   support interactive OAuth flows (no browser launch, no callback server).

Competing tools solved this with OAuth 2.0 Device Authorization Grant (RFC 8628):
- `gh auth login` (GitHub CLI)
- `gcloud auth login` (Google Cloud SDK)
- `doctl auth init` (DigitalOcean)
- `flyctl auth login` (Fly.io)

User types a command → CLI shows a URL + code → user opens URL in browser,
approves → CLI polls token endpoint → receives token → writes to config.

## Decision

Ship a small bootstrap script at `plugins.axoiq.com/atlas.sh` that implements
Device Flow OAuth against Authentik, then exchanges the Authentik access_token
for a CF Access Service Token via a custom AXOIQ endpoint `/atlas/exchange`.

```bash
curl -fsSL https://plugins.axoiq.com/atlas.sh | bash
```

UX flow:

```
🔑 ATLAS Marketplace Setup (Phase B.2)
   Requesting device code from Authentik...

   ┌───────────────────────────────────────────────────────┐
   │  Ouvre ce lien :                                      │
   │  https://auth.axoiq.com/application/o/device/?code=.. │
   │  Code   : ABCD-1234                                   │
   └───────────────────────────────────────────────────────┘
   Polling every 5s (timeout 300s)...
   ...
✓ Authenticated via Authentik (elapsed 23s)
   Exchanging for CF Access Service Token...
✓ Received CF Service Token (id: abc12345...)
   Writing CF credentials to /home/user/.claude/settings.json...
✓ Marketplace auth configured
   Running claude plugin install atlas-core@atlas-axoiq...
🎉 Setup complete. Type: claude
```

Technical components:

1. **Authentik OAuth2 Provider** `atlas-cli-device` with device_authorization
   grant enabled.
2. **Custom endpoint** `auth.axoiq.com/atlas/exchange`: validates incoming
   Authentik Bearer token (JWT introspection), issues per-user CF Access
   Service Token via CF API.
3. **Bootstrap script** `scripts/atlas-setup.sh` in atlas-plugin repo,
   served as `plugins.axoiq.com/atlas.sh` via Caddy path rewrite.
4. **Client-side `~/.claude/settings.json`** gets CF headers merged into
   marketplace config via jq-based atomic write (chmod 600).

## Alternatives considered

| Option | Verdict | Why rejected |
|---|---|---|
| **Manual token copy-paste** | ❌ | Error-prone; 2 UUIDs to copy correctly; no audit of which user got the token |
| **OAuth authorization code flow** | ❌ | Requires local HTTP server on 127.0.0.1:PORT for callback → firewall / port-availability issues; not portable |
| **OAuth implicit grant** | ❌ | Deprecated since OAuth 2.1; token in URL fragment = browser history leak |
| **Password grant (ROPC)** | ❌ | Deprecated; user types password into CLI → anti-pattern; no 2FA compat |
| **Client credentials grant** | ❌ | Machine-only, no user identity; can't issue per-user tokens |
| **Mutual TLS + PKI enrollment** | ❌ | Overkill; requires PKI infra; CC doesn't support mTLS |
| **Device Flow (CHOSEN)** | ✅ | Standard RFC 8628; battle-tested (gh, gcloud, doctl); no callback server; works in SSH/headless/Docker; UX equivalent to "best CLIs" |

## Consequences

### Positive
- **Familiar UX** : matches `gh auth login` pattern; zero training required.
- **Portable** : no callback server = works in SSH sessions, Docker containers,
  WSL, CI agents (with `--non-interactive` flag).
- **Security** : Authentik session flows through Seb's Google SSO (2FA enforced)
  → per-user CF token issuance with audit trail.
- **Idempotent** : script detects existing token and skips unless `--force`.
- **Revocable** : user can rotate by re-running script; old token auto-expires.

### Negative
- **Authentik dependency** : if Authentik is down, no new users can onboard.
  Mitigation: existing users' tokens keep working for 90 days.
- **Custom endpoint `/atlas/exchange`** : new code to maintain; bug risk.
  Mitigation: thin shim (~50 LoC Python or Go) with integration tests.
- **Authentik device_authorize endpoint must be enabled** : requires Authentik
  admin UI config (one-time setup).
- **Error UX** : device flow errors (expired_token, access_denied) must be
  user-friendly; current script handles 4 known error codes explicitly.

## Implementation

Phase B.2 sub-steps (2026-04-27 → 2026-05-01):

- B.2.a ✅ `scripts/atlas-setup.sh` script (shipped 2026-04-20 on
  `feature/phase-b-zero-trust`, commit `4f49d83`)
- B.2.b Host script at `plugins.axoiq.com/atlas.sh` via Caddy rewrite
- B.2.c Create Authentik OAuth2 provider `atlas-cli-device` with
  device_authorization grant
- B.2.c Implement `/atlas/exchange` endpoint (custom Python FastAPI or
  Authentik expression; decision pending Phase B exploration)
- B.2.d End-to-end test from fresh Oracle VPS VM

## Rollback plan

Bootstrap script failure = user falls back to manual token copy-paste via
ONBOARDING-EXTERNAL.md docs. The script is non-destructive (only writes to
`~/.claude/settings.json`, never modifies system state), so failures are
silent for the user (settings.json unchanged).

Authentik provider can be disabled in admin UI without affecting existing
tokens (JWT validation is stateless per-request).

## Cross-references

- Plan: `projects/atlas/synapse/.blueprint/plans/aujourdhui-su-rmon-ordinateur-clever-blum.md`
- Script: `scripts/atlas-setup.sh` (atlas-plugin repo)
- RFC 8628: https://datatracker.ietf.org/doc/html/rfc8628
- Companion ADR-020: CF Access Service Tokens
- Companion ADR-022: HITL auto-update gate
