Invoke the `devops-deploy` skill with the following arguments: $ARGUMENTS

This is the ATLAS deployment orchestration command. It deploys code to environments
with safety gates, health checks, and rollback support.

## Deployment Types

- `/atlas deploy full` — Full pipeline: push → CI wait → all envs → DB migrate → health check
- `/atlas deploy quick [env]` — Skip CI, deploy immediately (hotfix, urgent)
- `/atlas deploy promote` — Merge dev→main (PR + auto-approve + force-merge) → auto-deploy prod
- `/atlas deploy staging` — Deploy dev → staging only
- `/atlas deploy prod` — Deploy main → prod only
- `/atlas deploy sandbox` — Deploy dev → sandbox only
- `/atlas deploy all` — Deploy all envs (staging + prod + sandbox)
- `/atlas deploy status` — Health check all configured environments
- `/atlas deploy sync [env]` — Data sync (golden dump, DB, files)
- `/atlas deploy rollback <env>` — Rollback to previous version
- `/atlas deploy dry-run [env]` — Show what would happen without executing

If no subcommand given, present deployment types via AskUserQuestion.

## Key Implementation Notes

For projects with `scripts/deploy.sh`, use it as the deploy backend:
```bash
source ~/.env
DEPLOY_SSH_HOST=docker01 ./scripts/deploy.sh <subcommand>
```

The `promote` subcommand automates: create PR → ci-bot approve → update branch → force-merge → prod auto-deploy.

Read `.atlas/deploy.yaml` for project-specific configuration. If absent, use minimal mode
(git push + CI watch).
