#!/bin/bash
# ATLAS Hook Library: Portable Python 3 resolver
# Works on Linux, macOS, Windows (Git Bash), WSL2
#
# Usage: source this file early in any hook that needs Python 3
#   . "$(dirname "$0")/lib/python.sh"
#
# Provides:
#   $ATLAS_PYTHON  — path to python3 binary (or "false" if none found)
#   _atlas_py()    — shortcut: _atlas_py -c "import json; ..."

if [ -n "${ATLAS_PYTHON:-}" ]; then
  # Already resolved (e.g. by parent hook)
  :
elif command -v python3 &>/dev/null; then
  ATLAS_PYTHON=python3
elif command -v python &>/dev/null && python --version 2>&1 | grep -q "Python 3"; then
  ATLAS_PYTHON=python
elif command -v py &>/dev/null && py -3 --version &>/dev/null 2>&1; then
  ATLAS_PYTHON="py -3"
else
  ATLAS_PYTHON="false"
fi
export ATLAS_PYTHON

_atlas_py() {
  if [ "$ATLAS_PYTHON" = "false" ]; then
    return 1
  fi
  $ATLAS_PYTHON "$@"
}
