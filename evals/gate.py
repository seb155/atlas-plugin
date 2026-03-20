"""Release gate checker — fail CI if eval scores are below thresholds.

Usage:
    python -m evals.gate --min-structural 70 --max-regressions 0 /tmp/eval.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def check_gates(
    results_path: Path,
    min_structural: float = 70.0,
    min_behavioral: float = 60.0,
    max_regressions: int = 0,
) -> bool:
    """Check eval gates. Returns True if all pass."""
    data = json.loads(results_path.read_text(encoding="utf-8"))

    failures: list[str] = []

    structural_avg = data.get("structural_avg", 0)
    behavioral_avg = data.get("behavioral_avg", 0)
    regression_count = data.get("regression_count", 0)

    if structural_avg < min_structural:
        failures.append(
            f"Structural avg {structural_avg:.1f} < {min_structural} (FAIL)"
        )

    if behavioral_avg > 0 and behavioral_avg < min_behavioral:
        failures.append(
            f"Behavioral avg {behavioral_avg:.1f} < {min_behavioral} (FAIL)"
        )

    if regression_count > max_regressions:
        failures.append(
            f"Regressions: {regression_count} > {max_regressions} (FAIL)"
        )

    # Check for new skills without eval cases
    scores = data.get("scores", [])
    no_eval = [
        s["item_name"]
        for s in scores
        if s.get("composite", 0) == 0 and s.get("reasoning", "").startswith("SKILL.md not found")
    ]
    if no_eval:
        print(f"WARNING: Skills without eval cases: {', '.join(no_eval)}")

    if failures:
        print("\n=== EVAL GATE FAILED ===")
        for f in failures:
            print(f"  {f}")
        print()
        return False

    print("\n=== EVAL GATE PASSED ===")
    print(f"  Structural: {structural_avg:.1f}/100")
    if behavioral_avg > 0:
        print(f"  Behavioral: {behavioral_avg:.1f}/100")
    print(f"  Grade: {data.get('grade', 'N/A')}")
    print(f"  Regressions: {regression_count}")
    print()
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="ATLAS Eval Gate Checker")
    parser.add_argument("results", type=Path, help="Path to eval results JSON")
    parser.add_argument("--min-structural", type=float, default=70.0)
    parser.add_argument("--min-behavioral", type=float, default=60.0)
    parser.add_argument("--max-regressions", type=int, default=0)

    args = parser.parse_args()

    if not args.results.exists():
        print(f"ERROR: Results file not found: {args.results}")
        sys.exit(1)

    passed = check_gates(
        args.results,
        min_structural=args.min_structural,
        min_behavioral=args.min_behavioral,
        max_regressions=args.max_regressions,
    )

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
