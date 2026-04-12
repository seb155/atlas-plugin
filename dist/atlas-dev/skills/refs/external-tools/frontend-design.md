# Frontend Design — Distinctive UI Implementation

category: design
tool_prefix: (subagent type, not mcp__)
priority: 4

## When to Use
- Implementing UI from design specs, wireframes, or mockups
- Building production React/TypeScript components with high design quality
- Translating ASCII mockups into real components
- When generic AI aesthetics should be avoided

## Protocol
Invoke as a subagent:
```
Agent(subagent_type: "atlas-dev:design-implementer", prompt: "Implement [design description]")
```

Or use the ATLAS skill:
```
/atlas frontend-design
```

The agent translates designs into production components following:
- Project conventions (component patterns, styling approach)
- Tailwind v4 utility classes
- React 19 patterns
- Responsive design principles

## When NOT to Use
- Backend logic, API routes, database schemas
- Simple layout changes (just edit the file directly)
- Non-React projects

## Fallback
Manual implementation using existing component patterns from the codebase

## Example
User: "Build a dashboard card component matching this mockup"
-> Agent(subagent_type: "atlas-dev:design-implementer", prompt: "Implement dashboard card: [specs]")
