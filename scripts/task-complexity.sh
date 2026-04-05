#!/usr/bin/env bash
# task-complexity.sh — Classify task complexity for model selection
# Usage: echo "task description" | task-complexity.sh
#    or: task-complexity.sh "task description"
#
# Output: JSON with level, model, reasoning
# Levels: trivial (Haiku) | moderate (Sonnet) | complex (Opus) | architectural (Opus max)
#
# SP-EVOLUTION P7.1 — Foundation for auto model allocation
set -euo pipefail

DESC="${1:-$(cat 2>/dev/null || echo '')}"
[ -z "$DESC" ] && { echo '{"level":"moderate","model":"sonnet","reason":"no description"}'; exit 0; }

python3 -c "
import json, re, sys

desc = '''$DESC'''.lower().strip()
words = desc.split()
word_count = len(words)

# ── Signal scoring ──────────────────────────────────────────

score = 0  # Higher = more complex. 0-3=trivial, 4-7=moderate, 8-12=complex, 13+=architectural

# Word count signal
if word_count <= 10: score += 0
elif word_count <= 30: score += 2
elif word_count <= 80: score += 4
else: score += 6

# Architectural keywords (high complexity)
arch_words = ['architect', 'design', 'migration', 'refactor', 'rewrite', 'mega plan',
              'cross-plan', 'multi-repo', 'breaking change', 'schema change', 'api design',
              'security audit', 'performance', 'scalability', 'distributed', 'consensus']
arch_hits = sum(1 for w in arch_words if w in desc)
score += arch_hits * 3

# Complex keywords
complex_words = ['debug', 'investigate', 'optimize', 'race condition', 'deadlock',
                 'memory leak', 'integration', 'multi-file', 'cross-service',
                 'dependency', 'upgrade', 'rollback', 'deployment']
complex_hits = sum(1 for w in complex_words if w in desc)
score += complex_hits * 2

# Moderate keywords
moderate_words = ['implement', 'feature', 'endpoint', 'component', 'hook',
                  'test', 'fix bug', 'add', 'create', 'update', 'modify']
moderate_hits = sum(1 for w in moderate_words if w in desc)
score += moderate_hits * 1

# Trivial indicators (reduce score)
trivial_words = ['rename', 'typo', 'comment', 'format', 'lint', 'simple',
                 'quick', 'minor', 'small', 'one-liner', 'straightforward',
                 'delete', 'remove unused', 'cleanup', 'docs only']
trivial_hits = sum(1 for w in trivial_words if w in desc)
score -= trivial_hits * 2

# File count mentions
file_count = 0
file_match = re.search(r'(\d+)\s*files?', desc)
if file_match:
    file_count = int(file_match.group(1))
    if file_count > 10: score += 4
    elif file_count > 5: score += 2
    elif file_count > 2: score += 1

# ── Classify ────────────────────────────────────────────────

score = max(0, score)

if score <= 2:
    level, model, effort = 'trivial', 'haiku', 'low'
elif score <= 7:
    level, model, effort = 'moderate', 'sonnet', 'medium'
elif score <= 12:
    level, model, effort = 'complex', 'opus', 'high'
else:
    level, model, effort = 'architectural', 'opus', 'max'

result = {
    'level': level,
    'model': model,
    'effort': effort,
    'score': score,
    'signals': {
        'words': word_count,
        'arch_hits': arch_hits,
        'complex_hits': complex_hits,
        'moderate_hits': moderate_hits,
        'trivial_hits': trivial_hits,
        'files_mentioned': file_count
    }
}

print(json.dumps(result))
" 2>/dev/null || echo '{"level":"moderate","model":"sonnet","reason":"parse error"}'
