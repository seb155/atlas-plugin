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

# Step 1: Bump version
echo "1️⃣  Bump VERSION to ${NEW_VERSION}..."
if ! $DRY_RUN; then
  echo "$NEW_VERSION" > VERSION
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
    python3 -m pytest tests/ -x -q --tb=short
  else
    echo "   [DRY-RUN] Would run: pytest tests/ -x -q --tb=short"
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

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if $DRY_RUN; then
  echo "  DRY RUN complete — ${CURRENT} → ${NEW_VERSION}"
else
  echo "  ✅ Released v${NEW_VERSION}"
  echo "  CI will build + publish to Forgejo Package Registry"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
