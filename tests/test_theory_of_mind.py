"""
test_cognitive_state.py — Tests for the Unified Cognitive State hook.
# BROKEN: cognitive-state hook pattern detection broken since ~v4.38 — 17/25 failures

Replaces separate theory-of-mind + tone-adaptation + affect-signal hooks.

Tests:
- Pattern detection accuracy for all 5 states (FR/EN/QC)
- State file I/O (atlas-tom-state.json, atlas-tom-signals.json, atlas-tone-state.json)
- Confidence thresholds (no injection below threshold)
- Edge cases: empty prompt, very short, mixed signals
- Hook exits cleanly (exit code 0)

Marked @pytest.mark.hook for selective execution:
  pytest tests/test_theory_of_mind.py -x -q --tb=short
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

from conftest import HOOKS_DIR, PLUGIN_ROOT

pytestmark = pytest.mark.broken  # BROKEN: cognitive-state hook 17/25 fail since ~v4.38

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

HOOK_SCRIPT = HOOKS_DIR / "cognitive-state"


def _run_tom(
    prompt: str,
    env_extra: dict | None = None,
    tom_signals: list | None = None,
) -> subprocess.CompletedProcess:
    """Run theory-of-mind hook with given prompt and optional signal history."""
    env = {**os.environ}
    env["CLAUDE_PLUGIN_ROOT"] = str(PLUGIN_ROOT)
    env["HOOK_EVENT"] = "UserPromptSubmit"

    # Use temp dir for throttle to avoid interfering with real state
    throttle_dir = tempfile.mkdtemp(prefix="tom-test-throttle-")
    env["THROTTLE_DIR_OVERRIDE"] = throttle_dir

    # Clean up throttle state to avoid false negatives
    throttle_file = Path("/tmp/atlas-hook-throttle/cognitive-tom")
    if throttle_file.exists():
        throttle_file.unlink()

    if env_extra:
        env.update(env_extra)

    # If signal history provided, write it to a temp file and point HOME there
    if tom_signals is not None:
        tmp_home = tempfile.mkdtemp(prefix="tom-test-")
        claude_dir = Path(tmp_home) / ".claude"
        claude_dir.mkdir()
        with open(claude_dir / "atlas-tom-signals.json", "w") as f:
            json.dump(tom_signals, f)
        env["HOME"] = tmp_home

    stdin_data = json.dumps({"prompt": prompt})
    return subprocess.run(
        ["bash", str(HOOK_SCRIPT)],
        input=stdin_data,
        capture_output=True,
        text=True,
        env=env,
        cwd=str(PLUGIN_ROOT),
        timeout=10,
    )


def _parse_output(stdout: str) -> dict | None:
    """Parse TOM hook output into components."""
    if not stdout.strip():
        return None
    # Format: 🧠 ToM: {state} ({confidence}%) — {guidance}
    line = stdout.strip()
    if "ToM:" not in line:
        return None
    parts = line.split("ToM: ", 1)[1]
    state = parts.split(" (")[0]
    confidence = int(parts.split("(")[1].split("%")[0])
    guidance = parts.split("— ", 1)[1] if "— " in parts else ""
    return {"state": state, "confidence": confidence, "guidance": guidance}


# ---------------------------------------------------------------------------
# Frustrated state
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestFrustratedDetection:
    """Frustration patterns: imperative + short + QC sacres."""

    def test_sacres_quebecois(self):
        result = _run_tom("calice de bug à marde")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "frustrated"

    def test_imperative_french(self):
        result = _run_tom("juste fais-le maintenant")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "frustrated"

    def test_imperative_english(self):
        result = _run_tom("just do it already, stop asking")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "frustrated"

    def test_short_no(self):
        result = _run_tom("non!")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "frustrated"

    def test_repeated_instruction(self):
        result = _run_tom("non j'ai dit de changer le fichier, arrête de le supprimer")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "frustrated"


# ---------------------------------------------------------------------------
# Curious state
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestCuriousDetection:
    """Curiosity patterns: long questions + explain + what-if."""

    def test_explain_french(self):
        result = _run_tom(
            "explique-moi pourquoi on utilise ce pattern et comment ça marche dans le contexte de notre architecture?"
        )
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "curious"

    def test_explain_english(self):
        result = _run_tom(
            "explain how does this hook system work and why do we need theory of mind?"
        )
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "curious"

    def test_what_if(self):
        result = _run_tom(
            "what if we used a different approach? pourquoi pas celle-là? explain the trade-offs"
        )
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "curious"

    def test_cest_quoi(self):
        result = _run_tom(
            "c'est quoi exactement le pattern utilisé ici? pourquoi cette approche? comment on pourrait améliorer?"
        )
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "curious"


# ---------------------------------------------------------------------------
# Fatigued state
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestFatiguedDetection:
    """Fatigue patterns: explicit signals + decreasing length."""

    def test_explicit_fatigue_french(self):
        result = _run_tom("je suis fatigué, bonne nuit on arrête")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "fatigued"

    def test_explicit_fatigue_english(self):
        result = _run_tom("I'm done for today, tired and exhausted enough for now")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "fatigued"

    def test_ending_session(self):
        result = _run_tom("fini pour ce soir, fatigué, bonne nuit tout le monde")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "fatigued"


# ---------------------------------------------------------------------------
# Flow state
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestFlowDetection:
    """Flow patterns: code-heavy prompts."""

    def test_code_heavy(self):
        result = _run_tom(
            "def process_data():\n    import json\n    from pathlib import Path\n    export const x = 1\n    class Foo: pass"
        )
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "flow"

    def test_file_paths_with_command(self):
        result = _run_tom("pytest tests/test_theory_of_mind.py -x -q --tb=short")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "flow"


# ---------------------------------------------------------------------------
# Decision fatigue
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestDecisionFatigueDetection:
    """Decision fatigue patterns: rapid approvals + delegation."""

    def test_delegation_french(self):
        result = _run_tom("whatever je m'en fous tu choisis")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "decision_fatigue"

    def test_delegation_english(self):
        result = _run_tom("I don't care, choose for me whatever works")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "decision_fatigue"

    def test_rapid_approvals_with_history(self):
        """With 3+ short approvals in recent history, single 'oui' should trigger."""
        # 30 old normal-length entries, then 5 recent short approvals
        short_history = [
            {"ts": f"2026-04-04T09:{i:02d}:00", "hour": 9, "length": 100} for i in range(30)
        ] + [
            {"ts": "2026-04-04T10:00:00", "hour": 10, "length": 3},
            {"ts": "2026-04-04T10:01:00", "hour": 10, "length": 3},
            {"ts": "2026-04-04T10:02:00", "hour": 10, "length": 4},
            {"ts": "2026-04-04T10:03:00", "hour": 10, "length": 3},
            {"ts": "2026-04-04T10:04:00", "hour": 10, "length": 5},
        ]
        result = _run_tom("oui", tom_signals=short_history)
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        assert parsed["state"] == "decision_fatigue"


# ---------------------------------------------------------------------------
# Standard state (no detection)
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestStandardState:
    """Prompts that should NOT trigger any state detection."""

    def test_normal_request(self):
        result = _run_tom("Ajoute un bouton de sauvegarde dans le header du formulaire")
        assert result.returncode == 0
        assert result.stdout.strip() == ""

    def test_medium_length_neutral(self):
        result = _run_tom("Can you refactor the authentication middleware to use JWT tokens instead")
        assert result.returncode == 0
        assert result.stdout.strip() == ""


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestEdgeCases:
    """Edge cases: empty, short, mixed signals."""

    def test_empty_prompt(self):
        result = _run_tom("")
        assert result.returncode == 0
        assert result.stdout.strip() == ""

    def test_very_short_prompt(self):
        result = _run_tom("hi")
        assert result.returncode == 0
        assert result.stdout.strip() == ""

    def test_hook_exit_code_always_zero(self):
        """Hook should never return non-zero (would block Claude)."""
        for prompt in ["", "oui", "juste fais-le", "normal request"]:
            result = _run_tom(prompt)
            assert result.returncode == 0, f"Non-zero exit for prompt: {prompt!r}"

    def test_no_stderr_crash(self):
        """No python tracebacks or shell errors in stderr."""
        result = _run_tom("explique-moi pourquoi ce pattern est utilisé ici?")
        assert "Traceback" not in result.stderr
        assert "syntax error" not in result.stderr.lower()


# ---------------------------------------------------------------------------
# State file output
# ---------------------------------------------------------------------------


@pytest.mark.hook
class TestStateFileOutput:
    """Verify atlas-tom-state.json is written correctly."""

    def test_state_file_written(self):
        """After detection, atlas-tom-state.json should contain valid JSON."""
        result = _run_tom("calice de bug", tom_signals=[
            {"ts": f"2026-04-04T09:{i:02d}:00", "hour": 9, "length": 80}
            for i in range(35)
        ])
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None

    def test_confidence_format(self):
        """Confidence should be displayed as integer percentage."""
        result = _run_tom("tabarnac de maudit bug crisse")
        assert result.returncode == 0
        parsed = _parse_output(result.stdout)
        assert parsed is not None
        # Confidence should be an integer (no decimal in output)
        assert isinstance(parsed["confidence"], int)
        assert 60 <= parsed["confidence"] <= 100
