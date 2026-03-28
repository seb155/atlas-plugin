---
name: ci-management
description: "CI/CD pipeline management for Forgejo Actions. Check status, view logs, rerun failed jobs, manage runner fleet. Triggers on: /ci, 'CI status', 'check pipeline', 'rerun CI', 'runner status'."
effort: low
---

# CI Management -- Forgejo Actions Pipeline

Manage the Forgejo Actions CI/CD pipeline. Use the `forgejo-ci` subagent for detailed operations.

## When to Use

- User says "CI status", "check pipeline", "rerun CI", "runner status"
- After pushing code to check if CI passes
- When debugging CI failures
- Managing runner fleet capacity

## Sub-commands

| Command | Action |
|---------|--------|
| `/atlas ci` or `/atlas ci status` | List recent CI runs with status |
| `/atlas ci logs` | Get logs via SSH to runner host |
| `/atlas ci rerun` | Re-dispatch the latest workflow |
| `/atlas ci runners` | Show runner fleet (capacity, labels, status) |
| `/atlas ci rebuild-image` | Rebuild + deploy ci-atlas Docker image to all runners |

## Runner Fleet

| Runner | Host | Capacity | Image |
|--------|------|----------|-------|
| hlb-git-runner | 192.168.10.75 (LXC 105) | 3 | ci-atlas:latest |
| ci-runner | 192.168.10.70 (VM 700) | 4 | ci-atlas:latest |
| **Total** | | **7 concurrent jobs** | Cache on port 8088 |

## Notes

- Forgejo v14.0.3 has NO job log API -- use SSH to runner hosts for logs
- Auto-release creates tags + Forgejo Releases on push to main
- CI image: `ci-atlas:latest` (Python 3.10, pytest, yq, jq pre-installed)
- Use `ci-feedback-loop` skill for automated push -> CI green workflow

## Delegation

- Detailed log analysis: invoke `forgejo-ci` subagent
- Post-push monitoring: invoke `ci-feedback-loop` skill
