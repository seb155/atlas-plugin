---
name: ci
description: "Check CI status, view logs, rerun failed jobs, manage runners"
---

# /ci

Manage the Forgejo Actions CI/CD pipeline. Use the `forgejo-ci` subagent for detailed operations.

## Sub-commands

- `/atlas ci` or `/atlas ci status` — List recent CI runs with status
- `/atlas ci logs` — Get logs via SSH to runner host (Forgejo v14 has no log API)
- `/atlas ci rerun` — Re-dispatch the latest workflow
- `/atlas ci runners` — Show runner fleet (capacity, labels, status)
- `/atlas ci rebuild-image` — Rebuild + deploy ci-atlas Docker image to all runners

## Runner Fleet

- **hlb-git-runner** (192.168.10.75, LXC 105): capacity 3, ci-atlas image
- **ci-runner** (192.168.10.70, VM 700): capacity 4, ci-atlas image
- **Total**: 7 concurrent jobs, cache server on port 8088

## Notes

- Forgejo v14.0.3 has NO job log API — use SSH to runner hosts for logs
- Auto-release creates tags + Forgejo Releases on push to main
- CI image: `ci-atlas:latest` (Python 3.10, pytest, yq, jq pre-installed)
