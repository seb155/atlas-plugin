# Chrome MCP — Interactive Browser Automation (Claude-in-Chrome)

category: browser-automation
tool_prefix: mcp__claude-in-chrome__
priority: 8

## When to Use
- Interactive browser sessions (user sees the browser)
- Visual QA — take screenshots, record GIFs of workflows
- Live debugging in Chrome DevTools (console, network)
- Form interaction on real websites with the user watching
- Prefer over playwright when the user needs to SEE what's happening

## Protocol (call order)

### CRITICAL: Tools are DEFERRED — must load before use
All `mcp__claude-in-chrome__*` tools require ToolSearch to load their schemas first.

1. **ToolSearch** `select:mcp__claude-in-chrome__tabs_context_mcp` — load tab context tool
2. `tabs_context_mcp` — get current tab group and tab IDs
3. `tabs_create_mcp` — create new tab (each conversation gets its own tab)
4. `navigate` — go to URL (needs tabId from step 2/3)
5. `screenshot` / `read_page` — observe page state
6. Interact: `computer` (click/type), `find` (locate elements), `form_input`

### Key Tools
| Tool | Purpose |
|------|---------|
| `tabs_context_mcp` | FIRST CALL — get tab IDs |
| `tabs_create_mcp` | Create new tab for this session |
| `navigate` | Go to URL |
| `computer` | Mouse/keyboard actions (click, type, scroll, screenshot) |
| `read_page` | Accessibility tree of page |
| `find` | Find elements by natural language description |
| `form_input` | Set form field values by element ref |
| `get_page_text` | Extract raw text content |
| `gif_creator` | Record browser actions as GIF |
| `javascript_tool` | Execute JS in page context |
| `read_console_messages` | Read console output (use pattern filter!) |
| `read_network_requests` | Inspect network calls |

### GIF Recording
- `gif_creator` action: `start_recording` -> take actions -> `stop_recording` -> `export`
- Take screenshot immediately after start and before stop for first/last frames

## When NOT to Use
- Headless automated testing -> use playwright
- Simple URL fetch -> use WebFetch
- No Chrome browser available or extension not connected

## Fallback
Playwright MCP for headless automation; WebFetch for simple content extraction

## Example
User: "Check if synapse.axoiq.com loads properly"
-> ToolSearch("select:mcp__claude-in-chrome__tabs_context_mcp")
-> tabs_context_mcp(createIfEmpty: true)
-> tabs_create_mcp() -> get tabId
-> navigate(url: "https://synapse.axoiq.com", tabId)
-> computer(action: "screenshot", tabId)
