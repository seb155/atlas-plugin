# Secret Management Rules — Per-Tier Access

## Secret Resolution Chain (ALL tiers)

```
Tier 1: $SECRET_NAME in current env (fastest)
  ↓ empty
Tier 2: source ~/.env → re-check
  ↓ empty
Tier 3: keyring cache → bw get password (if vaultwarden provider)
  ↓ empty
Tier 4: Advisory warning in session badge
```

## Secrets by Tier

| Secret | Admin | Dev | User | Purpose |
|--------|:-----:|:---:|:----:|---------|
| FORGEJO_TOKEN | ✅ Required | ✅ Required | ⚠️ Optional | Git API (PRs, CI, deploy) |
| SYNAPSE_TOKEN | ✅ Required | ✅ Required | ⚠️ Optional | Backend API (profile, knowledge) |
| AUTHENTIK_TOKEN | ✅ Auto-resolve | ⚠️ Optional | ❌ N/A | SSO role detection |
| GEMINI_API_KEY | ⚠️ Optional | ⚠️ Optional | ⚠️ Optional | AI model access |
| BW_SESSION | 🔐 Auto (keyring) | 🔐 Auto (keyring) | ❌ N/A | Vaultwarden session |
| BW_CLIENTID | 🔐 CI only | ❌ N/A | ❌ N/A | API key auth (automation) |

## Skills by Tier — Token Requirements

### Admin Tier (inherits dev + user)
| Skill | Tokens Needed | Graceful if Missing? |
|-------|--------------|---------------------|
| atlas-vault | FORGEJO_TOKEN | ❌ Can't clone vault |
| devops-deploy | FORGEJO_TOKEN | ❌ Can't call Forgejo API |
| infrastructure-ops | SSH keys | ✅ Warns, falls back to manual |
| security-audit | None | ✅ Uses local scanning |
| enterprise-audit | SYNAPSE_TOKEN | ✅ Degrades gracefully |

### Dev Tier (inherits user)
| Skill | Tokens Needed | Graceful if Missing? |
|-------|--------------|---------------------|
| finishing-branch | FORGEJO_TOKEN | ❌ Can't create PR |
| code-review | FORGEJO_TOKEN (PR mode) | ✅ Falls back to local diff |
| tdd | None | ✅ Local only |
| verification | None | ✅ Local only |

### User Tier (base)
| Skill | Tokens Needed | Graceful if Missing? |
|-------|--------------|---------------------|
| knowledge-builder | SYNAPSE_TOKEN | ✅ Degrades, warns |
| user-profiler | SYNAPSE_TOKEN | ✅ Degrades, warns |
| note-capture | SYNAPSE_TOKEN | ✅ Degrades, warns |
| morning-brief | SYNAPSE_TOKEN | ✅ Degrades, warns |
| deep-research | None | ✅ Uses WebSearch |
| browser-automation | None | ✅ Local only |
| atlas-onboarding | Validates all | ✅ Reports status |
| atlas-doctor | Validates all | ✅ Reports status |

## Rules for Skill Authors

1. NEVER hardcode tokens — use `$FORGEJO_TOKEN`, `$SYNAPSE_TOKEN` from env
2. SessionStart hook exports tokens — they're available in the CC session
3. For scripts/hooks that run in subprocess: `source require-secrets.sh TOKEN_NAME`
4. ALWAYS degrade gracefully if token missing — warn, don't crash
5. Admin-only skills can assume tokens are available (admin = full setup)
6. User-tier skills MUST work without any tokens (read-only, local only)

## Vaultwarden Provider Flow (Admin)

```
First session:
  ! eval $(scripts/bw-login.sh)
  → password + 2FA → BW_SESSION cached in keyring (8h)

Subsequent sessions (automatic):
  SessionStart → reads BW_SESSION from keyring
  → auto-resolves FORGEJO_TOKEN + SYNAPSE_TOKEN via bw
  → exports to session env
  → no user interaction needed

After 8h (keyring expires):
  SessionStart → shows 🔐 VAULT LOCKED badge
  → user runs ! eval $(scripts/bw-login.sh) again
```

## Env Provider Flow (Dev/User, no Vaultwarden)

```
User adds to ~/.env:
  export FORGEJO_TOKEN=xxx
  export SYNAPSE_TOKEN=xxx

SessionStart → sources ~/.env → exports tokens
No keyring, no bw CLI needed.
```
