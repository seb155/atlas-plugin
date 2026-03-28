---
name: ref-react-best-practices
description: "Reference library: React performance and best practices (re-render optimization, server components, bundling, async patterns, hydration, memoization). Loaded on demand."
---

# React Best Practices Reference Library

Domain knowledge reference for React performance optimization and best practices.
Content loaded from the original global skill on demand.

See `~/.claude/skills/react-best-practices/` for full content including:
- Re-render optimization (memo, transitions, lazy state init, derived state)
- Server component patterns (caching, auth, serialization, parallel fetching)
- Bundle optimization (dynamic imports, barrel imports, conditional loading)
- Async patterns (Suspense boundaries, parallel loading, deferred await)
- Rendering optimization (content-visibility, hydration, SVG precision)
- Client-side patterns (localStorage schema, event listeners, SWR dedup)
- JavaScript micro-optimizations (Set/Map lookups, index maps, early exit)

## When to Load

Load specific `~/.claude/skills/react-best-practices/rules/` files when:
- Diagnosing performance issues in React components
- Optimizing re-renders or bundle size
- Implementing server components or async patterns
- Reviewing code for React anti-patterns

Use grep to find relevant rules:
```bash
grep -rl "keyword" ~/.claude/skills/react-best-practices/rules/
```
