# SKILL.md Frontmatter Reference

Complete specification for all SKILL.md frontmatter fields and body conventions.

---

## File Location

```
skills/{skill-name}/SKILL.md
```

Each skill lives in its own directory under `skills/`. The directory name becomes the default skill name.

---

## Frontmatter Fields

All fields are specified in YAML frontmatter between `---` delimiters.

### Identity

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `string` | Directory name | Skill identifier. Kebab-case, max 64 characters. Must be unique within the plugin. |
| `description` | `string` | — | Third-person description with trigger phrases. Used for auto-invocation matching. **Strongly recommended.** |
| `argument-hint` | `string` | — | Autocomplete hint shown in the `/` menu. Example: `"[filename] [format]"` |

### Invocation Control

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `disable-model-invocation` | `boolean` | `false` | When `true`, prevents Claude from auto-loading this skill based on context. Skill can only be invoked explicitly via `/plugin:skill-name`. |
| `user-invocable` | `boolean` | `true` | When `false`, hides the skill from the `/` menu. Useful for skills that are only invoked by other skills or agents, not directly by users. |
| `allowed-tools` | `string` | All tools | Comma-separated list of tool names this skill can use. Restricts the tool set when the skill is active. Example: `"Bash, Read, Write, Edit"` |

### Model & Execution

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `model` | `string` | `inherit` | Which model runs this skill. Values: `sonnet`, `opus`, `haiku`, `inherit`, or a full model ID like `claude-sonnet-4-20250514`. `inherit` uses the session's current model. |
| `context` | `string` | — | Set to `fork` to run the skill in an isolated subagent context. The subagent gets a fresh context window with only the skill instructions. Results are returned to the parent. |
| `agent` | `string` | — | Name of the agent to use when `context: fork` is set. Can be a built-in agent (`Explore`, `Plan`) or a custom agent name defined in the plugin's `agents/` directory. |

### Hooks (Skill-Scoped)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `hooks` | `object` | — | Lifecycle hooks scoped to this skill only. Same format as global hooks but only fire when this skill is active. |

Example:

```yaml
---
name: deploy
hooks:
  PreToolUse:
    - matcher: Bash
      type: prompt
      prompt: "Verify this command is safe for production before allowing."
---
```

---

## String Substitutions

Available in the skill body (below the frontmatter):

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `$ARGUMENTS` | Full argument string from user | `"src/app.ts json"` |
| `$ARGUMENTS[0]` | First argument (0-based index) | `"src/app.ts"` |
| `$ARGUMENTS[1]` | Second argument | `"json"` |
| `$0` | Alias for `$ARGUMENTS[0]` | `"src/app.ts"` |
| `$1` | Alias for `$ARGUMENTS[1]` | `"json"` |
| `${CLAUDE_SESSION_ID}` | Current session unique ID | `"abc123-def456"` |
| `${CLAUDE_SKILL_DIR}` | Absolute path to the skill's directory | `"/home/user/.claude/plugins/my-plugin/skills/deploy"` |

Usage in body:

```markdown
Read the file at $0 and convert it to $1 format.

Full arguments received: $ARGUMENTS

Load reference from ${CLAUDE_SKILL_DIR}/references/spec.md if needed.
```

---

## Progressive Disclosure (3 Levels)

Skills use progressive disclosure to manage context budget efficiently:

### Level 1 — Metadata (Frontmatter)

Loaded during skill discovery. Claude reads `name` and `description` to decide whether to invoke the skill. Keep descriptions concise but include trigger phrases.

```yaml
description: "Generate deployment manifests. Use when user says 'deploy', 'release', 'ship to prod', or 'create deployment'."
```

### Level 2 — Body (Below Frontmatter)

Loaded when the skill is invoked. Contains the main instructions. Ideal size: **1500-2000 words**. Hard maximum: **5000 words**.

### Level 3 — Bundled Resources

Loaded on demand from subdirectories. The skill body references these files, and Claude reads them only when needed.

```
skills/my-skill/
├── SKILL.md
├── references/          # Detailed specs, schemas, examples
│   ├── api-spec.md
│   └── schema.md
├── scripts/             # Executable scripts
│   ├── validate.sh
│   └── generate.py
├── examples/            # Example files, templates
│   ├── minimal.json
│   └── full.json
└── assets/              # Static assets (images, configs)
    └── template.yaml
```

Reference in the body:

```markdown
For the full API specification, read ${CLAUDE_SKILL_DIR}/references/api-spec.md.
```

---

## Body Writing Rules

### Structure

- Write in **imperative form** (do X, create Y, validate Z)
- Start with a 1-2 sentence summary of what the skill does
- Use headers (`##`) to organize sections
- Include a workflow/steps section for multi-step skills
- End with error handling / edge cases

### Length Guidelines

| Length | Guidance |
|--------|----------|
| < 500 words | Too short — likely missing edge cases |
| 500-1500 words | Acceptable for simple, focused skills |
| **1500-2000 words** | **Ideal** — thorough without bloat |
| 2000-5000 words | Acceptable if complex; consider splitting to references |
| > 5000 words | **Too long** — move detail to `references/` subdirectory |

### Description Best Practices

The `description` field is critical for auto-invocation. Write it in third person and include explicit trigger phrases in quotes:

```yaml
# GOOD — specific triggers, clear scope
description: "Build Claude Code plugins from scratch with correct structure, validation, and publishing. This skill should be used when the user asks to 'create a plugin', 'build a plugin', 'scaffold a plugin', or needs help with plugin.json."

# BAD — vague, no trigger phrases
description: "Helps with plugins."
```

---

## Complete Examples

### Minimal Skill

```yaml
---
name: greet
description: "Greet the user. Use when user says 'hello', 'hi', 'hey'."
---

Greet the user warmly and ask how you can help today.
```

### Standard Skill

```yaml
---
name: code-review
description: "Review code for quality, bugs, and best practices. Use when user says 'review this code', 'check my code', 'code review', or 'find bugs'."
argument-hint: "[file-or-directory]"
model: sonnet
allowed-tools: "Read, Glob, Grep, Bash"
---

# Code Review

Review the target code at $ARGUMENTS for quality, correctness, and maintainability.

## Process

1. Read the target file(s) at $0
2. Analyze for: bugs, security issues, performance problems, code style
3. Check against project conventions (read CLAUDE.md if present)
4. Present findings in a structured table

## Output Format

| Severity | File | Line | Issue | Suggestion |
|----------|------|------|-------|------------|

Severity levels: CRITICAL, WARNING, INFO
```

### Advanced Skill (Forked Subagent)

```yaml
---
name: deep-research
description: "Conduct deep multi-source research on a topic. Use when user says 'research', 'deep dive', 'investigate thoroughly'."
argument-hint: "[topic]"
model: opus
context: fork
agent: Explore
disable-model-invocation: true
allowed-tools: "WebSearch, WebFetch, Read, Write"
hooks:
  PostToolUse:
    - matcher: Write
      type: prompt
      prompt: "Verify the written content is factual and properly sourced."
---

# Deep Research

Conduct thorough multi-source research on: $ARGUMENTS

## Methodology

1. Decompose the topic into 3-5 sub-questions
2. Search each sub-question with WebSearch
3. Fetch and analyze top 3 sources per sub-question
4. Cross-reference findings for consistency
5. Write a structured report to ./research-output.md

## Report Structure

- Executive Summary (3-5 sentences)
- Key Findings (bulleted, with source citations)
- Detailed Analysis (per sub-question)
- Contradictions & Gaps
- Recommendations

For detailed output formatting, read ${CLAUDE_SKILL_DIR}/references/report-format.md.
```

### Internal-Only Skill (Not User-Invocable)

```yaml
---
name: validate-output
description: "Validate generated output against schema."
user-invocable: false
allowed-tools: "Bash, Read"
---

Validate the output file at $0 against the schema at ${CLAUDE_SKILL_DIR}/references/schema.json.

Run: `bash ${CLAUDE_SKILL_DIR}/scripts/validate.sh "$0"`

Report pass/fail with details.
```
