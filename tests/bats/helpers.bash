# helpers.bash — shared utilities for atlas-dev-plugin bats tests
# Source from each .bats file:   load helpers
#
# Assumes $BATS_TEST_DIRNAME resolves to tests/bats/. Computes $PLUGIN_ROOT
# (worktree root) and exports scan directories.

# --- Path resolution ---
_resolve_plugin_root() {
  # tests/bats → tests → plugin root
  local here
  here="$(cd "$BATS_TEST_DIRNAME" && pwd)"
  # shellcheck disable=SC2164
  cd "$here/../.." && pwd
}

PLUGIN_ROOT="$(_resolve_plugin_root)"
export PLUGIN_ROOT

# Scan targets for remnant probes (exclude tests/audit — that dir documents
# the patterns and is expected to contain them).
SCAN_DIRS=(
  "$PLUGIN_ROOT/hooks"
  "$PLUGIN_ROOT/skills"
  "$PLUGIN_ROOT/agents"
  "$PLUGIN_ROOT/scripts"
)
export SCAN_DIRS

# --- Frontmatter helpers ---

# parse_frontmatter <file>
# Prints only the lines BETWEEN the first two `---` fences.
# Exit 0 if a well-formed fence pair was found, 1 otherwise.
parse_frontmatter() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  awk '
    BEGIN { in_fm = 0; seen = 0 }
    /^---[[:space:]]*$/ {
      if (!seen) { seen = 1; in_fm = 1; next }
      else if (in_fm) { in_fm = 0; exit }
    }
    { if (in_fm) print }
  ' "$file"
}

# extract_yaml_value <file> <key>
# Prints the (trimmed) value of a top-level scalar key from frontmatter.
# Empty output if key absent. Handles `key: value` and `key:"value"`.
extract_yaml_value() {
  local file="$1" key="$2"
  parse_frontmatter "$file" | awk -v k="$key" '
    $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*", "")
      gsub(/^["'\''[:space:]]+|["'\''[:space:]]+$/, "")
      print
      exit
    }
  '
}

# has_yaml_key <file> <key>   returns 0 if key present at column 0
has_yaml_key() {
  parse_frontmatter "$1" | grep -qE "^$2:"
}

# grep_count_matches <pattern>
# Recursively greps $SCAN_DIRS for pattern across .md/.yaml/.json/.ts/.sh.
# Prints the number of matching lines (0 if none).
grep_count_matches() {
  local pattern="$1"
  local count=0
  for d in "${SCAN_DIRS[@]}"; do
    [[ -d "$d" ]] || continue
    local n
    n=$(grep -rE "$pattern" "$d" \
          --include="*.md" --include="*.yaml" --include="*.yml" \
          --include="*.json" --include="*.ts" --include="*.sh" \
          2>/dev/null | wc -l)
    count=$((count + n))
  done
  echo "$count"
}

# list_skill_files
# Echoes absolute paths to every skills/*/SKILL.md in the plugin.
list_skill_files() {
  find "$PLUGIN_ROOT/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" 2>/dev/null
}

# list_agent_files
list_agent_files() {
  find "$PLUGIN_ROOT/agents" -mindepth 2 -maxdepth 2 -name "AGENT.md" 2>/dev/null
}

# Effort enum — v6.0 canonical
readonly EFFORT_ENUM="low|medium|high|xhigh|max|auto"

# Superpowers pattern enum
readonly SP_PATTERN_ENUM="iron_law|red_flags|hard_gate|none"
