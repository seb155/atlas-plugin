# Skill Development Rules

## SKILL.md Structure
```yaml
---
name: skill-name          # kebab-case, matches directory name
description: "..."         # Trigger-friendly description for CC matching
effort: medium             # low | medium | high (for model routing)
---
```

## Content Patterns
- Lead with purpose statement (what this skill does)
- Triggers section: when this skill activates (keywords, user intents)
- Workflow: numbered steps with clear inputs/outputs
- Output format: show expected output structure
- Constraints: guardrails, max attempts, HITL gates
- Size: 60-200 lines (progressive disclosure)

## Checklist — Adding a New Skill
1. `mkdir skills/{name}` + create `SKILL.md` with frontmatter
2. Add to `profiles/{tier}.yaml` under `skills:`
3. Add to `scripts/generate-master-skill.sh`:
   - `EMOJI_MAP[{name}]="emoji"`
   - `DESC_MAP[{name}]="one-liner"`
   - `CATEGORY_MAP[{name}]="Category"`
4. Create `commands/{name}.md` for /atlas routing
5. Add command to `profiles/{tier}.yaml` under `commands:`
6. Run `make test` — validates everything
7. Run `make dev` — install + test in live session

## Quality Gates
- Frontmatter: validated by `test_skill_frontmatter.py`
- Coverage: validated by `test_skill_coverage.py` (no orphans)
- Cross-refs: validated by `test_cross_references.py`
- Quality: validated by `test_skill_quality.py`
- No hardcoded paths: validated by `test_no_hardcoded_paths.py`

## Common Mistakes
- Forgetting `effort:` in frontmatter → test failure
- Forgetting emoji in generate-master-skill.sh → ❓ fallback in built SKILL.md
- Creating skill without command → not accessible via /atlas
- Creating command without adding to profile → not built into dist/
