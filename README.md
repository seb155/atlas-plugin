# ATLAS -- AXOIQ's Unified AI Engineering Assistant

ATLAS is a multi-tier Claude Code plugin that replaces 18+ individual plugins with one
auto-routing co-pilot. It detects context at session start and routes to the appropriate
skill -- with HITL gates at every strategic decision point.

**v4.26.3** | 81 skills | 6 refs | 16 agents | 37 hook handlers | 6 domain scopes

## Architecture Overview

```
profiles/*.yaml       build.sh        dist/atlas-{tier}/       ~/.claude/plugins/cache/
  (tier defs)    -->  (resolve +  -->  (self-contained)    -->  (installed in CC)
                       generate)
```

**Two build modes**:
- **3-Tier** (legacy): `user` -> `dev` (inherits user) -> `admin` (inherits dev)
- **6-Domain** (current): `core`, `dev`, `frontend`, `infra`, `enterprise`, `experiential`

Each `dist/` artifact is self-contained -- no runtime inheritance or external deps.

### Skill Routing

Every tier/domain gets a generated `atlas-assist` master skill that:
1. Lists all available skills with emoji + category + description
2. Auto-routes user intent to the correct sub-skill
3. Defines the tier persona and pipeline stages

### Hook Lifecycle

`hooks/hooks.json` is the SSoT. Events flow: `CC event -> hooks.json matcher -> hook script -> branded output`.
Key events: `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `PreCompact`, `Stop`.
All hooks output with `ATLAS` branded prefix. Scripts have NO `.sh` extension.

## Quick Start

```bash
# Build + install to Claude Code (standard dev workflow)
make dev

# Build all 3 tiers
./build.sh all

# Build 6 domain plugins
./build.sh domains

# Run tests (always -x --tb=short)
make test

# Release (patch bump -> build -> test -> tag -> push)
make publish-patch
```

## External Install (Public Marketplace)

The ATLAS plugin marketplace is accessible publicly via the canonical URL
`https://plugins.axoiq.com`. Behind the scenes this is a Cloudflare Tunnel
-> Caddy reverse proxy -> Forgejo git gateway, fully public read-only.

### Install from any machine

```bash
claude plugin source add \
  --name atlas-marketplace \
  --source git \
  --url https://plugins.axoiq.com

# Then install any combination of the three plugins
claude plugin install atlas-core@atlas-marketplace     # required base
claude plugin install atlas-dev@atlas-marketplace      # optional dev tier
claude plugin install atlas-admin@atlas-marketplace    # optional admin tier
```

### Verify externally (from a WAN-only host)

```bash
# Sanity check: DNS + HTTP 200 + marketplace.json present
git ls-remote https://plugins.axoiq.com HEAD
# Expected: <SHA>  HEAD

git clone --depth=1 https://plugins.axoiq.com /tmp/atlas-mkt \
  && cat /tmp/atlas-mkt/.claude-plugin/marketplace.json | jq '.plugins[].name'
# Expected: "atlas-core", "atlas-admin", "atlas-dev"
```

### Infrastructure chain

```
VPS / external machine
      v  git clone https://plugins.axoiq.com
Cloudflare Edge  (DNS: CNAME to <tunnel-id>.cfargotunnel.com, proxied)
      v
CF Tunnel (Homelab_Prod_01)
      v  originServerName: plugins.axoiq.com, noTLSVerify: true
Caddy LXC 103 (192.168.5.103)
      v  rewrite * /axoiq/atlas-plugin.git{uri}
      v  header_up Host forgejo.axoiq.com
      v  header_up Authorization token <FORGEJO_PAT>
Forgejo (192.168.10.75:3000)
      v
Response: git packfile
```

### Publishing new versions

Releases are automated via `make publish-patch` / `make publish-minor`:

1. Bump `VERSION` file
2. Run `./build.sh modular` to regenerate `dist/`
3. Commit + tag (`v5.26.1`) + push to Forgejo (`axoiq/atlas-plugin`)
4. Forgejo CI workflow `.forgejo/workflows/sync-to-github.yaml` syncs to GitHub mirror (if configured)
5. Cloudflare route `plugins.axoiq.com` serves immediately (no caching layer, live git HTTP proxy)

### Tech-debt / follow-ups

- **Forgejo token in Caddy config**: Currently uses the owner's full-scope PAT
  because Forgejo server has `REQUIRE_SIGNIN_VIEW=true` globally. Follow-up:
  rotate to a dedicated read-only token scoped to `axoiq/atlas-plugin` only.
- **Forgejo -> GitHub auto-mirror**: Workflow exists in reverse direction
  (`.github/workflows/sync-to-forgejo.yaml`) but no automated forward mirror yet.

## Directory Structure

```
atlas-dev-plugin/
  profiles/          # 3 tier YAMLs + 5 domain YAMLs (inheritance definitions)
  skills/            # 81 skill dirs, each with SKILL.md (frontmatter + instructions)
    refs/            # 6 reference skills (bundled docs, not routable)
  agents/            # 16 agent dirs, each with AGENT.md (model, tools, constraints)
  hooks/             # hooks.json (SSoT) + 37 executable handler scripts
  scripts/           # Build, publish, CLI loader, and utilities
    atlas-cli.sh     # Shell launcher (38-line loader)
    atlas-modules/   # 7 CLI modules (dispatch, ui, completions, ...)
    presets/          # Safety policy JSON presets
  build.sh           # Main builder (tier inheritance + master skill generation)
  Makefile           # Dev workflow: dev, test, lint, publish-patch
  VERSION            # Semver SSoT (propagated to all manifests)
  .blueprint/        # Deep architecture docs (ARCHITECTURE.md, PATTERNS.md, ...)
  tests/             # 17 pytest files (frontmatter, coverage, hooks, build output)
```

## Creating a New Skill

1. Create `skills/{name}/SKILL.md` with YAML frontmatter (`name`, `description`, `effort`)
2. Add the skill name to the appropriate `profiles/{tier}.yaml` under `skills:`
3. Update `scripts/generate-master-skill.sh` maps: `EMOJI_MAP`, `DESC_MAP`, `CATEGORY_MAP`
4. Run `make test` -- validates frontmatter, profile coverage, cross-refs
5. Run `make dev` -- builds + installs to CC for live testing

## CI/CD

| Trigger | Action |
|---------|--------|
| Push/PR | `make test` via Forgejo Actions |
| Tag `v*` | Build all tiers + publish to Forgejo Package Registry |

## Documentation

| Doc | Purpose |
|-----|---------|
| **`DEPLOYMENT.md`** | **Step-by-step install guide for any platform** |
| `CLAUDE.md` | AI context (loaded by Claude Code sessions) |
| `ARCHITECTURE.md` | This-level architecture guide |
| `.blueprint/ARCHITECTURE.md` | Deep dive: build pipeline, inheritance, hooks |
| `.blueprint/SKILL-CATALOG.md` | Full skill inventory with categories |
| `.blueprint/PATTERNS.md` | Copy-paste patterns for common tasks |
| `ONBOARDING.md` | New contributor guide |
| `PARALLELISM.md` | Parallelism safety rules |

## License

UNLICENSED -- Private use only. AXOIQ property.
