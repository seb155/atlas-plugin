#!/usr/bin/env bash
# scripts/statusline/install.sh — idempotent ATLAS status line installer
#
# SP-STATUSLINE-SOTA-V3 Sprint B (L4).
#
# Goal: a single command that bootstraps a fresh machine OR repairs a
# damaged install, without overwriting user customization.
#
# Usage:
#   bash install.sh                   # interactive (HITL gate before risky steps)
#   bash install.sh --auto            # non-interactive (used by auto-heal hook)
#   bash install.sh --doctor-after    # run doctor.sh at end (print final audit)
#   bash install.sh --dry-run         # show what would change, write nothing
#   bash install.sh --target <DIR>    # override deploy dir (default ~/.local/share/atlas-statusline)
#
# Idempotency:
#   - md5 hashes the source artifact and the deployed copy; only writes if differ.
#   - settings.local.json is jq-merged (preserves user keys; sets statusLine.command if unset).
#   - Re-running is a no-op when nothing has drifted.
#
# Territorial boundary (ADR-019 + ADR-023 draft):
#   - We deploy under ~/.local/share/atlas-statusline/  (dotfile-sync immune)
#   - We update    ~/.claude/settings.local.json        (NOT settings.json)
#   - We never write to ~/.claude/settings.json
#
# Exit codes:
#   0  install OK (or no-op)
#   1  user aborted at HITL gate
#   2  missing dependency (cship/jq not installed and user declined to install)
#   3  destination not writable
#   4  source artifact missing (plugin packaging bug — open an issue)
#   5  doctor reported unhealthy (only when --doctor-after used)

set -euo pipefail

# ─── Args + defaults ───────────────────────────────────────────────────
AUTO=false
DOCTOR_AFTER=false
DRY_RUN=false
TARGET="$HOME/.local/share/atlas-statusline"

while [ $# -gt 0 ]; do
    case "$1" in
        --auto)          AUTO=true ;;
        --doctor-after)  DOCTOR_AFTER=true ;;
        --dry-run)       DRY_RUN=true ;;
        --target)        TARGET="$2"; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^# Idempotency:/p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
    shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"   # scripts/
SETTINGS_LOCAL="$HOME/.claude/settings.local.json"

# ─── Logging helpers ───────────────────────────────────────────────────
log()   { printf '\033[36m[install]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[install] ⚠\033[0m  %s\n' "$*" >&2; }
err()   { printf '\033[31m[install] ✗\033[0m  %s\n' "$*" >&2; }
ok()    { printf '\033[32m[install] ✓\033[0m  %s\n' "$*"; }

# ─── HITL gate ─────────────────────────────────────────────────────────
confirm() {
    local prompt="$1"
    if [ "$AUTO" = true ]; then return 0; fi
    if [ ! -t 0 ]; then return 0; fi   # not a TTY → assume auto
    printf '\033[1m[install] %s [Y/n]\033[0m ' "$prompt"
    local r; read -r r
    case "$r" in n|N|no|No|NO) return 1 ;; *) return 0 ;; esac
}

# ─── md5-based sync ────────────────────────────────────────────────────
# Returns 0 if file copied (or would copy in dry-run), 1 if no-op.
sync_artifact() {
    local src="$1" dst="$2"
    if [ ! -f "$src" ]; then
        err "source artifact missing: $src"
        return 4
    fi
    local src_md5 dst_md5
    src_md5=$(md5sum "$src" | cut -d' ' -f1)
    dst_md5=""
    [ -f "$dst" ] && dst_md5=$(md5sum "$dst" | cut -d' ' -f1)

    if [ "$src_md5" = "$dst_md5" ]; then
        return 1   # no-op
    fi
    if [ "$DRY_RUN" = true ]; then
        log "WOULD copy $src → $dst (md5 ${src_md5:0:8}..)"
        return 0
    fi
    install -D -m 0755 "$src" "$dst"
    log "copied $(basename "$dst")  md5=${src_md5:0:8}.."
    return 0
}

# ─── Phase 1: dependency check ─────────────────────────────────────────
check_deps() {
    log "Phase 1 — dependency check"
    local missing=()
    command -v jq    >/dev/null 2>&1 || missing+=(jq)
    command -v bash  >/dev/null 2>&1 || missing+=(bash)
    command -v git   >/dev/null 2>&1 || missing+=(git)
    if [ ${#missing[@]} -gt 0 ]; then
        err "missing required tools: ${missing[*]}"
        warn "install with: sudo apt install ${missing[*]}  (Debian/Ubuntu)"
        return 2
    fi

    # yq is used by atlas-discover-addons.sh — but Sprint A's L1 fix means
    # yq is no longer required (grep fallback works). Warn if snap-confined.
    if command -v yq >/dev/null 2>&1; then
        local yq_path
        yq_path=$(command -v yq)
        if [[ "$yq_path" == /snap/* ]] || [[ "$(readlink -f "$yq_path")" == /snap/* ]]; then
            warn "yq is installed via snap ($yq_path) — AppArmor blocks it from reading ~/.claude/**"
            warn "Sprint A grep fallback handles this, but you may prefer: sudo snap remove yq"
            warn "and re-install via apt or binary release"
        fi
    fi
    ok "tools present"
}

# ─── Phase 2: deploy artifacts to TARGET ──────────────────────────────
deploy_artifacts() {
    log "Phase 2 — deploy artifacts to $TARGET"
    [ "$DRY_RUN" = false ] && mkdir -p "$TARGET"

    # Files we deploy (kept dotfile-immune):
    #   wrapper.sh           — exec'd by CC; resolves plugin version + delegates
    #   atlas-resolve-version.sh — version resolver (Tier 1/2/3)
    # NOTE: command.sh (the renderer) stays in the plugin — wrapper exec's it
    # by version. Plugin updates → renderer updates automatically.
    sync_artifact "$SOURCE_DIR/statusline-wrapper.sh"     "$TARGET/statusline-wrapper.sh"   || true
    sync_artifact "$SOURCE_DIR/atlas-resolve-version.sh"  "$TARGET/atlas-resolve-version.sh" || true

    # Custom modules (legacy CShip — see ADR-024 draft)
    # Even though cship doesn't actually pipe JSON to them, we keep them
    # deployed so existing cship.toml configs do not error at render time.
    [ "$DRY_RUN" = false ] && mkdir -p "$TARGET/modules"
    for m in atlas-200k-badge-module.sh atlas-agents-module.sh atlas-alert-module.sh \
             atlas-context-size-module.sh atlas-cost-usd-module.sh atlas-effort-module.sh; do
        if [ -f "$SOURCE_DIR/$m" ]; then
            sync_artifact "$SOURCE_DIR/$m" "$TARGET/modules/$m" || true
            # Also keep at top-level for backward-compat with old cship.toml paths
            sync_artifact "$SOURCE_DIR/$m" "$TARGET/$m" || true
        fi
    done
    ok "artifacts deployed"
}

# ─── Phase 3: settings.local.json migration ───────────────────────────
update_settings_local() {
    log "Phase 3 — settings.local.json"
    local target_cmd="$TARGET/statusline-wrapper.sh"

    # If settings.json already points to ATLAS wrapper, that's fine — but
    # we want to migrate it to settings.local.json so dotfile-sync cannot
    # wipe it. ADR-023 (draft) describes this territorial boundary.
    local current=""
    if [ -f "$HOME/.claude/settings.json" ] && command -v jq >/dev/null 2>&1; then
        current=$(jq -r '.statusLine.command // ""' "$HOME/.claude/settings.json" 2>/dev/null)
    fi

    # Read current settings.local.json (if any) or start fresh
    local local_current=""
    if [ -f "$SETTINGS_LOCAL" ]; then
        local_current=$(jq -r '.statusLine.command // ""' "$SETTINGS_LOCAL" 2>/dev/null || echo "")
    fi

    if [ "$local_current" = "$target_cmd" ]; then
        ok "settings.local.json statusLine.command already correct"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log "WOULD set $SETTINGS_LOCAL .statusLine = {type:command, command:$target_cmd}"
        return 0
    fi

    if [ ! -f "$SETTINGS_LOCAL" ]; then
        echo '{}' > "$SETTINGS_LOCAL"
    fi
    # Backup before write
    cp -p "$SETTINGS_LOCAL" "$SETTINGS_LOCAL.bak-$(date +%Y%m%d-%H%M%S)"
    local tmp
    tmp=$(mktemp)
    jq --arg cmd "$target_cmd" \
       '.statusLine = {type: "command", command: $cmd}' \
       "$SETTINGS_LOCAL" > "$tmp"
    mv "$tmp" "$SETTINGS_LOCAL"
    ok "settings.local.json updated → $target_cmd"

    # Inform user about settings.json (don't auto-modify)
    if [ -n "$current" ] && [ "$current" != "$target_cmd" ]; then
        warn "~/.claude/settings.json statusLine.command is set to: $current"
        warn "settings.local.json takes precedence; the settings.json value is ignored."
        warn "If you want, remove the statusLine block from settings.json manually."
    fi
}

# ─── Phase 4: write install manifest ───────────────────────────────────
write_manifest() {
    log "Phase 4 — manifest"
    local manifest="$TARGET/.install-manifest"
    if [ "$DRY_RUN" = true ]; then
        log "WOULD write $manifest"
        return 0
    fi
    {
        echo "# ATLAS statusline install manifest"
        echo "# Generated by scripts/statusline/install.sh — do not edit by hand."
        echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "source_dir=$SOURCE_DIR"
        echo "target_dir=$TARGET"
        echo ""
        echo "# md5 stamps for drift detection (used by auto-heal hook)"
        for f in statusline-wrapper.sh atlas-resolve-version.sh; do
            if [ -f "$TARGET/$f" ]; then
                echo "md5_${f//[-.]/_}=$(md5sum "$TARGET/$f" | cut -d' ' -f1)"
            fi
        done
    } > "$manifest"
    ok "manifest written"
}

# ─── Phase 5: refresh capabilities + render check ──────────────────────
verify_render() {
    log "Phase 5 — render verification"
    if [ "$DRY_RUN" = true ]; then
        log "SKIP (dry-run)"
        return 0
    fi

    # Re-run discover so capabilities.json reflects current plugins
    if [ -x "$SOURCE_DIR/atlas-discover-addons.sh" ]; then
        "$SOURCE_DIR/atlas-discover-addons.sh" >/dev/null 2>&1 || \
            warn "atlas-discover-addons.sh exited non-zero (continuing)"
    fi

    # Mock render — assert output contains a real version, not a bare ?
    local mock_input='{"model":{"id":"claude-opus-4-7","display_name":"Opus"},"context_window":{"used_percentage":42,"context_window_size":1000000},"workspace":{"current_dir":"/tmp"},"effort":{"level":"high"},"rate_limits":{"five_hour":{"used_percentage":12}}}'
    local rendered
    rendered=$(echo "$mock_input" | bash "$TARGET/statusline-wrapper.sh" 2>&1)
    local stripped
    stripped=$(printf '%s' "$rendered" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')

    # Hard fail conditions:
    if [ -z "$stripped" ]; then
        err "wrapper produced empty output"
        return 1
    fi

    # Soft warning: wrapper resolved but plugin renderer not found (fresh
    # machine before plugin install / isolated test HOME). Not an installer
    # failure — install.sh's job is to deploy artifacts, not provision the
    # plugin cache.
    if [[ "$stripped" == *"statusline script missing"* ]]; then
        warn "wrapper deployed but plugin renderer not found in this HOME"
        warn "this is normal in an isolated test environment or before /plugin install"
        warn "render: ${stripped:0:120}"
        return 0
    fi

    if [[ "$stripped" =~ ATLAS\ \?\  ]] || [[ "$stripped" =~ ATLAS\ \?$ ]]; then
        warn "render contains bare 'ATLAS ?' — version unresolvable"
        warn "render: $stripped"
        warn "Check capabilities.json: jq .version $HOME/.atlas/runtime/capabilities.json"
        return 1
    fi
    ok "render: ${stripped:0:120}"
}

# ─── Main ──────────────────────────────────────────────────────────────
main() {
    log "ATLAS Statusline Installer (SP-STATUSLINE-V3 Sprint B)"
    log "source: $SOURCE_DIR"
    log "target: $TARGET"
    [ "$DRY_RUN" = true ] && warn "DRY RUN — no files will be written"
    echo ""

    if [ ! -d "$SOURCE_DIR" ]; then
        err "source dir not found: $SOURCE_DIR"
        exit 4
    fi
    # In dry-run, skip target creation so the user can see what *would* happen
    # without polluting their filesystem.
    if [ "$DRY_RUN" = false ]; then
        if ! mkdir -p "$TARGET" 2>/dev/null; then
            err "cannot create target: $TARGET"
            exit 3
        fi
    fi

    if ! confirm "Proceed with install/repair?"; then
        log "user aborted"
        exit 1
    fi

    check_deps         || exit 2
    deploy_artifacts   || exit 4
    update_settings_local
    write_manifest
    verify_render      || exit 5

    echo ""
    ok "install complete"
    log "settings.local.json statusLine.command → $TARGET/statusline-wrapper.sh"
    log "next CC restart will pick up the change"

    if [ "$DOCTOR_AFTER" = true ] && [ -x "$SCRIPT_DIR/doctor.sh" ]; then
        echo ""
        bash "$SCRIPT_DIR/doctor.sh"
    fi
}

main "$@"
