"""
test_hook_behavior.py — Behavioral tests for hook scripts via subprocess.

Each hook is executed with realistic mock stdin and environment.
Tests verify:
- Exit code 0
- stdout is valid JSON (for hooks that produce JSON)
- Expected keys appear in output
- No traceback / crash output

These tests are marked @pytest.mark.hook for selective execution:
  pytest tests/ -m hook
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

from conftest import HOOKS_DIR, PLUGIN_ROOT

pytestmark = pytest.mark.integration  # L3: requires bash subprocess execution

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run_hook(
    script: str,
    stdin_data: str = "",
    env_extra: dict | None = None,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess:
    """Run a hook script with optional stdin and extra env vars."""
    script_path = HOOKS_DIR / script
    env = {**os.environ}
    env["CLAUDE_PLUGIN_ROOT"] = str(PLUGIN_ROOT)
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [str(script_path)],
        input=stdin_data,
        capture_output=True,
        text=True,
        env=env,
        cwd=str(cwd or PLUGIN_ROOT),
        timeout=15,
    )


# ---------------------------------------------------------------------------
# session-start hook
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestSessionStartHook:

    def test_exits_zero_no_features(self, tmp_path: Path) -> None:
        """session-start must exit 0 when no .blueprint/FEATURES.md is present."""
        result = _run_hook("session-start", cwd=tmp_path)
        assert result.returncode == 0, (
            f"session-start exited {result.returncode}\n"
            f"stderr: {result.stderr}"
        )

    def test_stdout_is_valid_json_no_features(self, tmp_path: Path) -> None:
        """session-start stdout must be valid JSON."""
        result = _run_hook("session-start", cwd=tmp_path)
        assert result.returncode == 0
        try:
            data = json.loads(result.stdout.strip())
        except json.JSONDecodeError as exc:
            pytest.fail(
                f"session-start stdout is not valid JSON: {exc}\n"
                f"stdout: {result.stdout!r}"
            )
        assert isinstance(data, dict)

    def test_json_has_continue_key(self, tmp_path: Path) -> None:
        """session-start JSON output must include 'continue' key."""
        result = _run_hook("session-start", cwd=tmp_path)
        data = json.loads(result.stdout.strip())
        assert "continue" in data, f"Missing 'continue' key in session-start output: {data}"

    def test_continue_is_true(self, tmp_path: Path) -> None:
        """session-start 'continue' must be true (never block session)."""
        result = _run_hook("session-start", cwd=tmp_path)
        data = json.loads(result.stdout.strip())
        assert data["continue"] is True, (
            f"session-start returned continue=False — sessions should never be blocked"
        )

    def test_with_atlas_role_env(self, tmp_path: Path) -> None:
        """session-start respects ATLAS_ROLE environment variable."""
        for role in ("admin", "dev", "user"):
            result = _run_hook(
                "session-start",
                cwd=tmp_path,
                env_extra={"ATLAS_ROLE": role},
            )
            assert result.returncode == 0, (
                f"session-start failed with ATLAS_ROLE={role}: {result.stderr}"
            )
            data = json.loads(result.stdout.strip())
            assert data.get("continue") is True

    def test_with_features_md(self, tmp_path: Path) -> None:
        """session-start injects feature summary when .blueprint/FEATURES.md exists."""
        blueprint_dir = tmp_path / ".blueprint"
        blueprint_dir.mkdir()
        fixtures_dir = Path(__file__).parent / "fixtures"
        import shutil
        shutil.copy(fixtures_dir / "sample_features.md", blueprint_dir / "FEATURES.md")

        result = _run_hook("session-start", cwd=tmp_path)
        assert result.returncode == 0, f"stderr: {result.stderr}"
        data = json.loads(result.stdout.strip())
        assert data.get("continue") is True
        # When features exist, additionalContext should be injected
        if "additionalContext" in data:
            assert len(data["additionalContext"]) > 0

    def test_creates_audit_log_entry(self, tmp_path: Path) -> None:
        """session-start must write an entry to ~/.claude/atlas-audit.log."""
        # Use a temp HOME to avoid polluting real audit log
        fake_home = tmp_path / "home"
        fake_home.mkdir()
        result = _run_hook(
            "session-start",
            cwd=tmp_path,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        audit_log = fake_home / ".claude" / "atlas-audit.log"
        assert audit_log.exists(), (
            f"session-start should create {audit_log} but it does not exist"
        )
        log_content = audit_log.read_text(encoding="utf-8")
        assert "tier=" in log_content, f"Audit log entry missing tier: {log_content!r}"


# ---------------------------------------------------------------------------
# enterprise-check hook
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestEnterpriseCheckHook:

    def _make_tool_input(self, file_path: str) -> str:
        return json.dumps({"tool_name": "Write", "file_path": file_path})

    def test_exits_zero_no_file(self) -> None:
        """enterprise-check exits 0 when file_path is empty."""
        stdin_data = json.dumps({"tool_name": "Write", "file_path": ""})
        result = _run_hook("enterprise-check", stdin_data=stdin_data)
        assert result.returncode == 0, f"stderr: {result.stderr}"

    def test_exits_zero_nonexistent_file(self) -> None:
        """enterprise-check exits 0 when referenced file does not exist."""
        stdin_data = self._make_tool_input("/nonexistent/path/file.py")
        result = _run_hook("enterprise-check", stdin_data=stdin_data)
        assert result.returncode == 0

    def test_no_warnings_for_clean_file(self, tmp_path: Path) -> None:
        """enterprise-check produces no output for a clean Python file."""
        clean_file = tmp_path / "clean.py"
        clean_file.write_text(
            "import structlog\nlog = structlog.get_logger()\nlog.info('hello')\n",
            encoding="utf-8",
        )
        stdin_data = self._make_tool_input(str(clean_file))
        result = _run_hook("enterprise-check", stdin_data=stdin_data)
        assert result.returncode == 0
        assert result.stdout.strip() == "", (
            f"Unexpected warnings for clean file: {result.stdout!r}"
        )

    def test_detects_cors_wildcard(self, tmp_path: Path) -> None:
        """enterprise-check must flag CORS wildcard '*' in Python files."""
        risky_file = tmp_path / "app.py"
        risky_file.write_text(
            "from fastapi.middleware.cors import CORSMiddleware\n"
            "allow_origins = ['*']\n",
            encoding="utf-8",
        )
        stdin_data = self._make_tool_input(str(risky_file))
        result = _run_hook("enterprise-check", stdin_data=stdin_data)
        assert result.returncode == 0
        assert "CORS" in result.stdout or "wildcard" in result.stdout.lower(), (
            f"Expected CORS warning, got: {result.stdout!r}"
        )

    def test_detects_token_in_localstorage(self, tmp_path: Path) -> None:
        """enterprise-check flags localStorage.setItem with token in TypeScript files."""
        risky_file = tmp_path / "auth.ts"
        risky_file.write_text(
            "localStorage.setItem('authToken', token);\n",
            encoding="utf-8",
        )
        stdin_data = self._make_tool_input(str(risky_file))
        result = _run_hook("enterprise-check", stdin_data=stdin_data)
        assert result.returncode == 0
        assert "localStorage" in result.stdout or "Token" in result.stdout, (
            f"Expected localStorage token warning, got: {result.stdout!r}"
        )

    def test_skips_non_code_files(self, tmp_path: Path) -> None:
        """enterprise-check skips files with non-code extensions (e.g. .txt)."""
        txt_file = tmp_path / "notes.txt"
        txt_file.write_text("allow_origins = ['*']\npassword = 'secret'\n", encoding="utf-8")
        stdin_data = self._make_tool_input(str(txt_file))
        result = _run_hook("enterprise-check", stdin_data=stdin_data)
        assert result.returncode == 0
        assert result.stdout.strip() == "", (
            f"Should produce no output for .txt files, got: {result.stdout!r}"
        )

    def test_detects_debug_true_in_compose(self, tmp_path: Path) -> None:
        """enterprise-check flags DEBUG=true in docker-compose files."""
        compose_file = tmp_path / "compose.yml"
        compose_file.write_text(
            "services:\n  backend:\n    environment:\n      - DEBUG=true\n",
            encoding="utf-8",
        )
        stdin_data = self._make_tool_input(str(compose_file))
        result = _run_hook("enterprise-check", stdin_data=stdin_data)
        assert result.returncode == 0
        assert "DEBUG" in result.stdout, (
            f"Expected DEBUG warning in compose file, got: {result.stdout!r}"
        )


# ---------------------------------------------------------------------------
# permission-request hook
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestPermissionRequestHook:

    def _fake_home(self, tmp_path: Path) -> Path:
        """Create a fake HOME with ~/.claude/ pre-created (required by hook's set -e)."""
        fake_home = tmp_path / "home"
        (fake_home / ".claude").mkdir(parents=True)
        return fake_home

    def test_exits_zero_always(self, tmp_path: Path) -> None:
        """permission-request must always exit 0 (never block permission flow)."""
        stdin_data = json.dumps({"tool_name": "Bash", "command": "ls -la"})
        fake_home = self._fake_home(tmp_path)
        result = _run_hook(
            "permission-request",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0, (
            f"permission-request must exit 0, got {result.returncode}\n"
            f"stderr: {result.stderr}"
        )

    def test_warns_on_destructive_rm_rf(self, tmp_path: Path) -> None:
        """permission-request warns on rm -rf commands."""
        stdin_data = json.dumps({"tool_name": "Bash", "command": "rm -rf /some/path"})
        fake_home = self._fake_home(tmp_path)
        result = _run_hook(
            "permission-request",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        assert "Destructive" in result.stdout or "destructive" in result.stdout.lower(), (
            f"Expected destructive command warning, got: {result.stdout!r}"
        )

    def test_no_warning_for_safe_command(self, tmp_path: Path) -> None:
        """permission-request produces no warning for safe commands."""
        stdin_data = json.dumps({"tool_name": "Bash", "command": "pytest tests/ -q"})
        fake_home = self._fake_home(tmp_path)
        result = _run_hook(
            "permission-request",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        assert result.stdout.strip() == "", (
            f"Unexpected warning for safe command: {result.stdout!r}"
        )

    def test_creates_permission_log(self, tmp_path: Path) -> None:
        """permission-request appends to ~/.claude/permission-log.txt."""
        stdin_data = json.dumps({"tool_name": "Bash", "command": "git status"})
        fake_home = self._fake_home(tmp_path)
        result = _run_hook(
            "permission-request",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        log = fake_home / ".claude" / "permission-log.txt"
        assert log.exists(), f"permission-log.txt not created at {log}"


# ---------------------------------------------------------------------------
# post-compact hook
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestPostCompactHook:

    def _fake_home(self, tmp_path: Path) -> Path:
        """Create a fake HOME with ~/.claude/ pre-created (required by hook's set -e)."""
        fake_home = tmp_path / "home"
        (fake_home / ".claude").mkdir(parents=True)
        return fake_home

    def test_exits_zero(self, tmp_path: Path) -> None:
        """
        post-compact must exit 0.
        Run from PLUGIN_ROOT (a real git repo) so git commands succeed.
        """
        stdin_data = json.dumps({"trigger": "auto"})
        fake_home = self._fake_home(tmp_path)
        result = _run_hook(
            "post-compact",
            stdin_data=stdin_data,
            cwd=PLUGIN_ROOT,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0, (
            f"post-compact exited {result.returncode}\nstderr: {result.stderr}"
        )

    def test_outputs_context_reload_header(self, tmp_path: Path) -> None:
        """post-compact stdout should include context reload marker."""
        stdin_data = json.dumps({"trigger": "manual"})
        fake_home = self._fake_home(tmp_path)
        result = _run_hook(
            "post-compact",
            stdin_data=stdin_data,
            cwd=PLUGIN_ROOT,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        assert "RESTORED" in result.stdout or "ATLAS" in result.stdout, (
            f"Expected ATLAS branded context reload header in output: {result.stdout!r}"
        )

    def test_creates_compaction_log(self, tmp_path: Path) -> None:
        """post-compact must append to ~/.claude/compaction-log.txt."""
        stdin_data = json.dumps({"trigger": "test"})
        fake_home = self._fake_home(tmp_path)
        result = _run_hook(
            "post-compact",
            stdin_data=stdin_data,
            cwd=PLUGIN_ROOT,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        log = fake_home / ".claude" / "compaction-log.txt"
        assert log.exists(), f"compaction-log.txt not created at {log}"


# ---------------------------------------------------------------------------
# protect-plugin-cache hook (SOTA 2026-04-02)
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestProtectPluginCacheHook:

    def test_blocks_write_to_plugin_cache(self, tmp_path: Path) -> None:
        """protect-plugin-cache must exit 2 when writing to plugin cache dir."""
        fake_home = tmp_path / "home"
        fake_home.mkdir()
        cache_path = f"{fake_home}/.claude/plugins/cache/some-plugin/file.md"
        stdin_data = json.dumps({"tool_input": {"file_path": cache_path}})
        result = _run_hook(
            "protect-plugin-cache",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 2, (
            f"Expected exit 2 (block), got {result.returncode}\n"
            f"stderr: {result.stderr}"
        )
        assert "BLOQUE" in result.stderr or "READ-ONLY" in result.stderr

    def test_allows_write_to_normal_path(self, tmp_path: Path) -> None:
        """protect-plugin-cache must exit 0 for normal file paths."""
        stdin_data = json.dumps({"tool_input": {"file_path": "/tmp/normal-file.ts"}})
        result = _run_hook("protect-plugin-cache", stdin_data=stdin_data)
        assert result.returncode == 0

    def test_allows_empty_file_path(self) -> None:
        """protect-plugin-cache must exit 0 when file_path is missing."""
        stdin_data = json.dumps({"tool_input": {}})
        result = _run_hook("protect-plugin-cache", stdin_data=stdin_data)
        assert result.returncode == 0

    def test_allows_write_to_plugin_source(self, tmp_path: Path) -> None:
        """protect-plugin-cache must allow writes to the plugin SOURCE repo."""
        stdin_data = json.dumps({
            "tool_input": {"file_path": str(tmp_path / "atlas-dev-plugin" / "hooks" / "test")}
        })
        result = _run_hook("protect-plugin-cache", stdin_data=stdin_data)
        assert result.returncode == 0


# ---------------------------------------------------------------------------
# task-created-log hook (SOTA 2026-04-02)
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestTaskCreatedLogHook:

    def test_exits_zero(self) -> None:
        """task-created-log must always exit 0."""
        stdin_data = json.dumps({"tool_input": {"subject": "Test task"}})
        result = _run_hook("task-created-log", stdin_data=stdin_data)
        assert result.returncode == 0

    def test_writes_jsonl_entry(self, tmp_path: Path) -> None:
        """task-created-log must append a JSON line to task-log.jsonl."""
        fake_home = tmp_path / "home"
        (fake_home / ".claude").mkdir(parents=True)
        stdin_data = json.dumps({
            "tool_input": {"subject": "Fix auth bug"},
            "tool_result": {"task_id": "42"},
        })
        result = _run_hook(
            "task-created-log",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        log = fake_home / ".claude" / "task-log.jsonl"
        assert log.exists(), f"task-log.jsonl not created at {log}"
        line = log.read_text().strip()
        entry = json.loads(line)
        assert "ts" in entry
        assert entry["subject"] == "Fix auth bug"

    def test_handles_missing_fields(self, tmp_path: Path) -> None:
        """task-created-log must not crash on missing fields."""
        fake_home = tmp_path / "home"
        (fake_home / ".claude").mkdir(parents=True)
        stdin_data = json.dumps({})
        result = _run_hook(
            "task-created-log",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0


# ---------------------------------------------------------------------------
# permission-denied-log hook (SOTA 2026-04-02)
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestPermissionDeniedLogHook:

    def test_exits_zero(self) -> None:
        """permission-denied-log must always exit 0."""
        stdin_data = json.dumps({"tool_name": "Bash", "action": "deny"})
        result = _run_hook("permission-denied-log", stdin_data=stdin_data)
        assert result.returncode == 0

    def test_writes_jsonl_entry(self, tmp_path: Path) -> None:
        """permission-denied-log must append to permission-log.jsonl."""
        fake_home = tmp_path / "home"
        (fake_home / ".claude").mkdir(parents=True)
        stdin_data = json.dumps({
            "tool_name": "Bash",
            "action": "deny",
            "tool_input": {"command": "rm -rf /"},
        })
        result = _run_hook(
            "permission-denied-log",
            stdin_data=stdin_data,
            env_extra={"HOME": str(fake_home)},
        )
        assert result.returncode == 0
        log = fake_home / ".claude" / "permission-log.jsonl"
        assert log.exists(), f"permission-log.jsonl not created at {log}"
        entry = json.loads(log.read_text().strip())
        assert entry["tool"] == "Bash"


# ---------------------------------------------------------------------------
# cwd-changed-env hook (SOTA 2026-04-02)
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestCwdChangedEnvHook:

    def test_exits_zero(self, tmp_path: Path) -> None:
        """cwd-changed-env must always exit 0."""
        result = _run_hook("cwd-changed-env", cwd=tmp_path)
        assert result.returncode == 0

    def test_detects_dotenv(self, tmp_path: Path) -> None:
        """cwd-changed-env reports when .env is present."""
        env_file = tmp_path / ".env"
        env_file.write_text("PROJECT_ID=test-123\nSECRET_KEY=abc\n")
        result = _run_hook("cwd-changed-env", cwd=tmp_path)
        assert result.returncode == 0
        assert ".env" in result.stdout

    def test_no_output_without_dotenv(self, tmp_path: Path) -> None:
        """cwd-changed-env produces no output when no .env exists."""
        result = _run_hook("cwd-changed-env", cwd=tmp_path)
        assert result.returncode == 0
        assert result.stdout.strip() == ""
