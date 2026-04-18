# Installing ATLAS CLI (v5.28.0+)

ATLAS CLI distributes via NPM on Forgejo Packages (sovereignty-first).

## Prerequisites

- **Node.js ≥ 18** (for `npm install` + postinstall hook)
- **Bash 4+** (module sourcing uses associative arrays, globstar)
- **Optional**: `yq` v4+ (recommended for profile validation), `nmcli` (for WiFi overlay), `git` (for branch overlay)
- **Forgejo PAT** with `read_package` scope for private install

## Quick Install (one-liner)

```bash
# 1. Configure .npmrc once (AXOIQ Forgejo registry)
cat >> ~/.npmrc <<'EOF'
@axoiq:registry=https://forgejo.axoiq.com/api/packages/axoiq/npm/
//forgejo.axoiq.com/api/packages/axoiq/npm/:_authToken=<your-forgejo-pat>
EOF

# 2. Install
npm install -g @axoiq/atlas-cli

# 3. Enable in shell
echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> ~/.zshrc
echo 'export ATLAS_AUTO_DETECT_PROFILE=true' >> ~/.zshrc
source ~/.zshrc

# 4. Verify
atlas profile list
```

## Getting a Forgejo PAT

1. Login to [forgejo.axoiq.com](https://forgejo.axoiq.com)
2. Settings → Applications → Generate New Token
3. Scopes: `read_package` (minimum for install), add `write_package` if publishing
4. Copy token, paste in `~/.npmrc` as shown above

**Security**: Keep `.npmrc` with mode 600 (`chmod 600 ~/.npmrc`). Rotate token every 90 days.

## What Gets Installed

After `npm install -g @axoiq/atlas-cli`:

| Path | Contents |
|------|----------|
| `~/.atlas/shell/atlas.sh` | Main launcher (sourced by shell) |
| `~/.atlas/shell/modules/*.sh` | 12 CLI modules (platform, launcher, subcommands, etc.) |
| `~/.atlas/profiles/*.yaml` | 5 seed launch profiles (base, dev-synapse, admin-infra, research, home) |
| `~/.atlas/mcp-profiles/*.yaml` | 2 MCP profile bundles (chrome-playwright, minimal) |

Seed profiles installed only if `~/.atlas/profiles/` is empty. User customizations always preserved.

## Verifying Install

```bash
atlas --version                    # Should print 5.28.0 (or current version)
atlas profile list                 # 5 profiles tabular
atlas --detect-only                # From a project dir, auto-detects profile
atlas mcp doctor                   # MCP health check
```

## Troubleshooting

### `npm ERR! 401 Unauthorized`
Your Forgejo PAT is missing/expired. Regenerate and update `~/.npmrc`.

### `atlas: command not found`
Shell hasn't sourced the launcher. Check `~/.zshrc` has the source line, then run `source ~/.zshrc`.

### `yq: command not found`
Install yq v4+:
```bash
# Linux
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
sudo chmod +x /usr/local/bin/yq

# macOS
brew install yq
```

### Profiles not loading
- Verify files exist: `ls ~/.atlas/profiles/`
- Check yq works: `yq eval '.tier' ~/.atlas/profiles/dev-synapse.yaml`
- Re-seed: `cp -r ~/workspace_atlas/projects/atlas-dev-plugin/templates/profiles/* ~/.atlas/profiles/`

### Auto-detect not working
```bash
echo $ATLAS_AUTO_DETECT_PROFILE    # Must be "true"
# Add to shell: export ATLAS_AUTO_DETECT_PROFILE=true
```

## Updating

```bash
npm update -g @axoiq/atlas-cli     # Latest published
npm install -g @axoiq/atlas-cli@5.28.0  # Pin specific version
```

Postinstall hook re-copies bash files. Profiles preserved.

## Uninstalling

```bash
npm uninstall -g @axoiq/atlas-cli
# Optional full cleanup:
rm -rf ~/.atlas/{shell,profiles,mcp-profiles,runtime}
sed -i '/atlas.sh/d' ~/.zshrc ~/.bashrc 2>/dev/null
```

## See Also

- [CLAUDE-CODE-SETUP.md](./CLAUDE-CODE-SETUP.md) — Claude Code install + doctor + MCP
- [PROFILE-SYSTEM.md](./PROFILE-SYSTEM.md) — profile schema + inheritance + overrides
- [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md) — migrate from `make dev` workflow
