# Migration Guide — `make dev` → `npm install` (v5.28.0+)

For existing ATLAS users on the `make dev` workflow who want to migrate to NPM install.

## Who This Is For

You currently use ATLAS via:
```bash
cd ~/workspace_atlas/projects/atlas-dev-plugin
make dev           # copies bash files to ~/.atlas/shell/
source ~/.zshrc    # picks up atlas() function
```

## Why Migrate

| `make dev` (old) | `npm install -g` (new) |
|------------------|------------------------|
| Requires clone of `atlas-dev-plugin` repo | Standalone install |
| Manual `make dev` for updates | `npm update -g` |
| No version pinning | Semver: `@5.28.0`, `@latest` |
| No auto-update notifications | npm outdated detection |
| Source repo = ~50MB | Package = <100KB |

Both paths remain supported during transition (2+ releases). Migrate when convenient.

## Migration Steps

### 1. Backup existing customizations

```bash
# Back up any custom profiles you created
cp -r ~/.atlas/profiles/ ~/atlas-profiles-backup/
cp -r ~/.atlas/mcp-profiles/ ~/atlas-mcp-profiles-backup/
cp ~/.atlas/config.json ~/atlas-config-backup.json 2>/dev/null
```

### 2. Install via NPM

```bash
# Configure .npmrc (see INSTALL.md for PAT instructions)
cat >> ~/.npmrc <<'EOF'
@axoiq:registry=https://forgejo.axoiq.com/api/packages/axoiq/npm/
//forgejo.axoiq.com/api/packages/axoiq/npm/:_authToken=<your-forgejo-pat>
EOF

npm install -g @axoiq/atlas-cli
```

**What happens**: postinstall.js copies files to `~/.atlas/shell/`. Since `~/.atlas/profiles/` already exists (from your old install), **your customizations are preserved**.

### 3. Verify

```bash
source ~/.zshrc
atlas --version                    # Should show v5.28.0
atlas profile list                 # Your custom profiles still listed
```

### 4. (Optional) Remove source repo

Keep `atlas-dev-plugin/` clone only if you contribute to ATLAS dev. Otherwise:

```bash
# Safe to remove — you're now using npm-installed version
rm -rf ~/workspace_atlas/projects/atlas-dev-plugin
```

**Caution**: If you have uncommitted changes in the repo, commit or push first.

## Rollback

If npm version has issues, rollback to source:

```bash
# Remove npm install
npm uninstall -g @axoiq/atlas-cli

# Re-clone + make dev
git clone https://forgejo.axoiq.com/axoiq/atlas-plugin.git ~/workspace_atlas/projects/atlas-dev-plugin
cd ~/workspace_atlas/projects/atlas-dev-plugin
make dev
source ~/.zshrc
```

Your profiles (`~/.atlas/profiles/`) are untouched by either install method.

## Compatibility Matrix

| Feature | make dev | npm install | Notes |
|---------|----------|-------------|-------|
| `atlas profile ...` | ✅ | ✅ | Same profile files |
| Auto-detect (cwd/git/wifi/time) | ✅ | ✅ | Same overlays |
| MCP wrapper | ✅ | ✅ | Same |
| Custom profile files | ✅ preserved | ✅ preserved | `~/.atlas/profiles/` untouched |
| Hot-reload on source change | ✅ `make dev` | ❌ requires `npm update` | Tradeoff for sovereignty |
| Contribute patches | ✅ edit source | ❌ install read-only | Use clone for dev |

## Contributing After Migration

If you want to contribute patches back:

```bash
# Keep a separate dev clone
git clone https://forgejo.axoiq.com/axoiq/atlas-plugin.git ~/dev/atlas-plugin
cd ~/dev/atlas-plugin
git checkout -b feature/my-fix

# Make changes, test locally via make dev:
make dev                           # Installs dev version to ~/.atlas/shell/
# (this overwrites npm-installed files — run `npm install -g @axoiq/atlas-cli` to revert)

# Commit + PR
git add . && git commit -m "fix: my fix"
git push origin feature/my-fix
```

After PR merges + new npm publish, your contribution ships via normal `npm update -g`.

## Common Questions

### Q: Will my shell break during migration?
No — both installs place files at the same path (`~/.atlas/shell/`). Migration is transparent.

### Q: What if I have custom modules?
If you added `.sh` files to `~/.atlas/shell/modules/`, npm install will overwrite standard ones but preserve custom names. Back them up first.

### Q: Can I use both workflows simultaneously?
Not recommended — they'll conflict on which version of `atlas.sh` is installed. Pick one.

### Q: Does this affect my Claude Code plugin install?
No — the ATLAS CLI (shell launcher) is separate from the ATLAS plugin (Claude Code skills). Plugin is installed via `/plugin install` or `plugins.axoiq.com` and unchanged.

## See Also

- [INSTALL.md](./INSTALL.md) — full install guide
- [PROFILE-SYSTEM.md](./PROFILE-SYSTEM.md) — profile architecture
- [CLAUDE-CODE-SETUP.md](./CLAUDE-CODE-SETUP.md) — Claude Code itself
