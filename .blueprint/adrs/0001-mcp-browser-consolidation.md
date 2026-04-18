# ADR 0001 — MCP Browser Consolidation (v6.0)

**Status**: PROPOSED (awaiting Seb HITL approval)
**Date**: 2026-04-17
**Context**: ATLAS v6.0 Sprint 4 dedup initiative (plan Section K)
**Deciders**: Seb Gagnon, Claude Opus 4.7 (plan-architect)
**Supersedes**: none
**Superseded by**: none

## Context

ATLAS v5.x currently exposes **3 overlapping browser/computer automation tools** to skills and agents:

1. **claude-in-chrome** (MCP `mcp__claude-in-chrome__*`) — Chrome extension, interactive sessions, user-visible tabs. Primary tool for visual QA, debugging, site research. Used by 5 skills (browser-automation, visual-qa, product-health, atlas-team, refs).
2. **playwright** (MCP `mcp__plugin_playwright_playwright__*`) — headless cross-browser, scriptable, CI-friendly. Used by 11 skills (verification, tdd, test-orchestrator, product-health, etc.) for E2E test orchestration.
3. **computer-use** (CC native CLI since 2.1.111, Linux/macOS) — native desktop automation, multi-app (not just browser), no MCP overhead. Newer, no adoption in ATLAS skills yet.

**Problem**: 3 tools overlap significantly for browser tasks. Maintenance burden (docs, onboarding, skill fragmentation), cognitive load on skill authors, and drift risk (skills using different tools for same task). Plan v6.0 Sprint 4 mandate: choose **2 max**, log decision to `.claude/decisions.jsonl`.

## Options Evaluated

### Option 1: claude-in-chrome only
- **Pros**: Interactive sessions, user-visible, debugger-friendly, tab/cookie persistence, strong ATLAS adoption (5 skills).
- **Cons**: Chrome-only (no Firefox/Safari), requires extension, not headless, CI-unfriendly, can't run without GUI session.
- **Use cases**: UI development, visual QA, live site research, interactive debugging.

### Option 2: playwright only
- **Pros**: Cross-browser (Chromium/Firefox/WebKit), headless, CI-friendly, scriptable, wide ATLAS adoption (11 skills), mature ecosystem.
- **Cons**: No interactive mode, setup overhead (browsers install), weaker debug UX, no persistent session.
- **Use cases**: E2E tests, automated scraping, CI pipelines, regression testing.

### Option 3: computer-use (CC native)
- **Pros**: Native CC (no MCP overhead), multi-app (not just browser), unified API for desktop flows, future-proof.
- **Cons**: Newer (CC 2.1.111+), Linux/macOS only (no Windows), different API mental model, zero ATLAS skill adoption today, overlap with claude-in-chrome for browser cases.
- **Use cases**: Full desktop automation, multi-app flows (browser + terminal + IDE), non-browser UIs.

## Decision Matrix

| Criterion            | claude-in-chrome | playwright | computer-use |
|----------------------|:----------------:|:----------:|:------------:|
| Interactive          | ✓                | ✗          | ✓            |
| Headless             | ✗                | ✓          | ✗            |
| Cross-browser        | ✗ (Chrome only)  | ✓          | N/A          |
| CI-friendly          | ✗                | ✓          | ✗            |
| Debug-friendly       | ✓                | partial    | ✓            |
| Native CC            | ✗                | ✗          | ✓            |
| Multi-platform       | mac+linux+win    | all        | mac+linux    |
| Multi-app (non-browser)| ✗              | ✗          | ✓            |
| ATLAS skill adoption | 5 skills         | 11 skills  | 0 skills     |
| MCP overhead         | yes              | yes        | no           |
| Overlap source       | computer-use     | standalone | claude-in-chrome |

## Recommendation

**KEEP 2 of 3 — REMOVE `computer-use`** (preferred pair: `claude-in-chrome` + `playwright`).

### Rationale

1. **Coverage complete**: claude-in-chrome handles interactive/visual work; playwright handles headless/CI. Together they cover 100% of documented ATLAS browser use cases.
2. **ATLAS adoption**: 16 skills already use these two tools. Removing either triggers mass migration. Removing computer-use = zero migration.
3. **Browser-first scope**: ATLAS is an AI engineering assistant, not a desktop automation framework. Multi-app desktop flows (email + IDE + terminal) are NOT in the current roadmap.
4. **Platform coverage**: Removing computer-use preserves Windows support (via playwright). Windows onboarding is on the v6.x roadmap (GMS contractors).
5. **Maturity**: computer-use is CC 2.1.111+ and evolving; deferring adoption avoids retooling skills if API stabilizes differently.

### Alternative rejected: `playwright + computer-use`
- Would drop claude-in-chrome — but loses interactive/visual debugging UX (key for visual-qa, product-health). 5 skills need migration.
- Computer-use is too new; betting the interactive tier on it is premature.

### Alternative rejected: `claude-in-chrome + computer-use`
- Drops playwright — 11 skills broken, loses CI headless coverage, breaks verification gates. High-risk.

## Consequences

**If recommendation (claude-in-chrome + playwright) adopted**:

- Tool permissions `mcp__claude-in-chrome__*` and `mcp__plugin_playwright_playwright__*` remain in `settings.json`.
- No skill migration required (zero skills use computer-use today).
- Add deprecation notice to v6.0 `CHANGELOG.md`: "computer-use intentionally NOT adopted in ATLAS v6.0. Revisit in v6.5 if multi-app desktop flows enter roadmap."
- Document the 2-tool decision tree in `skills/refs/external-tools/README.md`: "Interactive/visual → claude-in-chrome. Headless/CI → playwright."
- Update `.blueprint/PATTERNS.md` with browser backend selection heuristic.

**Tradeoffs accepted**:
- No native CC option — all browser work stays MCP-mediated (small latency/overhead).
- If multi-app desktop automation becomes a roadmap priority, revisit and likely add computer-use back as a 3rd tool (not replacement).

## HITL Questions for Seb

1. **Which pair to keep?** (Primary question)
   - A) claude-in-chrome + playwright (recommended, 0 skills migrated)
   - B) playwright + computer-use (drops Chrome MCP, 5 skills migrated)
   - C) claude-in-chrome + computer-use (drops playwright, 11 skills migrated, loses CI)

2. **Multi-app desktop automation on v6.x roadmap?** (If YES → reconsider computer-use sooner.)

3. **Windows support priority for contractors?** (If YES → playwright mandatory; computer-use incompatible.)

4. **CI browser test frequency expectation?** (If daily/per-PR → playwright must stay.)

## Followup Work (if approved)

- [ ] Remove computer-use from `settings.json` permissions (if listed — today not present).
- [ ] Add `.blueprint/PATTERNS.md` section "Browser backend selection" with decision tree.
- [ ] Update `skills/refs/external-tools/README.md` with 2-tool map.
- [ ] Add CHANGELOG entry v6.0.0-alpha: "ADR 0001 — computer-use deferred (see `.blueprint/adrs/0001-mcp-browser-consolidation.md`)".
- [ ] Set calendar reminder: re-evaluate ADR at v6.5 planning (Q2 2027).

## Verification

- `grep -r "mcp__claude-in-chrome" skills/` → 5 files expected (no change post-ADR).
- `grep -r "mcp__plugin_playwright" skills/` → 11 files expected (no change post-ADR).
- `grep -r "computer-use\|computer_use" skills/` → 0 files expected (enforced by this ADR).

---

*See `.claude/decisions.jsonl` entry `adr-0001` for machine-readable record.*
