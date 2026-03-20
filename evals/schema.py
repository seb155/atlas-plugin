"""Pydantic models for eval YAML validation and result types.

All eval cases, rubrics, suites, and results are typed here.
The runner, structural, and behavioral modules import from this module.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any

import yaml


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------


class EvalMode(str, Enum):
    PLUGIN = "plugin"
    CODEBASE = "codebase"


class EvalLevel(str, Enum):
    STRUCTURAL = "structural"
    BEHAVIORAL = "behavioral"
    FULL = "full"


class SkillType(str, Enum):
    CODE_GENERATION = "code-generation"
    PLANNING = "planning"
    REVIEW = "review"
    OPS = "ops"
    RESEARCH = "research"
    META = "meta"
    PERSONAL = "personal"
    DOMAIN = "domain"
    WORKFLOW = "workflow"
    PRESENTATION = "presentation"
    REFERENCE = "reference"


class Grade(str, Enum):
    A = "A"
    B = "B"
    C = "C"
    D = "D"
    F = "F"


# ---------------------------------------------------------------------------
# Eval Case (per-skill YAML)
# ---------------------------------------------------------------------------


@dataclass
class StructuralCriteria:
    """Structural eval criteria (automated, no LLM needed)."""

    min_body_lines: int = 20
    required_sections: list[str] = field(default_factory=list)
    required_tool_mentions: list[str] = field(default_factory=list)
    max_token_estimate: int = 4000
    cross_references: list[str] = field(default_factory=list)
    requires_hitl_gates: bool = False
    progressive_disclosure_levels: int = 3


@dataclass
class BehavioralCase:
    """Single behavioral test case with golden input/output."""

    id: str
    name: str
    input: str
    expected_contains: list[str] = field(default_factory=list)
    expected_order: list[str] = field(default_factory=list)
    ground_truth: str = ""
    rubric_overrides: dict[str, float] = field(default_factory=dict)


@dataclass
class BehavioralCriteria:
    """Behavioral eval criteria (LLM-as-Judge on golden sets)."""

    cases: list[BehavioralCase] = field(default_factory=list)


@dataclass
class EvalCase:
    """Complete eval case for one skill."""

    skill: str
    version: str = "1.0"
    type: SkillType = SkillType.META
    structural: StructuralCriteria = field(default_factory=StructuralCriteria)
    behavioral: BehavioralCriteria = field(default_factory=BehavioralCriteria)


# ---------------------------------------------------------------------------
# Eval Suite
# ---------------------------------------------------------------------------


@dataclass
class EvalSuite:
    """Named collection of skills to evaluate."""

    name: str
    description: str = ""
    skills: list[str] = field(default_factory=lambda: ["*"])
    levels: list[EvalLevel] = field(
        default_factory=lambda: [EvalLevel.STRUCTURAL, EvalLevel.BEHAVIORAL]
    )
    judge_model: str = "claude-haiku-4-5-20251001"
    timeout_per_case: int = 120


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------


@dataclass
class DimensionScore:
    """Score for a single dimension."""

    name: str
    score: float  # 0-100 for structural, 1-5 for behavioral
    weight: float  # percentage weight
    details: str = ""


@dataclass
class EvalScore:
    """Score for a single skill/item at one eval level."""

    item_name: str
    eval_level: EvalLevel
    case_id: str | None = None
    composite: float = 0.0
    dimensions: list[DimensionScore] = field(default_factory=list)
    grade: Grade = Grade.F
    reasoning: str = ""
    judge_model: str | None = None
    judge_tokens: int = 0
    # Regression
    baseline_composite: float | None = None
    delta: float | None = None
    is_regression: bool = False


@dataclass
class EvalResult:
    """Complete result for an eval run."""

    mode: EvalMode
    level: EvalLevel
    suite_name: str = "full"
    target_name: str = ""
    plugin_version: str = ""
    branch: str = ""
    commit_sha: str = ""
    total_items: int = 0
    structural_avg: float = 0.0
    behavioral_avg: float = 0.0
    composite_avg: float = 0.0
    grade: Grade = Grade.F
    regression_count: int = 0
    scores: list[EvalScore] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Codebase eval config
# ---------------------------------------------------------------------------


@dataclass
class CodebaseDimension:
    """A single codebase evaluation dimension."""

    name: str
    weight: float  # percentage
    auto_checks: list[str] = field(default_factory=list)
    rubric_overrides: dict[str, Any] = field(default_factory=dict)


@dataclass
class CodebaseEvalConfig:
    """Config loaded from .atlas/eval.yaml for codebase mode."""

    mode: EvalMode = EvalMode.CODEBASE
    name: str = ""
    stack_override: dict[str, str] = field(default_factory=dict)
    dimensions: list[CodebaseDimension] = field(default_factory=list)
    min_grade: Grade = Grade.B
    max_critical: int = 0


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------


def load_eval_case(path: Path) -> EvalCase:
    """Load an eval case from a YAML file."""
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"Invalid eval case: {path}")

    structural_data = data.get("structural", {})
    structural = StructuralCriteria(
        min_body_lines=structural_data.get("min_body_lines", 20),
        required_sections=structural_data.get("required_sections", []),
        required_tool_mentions=structural_data.get("required_tool_mentions", []),
        max_token_estimate=structural_data.get("max_token_estimate", 4000),
        cross_references=structural_data.get("cross_references", []),
        requires_hitl_gates=structural_data.get("requires_hitl_gates", False),
        progressive_disclosure_levels=structural_data.get(
            "progressive_disclosure_levels", 3
        ),
    )

    behavioral_data = data.get("behavioral", {})
    cases = []
    for c in behavioral_data.get("cases", []):
        cases.append(
            BehavioralCase(
                id=c["id"],
                name=c.get("name", c["id"]),
                input=c["input"],
                expected_contains=c.get("expected_contains", []),
                expected_order=c.get("expected_order", []),
                ground_truth=c.get("ground_truth", ""),
                rubric_overrides=c.get("rubric_overrides", {}),
            )
        )
    behavioral = BehavioralCriteria(cases=cases)

    return EvalCase(
        skill=data["skill"],
        version=data.get("version", "1.0"),
        type=SkillType(data.get("type", "meta")),
        structural=structural,
        behavioral=behavioral,
    )


def load_suite(path: Path) -> EvalSuite:
    """Load an eval suite definition from YAML."""
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"Invalid suite: {path}")

    levels = [EvalLevel(l) for l in data.get("levels", ["structural", "behavioral"])]

    return EvalSuite(
        name=data["name"],
        description=data.get("description", ""),
        skills=data.get("skills", ["*"]),
        levels=levels,
        judge_model=data.get("judge_model", "claude-haiku-4-5-20251001"),
        timeout_per_case=data.get("timeout_per_case", 120),
    )


def load_rubric(path: Path) -> dict[str, float]:
    """Load a scoring rubric (dimension name -> weight)."""
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"Invalid rubric: {path}")
    dims = data.get("dimensions", {})
    return {name: float(weight) for name, weight in dims.items()}
