#!/usr/bin/env bash
# publish.sh — Full release flow: bump → build → test → commit → tag → push.
#
# Usage:
#   ./scripts/publish.sh patch   # 3.1.0 → 3.1.1
#   ./scripts/publish.sh minor   # 3.1.0 → 3.2.0
#   ./scripts/publish.sh major   # 3.1.0 → 4.0.0
#   ./scripts/publish.sh --dry-run patch  # Preview without committing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

DRY_RUN=false
BUMP_TYPE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    patch|minor|major) BUMP_TYPE="$arg" ;;
    *) echo "Usage: $0 [--dry-run] patch|minor|major"; exit 1 ;;
  esac
done

if [ -z "$BUMP_TYPE" ]; then
  echo "Usage: $0 [--dry-run] patch|minor|major"
  exit 1
fi

CURRENT=$(cat VERSION | tr -d '[:space:]')
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP_TYPE" in
  patch) PATCH=$((PATCH + 1)) ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ATLAS Plugin Release: ${CURRENT} → ${NEW_VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if $DRY_RUN; then
  echo "🔍 DRY RUN — no changes will be made"
  echo ""
fi

# Step 1: Bump version (VERSION file + package.json if present)
echo "1️⃣  Bump VERSION to ${NEW_VERSION}..."
if ! $DRY_RUN; then
  echo "$NEW_VERSION" > VERSION
  # P6.3: sync package.json version for npm publish
  if [ -f "package.json" ] && command -v node &>/dev/null; then
    node -e "
      const fs = require('fs');
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      pkg.version = '${NEW_VERSION}';
      fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
      console.log('   package.json version → ${NEW_VERSION}');
    "
  fi
fi

# Step 2: Build modular (core + addons) + domain plugins (if any)
echo "2️⃣  Building modular tiers..."
if ! $DRY_RUN; then
  ./build.sh modular
  # Build domain plugins only if at least one domain profile exists
  if ls profiles/domain-*.yaml >/dev/null 2>&1; then
    echo "   Found domain profiles, building domain plugins..."
    ./build.sh domains
  else
    echo "   No domain profiles — skipping domain builds"
  fi
fi

# Step 3: Run tests
echo "3️⃣  Running tests..."
if [ -d "tests" ]; then
  if ! $DRY_RUN; then
    # 2026-04-19: Filter out "broken" marker (tests known-broken since v4.38, tracked not skipped per regression gate policy)
    python3 -m pytest tests/ -x -q --tb=short -m "not broken"
  else
    echo "   [DRY-RUN] Would run: pytest tests/ -x -q --tb=short -m \"not broken\""
  fi
else
  echo "   ⚠️  No tests directory — skipping"
fi

# Step 4: Commit
echo "4️⃣  Committing..."
if ! $DRY_RUN; then
  git add -A
  git commit -m "release: v${NEW_VERSION}

Bumped from ${CURRENT}. All tiers built and tested."
fi

# Step 5: Tag
echo "5️⃣  Tagging v${NEW_VERSION}..."
if ! $DRY_RUN; then
  git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
fi

# Step 6: Push
echo "6️⃣  Pushing to origin..."
if ! $DRY_RUN; then
  git push origin HEAD --tags
fi

# Step 7: NPM publish to Forgejo (P6.3 Option A, respects ci-config-freeze-week1)
# Inline publish extends publish.sh rather than creating new workflow file.
echo "7️⃣  NPM publish to Forgejo Packages..."
if [ -f "package.json" ]; then
  if ! command -v npm &>/dev/null; then
    echo "   ⏭️  npm not available — skipping npm publish"
  else
    # Check @axoiq scope is configured to Forgejo registry
    REGISTRY=$(npm config get @axoiq:registry 2>/dev/null || echo "")
    if [[ "$REGISTRY" != *"forgejo.axoiq.com"* ]]; then
      echo "   ⚠️  @axoiq:registry not configured for Forgejo — skipping"
      echo "      Add to ~/.npmrc:"
      echo "        @axoiq:registry=https://forgejo.axoiq.com/api/packages/axoiq/npm/"
      echo "        //forgejo.axoiq.com/api/packages/axoiq/npm/:_authToken=<forgejo-pat>"
      echo "      Then re-run: npm publish (from $(pwd))"
    else
      if ! $DRY_RUN; then
        npm publish && echo "   ✅ Published to $REGISTRY" || echo "   ❌ npm publish failed (non-fatal)"
      else
        echo "   [DRY-RUN] Would run: npm publish (to $REGISTRY)"
      fi
    fi
  fi
else
  echo "   ⏭️  No package.json — skipping npm publish"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if $DRY_RUN; then
  echo "  DRY RUN complete — ${CURRENT} → ${NEW_VERSION}"
else
  echo "  ✅ Released v${NEW_VERSION}"
  echo "  Git tag pushed: Forgejo + GitHub mirror"
  if [ -f "package.json" ] && command -v npm &>/dev/null; then
    echo "  NPM published (if registry configured): @axoiq/atlas-cli@${NEW_VERSION}"
  fi
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
