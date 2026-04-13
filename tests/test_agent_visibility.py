"""
test_agent_visibility.py — SP-AGENT-VIS (Subagent Visibility) test suite.

Validates Phases 1-4 of the Subagent Visibility stack:
- Layer 1: telemetry capture (hooks/ts/lib/agent-registry.ts)
- Layer 2: statusline indicator (scripts/atlas-agents-module.sh)
- Layer 3: cross-platform auto-tail (scripts/atlas-{agent-tail,jsonl-format}.sh + lib/)
- Layer 4: CLI module (scripts/atlas-modules/agents.sh)

Plan: .blueprint/plans/keen-nibbling-umbrella.md (SP-AGENT-VIS v1.0 FINAL).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

from conftest import HOOKS_DIR, PLUGIN_ROOT

SCRIPTS_DIR = PLUGIN_ROOT / "scripts"
LIB_DIR = SCRIPTS_DIR / "lib"
HOOKS_TS_DIR = HOOKS_DIR / "ts"
HOOKS_LIB_DIR = HOOKS_TS_DIR / "lib"
AGENTS_SKILL = PLUGIN_ROOT / "skills" / "agent-visibility" / "SKILL.md"


# ============================================================
# Layer 1 — Telemetry (TypeScript + hooks.json)
# ============================================================


def test_agent_registry_ts_exists():
    """Layer 1 foundation: agent-registry.ts module must exist."""
    registry = HOOKS_LIB_DIR / "agent-registry.ts"
    assert registry.exists(), f"Missing: {registry}"
    assert registry.stat().st_size > 1000, "agent-registry.ts seems too small"


def test_subagent_output_capture_ts_exists():
    """PostToolUse:Agent hook handler must exist."""
    capture = HOOKS_TS_DIR / "subagent-output-capture.ts"
    assert capture.exists(), f"Missing: {capture}"


def test_subagent_track_stop_ts_exists():
    """SubagentStop cleanup hook must exist."""
    stop = HOOKS_TS_DIR / "subagent-track-stop.ts"
    assert stop.exists(), f"Missing: {stop}"


def test_agent_registry_exports():
    """agent-registry.ts must export all 9 documented functions + paths."""
    content = (HOOKS_LIB_DIR / "agent-registry.ts").read_text()
    expected_exports = [
        "registerSpawn",
        "registerStart",
        "markCompleted",
        "updateVisibility",
        "getByAgentId",
        "getActive",
        "getAll",
        "pruneStale",
        "AGENTS_REGISTRY_PATH",
    ]
    for name in expected_exports:
        assert f"export " in content and name in content, f"Missing export: {name}"


def test_agent_entry_schema_fields():
    """AgentEntry interface must include all 12 fields from plan Section C."""
    content = (HOOKS_LIB_DIR / "agent-registry.ts").read_text()
    required_fields = [
        "agent_id",
        "agent_type",
        "output_file",
        "started_at",
        "finished_at",
        "status",
        "duration_ms",
        "success",
        "tmux_pane",
        "wt_tab",
        "visibility_mode",
        "session_id",
    ]
    for field in required_fields:
        assert field in content, f"AgentEntry missing field: {field}"


# ============================================================
# Layer 1 — Hook registration (hooks.json)
# ============================================================


@pytest.fixture
def hooks_config():
    return json.loads((HOOKS_DIR / "hooks.json").read_text())


def test_hooks_post_tool_use_agent_registered(hooks_config):
    """PostToolUse:Agent handler must be registered for subagent-output-capture."""
    post = hooks_config.get("hooks", {}).get("PostToolUse", [])
    agent_matchers = [h for h in post if h.get("matcher") == "Agent"]
    assert len(agent_matchers) >= 1, "No PostToolUse matcher=Agent entry found"
    hook_cmds = [h.get("command", "") for h in agent_matchers[0].get("hooks", [])]
    assert any(
        "subagent-output-capture" in cmd for cmd in hook_cmds
    ), f"subagent-output-capture hook not registered. Found: {hook_cmds}"


def test_hooks_subagent_stop_track_registered(hooks_config):
    """SubagentStop must include subagent-track-stop alongside existing capture."""
    stop = hooks_config.get("hooks", {}).get("SubagentStop", [])
    assert len(stop) >= 1, "No SubagentStop hooks registered"
    all_cmds = []
    for entry in stop:
        for h in entry.get("hooks", []):
            all_cmds.append(h.get("command", ""))
    assert any("subagent-result-capture" in c for c in all_cmds), "Existing result-capture missing"
    assert any("subagent-track-stop" in c for c in all_cmds), "New track-stop missing"


# ============================================================
# Layer 2 — Statusline module
# ============================================================


def test_atlas_agents_module_sh_exists():
    """Statusline custom module must exist and be executable."""
    mod = SCRIPTS_DIR / "atlas-agents-module.sh"
    assert mod.exists(), f"Missing: {mod}"
    assert os.access(mod, os.X_OK), f"Not executable: {mod}"


def test_statusline_command_integrates_agents():
    """statusline-command.sh must have agents indicator block."""
    sl = (SCRIPTS_DIR / "statusline-command.sh").read_text()
    assert "agents_display" in sl, "statusline-command.sh missing agents_display var"
    assert "agents.json" in sl, "statusline-command.sh missing agents.json reference"
    assert "🤖" in sl, "Missing robot emoji indicator"


def test_cship_toml_registers_atlas_agents():
    """cship.toml must register $custom.atlas_agents in Row 1."""
    toml = (SCRIPTS_DIR / "cship.toml").read_text()
    assert "$custom.atlas_agents" in toml, "cship.toml Row 1 missing $custom.atlas_agents"
    assert "[custom.atlas_agents]" in toml, "cship.toml missing [custom.atlas_agents] definition"


def test_cship_atlas_toml_registers_atlas_agents():
    """cship-atlas.toml variant must also register $custom.atlas_agents."""
    toml = (SCRIPTS_DIR / "cship-atlas.toml").read_text()
    assert "$custom.atlas_agents" in toml


# ============================================================
# Layer 2 — Functional test with mock agents.json
# ============================================================


def _write_mock_agents_json(path: Path, running: int = 0, completed: int = 0, failed: int = 0):
    """Helper: generate a mock agents.json with N running + completed + failed."""
    import datetime as dt

    now = dt.datetime.now(dt.timezone.utc).isoformat()
    store = {}
    for i in range(running):
        aid = f"test-running-{i}"
        store[aid] = {
            "agent_id": aid, "agent_type": "test", "output_file": None,
            "started_at": now, "finished_at": None, "status": "running",
            "duration_ms": None, "success": None, "tmux_pane": None,
            "wt_tab": None, "visibility_mode": "none", "session_id": "",
        }
    for i in range(completed):
        aid = f"test-done-{i}"
        store[aid] = {
            "agent_id": aid, "agent_type": "test", "output_file": None,
            "started_at": now, "finished_at": now, "status": "completed",
            "duration_ms": 1000, "success": True, "tmux_pane": None,
            "wt_tab": None, "visibility_mode": "none", "session_id": "",
        }
    for i in range(failed):
        aid = f"test-fail-{i}"
        store[aid] = {
            "agent_id": aid, "agent_type": "test", "output_file": None,
            "started_at": now, "finished_at": now, "status": "failed",
            "duration_ms": 500, "success": False, "tmux_pane": None,
            "wt_tab": None, "visibility_mode": "none", "session_id": "",
        }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(store, indent=2))


@pytest.mark.integration
def test_atlas_agents_module_renders_counts(tmp_path):
    """atlas-agents-module.sh must render correct counts when agents present."""
    agents_file = tmp_path / "runtime" / "agents.json"
    _write_mock_agents_json(agents_file, running=2, completed=1, failed=0)
    env = {**os.environ, "ATLAS_DIR": str(tmp_path)}
    result = subprocess.run(
        [str(SCRIPTS_DIR / "atlas-agents-module.sh")],
        capture_output=True, text=True, env=env, timeout=5,
    )
    assert result.returncode == 0
    out = result.stdout.strip()
    assert "🤖" in out, f"Missing robot emoji in output: {out!r}"
    assert "2▶" in out, f"Missing running count 2▶ in output: {out!r}"
    assert "1✓" in out, f"Missing done count 1✓ in output: {out!r}"


@pytest.mark.integration
def test_atlas_agents_module_empty_silent(tmp_path):
    """atlas-agents-module.sh must output nothing when no agents tracked."""
    env = {**os.environ, "ATLAS_DIR": str(tmp_path)}  # no agents.json
    result = subprocess.run(
        [str(SCRIPTS_DIR / "atlas-agents-module.sh")],
        capture_output=True, text=True, env=env, timeout=5,
    )
    assert result.returncode == 0
    assert result.stdout.strip() == "", "Should be silent when no registry file"


# ============================================================
# Layer 3 — Cross-platform auto-tail scripts
# ============================================================


def test_jsonl_format_sh_exists_executable():
    fmt = SCRIPTS_DIR / "atlas-jsonl-format.sh"
    assert fmt.exists() and os.access(fmt, os.X_OK)


def test_agent_tail_sh_exists_executable():
    tail = SCRIPTS_DIR / "atlas-agent-tail.sh"
    assert tail.exists() and os.access(tail, os.X_OK)


def test_detect_visibility_env_sh_exists_executable():
    det = LIB_DIR / "detect-visibility-env.sh"
    assert det.exists() and os.access(det, os.X_OK)


def test_show_hint_sh_exists_executable():
    hint = LIB_DIR / "show-hint.sh"
    assert hint.exists() and os.access(hint, os.X_OK)


@pytest.mark.integration
def test_detect_visibility_env_returns_valid_value():
    """detect-visibility-env.sh must return one of: tmux, wt, fallback, none."""
    result = subprocess.run(
        [str(LIB_DIR / "detect-visibility-env.sh")],
        capture_output=True, text=True, timeout=3,
    )
    assert result.returncode == 0
    out = result.stdout.strip()
    assert out in {"tmux", "wt", "fallback", "none"}, f"Unexpected env: {out!r}"


@pytest.mark.integration
def test_detect_visibility_env_opt_out():
    """ATLAS_AUTO_TAIL_AGENTS=0 must produce 'none'."""
    env = {**os.environ, "ATLAS_AUTO_TAIL_AGENTS": "0"}
    result = subprocess.run(
        [str(LIB_DIR / "detect-visibility-env.sh")],
        capture_output=True, text=True, env=env, timeout=3,
    )
    assert result.stdout.strip() == "none"


@pytest.mark.integration
def test_jsonl_format_handles_assistant_text():
    """Formatter must handle assistant message with text block."""
    sample = json.dumps({
        "type": "assistant",
        "message": {
            "role": "assistant",
            "content": [{"type": "text", "text": "Hello world from test"}],
        },
    })
    result = subprocess.run(
        [str(SCRIPTS_DIR / "atlas-jsonl-format.sh")],
        input=sample + "\n", capture_output=True, text=True, timeout=5,
    )
    assert result.returncode == 0
    assert "💬" in result.stdout
    assert "Hello world" in result.stdout


@pytest.mark.integration
def test_jsonl_format_handles_tool_use():
    """Formatter must handle assistant tool_use block."""
    sample = json.dumps({
        "type": "assistant",
        "message": {
            "role": "assistant",
            "content": [
                {"type": "tool_use", "id": "tu_1", "name": "Bash",
                 "input": {"command": "ls -la"}},
            ],
        },
    })
    result = subprocess.run(
        [str(SCRIPTS_DIR / "atlas-jsonl-format.sh")],
        input=sample + "\n", capture_output=True, text=True, timeout=5,
    )
    assert "🔧" in result.stdout
    assert "Bash" in result.stdout


@pytest.mark.integration
def test_jsonl_format_handles_tool_result():
    """Formatter must handle user tool_result block (success)."""
    sample = json.dumps({
        "type": "user",
        "message": {
            "role": "user",
            "content": [
                {"type": "tool_result", "tool_use_id": "tu_1", "content": "output"},
            ],
        },
    })
    result = subprocess.run(
        [str(SCRIPTS_DIR / "atlas-jsonl-format.sh")],
        input=sample + "\n", capture_output=True, text=True, timeout=5,
    )
    assert "✓" in result.stdout


@pytest.mark.integration
def test_jsonl_format_raw_passthrough():
    """--raw flag must bypass formatting."""
    sample = '{"type":"something","raw":"data"}\n'
    result = subprocess.run(
        [str(SCRIPTS_DIR / "atlas-jsonl-format.sh"), "--raw"],
        input=sample, capture_output=True, text=True, timeout=3,
    )
    assert result.returncode == 0
    assert sample in result.stdout


@pytest.mark.integration
def test_show_hint_throttles(tmp_path):
    """show-hint.sh must emit hint first time, skip on second call (same session)."""
    script = LIB_DIR / "show-hint.sh"
    # Use CLAUDE_SESSION_ID (script's first-priority var) with a unique test value.
    # Also clear any existing marker for this session to ensure a clean start.
    test_session = f"test-visibility-{tmp_path.name}"
    env = {**os.environ, "CLAUDE_SESSION_ID": test_session}
    marker_file = Path(f"/tmp/atlas-hint-shown-{test_session}")
    if marker_file.exists():
        marker_file.unlink()

    try:
        # First call: should emit
        r1 = subprocess.run([str(script)], capture_output=True, text=True, env=env, timeout=3)
        assert "ATLAS Subagent running" in r1.stderr, "First call should emit hint"

        # Second call: should be silent (marker file exists)
        r2 = subprocess.run([str(script)], capture_output=True, text=True, env=env, timeout=3)
        assert r2.stderr.strip() == "", f"Second call should be silent, got: {r2.stderr!r}"

        # --reset clears throttle
        subprocess.run([str(script), "--reset"], capture_output=True, text=True, env=env, timeout=3)
        r3 = subprocess.run([str(script)], capture_output=True, text=True, env=env, timeout=3)
        assert "ATLAS Subagent running" in r3.stderr, "Post-reset call should emit again"
    finally:
        if marker_file.exists():
            marker_file.unlink()


# ============================================================
# Layer 4 — CLI module + skill
# ============================================================


def test_agents_sh_cli_module_exists():
    mod = SCRIPTS_DIR / "atlas-modules" / "agents.sh"
    assert mod.exists(), f"Missing: {mod}"


def test_atlas_cli_loads_agents_module():
    """atlas-cli.sh module load list must include 'agents'."""
    cli = (SCRIPTS_DIR / "atlas-cli.sh").read_text()
    assert "agents" in cli, "atlas-cli.sh module list missing 'agents'"


def test_launcher_routes_agents_to_cmd():
    """launcher.sh must route 'agents)' case to _atlas_agents_cmd."""
    launcher = (SCRIPTS_DIR / "atlas-modules" / "launcher.sh").read_text()
    assert "_atlas_agents_cmd" in launcher, "launcher missing _atlas_agents_cmd call"


def test_agent_visibility_skill_exists():
    """agent-visibility SKILL.md must exist with frontmatter."""
    assert AGENTS_SKILL.exists(), f"Missing: {AGENTS_SKILL}"
    content = AGENTS_SKILL.read_text()
    assert "name: agent-visibility" in content
    assert "triggers" in content.lower() or "trigger" in content.lower()
    assert "atlas agents" in content


def test_agent_visibility_in_metadata():
    """skills/_metadata.yaml must register agent-visibility entry."""
    metadata = (PLUGIN_ROOT / "skills" / "_metadata.yaml").read_text()
    assert "agent-visibility:" in metadata, "agent-visibility not registered in _metadata.yaml"


def test_agents_sh_covers_all_subcommands():
    """agents.sh module must define all 7 documented subcommands."""
    mod = (SCRIPTS_DIR / "atlas-modules" / "agents.sh").read_text()
    for sub in ["list", "tail", "stop", "replay", "stats", "clean", "env"]:
        assert sub in mod, f"Subcommand '{sub}' not found in agents.sh"
