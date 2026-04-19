---
name: devportal-chat
description: "Interactive CLI chat to the DevPortal backend via MCP SSE. Use when the user says 'devportal chat', 'dp chat', 'ask devportal', or 'query devportal'. Routes natural-language queries to the 9 DevPortal MCP tools and streams the response to the terminal."
triggers:
  - "atlas devportal chat"
  - "atlas dp chat"
  - "/atlas devportal chat"
  - "dp chat"
  - "ask devportal"
  - "query devportal about"
model: sonnet
tier: dev
---

# DevPortal Chat — Interactive MCP Query Interface

Query the DevPortal backend in natural language from the terminal.
Backed by 9 MCP tools via SSE endpoint. Streams response with tool call display.

## Usage

```bash
atlas dp chat "<query>"
atlas devportal chat "<query>"
atlas dp chat --help
```

## Examples

```bash
atlas dp chat "show me all SP plans for G3"
atlas dp chat "what entities are in domain:engineering"
atlas dp chat "summarize ADR-020"
atlas dp chat "list active plans owned by sgagnon"
atlas dp chat "claim task T-001 on SP-17"
```

## MCP Tools — Selection Guide

| Tool | When to use |
|------|-------------|
| `devportal.search` | Free-text query across all entities |
| `devportal.list_plans` | Browse plans (filter: phase, sprint, owner) |
| `devportal.get_plan` | Fetch single plan by ID |
| `devportal.get_gate` | Check DoD gate pass/fail for a phase |
| `devportal.claim_task` | Assign a task to the current user |
| `devportal.list_entities` | Browse entities by domain |
| `devportal.get_entity` | Fetch single entity by slug |
| `devportal.list_adrs` | List Architecture Decision Records |
| `devportal.add_lesson` | Persist a new lesson learned |

## Modes

**Primary** (Wave 2.5+): POST to `/api/v1/devportal/chat/stream` — full SSE streaming
with LLM-backed routing over all 9 tools.

**Degraded fallback** (404): Direct MCP call via POST to
`/api/v1/devportal/mcp/sse` with `devportal.search` and the raw query.
Output is non-streamed JSON, formatted for terminal.

## Auth & Env

```bash
ATLAS_ENV=dev   # Use http://localhost:8001 (default: prod synapse.axoiq.com)
ATLAS_TOKEN     # Bearer token (fallback: DEVPORTAL_TOKEN, ~/.atlas/credentials.json)
DEVPORTAL_URL   # Override base URL entirely
```

## V2 Roadmap

- Persistent chat history (`~/.atlas/devportal-chat-history.jsonl`)
- Streaming token-by-token rendering (ansi clear-line progressive)
- `--interactive` / REPL mode (`atlas dp chat -i`)
- Tool call annotations with latency
