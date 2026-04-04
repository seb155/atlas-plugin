#!/usr/bin/env zsh
# ATLAS CLI Module: Topic Registry (create, list, resume, complete)
# Sourced by atlas-cli.sh — do not execute directly

# ─── Topic Registry ──────────────────────────────────────────
ATLAS_TOPICS_FILE="${HOME}/.atlas/topics.json"

_atlas_topics_init() {
  [ -f "$ATLAS_TOPICS_FILE" ] || echo '{}' > "$ATLAS_TOPICS_FILE"
}

_atlas_topic_get() {
  local topic="$1"
  _atlas_topics_init
  python3 -c "
import json, sys
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
t = topics.get('$topic')
if t:
    print(json.dumps(t))
else:
    sys.exit(1)
" 2>/dev/null
}

_atlas_topic_create() {
  local topic="$1" project="$2" branch="$3"
  _atlas_topics_init
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
topics['$topic'] = {
    'project': '$project',
    'branches': ['$branch'] if '$branch' else [],
    'sessions': [],
    'handoffs': [],
    'plans': [],
    'created': datetime.now().isoformat(),
    'lastActive': datetime.now().isoformat(),
    'status': 'active'
}
with open('$ATLAS_TOPICS_FILE', 'w') as f:
    json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_update_active() {
  local topic="$1"
  _atlas_topics_init
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    topics['$topic']['lastActive'] = datetime.now().isoformat()
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_add_session() {
  local topic="$1" session_name="$2"
  python3 -c "
import json
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    sessions = topics['$topic'].get('sessions', [])
    if '$session_name' not in sessions:
        sessions.append('$session_name')
        topics['$topic']['sessions'] = sessions
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_add_handoff() {
  local topic="$1" handoff_path="$2"
  python3 -c "
import json
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    handoffs = topics['$topic'].get('handoffs', [])
    if '$handoff_path' not in handoffs:
        handoffs.append('$handoff_path')
        topics['$topic']['handoffs'] = handoffs
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topic_complete() {
  local topic="$1"
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if '$topic' in topics:
    topics['$topic']['status'] = 'completed'
    topics['$topic']['completedAt'] = datetime.now().isoformat()
    with open('$ATLAS_TOPICS_FILE', 'w') as f:
        json.dump(topics, f, indent=2)
" 2>/dev/null
}

_atlas_topics_list() {
  _atlas_topics_init
  python3 -c "
import json
from datetime import datetime
with open('$ATLAS_TOPICS_FILE') as f:
    topics = json.load(f)
if not topics:
    print('No topics registered.')
else:
    active = {k:v for k,v in topics.items() if v.get('status') == 'active'}
    completed = {k:v for k,v in topics.items() if v.get('status') == 'completed'}
    if active:
        print(f'Active topics ({len(active)}):')
        for name, t in sorted(active.items(), key=lambda x: x[1].get('lastActive',''), reverse=True):
            proj = t.get('project', '?')
            last = t.get('lastActive', '')[:16].replace('T', ' ')
            handoff_count = len(t.get('handoffs', []))
            print(f'  {name:20s}  {proj:12s}  last: {last}  handoffs: {handoff_count}')
    if completed:
        print(f'Completed topics ({len(completed)}):')
        for name, t in sorted(completed.items(), key=lambda x: x[1].get('completedAt',''), reverse=True)[:5]:
            proj = t.get('project', '?')
            print(f'  {name:20s}  {proj:12s}  (completed)')
" 2>/dev/null
}

# Archive completed topics older than 90 days
_atlas_cleanup_topics() {
  local topics_file="$HOME/.atlas/topics.json"
  [ -f "$topics_file" ] || return 0

  local ninety_days=$((90 * 86400))

  python3 -c "
import json, time
with open('$topics_file') as f:
    topics = json.load(f)
now = time.time()
archived = 0
for name, info in list(topics.items()):
    if info.get('status') == 'completed':
        completed = info.get('completedAt', '')
        if completed:
            try:
                from datetime import datetime
                ct = datetime.fromisoformat(completed).timestamp()
                if now - ct > ${ninety_days}:
                    info['status'] = 'archived'
                    archived += 1
            except: pass
if archived > 0:
    with open('$topics_file', 'w') as f:
        json.dump(topics, f, indent=2)
    print(f'Archived {archived} stale topics')
" 2>/dev/null
}

# Run cleanup once per day (marker file guard)
_atlas_maybe_cleanup_topics() {
  local marker="$HOME/.atlas/.topics-cleaned-$(date +%Y-%m-%d)"
  [ -f "$marker" ] && return 0
  _atlas_cleanup_topics
  touch "$marker" 2>/dev/null
  # Remove markers older than 7 days
  find "$HOME/.atlas" -maxdepth 1 -name '.topics-cleaned-*' -mtime +7 -delete 2>/dev/null
}

