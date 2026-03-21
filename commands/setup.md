Invoke the `atlas-onboarding` skill with the following arguments: $ARGUMENTS

Guided setup wizard for new ATLAS users or environment reconfiguration.
5-phase interactive onboarding with HITL gates at each step.

Subcommands:
- `/atlas setup` — Full 5-phase wizard (profile → credentials → env → context → optional)
- `/atlas setup profile` — Phase 1: User identity (name, role, expertise, preferences)
- `/atlas setup credentials` — Phase 2: Token validation (SYNAPSE, FORGEJO, AUTHENTIK)
- `/atlas setup environment` — Phase 3: Tool checks (bash, yq, docker, bun, git, etc.)
- `/atlas setup context` — Phase 4: Project context (CLAUDE.md, rules, .blueprint)
- `/atlas setup optional` — Phase 5: Optional integrations (CShip, browser, SSH)
- `/atlas setup status` — Show onboarding completion status

If no subcommand given, run full wizard.
Storage: `~/.atlas/profile.json`
