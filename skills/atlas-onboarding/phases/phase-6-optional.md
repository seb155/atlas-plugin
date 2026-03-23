# Phase 6: ⚙️ Optional Integrations

AskUserQuestion with multi-select:

```
header: "Optional"
multiSelect: true
options:
  - "Forgejo SSH — Git SSH access verification"
  - "Headscale/Tailscale — mesh networking"
  - "Coder workspace — remote dev environment"
  - "Ollama local models — offline AI (qwen2.5, deepseek-r1)"
```

For each selected:
- Forgejo SSH → verify `~/.ssh/config` has Forgejo host entry
- Headscale → run `tailscale status` and report
- Coder → check `coder agents` status
- Ollama → check local Ollama API: `curl http://localhost:11434/api/tags` and show available models
