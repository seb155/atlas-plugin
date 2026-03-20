# /atlas eval — Evaluation Lifecycle

Route to `eval-lifecycle` skill for full evaluation workflows.

## Subcommands

| Command | Description |
|---------|-------------|
| `/atlas eval` | Auto-detect mode and run full eval |
| `/atlas eval --mode plugin` | Evaluate ATLAS plugin skills |
| `/atlas eval --mode codebase` | Evaluate current codebase |
| `/atlas eval --suite core` | Run core skills suite only |
| `/atlas eval --level structural` | Structural eval only (fast, no API cost) |
| `/atlas eval --skill tdd` | Evaluate a single skill |
| `/atlas eval --baseline` | Establish baseline for regression detection |
| `/atlas eval --compare` | Compare current run to baseline |
| `/atlas eval --report` | Generate report from latest run |
| `/atlas eval --experiment FILE` | Run A/B experiment on skill variants |
| `/atlas eval --gate` | Check release gates against latest results |

## Quick Start

```bash
# Fast structural eval (no API cost)
python -m evals.runner --mode plugin --level structural -o /tmp/eval.json

# Full eval with LLM judge (requires ANTHROPIC_API_KEY)
python -m evals.runner --mode plugin --suite core -o /tmp/eval.json

# Check CI gate
python -m evals.gate --min-structural 70 /tmp/eval.json
```

## Skill Reference

Delegates to: `eval-lifecycle` skill (admin tier)
