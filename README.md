# ATLAS — AXOIQ's Unified AI Engineering Assistant

ATLAS is AXOIQ's unified Claude Code plugin that replaces 18 individual plugins, 10 global commands,
and 26 skills with a single auto-routing co-pilot. It activates at session start, detects context,
and routes to the appropriate workflow — with HITL gates at every strategic decision point.

## Tiers

ATLAS ships as three tiers, each inheriting from the one below it.

| Feature | User | Dev | Admin |
|---------|:----:|:---:|:-----:|
| Personal assistant (notes, brief, research) | ✓ | ✓ | ✓ |
| Browser automation | ✓ | ✓ | ✓ |
| Document generation (PPTX/DOCX/XLSX) | ✓ | ✓ | ✓ |
| TDD pipeline | | ✓ | ✓ |
| Code review & simplify | | ✓ | ✓ |
| Plan builder (15-section, quality gate 12/15) | | ✓ | ✓ |
| Git worktrees | | ✓ | ✓ |
| Subagent dispatch | | ✓ | ✓ |
| Engineering ops & estimation | | ✓ | ✓ |
| Deploy to any environment | | | ✓ |
| Infrastructure ops | | | ✓ |
| Security audit | | | ✓ |
| Autonomous optimization (`/atlas tune`) | | | ✓ |
| **Skills** | 10 | ~25 | ~29 |
| **Agents** | 1 | 5 | 5 |
| **Commands** | 10 | ~18 | ~22 |

## Installation

### From Forgejo Package Registry

```bash
# Install a specific tier (replace {tier} with admin, dev, or user)
VERSION=$(curl -s https://forgejo.axoiq.com/api/packages/atlas/generic/atlas-{tier}/index.json | jq -r '.versions[0]')
curl -L "https://forgejo.axoiq.com/api/packages/atlas/generic/atlas-{tier}/${VERSION}/atlas-{tier}-${VERSION}.tar.gz" \
  -o atlas-{tier}.tar.gz
tar -xzf atlas-{tier}.tar.gz
claude plugins add ./atlas-{tier}
```

### From Git (latest)

```bash
# Clone and install directly
git clone https://forgejo.axoiq.com/atlas/atlas-plugin.git
cd atlas-plugin
./build.sh dev          # or: admin, user, all
claude plugins add ./dist/atlas-dev
```

### Remove old plugins

```bash
# Remove legacy plugins before installing ATLAS
for p in superpowers feature-dev code-review frontend-design hookify; do
  claude plugins remove "$p" 2>/dev/null || true
done
```

## Building from Source

Requires: `bash`, `yq` (via snap: `sudo snap install yq`)

```bash
./build.sh all      # Build all 3 tiers → dist/atlas-{admin,dev,user}/
./build.sh dev      # Build one tier only
./build.sh admin
./build.sh user
```

Outputs land in `dist/atlas-{tier}/` with the full plugin structure:

```
dist/atlas-dev/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── commands/       # /atlas subcommands
├── skills/         # Skill definitions (SKILL.md per skill)
├── agents/         # Subagent configs
└── hooks/          # SessionStart, SessionEnd, PostCompact hooks
```

## Version Bumping

```bash
# Bump patch (2.0.0 → 2.0.1), commit, and tag
./scripts/bump-version.sh patch

# Bump minor (2.0.0 → 2.1.0)
./scripts/bump-version.sh minor

# Bump major (2.0.0 → 3.0.0)
./scripts/bump-version.sh major
```

The script writes the new version to `VERSION`, commits, and creates a `v{version}` git tag.
Pushing the tag triggers the CI publish workflow.

```bash
git push && git push --tags
```

## Architecture

```
atlas-plugin/
├── profiles/           # Tier definitions (YAML, with inheritance)
│   ├── user.yaml       # Base tier
│   ├── dev.yaml        # Inherits: user
│   └── admin.yaml      # Inherits: dev
│
├── skills/             # Shared skill library
│   ├── tdd/
│   ├── plan-builder/
│   ├── deep-research/
│   └── refs/           # Reference docs bundled into tiers
│
├── commands/           # /atlas subcommand definitions (*.md)
├── agents/             # Subagent configs (plan-architect, code-reviewer, …)
├── hooks/              # hooks.json + session lifecycle scripts
├── templates/          # Reusable templates
│
├── build.sh            # Builder: resolves inheritance → dist/
├── scripts/
│   ├── generate-master-skill.sh  # Generates using-atlas SKILL.md per tier
│   └── bump-version.sh           # Semver bump + git tag
│
└── dist/               # Build outputs (gitignored)
    ├── atlas-admin/
    ├── atlas-dev/
    └── atlas-user/
```

Tier inheritance resolves at build time — `admin` inherits all `dev` skills/commands, which
inherit all `user` skills/commands. No runtime resolution; each `dist/` artifact is self-contained.

## CI/CD

The `.forgejo/workflows/build-publish.yaml` workflow runs on every push to `main` and on tag pushes.

| Trigger | Jobs |
|---------|------|
| Push to `main` | build + verify |
| Tag `v*` | build + verify + publish to Package Registry |
| Manual dispatch | build + verify |

Published packages are available at:
`https://forgejo.axoiq.com/atlas/-/packages/generic/atlas-{tier}`

## Contributing

1. Branch from `main`: `git checkout -b feature/my-change`
2. Edit skills in `skills/`, commands in `commands/`, or tier profiles in `profiles/`
3. Build and test locally: `./build.sh all && claude plugins add ./dist/atlas-dev`
4. Commit with conventional format: `feat(skills): add new-skill`
5. Open a PR on Forgejo — CI must be green before merge

## License

UNLICENSED — Private use only. AXOIQ property.
