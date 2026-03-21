# Changelog

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


