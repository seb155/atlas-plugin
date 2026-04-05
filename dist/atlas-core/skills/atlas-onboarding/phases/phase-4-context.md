# Phase 4: 📄 Project Context

Check current project directory:

```bash
[ -f CLAUDE.md ]                    # Project CLAUDE.md
[ -d .claude/rules ]                # Rules directory
[ -d .blueprint ]                   # Blueprint directory
[ -f .blueprint/FEATURES.md ]       # Feature registry
```

For each gap, AskUserQuestion:
- Missing CLAUDE.md → "Generate from project scan? (uses W3H format, ~100 lines)"
- Missing .claude/rules/ → "Create basic rules (code-quality, testing)?"
- Missing .blueprint/ → "Create blueprint structure (INDEX.md, plans/)?"

If approved, invoke the relevant generation:
- CLAUDE.md: scan package.json/requirements.txt/docker-compose, generate W3H template
- Rules: extract conventions from existing code patterns
- Blueprint: create minimal directory structure
