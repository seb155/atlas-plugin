#!/usr/bin/env bash
# ATLAS Auto-Release — Conventional Commits → SemVer → Tag → Forgejo Release
#
# Portable script for any Forgejo repo using conventional commits.
# Analyzes commits since last tag, determines bump type, creates tag + release.
#
# Usage:
#   ./auto-release.sh                  # normal: bump + tag + push + release
#   ./auto-release.sh --dry-run        # preview what would happen
#   ./auto-release.sh --no-push        # tag locally, don't push
#
# Env vars (for CI):
#   FORGEJO_TOKEN    — API token for creating releases
#   FORGEJO_API_URL  — e.g. http://192.168.10.75:3000/api/v1
#   GITHUB_REPOSITORY — owner/repo (set by Forgejo Actions)
#
# Requirements: git, bash 4+. Optional: curl, python3 (for CHANGELOG).

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────
DRY_RUN=false
NO_PUSH=false
VERSION_FILE=""          # auto-detected: VERSION, package.json, pyproject.toml
CHANGELOG_FILE="CHANGELOG.md"

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --no-push)  NO_PUSH=true ;;
    --help|-h)
      echo "Usage: auto-release.sh [--dry-run] [--no-push]"
      echo "  Analyzes conventional commits since last tag and creates a new release."
      exit 0
      ;;
  esac
done

# ─── Detect last tag ─────────────────────────────────────────────────
# Only consider semver tags (v<major>.<minor>.<patch> [-prerelease]).
# Filters out safety/* backup tags, release-candidates, and custom markers.
LAST_TAG=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
  echo "ℹ️  No previous semver tags found (v<N>.<N>.<N>) — starting from v0.0.0"
  LAST_TAG="v0.0.0"
  COMMIT_RANGE="HEAD"
else
  echo "📌 Last tag: ${LAST_TAG}"
  COMMIT_RANGE="${LAST_TAG}..HEAD"
fi

# ─── Analyze commits ─────────────────────────────────────────────────
COMMITS=$(git log ${COMMIT_RANGE} --format='%s' 2>/dev/null || true)

if [ -z "$COMMITS" ]; then
  echo "ℹ️  No new commits since ${LAST_TAG} — nothing to release."
  exit 0
fi

COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
echo "📊 ${COMMIT_COUNT} commits since ${LAST_TAG}"

# Count commit types
FEAT_COUNT=$(echo "$COMMITS" | grep -cE '^feat(\(|:)' || true)
FIX_COUNT=$(echo "$COMMITS" | grep -cE '^fix(\(|:)' || true)
PERF_COUNT=$(echo "$COMMITS" | grep -cE '^perf(\(|:)' || true)
BREAKING_COUNT=$(echo "$COMMITS" | grep -cE 'BREAKING[ _]CHANGE|^[a-z]+!(\(|:)|^[a-z]+(\([^)]*\))?!:' || true)
CHORE_COUNT=$(echo "$COMMITS" | grep -cE '^(chore|docs|style|refactor|test|build|ci)(\(|:)' || true)

echo "   feat: ${FEAT_COUNT} | fix: ${FIX_COUNT} | perf: ${PERF_COUNT} | breaking: ${BREAKING_COUNT} | other: ${CHORE_COUNT}"

# ─── Determine bump type ─────────────────────────────────────────────
BUMP="patch"
if [ "$FEAT_COUNT" -gt 0 ]; then
  BUMP="minor"
fi
if [ "$BREAKING_COUNT" -gt 0 ]; then
  BUMP="major"
fi

# Skip release if only chore/docs/ci commits (no feat, fix, perf, or breaking)
if [ "$FEAT_COUNT" -eq 0 ] && [ "$FIX_COUNT" -eq 0 ] && [ "$PERF_COUNT" -eq 0 ] && [ "$BREAKING_COUNT" -eq 0 ]; then
  echo "ℹ️  Only non-functional commits (chore/docs/ci). Skipping release."
  exit 0
fi

# ─── Compute next version ────────────────────────────────────────────
CURRENT="${LAST_TAG#v}"
IFS='.' read -r MAJ MIN PAT <<< "$CURRENT"
# Handle empty/non-numeric values
MAJ=${MAJ:-0}; MIN=${MIN:-0}; PAT=${PAT:-0}

case "$BUMP" in
  major) NEW_MAJ=$((MAJ + 1)); NEW_MIN=0;              NEW_PAT=0 ;;
  minor) NEW_MAJ=$MAJ;         NEW_MIN=$((MIN + 1));   NEW_PAT=0 ;;
  patch) NEW_MAJ=$MAJ;         NEW_MIN=$MIN;           NEW_PAT=$((PAT + 1)) ;;
esac

NEXT_VERSION="${NEW_MAJ}.${NEW_MIN}.${NEW_PAT}"
NEXT_TAG="v${NEXT_VERSION}"

# Guard against stale tags from prior versioning schemes (e.g., a leftover
# v0.3.0 from a pre-autorelease era blocks a fresh minor bump). Walk PATCH
# forward until we find a free slot. Checks local refs; CI must have run
# `git fetch --tags` beforehand so local reflects remote tag state.
BUMP_ATTEMPTS=0
while git rev-parse "refs/tags/${NEXT_TAG}" >/dev/null 2>&1; do
  BUMP_ATTEMPTS=$((BUMP_ATTEMPTS + 1))
  if [ "$BUMP_ATTEMPTS" -gt 50 ]; then
    echo "❌ Could not find free tag after 50 PATCH bumps from ${NEW_MAJ}.${NEW_MIN}.x — aborting."
    exit 1
  fi
  echo "⚠️  Tag ${NEXT_TAG} already exists — bumping PATCH to find free slot"
  NEW_PAT=$((NEW_PAT + 1))
  NEXT_VERSION="${NEW_MAJ}.${NEW_MIN}.${NEW_PAT}"
  NEXT_TAG="v${NEXT_VERSION}"
done

echo ""
echo "🏷️  ${LAST_TAG} → ${NEXT_TAG} (${BUMP} bump)"

# ─── Generate release notes ──────────────────────────────────────────
RELEASE_DATE=$(date '+%Y-%m-%d')
RELEASE_NOTES="## ${NEXT_TAG} (${RELEASE_DATE})"$'\n\n'

# Group commits by type
if [ "$BREAKING_COUNT" -gt 0 ]; then
  RELEASE_NOTES+="### ⚠️ Breaking Changes"$'\n'
  while IFS= read -r line; do
    RELEASE_NOTES+="- ${line}"$'\n'
  done <<< "$(echo "$COMMITS" | grep -E 'BREAKING[ _]CHANGE|^[a-z]+(\([^)]*\))?!:' || true)"
  RELEASE_NOTES+=$'\n'
fi

if [ "$FEAT_COUNT" -gt 0 ]; then
  RELEASE_NOTES+="### ✨ Features"$'\n'
  while IFS= read -r line; do
    RELEASE_NOTES+="- ${line}"$'\n'
  done <<< "$(echo "$COMMITS" | grep -E '^feat(\(|:)' || true)"
  RELEASE_NOTES+=$'\n'
fi

if [ "$FIX_COUNT" -gt 0 ]; then
  RELEASE_NOTES+="### 🐛 Bug Fixes"$'\n'
  while IFS= read -r line; do
    RELEASE_NOTES+="- ${line}"$'\n'
  done <<< "$(echo "$COMMITS" | grep -E '^fix(\(|:)' || true)"
  RELEASE_NOTES+=$'\n'
fi

# Other commits (chore, refactor, etc.)
OTHER_COMMITS=$(echo "$COMMITS" | grep -vE '^(feat|fix)(\(|:)|BREAKING' || true)
if [ -n "$OTHER_COMMITS" ]; then
  RELEASE_NOTES+="### 🔧 Other Changes"$'\n'
  while IFS= read -r line; do
    [ -n "$line" ] && RELEASE_NOTES+="- ${line}"$'\n'
  done <<< "$OTHER_COMMITS"
  RELEASE_NOTES+=$'\n'
fi

echo ""
echo "📝 Release notes:"
echo "$RELEASE_NOTES"

if [ "$DRY_RUN" = "true" ]; then
  echo "🔍 DRY RUN — no changes made."
  exit 0
fi

# ─── Update VERSION file (if exists) ─────────────────────────────────
if [ -f "VERSION" ]; then
  echo "$NEXT_VERSION" > VERSION
  echo "📄 Updated VERSION → ${NEXT_VERSION}"
  VERSION_FILE="VERSION"

  # Also update plugin.json if it exists (Claude Code plugin convention)
  PLUGIN_JSON=".claude-plugin/plugin.json"
  if [ -f "$PLUGIN_JSON" ]; then
    python3 -c "
import json
with open('${PLUGIN_JSON}') as f: d = json.load(f)
d['version'] = '${NEXT_VERSION}'
with open('${PLUGIN_JSON}', 'w') as f: json.dump(d, f, indent=2)
f.write('\n')
print('ok')
" && echo "📄 Updated ${PLUGIN_JSON} version → ${NEXT_VERSION}"
    git add "$PLUGIN_JSON"
  fi

  # Also update marketplace.json version (Claude Code marketplace discovery)
  MARKETPLACE_JSON=".claude-plugin/marketplace.json"
  if [ -f "$MARKETPLACE_JSON" ]; then
    python3 -c "
import json
with open('${MARKETPLACE_JSON}') as f: d = json.load(f)
for p in d.get('plugins', []):
    p['version'] = '${NEXT_VERSION}'
with open('${MARKETPLACE_JSON}', 'w') as f: json.dump(d, f, indent=2)
f.write('\n')
print('ok')
" && echo "📄 Updated ${MARKETPLACE_JSON} version → ${NEXT_VERSION}"
    git add "$MARKETPLACE_JSON"
  fi
fi

# Also sync package.json if it exists (even when VERSION file is primary)
if [ -f "package.json" ]; then
  # Update version in package.json using python3 (no jq dependency)
  python3 -c "
import json
with open('package.json') as f: d = json.load(f)
d['version'] = '${NEXT_VERSION}'
with open('package.json', 'w') as f: json.dump(d, f, indent=2)
print('ok')
" && echo "📄 Updated package.json version → ${NEXT_VERSION}"
  [ -z "$VERSION_FILE" ] && VERSION_FILE="package.json"
fi

if [ -f "pyproject.toml" ]; then
  sed -i "s/^version = .*/version = \"${NEXT_VERSION}\"/" pyproject.toml
  echo "📄 Updated pyproject.toml version → ${NEXT_VERSION}"
  VERSION_FILE="pyproject.toml"
fi

# ─── Update CHANGELOG.md ─────────────────────────────────────────────
if [ -f "$CHANGELOG_FILE" ]; then
  # Prepend new entry after first line (usually "# Changelog")
  TEMP_CL=$(mktemp)
  head -1 "$CHANGELOG_FILE" > "$TEMP_CL"
  echo "" >> "$TEMP_CL"
  echo "$RELEASE_NOTES" >> "$TEMP_CL"
  tail -n +2 "$CHANGELOG_FILE" >> "$TEMP_CL"
  mv "$TEMP_CL" "$CHANGELOG_FILE"
  echo "📄 Updated CHANGELOG.md"
else
  # Create new CHANGELOG
  echo "# Changelog" > "$CHANGELOG_FILE"
  echo "" >> "$CHANGELOG_FILE"
  echo "$RELEASE_NOTES" >> "$CHANGELOG_FILE"
  echo "📄 Created CHANGELOG.md"
fi

# ─── Rebuild dist/ so marketplace users get latest plugin content ────
# Without this step, dist/ stays stale when VERSION bumps and marketplace
# users (who pull via git-subdir path) receive the old plugin files.
if [ -x "./build.sh" ]; then
  echo "🏗️  Rebuilding dist/ for marketplace distribution..."
  ./build.sh modular || {
    echo "⚠️  build.sh modular failed — dist/ may be stale"
    # Don't exit: release should proceed even if dist rebuild has issues,
    # the developer can run `./build.sh modular` manually + amend.
  }
fi

# ─── Git commit + tag ─────────────────────────────────────────────────
git add "${CHANGELOG_FILE}"
[ -n "$VERSION_FILE" ] && git add "$VERSION_FILE"
# Stage dist/ so marketplace users always get content matching this VERSION
[ -d "dist" ] && git add dist/

# Only commit if there are staged changes
if ! git diff --cached --quiet; then
  git commit -m "chore(release): ${NEXT_TAG}"
  echo "📦 Committed release changes (VERSION + plugin.json + marketplace.json + CHANGELOG + dist/)"
fi

git tag -a "$NEXT_TAG" -m "Release ${NEXT_TAG}"$'\n\n'"${RELEASE_NOTES}"
echo "🏷️  Created tag ${NEXT_TAG}"

# ─── Push ─────────────────────────────────────────────────────────────
if [ "$NO_PUSH" = "true" ]; then
  echo "⏸️  --no-push: tag created locally. Push manually: git push origin main --tags"
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
# Push commit first ([skip ci] only affects this push)
git push origin "$BRANCH"
echo "🚀 Pushed commit to origin/${BRANCH}"
# Push tag separately so publish.yaml triggers (not affected by [skip ci])
sleep 2
git push origin "$NEXT_TAG"
echo "🏷️  Pushed tag ${NEXT_TAG} to origin"

# ─── Create Forgejo Release (if API available) ───────────────────────
FORGEJO_TOKEN="${FORGEJO_TOKEN:-}"
FORGEJO_API_URL="${FORGEJO_API_URL:-}"
REPO="${GITHUB_REPOSITORY:-}"

# Auto-detect Forgejo API URL from git remote
if [ -z "$FORGEJO_API_URL" ]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  if echo "$REMOTE_URL" | grep -q "192.168.10.75:3000"; then
    FORGEJO_API_URL="http://192.168.10.75:3000/api/v1"
  elif echo "$REMOTE_URL" | grep -q "forgejo"; then
    # Extract base URL from remote
    BASE=$(echo "$REMOTE_URL" | sed -E 's|^https?://([^/]+)/.*|\1|' | sed 's|\.git$||')
    [ -n "$BASE" ] && FORGEJO_API_URL="https://${BASE}/api/v1"
  fi
fi

# Auto-detect repo from git remote
if [ -z "$REPO" ]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  REPO=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+/[^/]+?)(\.git)?$|\1|')
fi

if [ -n "$FORGEJO_TOKEN" ] && [ -n "$FORGEJO_API_URL" ] && [ -n "$REPO" ]; then
  # Escape release notes for JSON
  ESCAPED_NOTES=$(printf '%s' "$RELEASE_NOTES" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

  HTTP_CODE=$(curl -sf -o /dev/null -w '%{http_code}' \
    -X POST "${FORGEJO_API_URL}/repos/${REPO}/releases" \
    -H "Authorization: token ${FORGEJO_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"tag_name\": \"${NEXT_TAG}\",
      \"name\": \"${NEXT_TAG}\",
      \"body\": ${ESCAPED_NOTES},
      \"draft\": false,
      \"prerelease\": false
    }" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "201" ]; then
    echo "🎉 Forgejo Release created: ${NEXT_TAG}"
  else
    echo "⚠️  Forgejo Release API returned ${HTTP_CODE} (tag pushed but release not created)"
  fi
else
  echo "ℹ️  Skipping Forgejo Release (no FORGEJO_TOKEN or API URL detected)"
fi

echo ""
echo "✅ Released ${NEXT_TAG} (${BUMP})"
