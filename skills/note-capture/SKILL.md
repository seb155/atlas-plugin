---
name: note-capture
description: "Quick capture notes with tags and context. Links to meetings, projects, people. Searchable knowledge base."
---

# Note Capture

Capture notes from conversation context into the PA knowledge base. Notes are persistent,
searchable, and linked to their source (meeting, project, email, conversation).

## Trigger Phrases

Activate this skill when the user says any of:
- "note this", "jot down", "remember that", "save this"
- "take a note", "capture this", "log this"
- "add to my notes", "write down"

Also activate when the user explicitly references notes:
- "find my notes about...", "what did I note about..."
- "show notes from...", "search notes for..."

## API Configuration

**Write (from CC skills)**: `http://localhost:8001/api/v1/hooks/atlas` — token-protected, no JWT
**Read (from browser)**: `http://localhost:8001/api/v1/pa` — JWT auth

For CC skills, always use the hooks router with `?user_email=seb@test.dev` query param.

## Creating a Note

### Step 1 — Extract content from conversation

Parse the user's message to identify:
- **title**: Short summary (max 120 chars). If not obvious, generate from content.
- **content**: The full note body. Preserve formatting, code blocks, URLs.
- **source_type**: One of `conversation`, `meeting`, `email`, `document`, `observation`
- **source_ref**: Link to origin (meeting_id, email subject, URL, or `null`)

### Step 2 — Auto-tag based on context

Generate tags from:
1. **Current project context** — e.g. `thm-012`, `synapse`, `atlas`
2. **Topic detection** — e.g. `procurement`, `plc`, `isa-classification`, `architecture`
3. **People mentioned** — e.g. `person:seb`, `person:client-name`
4. **Action items** — tag `action-item` if note contains a TODO or decision
5. **Meeting context** — tag `meeting:daily`, `meeting:review` if applicable

Maximum 8 tags. Use lowercase kebab-case.

### Step 3 — HITL: Confirm before saving

Present the note to the user for confirmation:

```
Note to capture:
  Title: {title}
  Tags:  {tag1}, {tag2}, {tag3}
  Source: {source_type} ({source_ref or "this conversation"})
  Content: {first 200 chars}...

Save this note? [Y/n] Adjust tags?
```

Use AskUserQuestion with the preview. Let user modify tags or title before saving.

### Step 4 — Save via API

**Schema**: `UserNoteCreate` — fields: `title`, `content`, `tags[]`, `context{}`, `project_id?`

The `context` JSONB field holds source info and metadata:

```bash
curl -s -X POST "http://localhost:8001/api/v1/hooks/atlas/notes?user_email=seb@test.dev" \
  -H "Content-Type: application/json" \
  -H "X-Atlas-Token: ${ATLAS_HOOKS_TOKEN:-}" \
  -d '{
    "title": "...",
    "content": "...",
    "tags": ["tag1", "tag2"],
    "context": {
      "source": "conversation",
      "captured_by": "atlas-skill",
      "session_id": "...",
      "branch": "dev"
    }
  }'
```

### Step 5 — Confirm save

Show confirmation:
```
Saved note #{id}: "{title}"
Tags: {tags joined}
Created: {timestamp}
```

## Searching Notes

When the user asks to find or recall notes:

```bash
# Full-text search
curl -s "http://localhost:8001/api/v1/pa/notes?search=procurement+rules" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"

# Filter by tag
curl -s "http://localhost:8001/api/v1/pa/notes?tags=thm-012,meeting" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"

# Filter by source type
curl -s "http://localhost:8001/api/v1/pa/notes?source_type=meeting" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"

# Combined filters with pagination
curl -s "http://localhost:8001/api/v1/pa/notes?search=valve&tags=procurement&limit=10&offset=0" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

Display results as a compact table:

```
| # | Title                        | Tags              | Date       |
|---|------------------------------|-------------------|------------|
| 1 | Valve procurement decision   | procurement, thm  | 2026-03-15 |
| 2 | Meeting notes — valve review | meeting, valves   | 2026-03-14 |
```

## Updating a Note

```bash
curl -s -X PATCH "http://localhost:8001/api/v1/pa/notes/{note_id}" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tags": ["updated-tag1", "tag2"], "content": "updated content..."}'
```

## Deleting a Note

Always confirm with AskUserQuestion before deletion.

```bash
curl -s -X DELETE "http://localhost:8001/api/v1/pa/notes/{note_id}" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN"
```

## Linking Notes

Notes can be linked to other PA entities via metadata:
- `meeting_id` — link to a meeting record
- `email_id` — link to an email thread
- `project` — project identifier (e.g. `thm-012`)
- `related_notes` — array of related note IDs

## Best Practices

- **One thought per note** — split multi-topic captures into separate notes
- **Title = searchable** — write titles that future-you would search for
- **Tags = findable** — use consistent tag taxonomy (project, topic, person, type)
- **Source = traceable** — always link back to where the information came from
- **Action items** — if a note contains a TODO, tag it `action-item` for easy filtering
