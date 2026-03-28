# Phase 2: 🔑 Credentials

Check each token via bash, then present results:

```bash
# Config helper — read from ~/.atlas/config.json with fallback
atlas_config() {
  local key="$1" fallback="${2:-}"
  python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.atlas/config.json')) as f:
        d = json.load(f)
    keys = '$key'.split('.')
    v = d
    for k in keys: v = v[k]
    if isinstance(v, list): print(' '.join(v))
    else: print(v)
except: print('$fallback')
" 2>/dev/null || echo "$fallback"
}

# Check existence + API validity
SYNAPSE_URL=$(atlas_config "services.synapse.url" "http://localhost:8001")
SYNAPSE_OK="❌"
[ -n "${SYNAPSE_TOKEN:-}" ] && curl -sf -m 3 -H "Authorization: Bearer $SYNAPSE_TOKEN" "${SYNAPSE_URL}/api/v1/health" >/dev/null 2>&1 && SYNAPSE_OK="✅"

FORGEJO_OK="❌"
FORGEJO_URL=$(atlas_config "services.forgejo.local_url" "")
FORGEJO_API_PATH=$(atlas_config "services.forgejo.api_path" "/api/v1")
[ -n "${FORGEJO_TOKEN:-}" ] && [ -n "$FORGEJO_URL" ] && \
  curl -sf -m 3 -H "Authorization: token $FORGEJO_TOKEN" "${FORGEJO_URL}${FORGEJO_API_PATH}/user" >/dev/null 2>&1 && FORGEJO_OK="✅"

AUTHENTIK_OK="⏭️ optional"
AUTHENTIK_URL_CFG=$(atlas_config "services.authentik.url" "")
[ -n "${AUTHENTIK_TOKEN:-}" ] && [ -n "$AUTHENTIK_URL_CFG" ] && \
  curl -sf -m 3 -H "Authorization: Bearer $AUTHENTIK_TOKEN" "${AUTHENTIK_URL:-$AUTHENTIK_URL_CFG}/api/v3/core/users/me/" >/dev/null 2>&1 && AUTHENTIK_OK="✅"

GEMINI_OK="❌"
[ -n "${GEMINI_API_KEY:-}" ] && GEMINI_OK="✅"
```

Present as table:
```
| Token          | Status | Purpose                              |
|----------------|--------|--------------------------------------|
| SYNAPSE_TOKEN  | {status} | Backend API (profile, knowledge, notes) |
| FORGEJO_TOKEN  | {status} | Git hosting (PRs, CI, deploy)          |
| AUTHENTIK_TOKEN| {status} | SSO role detection (optional)          |
| GEMINI_API_KEY | {status} | AI model access (optional)             |
```

For each ❌ token:
1. Explain what it's for and why it matters
2. Show generation instructions:
   - SYNAPSE_TOKEN: "In Synapse → Admin → API Tokens → Create"
   - FORGEJO_TOKEN: "In Forgejo → Settings → Applications → Generate Token"
   - AUTHENTIK_TOKEN: "In Authentik → Admin → Tokens → Create API Token"
3. Ask user: "Add to ~/.env: `export TOKEN_NAME=xxx` then `source ~/.env`"
4. NEVER store the token value — only validate and record true/false

Update `~/.atlas/profile.json` credentials section.
