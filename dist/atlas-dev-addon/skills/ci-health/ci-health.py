#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-AXOIQ-Proprietary
"""ci-health.py — Woodpecker observability dashboard for ATLAS sessions.

Per .blueprint/plans/hazy-mapping-stallman.md Phase 5 T5.1 + T5.4.

Reads:    ci.axoiq.com API (WP_TOKEN env)
Writes:   JSON / human table to stdout, optional Telegram post, optional
          Forgejo issues for flaky tests.

Usage:
    WP_TOKEN=... python3 ci-health.py --since 7d --format table
    WP_TOKEN=... python3 ci-health.py --validate-p1    # exit 0 if kill_rate<8%
    WP_TOKEN=... TELEGRAM_TOKEN=... TELEGRAM_CHAT_ID=... python3 ci-health.py --post-telegram
"""
from __future__ import annotations

import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

WP_API = os.getenv("WP_API", "https://ci.axoiq.com/api")
WP_TOKEN = os.getenv("WP_TOKEN", "")
WP_REPO_ID = os.getenv("WP_REPO_ID", "1")

# Targets per plan G1/G5
TARGET_KILL_RATE_PCT_P1 = 8.0   # Phase 1 HITL gate
TARGET_KILL_RATE_PCT_P5 = 3.0   # Phase 5 final target
FLAKY_THRESHOLD = 0.20           # 20% fail rate triggers auto-issue


def _parse_since(s: str) -> datetime:
    m = re.match(r"^(\d+)([dh])$", s)
    if not m:
        raise ValueError(f"bad --since: {s} (expected '7d' / '24h')")
    n = int(m.group(1))
    unit = m.group(2)
    delta = timedelta(days=n) if unit == "d" else timedelta(hours=n)
    return datetime.now(UTC) - delta


def _fetch_pipelines(limit: int = 200) -> list[dict[str, Any]]:
    if not WP_TOKEN:
        print("error: WP_TOKEN not set", file=sys.stderr)
        sys.exit(2)
    url = f"{WP_API}/repos/{WP_REPO_ID}/pipelines?perPage={limit}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {WP_TOKEN}"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        print(f"Woodpecker API error {e.code}: {e.reason}", file=sys.stderr)
        sys.exit(3)


def _since_epoch(dt: datetime) -> int:
    return int(dt.timestamp())


def compute_metrics(pipelines: list[dict], since: datetime, branch_filter: str | None) -> dict:
    since_ts = _since_epoch(since)
    in_window: list[dict] = []
    for p in pipelines:
        ts = p.get("created") or p.get("created_at") or 0
        if ts < since_ts:
            continue
        if branch_filter and not (p.get("branch") or "").startswith(branch_filter.rstrip("*")):
            continue
        in_window.append(p)

    total = len(in_window)
    status_counts = Counter(p.get("status", "?") for p in in_window)
    killed = status_counts.get("killed", 0)
    kill_rate = (killed / total * 100.0) if total else 0.0

    workflow_durations: dict[str, list[int]] = defaultdict(list)
    for p in in_window:
        for w in p.get("workflows") or []:
            start = w.get("start_time") or w.get("started") or 0
            end = w.get("end_time") or w.get("finished") or 0
            if start and end and end > start and (w.get("state") or w.get("status")) in {"success", "failure"}:
                workflow_durations[w["name"]].append((end - start) * 1000)

    wf_p50 = {k: int(statistics.median(v)) for k, v in workflow_durations.items() if v}
    wf_p95 = {
        k: int(sorted(v)[int(len(v) * 0.95)]) if len(v) > 4 else int(max(v))
        for k, v in workflow_durations.items()
        if v
    }

    top_branches = Counter(p.get("branch") or "-" for p in in_window).most_common(5)

    now = datetime.now(UTC)
    return {
        "window_days": (now - since).total_seconds() / 86400,
        "sample_size": total,
        "kill_rate_pct": round(kill_rate, 2),
        "status_counts": dict(status_counts),
        "workflow_p50_ms": wf_p50,
        "workflow_p95_ms": wf_p95,
        "top_branches": [{"branch": b, "count": c} for b, c in top_branches],
        "generated_at": now.isoformat(),
    }


def format_table(m: dict) -> str:
    lines = [
        f"== CI Health (last {m['window_days']:.1f}d) ==",
        f"Sample: {m['sample_size']} pipelines",
        f"Kill rate: {m['kill_rate_pct']}% (target P1<{TARGET_KILL_RATE_PCT_P1}%, P5<{TARGET_KILL_RATE_PCT_P5}%)",
        "",
        "Statuses:",
    ]
    for k, v in sorted(m["status_counts"].items(), key=lambda x: -x[1]):
        lines.append(f"  {k:10} {v}")
    lines.append("")
    lines.append("Workflow latencies:")
    for wf in sorted(m["workflow_p50_ms"].keys()):
        p50 = m["workflow_p50_ms"][wf] / 1000
        p95 = m["workflow_p95_ms"].get(wf, 0) / 1000
        lines.append(f"  {wf:20} p50={p50:.1f}s  p95={p95:.1f}s")
    lines.append("")
    lines.append("Top branches:")
    for b in m["top_branches"]:
        lines.append(f"  {b['branch']:40} {b['count']}")
    return "\n".join(lines)


def post_telegram(message: str) -> bool:
    token = os.getenv("TELEGRAM_TOKEN", "")
    chat_id = os.getenv("TELEGRAM_CHAT_ID", "")
    if not (token and chat_id):
        print("skip telegram: TELEGRAM_TOKEN/CHAT_ID not set", file=sys.stderr)
        return False
    data = urllib.parse.urlencode({"chat_id": chat_id, "text": message}).encode()
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    try:
        urllib.request.urlopen(url, data=data, timeout=8)
        return True
    except Exception as e:
        print(f"telegram failed: {e}", file=sys.stderr)
        return False


def validate_p1(m: dict) -> int:
    if m["sample_size"] < 10:
        print(f"⚠ only {m['sample_size']} pipelines in window — need ≥10 for decision", file=sys.stderr)
        return 2
    if m["kill_rate_pct"] < TARGET_KILL_RATE_PCT_P1:
        print(f"✓ G1 PASSED — kill_rate {m['kill_rate_pct']}% < {TARGET_KILL_RATE_PCT_P1}%")
        return 0
    print(f"✗ G1 FAILED — kill_rate {m['kill_rate_pct']}% ≥ {TARGET_KILL_RATE_PCT_P1}%")
    return 1


def file_flaky_issues(pipelines: list[dict], _metrics: dict) -> list[dict]:
    # Placeholder for Phase 5 T5.4 — would parse pipeline logs or test reports
    # to identify flaky tests. Needs access to per-test results which require
    # junit.xml output from pytest/vitest. Stub for now; full impl in follow-up.
    print("note: flaky detection requires junit.xml output; stub only", file=sys.stderr)
    return []


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__ or "")
    ap.add_argument("--since", default="7d")
    ap.add_argument("--branch", default=None)
    ap.add_argument("--format", default="table", choices=["table", "json"])
    ap.add_argument("--out", type=Path)
    ap.add_argument("--post-telegram", action="store_true")
    ap.add_argument("--flaky-issues", action="store_true")
    ap.add_argument("--validate-p1", action="store_true")
    args = ap.parse_args()

    since = _parse_since(args.since)
    pipelines = _fetch_pipelines()
    m = compute_metrics(pipelines, since, args.branch)

    if args.validate_p1:
        return validate_p1(m)

    output = json.dumps(m, indent=2) if args.format == "json" else format_table(m)

    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output)
        print(f"wrote {args.out}", file=sys.stderr)
    else:
        print(output)

    if args.post_telegram:
        msg = (
            f"[synapse/CI] {args.since} — {m['sample_size']} runs, "
            f"kill {m['kill_rate_pct']}%"
        )
        if m["workflow_p50_ms"]:
            slowest = max(m["workflow_p50_ms"].items(), key=lambda kv: kv[1])
            msg += f", slowest: {slowest[0]} p50={slowest[1] / 1000:.0f}s"
        post_telegram(msg)

    if args.flaky_issues:
        file_flaky_issues(pipelines, m)

    return 0


if __name__ == "__main__":
    sys.exit(main())
