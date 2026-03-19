# MCP & LSP Server Configuration Reference

Complete specification for configuring MCP (Model Context Protocol) and LSP (Language Server Protocol) servers in Claude Code plugins.

---

## MCP Server Configuration

### File Location

```
.mcp.json          # At plugin root (auto-discovered)
```

Or specified in `plugin.json`:

```json
{
  "mcpServers": "./.mcp.json"
}
```

### .mcp.json Format

```json
{
  "mcpServers": {
    "server-name": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/server.js"],
      "env": {
        "API_KEY": "${MY_API_KEY}",
        "DATA_DIR": "${CLAUDE_PLUGIN_DATA}"
      },
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

### MCP Server Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `command` | `string` | **Required** | Executable to run (e.g., `node`, `python`, `npx`, path to binary) |
| `args` | `string[]` | Optional | Arguments passed to the command |
| `env` | `object` | Optional | Environment variables (key-value pairs) |
| `cwd` | `string` | Optional | Working directory for the server process |

### Variable Expansion

All string values support variable expansion:

| Variable | Description |
|----------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to the installed plugin directory |
| `${CLAUDE_PLUGIN_DATA}` | Persistent data directory for this plugin |
| `${ENV_VAR_NAME}` | Any environment variable from the user's shell |

### Examples

#### Node.js MCP Server

```json
{
  "mcpServers": {
    "my-tools": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/index.js"],
      "env": {
        "PORT": "3100"
      }
    }
  }
}
```

#### Python MCP Server

```json
{
  "mcpServers": {
    "data-tools": {
      "command": "python",
      "args": ["-m", "my_mcp_server"],
      "cwd": "${CLAUDE_PLUGIN_ROOT}/mcp",
      "env": {
        "PYTHONPATH": "${CLAUDE_PLUGIN_ROOT}/mcp"
      }
    }
  }
}
```

#### npx MCP Server

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@anthropic/mcp-playwright"]
    }
  }
}
```

#### Multiple Servers

```json
{
  "mcpServers": {
    "database": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/db-server.js"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL}"
      }
    },
    "file-tools": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/file-server.js"]
    },
    "api-client": {
      "command": "python",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/api_server.py"],
      "env": {
        "API_BASE_URL": "${API_BASE_URL}",
        "API_TOKEN": "${API_TOKEN}"
      }
    }
  }
}
```

### Inline in plugin.json

MCP servers can also be defined directly in `plugin.json` instead of a separate `.mcp.json` file:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/server.js"]
    }
  }
}
```

When `mcpServers` is a string or array in plugin.json, it points to config file(s). When it's an object, it's an inline server definition.

---

## LSP Server Configuration

### File Location

```
.lsp.json          # At plugin root (auto-discovered)
```

Or specified in `plugin.json`:

```json
{
  "lspServers": "./.lsp.json"
}
```

### .lsp.json Format

```json
{
  "lspServers": {
    "server-name": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".ts": "typescript",
        ".tsx": "typescriptreact",
        ".js": "javascript",
        ".jsx": "javascriptreact"
      },
      "transport": "stdio",
      "env": {},
      "initializationOptions": {},
      "settings": {}
    }
  }
}
```

### LSP Server Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `command` | `string` | **Required** | LSP server executable |
| `args` | `string[]` | Optional | Arguments passed to the command |
| `extensionToLanguage` | `object` | **Required** | Maps file extensions to language IDs |
| `transport` | `string` | Optional | Communication transport. Default: `"stdio"`. Options: `"stdio"`, `"tcp"` |
| `env` | `object` | Optional | Environment variables for the server process |
| `initializationOptions` | `object` | Optional | LSP initialization options sent on startup |
| `settings` | `object` | Optional | LSP workspace settings |

### extensionToLanguage

Maps file extensions (with leading dot) to LSP language identifiers:

```json
{
  "extensionToLanguage": {
    ".py": "python",
    ".pyi": "python",
    ".ts": "typescript",
    ".tsx": "typescriptreact",
    ".js": "javascript",
    ".jsx": "javascriptreact",
    ".rs": "rust",
    ".go": "go",
    ".java": "java",
    ".rb": "ruby",
    ".lua": "lua",
    ".c": "c",
    ".cpp": "cpp",
    ".h": "c",
    ".hpp": "cpp",
    ".cs": "csharp",
    ".swift": "swift",
    ".kt": "kotlin",
    ".toml": "toml",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".json": "json",
    ".md": "markdown"
  }
}
```

### Examples

#### TypeScript LSP

```json
{
  "lspServers": {
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".ts": "typescript",
        ".tsx": "typescriptreact",
        ".js": "javascript",
        ".jsx": "javascriptreact"
      },
      "initializationOptions": {
        "preferences": {
          "importModuleSpecifierPreference": "relative"
        }
      }
    }
  }
}
```

#### Python LSP (Pyright)

```json
{
  "lspServers": {
    "python": {
      "command": "pyright-langserver",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".py": "python",
        ".pyi": "python"
      },
      "settings": {
        "python": {
          "pythonPath": "/usr/bin/python3",
          "analysis": {
            "typeCheckingMode": "strict"
          }
        }
      }
    }
  }
}
```

#### Rust LSP (rust-analyzer)

```json
{
  "lspServers": {
    "rust": {
      "command": "rust-analyzer",
      "extensionToLanguage": {
        ".rs": "rust"
      },
      "settings": {
        "rust-analyzer": {
          "checkOnSave": {
            "command": "clippy"
          }
        }
      }
    }
  }
}
```

#### Multiple LSP Servers

```json
{
  "lspServers": {
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".ts": "typescript",
        ".tsx": "typescriptreact"
      }
    },
    "python": {
      "command": "pyright-langserver",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".py": "python"
      }
    },
    "css": {
      "command": "vscode-css-language-server",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".css": "css",
        ".scss": "scss",
        ".less": "less"
      }
    }
  }
}
```

### Variable Expansion

LSP configs support the same variables as MCP:

```json
{
  "lspServers": {
    "custom": {
      "command": "${CLAUDE_PLUGIN_ROOT}/bin/my-lsp",
      "env": {
        "CONFIG_PATH": "${CLAUDE_PLUGIN_ROOT}/config/lsp.yaml"
      }
    }
  }
}
```

---

## Plugin Layout with MCP + LSP

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── .mcp.json                    # MCP server configs
├── .lsp.json                    # LSP server configs
├── mcp/                         # MCP server source code
│   ├── index.js
│   └── package.json
├── skills/
├── commands/
└── hooks/
```

---

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Server not starting | Command not found | Ensure the LSP/MCP server binary is installed and in PATH |
| Variable not expanding | Missing `${}` syntax | Use `${CLAUDE_PLUGIN_ROOT}`, not `$CLAUDE_PLUGIN_ROOT` |
| Server crashes on startup | Bad init options | Check `initializationOptions` matches the server's expected schema |
| No tool discovery (MCP) | Server key mismatch | Ensure server names in `.mcp.json` are unique and kebab-case |
| LSP not activating | Missing extension mapping | Add the file extension to `extensionToLanguage` |
| Permission denied | Script not executable | `chmod +x` the MCP server script |
| Port conflict (TCP) | Another server on same port | Change the port in `env` or `args` |
