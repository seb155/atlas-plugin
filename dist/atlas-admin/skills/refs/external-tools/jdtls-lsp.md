# JDTLS LSP — Java Code Intelligence

category: lsp
tool_prefix: (uses LSP tool directly, not mcp__)
priority: 6

## When to Use
- Navigate Java codebases: definitions, references, implementations
- Get type information and Javadoc on hover
- List all classes/methods in a Java file
- Trace call hierarchies in Java projects
- Requires Java 17+ installed on the system

## Protocol
Same as typescript-lsp — uses the built-in `LSP` tool with `operation`, `filePath`, `line`, `character`.

### Operations
| Operation | Purpose |
|-----------|---------|
| `goToDefinition` | Jump to class/method declaration |
| `findReferences` | All usages of a symbol |
| `hover` | Javadoc + type info |
| `documentSymbol` | All symbols in a .java file |
| `goToImplementation` | Find concrete class implementations |
| `incomingCalls` / `outgoingCalls` | Call hierarchy |

## Supported Languages
`.java` only

## When NOT to Use
- Kotlin, Scala, Groovy -> not supported by JDTLS
- TypeScript/JavaScript -> use typescript-lsp instead

## Fallback
Grep + Read for Java symbol search

## Example
User: "Find all implementations of the Repository interface"
-> LSP(operation: "goToImplementation", filePath: "src/Repository.java", line: 5, character: 18)
