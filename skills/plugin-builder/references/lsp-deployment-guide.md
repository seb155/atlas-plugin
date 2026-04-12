# LSP Server Deployment & Operations Guide

Practical guide for deploying, configuring, and maintaining LSP servers with Claude Code plugins.
For schema reference (fields, format, variable expansion), see `mcp-lsp-spec.md`.

Updated: 2026-04-11

---

## Overview

LSP (Language Server Protocol) gives Claude Code semantic code intelligence — go-to-definition,
find references, hover info, diagnostics — at 50ms instead of 45s grep. Three protocols coexist:

| Protocol | Role | CC Support |
|----------|------|------------|
| **LSP** | Code intelligence (types, nav, diagnostics) | Native since v2.0.74 (Dec 2025) |
| **MCP** | AI agent tools (DB, APIs, resources) | Native since launch |
| **ACP** | AI agent reasoning in IDEs (JetBrains/Zed) | Not supported |

LSP and MCP are complementary: LSP tells Claude what the code means, MCP gives Claude tools to act.

---

## Prerequisites

| Requirement | Check | Notes |
|-------------|-------|-------|
| Claude Code >= 2.1.50 | `claude --version` | LSP stable since 2.1.50 |
| `ENABLE_LSP_TOOL=1` | `echo $ENABLE_LSP_TOOL` | Add to `~/.claude/settings.json` (see below) |
| LSP binary installed | `which pyright` | Plugin does NOT bundle the server binary |
| Plugin installed + enabled | `claude /plugin list` | Plugins install disabled by default |

### Enable LSP in settings.json

```json
{
  "env": {
    "ENABLE_LSP_TOOL": "1"
  }
}
```

---

## Quick Start (4 steps)

```bash
# 1. Install LSP server binary (choose your language)
pip install pyright                                    # Python
npm install -g @vtsls/language-server typescript        # TypeScript
go install golang.org/x/tools/gopls@latest             # Go
rustup component add rust-analyzer                     # Rust

# 2. Add community marketplace (one time)
claude /plugin marketplace add Piebald-AI/claude-code-lsps

# 3. Install + enable plugin
claude /plugin install pyright@Piebald-AI/claude-code-lsps
claude /plugin enable pyright    # CRITICAL — often forgotten!

# 4. Restart Claude Code, verify
claude /plugin list              # should show "pyright ... enabled"
```

### Verify it works

Ask Claude: "Find all references to `my_function()`"
- **With LSP**: returns exact call sites in ~50ms
- **Without LSP**: falls back to grep (~45s, noisy results)

---

## Available Languages (Piebald-AI Marketplace, April 2026)

| Category | Languages |
|----------|-----------|
| Systems | Rust (`rust-analyzer`), C/C++ (`clangd`), Go (`gopls`) |
| Web | TypeScript (`vtsls`), HTML/CSS, Vue, Svelte |
| JVM | Java (`jdtls`), Kotlin, Scala |
| Scripting | Python (`pyright`), Ruby, PHP, PowerShell |
| Other | LaTeX, Julia, OCaml, Ada, Dart, Solidity, Markdown |

**Most deployed combo**: pyright (Python) + vtsls (TypeScript) — covers 80% of web stacks.

---

## Deployment Topology

### Where to run LSP servers

| Location | Install LSP? | Why |
|----------|-------------|-----|
| **Developer laptop** | **Yes (primary)** | CC runs here. stdio = local, 50ms latency. Best UX |
| Remote VMs (SSH) | No | Let laptop LSP handle it. CC reads files via SSH |
| **Coder workspaces** | **Yes (in container)** | Pre-install for team consistency. Isolated per workspace |
| Production VMs | **Never** | No dev tools on prod |

### Architecture diagram

```
Developer Laptop (CC + LSP)          Homelab VMs
┌─────────────────────────┐          ┌──────────────────┐
│ Claude Code             │──SSH────►│ VM 560 (code)    │
│ ├─ pyright (child proc) │          │ No LSP here      │
│ └─ vtsls (child proc)   │          └──────────────────┘
│   ~1.5 GB RAM total     │          ┌──────────────────┐
└─────────────────────────┘          │ Coder workspace   │
                                     │ ├─ pyright (in    │
                                     │ │  Dockerfile)    │
                                     │ └─ vtsls          │
                                     └──────────────────┘
```

---

## Resource Usage

| Server | RAM base | RAM peak (medium project) | CPU idle |
|--------|----------|---------------------------|----------|
| pyright (Python) | ~200 MB | ~1 GB | Low |
| vtsls (TypeScript) | ~200 MB | ~1 GB+ | Moderate |
| gopls (Go) | ~150 MB | ~500 MB | Low |
| rust-analyzer | ~300 MB | ~2 GB | Moderate |
| **Typical (2 servers)** | **~400 MB** | **~2 GB** | **OK for laptop** |

**Guideline**: Max 2-3 concurrent LSP servers on a laptop. More requires dedicated VM or container.

---

## Homelab / Coder Integration

### Pre-install LSP in Coder Dockerfile

```dockerfile
# In your Coder workspace template Dockerfile
RUN npm install -g @vtsls/language-server typescript
RUN pip install pyright
# Add to PATH if needed
ENV PATH="/root/.local/bin:$PATH"
```

### Team onboarding benefits

- Every developer gets LSP support out of the box
- No manual binary installation per workstation
- Consistent language server versions across team
- Isolated per workspace (no resource conflicts)

---

## New User Onboarding Checklist

- [ ] Claude Code >= 2.1.50 installed
- [ ] `ENABLE_LSP_TOOL=1` in `~/.claude/settings.json`
- [ ] Language server binaries installed (`which pyright`, `which vtsls`)
- [ ] Marketplace added: `claude /plugin marketplace add Piebald-AI/claude-code-lsps`
- [ ] Plugins installed AND enabled (check `claude /plugin list`)
- [ ] Claude Code restarted after plugin install
- [ ] Test: "Find references to X" returns semantic results (not grep)

---

## Maintenance

### Updating LSP servers

```bash
pip install --upgrade pyright                  # Python
npm update -g @vtsls/language-server           # TypeScript
```

### Orphaned processes (after CC crash)

```bash
# Check for lingering LSP processes
ps aux | grep -E 'pyright|vtsls|gopls|rust-analyzer'
# Kill if orphaned
pkill -f pyright-langserver
```

### Version pinning (for teams)

Pin versions in Coder Dockerfile or team setup scripts:
```bash
pip install pyright==1.1.389
npm install -g @vtsls/language-server@0.2.6
```

---

## Known Issues (April 2026)

| Issue | Severity | Workaround |
|-------|----------|------------|
| [#14803](https://github.com/anthropics/claude-code/issues/14803): "No LSP server available" | Critical | `/plugin enable` + restart. Check binary in PATH |
| [#15235](https://github.com/anthropics/claude-code/issues/15235): Missing plugin.json in marketplace | High | Reinstall from marketplace, or manual `.lsp.json` |
| [#20050](https://github.com/anthropics/claude-code/issues/20050): Standalone binary incompatible | Medium | Use npm-installed CC instead of standalone binary |
| [#15785](https://github.com/anthropics/claude-code/issues/15785): Compound extensions (.tfcomponent.hcl) | Low | Use single extension mapping |

**Alternative**: If CC LSP plugins are unreliable, use MCP-LSP bridge (`Tritlo/lsp-mcp`) as workaround.

---

## SOTA Landscape (April 2026)

| Tool | LSP | MCP | ACP | Notes |
|------|-----|-----|-----|-------|
| **Claude Code** | Native (Dec 2025) | Native | No | Plugin marketplace, 24 langs |
| **Cursor** | Via VS Code | Yes | No | Internal LSP, no custom exposure |
| **Windsurf** | Auto-download | Yes | No | Auto-installed on login |
| **GitHub Copilot** | npm package | Yes | No | `copilot-language-server` |
| **Zed** | Native | Yes | **Yes** | First IDE with ACP |
| **JetBrains AI** | Public API | Yes | **Yes** | LSP4IJ open-source |

**Emerging**: Agent Client Protocol (ACP, Jan 2026) is the next frontier — doing for AI agents
what LSP did for language intelligence. Currently JetBrains + Zed only.

### Custom LSP frameworks (for domain-specific languages)

| Framework | Language | Best for |
|-----------|----------|----------|
| **Langium** | TypeScript | Custom DSLs, config schemas (recommended) |
| **Eclipse Xtext** | Java | Enterprise DSLs |
| **vscode-languageserver** | TypeScript | VS Code extensions |

---

## References

- Schema: `mcp-lsp-spec.md` (same directory)
- Marketplace: [Piebald-AI/claude-code-lsps](https://github.com/Piebald-AI/claude-code-lsps)
- CC docs: [Claude Code LSP Setup](https://www.aifreeapi.com/en/posts/claude-code-lsp)
- Bridge: [lsp-mcp](https://github.com/Tritlo/lsp-mcp) (MCP-LSP bridge)
- Langium: [langium.org](https://langium.org/) (custom LSP framework)
- ACP: [agentclientprotocol.com](https://agentclientprotocol.com/get-started/introduction)
