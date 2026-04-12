# Code Simplifier — Post-Edit Code Quality Pass

category: code-quality
tool_prefix: (subagent type, not mcp__)
priority: 4

## When to Use
- After implementing a feature, run a simplification pass
- Focuses on recently modified code (unless told otherwise)
- Reduces complexity, improves clarity, maintains functionality
- Good for refactoring verbose implementations

## Protocol
Invoke as a subagent:
```
Agent(subagent_type: "code-simplifier", prompt: "Simplify recently modified code")
```

The agent has access to all file tools (Read, Edit, Write, Bash, Glob, Grep) and will:
1. Identify recently changed files
2. Analyze for simplification opportunities
3. Apply changes preserving all functionality

## When NOT to Use
- During initial implementation (simplify AFTER, not during)
- For architectural refactoring -> use brainstorming + plan-builder
- For security fixes -> use security-audit skill
- When the code is already clean and simple

## Fallback
Manual code review or `/atlas code-simplify` skill

## Example
User: "Clean up the code I just wrote"
-> Agent(subagent_type: "code-simplifier", prompt: "Review and simplify the files modified in the last commit")
