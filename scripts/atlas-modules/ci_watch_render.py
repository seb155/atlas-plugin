#!/usr/bin/env python3
"""ATLAS CI watch renderer.

Stateless TUI/plain renderer for `atlas ci watch --live`.
Reads pipeline meta JSON + per-step log JSON files + bash-managed state file,
prints a single frame to stdout.

Bash drives polling + curl. This script is a one-shot frame renderer.
"""

import argparse
import base64
import json
import re
import sys
import time
from pathlib import Path

STATE_ICON = {
    "success": "✅",
    "failure": "❌",
    "pending": "⏳",
    "running": "▶",
    "killed":  "☠",
    "error":   "💥",
    "skipped": "○",
    "started": "▶",
}


def load_step_logs(logs_dir, step_id, max_lines=200):
    """Decode Woodpecker log JSON for a step. Returns list of text lines."""
    if not logs_dir:
        return []
    p = Path(logs_dir) / f"{step_id}.json"
    if not p.exists():
        return []
    try:
        entries = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return []
    if not isinstance(entries, list) or not entries:
        return []
    entries.sort(key=lambda x: x.get("line", 0))
    out = []
    for e in entries[-max_lines:]:
        data = e.get("data")
        if not data:
            continue
        try:
            out.append(base64.b64decode(data).decode("utf-8", errors="replace").rstrip("\n"))
        except Exception:
            continue
    return out


# ── Framework-aware progress parsers ─────────────────────────────────
_PYTEST_PASSED = re.compile(r"(\d+)\s+passed", re.IGNORECASE)
_PYTEST_SKIPPED = re.compile(r"(\d+)\s+skipped", re.IGNORECASE)
_PYTEST_FAILED = re.compile(r"(\d+)\s+failed", re.IGNORECASE)
_PYTEST_XDIST = re.compile(r"\[\s*(\d+)%\s*\]")
_VITEST_END = re.compile(r"Tests\s+(?:(\d+)\s+failed\s*\|\s*)?(\d+)\s+passed", re.IGNORECASE)
_BUN_LINE = re.compile(r"^\s*(\d+)\s+(pass|skip|fail)\s*$", re.IGNORECASE)
_PLAYWRIGHT_END = re.compile(r"(?:(\d+)\s+failed.*?)?(\d+)\s+passed\s*\(", re.IGNORECASE)


def parse_pytest(lines):
    for line in reversed(lines[-80:]):
        m_pass = _PYTEST_PASSED.search(line)
        if m_pass:
            m_skip = _PYTEST_SKIPPED.search(line)
            m_fail = _PYTEST_FAILED.search(line)
            skip = m_skip.group(1) if m_skip else "0"
            fail = m_fail.group(1) if m_fail else "0"
            return f"pytest {m_pass.group(1)} pass, {skip} skip, {fail} fail"
    for line in reversed(lines[-80:]):
        m = _PYTEST_XDIST.search(line)
        if m:
            return f"pytest {m.group(1)}%"
    return None


def parse_vitest(lines):
    for line in reversed(lines[-80:]):
        m = _VITEST_END.search(line)
        if m:
            return f"vitest {m.group(2)} pass, {m.group(1) or '0'} fail"
    return None


def parse_bun(lines):
    pass_n = skip_n = fail_n = None
    for line in lines[-30:]:
        m = _BUN_LINE.match(line)
        if m:
            kind = m.group(2).lower()
            n = int(m.group(1))
            if kind == "pass":
                pass_n = n
            elif kind == "skip":
                skip_n = n
            elif kind == "fail":
                fail_n = n
    if pass_n is not None or fail_n is not None:
        return f"bun {pass_n or 0} pass, {skip_n or 0} skip, {fail_n or 0} fail"
    return None


def parse_playwright(lines):
    for line in reversed(lines[-80:]):
        m = _PLAYWRIGHT_END.search(line)
        if m:
            return f"playwright {m.group(2)} pass, {m.group(1) or '0'} fail"
    return None


_FRAMEWORK_HINTS = (
    ("pytest", parse_pytest, ("pytest", "tests/unit", "test_", "conftest")),
    ("vitest", parse_vitest, ("vitest", "vite test")),
    ("bun", parse_bun, ("bun test", "bun:test")),
    ("playwright", parse_playwright, ("playwright", "e2e/", ".spec.ts")),
)


def detect_progress(step_name, log_lines):
    """Detect framework from step name + recent log content, return progress string or None."""
    if not log_lines:
        return None
    name = (step_name or "").lower()
    text = "\n".join(log_lines[-50:]).lower()
    for _fw, parser, hints in _FRAMEWORK_HINTS:
        if any(h in name for h in hints) or any(h in text for h in hints):
            result = parser(log_lines)
            if result:
                return result
    return None


# ── Freeze detection ─────────────────────────────────────────────────
def load_state(state_path):
    """Load bash-managed state file: {str(step_id): last_stdout_ts_unix}."""
    if not state_path:
        return {}
    p = Path(state_path)
    if not p.exists():
        return {}
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def detect_freeze(state, step_id, threshold, now):
    """Return warning string if step_id has been silent > threshold seconds, else None."""
    last_ts = state.get(str(step_id))
    if last_ts is None:
        return None
    try:
        delta = now - float(last_ts)
    except (ValueError, TypeError):
        return None
    if delta > threshold:
        return f"⚠ frozen — no output for {fmt_duration(delta)} (threshold {threshold}s)"
    return None


def fmt_duration(sec):
    if sec is None or sec <= 0:
        return "—"
    sec = int(sec)
    if sec < 60:
        return f"{sec}s"
    m, s = divmod(sec, 60)
    if m < 60:
        return f"{m}m{s:02d}s" if s else f"{m}m"
    h, m = divmod(m, 60)
    return f"{h}h{m:02d}m" if m else f"{h}h"


def parse_meta(meta_json):
    """Normalise Woodpecker pipeline meta into a flat structure."""
    pipeline = {
        "number": meta_json.get("number", "?"),
        "branch": meta_json.get("branch", "?"),
        "commit": (meta_json.get("commit") or "")[:8],
        "status": meta_json.get("status", "?"),
        "started": meta_json.get("started", 0) or 0,
        "finished": meta_json.get("finished", 0) or 0,
    }
    workflows = []
    for wf in (meta_json.get("workflows") or []):
        steps = []
        for s in (wf.get("children") or []):
            steps.append({
                "name": s.get("name", "?"),
                "pid": s.get("pid", 0) or 0,
                "step_id": s.get("id", 0) or 0,
                "state": s.get("state", "?"),
                "started": s.get("started", 0) or 0,
                "finished": s.get("finished", 0) or 0,
                "exit_code": s.get("exit_code", 0) or 0,
            })
        workflows.append({
            "name": wf.get("name", "workflow"),
            "state": wf.get("state", "?"),
            "started": wf.get("started", 0) or 0,
            "finished": wf.get("finished", 0) or 0,
            "steps": sorted(steps, key=lambda x: x["pid"]),
        })
    return {"pipeline": pipeline, "workflows": workflows}


def step_duration(step, now):
    if step["finished"]:
        return step["finished"] - step["started"]
    if step["started"]:
        return now - step["started"]
    return 0


def render_plain(parsed, logs_dir=None, state_path=None, tail=3, freeze_threshold=60, now=None):
    """Render plain text timeline (no ANSI escapes).

    logs_dir: optional dir with per-step log JSON for progress + tail under running steps.
    state_path: optional bash-managed state JSON for freeze detection.
    tail: number of last decoded log lines per running step (0 disables tail).
    freeze_threshold: seconds without stdout to flag a step as frozen.
    """
    if now is None:
        now = time.time()
    state = load_state(state_path)
    out = []
    p = parsed["pipeline"]
    out.append(
        f"  Pipeline #{p['number']} | {p['branch']} @ {p['commit']} | {p['status']}"
    )
    for wf in parsed["workflows"]:
        wicon = STATE_ICON.get(wf["state"], "?")
        wf_dur = step_duration(wf, now) if isinstance(wf, dict) else 0
        out.append(f"  {wicon} {wf['name']:<24} {wf['state']:<10} {fmt_duration(wf_dur)}")
        for s in wf["steps"]:
            sicon = STATE_ICON.get(s["state"], "?")
            s_dur = step_duration(s, now)
            out.append(
                f"    {sicon} {s['name']:<28} {s['state']:<10} {fmt_duration(s_dur)}"
            )
            if s["state"] == "running":
                if logs_dir:
                    log_lines = load_step_logs(logs_dir, s["step_id"])
                    progress = detect_progress(s["name"], log_lines)
                    if progress:
                        out.append(f"      Progress: {progress}")
                    if log_lines and tail > 0:
                        for line in log_lines[-tail:]:
                            out.append(f"      └─ {line[:88]}")
                freeze_warn = detect_freeze(state, s["step_id"], freeze_threshold, now)
                if freeze_warn:
                    out.append(f"      {freeze_warn}")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="ci_watch_render", description=__doc__)
    ap.add_argument("meta", help="Path to pipeline meta JSON file")
    ap.add_argument("--logs-dir", default=None,
                    help="Directory containing per-step log JSONs (named <step_id>.json)")
    ap.add_argument("--state", default=None,
                    help="Path to state JSON (last_stdout_ts per step_id)")
    ap.add_argument("--tail", type=int, default=3,
                    help="Lines of log tail per running step (default 3)")
    ap.add_argument("--plain", action="store_true",
                    help="Force plain mode (no ANSI/TUI). Default if not a TTY.")
    ap.add_argument("--tty", action="store_true",
                    help="Force TUI mode (override plain auto-detect).")
    ap.add_argument("--freeze-threshold", type=int, default=60,
                    help="Seconds without stdout to consider a step frozen (default 60)")
    args = ap.parse_args(argv)

    try:
        meta_json = json.loads(Path(args.meta).read_text(encoding="utf-8"))
    except Exception as e:
        print(f"render error: cannot read meta: {e}", file=sys.stderr)
        return 2

    parsed = parse_meta(meta_json)
    print(render_plain(
        parsed,
        logs_dir=args.logs_dir,
        state_path=args.state,
        tail=args.tail,
        freeze_threshold=args.freeze_threshold,
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
