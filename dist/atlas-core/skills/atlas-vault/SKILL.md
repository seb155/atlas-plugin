---
name: atlas-vault
description: "Ingest and manage user vault for personalized ATLAS behavior. Auto-detects vault repos, reads profile/rules/personality, respects sharing.json privacy boundaries. Use when 'vault', 'personal data', 'credentials', 'profile sync', or 'ingest vault'."
effort: medium
---

# ATLAS Vault Manager

Manages the connection between ATLAS and the user's private vault repo on Forgejo. The vault contains personal profile, behavior rules, personality (DAIMON), credentials index, and life matrix.

## Data Layers (CRITICAL — respect boundaries)

| Layer | Access | Content |
|-------|--------|---------|
| **Shareable** | Auto-loaded, any trust | kernel/, profile/ (per sharing.json) |
| **Private** | On-demand, trusted network only | daimon/, credentials/, matrix/holdings/ |
| **Always Private** | NEVER auto-loaded | credentials/ secrets, inbox/ |

**Rule**: NEVER copy secret values to `~/.atlas/`. Read from vault at runtime only.

## Subcommands

| Command | Action |
|---------|--------|
| `/atlas vault` | Show vault status (path, freshness, what's loaded) |
| `/atlas vault ingest` | Full re-ingestion with HITL summary |
| `/atlas vault sync` | Git pull vault + refresh session context |
| `/atlas vault init` | Scaffold new vault for current user |
| `/atlas vault path [path]` | Show or set vault path |

## Auto-Detection (SessionStart integration)

The session-start hook calls this logic automatically:

```bash
# Check for vault_path in profile
VAULT_PATH=$(python3 -c "
import json
with open('${HOME}/.atlas/profile.json') as f:
    print(json.load(f).get('vault_path', ''))
" 2>/dev/null || true)

# If no vault_path → scan workspace
if [ -z "$VAULT_PATH" ]; then
  VAULT_PATH=$(find "${ATLAS_ROOT:-$HOME/workspace_atlas}/vaults" \
    -maxdepth 1 -type d -name "*" ! -name "vaults" 2>/dev/null | head -1)
fi
```

If vault found but never ingested → inject context line:
```
🏛️ ATLAS │ 🔐 VAULT │ Found: vaults/SebG. Run /atlas vault ingest to connect.
```

If vault already linked → silent refresh of shareable data.

## Ingestion Workflow

### 1. Detect Vault
```bash
find ${ATLAS_ROOT:-$HOME/workspace_atlas}/vaults -maxdepth 1 -type d
```

### 2. Read sharing.json
```bash
SHARING=$(cat "${VAULT_PATH}/sharing.json" 2>/dev/null || echo '{"policy":"all_private"}')
```

### 3. Ingest Shareable Data

Based on sharing.json, read ONLY what's marked as shared:

```bash
# Kernel (usually shareable)
if sharing allows kernel/rules.json:
  cp "${VAULT_PATH}/kernel/rules.json" ~/.atlas/behavior-rules.json

# Profile (partial — only allowed fields)
if sharing allows profile/:
  python3 -c "
  import json
  with open('${VAULT_PATH}/profile/user-profile.json') as f: vault = json.load(f)
  with open('${HOME}/.atlas/profile.json') as f: local = json.load(f)
  # Merge allowed fields only
  allowed = sharing.get('profile/user-profile.json', [])
  for field in allowed:
    if field in vault: local['vault_' + field] = vault[field]
  local['vault_path'] = '${VAULT_PATH}'
  with open('${HOME}/.atlas/profile.json', 'w') as f: json.dump(local, f, indent=2)
  "
```

### 4. HITL Summary
Present what was ingested via AskUserQuestion:
```
"Vault ingested from vaults/SebG:
 ✅ kernel/rules.json → behavior modes (engineer/architect/normal)
 ✅ kernel/manifest.json → ecosystem awareness
 ✅ profile/ → expertise, preferences (partial per sharing.json)
 🔒 daimon/ → available on-demand (trusted network only)
 🔒 credentials/ → referenced, not copied
 🔒 matrix/ → available on-demand"
```

## Vault Scaffold (/atlas vault init)

For new users without a vault:

```bash
VAULT_DIR="${ATLAS_ROOT}/vaults/${USERNAME}"
mkdir -p "${VAULT_DIR}"/{profile,kernel,credentials,daimon,matrix/{goals,domains,inventory}}
```

Generate template files:
- `sharing.json` — default all private
- `profile/user-profile.json` — empty template
- `kernel/manifest.json` — minimal config
- `kernel/rules.json` — default behavior rules
- `daimon/${username}.daimon.md` — empty personality template
- `README.md` — vault usage guide

HITL: "Push to Forgejo as private repo?"
```bash
cd "${VAULT_DIR}" && git init && git add -A
git commit -m "feat: initial vault scaffold"
# Create private repo on Forgejo via API
curl -sf -X POST "${FORGEJO_URL}/api/v1/user/repos" \
  -H "Authorization: token $FORGEJO_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"vault-'${USERNAME}'","private":true}'
git remote add origin "${FORGEJO_URL}/${USERNAME}/vault-${USERNAME}.git"
git push -u origin main
```

## Trust-Based Access

| Operation | Trusted | Standard | Restricted |
|-----------|---------|----------|------------|
| Read shareable | ✅ auto | ✅ auto | ✅ auto |
| Read daimon | ✅ on-demand | ❌ | ❌ |
| Read credentials index | ✅ on-demand | ❌ | ❌ |
| Read matrix/holdings | ✅ on-demand | ❌ | ❌ |
| Write to vault | ✅ with HITL | ❌ | ❌ |
| Git push vault | ✅ with HITL | ❌ | ❌ |
