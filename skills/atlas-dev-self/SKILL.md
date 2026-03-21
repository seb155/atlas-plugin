---
name: atlas-dev-self
description: "Self-development workflow for the ATLAS plugin itself. Use when adding skills, agents, hooks, or commands to the plugin. Knows the full plugin structure, test suite, and release workflow."
effort: high
---

# ATLAS Self-Development

You are developing the ATLAS plugin **from inside ATLAS**. This skill provides the complete workflow for modifying the plugin itself.

## When to Use

- Adding a new skill, agent, hook, or command to the plugin
- Modifying existing plugin components
- Fixing plugin tests or build issues
- Preparing a plugin release (version bump + publish)
- Auditing plugin structure or quality

## Plugin Root

The plugin lives at a known location relative to the Synapse project:
```
{synapse_root}/atlas-plugin/
```

Detect it:
```bash
PLUGIN_DIR=$(find . -maxdepth 2 -name "plugin.json" -path "*/.claude-plugin/*" -exec dirname {} \; | head -1 | xargs dirname)
```

## Workflow: Add a New Skill

### Step 1 — Create the skill
```bash
mkdir -p ${PLUGIN_DIR}/skills/{name}
```
Write `SKILL.md` with frontmatter: `name`, `description`, `effort`.

### Step 2 — Register in profile
Add to `profiles/{tier}.yaml` under `skills:` (user, dev, or admin).

### Step 3 — Add emoji + description maps
Edit `scripts/generate-master-skill.sh`:
- `EMOJI_MAP[{name}]="emoji"`
- `DESC_MAP[{name}]="one-liner"`
- `CATEGORY_MAP[{name}]="Category"`

### Step 4 — Create command
Write `commands/{name}.md`:
```
Invoke the `{name}` skill with the following arguments: $ARGUMENTS
{description + subcommands}
```
Add command to profile under `commands:`.

### Step 5 — Test
```bash
cd ${PLUGIN_DIR} && python3 -m pytest tests/ -x -q --tb=short
```

### Step 6 — Build + Install
```bash
cd ${PLUGIN_DIR} && make dev
```

### Step 7 — Verify in live session
Restart Claude Code. Test `/atlas {name}`.

## Workflow: Add a New Agent

1. `mkdir agents/{name}` + write `AGENT.md` (name, description, model)
2. Add to profile under `agents:`
3. Read-only agents: add deny list
4. `make test && make dev`

## Workflow: Add a New Hook

1. Create `hooks/{name}` (executable bash script)
2. Add entry to `hooks/hooks.json`
3. Brand output: `🏛️ ATLAS │ ...`
4. `make test && make dev`
5. Build auto-includes via wildcard (no manual list)

## Workflow: Release

```bash
cd ${PLUGIN_DIR}
# 1. Version bump
make publish-patch    # or publish-minor

# Or manual:
echo "X.Y.Z" > VERSION
./build.sh all
python3 -m pytest tests/ -x -q --tb=short
git add -A && git commit -m "feat(plugin): vX.Y.Z — {description}"
git tag vX.Y.Z
git push origin main --tags
```

## Workflow: Bootstrap User Project Context

When a user's project is missing context files, ATLAS should help create them:

### Missing CLAUDE.md
- Detect: `[ ! -f CLAUDE.md ]`
- Action: Invoke `context-discovery` skill → generate CLAUDE.md from scan results
- Template: Use W3H format (What, Why, Where, How) — max 100 lines

### Missing .claude/rules/
- Detect: `[ ! -d .claude/rules ]`
- Action: Extract patterns from existing code → generate 2-3 rule files
- Focus: code-quality, testing, naming conventions

### Missing memory files
- Detect: check `~/.claude/projects/{path}/memory/MEMORY.md`
- Action: Create MEMORY.md index + initial memory files from session context

### Missing .blueprint/
- Detect: `[ ! -d .blueprint ]`
- Action: Create minimal structure: INDEX.md, plans/ directory

## Onboarding & Doctor System (v3.4.0+)

When modifying onboarding or doctor:
- Onboarding skill: `skills/atlas-onboarding/SKILL.md`
- Doctor skill: `skills/atlas-doctor/SKILL.md`
- First-run detection: `hooks/session-start` (checks `~/.atlas/profile.json`)
- Profile storage: `~/.atlas/profile.json`
- Doctor report: `~/.atlas/doctor-report.json`

Doctor checks are bash one-liners. To add a new check:
1. Add to the appropriate category in atlas-doctor SKILL.md
2. Update the scoring (N+1 checks in that category)
3. Add auto-fix suggestion if applicable
4. Run `make test && make dev`

## Quality Gates

Before any plugin commit:
1. `python3 -m pytest tests/ -x -q --tb=short` — ALL PASS
2. `./build.sh all` — 3 tiers build clean
3. `grep "❓" dist/atlas-admin/skills/atlas-assist/SKILL.md` — 0 results
4. `make dev` — installs to CC cache

## Key Files (cheat sheet)

| Need to... | Edit this file |
|------------|---------------|
| Add skill | `skills/{name}/SKILL.md` + `profiles/{tier}.yaml` + `scripts/generate-master-skill.sh` + `commands/{name}.md` |
| Add agent | `agents/{name}/AGENT.md` + `profiles/{tier}.yaml` |
| Add hook | `hooks/{name}` + `hooks/hooks.json` |
| Add ref | `skills/refs/{name}/SKILL.md` + `profiles/{tier}.yaml` refs: |
| Bump version | `VERSION` (build.sh propagates) |
| Fix test | `tests/test_{name}.py` + `tests/conftest.py` |
| Update CI | `.forgejo/workflows/build-publish.yaml` |
