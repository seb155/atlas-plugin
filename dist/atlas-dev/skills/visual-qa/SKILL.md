---
name: visual-qa
description: "Multi-page visual QA via Chrome MCP or Playwright. Auto-navigate routes, screenshot, check for errors, report pass/fail matrix."
triggers:
  - "/atlas visual-qa"
  - "/atlas qa"
  - "visual QA"
  - "test all pages"
  - "check all perspectives"
  - "screenshot all routes"
effort: low
---

# Visual QA — Multi-Page Automated Testing

Navigate through a list of routes, screenshot each, check for errors, and report results.
Uses Chrome MCP (preferred) or Playwright MCP.

## Commands

```bash
/atlas visual-qa                                    # Test from .atlas/visual-qa.yaml
/atlas visual-qa https://dev.axoiq.com              # Custom base URL
/atlas visual-qa --routes /dashboard,/architecture  # Specific routes
/atlas visual-qa --responsive 768,1024,1440         # Multiple viewports
```

## Configuration

`.atlas/visual-qa.yaml`:

```yaml
profiles:
  devhub:
    base_url: https://dev.axoiq.com
    auth: authentik-sso   # none | authentik-sso | basic
    wait_ms: 3000         # Wait after navigation before screenshot
    viewports: [1440x900] # Default viewport
    error_patterns:
      - "Something went wrong"
      - "ErrorBoundary"
      - "500 Internal"
      - "Failed to load"
    routes:
      - path: /dashboard
        expect_text: "Synapse Developer Wiki"
        expect_heading: true
      - path: /programme
        expect_text: "Feature Board"
      - path: /sprint
        expect_text: "Sprint"
      - path: /ai-ops
        expect_text: "AI Ops"
      - path: /architecture
        expect_text: "System Architecture"
      - path: /chain
        expect_text: "Engineering Chain"
      - path: /knowledge
        expect_text: "Knowledge"
      - path: /stack
        expect_text: "Stack Health"
      - path: /devops
        expect_text: "DevOps Command Center"
      - path: /tests
        expect_text: "Test Observability"
      - path: /infra
        expect_text: "Infrastructure Dashboard"
      - path: /team
        expect_text: "Team Portal"
```

## Process

### Step 1: Setup Browser

Prefer Chrome MCP (claude-in-chrome) if available. Fallback to Playwright MCP.

```
1. Call tabs_context_mcp to get current tab group
2. Create a new tab (tabs_create_mcp)
3. Navigate to base_url to handle SSO
4. Wait for SSO redirect to complete
```

### Step 2: Test Each Route

For each route in the config:

```
1. Navigate to {base_url}{route.path}
2. Wait {wait_ms}ms for page to load
3. Take screenshot
4. Check for error patterns in page content:
   - Read page text or snapshot
   - Search for error_patterns
   - Check browser console for errors
5. Verify expect_text is present
6. Record: route, status, screenshot_id, errors
```

### Step 3: Console Error Check

After each page load:

```
1. Read console messages (error level only)
2. Filter out known benign errors (e.g., favicon, analytics)
3. Flag any real errors (TypeError, NetworkError, etc.)
```

### Step 4: Responsive Check (optional)

If `--responsive` flag or multiple viewports in config:

```
1. For each viewport size:
   - Resize window
   - Navigate to route
   - Wait + screenshot
   - Check for overflow (horizontal scrollbar)
2. Restore original viewport
```

### Step 5: Report

Output format (table):

```
🔍 Visual QA Report — dev.axoiq.com
────────────────────────────────────────────────────

Route               Status  Text OK  Console  Screenshot
────────────────────────────────────────────────────
/dashboard          ✅      ✅       0 errors  ss_1234
/programme          ✅      ✅       0 errors  ss_1235
/sprint             ✅      ✅       0 errors  ss_1236
/ai-ops             ✅      ✅       0 errors  ss_1237
/architecture       ✅      ✅       0 errors  ss_1238
/chain              ✅      ✅       0 errors  ss_1239
/knowledge          ✅      ✅       0 errors  ss_1240
/stack              ✅      ✅       0 errors  ss_1241
/devops             ✅      ✅       0 errors  ss_1242
/tests              ✅      ✅       0 errors  ss_1243
/infra              ✅      ✅       0 errors  ss_1244
/team               ✅      ✅       0 errors  ss_1245

Results: 12/12 pass (100%) | 0 console errors | 12 screenshots
────────────────────────────────────────────────────
```

### Step 6: Failure Deep-Dive

For any failing route:

```
1. Show screenshot of the failing page
2. List console errors
3. Show page text around error pattern
4. Suggest fix (e.g., "API endpoint returning 302 — check Caddy SSO config")
```

## HITL Gates

- **SSO login**: If auth=authentik-sso, prompt user to complete login in browser
- **Failure > 50%**: "Most routes failing — likely infrastructure issue. Check backend health first?"

## Error Patterns Database

Common error patterns and their likely causes:

| Pattern | Likely Cause | Suggested Fix |
|---------|-------------|---------------|
| "Something went wrong" | React ErrorBoundary caught crash | Check console for TypeError |
| "Failed to fetch" | API endpoint down or CORS | Check backend health + Caddy config |
| "401" / "403" | Auth token expired | Re-authenticate SSO |
| "Network Error" | Backend unreachable | Check docker ps + health endpoint |
| "t.map is not a function" | API returns wrong shape | Check API response format |

## Related

- `browser-automation` — Lower-level browser control
- `api-healthcheck` — API-only testing (no UI)
- `verification` — Full verification pipeline (tests + API + UI)
- `devops-deploy` — Post-deploy QA step
