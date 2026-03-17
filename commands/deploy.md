Invoke the `devops-deploy` skill with the following arguments: $ARGUMENTS

This is the ATLAS deployment orchestration command. It deploys code to environments
with safety gates, health checks, and rollback support.

Subcommands:
- `/atlas deploy [env]` — Deploy to specific environment (staging, prod, sandbox, all)
- `/atlas deploy status` — Health check all configured environments
- `/atlas deploy promote` — Merge dev→main and trigger prod deploy
- `/atlas deploy sync [env]` — Data sync (golden dump, DB, files)
- `/atlas deploy rollback <env>` — Rollback to previous version
- `/atlas deploy dry-run [env]` — Show what would happen without executing

If no subcommand given, show deploy status.

Read `.atlas/deploy.yaml` for project-specific configuration. If absent, use minimal mode
(git push + CI watch).
