# `.claude/rules/_meta.yaml` Schema v1.0

> v6.0 Phase 4: Rules Conditional Loader — per-rule auto-include configuration.
> Consumer: `hooks/rules-conditional-loader.sh`
> Created: 2026-04-23

## Purpose

Enables lean SessionStart by loading **only relevant rules** based on project context (cwd, branch, recent file modifications). Target: 33K → <15K tokens at SessionStart.

## Location

Each project's `.claude/rules/` directory should contain `_meta.yaml` alongside the individual rule markdown files:

```
.claude/rules/
├── _meta.yaml                          # THIS SCHEMA
├── testing-discipline.md
├── enterprise-security.md
├── code-quality.md
├── dod.md
└── ...
```

## Schema

```yaml
rules:
  rule-file-name.md:
    auto_include: always | conditional | never   # default: conditional
    priority: 1-10                                # default: 5 (higher = top)
    description: "brief desc for loader output"
    triggers:                                     # only for conditional
      cwd_contains: [substring1, substring2]     # any match = +10 score
      branch_patterns: ["feat/*", "fix/*"]       # fnmatch, any match = +5
      file_patterns: ["*.py", "*test*", "*.tsx"] # fnmatch on recent mods, any match = +3
```

## Modes

| Mode | Behavior |
|------|----------|
| `always` | Include every session (priority + 100 boost) |
| `conditional` | Include only if triggers match (default) |
| `never` | Never include (explicit exclusion, keeps rule for manual read) |

## Scoring

Final score = sum of matched trigger scores + priority. Top N (configurable, default 10) selected per session.

Example:
- `testing-discipline.md` with `cwd_contains: [backend]` + priority 7 → score 17 if in backend/
- `code-quality.md` with `auto_include: always` + priority 8 → score 108 (always top)

## Example _meta.yaml

```yaml
rules:
  code-quality.md:
    auto_include: always
    priority: 8
    description: "Per-language code hygiene rules — always loaded for coding context"

  dod.md:
    auto_include: always
    priority: 7
    description: "Definition of Done — 13-layer validation, always relevant"

  testing-discipline.md:
    auto_include: conditional
    priority: 7
    description: "Testing rules (pytest flags, TVT tiers, mock budget)"
    triggers:
      cwd_contains: [backend, tests]
      file_patterns: ["*test*.py", "*.test.ts", "test_*.py"]
      branch_patterns: ["feat/*", "fix/*"]

  enterprise-security.md:
    auto_include: conditional
    priority: 9  # High priority when it matches
    description: "Enterprise security patterns (auth, RBAC, secrets)"
    triggers:
      cwd_contains: [auth, security, backend/app/core]
      file_patterns: ["*auth*", "*security*", "*secret*"]

  compaction-protocol.md:
    auto_include: conditional
    priority: 10  # Critical when context is high
    description: "Compaction 6-section preservation"
    triggers:
      # Injected by a different hook (PreCompact) — never at SessionStart
      # Keeping entry to document policy
      file_patterns: []

  zustand-enforcement.md:
    auto_include: conditional
    priority: 6
    description: "Zustand selector pattern enforcement"
    triggers:
      cwd_contains: [frontend, src/store]
      file_patterns: ["*.tsx", "*.ts", "*store*"]
```

## Integration

### Hook
`hooks/rules-conditional-loader.sh` reads `_meta.yaml`, scores rules, emits SessionStart additionalContext with top N rule pointers.

### Registration
Add to `hooks/hooks.json`:
```json
{
  "hooks": [
    {
      "events": ["SessionStart"],
      "command": "$CLAUDE_PLUGIN_ROOT/hooks/rules-conditional-loader.sh",
      "async": true,
      "timeout": 5
    }
  ]
}
```

### Fallback behavior
If `_meta.yaml` missing OR zero rules selected:
- Fallback to conservative defaults: `code-quality.md` + `dod.md`
- If neither exists, silent exit (no context injection)

## Telemetry

- Rules loaded per session → log to `.claude/skill-usage.jsonl` (future: dedicated `rules-loaded.jsonl`)
- Avg rules loaded per session should be 3-6 (not the full 19)
- Target token reduction: 33K → <15K at SessionStart (60% reduction)

## Version History

- **v1.0** (2026-04-23): Initial schema — Phase 4 foundation (v6.0.0-alpha.7+)

## References

- Plan: `.blueprint/plans/le-plugin-atlas-core-devrais-adaptive-treasure.md` (Dim 3)
- Hook: `hooks/rules-conditional-loader.sh`
- Companion: `hooks/memory-auto-index.sh` (v6.0 Phase 3)
