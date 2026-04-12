# {Tool Name} — {One-line purpose}

category: {documentation|browser-automation|code-quality|lsp|auth|design|vcs}
tool_prefix: {mcp__<prefix>__}
priority: {1-10, higher = prefer over alternatives}

## When to Use
- {Trigger condition 1}
- {Trigger condition 2}

## Protocol (call order)
1. {First tool to call with key params}
2. {Second tool to call}
3. {Constraints: max calls, timeouts, etc.}

## When NOT to Use
- {Anti-pattern — when this tool is wrong choice}

## Fallback
{Alternative tool/approach if this one is unavailable or fails}

## Example
User: "{example request}"
-> {step 1} -> {step 2} -> {result}
