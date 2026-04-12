# Context7 — Library & Framework Documentation Lookup

category: documentation
tool_prefix: mcp__plugin_context7_context7__
priority: 9

## When to Use
- User asks about library/framework API, syntax, configuration
- Version migration questions (e.g., "React 18 -> 19 changes")
- CLI tool usage, SDK patterns, setup instructions
- ALWAYS prefer over WebSearch for library docs — training data may be stale

## Protocol (call order)
1. `resolve-library-id` — convert library name to Context7 ID
   - Use official name with punctuation: "Next.js" not "nextjs"
   - Params: `libraryName` (required), `query` (what you need)
   - Returns library IDs ranked by relevance + snippet count
2. `query-docs` — search docs with specific question
   - Params: `libraryId` (from step 1, format `/org/project`), `query` (specific question)
   - Returns code snippets + explanations from current docs
3. **Max 3 calls per question** — if not found after 3 tries, fall back

## When NOT to Use
- General programming concepts (loops, data structures)
- Business logic, refactoring, code review
- Debugging app-specific bugs (not library bugs)
- Writing scripts from scratch

## Fallback
WebSearch -> WebFetch on official documentation site

## Example
User: "How does useOptimistic work in React 19?"
-> resolve-library-id("React", "useOptimistic hook") -> /vercel/next.js or /facebook/react
-> query-docs("/facebook/react", "useOptimistic hook usage and examples")
-> Returns current API with code snippets
