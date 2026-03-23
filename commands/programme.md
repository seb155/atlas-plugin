# /programme — Programme Dashboard

Manage the Synapse Enterprise mega plan programme.
Reads mega plan + all sub-plans + MEGA-STATUS.jsonl.

**Usage**: `/atlas programme [subcommand]`

Invoke Skill 'programme-manager'.

ARGUMENTS: $ARGUMENTS

Subcommands:
- `/atlas programme` — Dashboard (default): progress bars per phase
- `/atlas programme status` — Detailed status with rollup per sub-plan
- `/atlas programme deps` — Dependency graph (ASCII + Mermaid)
- `/atlas programme gate P{N}` — Phase gate check for specific phase
- `/atlas programme next` — Suggest next sub-plan to work on
