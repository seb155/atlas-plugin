#!/usr/bin/env python3
"""Fix SC2155 warnings (masking return values in local+assign).

Transforms:
    local VAR=$(cmd)
into:
    local VAR
    VAR=$(cmd)

SAFE PATTERNS (transformed):
    local foo=$(cmd)
    local foo=$(cmd arg)
    local foo=$(cmd | filter)

SKIPPED (requires manual review):
    local foo=$(a) bar=$(b)       # multi-assign — too risky
    local readonly foo=$(cmd)     # attribute variants
    local -r foo=$(cmd)           # typeset flags
    local foo="$bar"              # not a command substitution
    local foo=${var}              # parameter expansion, not $()

Usage:
    python3 scripts/fix-sc2155.py FILE [FILE ...]      # fix in place
    python3 scripts/fix-sc2155.py --dry-run FILE ...   # preview
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Match: leading whitespace + "local" + space + VAR + "=$(..." (command sub)
# Exclude multi-assign, typeset flags, no-cmd-sub patterns.
PATTERN = re.compile(
    r"^(?P<indent>\s*)local\s+(?P<var>[a-zA-Z_][a-zA-Z0-9_]*)=\$\((?P<rest>.*)$"
)

# Patterns to skip entirely (risky)
SKIP_PATTERNS = [
    re.compile(r"^\s*local\s+-[a-zA-Z]"),     # local -r, local -a, etc
    re.compile(r"^\s*local\s+readonly\s"),    # local readonly
    re.compile(r"^\s*local\s+\w+=\S+\s+\w+="), # multi-assign on one line
]


def transform_line(line: str) -> tuple[str, bool]:
    """Return (new_content, was_transformed)."""
    # Skip risky patterns
    for skip in SKIP_PATTERNS:
        if skip.match(line):
            return line, False

    m = PATTERN.match(line)
    if not m:
        return line, False

    indent = m.group("indent")
    var = m.group("var")
    rest = m.group("rest")  # content after $( up to newline

    # Build the replacement: two lines
    # Original: <indent>local VAR=$(rest\n
    # New:     <indent>local VAR\n<indent>VAR=$(rest\n
    new_content = f"{indent}local {var}\n{indent}{var}=$({rest}\n"
    return new_content, True


def process_file(path: Path, dry_run: bool = False) -> tuple[int, int]:
    """Return (transformations, skipped_risky)."""
    lines = path.read_text().splitlines(keepends=True)
    new_lines: list[str] = []
    transformed = 0

    for line in lines:
        new, changed = transform_line(line)
        if changed:
            transformed += 1
        new_lines.append(new)

    if transformed == 0:
        return 0, 0

    if dry_run:
        print(f"{path}: {transformed} fixes (dry-run)")
    else:
        path.write_text("".join(new_lines))
        print(f"{path}: {transformed} fixes applied")

    return transformed, 0


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    files = [Path(a) for a in args if not a.startswith("--")]

    if not files:
        print(__doc__)
        sys.exit(1)

    total = 0
    for f in files:
        if not f.is_file():
            print(f"SKIP: {f} not a file", file=sys.stderr)
            continue
        t, _ = process_file(f, dry_run=dry_run)
        total += t

    verb = "would fix" if dry_run else "fixed"
    print(f"\nTotal: {total} SC2155 {verb}")


if __name__ == "__main__":
    main()
