# ATLAS — AXOIQ's Unified AI Engineering Assistant

ATLAS is a multi-tier **Claude Code plugin** + standalone **shell CLI launcher** that
replaces dozens of individual plugins with one auto-routing co-pilot. It detects context
at session start and routes to the appropriate skill — with HITL gates at every strategic
decision point.

**v5.28.0** | 131 skills | 24 agents | 41+ hook handlers | 6 domain scopes | profile-first CLI

## 🎯 Two Distribution Channels

| Channel | What | How to install |
|---------|------|----------------|
| **ATLAS Plugin** (Claude Code skills + agents + hooks) | `atlas-core`, `atlas-dev-addon`, `atlas-admin-addon` via Claude Code marketplace | `/plugin install atlas-core@atlas-marketplace` (see External Install below) |
| **ATLAS CLI** (shell launcher, profile-first) | `@axoiq/atlas-cli` npm package on Forgejo | `npm install -g @axoiq/atlas-cli` (see CLI Install below) |

Both ship from this single repo. Released together via `scripts/publish.sh minor`.

---

## 🚀 ATLAS CLI (v5.28.0+ — profile-first launcher)

Shell launcher for Claude Code with **profile-first architecture** and **auto-context detection**.

### CLI Install

```bash
# 1. Configure ~/.npmrc once (Forgejo registry + PAT)
cat >> ~/.npmrc <<'EOF'
@axoiq:registry=https://forgejo.axoiq.com/api/packages/axoiq/npm/
//forgejo.axoiq.com/api/packages/axoiq/npm/:_authToken=<your-forgejo-pat>
EOF
chmod 600 ~/.npmrc

# 2. Install
npm install -g @axoiq/atlas-cli

# 3. Enable in shell
echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> ~/.zshrc
echo 'export ATLAS_AUTO_DETECT_PROFILE=true' >> ~/.zshrc
source ~/.zshrc

# 4. Verify
atlas --version       # ATLAS CLI v5.28.0 | Plugin v5.28.0 | CC v2.1.114
atlas profile list    # tabular list of 5 seed profiles
```

### CLI Commands

```bash
# Profile management
atlas profile list                          # tabular view
atlas profile show dev-synapse              # YAML dump
atlas profile create my-feat --from base    # copy template
atlas profile validate my-feat              # schema check

# Profile-driven launch
atlas --profile dev-synapse synapse         # explicit profile
atlas synapse                               # auto-detect (if enabled)
atlas synapse --override effort=max         # composable override

# Debug / dry-run
atlas --detect-only                         # resolve profile + print + exit
atlas synapse --print-command               # show built claude cmd + exit

# Session resume
atlas resume                                # continue last
atlas resume --picker                       # native CC picker (cross-project)
atlas resume --last                         # explicit last

# Fork session (for feature branches)
atlas synapse --fork-session                # force new session ID
atlas synapse --no-fork-session             # override profile auto

# MCP server wrapper
atlas mcp list                              # formatted list
atlas mcp doctor                            # health summary (✅/⚠️/❌ counts)
atlas mcp profile chrome-playwright         # show MCP bundle YAML
atlas mcp add context7 https://mcp.context7.com/mcp   # passthrough claude mcp add
```

### Profile System

Profiles (`~/.atlas/profiles/*.yaml`) bundle Claude Code launch config:

- **tier** (`core`/`dev`/`admin`/`none`) — which ATLAS plugin tier to load
- **permission_mode** (`default`/`plan`/`auto`/`dontAsk`/...) — prompt behavior
- **effort** (`low`/`medium`/`high`/`xhigh`/`max`) — reasoning depth
- **worktree**, **fork_session**, **bare** — session isolation flags
- **mcp_profile** — refs MCP bundle from `~/.atlas/mcp-profiles/`
- **env** — environment variables for the session

**Inheritance**: `extends: base` chains (max depth 3) for DRY configs.

**Auto-detection** (with `ATLAS_AUTO_DETECT_PROFILE=true`):
1. `.atlas/project.json` manifest in cwd/parent dirs
2. `cwd_match` glob patterns in profile YAML
3. Contextual overlays: git branch hooks, WiFi trust, time-based

5 seed profiles ship with the CLI: `base`, `dev-synapse`, `admin-infra`, `research`, `home`.

📖 Full schema docs: [`docs/PROFILE-SYSTEM.md`](./docs/PROFILE-SYSTEM.md)

---

## 🧩 ATLAS Plugin (Claude Code skills)

```
profiles/*.yaml       build.sh        dist/atlas-{tier}/       ~/.claude/plugins/cache/
  (tier defs)    -->  (resolve +  -->  (self-contained)    -->  (installed in CC)
                       generate)
```

**Build modes**:
- **3-Tier** (legacy): `user` → `dev` → `admin`
- **Modular** (current, canonical): `atlas-core` + `atlas-dev-addon` + `atlas-admin-addon`

Each `dist/` artifact is self-contained — no runtime inheritance or external deps.

### Skill Routing

Every tier gets a generated `atlas-assist` master skill that:
1. Lists all available skills with emoji + category + description
2. Auto-routes user intent to the correct sub-skill
3. Defines the tier persona and pipeline stages

### Hook Lifecycle

`hooks/hooks.json` is the SSoT. Events flow: `CC event → hooks.json matcher → hook script → branded output`.
Key events: `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `PreCompact`, `Stop`.
All hooks output with `ATLAS` branded prefix. Scripts have NO `.sh` extension.

---

## 🛠️ Dev Quick Start

```bash
# Build + install plugin + CLI to ~/.atlas/ (standard dev workflow)
make dev

# Build modular plugins (core + addons)
./build.sh modular

# Run tests (always -x --tb=short)
make test

# Release (minor bump → build → test → commit → tag → push → npm publish)
./scripts/publish.sh minor
```

### Publish Workflow (v5.28.0+)

`scripts/publish.sh` is the release SSoT. On merge to `main`:

1. `VERSION` file + `package.json` bumped
2. `./build.sh modular` rebuilds `dist/atlas-{core,dev-addon,admin-addon}/`
3. `pytest tests/ -x -q --tb=short` runs (manual release if legacy test failures)
4. Commit + tag `vX.Y.Z`
5. Push to Forgejo + GitHub mirror
6. **NPM publish** to Forgejo Packages (`@axoiq/atlas-cli`) — Step 7 added in v5.28.0

**Note**: Forgejo CI (`atlas-ci` bot) also auto-releases on merge to `main`. There's a known race — CI usually wins, so `publish.sh` is most useful for `--dry-run` preview and emergency out-of-band releases. See `memory/lesson_publish_sh_ci_coordination.md`.

---

## 🌐 External Install — Claude Code Plugin (via plugins.axoiq.com)

The ATLAS plugin marketplace is accessible via the **canonical URL**
`https://plugins.axoiq.com` — one URL works from **both** internal LAN and external
internet, with **zero credentials** required.

```bash
/plugin marketplace add https://plugins.axoiq.com
/plugin install atlas-core@atlas-marketplace         # required base (28 skills)
/plugin install atlas-dev-addon@atlas-marketplace    # optional dev (36 skills, 7 agents)
/plugin install atlas-admin-addon@atlas-marketplace  # optional admin (67 skills, 16 agents)
```

### How it works

`plugins.axoiq.com` is a public Caddy gateway in front of the private Forgejo SSoT:

```
External user                       Internal dev
      v                                  v
Cloudflare Edge                     LAN DNS (Technitium)
      v                                  v
CF Tunnel (Homelab_Prod_01)        ──────┬
      v                                  v
      └───────► Caddy LXC 103 (192.168.5.103)
                (plugins.axoiq.com block)
                      v
                dual behavior:
                  - GET / or /marketplace.json → proxy to Forgejo API raw
                  - git operations → rewrite + proxy to /axoiq/atlas-plugin.git
                      v
                header_up Authorization "token {env.FORGEJO_PROXY_TOKEN}"
                      v  (readonly scope: read:repository)
                Forgejo LXC (192.168.10.75:3000)
```

**Key design notes**:
- Readonly Forgejo PAT injected by Caddy — users don't need Forgejo credentials
- Token stored in `/etc/caddy/.env` (chmod 600 root)
- GitHub mirror at `github.com/seb155/atlas-plugin` kept as backup (sync_on_commit)

---

## 📂 Directory Structure

```
atlas-dev-plugin/
  package.json                     # NPM manifest — @axoiq/atlas-cli (v5.28.0+)
  VERSION                          # Semver SSoT (propagated to all manifests)
  CHANGELOG.md                     # Release history
  profiles/                        # Legacy 3-tier YAMLs (admin/dev/user)
  skills/                          # 131 skill dirs across core/dev/admin
    refs/                          # Reference skills (bundled docs)
  agents/                          # 24 agent dirs (model, tools, constraints)
  hooks/                           # hooks.json SSoT + 41+ executable handlers
  scripts/
    atlas-cli.sh                   # Shell launcher (43-line loader, sourced by zshrc/bashrc)
    atlas-modules/                 # 13 CLI modules (platform, launcher, subcommands, ...)
    postinstall.js                 # NPM postinstall hook (copies bash → ~/.atlas/)
    preuninstall.js                # NPM preuninstall hook (preserves user data)
    publish.sh                     # Release pipeline (P6.3 extended with npm publish)
    presets/                       # Safety policy JSON presets
  templates/                       # Seeds copied by postinstall.js
    profiles/                      # 5 launch profiles (base, dev-synapse, admin-infra, research, home)
    mcp-profiles/                  # 2 MCP bundles (chrome-playwright, minimal)
  docs/                            # User-facing documentation
    INSTALL.md                     # NPM install + .npmrc config
    MIGRATION-GUIDE.md             # make dev → npm install -g transition
    CLAUDE-CODE-SETUP.md           # Claude Code install + doctor + MCP reference
    PROFILE-SYSTEM.md              # Profile schema + inheritance + overlays
    ADR/
      ADR-004-profile-first-architecture.md
      ADR-005-distribution-sovereignty.md
  build.sh                         # Main builder (modular + legacy)
  Makefile                         # Dev workflow: dev, test, lint, publish-patch
  .blueprint/                      # Deep architecture docs
  tests/                           # 17 pytest files (frontmatter, coverage, hooks, build)
```

## ✏️ Creating a New Skill

1. Create `skills/{name}/SKILL.md` with YAML frontmatter (`name`, `description`, `effort`)
2. Add to appropriate `profiles/{tier}.yaml` under `skills:`
3. Update `scripts/generate-master-skill.sh` maps: `EMOJI_MAP`, `DESC_MAP`, `CATEGORY_MAP`
4. `make test` — validates frontmatter, profile coverage, cross-refs
5. `make dev` — builds + installs to CC for live testing

## 🔁 CI/CD

| Trigger | Action |
|---------|--------|
| Push/PR | `make test` via Forgejo Actions |
| Merge to `main` | `atlas-ci` bot: VERSION bump + build + commit + tag + push |
| Tag `v*` | GitHub mirror sync + marketplace serves new version |

## 📚 Documentation

### User-facing (`docs/`)
| Doc | Purpose |
|-----|---------|
| **`INSTALL.md`** | **NPM install + .npmrc config + troubleshooting** |
| `MIGRATION-GUIDE.md` | `make dev` → `npm install -g` transition |
| `CLAUDE-CODE-SETUP.md` | Claude Code install + doctor + MCP management |
| `PROFILE-SYSTEM.md` | Profile schema + inheritance + overlays + resolution order |
| `ADR/ADR-004-*.md` | Profile-first architecture decision |
| `ADR/ADR-005-*.md` | Distribution sovereignty (Forgejo NPM) decision |

### Architecture (`.blueprint/`)
| Doc | Purpose |
|-----|---------|
| `ARCHITECTURE.md` | Build pipeline, inheritance, hooks |
| `SKILL-CATALOG.md` | Full skill inventory with categories |
| `PATTERNS.md` | Copy-paste patterns for common tasks |

### Meta
| Doc | Purpose |
|-----|---------|
| `CLAUDE.md` | AI context (loaded by Claude Code sessions) |
| `DEPLOYMENT.md` | Step-by-step install guide for any platform |
| `ONBOARDING.md` | New contributor guide |
| `PARALLELISM.md` | Parallelism safety rules |
| `CHANGELOG.md` | Release history |

## 🔒 License

UNLICENSED — Private use only. AXOIQ property.
