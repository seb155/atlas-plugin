/**
 * File-role classification for skill-lint.
 *
 * A "skill" repo has a SKILL.md at root. A "collection" repo (e.g. lich-skills)
 * has NO root SKILL.md but has one or more `skills/<name>/SKILL.md` files.
 * A non-skill repo has no SKILL.md anywhere — we still scan but report it.
 */

/**
 * @param {Array} files  walkFiles() output
 * @returns {{ mode: 'single'|'collection'|'non-skill', skillRoots: string[] }}
 */
export function detectMode(files) {
  const skillRoots = [];
  for (const f of files) {
    if (/(^|\/)SKILL\.md$/.test(f.relPath)) {
      const root = f.relPath.replace(/(^|\/)SKILL\.md$/, '');
      skillRoots.push(root); // '' for root-level SKILL.md
    }
  }
  if (skillRoots.includes('')) return { mode: 'single', skillRoots: [''] };
  if (skillRoots.length > 0) return { mode: 'collection', skillRoots };
  return { mode: 'non-skill', skillRoots: [] };
}

/**
 * Classify a file's role for severity weighting.
 *   skill       = the SKILL.md itself
 *   skill-script= any non-markdown file inside a skill dir (code that runs)
 *   skill-doc   = additional .md inside a skill dir (e.g. reference.md)
 *   readme      = README/CHANGELOG/LICENSE/CONTRIBUTING at any level
 *   doc         = docs/** or *.md outside any skill dir
 *   repo-infra  = root-level non-doc files in collection/non-skill repos
 *                 (package.json, index.js, scripts/, test/, etc.)
 *   other       = default
 */
export function classify(f, mode, skillRoots) {
  const rel = f.relPath;
  const base = rel.split('/').pop();

  // README / LICENSE / CHANGELOG / CONTRIBUTING — only if extension is a doc
  // format OR file is extensionless. README.py / README.sh / LICENSE.sh must
  // NOT be classified as readme (would bypass all script-aware rules).
  if (/^(README|CHANGELOG|CONTRIBUTING|LICENSE|NOTICE|SECURITY|CODE_OF_CONDUCT)(?:[-_][A-Za-z0-9]+)*(?:\.(?:md|markdown|txt|rst))?$/i.test(base)) {
    return 'readme';
  }

  // Which skillRoot does this file belong to?
  const inSkill = skillRoots.find((r) => {
    if (r === '') return true; // single-mode: root is the skill
    return rel === `${r}/SKILL.md` || rel.startsWith(`${r}/`);
  });

  if (inSkill !== undefined) {
    if (base === 'SKILL.md') return 'skill';
    if (/\.(md|markdown|rst|txt)$/i.test(base)) return 'skill-doc';
    return 'skill-script';
  }

  // Outside any skill dir
  if (/^docs?\//i.test(rel)) return 'doc';
  if (/\.(md|markdown|rst|txt)$/i.test(base)) return 'doc';

  return 'repo-infra';
}

/**
 * Severity downgrade map. Returns a new severity or null (skip).
 *
 * Rationale: prose inside docs/README is describing patterns, not executing
 * them. A "curl | sh" in a tutorial is different from a "curl | sh" inside
 * SKILL.md that the agent will actually run.
 */
export function downgradeForRole(severity, role, { allowInReadme = false } = {}) {
  // Only downgrade for documentation-class files.
  // ATLAS fork: SKILL.md and additional skill-doc .md files are documentation
  // for the reasoning agent, not executable code. Apply the same downgrade
  // as readme/doc so that code-fence examples (curl | bash etc.) do not push
  // a legitimate instructional skill past the TOXIC threshold.
  if (role !== 'readme' && role !== 'doc' && role !== 'skill' && role !== 'skill-doc') return severity;

  // ATLAS fork: for skill/skill-doc we ignore the rule's allowInReadme hint.
  // Rationale: upstream reasoning "agents follow prose too" applies to direct
  // executors; ATLAS's reasoning-first agent does not blindly execute prose.
  // R01 CLI placeholders (`<user>`, `<system>` in tree diagrams or `qm set
  // --ciuser <user>` CLI docs) would otherwise stay CRITICAL despite being
  // obvious false positives. Readme/doc still honor allowInReadme upstream.
  if (allowInReadme && role !== 'skill' && role !== 'skill-doc') return severity;

  switch (severity) {
    case 'CRITICAL': return 'MEDIUM';
    case 'HIGH':     return 'LOW';
    case 'MEDIUM':   return null; // skip
    case 'LOW':      return null;
    default:         return severity;
  }
}

/**
 * Whether a finding should be skipped entirely for a role.
 * Used by rules that have no meaning in prose (e.g. R06 suspicious-binaries).
 */
export function skipForRole(role, rule) {
  if (rule === 'R06' && (role === 'readme' || role === 'doc' || role === 'repo-infra')) return true;
  return false;
}

/**
 * Split markdown text into prose / code-fence segments.
 * Returns { prose, fences } where each is a string (segments joined by \n).
 */
export function splitMarkdown(text) {
  const lines = text.split(/\r?\n/);
  let inFence = false;
  const prose = [];
  const fences = [];
  for (const line of lines) {
    if (/^\s{0,3}(```|~~~)/.test(line)) {
      inFence = !inFence;
      continue;
    }
    (inFence ? fences : prose).push(line);
  }
  return { prose: prose.join('\n'), fences: fences.join('\n') };
}

/**
 * Text to scan, given a file's role.
 *
 * ATLAS fork note (atlas-skill-lint v0.2.0+):
 *   SKILL.md and skill-doc .md files are classified as DOCUMENTATION for
 *   pattern scanning. Rationale: in ATLAS, SKILL.md is a set of instructions
 *   to a reasoning AI agent, not an executable script the agent blindly
 *   follows. Prose patterns like "curl | bash" in a fenced code block are
 *   pedagogical examples the AI decides whether to execute, based on its
 *   task context. Treating SKILL.md prose as agent-executable (upstream
 *   behavior) produces ~85% false-positive rate on ATLAS skills that
 *   document shell operations (see atlas-plugin benchmark 2026-04-19).
 *
 *   Skill scripts (non-markdown code inside a skill dir) still get full
 *   text scan — those ARE executed verbatim by `Bash` tool calls.
 *
 *   skill / skill-doc (.md)        : code-fence only (docs/prose scoped)
 *   skill-script (non-.md)         : full text (real executable code)
 *   readme / doc                   : code-fence only (upstream behavior)
 *   repo-infra                     : full text (install scripts, etc.)
 */
export function scanTextFor(f, text, role) {
  let out = text;
  // ATLAS fork: treat SKILL.md and skill-doc .md as documentation.
  if (role === 'readme' || role === 'doc' || role === 'skill' || role === 'skill-doc') {
    if (/\.(md|markdown|rst)$/i.test(f.relPath)) {
      out = splitMarkdown(text).fences;
    }
  }
  // Normalize shell line-continuations so pattern matches survive `\<LF>`.
  return collapseLineContinuations(out);
}

/**
 * Known installer hosts. Fetching from these via curl|sh is suspicious when
 * done by a skill, but in README install-docs it's the canonical pattern.
 */
/**
 * Shell interpreter token, tolerating:
 *   - absolute paths: /bin/bash, /usr/local/bin/python3
 *   - wrapper chains: `env bash`, `sudo sh`, `nohup python3`, `exec node`
 *   - the `/usr/bin/env` convention
 * The resulting fragment is meant to slot in after a pipe: `|\s*${INTERPRETER_RE}\b`.
 */
export const INTERPRETER_RE = String.raw`(?:(?:/[\w./-]+/)?(?:env|sudo|nohup|exec|nice|ionice)\s+)*(?:/[\w./-]+/)?(?:bash|sh|zsh|ksh|dash|ash|python3?|node|nodejs|perl|ruby|php|lua)`;

/**
 * Home-directory expansion forms in shell: ~, $HOME, ${HOME}, ${HOME:-...},
 * ${HOME:=...}, ${HOME:+...}, ${HOME-...}. Used by rules that target attacks
 * rooted at the user home but want to survive minor obfuscation.
 */
export const HOME_PREFIX_RE = String.raw`(?:~|\$HOME|\$\{HOME(?:[:\-=+?!#%*][^}]*)?\})`;

/**
 * Collapse shell line-continuations so regex matching isn't defeated by
 *   curl -sSL \
 *     URL \
 *     | bash
 * which is a single logical command in bash. Returns a string where every
 * `\<LF>` (optionally followed by indent) becomes a single space.
 */
export function collapseLineContinuations(text) {
  return text.replace(/\\\r?\n[ \t]*/g, ' ');
}

// Curated installers only. NEVER add hosts that serve arbitrary user content
// (raw.githubusercontent.com, gist.github.com, codeberg raw, gitlab raw, S3
// buckets) — attackers can host payloads there and would get a free downgrade.
export const KNOWN_INSTALLER_HOSTS = new Set([
  'claude.ai',
  'astral.sh',
  'brew.sh',
  'sh.rustup.rs',
  'deno.land',
  'bun.sh',
  'nodejs.org',
  'get.docker.com',
  'pyenv.run',
  'fnm.vercel.app',
]);
