export const SEVERITY = {
  CRITICAL: 'CRITICAL',
  HIGH: 'HIGH',
  MEDIUM: 'MEDIUM',
  LOW: 'LOW',
};

export const SCORE = {
  CRITICAL: 10,
  HIGH: 5,
  MEDIUM: 2,
  LOW: 1,
};

export const TOXIC_THRESHOLD = 10;
export const WARN_THRESHOLD = 5;

// ATLAS fork: cap LOW contribution per-rule to a noise floor.
// Rationale: documentation-heavy SKILL.md files accumulate many LOW findings
// (e.g., 21× "inline python -c exec" from fenced bash blocks teaching shell
// operations). Without a cap, the aggregate crosses TOXIC_THRESHOLD even
// though each individual finding is LOW severity and lives in documentation.
// With a cap, repeated patterns within a rule contribute up to LOW_CAP_PER_RULE
// points total, preserving signal without punishing thorough docs.
export const LOW_CAP_PER_RULE = 3;

export function verdict(findings) {
  // Score CRITICAL/HIGH/MEDIUM at face value.
  let total = 0;
  for (const f of findings) {
    if (f.severity !== 'LOW') total += (SCORE[f.severity] || 0);
  }

  // Score LOW with a per-rule cap so 20× identical doc matches don't snowball.
  const lowByRule = new Map();
  for (const f of findings) {
    if (f.severity !== 'LOW') continue;
    const k = f.ruleId || '?';
    lowByRule.set(k, (lowByRule.get(k) || 0) + SCORE.LOW);
  }
  for (const [, raw] of lowByRule) {
    total += Math.min(raw, LOW_CAP_PER_RULE);
  }

  if (total >= TOXIC_THRESHOLD) return { label: 'TOXIC', score: total, exitCode: 2 };
  if (total >= WARN_THRESHOLD) return { label: 'WARN', score: total, exitCode: 1 };
  return { label: 'SAFE', score: total, exitCode: 0 };
}
