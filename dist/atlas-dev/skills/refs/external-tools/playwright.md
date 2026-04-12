# Playwright MCP — Headless Browser Automation & E2E Testing

category: browser-automation
tool_prefix: mcp__plugin_playwright_playwright__
priority: 8

## When to Use
- Automated E2E testing (headless, no visual browser needed)
- Page snapshot for accessibility tree (better than screenshot for actions)
- Form filling, clicking, navigation in automated flows
- Network request inspection, console message reading
- Prefer over chrome MCP for non-interactive/scripted automation

## Protocol (call order)
1. `browser_navigate` — go to target URL
2. `browser_snapshot` — get accessibility tree (MANDATORY before any click/type)
   - Returns element refs (e.g., `ref="s1e5"`) — use these for interactions
3. `browser_click` / `browser_type` / `browser_fill_form` — interact using refs from snapshot
4. `browser_snapshot` again after interaction to verify state
5. `browser_close` — clean up when done

### Key Tools
| Tool | Purpose |
|------|---------|
| `browser_snapshot` | Accessibility tree — ALWAYS before clicks |
| `browser_click` | Click element by ref |
| `browser_type` | Type text into element |
| `browser_fill_form` | Fill multiple form fields at once |
| `browser_evaluate` | Run JavaScript in page context |
| `browser_take_screenshot` | Visual screenshot (for review, not actions) |
| `browser_network_requests` | Inspect XHR/fetch calls |
| `browser_console_messages` | Read console output |
| `browser_tabs` | Manage multiple tabs |
| `browser_run_code` | Execute Playwright code snippet |

## When NOT to Use
- Interactive browsing where user needs to see/control browser -> use chrome MCP
- Simple URL content extraction -> use WebFetch
- API testing -> use curl/Bash

## Fallback
Chrome MCP (mcp__claude-in-chrome__*) for interactive browser sessions

## Example
User: "Test if the login page works"
-> browser_navigate("https://app.example.com/login")
-> browser_snapshot() -> find username/password fields
-> browser_fill_form([{ref: "s1e3", value: "test@example.com"}, ...])
-> browser_click(ref for submit button)
-> browser_snapshot() -> verify redirect to dashboard
-> browser_close()
