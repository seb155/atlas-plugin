#!/usr/bin/env bash
# scripts/statusline/doctor.sh — 8-level audit of the ATLAS status line
#
# SP-STATUSLINE-SOTA-V3 Sprint C (L5).
#
# Diagnoses the most common failure modes seen during the 2026-04-25
# forensic session, plus drift detection between deployed artifacts and
# the plugin source.
#
# Usage:
#   bash doctor.sh                  # full audit, human-readable
#   bash doctor.sh --json           # machine-readable JSON for /atlas doctor integration
#   bash doctor.sh --fix            # suggest commands; do NOT auto-execute
#   bash doctor.sh --quiet          # only print failures (CI mode)
#
# Exit codes:
#   0  all 8 checks pass (HEALTHY)
#   1  one or more checks failed (DEGRADED) — see output for details
#   2  critical: statusline cannot render at all (renderer missing or settings broken)

set -uo pipefail

# ─── Args ──────────────────────────────────────────────────────────────
JSON=false
FIX=false
QUIET=false
while [ $# -gt 0 ]; do
    case "$1" in
        --json)    JSON=true ;;
        --fix)     FIX=true ;;
        --quiet)   QUIET=true ;;
        -h|--help)
            sed -n '/^# Usage:/,/^# Exit codes:/p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
    shift
done

# ─── Paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"   # scripts/
TARGET="${ATLAS_STATUSLINE_TARGET:-$HOME/.local/share/atlas-statusline}"
CAPS="${ATLAS_DIR:-$HOME/.atlas}/runtime/capabilities.json"
SETTINGS_LOCAL="$HOME/.claude/settings.local.json"
SETTINGS="$HOME/.claude/settings.json"

# ─── Result accumulator ────────────────────────────────────────────────
TOTAL=0
PASSED=0
FAILED=0
declare -a RESULTS_NAME
declare -a RESULTS_STATUS  # ok|fail|warn
declare -a RESULTS_DETAIL
declare -a RESULTS_FIX

record() {
    local name="$1" status="$2" detail="$3" fix="${4:-}"
    TOTAL=$((TOTAL+1))
    RESULTS_NAME+=("$name")
    RESULTS_STATUS+=("$status")
    RESULTS_DETAIL+=("$detail")
    RESULTS_FIX+=("$fix")
    case "$status" in
        ok)   PASSED=$((PASSED+1)) ;;
        fail) FAILED=$((FAILED+1)) ;;
    esac
}

# ─── Check 1: Tools ────────────────────────────────────────────────────
check_tools() {
    local missing=()
    for t in cship jq starship; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        local versions
        versions="cship $(cship help 2>&1 | head -1 | grep -oE 'v[0-9.]+' || echo '?'),"
        versions+=" jq $(jq --version | sed 's/^jq-//'),"
        versions+=" starship $(starship --version 2>&1 | head -1 | awk '{print $2}')"
        record "Tools" "ok" "$versions"
    else
        record "Tools" "fail" "missing: ${missing[*]}" "sudo apt install ${missing[*]}"
    fi
}

# ─── Check 2: Settings ─────────────────────────────────────────────────
check_settings() {
    local cmd_local=""
    [ -f "$SETTINGS_LOCAL" ] && cmd_local=$(jq -r '.statusLine.command // ""' "$SETTINGS_LOCAL" 2>/dev/null)
    local cmd_main=""
    [ -f "$SETTINGS" ] && cmd_main=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null)

    if [ -n "$cmd_local" ]; then
        # Expand $HOME if literal
        local resolved="${cmd_local/\$HOME/$HOME}"
        if [ -x "$resolved" ]; then
            record "Settings" "ok" "settings.local.json statusLine → $cmd_local"
        else
            record "Settings" "fail" "command path is set but not executable: $resolved" \
                "bash $SOURCE_DIR/statusline/install.sh --auto"
        fi
    elif [ -n "$cmd_main" ]; then
        record "Settings" "warn" "statusLine in settings.json (not .local.json) — vulnerable to dotfile sync overwrite" \
            "bash $SOURCE_DIR/statusline/install.sh --auto  # migrates to settings.local.json"
    else
        record "Settings" "fail" "no statusLine.command configured anywhere" \
            "bash $SOURCE_DIR/statusline/install.sh"
    fi
}

# ─── Check 3: Wrapper deployed ─────────────────────────────────────────
check_wrapper() {
    local wrapper="$TARGET/statusline-wrapper.sh"
    if [ ! -f "$wrapper" ]; then
        record "Wrapper" "fail" "not deployed at $wrapper" \
            "bash $SOURCE_DIR/statusline/install.sh"
        return
    fi
    if [ ! -x "$wrapper" ]; then
        record "Wrapper" "fail" "not executable: $wrapper" "chmod +x $wrapper"
        return
    fi
    local md5_target md5_source
    md5_target=$(md5sum "$wrapper" | cut -d' ' -f1)
    md5_source=$(md5sum "$SOURCE_DIR/statusline-wrapper.sh" 2>/dev/null | cut -d' ' -f1)
    if [ -n "$md5_source" ] && [ "$md5_target" != "$md5_source" ]; then
        record "Wrapper" "warn" "md5 mismatch with source (target ${md5_target:0:8} vs source ${md5_source:0:8})" \
            "bash $SOURCE_DIR/statusline/install.sh --auto"
    else
        record "Wrapper" "ok" "$wrapper  md5=${md5_target:0:8}"
    fi
}

# ─── Check 4: capabilities.json fresh ──────────────────────────────────
check_capabilities() {
    if [ ! -f "$CAPS" ]; then
        record "Capabilities" "fail" "$CAPS missing" \
            "bash $SOURCE_DIR/atlas-discover-addons.sh"
        return
    fi
    local v
    v=$(jq -r '.version // "?"' "$CAPS" 2>/dev/null)
    if [ "$v" = "?" ]; then
        record "Capabilities" "fail" ".version is '?' — discover did not resolve" \
            "bash $SOURCE_DIR/atlas-discover-addons.sh"
    else
        local computed_at
        computed_at=$(jq -r '.computed_at // empty' "$CAPS" 2>/dev/null)
        record "Capabilities" "ok" ".version=$v  computed=$computed_at"
    fi
}

# ─── Check 5: cship.toml present and valid ─────────────────────────────
check_cship_toml() {
    local toml="$HOME/.config/cship.toml"
    if [ ! -f "$toml" ]; then
        record "cship.toml" "warn" "$toml missing — cship will use built-in defaults"
        return
    fi
    if ! grep -q 'ATLAS\|atlas' "$toml" 2>/dev/null; then
        record "cship.toml" "warn" "config exists but contains no ATLAS-specific blocks"
        return
    fi
    local count
    count=$(grep -c '\[custom\.atlas' "$toml" 2>/dev/null || echo 0)
    record "cship.toml" "ok" "$count [custom.atlas_*] blocks present"
}

# ─── Check 6: starship.toml fragment merged (optional) ─────────────────
check_starship_fragment() {
    local toml="$HOME/.config/starship.toml"
    if [ ! -f "$toml" ]; then
        record "starship.toml" "warn" "$toml missing (optional — cship can stand alone)"
        return
    fi
    if grep -q 'custom\.atlas' "$toml" 2>/dev/null; then
        record "starship.toml" "ok" "ATLAS fragment merged"
    else
        record "starship.toml" "warn" "starship.toml exists but no [custom.atlas*] blocks"
    fi
}

# ─── Check 7: Mock render (E2E) ────────────────────────────────────────
check_mock_render() {
    local wrapper="$TARGET/statusline-wrapper.sh"
    if [ ! -x "$wrapper" ]; then
        record "Mock render" "fail" "wrapper not executable — cannot test render"
        return
    fi
    local mock='{"model":{"id":"claude-opus-4-7","display_name":"Opus"},"context_window":{"used_percentage":42,"context_window_size":1000000},"workspace":{"current_dir":"/tmp"},"effort":{"level":"high"},"rate_limits":{"five_hour":{"used_percentage":12}}}'
    local rendered
    rendered=$(echo "$mock" | "$wrapper" 2>&1)
    local stripped
    stripped=$(printf '%s' "$rendered" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')

    if [ -z "$stripped" ]; then
        record "Mock render" "fail" "wrapper produced empty output"
    elif [[ "$stripped" =~ ATLAS\ \?\  ]] || [[ "$stripped" =~ ATLAS\ \?$ ]]; then
        record "Mock render" "fail" "render contains bare 'ATLAS ?' — version unresolvable" \
            "bash $SOURCE_DIR/atlas-discover-addons.sh"
    elif [[ "$stripped" == *"unresolvable"* ]]; then
        record "Mock render" "warn" "render uses honest fallback (?-unresolvable) — degraded but designed" \
            "bash $SOURCE_DIR/atlas-discover-addons.sh"
    else
        record "Mock render" "ok" "${stripped:0:100}"
    fi
}

# ─── Check 8: Drift between deployed and source ────────────────────────
check_drift() {
    local manifest="$TARGET/.install-manifest"
    if [ ! -f "$manifest" ]; then
        record "Drift" "warn" "$manifest missing — installer was never run"
        return
    fi
    # Compare each deployed file against its source
    local drift=0 total=0
    for f in statusline-wrapper.sh atlas-resolve-version.sh; do
        if [ -f "$TARGET/$f" ] && [ -f "$SOURCE_DIR/$f" ]; then
            total=$((total+1))
            local md5_t md5_s
            md5_t=$(md5sum "$TARGET/$f" | cut -d' ' -f1)
            md5_s=$(md5sum "$SOURCE_DIR/$f" | cut -d' ' -f1)
            [ "$md5_t" != "$md5_s" ] && drift=$((drift+1))
        fi
    done
    if [ "$drift" -eq 0 ]; then
        record "Drift" "ok" "$total/$total deployed files match source"
    else
        record "Drift" "warn" "$drift/$total files diverge from source — re-run install.sh" \
            "bash $SOURCE_DIR/statusline/install.sh --auto"
    fi
}

# ─── Render output ─────────────────────────────────────────────────────
render_human() {
    [ "$QUIET" = false ] && echo "🏛️ ATLAS Status Line Diagnostic"
    [ "$QUIET" = false ] && echo "─────────────────────────────────"
    [ "$QUIET" = false ] && echo ""

    local i
    for i in $(seq 0 $((TOTAL-1))); do
        local n="${RESULTS_NAME[$i]}"
        local s="${RESULTS_STATUS[$i]}"
        local d="${RESULTS_DETAIL[$i]}"
        local f="${RESULTS_FIX[$i]}"
        local sym col
        case "$s" in
            ok)   sym="✓"; col='\033[32m' ;;
            warn) sym="⚠"; col='\033[33m' ;;
            fail) sym="✗"; col='\033[31m' ;;
        esac
        if [ "$QUIET" = true ] && [ "$s" = "ok" ]; then continue; fi
        printf "  ${col}%s %d. %-15s${col}\033[0m  %s\n" "$sym" "$((i+1))" "$n" "$d"
        if [ -n "$f" ] && [ "$s" != "ok" ]; then
            printf "         \033[2mfix:\033[0m %s\n" "$f"
        fi
    done
    echo ""
    if [ "$FAILED" -eq 0 ]; then
        printf '  Overall: \033[32mHEALTHY ✅\033[0m  (%d/%d ok)\n' "$PASSED" "$TOTAL"
    else
        printf '  Overall: \033[31mDEGRADED ⚠️\033[0m  (%d/%d ok, %d failed)\n' "$PASSED" "$TOTAL" "$FAILED"
    fi
}

render_json() {
    local i
    printf '{\n  "total": %d,\n  "passed": %d,\n  "failed": %d,\n  "checks": [\n' "$TOTAL" "$PASSED" "$FAILED"
    for i in $(seq 0 $((TOTAL-1))); do
        local sep=","
        [ "$i" -eq "$((TOTAL-1))" ] && sep=""
        printf '    {"name": %s, "status": %s, "detail": %s, "fix": %s}%s\n' \
            "$(printf '%s' "${RESULTS_NAME[$i]}" | jq -Rs .)" \
            "$(printf '%s' "${RESULTS_STATUS[$i]}" | jq -Rs .)" \
            "$(printf '%s' "${RESULTS_DETAIL[$i]}" | jq -Rs .)" \
            "$(printf '%s' "${RESULTS_FIX[$i]}" | jq -Rs .)" \
            "$sep"
    done
    printf '  ]\n}\n'
}

# ─── Main ──────────────────────────────────────────────────────────────
check_tools
check_settings
check_wrapper
check_capabilities
check_cship_toml
check_starship_fragment
check_mock_render
check_drift

if [ "$JSON" = true ]; then
    render_json
else
    render_human
fi

# Critical = settings missing OR wrapper not executable OR mock render empty
if [ "$FAILED" -gt 0 ]; then
    if [[ " ${RESULTS_DETAIL[*]} " == *"no statusLine.command configured"* ]] \
       || [[ " ${RESULTS_DETAIL[*]} " == *"empty output"* ]]; then
        exit 2
    fi
    exit 1
fi
exit 0
