# Phase 1: 👤 Profile

Gather user identity via AskUserQuestion:

**Question 1** — Role:
```
header: "Role"
options: ["I&C Engineer", "Electrical Engineer", "Project Manager", "Software Developer", "Admin/DevOps"]
```

**Question 2** — Expertise (multi-select):
```
header: "Expertise"
multiSelect: true
options: ["I&C", "Electrical", "Mechanical", "Process", "Software", "DevOps", "Mining/Resources"]
```

**Question 3** — Language:
```
header: "Language"
options: ["Français (Recommended)", "English"]
```

**Question 4** — Default model:
```
header: "Model"
options: [
  "Opus 4.7 (Recommended) — deep reasoning, architecture, plans",
  "Sonnet 4.6 — fast, 98% coding quality, lower cost"
]
```

After collecting answers, ask for name and team via free-form AskUserQuestion.

Write `~/.atlas/profile.json`:
```bash
cat > ~/.atlas/profile.json <<EOF
{
  "version": 1,
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": {
    "name": "{name}",
    "role": "{role}",
    "team": "{team}",
    "expertise": [{expertise}],
    "preferences": { "language": "{lang}", "model": "{model}" }
  },
  "onboarding": {
    "phases_completed": ["profile"]
  }
}
EOF
```
