# ATLAS Developer Onboarding

> Get a new developer up and running with Claude Code + ATLAS in < 30 minutes.
>
> Updated: 2026-04-10

---

## Quick Start (Admin)

Run the onboarding script to create all accesses:

```bash
# Requires: gh CLI authenticated + FORGEJO_TOKEN set
./scripts/admin/onboard-developer.sh <github-username> <forgejo-username> <email>
```

This script:
1. Invites the developer as GitHub collaborator on all shared repos
2. Adds them to the Forgejo `axoiq` org with write access
3. Generates an onboarding message to send them

---

## Quick Start (New Developer — Windows)

### Option A: Automated Setup

```powershell
# 1. Clone deploy scripts (ask admin for GitHub access first)
git clone https://github.com/seb155/claude-deploy-scripts.git
cd claude-deploy-scripts

# 2. Run setup (replace with your GitHub token)
.\windows\setup-developer.ps1 -GitHubToken "ghp_your_token_here"
```

### Option B: Manual Setup

#### Prerequisites

| Tool | Install |
|------|---------|
| Git for Windows | `winget install Git.Git` |
| Claude Code | `irm https://claude.ai/install.ps1 \| iex` |
| Python 3.13 | `winget install Python.Python.3.13` (check "Add to PATH") |

#### Steps

1. **Create GitHub Token**
   - Go to [github.com/settings/tokens](https://github.com/settings/tokens)
   - Create a **Fine-grained token** with:
     - Repository access: `seb155/atlas-plugin`
     - Permissions: `Contents: Read-only`

2. **Set Token**
   ```powershell
   [Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "ghp_xxx", "User")
   ```

3. **Configure Git Bash** (for Claude Code hooks)
   ```powershell
   # Add to %USERPROFILE%\.claude\settings.json:
   # { "env": { "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe" } }
   ```

4. **Install ATLAS Plugin**
   ```
   claude
   /plugin marketplace add seb155/atlas-plugin
   /plugin install atlas-admin@atlas-admin-marketplace
   # Exit and restart Claude Code
   ```

5. **Verify**
   ```
   # You should see:
   🏛️ ATLAS v4.x.x online | hostname
   72 skills | 15 agents | Quality gate 16/20
   ```

6. **Clone Repos** (for contributing)
   ```bash
   mkdir ~/atlas-dev && cd ~/atlas-dev
   git clone https://github.com/seb155/atlas-plugin.git
   git clone https://github.com/seb155/gms-cowork-plugins.git
   git clone https://github.com/seb155/genie-framework.git
   ```

---

## Contributing Workflow

```
                    ┌─────────────┐
                    │  Developer   │
                    │  (Windows)   │
                    └──────┬──────┘
                           │ git push
                           ▼
                    ┌─────────────┐     GitHub Action     ┌─────────────┐
                    │   GitHub     │ ──────────────────→   │   Forgejo    │
                    │  (private)   │     sync-to-forgejo   │  (primary)   │
                    │              │ ←────────────────── │              │
                    └─────────────┘     publish.yaml      └─────────────┘
                                        (on tag push)           │
                                                                │ CI
                                                                ▼
                                                        ┌─────────────┐
                                                        │  Build +    │
                                                        │  Publish    │
                                                        └─────────────┘
```

### Branch Convention

- `feature/*` — development branches
- `main` — stable, deployed
- Push to GitHub → auto-mirrors to Forgejo → CI runs on Forgejo

### Version Bump (maintainers only)

```bash
cd atlas-plugin
./scripts/publish.sh patch   # or: minor, major
# Bumps VERSION, builds, commits, tags, pushes to both remotes
```

---

## Shared Repos

| Repo | GitHub | Purpose | Access |
|------|--------|---------|--------|
| **atlas-plugin** | `seb155/atlas-plugin` | ATLAS plugin (72 skills) | All devs |
| **gms-cowork-plugins** | `seb155/gms-cowork-plugins` | GMS discipline plugins | GMS team |
| **genie-framework** | `seb155/genie-framework` | GEnie I&C/OT framework | GMS team |
| **claude-deploy-scripts** | `seb155/claude-deploy-scripts` | Deploy/setup scripts | 🔒 Restricted |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `claude` not found after install | Restart terminal, check PATH |
| Plugin install fails | Check `GITHUB_TOKEN` is set, repo is accessible |
| Hooks error "bash not found" | Set `CLAUDE_CODE_GIT_BASH_PATH` in settings.json |
| "Permission denied" on clone | Accept the GitHub collaborator invite in your email |
| No ATLAS banner after restart | Run `/plugin list` to verify plugin is installed |
| Mirror not syncing | Check GitHub Secrets: `FORGEJO_TOKEN`, `CF_ACCESS_CLIENT_ID/SECRET` |
