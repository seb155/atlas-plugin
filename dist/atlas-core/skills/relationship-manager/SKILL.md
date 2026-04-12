---
name: relationship-manager
description: "Create or update deep relationship profiles for team members and collaborators. Use when 'relationship', 'team member profile', 'who is', 'update relationship', 'add team member', 'trust level', 'collaboration', 'relationship update'."
effort: medium
---

# Relationship Manager — Relational Context

> Create and update deep relationship files for team members, collaborators, and
> stakeholders. Captures trust, dynamics, strengths, and interaction history.
> Part of the SP-EXP Experiential Memory Layer (v4).

## When to Use

- When onboarding a new team member
- When you want to capture relationship dynamics after a collaboration
- When Dream Phase 3.7 detects a person mentioned 3+ times without a relationship file
- When you want to update trust levels or interaction history

## Arguments

`/atlas relationship {person-name}` — create or update a profile for this person

## Steps

### Check Existing

1. Look for `memory/relationship-{person-slug}.md` in the memory directory
2. If found → **UPDATE mode**
3. If not found → **CREATE mode**

### UPDATE Mode

1. Read the current relationship file
2. Ask what changed via AskUserQuestion:
   - Options: "New interaction to log" / "Trust level changed" / "New strength observed" / "Update role/org" / "General update"
3. Based on choice:
   - **New interaction**: Ask context + quality, add row to Interaction History table
   - **Trust level**: Ask new level + reason, update frontmatter
   - **New strength**: Ask what observed, add to strengths list
   - **Role/org**: Ask new values, update Identity section
4. Always update `last_interaction` date
5. HITL gate: show changes before writing

### CREATE Mode

1. Ask **role** via AskUserQuestion (free text)
2. Ask **organization** via AskUserQuestion (free text)
3. Ask **2-3 strengths** (free text)
4. Ask **interaction style**: "How do they prefer to communicate?"
5. Ask **trust level**: "Low" / "Medium" / "High"
6. Generate file from relationship template:
   ```yaml
   ---
   name: {Full Name}
   description: {Role + relationship summary}
   type: relationship
   knowledge: propositional
   person: {Full Name}
   role: {role}
   organization: {org}
   strengths:
     - {strength 1}
     - {strength 2}
   interaction_style: {style}
   trust_level: {level}
   collaboration_quality: good  # Default
   last_interaction: {today YYYY-MM-DD}
   ---
   ```
7. HITL gate: preview before write

### Reclassification Check

After create/update, check if `memory/team_{person_slug}.md` exists (old format):
- If found, propose via AskUserQuestion:
  "Found existing team_{person}.md (old format). Migrate to relationship format?"
  - Options: "Yes, migrate + archive old" / "Keep both" / "Skip"
- If migrate: content from old file merged into relationship file, old renamed to `_archived-team_{person}.md`

### Write + Index

1. Write to `memory/relationship-{person-slug}.md`
2. Update MEMORY.md EXPERIENTIAL CONTEXT table (relationship count)

## Template Reference

For full template, read `${SKILL_DIR}/../memory-dream/references/relationship-template.md`
For schema, read `${SKILL_DIR}/../memory-dream/references/experiential-schema.md`
