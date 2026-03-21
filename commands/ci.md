---
name: ci
description: "Check CI status, view runner fleet, rerun failed jobs, manage Forgejo Actions pipeline"
---

Invoke the ci-feedback-loop skill with: $ARGUMENTS

This command manages the Forgejo Actions CI/CD pipeline.

## Sub-commands

- `/atlas ci` or `/atlas ci status` — List recent CI runs with status
- `/atlas ci logs [run_id]` — Get logs via SSH to runner host
- `/atlas ci rerun` — Re-dispatch the latest workflow
- `/atlas ci runners` — Show runner fleet (capacity, labels, status)
- `/atlas ci rebuild-image` — Rebuild + deploy ci-atlas Docker image to all runners

## Quick Reference

```bash
# Check CI status (API)
source ~/.env && curl -sf "http://192.168.10.75:3000/api/v1/repos/${OWNER}/${REPO}/actions/tasks?limit=6" \
  -H "Authorization: token $FORGEJO_TOKEN"

# Runner logs (SSH — Forgejo v14 has no log API)
ssh root@192.168.10.75 "journalctl -u forgejo-runner --since '10 min ago' --no-pager"
ssh runner@192.168.10.70 "sudo journalctl -u forgejo-runner --since '10 min ago' --no-pager"

# Re-dispatch workflow
curl -sf -X POST "http://192.168.10.75:3000/api/v1/repos/${OWNER}/${REPO}/actions/workflows/build-publish.yaml/dispatches" \
  -H "Authorization: token $FORGEJO_TOKEN" -H "Content-Type: application/json" -d '{"ref": "main"}'

# Runner fleet
# HLB-git (192.168.10.75): capacity 3, labels: ubuntu-latest, bun, ci-atlas
# ci-runner (192.168.10.70): capacity 4, labels: ubuntu-latest, bun, ci-atlas, docker, alpine

# Rebuild ci-atlas image
docker build -f .forgejo/images/Dockerfile.ci-atlas -t ci-atlas:latest .forgejo/images/
docker save ci-atlas:latest | ssh root@192.168.10.75 "docker load"
docker save ci-atlas:latest | ssh runner@192.168.10.70 "sudo docker load"
```
