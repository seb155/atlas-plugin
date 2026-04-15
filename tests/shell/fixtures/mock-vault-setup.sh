#!/usr/bin/env bash
# Mock vault fixture for SP-DAIMON hooks tests
# Usage: source this and call setup_mock_vault "$vault_dir" [opt_in]

setup_mock_vault() {
  local vault_dir="$1"
  local opt_in="${2:-true}"  # default: enabled

  mkdir -p "$vault_dir/daimon" "$vault_dir/profile" "$vault_dir/kernel"

  # kernel/config.json
  cat > "$vault_dir/kernel/config.json" <<EOF
{
  "schema_version": "1.0",
  "daimon_auto_load": ${opt_in}
}
EOF

  # sharing.json
  cat > "$vault_dir/sharing.json" <<'EOF'
{
  "daimon/test.daimon.md": {
    "auto_load": true,
    "trust_levels": ["high"],
    "fields": ["big_five", "enneagram", "core_values"]
  },
  "daimon/test.telos-profond.md": {
    "auto_load": true,
    "trust_levels": ["high"],
    "fields": ["cognitive_pattern", "deep_telos"]
  },
  "profile/user-profile.json": {
    "auto_load": true,
    "trust_levels": ["high", "standard"],
    "fields": ["userId"]
  }
}
EOF

  # daimon/test.daimon.md (matches SP-DAIMON parser expectations)
  cat > "$vault_dir/daimon/test.daimon.md" <<'EOF'
# Test DAIMON

### Big Five (OCEAN)

| Trait | Score | Percentile |
|-------|-------|------------|
| **O** (Openness) | 3.50 | 55% |
| **C** (Conscientiousness) | 4.00 | 80% |
| **E** (Extraversion) | 2.50 | 25% |
| **A** (Agreeableness) | 3.00 | 35% |
| **N** (Neuroticism) | 2.80 | 45% |

#### Facets

| Facette | Score | Observation |
|---------|-------|-------------|
| **Intellect** | **4.5** | Elevated |
| **Recherche de réussite** | **4.0** | High drive |
| **Self-Consciousness** | **3.5** | Moderate |
| **Vulnérabilité** | **2.0** | Low |

### Enneagram

| Aspect | Résultat |
|--------|----------|
| **Type principal** | **5 - The Observer** (72%) |
| **Aile** | **5w4** |

**Essence:** "Test Architect"

### Core Values (ACT)

| Rang | Valeur | Signification |
|------|--------|---------------|
| 1 | **Curiosity** | Love of learning |
| 2 | **Autonomy** | Self-direction |
| 3 | **Rigor** | Precise thinking |
EOF

  # daimon/test.telos-profond.md
  cat > "$vault_dir/daimon/test.telos-profond.md" <<'EOF'
# Test Telos Profond

## LE PATTERN (7 couches du vidéo)

Various patterns.

## TELOS PROFOND

> **Bâtir les frameworks de test qui simulent la réalité — pour la science.**

Other content.
EOF

  # profile/user-profile.json
  cat > "$vault_dir/profile/user-profile.json" <<'EOF'
{
  "userId": "testuser",
  "temporal": {"timeOfDay": {}}
}
EOF
}

# Setup ~/.atlas/profile.json to point to mock vault
setup_atlas_profile_for_vault() {
  local vault_path="$1"
  mkdir -p "$HOME/.atlas"
  cat > "$HOME/.atlas/profile.json" <<EOF
{
  "version": 1,
  "vault_path": "$vault_path"
}
EOF
}
