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

// ATLAS fork: cap LOW and MEDIUM contribution per-rule to a noise floor.
// Rationale: documentation-heavy SKILL.md files accumulate many identical
// findings (e.g., 21× "inline python -c exec" from fenced bash blocks; 2×
// "curl | python3" JSON parsing patterns in a REST API skill). Without caps,
// the aggregate crosses TOXIC_THRESHOLD even though each finding is a
// documentation match, not additive risk.
// Caps are per-rule so FIVE distinct rules each hitting 10 findings still
// totals 5 × cap — the distinct-rule count grows linearly, preserving signal.
// CRITICAL and HIGH are NEVER capped — single occurrences are always scored
// at face value (real compromises don't come in 20-copy batches).
export const LOW_CAP_PER_RULE = 3;
export const MEDIUM_CAP_PER_RULE = 3;

export function verdict(findings) {
  // CRITICAL and HIGH: face-value, no cap.
  let total = 0;
  for (const f of findings) {
    if (f.severity === 'CRITICAL' || f.severity === 'HIGH') {
      total += (SCORE[f.severity] || 0);
    }
  }

  // MEDIUM and LOW: per-rule cap so repeated doc matches don't snowball.
  const capped = (severity, cap) => {
    const byRule = new Map();
    for (const f of findings) {
      if (f.severity !== severity) continue;
      const k = f.ruleId || '?';
      byRule.set(k, (byRule.get(k) || 0) + (SCORE[severity] || 0));
    }
    for (const [, raw] of byRule) {
      total += Math.min(raw, cap);
    }
  };
  capped('MEDIUM', MEDIUM_CAP_PER_RULE);
  capped('LOW', LOW_CAP_PER_RULE);

  if (total >= TOXIC_THRESHOLD) return { label: 'TOXIC', score: total, exitCode: 2 };
  if (total >= WARN_THRESHOLD) return { label: 'WARN', score: total, exitCode: 1 };
  return { label: 'SAFE', score: total, exitCode: 0 };
}
