# ATLAS Plugin — Claude Code AI Engineering Assistant

> **Stack**: Bash + yq + Python (tests) | **Version**: `cat VERSION` | **Branch**: `main`
> **Repo**: `forgejo.axoiq.com/atlas/atlas-plugin` | **Owner**: Seb Gagnon (AXOIQ)

## IDENTITY

**ATLAS** is AXOIQ's unified Claude Code plugin — a multi-tier AI engineering assistant with skills, agents, commands, and lifecycle hooks. It replaces 18+ individual plugins with one cohesive system.

**Key insight**: ATLAS develops itself using ATLAS. The plugin-builder, skill-management, and atlas-dev-self skills are used to extend the plugin.

## ARCHITECTURE

```
profiles/{user,dev,admin}.yaml   ← Tier definitions (YAML inheritance)
        ↓ build.sh
dist/atlas-{user,dev,user}/      ← Self-contained artifacts (no runtime deps)
        ↓ make dev
~/.claude/plugins/cache/         ← Installed in Claude Code
```

**3-Tier Inheritance**: `user` → `dev` (inherits user) → `admin` (inherits dev)

| Component | Location | Count (admin) |
|-----------|----------|---------------|
| Skills | `skills/*/SKILL.md` | ~40 |
| Agents | `agents/*/AGENT.md` | 6 |
| Commands | `commands/*.md` | ~37 |
| Hooks | `hooks/hooks.json` + scripts | 8 |
| Refs | `skills/refs/*/SKILL.md` | 5 |
| Tests | `tests/test_*.py` | 14 |

## COMMANDS

```bash
# Build
./build.sh all                    # Build 3 tiers → dist/
./build.sh admin                  # Build admin only

# Test (ALWAYS -x --tb=short)
python3 -m pytest tests/ -x -q --tb=short
python3 -m pytest tests/test_skill_frontmatter.py -x -q --tb=short  # Single test

# Dev cycle (build admin + install to CC cache)
make dev

# Publish
make publish-patch                # patch bump → build → test → tag → push
make publish-minor                # minor bump

# Lint
make lint                         # Frontmatter + coverage checks
```

## PRINCIPLES

1. **Self-Contained Tiers** — Each `dist/atlas-{tier}/` is independent. No runtime inheritance.
2. **Build-Time Resolution** — `resolve_field()` in build.sh resolves YAML inheritance recursively.
3. **Dynamic Generation** — `generate-master-skill.sh` builds atlas-assist per tier with real counts.
4. **Test Everything** — 14 test types validate structure, frontmatter, cross-refs, build output, hooks.
5. **Version SSoT** — `VERSION` file → propagated to all JSON manifests by build.sh.
6. **Visual Identity** — All hook outputs use `🏛️ ATLAS │` prefix. See `skills/refs/atlas-visual-identity/`.

## EXTENDING THE PLUGIN

### Adding a Skill
1. Create `skills/{name}/SKILL.md` with frontmatter: `name`, `description`, `effort`
2. Add to appropriate profile (`profiles/{tier}.yaml`)
3. Add to `EMOJI_MAP`, `DESC_MAP`, `CATEGORY_MAP` in `scripts/generate-master-skill.sh`
4. Create command `commands/{name}.md`: `Invoke the {name} skill with: $ARGUMENTS`
5. Run `make test` — validates frontmatter, coverage, cross-refs

### Adding an Agent
1. Create `agents/{name}/AGENT.md` with frontmatter: `name`, `description`, `model`
2. Add to profile under `agents:` list
3. Define workflow, tools, constraints in the AGENT.md
4. Read-only agents: add "Tools NOT Allowed" deny list

### Adding a Hook
1. Create executable script in `hooks/{name}`
2. Add entry to `hooks/hooks.json` with event, matcher, async, timeout
3. Brand output with `🏛️ ATLAS │ {emoji}{severity} {CATEGORY} │ {message}`
4. Build copies all executable hooks automatically (wildcard)

### Adding a Reference
1. Create `skills/refs/{name}/SKILL.md`
2. Add to profile under `refs:` list

## ONBOARDING & DOCTOR

- `/atlas setup` — 5-phase wizard (profile, credentials, env, context, optional)
- `/atlas doctor` — 8-category health dashboard with auto-fix
- First-run: SessionStart hook detects missing `~/.atlas/profile.json` → shows `👋 FIRST RUN`
- Storage: `~/.atlas/` (profile.json, doctor-report.json)
- Both skills available in ALL tiers (user, dev, admin)

## SELF-DEVELOPMENT

This plugin develops itself. When modifying atlas-plugin:
- **Use skill-management** for creating/improving skills
- **Use plugin-builder** for structural changes
- **Use atlas-dev-self** for the full self-development workflow
- **Always run `make test` before commit**
- **Always run `make dev` to install and test in a live CC session**

## KEY FILES

| File | Purpose |
|------|---------|
| `build.sh` | Multi-tier builder with inheritance |
| `scripts/generate-master-skill.sh` | Dynamic atlas-assist generator |
| `profiles/*.yaml` | Tier definitions |
| `hooks/hooks.json` | Hook registry |
| `Makefile` | Dev workflow shortcuts |
| `VERSION` | Semver SSoT |
| `tests/conftest.py` | Test fixtures + constants |
| `.forgejo/workflows/build-publish.yaml` | CI/CD |

## TESTING

14 test files covering:
- `test_skill_frontmatter` — name, description, effort in every SKILL.md
- `test_skill_coverage` — no orphan skills (except atlas-assist source)
- `test_command_structure` — command routing validity
- `test_profiles` — YAML inheritance chain
- `test_build_output` — dist/ artifact completeness
- `test_version_sync` — VERSION matches all manifests
- `test_cross_references` — skills ↔ commands ↔ profiles aligned
- `test_hooks_schema` — hooks.json validity
- `test_hook_behavior` — hook script execution
- `test_agent_frontmatter` — agent spec completeness
- `test_manifest` — plugin.json validity
- `test_no_hardcoded_paths` — portability
- `test_skill_quality` — documentation quality
