# Bash Naming Conventions

ATLAS-specific conventions based on Google Shell Style Guide + internal standards.

## Core rules

| Entity | Case | Example | Counter-example |
|--------|------|---------|-----------------|
| Variables (local) | `snake_case` lowercase | `local user_id="$1"` | `local UserID`, `local USR` |
| Constants | `UPPER_SNAKE_CASE` | `readonly MAX_RETRIES=3` | `readonly max_retries` |
| Env vars | `UPPER_SNAKE_CASE` with prefix | `ATLAS_PLUGIN_ROOT`, `CLAUDE_SESSION_ID` | `atlas_plugin_root` |
| Functions | `snake_case` | `log_info()`, `validate_input()` | `LogInfo()`, `validate-input()` |
| Private functions | `_snake_case` | `_check_prereqs()` | `.check_prereqs()` |
| Script files | `kebab-case.sh` | `atlas-cli.sh`, `build-plugin.sh` | `atlas_cli.sh`, `buildPlugin.sh` |
| Hook files (no ext) | `kebab-case` | `session-start`, `context-threshold-injector` | `session_start`, `sessionStart` |

## Project conventions (ATLAS)

All shell scripts use `#!/usr/bin/env bash` shebang. Zsh scripts converted to bash (Phase 6A-2).
Shell modules sourced from user's shell use `# shellcheck shell=bash` directive.

## Function patterns

```bash
# Public (exported for sourcing)
atlas_resolve_version() {
    local version
    version=$(cat VERSION 2>/dev/null || echo "0.0.0")
    echo "$version"
}

# Private (single underscore)
_atlas_internal_helper() {
    ...
}

# Main entry (if script is executable)
main() {
    local arg="${1:?usage: script <arg>}"
    atlas_resolve_version
}

# Always invoke main with "$@" at end
main "$@"
```

## Variable scope

```bash
# Good — explicit local scope
my_function() {
    local input="${1:-default}"
    local result
    result=$(compute "$input")
    echo "$result"
}

# Bad — leaking to parent scope
my_function() {
    input="$1"                # pollutes parent!
    result=$(compute "$input")
}
```

## Environment variables

ATLAS-specific env vars follow a naming convention to avoid collisions:

| Prefix | Purpose | Examples |
|--------|---------|----------|
| `ATLAS_*` | ATLAS plugin / CLI state | `ATLAS_PLUGIN_ROOT`, `ATLAS_SHELL_DIR` |
| `CLAUDE_*` | Claude Code runtime (set by CC) | `CLAUDE_PLUGIN_ROOT`, `CLAUDE_SESSION_ID` |
| `WP_*` | Woodpecker CI | `WP_TOKEN`, `WP_URL` |
| `FORGEJO_*` | Forgejo API | `FORGEJO_TOKEN`, `FORGEJO_API_URL` |

## File naming

```
# Good
scripts/atlas-cli.sh              # kebab-case
scripts/setup-wizard.sh
hooks/session-start               # no extension, kebab-case
hooks/context-threshold-injector
hooks/lib/throttle.sh             # shared libs in lib/

# Bad
scripts/atlasCli.sh               # camelCase
scripts/atlas_cli.sh              # snake_case (reserved for Python)
hooks/SessionStart                # PascalCase
```

## Quoting rule

ALWAYS quote variables:
```bash
# Good
if [ -f "$file" ]; then
    rm -f "$file"
fi

# Bad (breaks on spaces, glob expansion)
if [ -f $file ]; then
    rm -f $file
fi
```

Exceptions (intentional unquoting):
- Inside `[[ ]]` for regex matches: `[[ "$str" =~ pattern ]]`
- Inside arithmetic: `(( x > 5 ))`
- `# shellcheck disable=SC2086` with comment explaining why

## Strict mode (for EXECUTED scripts, not sourced)

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Optional cleanup
trap 'rc=$?; rm -f "$tmpfile" 2>/dev/null; exit $rc' EXIT
```

Sourced libraries (hooks/lib/*, scripts/atlas-modules/*) SHOULD NOT set strict mode at file level —
it affects the caller's shell. Document with:
```bash
# NOTE: Sourced library — no set -euo pipefail at file level.
# Callers manage their own strict mode.
```

## Boolean conventions

Shell doesn't have real booleans. Use:
```bash
# Pattern 1: exit code (preferred)
is_admin() {
    [ "$USER_ROLE" = "admin" ]
}
if is_admin; then echo "admin"; fi

# Pattern 2: string "true"/"false"
is_admin="true"
[ "$is_admin" = "true" ] && echo "admin"

# Pattern 3: integer 0/1 (harder to read)
is_admin=0  # 0 = true (exit code convention)
[ "$is_admin" -eq 0 ] && echo "admin"
```

Prefer Pattern 1 (function + exit code) for readability.

## AVOID

- `CamelCase` for variables (reserved for classes in other langs — confusing)
- Single-letter variables outside of short loops
- Abbreviations unless in allowlist (`id`, `url`, `api`, `db`, `ui`, `dir`, `fn`, `cmd`, `ret`)
- Uppercase local variables (convention says constants are uppercase)
- Unquoted variable expansion (`$var` without `"..."`)
- `function funcname` (prefer `funcname()` — POSIX-compatible)

## References

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck rules](https://www.shellcheck.net/wiki/)
- ATLAS CONTRIBUTING.md — Shell Module Contract
