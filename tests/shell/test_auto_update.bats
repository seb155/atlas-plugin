#!/usr/bin/env bats
# Tests for hooks/lib/auto-update.sh — atlas_auto_update_plugins()

load helper.bash

setup() {
    setup_isolated_home
    # Source the lib; set ATLAS_SOURCE_REPO to a deliberately missing path
    # so no test accidentally triggers git/make operations.
    export ATLAS_SOURCE_REPO="$HOME/nonexistent-source-repo"
    # shellcheck disable=SC1091
    source "$PLUGIN_ROOT/hooks/lib/auto-update.sh"
}

teardown() {
    teardown_isolated_home
}

# Helper: seed marketplace.json with given versions for atlas-core/admin/dev
seed_marketplace() {
    local ver="$1"
    mkdir -p "$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin"
    cat > "$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json" <<EOF
{
  "name": "atlas-marketplace",
  "plugins": [
    {"name": "atlas-core",  "version": "$ver", "source": "./manifests/atlas-core.json"},
    {"name": "atlas-admin", "version": "$ver", "source": "./manifests/atlas-admin.json"},
    {"name": "atlas-dev",   "version": "$ver", "source": "./manifests/atlas-dev.json"}
  ]
}
EOF
}

# Helper: seed installed_plugins.json with given atlas-core version at scope=user
seed_installed() {
    local ver="$1"
    mkdir -p "$HOME/.claude/plugins"
    cat > "$HOME/.claude/plugins/installed_plugins.json" <<EOF
{
  "version": 2,
  "plugins": {
    "atlas-core@atlas-marketplace": [
      {"scope": "user", "installPath": "/fake/$ver", "version": "$ver", "installedAt": "2026-04-14T00:00:00Z", "lastUpdated": "2026-04-14T00:00:00Z", "gitCommitSha": "abc123"},
      {"scope": "project", "projectPath": "/p", "installPath": "/fake/old", "version": "5.0.0", "installedAt": "2026-04-01T00:00:00Z", "lastUpdated": "2026-04-01T00:00:00Z"}
    ]
  }
}
EOF
}

@test "no-op when ATLAS_NO_AUTO_UPDATE=1" {
    export ATLAS_NO_AUTO_UPDATE=1
    seed_marketplace "5.10.0"
    seed_installed "5.7.0-alpha.1"
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no-op when marketplace.json missing" {
    seed_installed "5.7.0-alpha.1"
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no-op when installed_plugins.json missing" {
    seed_marketplace "5.10.0"
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no-op when versions match (up to date)" {
    seed_marketplace "5.10.0"
    seed_installed "5.10.0"
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "no-op when installed is newer than marketplace" {
    seed_marketplace "5.7.0"
    seed_installed "5.10.0"
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "detects gap and reports missing source repo" {
    seed_marketplace "5.10.0"
    seed_installed "5.7.0-alpha.1"
    # ATLAS_SOURCE_REPO points to nonexistent dir (setup)
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [[ "$output" == *"5.10.0"* ]]
    [[ "$output" == *"5.7.0-alpha.1"* ]]
    [[ "$output" == *"source repo not found"* ]]
}

@test "semver: marketplace 5.10.0 correctly detected > installed 5.7.0-alpha.1" {
    # Hand-verify sort -V handles this case.
    run _atlas_au_max_version "5.7.0-alpha.1" "5.10.0"
    [ "$status" -eq 0 ]
    [ "$output" = "5.10.0" ]
}

@test "semver: 5.2.0 correctly detected > 5.1.5" {
    run _atlas_au_max_version "5.1.5" "5.2.0"
    [ "$output" = "5.2.0" ]
}

@test "marketplace max version picks highest across addons" {
    mkdir -p "$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin"
    cat > "$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json" <<'EOF'
{
  "plugins": [
    {"name": "atlas-core",  "version": "5.9.0"},
    {"name": "atlas-admin", "version": "5.10.0"},
    {"name": "atlas-dev",   "version": "5.8.0"},
    {"name": "other-plugin", "version": "99.0.0"}
  ]
}
EOF
    run _atlas_au_marketplace_max_version "$HOME/.claude/plugins/marketplaces/atlas-marketplace/.claude-plugin/marketplace.json"
    [ "$output" = "5.10.0" ]
}

@test "installed user version reads scope=user only (not project)" {
    seed_installed "5.7.0-alpha.1"
    run _atlas_au_installed_user_version "$HOME/.claude/plugins/installed_plugins.json" "atlas-core@atlas-marketplace"
    [ "$output" = "5.7.0-alpha.1" ]
}

@test "no-op when source repo not a git repo" {
    seed_marketplace "5.10.0"
    seed_installed "5.7.0-alpha.1"
    export ATLAS_SOURCE_REPO="$HOME/fake-repo"
    mkdir -p "$ATLAS_SOURCE_REPO"
    # Not a git repo (no .git dir)
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [[ "$output" == *"source repo not found"* ]]
}

@test "plugin not installed (scope=user) returns silent no-op" {
    seed_marketplace "5.10.0"
    # No atlas-core entry in installed_plugins.json → should not attempt install
    cat > "$HOME/.claude/plugins/installed_plugins.json" <<'EOF'
{
  "version": 2,
  "plugins": {
    "other-plugin@other-marketplace": [{"scope": "user", "version": "1.0.0"}]
  }
}
EOF
    run atlas_auto_update_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
