# YAML LSP — Schema Validation + Navigation for YAML

category: lsp
tool_prefix: (uses LSP tool directly, not mcp__)
priority: 6

## When to Use
- Validate YAML syntax + schema (profiles, hooks.json, Woodpecker pipelines)
- Find where a YAML anchor (`&name`) is defined (goToDefinition)
- Find all references to a YAML anchor (findReferences)
- Get schema hint on hover (hover) — if schema URL configured
- List keys in a YAML document (documentSymbol)

## Protocol (call order)

Uses the built-in `LSP` tool. Params: `operation`, `filePath`, `line`, `character`.

### Operations
| Operation | Purpose | When |
|-----------|---------|------|
| `goToDefinition` | Jump to anchor declaration | "Where is `*default-config` defined?" |
| `findReferences` | All uses of an anchor | "Who uses `&project-template`?" |
| `hover` | Schema info at position | "What type is this key?" |
| `documentSymbol` | Key hierarchy in a YAML file | "What top-level keys does this profile have?" |

## Supported Files
`.yaml`, `.yml`

## Prerequisites
```bash
npm install -g yaml-language-server
which yaml-language-server   # verify in PATH
```

Plugin declares the server in `dist/atlas-core/.lsp.json`. CC auto-discovers at startup.

## Schema validation

yaml-language-server supports schema associations via `schemas` field in settings.
Currently minimal config (validate + hover + completion). To enable schema validation
for specific files, extend `lsp/core.json`:

```json
{
  "lspServers": {
    "yaml-language-server": {
      "settings": {
        "yaml": {
          "schemas": {
            "kubernetes": "*.k8s.yaml",
            "https://json.schemastore.org/github-workflow.json": ".github/workflows/*.yml"
          }
        }
      }
    }
  }
}
```

## When NOT to Use
- Non-YAML files — use language-specific LSP
- Simple syntax checks (lint) — `yq` or `yamllint` is faster
- Runtime value inspection — use `jq` / `yq` / `python3 -c`

## Fallback
Grep + Read when LSP unavailable.

## Examples

**Check all profile hooks sections**:
```
LSP(operation: "documentSymbol", filePath: "profiles/core.yaml")
# Returns: skills, refs, hooks, agents, persona, pipeline, banner_label
```

**Jump to an anchor definition**:
```
LSP(operation: "goToDefinition", filePath: ".woodpecker/ci.yml", line: 42, character: 8)
```

## Known limitations (yaml-language-server)

- No custom validation for our `profiles/*.yaml` schema (would need a JSON schema registered)
- Anchor resolution across files not supported (YAML spec limitation)
- Does not understand CC-specific fields (hooks, lsps) without schema registration

Complement with:
- `yq -e '.'` for syntax validation
- `python3 -c "import yaml; yaml.safe_load(open('x.yaml'))"` for quick parse check

Reference: https://github.com/redhat-developer/yaml-language-server
