---
name: zoom-out
description: "Meta-cognitive anti-tunnel-vision broadening. Use when the user says 'zoom out', 'step back', 'bigger picture', 'what is the architecture', or when stack depth >5 levels deep into details."
effort: low
version: 1.0.0
tier: [core]
attribution: "Cherry-picked from mattpocock/skills (MIT licensed, see CREDITS.md)"
see_also: [scope-check, context-discovery, code-analysis]
thinking_mode: adaptive
---

# Zoom Out

> Meta-cognitive skill : **proactive** broadening pour casser le tunnel-vision avant de plonger plus creux. Complement reactif de `scope-check` (drift detection).

## When to Invoke

### Manual triggers (user-initiated)
- "zoom out" / "step back" / "give me the big picture"
- "what is the architecture here?"
- "explain how this fits in the system"
- "I'm lost — donne-moi un map"

### Automatic triggers (agent self-detection)
Invoke proactively quand TOUS ces signaux sont presents :
- Stack depth > 5 niveaux dans des details (file -> function -> branch -> sub-call -> implementation)
- Plus de 10 minutes sans surfacer le contexte global
- L'utilisateur exprime confusion ("je comprends pas", "ca s'imbrique comment ?")
- Refactor multi-fichier sans architecture explicite reference

## Behavior

Au lieu de continuer en profondeur, **stop et produire un map**. Demande explicitement la perspective superieure :

> "Avant de continuer, je vais zoom out pour confirmer le bigger picture. Voici l'architecture relevante :"

Puis genere un overview **borne en taille** (max 200 mots + diagramme optionnel).

## Output Template

```markdown
## Zoom Out : <feature/module name>

**Domaine** : <1-line domain context, ex: "Engineering chain - material classification">

**Tech stack relevant** :
- <language/framework> : <role>
- <library/service> : <role>
- <storage/queue> : <role>

**Composants cles** (max 5, par responsabilite) :
1. `<path/to/module>` - <one-line responsibility>
2. `<path/to/module>` - <one-line responsibility>
...

**Integration points** :
- Upstream : <who calls this>
- Downstream : <what this calls>
- Side effects : <DB, queue, cache, external API>

**Domain glossary** (si applicable) :
- <term> = <project-specific definition>

**Mermaid map** (si > 3 composants) :
\`\`\`mermaid
graph LR
  A[Caller] --> B[This module]
  B --> C[Dependency 1]
  B --> D[Dependency 2]
\`\`\`
```

## Constraints

- Max 200 mots dans le narratif (hors diagramme et code blocks)
- Pas de code source detaille - c'est un map, pas une implementation
- Cite **vocabulaire du projet** (CLAUDE.md, glossary, .blueprint/) quand disponible
- Si glossary inconnu, demande via `AskUserQuestion` avant de proceder

## Synergy avec autres skills

| Skill | Relation |
|-------|----------|
| `scope-check` | **Reactif** (drift detection apres action). Zoom-out est **proactif** (avant action). |
| `context-discovery` | Zoom-out = light-weight subset. Si codebase inconnu en entier -> escalate vers context-discovery. |
| `code-analysis` | Zoom-out = vue narrative. code-analysis = vue mecanique (deps graph, dead code). |
| `brainstorming` | Zoom-out clarify le terrain AVANT de brainstormer des options. |

## Anti-Patterns

- DO NOT zoom-out apres chaque action - ca devient bruit. Reserve aux signaux ci-haut.
- DO NOT generer 1000+ mots d'overview - c'est un map, pas une these.
- DO NOT inferer l'architecture - cite des fichiers/modules reels. Si flou, ASK.
- DO NOT zoom-out si l'utilisateur a deja un plan SSoT en main - reference le plan.

## Example invocation

**User context** : agent has been navigating 6 levels deep into `backend/app/services/chat/intent_router/classifiers/heuristic.py` debugging a regex.

**Auto-trigger** : zoom-out fires.

**Agent output** :
> Avant de continuer le debug, je zoom out pour confirmer le bigger picture.
>
> ## Zoom Out : Chat Intent Routing
>
> **Domaine** : Synapse chat orchestration (UnifiedChatService)
>
> **Tech stack** : FastAPI + structlog + PG/ParadeDB BM25 + Ollama LLM
>
> **Composants cles** :
> 1. `UnifiedChatService` - orchestrator (5 DI deps, T4 smoke required)
> 2. `IntentRouter` - dispatch user query to {knowledge|action|chat} bucket
> 3. `HeuristicClassifier` (ce qu'on debug) - regex-based first-pass before LLM fallback
> 4. `LLMClassifier` - fallback when heuristic confidence < threshold
>
> **Integration** :
> - Upstream : `/api/v1/chat/stream` endpoint
> - Downstream : `KnowledgeRagService` | `ActionExecutor` | passthrough LLM
>
> Le bug regex est dans la couche heuristique - faible blast radius. OK de continuer en profondeur.

## Origin

Pattern adopte de [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). Adapte au format ATLAS :
- Ajoute auto-triggers (Pocock = manual only)
- Ajoute output template borne (Pocock = free-form)
- Ajoute synergie matrix avec skills existants ATLAS
- Ton francais/quebecois friendly per Seb preferences

Voir `CREDITS.md` pour attribution complete.
