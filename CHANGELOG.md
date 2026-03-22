# Changelog

## v3.19.1 (2026-03-22)

### 🐛 Bug Fixes
- fix: assign frontend-workflow and test-orchestrator to dev tier

### 🔧 Other Changes
- docs: add .blueprint/ + rules + memory for AI maintainability



## v3.19.0 (2026-03-22)

### ✨ Features
- feat(onboarding,doctor): add Opus 4.6 CC settings validation (15 checks)



## v3.18.1 (2026-03-22)

### 🐛 Bug Fixes
- fix(build): add Forgejo repo URL to marketplace.json source



## v3.18.0 (2026-03-22)

### ✨ Features
- feat(statusline): dynamic version from CC marketplace registry



## v3.17.0 (2026-03-22)

### ✨ Features
- feat(skills): add test-orchestrator skill + gitignore pycache



## v3.16.0 (2026-03-22)

### ✨ Features
- feat(hooks): add version check notification on session start

### 🔧 Other Changes
- refactor(tests): replace hardcoded count thresholds with structural checks



## v3.15.2 (2026-03-22)

### 🐛 Bug Fixes
- fix(ci): replace hardcoded skill count gates with structural checks
- fix(release): auto-sync marketplace.json + plugin.json + VERSION on release



## v3.15.1 (2026-03-22)

### 🐛 Bug Fixes
- fix(release): auto-release now updates plugin.json version



## v3.15.0 (2026-03-22)

### ✨ Features
- feat(skills): add frontend-workflow skill + UX architecture gate



## v3.14.0 (2026-03-22)

### ✨ Features
- feat(hooks): add code-quality-check hook for dead imports and antipatterns

### 🔧 Other Changes
- chore(release): bump to v3.14.0 — sync marketplace + plugin.json versions [skip ci]



## v3.13.1 (2026-03-22)

### 🐛 Bug Fixes
- fix(ci): split workflow into ci.yaml + publish.yaml — fixes false failure status from skipped publish job



## v3.13.0 (2026-03-22)

### ✨ Features
- feat(pickup): search .blueprint/handoffs/ first, sort by date DESC, add Age column and priority indicators



## v3.12.0 (2026-03-21)

### ✨ Features
- feat(setup): add showClearContextOnPlanAccept validation to onboarding + doctor



## v3.11.2 (2026-03-21)

### 🐛 Bug Fixes
- fix(hooks): make async atlas-status-writer resilient to transient errors



## v3.11.1 (2026-03-21)

### 🐛 Bug Fixes
- fix(hooks): remove 'local' keyword outside function in atlas-status-writer

### 🔧 Other Changes
- test(hooks): validate hook file references in dist/ build artifacts



## v3.11.0 (2026-03-21)

### ✨ Features
- feat(plugin): add youtube-transcript skill + ci command + gitignore pycache



## v3.10.0 (2026-03-21)

### ✨ Features
- feat(tests): add smoke/strict test levels — CI skips strict by default



## v3.9.0 (2026-03-21)

### ✨ Features
- feat(ci): add build artifact caching between jobs
- feat(plugin): add /atlas ci command + CI integration

### 🐛 Bug Fixes
- fix(ci): use H1 heading pattern instead of skill reference in ci.md
- fix(ci): add backticks to invoke pattern in ci.md (test compat)
- fix(ci): remove template vars from ci.md command (test compat)

### 🔧 Other Changes
- revert(ci): remove actions/cache — incompatible with manual git clone



## v3.8.0 (2026-03-21)

### ✨ Features
- feat(ci): custom ci-atlas Docker image + simplified workflow



## v3.7.0 (2026-03-21)

### ✨ Features
- feat(hooks): add /rename suggestion with repo-version-branch in session-start
- feat(ci): add auto-release — conventional commits → SemVer → tag → Forgejo release
- feat(plugin): auto-unlock vault via keyring + punycode fix in session-start

### 🐛 Bug Fixes
- fix(ci): remove silent pip error suppression for better debug
- fix(ci): use ATLAS_FORGEJO_TOKEN for all jobs — GITHUB_TOKEN insufficient
- fix(ci): revert to GITHUB_TOKEN for build/test, use ATLAS_FORGEJO_TOKEN for release/publish
- fix(ci): add --break-system-packages for PEP 668 (Python 3.12+ in Ubuntu)
- fix(ci): use FORGEJO_TOKEN for git clone auth (GITHUB_TOKEN insufficient)
- fix(plugin): keyring dead code + secret management rules + require-secrets

### 🔧 Other Changes
- ci: trigger auto-release test (empty commit)


