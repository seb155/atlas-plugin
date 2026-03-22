# ATLAS Plugin Integration Map

> How the plugin connects to the AXOIQ ecosystem. Each integration point
> documents the protocol, credentials, and which skills use it.

---

## Integration Overview

```
                    ┌──────────────┐
                    │ ATLAS Plugin │
                    │  (CC plugin) │
                    └──────┬───────┘
           ┌───────┬───────┼───────┬───────┬───────┐
           │       │       │       │       │       │
      ┌────▼──┐ ┌──▼───┐ ┌▼────┐ ┌▼─────┐ ┌▼────┐ ┌▼──────┐
      │Synapse│ │Forgej│ │Vault│ │ IaC  │ │ Hub │ │Config │
      │  API  │ │  o   │ │ward │ │Platfm│ │     │ │Preset │
      └───────┘ └──────┘ └─────┘ └──────┘ └─────┘ └───────┘
```

---

## 1. ATLAS → Synapse Platform

| Aspect | Detail |
|--------|--------|
| Protocol | REST API (FastAPI) |
| Base URL | Config preset (`~/.atlas/config.json`) |
| Auth | `SYNAPSE_TOKEN` (Vaultwarden or env) |
| Skills | engineering-ops, enterprise-audit, feature-board, knowledge-manager |

**Touchpoints**:
- `engineering-ops` reads project data, instruments, estimation
- `enterprise-audit` checks multi-tenant safety, auth, observability
- `feature-board` reads FEATURES.md + validation matrix
- `knowledge-manager` queries RAG pipeline (ParadeDB BM25 + pgvector)

**Rule**: Plugin NEVER directly calls Synapse API with hardcoded URLs.
All endpoints come from config preset.

---

## 2. ATLAS → Forgejo

| Aspect | Detail |
|--------|--------|
| Protocol | REST API v1 + Git SSH |
| Base URL | `http://192.168.10.75:3000/api/v1` (internal) |
| Auth | `FORGEJO_TOKEN` (Vaultwarden or env) |
| Skills | finishing-branch, git-worktrees, code-review |

**Touchpoints**:
- `finishing-branch` creates PRs, pushes branches, reads CI status
- `git-worktrees` creates isolated worktrees with Forgejo branch naming
- `code-review` reads PR diffs, posts review comments
- CI pipeline (`.forgejo/workflows/`) runs on push/PR

**Rule**: External access blocked by Cloudflare. Use internal IP only.

---

## 3. ATLAS → Vaultwarden

| Aspect | Detail |
|--------|--------|
| Protocol | Bitwarden CLI (`bw`) |
| Collections | Shared, Project-specific, Admin, Per-Developer |
| Auth | Master password → keyring (auto-unlock) |
| Skills | atlas-vault, atlas-doctor, atlas-onboarding |
| Script | `scripts/get-secret.sh`, `scripts/bw-login.sh`, `scripts/atlas-keyring.sh` |

**Secret Resolution Chain** (4-tier):
```
1. Environment variable ($SECRET_NAME)
   ↓ not found
2. Keyring (keyctl on Linux, Python keyring on macOS)
   ↓ not found
3. Vaultwarden lookup (bw get password "name")
   ↓ not found
4. Prompt user
```

**Rule**: NEVER hardcode secrets. Use `get-secret.sh` or `require-secrets.sh`.

---

## 4. ATLAS → IaC Developer Platform

| Aspect | Detail |
|--------|--------|
| Protocol | SSH + REST API (Authentik, Coder) |
| Mesh | NetBird VPN (OIDC group sync) |
| Skills | infrastructure-ops, devops-deploy, security-audit |

**Touchpoints**:
- `infrastructure-ops` manages VMs (Proxmox), containers (Docker/LXC), DNS
- `devops-deploy` orchestrates staging/prod deployments via SSH
- `security-audit` audits RBAC (Authentik), VPN (NetBird), SSL/TLS

---

## 5. ATLAS → Enterprise Hub

| Aspect | Detail |
|--------|--------|
| Protocol | REST API (same FastAPI backend as Synapse) |
| Skills | enterprise-audit, document-generator, knowledge-manager |

**Touchpoints**:
- Meeting Copilot integration (Recall.ai, WhisperX)
- Programme management (lessons learned, KPIs)
- Knowledge graph cross-references

---

## 6. ATLAS → Config Preset System

| Aspect | Detail |
|--------|--------|
| Location | `~/.atlas/config.json` |
| Presets | `scripts/presets/*.json` |
| Default | AXOIQ preset (reference implementation) |

**How presets work**:
```json
{
  "preset": "axoiq",
  "synapse_url": "https://synapse.home.axoiq.com",
  "forgejo_url": "http://192.168.10.75:3000",
  "vault_url": "https://vault.axoiq.com"
}
```

**New company** = new preset JSON file. Zero code changes.

---

## Token Summary

| Token | Source | Used By | Stored In |
|-------|--------|---------|-----------|
| `FORGEJO_TOKEN` | Forgejo → Settings → Applications | finishing-branch, git-worktrees, code-review | Vaultwarden "Shared" |
| `SYNAPSE_TOKEN` | Synapse Admin → API Keys | engineering-ops, enterprise-audit | Vaultwarden "Project" |
| `ANTHROPIC_API_KEY` | Anthropic Console | deep-research, experiment-loop | Vaultwarden "Shared" |

**Rule**: `source ~/.env` loads tokens for local dev. CI uses Forgejo secrets.

---

*Updated: 2026-03-22 | Maintain when: new integration point added or credentials change*
