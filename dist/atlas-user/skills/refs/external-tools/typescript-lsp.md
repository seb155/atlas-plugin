# TypeScript LSP — Code Intelligence for TS/JS

category: lsp
tool_prefix: (uses LSP tool directly, not mcp__)
priority: 7

## When to Use
- Find where a symbol is defined (goToDefinition)
- Find all usages of a function/type (findReferences)
- Get type info or documentation on hover (hover)
- List all symbols in a file (documentSymbol)
- Search symbols across workspace (workspaceSymbol)
- Find interface implementations (goToImplementation)
- Trace call hierarchies (prepareCallHierarchy, incomingCalls, outgoingCalls)
- Prefer over Grep for symbol navigation in TypeScript/JavaScript

## Protocol (call order)

Uses the built-in `LSP` tool (not an MCP tool). Params: `operation`, `filePath`, `line`, `character`.

1. Identify the file and position (line:character, both 1-based)
2. Call `LSP` with the appropriate operation
3. Results include file paths, line numbers, and content

### Operations
| Operation | Purpose | When |
|-----------|---------|------|
| `goToDefinition` | Jump to where symbol is declared | "Where is this defined?" |
| `findReferences` | All files using this symbol | "Who calls this?" |
| `hover` | Type info + docs at position | "What type is this?" |
| `documentSymbol` | All symbols in a file | "What's in this file?" |
| `workspaceSymbol` | Search symbols by name across project | "Find all hooks named useX" |
| `goToImplementation` | Find concrete implementations | "Who implements this interface?" |
| `prepareCallHierarchy` | Get callable at position | Setup for call hierarchy queries |
| `incomingCalls` | Who calls this function | "What depends on this?" |
| `outgoingCalls` | What this function calls | "What does this depend on?" |

## Supported Languages
`.ts`, `.tsx`, `.js`, `.jsx`, `.mts`, `.cts`, `.mjs`, `.cjs`

## When NOT to Use
- Python, Java, or other non-JS/TS files
- Searching for string literals or comments -> use Grep
- File-level operations (rename, move) -> use Edit/Write

## Fallback
Grep + Read for symbol search when LSP unavailable

## Example
User: "Find all references to useWorkspaceNavigation"
-> LSP(operation: "workspaceSymbol", filePath: "src/index.ts", line: 1, character: 1)
   (workspaceSymbol uses query-like matching)
-> Or: find the definition first, then findReferences at that position
