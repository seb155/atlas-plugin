"""LLM-as-Judge client for behavioral skill evaluation.

Reuses the Synapse judge_service.py pattern (httpx + Anthropic API).
The judge evaluates how well a skill's instructions would guide an LLM
to produce the expected output for a given test scenario.
"""

from __future__ import annotations

import json
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# System prompt for skill evaluation
# ---------------------------------------------------------------------------

SKILL_JUDGE_SYSTEM = """You are an expert evaluator for Claude Code plugin skills.
A "skill" is a markdown document that provides instructions to an LLM (Claude) on how to
perform a specific task (e.g., TDD, code review, deployment).

Your job: evaluate how well the skill's instructions would guide Claude to produce
the expected output for a given test scenario.

Score STRICTLY — a skill that would lead to incorrect, incomplete, or unsafe output
deserves low scores. A skill that clearly and completely guides correct behavior
deserves high scores.

Always return valid JSON. Never include explanations outside the JSON object."""


# ---------------------------------------------------------------------------
# Rubric templates per skill type
# ---------------------------------------------------------------------------

RUBRIC_TEMPLATES: dict[str, dict[str, str]] = {
    "code-generation": {
        "correctness": "Would the output be functionally correct? (1=broken, 5=perfect)",
        "adherence": "Does the skill enforce its methodology strictly? (1=ignores rules, 5=strict)",
        "completeness": "Are all steps covered? (1=missing critical steps, 5=complete)",
        "style": "Clean code, proper conventions? (1=messy, 5=exemplary)",
        "safety": "Error handling, edge cases? (1=none, 5=thorough)",
    },
    "planning": {
        "structure": "All required sections present and well-organized? (1=chaotic, 5=perfect)",
        "coverage": "Problem space fully explored? (1=surface-level, 5=comprehensive)",
        "feasibility": "Realistic effort, dependencies identified? (1=unrealistic, 5=spot-on)",
        "actionability": "Clear next steps, assignable tasks? (1=vague, 5=actionable)",
        "traceability": "Links to requirements, audit trail? (1=none, 5=full)",
    },
    "review": {
        "thoroughness": "All dimensions/categories covered? (1=superficial, 5=exhaustive)",
        "accuracy": "Findings match ground truth? (1=wrong, 5=accurate)",
        "actionability": "Clear remediation steps? (1=vague, 5=actionable)",
        "severity_calibration": "Correct severity classification? (1=miscalibrated, 5=precise)",
        "evidence": "Every finding has supporting evidence? (1=none, 5=full)",
    },
    "ops": {
        "completeness": "All steps present? (1=missing steps, 5=complete)",
        "safety": "Rollback, HITL gates, destructive checks? (1=dangerous, 5=safe)",
        "correctness": "Commands/configs correct? (1=broken, 5=correct)",
        "idempotency": "Safe to re-run? (1=destructive, 5=idempotent)",
        "observability": "Logging, monitoring, health checks? (1=blind, 5=observable)",
    },
}

# Default rubric for types not explicitly defined
DEFAULT_RUBRIC = {
    "correctness": "Would the output be correct? (1=wrong, 5=correct)",
    "completeness": "Are all aspects covered? (1=incomplete, 5=complete)",
    "clarity": "Is the output clear and well-structured? (1=confusing, 5=clear)",
    "usefulness": "Would this help the user? (1=useless, 5=very helpful)",
    "safety": "No harmful or risky actions? (1=dangerous, 5=safe)",
}


def get_rubric_for_type(skill_type: str) -> dict[str, str]:
    """Get the rubric template for a skill type."""
    return RUBRIC_TEMPLATES.get(skill_type, DEFAULT_RUBRIC)


# ---------------------------------------------------------------------------
# Judge prompt construction
# ---------------------------------------------------------------------------


def build_judge_prompt(
    skill_name: str,
    skill_type: str,
    skill_body: str,
    test_input: str,
    expected_contains: list[str],
    ground_truth: str,
    rubric: dict[str, str],
) -> str:
    """Build the evaluation prompt for the LLM judge."""
    rubric_text = "\n".join(
        f"- **{dim.upper()}**: {desc}" for dim, desc in rubric.items()
    )
    dim_keys = list(rubric.keys())

    return f"""## Evaluation Task

**Skill**: {skill_name}
**Skill Type**: {skill_type}

**Skill Instructions** (what the LLM receives as guidance):
```
{skill_body[:3000]}
```

**Test Scenario Input**:
{test_input}

**Expected Output Should Contain**:
{', '.join(expected_contains) if expected_contains else 'N/A'}

**Ground Truth**:
{ground_truth or 'N/A'}

## Score on these dimensions (1-5 each):

{rubric_text}

## Output

Return ONLY a JSON object (no markdown wrapping):
{{{', '.join(f'"{k}": N' for k in dim_keys)}, "reasoning": "brief explanation"}}"""


# ---------------------------------------------------------------------------
# API call
# ---------------------------------------------------------------------------


async def judge_skill(
    skill_name: str,
    skill_type: str,
    skill_body: str,
    test_input: str,
    expected_contains: list[str],
    ground_truth: str,
    rubric: dict[str, str] | None = None,
    model: str = "claude-haiku-4-5-20251001",
) -> dict[str, Any]:
    """Score a skill using an LLM judge.

    Returns dict with dimension scores (1-5 each) + reasoning.
    """
    api_key = os.getenv("ANTHROPIC_API_KEY", "")
    if not api_key:
        logger.warning("ANTHROPIC_API_KEY not set — returning default scores")
        return _default_scores(rubric or DEFAULT_RUBRIC, "No API key for judge")

    if rubric is None:
        rubric = get_rubric_for_type(skill_type)

    prompt = build_judge_prompt(
        skill_name=skill_name,
        skill_type=skill_type,
        skill_body=skill_body,
        test_input=test_input,
        expected_contains=expected_contains,
        ground_truth=ground_truth,
        rubric=rubric,
    )

    try:
        import httpx

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": model,
                    "max_tokens": 500,
                    "system": SKILL_JUDGE_SYSTEM,
                    "messages": [{"role": "user", "content": prompt}],
                },
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["content"][0]["text"].strip()

            # Handle potential markdown wrapping
            if text.startswith("```"):
                text = text.split("\n", 1)[1].rsplit("```", 1)[0].strip()

            scores = json.loads(text)

            # Extract token usage
            usage = data.get("usage", {})
            total_tokens = usage.get("input_tokens", 0) + usage.get("output_tokens", 0)

            # Validate all dimensions present
            for dim in rubric:
                if dim not in scores or not isinstance(scores[dim], (int, float)):
                    scores[dim] = 3  # Default if missing
                scores[dim] = max(1, min(5, scores[dim]))  # Clamp to 1-5

            scores["_judge_model"] = model
            scores["_judge_tokens"] = total_tokens
            return scores

    except Exception as e:
        logger.error("Judge evaluation failed: %s", e)
        return _default_scores(rubric, f"Judge error: {e}")


def _default_scores(rubric: dict[str, str], reason: str) -> dict[str, Any]:
    """Return neutral scores when judge is unavailable."""
    scores = {dim: 3 for dim in rubric}
    scores["reasoning"] = reason
    scores["_judge_model"] = None
    scores["_judge_tokens"] = 0
    return scores
