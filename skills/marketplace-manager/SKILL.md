---
name: marketplace-manager
description: "Manage Claude Code plugin marketplaces — diagnose schema errors, add/remove marketplaces, sync cache, manage plugin scopes. Use when 'marketplace', 'plugin install', 'plugin error', '/plugin broken', 'marketplace refresh'."
effort: low
---

# CC Plugin Marketplace Manager

Diagnose and fix Claude Code plugin marketplace issues. Knowledge base for CC's marketplace internals.

## When to Use

- User reports `/plugin` errors (schema, cache, auth)
- Adding/removing custom marketplaces (Forgejo, GitLab, etc.)
- Changing plugin scope (user vs project)
- Marketplace refresh/sync problems
- Setting up marketplace for new machines

## CC Marketplace Architecture

```
known_marketplaces.json (registry)
  ├── source: github → git clone to ~/.claude/plugins/marketplaces/{name}/
  ├── source: directory → read local dir
  └── source: url → HTTP GET raw JSON → cache to ~/.claude/plugins/cache/{name}/

installed_plugins.json (install records)
  ├── scope: "user" → all sessions globally
  └── scope: "project" → only that project

settings.json (enablement)
  ├── ~/.claude/settings.json → user-level (all sessions)
  └── {project}/.claude/settings.json → project-level
```

## Key Files

| File | Purpose |
|------|---------|
| `~/.claude/plugins/known_marketplaces.json` | Registry: key → {source, installLocation, lastUpdated, autoUpdate} |
| `~/.claude/plugins/installed_plugins.json` | Per-plugin: scope, version, installPath, gitCommitSha |
| `~/.claude/plugins/cache/{marketplace}/marketplace.json` | Cached marketplace manifest (name MUST match registry key) |
| `~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/` | Actual plugin content |
| `~/.claude/plugins/marketplaces/{name}/` | Git-cloned marketplace (github source only) |

## Plugin Source Types (in marketplace.json `plugins[].source`)

| Type | Format | Use case |
|------|--------|----------|
| relative | `"./plugins/name"` | Monorepo subdir |
| github | `{"source":"github","repo":"owner/repo"}` | GitHub repos |
| url | `{"source":"url","url":"https://...git"}` | Any git host (Forgejo, GitLab, Gitea) |
| git-subdir | `{"source":"git-subdir","url":"...","path":"..."}` | Subdir in a git repo |
| npm | `{"source":"npm","package":"@org/pkg"}` | npm registry |

## Marketplace Source Types (in known_marketplaces.json)

| Type | How CC loads | installLocation |
|------|-------------|-----------------|
| github | `git clone` to installLocation | `~/.claude/plugins/marketplaces/{name}/` |
| directory | Read local `.claude-plugin/marketplace.json` | The directory path itself |
| url | HTTP GET the URL, parse response as JSON | `~/.claude/plugins/marketplaces/{name}/` (CC-managed) |

**CRITICAL**: `url` source does HTTP GET and expects raw JSON response. NOT a git URL. Use raw file endpoints (e.g., Forgejo raw, CF proxy, API endpoint).

## Schema Rules (CRITICAL — CC validates strictly)

1. `known_marketplaces.json` entry REQUIRES:
   - `source` (object with `source` type + params)
   - `installLocation` (string, MUST be under `~/.claude/plugins/marketplaces/`)
   - `lastUpdated` (ISO 8601 string)

2. `marketplace.json` `name` field **MUST exactly match** the key in `known_marketplaces.json`

3. Plugin `source` field must be an **object** `{"source":"url","url":"..."}`, never a plain string (except relative paths like `"./plugins/foo"`)

## Diagnostic Workflow

When user reports marketplace errors, run these checks IN ORDER:

### Step 1: Check known_marketplaces.json
```bash
cat ~/.claude/plugins/known_marketplaces.json | python3 -m json.tool
# Verify: installLocation, lastUpdated present
# Verify: installLocation starts with ~/.claude/plugins/marketplaces/
```

### Step 2: Check cache marketplace.json
```bash
cat ~/.claude/plugins/cache/{MARKETPLACE_NAME}/marketplace.json | python3 -m json.tool
# Verify: "name" field matches the key in known_marketplaces.json EXACTLY
# If mismatch → root cause of "expected object, received string" error
```

### Step 3: Test source URL
```bash
# For url sources — verify the URL returns valid JSON
curl -s {SOURCE_URL} | python3 -m json.tool
# Check: HTTP 200, valid JSON, correct name field
```

### Step 4: Check installed_plugins.json
```bash
grep -A8 '{PLUGIN_NAME}@{MARKETPLACE}' ~/.claude/plugins/installed_plugins.json
# Verify: scope is correct (user vs project)
# Verify: installPath exists
# Verify: version matches what you expect
```

### Step 5: Check enabledPlugins in settings
```bash
grep -r '{PLUGIN_NAME}@{MARKETPLACE}' ~/.claude/settings.json
grep -r '{PLUGIN_NAME}@{MARKETPLACE}' .claude/settings.json
# For user-scope: should be in ~/.claude/settings.json
# For project-scope: should be in {project}/.claude/settings.json
```

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "corrupted installLocation" | Path outside `~/.claude/plugins/marketplaces/` | Set installLocation to `~/.claude/plugins/marketplaces/{name}` |
| "expected object, received string" | Cache `marketplace.json` name mismatch with registry key | Purge cache + re-add marketplace via `/plugin` |
| "Invalid marketplace schema from URL" | URL returns HTML/git instead of JSON; OR missing required fields | Use raw JSON URL (CF proxy, Forgejo raw API) |
| Plugin not loading in new sessions | Scope is `project` not `user` | Re-install with user scope via `/plugin` |
| "Failed to refresh marketplace" | Auth failure on source URL | Check git config extraheader / CF proxy / token |

## Fix Procedure (Clean Re-add)

**NEVER manually edit cache files.** Always use the CC `/plugin` workflow:

1. **Remove marketplace**: `/plugin` → Marketplaces → {name} → Remove
2. **Purge stale cache**: `rm -rf ~/.claude/plugins/cache/{name}/marketplace.json`
3. **Re-add marketplace**: `/plugin` → Add marketplace → URL → enter the raw JSON URL
4. **Install plugin**: `/plugin` → Browse → {plugin} → Install (choose user scope)
5. **Verify**: New CC session in a different project → plugin loads

## ATLAS-Specific Config (Forgejo Direct)

| Component | URL/Path |
|-----------|----------|
| Marketplace JSON | `https://forgejo.axoiq.com/atlas/atlas-plugin/raw/branch/main/.claude-plugin/marketplace.json` |
| Plugin git source | `https://forgejo.axoiq.com/atlas/atlas-plugin.git` |
| Git auth | `git config --global http.extraheader` + URL rewrite (CF Access + Forgejo PAT) |
| CF Access secrets | `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`, `FORGEJO_TOKEN` |

### Setup on New Machine

```bash
# 1. Git auth for Forgejo (required for plugin git clone)
git config --global http.https://forgejo.axoiq.com/.extraheader "CF-Access-Client-Id: <ID>"
git config --global --add http.https://forgejo.axoiq.com/.extraheader "CF-Access-Client-Secret: <SECRET>"
git config --global url."https://atlas:<FORGEJO_TOKEN>@forgejo.axoiq.com/".insteadOf "https://forgejo.axoiq.com/"

# 2. Add marketplace in CC
# /plugin → Add marketplace → URL → https://forgejo.axoiq.com/atlas/atlas-plugin/raw/branch/main/.claude-plugin/marketplace.json

# 3. Install plugin with user scope
# /plugin → Browse → atlas-admin → Install → User scope

# 4. Enable globally
# Verify ~/.claude/settings.json has: "atlas-admin@atlas-admin-marketplace": true
```
