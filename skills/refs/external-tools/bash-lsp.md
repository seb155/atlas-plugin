# Bash LSP — Code Intelligence for Shell Scripts

category: lsp
tool_prefix: (uses LSP tool directly, not mcp__)
priority: 6

## When to Use
- Find where a function is defined in a large shell codebase (goToDefinition)
- Find all call sites of a function before refactoring (findReferences)
- Get variable/function documentation on hover (hover)
- List all functions defined in a script (documentSymbol)
- Search functions across the plugin's shell scripts (workspaceSymbol)
- Prefer over Grep for symbol navigation in `.sh` / `.bash` files

## Protocol (call order)

Uses the built-in `LSP` tool (not an MCP tool). Params: `operation`, `filePath`, `line`, `character`.

1. Identify the file and position (line:character, both 1-based)
2. Call `LSP` with the appropriate operation
3. Results include file paths, line numbers, and content

### Operations
| Operation | Purpose | When |
|-----------|---------|------|
| `goToDefinition` | Jump to function/variable declaration | "Where is `_check` defined?" |
| `findReferences` | All files using this function/variable | "Who calls `_atlas_resolve_version`?" |
| `hover` | Type/signature info at position | "What args does this take?" |
| `documentSymbol` | All symbols in a shell file | "What functions does this module expose?" |
| `workspaceSymbol` | Search by name across project | "Find all functions matching `_atlas_*`" |

## Supported Files
`.sh`, `.bash`

Not supported: `.zsh` (convert to bash — see `lesson_zsh_to_bash_module_conversion.md`).

## Prerequisites
```bash
npm install -g bash-language-server
which bash-language-server   # verify in PATH
```

Plugin declares the server in `dist/atlas-dev-addon/.lsp.json`. CC auto-discovers at startup.

## When NOT to Use
- `.zsh` scripts — bash-language-server doesn't parse zsh extensions
- One-liner inline scripts — overhead not worth it
- Searching for literal strings or comments — use Grep
- File-level operations (rename, move) — use Edit/Write

## Fallback
Grep + Read for symbol search when LSP unavailable.

## Examples

**Find who calls `_atlas_discover_projects`**:
```
LSP(operation: "findReferences", filePath: "scripts/atlas-modules/subcommands.sh", line: 13, character: 5)
```

**Get signature of `throttle_check`**:
```
LSP(operation: "hover", filePath: "hooks/lib/throttle.sh", line: 12, character: 1)
```

**List all functions in a module**:
```
LSP(operation: "documentSymbol", filePath: "scripts/atlas-modules/launcher.sh")
```

## Known limitations (bash-language-server)

- Does not fully handle `source` / `.` statements — cross-file navigation may miss
- Limited for dynamically constructed command names (e.g., `"$var" arg`)
- No support for shellcheck diagnostics (use shellcheck directly for linting)

Complement with:
- `shellcheck` for lint diagnostics
- `bats-core` for behavior tests

Reference: https://github.com/bash-lsp/bash-language-server
