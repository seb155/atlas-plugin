Invoke the `atlas-onboarding` skill with the following arguments: $ARGUMENTS

Guided setup wizard for new ATLAS users or environment reconfiguration.
7-phase interactive onboarding with HITL gates at each step.

Subcommands:
- `/atlas setup` — Full wizard (all 7 phases)
- `/atlas setup profile` — Phase 1: User identity (name, role, expertise, preferences)
- `/atlas setup credentials` — Phase 2: Token validation (SYNAPSE, FORGEJO, AUTHENTIK)
- `/atlas setup environment` — Phase 3: Tool checks (bash, yq, docker, bun, git, etc.)
- `/atlas setup terminal` — Phase 3.5: Platform detection + shell alias installation
- `/atlas setup context` — Phase 4: Project context (CLAUDE.md, rules, .blueprint)
- `/atlas setup statusline` — Phase 5A: CShip + Starship deployment
- `/atlas setup settings` — Phase 5B: CC global + project settings validation
- `/atlas setup mcp` — Phase 5C: MCP server configuration
- `/atlas setup optional` — Phase 6: Optional integrations (SSH, Tailscale, Coder, Ollama)
- `/atlas setup status` — Show onboarding completion status

If no subcommand given, run full wizard.
Storage: `~/.atlas/profile.json`
