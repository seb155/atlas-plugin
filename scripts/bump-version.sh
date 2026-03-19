#!/usr/bin/env bash
# Bump semver version in VERSION file and create a git tag.
# Usage: ./scripts/bump-version.sh <major|minor|patch>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="${ROOT_DIR}/VERSION"

COMPONENT="${1:-}"

if [[ -z "$COMPONENT" ]]; then
  echo "Usage: $0 <major|minor|patch>"
  exit 1
fi

if [[ ! "$COMPONENT" =~ ^(major|minor|patch)$ ]]; then
  echo "Error: component must be one of: major, minor, patch"
  exit 1
fi

CURRENT=$(cat "$VERSION_FILE" | tr -d '[:space:]')

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$COMPONENT" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "${NEW_VERSION}" > "$VERSION_FILE"

cd "$ROOT_DIR"
git add VERSION
git commit -m "chore(release): bump version ${CURRENT} → ${NEW_VERSION}"
git tag "v${NEW_VERSION}"

echo "${NEW_VERSION}"
