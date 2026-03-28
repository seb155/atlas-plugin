#!/usr/bin/env bash
# ATLAS Starship Custom Module — Context alert (conditional)
# Only outputs when context >75%. Empty output = CShip hides the row.
# CShip exports CSHIP_CONTEXT_PCT as env var to Starship modules.
set -euo pipefail

CTX="${CSHIP_CONTEXT_PCT:-0}"
CTX_INT="${CTX%.*}"
[ "${CTX_INT:-0}" -gt 75 ] 2>/dev/null && echo "⚠️ context ${CTX_INT}%"
exit 0
