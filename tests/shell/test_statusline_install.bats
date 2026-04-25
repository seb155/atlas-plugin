#!/usr/bin/env bats
# SP-STATUSLINE-SOTA-V3 Sprint B — installer tests for L4.

load helper.bash

setup() {
    setup_isolated_home
    export TARGET="$HOME_TMP/.local/share/atlas-statusline"
    export INSTALLER="$PLUGIN_ROOT/scripts/statusline/install.sh"
}

teardown() {
    teardown_isolated_home
}

# ─── Smoke ──────────────────────────────────────────────────────────────

@test "installer is executable" {
    [ -x "$INSTALLER" ]
}

@test "installer --help exits 0 and prints usage" {
    run bash "$INSTALLER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "installer --dry-run does not write anything" {
    run bash "$INSTALLER" --auto --dry-run --target "$TARGET"
    [ "$status" -eq 0 ]
    [ ! -d "$TARGET" ]
    [ ! -f "$HOME/.claude/settings.local.json" ]
}

# ─── Idempotency ───────────────────────────────────────────────────────

@test "installer creates target dir + artifacts" {
    run bash "$INSTALLER" --auto --target "$TARGET"
    [ "$status" -eq 0 ]
    [ -f "$TARGET/statusline-wrapper.sh" ]
    [ -f "$TARGET/atlas-resolve-version.sh" ]
    [ -f "$TARGET/.install-manifest" ]
    [ -d "$TARGET/modules" ]
}

@test "installer is idempotent (second run is a no-op for unchanged files)" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null
    local first_md5
    first_md5=$(md5sum "$TARGET/statusline-wrapper.sh" | cut -d' ' -f1)
    local first_mtime
    first_mtime=$(stat -c %Y "$TARGET/statusline-wrapper.sh")
    sleep 1
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null
    local second_md5
    second_md5=$(md5sum "$TARGET/statusline-wrapper.sh" | cut -d' ' -f1)
    local second_mtime
    second_mtime=$(stat -c %Y "$TARGET/statusline-wrapper.sh")
    [ "$first_md5" = "$second_md5" ]
    # mtime should not change because md5 matched and we skipped the write
    [ "$first_mtime" = "$second_mtime" ]
}

# ─── settings.local.json ───────────────────────────────────────────────

@test "installer creates settings.local.json with statusLine block" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null
    [ -f "$HOME/.claude/settings.local.json" ]
    local cmd
    cmd=$(jq -r '.statusLine.command' "$HOME/.claude/settings.local.json")
    [ "$cmd" = "$TARGET/statusline-wrapper.sh" ]
    local type
    type=$(jq -r '.statusLine.type' "$HOME/.claude/settings.local.json")
    [ "$type" = "command" ]
}

@test "installer preserves existing keys in settings.local.json" {
    mkdir -p "$HOME/.claude"
    echo '{"customKey":"preserved","permissions":{"allow":["x"]}}' > "$HOME/.claude/settings.local.json"
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null
    [ "$(jq -r '.customKey' "$HOME/.claude/settings.local.json")" = "preserved" ]
    [ "$(jq -r '.permissions.allow[0]' "$HOME/.claude/settings.local.json")" = "x" ]
    [ "$(jq -r '.statusLine.command' "$HOME/.claude/settings.local.json")" = "$TARGET/statusline-wrapper.sh" ]
}

@test "installer creates a backup of settings.local.json before writing" {
    mkdir -p "$HOME/.claude"
    echo '{"existing":"data"}' > "$HOME/.claude/settings.local.json"
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null
    # At least one backup file should exist
    local backups
    backups=$(ls "$HOME/.claude/settings.local.json.bak-"* 2>/dev/null | wc -l)
    [ "$backups" -ge 1 ]
}

@test "installer does NOT modify settings.json" {
    mkdir -p "$HOME/.claude"
    echo '{"customSettings":"untouched"}' > "$HOME/.claude/settings.json"
    local before_md5
    before_md5=$(md5sum "$HOME/.claude/settings.json" | cut -d' ' -f1)
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null
    local after_md5
    after_md5=$(md5sum "$HOME/.claude/settings.json" | cut -d' ' -f1)
    [ "$before_md5" = "$after_md5" ]
}

# ─── Manifest ──────────────────────────────────────────────────────────

@test "installer writes manifest with md5 stamps" {
    bash "$INSTALLER" --auto --target "$TARGET" >/dev/null
    [ -f "$TARGET/.install-manifest" ]
    grep -q "^installed_at=" "$TARGET/.install-manifest"
    grep -q "^source_dir=" "$TARGET/.install-manifest"
    grep -q "^md5_statusline_wrapper_sh=" "$TARGET/.install-manifest"
    grep -q "^md5_atlas_resolve_version_sh=" "$TARGET/.install-manifest"
}

# ─── Render verification phase ─────────────────────────────────────────

@test "installer render check passes when capabilities populated" {
    # Pre-populate capabilities so the wrapper resolves a real version
    mkdir -p "$HOME/.atlas/runtime"
    cat > "$HOME/.atlas/runtime/capabilities.json" <<EOF
{"version":"6.0.0-test","tier":"core","addons":[{"name":"atlas-core","version":"6.0.0-test","priority":1}]}
EOF
    run bash "$INSTALLER" --auto --target "$TARGET"
    [ "$status" -eq 0 ]
    [[ "$output" == *"render:"* ]]
    [[ "$output" != *"unresolvable"* ]]
}
