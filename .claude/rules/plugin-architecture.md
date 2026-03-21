# Plugin Architecture Rules

## Tier Inheritance
- 3 tiers: user → dev → admin. Child inherits all parent components.
- Resolution is BUILD-TIME only. Each dist/ artifact is self-contained.
- `resolve_field()` in build.sh recursively collects items via `inherits:` chain.
- `awk '!seen[$0]++'` deduplicates without changing YAML order.

## Skills
- 1 skill = 1 directory under `skills/` with `SKILL.md`
- Frontmatter REQUIRED: `name`, `description`, `effort` (low|medium|high)
- Optional: `examples/` subdir, `references/` subdir
- Max size: ~200 lines for SKILL.md (progressive disclosure)

## Agents
- 1 agent = 1 directory under `agents/` with `AGENT.md`
- Frontmatter REQUIRED: `name`, `description`, `model` (opus|sonnet|haiku)
- Read-only agents MUST have "Tools NOT Allowed" deny list

## Commands
- 1 command = 1 markdown file in `commands/`
- Standard pattern: `Invoke the {skill} skill with: $ARGUMENTS`
- Commands are the USER-FACING interface; skills are the implementation

## Hooks
- All hooks in `hooks/` directory. `hooks.json` is the registry.
- Build copies ALL executable scripts (wildcard). No manual list.
- Output format: `🏛️ ATLAS │ {emoji}{severity} {CATEGORY} │ {message}`
- Async hooks: PostToolUse, UserPromptSubmit, SessionEnd
- Sync hooks: SessionStart, PermissionRequest, PreCompact, PostCompact

## Build System
- VERSION file is SSoT. build.sh propagates to all JSON manifests.
- generate-master-skill.sh creates tier-specific atlas-assist with real counts.
- 4 associative arrays: EMOJI_MAP, DESC_MAP, CATEGORY_MAP, CATEGORY_EMOJI
- New skills MUST be added to all 4 arrays.
