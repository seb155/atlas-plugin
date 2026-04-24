# ADR-005 — Distribution Sovereignty via Forgejo NPM Packages

**Status**: ACCEPTED (2026-04-18)
**Context**: ATLAS CLI SOTA Refactor (v5.28.0) — public distribution strategy
**Decision-makers**: Seb Gagnon
**Related**: ADR-004 Profile-First Architecture

## Context

ATLAS CLI was previously distributed internal-only via `make dev` (git clone + Makefile). For external users (AXOIQ contractors, G Mining MSEs, future public customers), we need a production distribution channel.

Options evaluated:

1. **NPM via GitHub Packages** (`@axoiq` scope on `npm.pkg.github.com`)
2. **NPM via Forgejo Packages** (self-hosted `forgejo.axoiq.com`)
3. **Curl one-liner installer** (static hosting + shell script)
4. **Homebrew formula** (macOS+Linux package manager)
5. **Keep `make dev`** (clone-only, no public distribution)

## Decision

**Primary: NPM via Forgejo Packages (self-hosted)**
**Retained: `make dev` for internal development**

Sovereignty-first rationale:
- Self-hosted infrastructure (Forgejo already running at `forgejo.axoiq.com`)
- Zero dependency on GitHub infrastructure
- AXOIQ owns the distribution channel (control, audit, compliance)
- Registry confirmed active (HTTP 405 GET+PUT on `/api/packages/axoiq/npm/@axoiq/atlas-cli`)

Implementation:
- Package: `@axoiq/atlas-cli` scope
- Registry URL: `https://forgejo.axoiq.com/api/packages/axoiq/npm/`
- User `.npmrc` required: scope + auth token (Forgejo PAT `read_package`)
- Publish: `scripts/publish.sh minor` extended with `npm publish` step (P6.3 Option A)

### Why NOT npm public (`npmjs.com`)
- Public distribution not desired yet (AXOIQ internal + contracted users only)
- Would require scope verification + compliance (trademark, DMCA, etc.)
- Loss of access control granularity

### Why NOT GitHub Packages
- Dependency on GitHub infrastructure (antithetical to sovereignty goal)
- Auth tokens coupled to GitHub accounts, not AXOIQ identity
- Already have Forgejo running at forgejo.axoiq.com

### Why NOT Homebrew (yet)
- Premature for beta stage
- Requires stable, versioned releases + tap maintenance
- Consider in Phase 3 (6+ months of feedback)

### Why NOT curl installer (as primary)
- Retained as future option for non-dev audiences (G Mining MSEs)
- Current: npm handles version management, updates, uninstall automatically
- Curl adds custom parsing for versions, updates = reinvention

## Consequences

### Positive
- **AXOIQ sovereign** — all distribution infrastructure in AXOIQ-controlled Forgejo
- **Semver native** — `npm update -g`, `@5.28.0` pinning, outdated detection
- **Automation** — `publish.sh minor` atomically: bump + build + test + commit + tag + push + npm publish
- **User familiarity** — npm is standard for JS/Node devs (which ATLAS users likely are)
- **Zero infrastructure cost** — Forgejo already running
- **Private by default** — `publishConfig.access: restricted`, PAT required

### Negative
- **Requires Forgejo PAT** — extra setup step for new users (mitigated by INSTALL.md)
- **npm install requires Node ≥18** — minor dep, but present on most dev machines
- **Postinstall hook** — copies bash files via Node script (slight complexity vs native bash install)
- **No anonymous install** — can't `curl | bash` without auth

### Neutral
- **make dev preserved** — internal dev + contributors unchanged
- **2-release transition** — both paths supported (no forced migration)

## Fallback Strategy

If Forgejo npm registry fails or access becomes problematic:

**Backup**: Activate GitHub Packages `@axoiq` scope (pattern already proven by `@hcengineering` config in `.npmrc`). Migration would be:
1. Create GitHub Packages registry for `@axoiq`
2. Update `publishConfig.registry` in package.json
3. Publish to both registries during transition
4. Update INSTALL.md with both options
5. Users pick based on their auth setup

This fallback is NOT activated — keeping sovereignty-first unless Forgejo becomes unviable.

## Rollout Plan

- **v5.28.0** (this release): NPM publish enabled via `publish.sh`. User-facing install docs published.
- **v5.29.0+**: First publish attempt, monitor adoption + issues.
- **v5.30.0**: Deprecate `make dev` for non-dev users (keep for contributors).
- **v6.0.0+** (6+ months): Evaluate Homebrew tap if public release justified.

## References

- Plan: `.blueprint/plans/regarde-cest-quoi-atlas-snoopy-unicorn.md` (C.3 Sovereignty-First Distribution)
- Decision log: D4 (2026-04-18)
- P6.1 investigation: Forgejo npm registry confirmed active via HTTP 405 GET+PUT
- Pattern reference: `.npmrc` existing `@hcengineering:registry=https://npm.pkg.github.com` (Huly)
- Implementation: `package.json`, `scripts/postinstall.js`, `scripts/publish.sh` extended (P6.2+P6.3)
- Docs: [INSTALL.md](../INSTALL.md), [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md)
