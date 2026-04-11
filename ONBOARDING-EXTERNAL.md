# ATLAS Plugin — Onboarding Collaborateur Externe

> Guide complet pour installer et utiliser ATLAS sur un homelab personnel.
>
> Updated: 2026-04-11

---

## Prérequis

| Outil | Requis | Installation (Linux) | Installation (macOS) |
|-------|--------|---------------------|---------------------|
| git | Oui | `sudo apt install git` | `brew install git` |
| python3 | Oui | `sudo apt install python3` | `brew install python3` |
| curl | Oui | `sudo apt install curl` | Préinstallé |
| jq | Recommandé | `sudo apt install jq` | `brew install jq` |
| bash 4+ | Oui | Préinstallé | `brew install bash` |
| make | Oui | `sudo apt install build-essential` | Xcode CLI tools |
| zsh | Recommandé | `sudo apt install zsh` | Préinstallé |

**Compte GitHub**: Tu as besoin d'un compte GitHub pour créer un token d'accès.
Le plugin s'installe via un mirror public — pas besoin d'être collaborateur sur le repo.

---

## Étape 1 — Installer Claude Code

```bash
# Linux / macOS
curl -fsSL https://claude.ai/install.sh | sh

# Vérifier
claude --version
```

Si tu es sur Windows (WSL2):
```powershell
# PowerShell (admin)
irm https://claude.ai/install.ps1 | iex
```

---

## Étape 2 — Configurer le token GitHub

Le plugin ATLAS est distribué via un mirror GitHub public. Claude Code a besoin d'un
token pour cloner le repo pendant l'installation.

1. Va sur [github.com/settings/tokens](https://github.com/settings/tokens)
2. Clique **Generate new token** → **Fine-grained token**
3. Configure:
   - Token name: `atlas-plugin-read`
   - Expiration: 90 jours (ou plus)
   - Repository access: **Public Repositories (read-only)**
   - Permissions: `Contents: Read-only`
4. Copie le token

```bash
# Linux / macOS
echo 'export GITHUB_TOKEN="ghp_xxx"' >> ~/.zshrc
source ~/.zshrc

# Vérifier
echo $GITHUB_TOKEN  # Devrait afficher ton token
```

---

## Étape 3 — Installer le plugin ATLAS (admin)

```bash
# Lancer Claude Code
claude

# Dans Claude Code:
/plugin marketplace add seb155/atlas-plugin
/plugin install atlas-admin@atlas-admin-marketplace

# Quitter et relancer
exit
claude
```

**Résultat attendu** — Tu devrais voir le banner ATLAS:

```
🏛️ ATLAS v4.37.0 online | <ton-hostname>
72 skills | 15 agents | Quality gate 16/20
Auto-routing active — just tell me what you need.
```

**Dépannage**:
- Pas de banner? → `/plugin list` pour vérifier que `atlas-admin` est installé
- Erreur d'installation? → Vérifier que `GITHUB_TOKEN` est bien set
- "Repository not found"? → Le token doit avoir accès aux repos publics

---

## Étape 4 — Vérifier avec Atlas Doctor

Dans Claude Code, tape:

```
/atlas doctor
```

**Résultat attendu** (homelab personnel):

| Catégorie | Attendu | Notes |
|-----------|---------|-------|
| OS & Shell | PASS | Linux/macOS |
| Permissions | PASS | Home directory writable |
| Tools | PASS ou PARTIAL | jq, yq optionnels |
| Tokens | PARTIAL | GITHUB_TOKEN ✅, FORGEJO_TOKEN optionnel |
| Services | PARTIAL | Pas de Synapse local = normal |
| Claude Code | PASS | Version récente |
| ATLAS Plugin | PASS | Admin tier installé |

---

## Étape 5 — Installer le CLI ATLAS (optionnel)

Le CLI ATLAS ajoute des commandes shell (`atlas version`, `atlas list`, etc.).

```bash
# Cloner le repo plugin
mkdir -p ~/atlas-dev && cd ~/atlas-dev
git clone https://github.com/seb155/atlas-plugin.git
cd atlas-plugin

# Build et installer localement
make dev

# Ajouter au shell
echo '[ -f "$HOME/.atlas/shell/atlas.sh" ] && source "$HOME/.atlas/shell/atlas.sh"' >> ~/.zshrc
source ~/.zshrc

# Vérifier
atlas version    # Devrait afficher la version
atlas help       # Liste des commandes
```

---

## Étape 6 — Configurer le fork pour contribuer

Tu as un fork sur Forgejo (`charles/atlas-plugin`) pour proposer des améliorations.

### Option A: Cloner depuis le fork (recommandé)

```bash
cd ~/atlas-dev

# Cloner ton fork
git clone https://forgejo.axoiq.com/charles/atlas-plugin.git atlas-plugin-fork
cd atlas-plugin-fork

# Ajouter le repo upstream (principal)
git remote add upstream https://forgejo.axoiq.com/axoiq/atlas-plugin.git
git fetch --all
```

### Option B: Ajouter les remotes au clone GitHub existant

```bash
cd ~/atlas-dev/atlas-plugin

# Renommer le remote GitHub
git remote rename origin github

# Ajouter ton fork et upstream
git remote add origin https://forgejo.axoiq.com/charles/atlas-plugin.git
git remote add upstream https://forgejo.axoiq.com/axoiq/atlas-plugin.git
git fetch --all
```

### Configurer l'authentification Forgejo

Pour push vers ton fork, configure git avec tes credentials Forgejo:

```bash
# Option 1: Token Forgejo dans l'URL (simple)
git remote set-url origin https://charles:TON_TOKEN_FORGEJO@forgejo.axoiq.com/charles/atlas-plugin.git

# Option 2: Git credential helper (plus propre)
git config --global credential.https://forgejo.axoiq.com.helper store
# Puis la première fois que tu push, entre tes credentials
```

---

## Étape 7 — Workflow de contribution

### Proposer une amélioration

```bash
cd ~/atlas-dev/atlas-plugin-fork

# 1. Synchroniser avec upstream
git fetch upstream
git checkout main
git rebase upstream/main

# 2. Créer une branche feature
git checkout -b feature/mon-amelioration

# 3. Développer...
# (éditer les fichiers dans skills/, hooks/, scripts/, etc.)

# 4. Tester localement
make test              # Tests automatisés
make dev               # Build + install local

# 5. Redémarrer Claude Code et tester
# exit + claude → vérifier que le changement fonctionne

# 6. Commit et push
git add -A
git commit -m "feat(skills): add my improvement"
git push origin feature/mon-amelioration

# 7. Créer une PR sur Forgejo
# Va sur: https://forgejo.axoiq.com/charles/atlas-plugin
# Clique "New Pull Request"
# Base: axoiq/atlas-plugin:main ← charles/atlas-plugin:feature/mon-amelioration
```

### Règles de contribution

- **Branches**: `feature/*` pour les nouvelles fonctionnalités, `fix/*` pour les corrections
- **Commits**: Format conventionnel: `type(scope): description`
  - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- **Review**: Seul Seb peut merger sur `main` (branch protection)
- **Tests**: `make test` doit passer avant de soumettre une PR

---

## Étape 8 — Créer une nouvelle skill

Pour ajouter une skill à l'écosystème ATLAS:

```bash
# 1. Créer le répertoire et fichier SKILL.md
mkdir -p skills/ma-nouvelle-skill
cat > skills/ma-nouvelle-skill/SKILL.md << 'EOF'
---
name: ma-nouvelle-skill
description: Description courte de ce que fait la skill
tier: admin
category: Meta
emoji: 🔧
triggers:
  - "ma skill"
  - "mon outil"
---

# Ma Nouvelle Skill

Instructions détaillées pour la skill...
EOF

# 2. Ajouter au profil admin
# Éditer profiles/admin.yaml → ajouter "ma-nouvelle-skill" dans la liste skills

# 3. Tester
make test       # Vérifie la structure
make dev        # Build + install

# 4. Restart CC et tester
# /atlas ma skill → devrait activer ta skill
```

---

## Étape 9 — Commandes essentielles

### Dans Claude Code (plugin)

| Commande | Description |
|----------|-------------|
| `/atlas assist "..."` | Routing intelligent vers la bonne skill |
| `/atlas doctor` | Diagnostic de santé ATLAS |
| `/atlas skills` | Liste des 72 skills disponibles |
| `/atlas plan "..."` | Créer un plan d'implémentation |
| `/atlas verify` | Exécuter les quality gates |
| `/atlas finish` | Commit + push + PR |
| `/atlas research "..."` | Recherche web approfondie |
| `/atlas note "..."` | Capture rapide de notes |

### CLI Shell (si installé)

| Commande | Description |
|----------|-------------|
| `atlas version` | Version installée |
| `atlas help` | Aide complète |
| `atlas list` | Lister les projets |
| `atlas <project>` | Lancer CC sur un projet |
| `atlas doctor` | Diagnostic rapide |

---

## Dépannage

| Problème | Solution |
|----------|----------|
| `claude` not found | Restart terminal, vérifier PATH |
| Plugin install échoue | Vérifier `GITHUB_TOKEN` est set et valide |
| Pas de banner ATLAS au démarrage | `/plugin list` → vérifier atlas-admin installé |
| `make dev` échoue | Vérifier python3, bash, make installés |
| `git push` vers fork échoue | Vérifier credentials Forgejo (token ou SSH) |
| PR refusée / merge bloqué | Branch protection: seul Seb peut merge sur main |
| Fork introuvable | Vérifier `https://forgejo.axoiq.com/charles/atlas-plugin` |
| Skill pas détectée | Vérifier SKILL.md frontmatter + ajouté au profil YAML |
| `atlas` command not found | Vérifier `source ~/.zshrc` et que atlas.sh existe |

---

## Support

- **Seb Gagnon**: seb@axoiq.com ou Teams
- **Documentation ATLAS**: Dans le repo, voir `ARCHITECTURE.md` et `DEPLOYMENT.md`
- **Issues**: Créer une issue sur `https://forgejo.axoiq.com/axoiq/atlas-plugin/issues`
