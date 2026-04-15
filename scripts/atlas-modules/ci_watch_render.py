#!/usr/bin/env python3
"""ATLAS CI watch renderer.

Stateless TUI/plain renderer for `atlas ci watch --live`.
Reads pipeline meta JSON + per-step log JSON files + bash-managed state file,
prints a single frame to stdout.

Bash drives polling + curl. This script is a one-shot frame renderer.
"""

import argparse
import json
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


def render_plain(parsed, now=None):
    """Render plain text timeline (no ANSI escapes)."""
    if now is None:
        now = time.time()
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
    print(render_plain(parsed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
