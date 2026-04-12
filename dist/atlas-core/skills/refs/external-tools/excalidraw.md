# Excalidraw — Hand-Drawn Diagrams

category: design
tool_prefix: mcp__claude_ai_Excalidraw__
priority: 5

## When to Use
- Create visual diagrams (architecture, flowcharts, wireframes)
- Hand-drawn aesthetic preferred over formal diagrams
- Shareable diagrams (export to excalidraw.com URL)
- When Mermaid markdown diagrams aren't visual enough

## Protocol (call order)

### CRITICAL: read_me FIRST (mandatory)
1. `read_me` — returns element format reference, color palettes, examples, tips
   - MUST call before first `create_view` in a session
2. `create_view` — render diagram with JSON elements array
   - Elements stream in one-by-one with draw-on animations
   - Must be valid JSON (no comments, no trailing commas)
3. `export_to_excalidraw` — upload to excalidraw.com for sharing
4. `save_checkpoint` / `read_checkpoint` — persist/restore state

### Key Tools
| Tool | Purpose |
|------|---------|
| `read_me` | MANDATORY first call — get element format |
| `create_view` | Render elements as hand-drawn diagram |
| `export_to_excalidraw` | Get shareable excalidraw.com URL |
| `save_checkpoint` | Persist diagram state |
| `read_checkpoint` | Restore saved diagram |

## When NOT to Use
- Simple text diagrams -> use Mermaid in markdown
- Sequence diagrams or class diagrams -> Mermaid is better
- Data visualizations (charts, graphs) -> use other tools

## Fallback
Mermaid diagrams in markdown (```mermaid blocks)

## Example
User: "Draw the architecture of our backend"
-> read_me() -> learn element format
-> create_view(elements: [{type: "rectangle", ...}, {type: "arrow", ...}])
-> export_to_excalidraw(json) -> get shareable URL
