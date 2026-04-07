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
