#!/usr/bin/env bash
# quick-test.sh — Run plugin tests (all or filtered by skill name).
#
# Usage:
#   ./scripts/quick-test.sh             # Run all tests
#   ./scripts/quick-test.sh brainstorm  # Test matching 'brainstorm'
#   ./scripts/quick-test.sh -v          # Verbose mode
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

if [ ! -d "tests" ]; then
  echo "❌ No tests/ directory. Run sync-repos.sh --to-synapse first."
  exit 1
fi

FILTER=""
VERBOSE=""
for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE="-v" ;;
    *) FILTER="-k $arg" ;;
  esac
done

python3 -m pytest tests/ -x -q --tb=short $VERBOSE $FILTER
