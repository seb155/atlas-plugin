# Migration Guide: ATLAS v5.x → v6.0

> v6.0.0-alpha.1 introduces the **Philosophy Engine** (Iron Laws + Red Flags + `<HARD-GATE>`)
> + **SOTA Opus 4.7 patterns** (adaptive thinking, effort routing, agent visibility).
> This guide walks you through the 5-step migration path.
>
> Plan reference: `.blueprint/plans/regarde-comment-adapter-atlas-compressed-wave.md`
> CHANGELOG: see `CHANGELOG.md` (v6.0.0-alpha.1 section).

---

## TL;DR

ATLAS v6.0 is **backward compatible** for skills/agents that haven't been migrated yet — defaults are preserved, nothing breaks at install time. You can adopt new features incrementally:

1. **Required (BREAKING)**: Verify zero `extended thinking` (`{type: "enabled", budget_tokens: N}`) calls in your custom skills — Opus 4.7 rejects them at the API layer.
2. **Recommended**: Enable agent-visibility env vars in `~/.claude/settings.json` (3 keys, defaults preserved).
3. **Recommended**: Bump VERSION + add v6 frontmatter (`thinking_mode`, `superpowers_pattern`, `see_also`) to your custom skills.
4. **Optional**: Adopt Philosophy Engine (Iron Laws + Red Flags + `<HARD-GATE>`) for Tier-1 skills.
5. **Optional**: Tune `effort` + `task_budget` for your custom agents per the SOTA allocation table.

> Run `./scripts/migrate-to-v6.sh` for an automated audit + suggestions.

---

## Step 1 — Extended Thinking Deprecation (BREAKING)

**What changed**: Anthropic retired the `extended thinking` API (`thinking: {type: "enabled", budget_tokens: N}`) when Opus 4.7 launched (2026-04-16). Calls fail with `400 invalid_request`.

**v6.0 replacement**: `thinking_mode: adaptive` (frontmatter key). The model self-paces its reasoning depth — no client-side budget.

**Find offenders**:

```bash
grep -rn 'thinking.*type.*enabled\|budget_tokens' hooks/ skills/ scripts/ \
  ~/.claude/skills/ ~/.claude/hooks/ 2>/dev/null
```

**Fix pattern** — for each hit:

| Before (v5.x) | After (v6.0) |
|---|---|
| `thinking: {type: enabled, budget_tokens: 8000}` (in API client code) | Remove entirely |
| `extended_thinking: true` (in skill body / hook env) | Replace with `thinking_mode: adaptive` in frontmatter |
| `THINKING_BUDGET=8000` (env var) | Delete the env var |

**Verify**: `./scripts/migrate-to-v6.sh` reports `Step 1: ✓` when zero references remain.

---

## Step 2 — Agent Visibility Env Vars

**What's new**: SP-AGENT-VIS (in v5.23) added a 3-layer visibility system (statusline counter + tmux side pane auto-tail + `atlas agents` CLI). v6.0 makes it **opt-in explicit** — defaults stay ON, but declaring them in `settings.json` makes intent visible.

**Patch your `~/.claude/settings.json`**:

```jsonc
{
  "env": {
    // ... your existing env vars ...
    "ATLAS_AUTO_TAIL_AGENTS": "1",       // Auto-tail subagents in tmux side panes
    "ATLAS_MAX_TAIL_PANES": "2",         // Cap to prevent pane proliferation
    "ATLAS_AGENT_STATUS_INTERVAL": "2"   // Poll seconds for statusline counter
  }
}
```

**Disable per-session**: `export ATLAS_AUTO_TAIL_AGENTS=0` before `claude` to opt-out (e.g., headless CI).

**Verify**: `echo $ATLAS_AUTO_TAIL_AGENTS` returns `1` in a fresh CC session.

---

## Step 3 — Frontmatter v6 Schema

**What changed**: SKILL.md and AGENT.md frontmatters gained 4 new keys (3 required, 1 optional). Backward compat: missing keys default to safe values.

### 3a. SKILL.md — Before/After

**Before (v5.x — `skills/my-skill/SKILL.md`)**:

```yaml
---
name: my-skill
description: "What this skill does, in one sentence."
effort: medium
---
```

**After (v6.0)**:

```yaml
---
name: my-skill
description: "What this skill does, in one sentence."
effort: medium
thinking_mode: adaptive          # NEW (required, only `adaptive` accepted)
superpowers_pattern: [none]      # NEW (required: iron_law|red_flags|hard_gate|none)
see_also: []                     # NEW (required, min `[]`)
version: 6.0.0                   # NEW (required, semver)
tier: [dev]                      # OPTIONAL but recommended (was implicit)
---
```

**Decision matrix for `superpowers_pattern`**:

| Skill type | Recommended pattern |
|---|---|
| Tier-1 (TDD, debugging, code review, planning) | `[iron_law, red_flags, hard_gate]` |
| Routine utility (formatter, linter, status check) | `[none]` |
| Has anti-patterns to call out but no blocking gate | `[red_flags]` |

### 3b. AGENT.md — Before/After

**Before (v5.x — `agents/my-agent/AGENT.md`)**:

```yaml
---
name: my-agent
description: "Implements features end-to-end with TDD."
model: sonnet
---
```

**After (v6.0)**:

```yaml
---
name: my-agent
description: "Implements features end-to-end with TDD."
model: claude-sonnet-4-6         # Full ID recommended (CLI alias still works)
effort: high                     # NEW (required, see SOTA table below)
thinking_mode: adaptive          # NEW (required)
version: 6.0.0                   # NEW (required)
isolation: worktree              # OPTIONAL (default `none`)
task_budget: 100000              # OPTIONAL (advisory token ceiling)
---
```

### 3c. SOTA Effort Allocation (17 ATLAS agents — v6.0 reference)

| Tier | Model | Default `effort` | When to override |
|---|---|---|---|
| **Top reasoners** (plan-architect, code-reviewer, infra-expert) | `claude-opus-4-7` | `xhigh` (architecture: `max`) | Document rationale in commit msg |
| **Engineers** (team-engineer, devops-engineer, data-engineer, team-security) | `claude-sonnet-4-6` | `high` | Downgrade only for pattern-match work |
| **Reviewers/Implementers** (team-tester, team-reviewer, design-implementer) | `claude-sonnet-4-6` | `medium` | — |
| **Analysts** (domain-analyst, team-researcher) | `claude-haiku-4-5` | `medium` | — |
| **Pollers** (team-coordinator, context-scanner) | `claude-haiku-4-5` | `low` | — |

Full table: `.blueprint/schemas/agent-frontmatter-v6.md` Section 2.

---

## Step 4 — Philosophy Engine Adoption (optional)

**What it is**: 9 Iron Laws + 25 Red Flags codified in YAML (`scripts/execution-philosophy/`). Tier-1 skills embed `<HARD-GATE>` blocks that the linter enforces (sha256 byte-match on Iron Law statements + Jaccard 80% fuzzy match on Red Flag patterns).

**When to adopt**: Skills that perform **execution discipline** (TDD enforcement, debugging methodology, code review, planning). Skip for utility skills.

### 4a. Add a HARD-GATE to a Tier-1 skill

In `skills/my-tier1-skill/SKILL.md` body, append:

```markdown
<HARD-GATE id="LAW-TDD-001">
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
This is not a recommendation. This is an Iron Law.
Write code before the test? Delete it. Start over.
</HARD-GATE>

<red-flags>
| Phrase | Severity | Action |
|---|---|---|
| "Let me write the implementation first, then add tests" | HARD-FAIL | STOP, restart with failing test |
| "The test passes immediately — no need to watch it fail" | HARD-FAIL | STOP, force red phase |
| "Just a small fix, skip the test" | WARN | Confirm trivial change with HITL |
</red-flags>
```

### 4b. Validate

```bash
./scripts/execution-philosophy/hard-gate-linter.sh skills/my-tier1-skill/SKILL.md
```

Output: `✓ LAW-TDD-001 verbatim match` or `✗ Statement mismatch (sha256 expected: ...)`.

**Iron Law corpus**: `scripts/execution-philosophy/iron-laws.yaml` (9 laws — TDD, debugging, design, verification, planning, scope drift, subagent independence, enterprise compliance, context discovery).

**Red Flag corpus**: `scripts/execution-philosophy/red-flags-corpus.yaml` (25 patterns across 5 categories).

---

## Step 5 — Effort + Task Budgets (optional)

**What it does**: Effort routing tells the model how much to think; task budgets cap output tokens (advisory ceiling, warns at 80%, kills at 100%).

**When to tune**:

- **Promote to `xhigh`/`max`**: Custom agents performing architecture, multi-file review, ultrathink reasoning.
- **Demote to `low`/`medium`**: Custom agents doing pure pattern-match, polling, classification.
- **Set `task_budget`**: Long-running agents that shouldn't blow the context window (recommend 80K for most Sonnet agents, 200K for Opus architects).

**Per-invocation override** (in chat):

```
/effort xhigh
"now refactor the entire auth module"
```

**Frontmatter override** (permanent for a custom agent):

```yaml
effort: xhigh
task_budget: 120000
```

**Verify routing works**: After invoking a Task/Agent tool, check `~/.claude/atlas-audit.log` for the `effort_router` advisory entry.

---

## Automated Helper: `scripts/migrate-to-v6.sh`

```bash
cd ~/path/to/your/install
./scripts/migrate-to-v6.sh           # audit only (default)
./scripts/migrate-to-v6.sh --verbose # show every offender
```

**Output**: 5-section report (one per Step above) with ✓ pass / ⚠ warn / ✗ fail status + suggested next action. Non-destructive — never auto-modifies files.

---

## Rollback

If v6.0-alpha breaks something for you:

```bash
# Pin to v5.23.0 (last stable v5.x)
cd ~/.claude/plugins/cache/atlas-marketplace
git checkout v5.23.0
# Restart Claude Code
```

Then file an issue at the Forgejo repo (`projects/atlas-dev-plugin/`) with:
- Your `VERSION` content (before rollback)
- `migrate-to-v6.sh` output
- The offending file/skill/agent name

---

## FAQ

**Q1. My skills/agents don't have v6 frontmatter — will install break?**
No. v6.0 is backward compatible: missing keys default to `version: 5.0.0`, `thinking_mode: adaptive`, `superpowers_pattern: [none]`, `see_also: []`. The build only fails on **active `extended thinking` references** (Step 1).

**Q2. Do I have to migrate ALL my skills at once?**
No. Migrate Tier-1 skills first (TDD, debugging, code review). Routine skills can stay on v5.x defaults indefinitely.

**Q3. What if I have a custom agent using `model: claude-opus-4-6`?**
Replace with `model: claude-opus-4-7`. Opus 4.6 was retired by Anthropic on 2026-04-16 — v5.23.0 already migrated all built-in agents. Custom agents need manual update.

**Q4. Will `thinking_mode: extended` keep working in alpha?**
**No** — `build.sh` rejects it in v6.0 (Opus 4.7 API rejects it at runtime anyway). Replace with `adaptive` everywhere.

**Q5. Can I keep my `extended thinking` calls in non-ATLAS code?**
Outside the plugin? Yes, but Opus 4.7 will reject the API call. Migrate to either `thinking_mode: adaptive` (frontmatter) or remove the thinking config (model decides on its own).

**Q6. What's the cost impact of v6.0?**
Target: ≤+15% cost vs v5.23.0 baseline. SessionStart payload grew ~23KB (atlas-assist injection) — caches well after first turn. Net effect monitored over alpha period; report anomalies via Forgejo issue.

**Q7. How do I know if v6.0 made my agents better?**
Target: ≥+25% accuracy vs v5.23.0 baseline (measured on standard task corpus). Use `atlas analytics` (in atlas-admin addon) to compare session metrics across version bumps.

---

*Updated: 2026-04-17 | v6.0.0-alpha.1 | See CHANGELOG.md for full release notes*
