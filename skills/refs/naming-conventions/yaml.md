# YAML Naming Conventions

Based on YAML 1.2 spec + ecosystem norms (Kubernetes, CI, Docker Compose).

## Core rules

| Context | Case | Example | Counter-example |
|---------|------|---------|-----------------|
| Keys (general) | `snake_case` or `camelCase` (pick one per file) | `max_retries`, `maxRetries` | `MaxRetries`, `max-retries` (in most ecosystems) |
| Keys (Kubernetes) | `camelCase` | `apiVersion`, `containerPort` | `api_version` |
| Keys (Docker Compose) | `snake_case` | `build_args`, `restart_policy` | `buildArgs` |
| Keys (Woodpecker) | `snake_case` | `when`, `branch`, `event` | `When`, `Branch` |
| Keys (ATLAS profiles) | `snake_case` | `tier`, `description`, `skills`, `hooks` | `Tier`, `skill_list` |
| Anchors | `snake_case` with `&` prefix | `&default_resources` | `&DefaultResources` |
| Aliases | Match anchor | `*default_resources` | `*Default_Resources` |
| Values (enum-like) | `snake_case` or `kebab-case` (pick per enum) | `status: active`, `tier: dev-addon` | mixing |

## Rule: consistency within a file

**Never mix case styles within a single YAML file.** Pick one and stick with it:
- All keys `camelCase` (Kubernetes style)
- OR all keys `snake_case` (Docker Compose, most CI)

## ATLAS-specific (from `profiles/*.yaml`)

```yaml
# All keys snake_case
tier: core
description: Shared base
skills:
- session-pickup       # values can be kebab-case (matches file names)
- memory-dream
refs:
- external-tools
hooks:
- session-start
- prompt-intelligence
agents:
- context-scanner
persona: helpful assistant
pipeline: DISCOVER → ASSIST
banner_label: Core
```

**Notes**:
- Keys are `snake_case` (`banner_label`, not `bannerLabel`)
- List values are `kebab-case` strings matching file paths

## Anchors & aliases (YAML reuse)

```yaml
# Good — descriptive anchor names
defaults: &project_defaults
  image: python:3.13-slim
  resources:
    memory: 512Mi

job_a:
  <<: *project_defaults
  script: python a.py

job_b:
  <<: *project_defaults
  script: python b.py

# Bad — cryptic
x: &a
  image: python:3.13-slim
y:
  <<: *a
```

## Woodpecker CI convention

```yaml
# Good
when:
  branch: [main, "feat/*", "feature/*"]
  event: [push, pull_request]

steps:
  l1-structural:          # step names: kebab-case
    image: python:3.13-slim
    commands:
      - pytest tests/ -x -q
    depends_on: [clone]
    failure: ignore       # bool or string value, snake_case

# Bad
When:                     # capital letter
steps:
  L1Structural:           # PascalCase
    Image: python:3.13-slim
    DependsOn: [clone]
```

## Kubernetes convention (camelCase)

```yaml
apiVersion: v1             # camelCase keys
kind: Pod                  # PascalCase values for enums
metadata:
  name: my-pod
  labels:
    app.kubernetes.io/name: my-app   # DNS-style for labels
spec:
  containers:
  - name: app              # list item values
    image: alpine:latest
    ports:
    - containerPort: 8080  # camelCase
      protocol: TCP
```

## Docker Compose convention (snake_case)

```yaml
version: '3.8'
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped     # kebab-case enum value
    environment:
      - DATABASE_URL=${DATABASE_URL}
    depends_on:
      - db
```

## AVOID

- Keys with spaces (requires quoting, error-prone)
- Tabs as indentation — use 2 spaces (YAML spec requires spaces)
- `!!int`, `!!str` tags unless needed (verbose)
- Single-letter anchor names (`&a`, `&b`)
- Mixing case styles within a single file (`snake_case` + `camelCase`)

## Validation

```bash
# Syntax check
yq -e '.' profile.yaml   # exit 0 = valid
python3 -c "import yaml; yaml.safe_load(open('profile.yaml'))"

# Schema validation (with yaml-language-server + schema)
# See yaml-lsp.md for schema association setup.
```

## References

- [YAML 1.2 spec](https://yaml.org/spec/1.2.2/)
- [Kubernetes API conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
- ATLAS `profiles/*.yaml` — snake_case keys + kebab-case values pattern
