---
name: browser-automation
description: "Browser automation for E2E testing, visual QA, web interaction, and data extraction. This skill should be used when the user asks to 'open a website', 'test this page', 'take a screenshot', 'fill out a form', 'click a button', 'scrape data', 'automate browser actions', 'run visual QA', 'E2E test', or any task requiring programmatic web interaction. Supports both agent-browser CLI and Claude-in-Chrome MCP."
effort: low
---

# Browser Automation

Automate browser interactions for E2E testing, visual QA, form filling, data extraction, and web scraping.

## Two Backends

| Backend | When to Use | Tools |
|---------|-------------|-------|
| **agent-browser CLI** | Headless automation, CI, scripted flows | `Bash(agent-browser:*)` |
| **Claude-in-Chrome MCP** | Interactive browser, visual debugging, live pages | `mcp__claude-in-chrome__*` |

Detect which is available. Prefer agent-browser for automated flows, Chrome MCP for interactive/visual work.

## Core Workflow (agent-browser)

Every automation follows: **Navigate → Snapshot → Interact → Re-snapshot**

```bash
agent-browser open https://example.com
agent-browser snapshot -i              # Get element refs (@e1, @e2...)
agent-browser fill @e1 "value"         # Interact using refs
agent-browser click @e2
agent-browser wait --load networkidle
agent-browser snapshot -i              # Fresh refs after page change
```

### Essential Commands

```bash
# Navigation
agent-browser open <url>
agent-browser close

# Snapshot (ALWAYS before interacting)
agent-browser snapshot -i              # Interactive elements with refs
agent-browser snapshot -i -C           # Include cursor-interactive elements

# Interaction (use @refs from snapshot)
agent-browser click @e1
agent-browser fill @e2 "text"
agent-browser select @e1 "option"
agent-browser check @e1
agent-browser press Enter
agent-browser scroll down 500

# Information
agent-browser get text @e1
agent-browser get url
agent-browser get title

# Wait
agent-browser wait @e1                 # Wait for element
agent-browser wait --load networkidle  # Wait for network idle
agent-browser wait 2000                # Wait milliseconds

# Capture
agent-browser screenshot
agent-browser screenshot --full
agent-browser pdf output.pdf
```

### Ref Lifecycle (CRITICAL)
Refs (`@e1`, `@e2`) are **invalidated** when the page changes. ALWAYS re-snapshot after:
- Clicking links/buttons that navigate
- Form submissions
- Dynamic content loading (dropdowns, modals)

## Core Workflow (Chrome MCP)

```
1. tabs_context_mcp → get tab IDs
2. navigate → URL
3. read_page / find → get element refs
4. computer / form_input → interact
5. screenshot → verify
```

## Common Patterns

### Form Submission
```bash
agent-browser open <url>
agent-browser snapshot -i
agent-browser fill @e1 "name"
agent-browser fill @e2 "email"
agent-browser click @e3              # Submit
agent-browser wait --load networkidle
agent-browser screenshot             # Verify result
```

### Authentication + State Persistence
```bash
agent-browser open <login-url>
agent-browser snapshot -i
agent-browser fill @e1 "$USERNAME"
agent-browser fill @e2 "$PASSWORD"
agent-browser click @e3
agent-browser wait --url "**/dashboard"
agent-browser state save auth.json   # Reuse later
```

### Data Extraction
```bash
agent-browser open <url>
agent-browser snapshot -i
agent-browser get text @e5
agent-browser get text body > page.txt
```

### Visual QA (Screenshot Comparison)
```bash
agent-browser open <url>
agent-browser screenshot before.png
# ... make changes ...
agent-browser screenshot after.png
# Compare visually or with diff tool
```

## HITL Gates

- Before filling forms with sensitive data → confirm via AskUserQuestion
- Before submitting/posting anything → confirm
- Before login flows → confirm credentials usage
- After screenshot → present for visual approval
