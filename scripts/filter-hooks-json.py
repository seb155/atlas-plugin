#!/usr/bin/env python3
"""Filter master hooks.json to include only hooks matching allowed script names.

Usage: python3 filter-hooks-json.py hooks/hooks.json script1 script2 ...

Reads the master hooks.json and outputs a filtered version containing only
hook entries whose command references one of the allowed script names.
Inline commands (no ${CLAUDE_PLUGIN_ROOT} reference) are always preserved
for non-empty hook lists (e.g., PreCompact echo).
"""
import json
import re
import sys


def extract_script_name(command: str) -> str | None:
    """Extract script name from hook command string.

    Handles two formats:
    1. Direct: "${CLAUDE_PLUGIN_ROOT}/hooks/session-start"  → "session-start"
    2. Wrapper: "${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.sh" inject-datetime  → "inject-datetime"
    """
    # Format 2: run-hook.sh wrapper with subcommand
    m = re.search(r'/hooks/run-hook\.sh["\s]+(\S+)', command)
    if m:
        return m.group(1)
    # Format 1: direct hook script
    m = re.search(r'/hooks/([^"]+)"?$', command)
    return m.group(1) if m else None


def filter_hooks(master: dict, allowed: set[str]) -> dict:
    """Return filtered hooks.json with only allowed script entries."""
    result: dict = {"hooks": {}}
    for event, matcher_groups in master.get("hooks", {}).items():
        filtered_groups = []
        for group in matcher_groups:
            filtered_entries = []
            for entry in group.get("hooks", []):
                cmd = entry.get("command", "")
                script = extract_script_name(cmd)
                if script is None:
                    # True inline command (e.g., PreCompact echo) — always keep
                    filtered_entries.append(entry)
                elif script in allowed:
                    filtered_entries.append(entry)
            if filtered_entries:
                new_group = dict(group)
                new_group["hooks"] = filtered_entries
                filtered_groups.append(new_group)
        if filtered_groups:
            result["hooks"][event] = filtered_groups
    return result


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <hooks.json> [script1 script2 ...]", file=sys.stderr)
        sys.exit(1)

    hooks_path = sys.argv[1]
    allowed = set(sys.argv[2:])

    with open(hooks_path) as f:
        master = json.load(f)

    filtered = filter_hooks(master, allowed)
    print(json.dumps(filtered, indent=2))


if __name__ == "__main__":
    main()
