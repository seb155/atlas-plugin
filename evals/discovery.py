"""Codebase auto-discovery engine — detect stack, patterns, and quality signals.

Scans any repository and produces a structured discovery report used by the
codebase eval mode. Discovery results can be overridden via `.atlas/eval.yaml`.
"""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass, field
from pathlib import Path

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Discovery result types
# ---------------------------------------------------------------------------


@dataclass
class StackInfo:
    """Detected technology stack."""

    backend: str = ""  # python-fastapi, node-express, go, etc.
    frontend: str = ""  # react-ts, vue, svelte, etc.
    database: str = ""  # postgresql, mysql, mongodb, etc.
    infra: str = ""  # docker, k8s, terraform, etc.
    languages: list[str] = field(default_factory=list)


@dataclass
class TestInfo:
    """Detected test infrastructure."""

    frameworks: list[str] = field(default_factory=list)
    config_files: list[str] = field(default_factory=list)
    has_ci: bool = False
    ci_system: str = ""  # github | forgejo | gitlab | none
    coverage_available: bool = False
    estimated_coverage: float | None = None


@dataclass
class DocInfo:
    """Detected documentation."""

    has_readme: bool = False
    has_architecture_docs: bool = False
    has_api_docs: bool = False
    has_changelog: bool = False
    doc_dirs: list[str] = field(default_factory=list)


@dataclass
class SecurityInfo:
    """Detected security signals."""

    env_files_exposed: int = 0
    potential_secrets: int = 0
    has_gitignore: bool = False
    has_secret_scanner: bool = False
    dependency_lock: bool = False


@dataclass
class ArchitectureInfo:
    """Detected architecture patterns."""

    total_files: int = 0
    total_dirs: int = 0
    max_file_lines: int = 0
    avg_file_lines: float = 0.0
    large_files: list[str] = field(default_factory=list)  # files > 500 lines


@dataclass
class DependencyInfo:
    """Detected dependency state."""

    total_deps: int = 0
    lock_file: str = ""
    package_manager: str = ""


@dataclass
class DiscoveryReport:
    """Complete auto-discovery result for a repository."""

    repo_path: str = ""
    stack: StackInfo = field(default_factory=StackInfo)
    tests: TestInfo = field(default_factory=TestInfo)
    docs: DocInfo = field(default_factory=DocInfo)
    security: SecurityInfo = field(default_factory=SecurityInfo)
    architecture: ArchitectureInfo = field(default_factory=ArchitectureInfo)
    dependencies: DependencyInfo = field(default_factory=DependencyInfo)


# ---------------------------------------------------------------------------
# Stack detection
# ---------------------------------------------------------------------------

_BACKEND_MARKERS: list[tuple[str, str]] = [
    ("pyproject.toml", "python"),
    ("requirements.txt", "python"),
    ("setup.py", "python"),
    ("go.mod", "go"),
    ("Cargo.toml", "rust"),
    ("pom.xml", "java"),
    ("build.gradle", "java"),
    ("Gemfile", "ruby"),
]

_BACKEND_FRAMEWORK_PATTERNS: list[tuple[str, str, str]] = [
    # (file, pattern, framework_name)
    ("pyproject.toml", "fastapi", "python-fastapi"),
    ("pyproject.toml", "django", "python-django"),
    ("pyproject.toml", "flask", "python-flask"),
    ("requirements.txt", "fastapi", "python-fastapi"),
    ("requirements.txt", "django", "python-django"),
    ("package.json", '"express"', "node-express"),
    ("package.json", '"nestjs"', "node-nest"),
    ("package.json", '"hono"', "node-hono"),
]

_FRONTEND_MARKERS: list[tuple[str, str, str]] = [
    ("package.json", '"react"', "react"),
    ("package.json", '"vue"', "vue"),
    ("package.json", '"svelte"', "svelte"),
    ("package.json", '"angular"', "angular"),
    ("package.json", '"next"', "nextjs"),
]

_DB_MARKERS: list[tuple[str, str]] = [
    ("postgresql", "postgresql"),
    ("psycopg", "postgresql"),
    ("mysql", "mysql"),
    ("mongodb", "mongodb"),
    ("sqlite", "sqlite"),
    ("redis", "redis"),
    ("valkey", "valkey"),
]


def _detect_stack(repo: Path) -> StackInfo:
    """Detect technology stack from file markers."""
    info = StackInfo()
    languages = set()

    # Detect backend language (check root + common subdirs)
    search_dirs = [repo, repo / "backend", repo / "server", repo / "api", repo / "src"]
    for search_dir in search_dirs:
        for marker_file, lang in _BACKEND_MARKERS:
            p = search_dir / marker_file
            if p.exists() and p.is_file():
                languages.add(lang)

    # Detect backend framework (check root + common subdirs)
    for search_dir in search_dirs:
        for config_file, pattern, framework in _BACKEND_FRAMEWORK_PATTERNS:
            config_path = search_dir / config_file
            if config_path.exists() and config_path.is_file():
                content = config_path.read_text(encoding="utf-8", errors="ignore")
                if pattern.lower() in content.lower():
                    info.backend = framework
                    break
        if info.backend:
            break

    if not info.backend and languages:
        info.backend = sorted(languages)[0]

    # Detect frontend
    pkg_json = repo / "package.json"
    frontend_pkg = repo / "frontend" / "package.json"
    for pkg in [frontend_pkg, pkg_json]:
        if pkg.exists() and pkg.is_file():
            content = pkg.read_text(encoding="utf-8", errors="ignore")
            for _, pattern, fw in _FRONTEND_MARKERS:
                if pattern.lower() in content.lower():
                    # Check for TypeScript
                    ts_config = pkg.parent / "tsconfig.json"
                    info.frontend = f"{fw}-ts" if ts_config.exists() else fw
                    break
            if info.frontend:
                break

    # Detect database (scan config files)
    config_candidates = ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"]
    for cfg_name in config_candidates:
        cfg_path = repo / cfg_name
        if cfg_path.exists():
            content = cfg_path.read_text(encoding="utf-8", errors="ignore").lower()
            for pattern, db in _DB_MARKERS:
                if pattern in content:
                    info.database = db
                    break
            break

    # Detect infra
    if any((repo / f).exists() for f in config_candidates):
        info.infra = "docker"
    if (repo / "terraform").is_dir() or (repo / "main.tf").exists():
        info.infra = "terraform"
    if (repo / "k8s").is_dir() or (repo / "kubernetes").is_dir():
        info.infra = "kubernetes"

    # TypeScript detection
    if (repo / "tsconfig.json").exists() or (repo / "frontend" / "tsconfig.json").exists():
        languages.add("typescript")
    if pkg_json.exists() or frontend_pkg.exists():
        languages.add("javascript")

    info.languages = sorted(languages)
    return info


# ---------------------------------------------------------------------------
# Test infrastructure detection
# ---------------------------------------------------------------------------


_TEST_CONFIGS: list[tuple[str, str]] = [
    ("pytest.ini", "pytest"),
    ("pyproject.toml", "pytest"),  # check [tool.pytest] section
    ("setup.cfg", "pytest"),
    ("vitest.config.ts", "vitest"),
    ("vitest.config.js", "vitest"),
    ("jest.config.ts", "jest"),
    ("jest.config.js", "jest"),
    ("playwright.config.ts", "playwright"),
    (".mocharc.yml", "mocha"),
]

_CI_SYSTEMS: list[tuple[str, str]] = [
    (".github/workflows", "github"),
    (".forgejo/workflows", "forgejo"),
    (".gitlab-ci.yml", "gitlab"),
    ("Jenkinsfile", "jenkins"),
    (".circleci", "circleci"),
]


def _detect_tests(repo: Path) -> TestInfo:
    """Detect test frameworks and CI system."""
    info = TestInfo()

    for config_name, framework in _TEST_CONFIGS:
        # Check in root and common subdirs
        for subdir in ["", "backend", "frontend"]:
            cfg_path = repo / subdir / config_name if subdir else repo / config_name
            if cfg_path.exists():
                info.frameworks.append(framework)
                info.config_files.append(str(cfg_path.relative_to(repo)))
                break

    # Deduplicate frameworks
    info.frameworks = sorted(set(info.frameworks))

    # CI system
    for marker, system in _CI_SYSTEMS:
        marker_path = repo / marker
        if marker_path.exists() or marker_path.is_dir():
            info.has_ci = True
            info.ci_system = system
            break

    # Coverage
    coverage_files = [".coverage", "coverage", "htmlcov", "coverage/lcov.info"]
    for cov in coverage_files:
        if (repo / cov).exists():
            info.coverage_available = True
            break

    return info


# ---------------------------------------------------------------------------
# Documentation detection
# ---------------------------------------------------------------------------


def _detect_docs(repo: Path) -> DocInfo:
    """Detect documentation."""
    info = DocInfo()

    info.has_readme = (repo / "README.md").exists() or (repo / "readme.md").exists()
    info.has_changelog = (
        (repo / "CHANGELOG.md").exists()
        or (repo / "CHANGES.md").exists()
        or (repo / "HISTORY.md").exists()
    )

    # Architecture docs
    arch_dirs = [".blueprint", "docs", "doc", "documentation"]
    for d in arch_dirs:
        dp = repo / d
        if dp.is_dir():
            info.doc_dirs.append(d)
            md_count = len(list(dp.rglob("*.md")))
            if md_count >= 3:
                info.has_architecture_docs = True

    # API docs
    api_patterns = ["openapi.yaml", "openapi.json", "swagger.yaml", "swagger.json"]
    for pat in api_patterns:
        if list(repo.rglob(pat)):
            info.has_api_docs = True
            break

    return info


# ---------------------------------------------------------------------------
# Security detection
# ---------------------------------------------------------------------------

_SECRET_PATTERNS = [
    re.compile(r'(?:api[_-]?key|secret|token|password)\s*[=:]\s*["\'][^"\']{8,}', re.I),
    re.compile(r'AKIA[0-9A-Z]{16}'),  # AWS access key
    re.compile(r'ghp_[a-zA-Z0-9]{36}'),  # GitHub PAT
]


def _detect_security(repo: Path) -> SecurityInfo:
    """Detect security signals."""
    info = SecurityInfo()

    info.has_gitignore = (repo / ".gitignore").exists()

    # Check for exposed .env files
    env_files = list(repo.glob(".env*"))
    gitignore_content = ""
    if info.has_gitignore:
        gitignore_content = (repo / ".gitignore").read_text(encoding="utf-8", errors="ignore")

    for env_file in env_files:
        if env_file.name not in gitignore_content:
            info.env_files_exposed += 1

    # Check for secret scanning tools
    secret_scanners = [".gitleaks.toml", ".gitleaks.yaml", ".secretlintrc"]
    info.has_secret_scanner = any((repo / s).exists() for s in secret_scanners)

    # Lock file presence
    lock_files = ["bun.lockb", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "poetry.lock", "Pipfile.lock"]
    info.dependency_lock = any((repo / lf).exists() for lf in lock_files)

    # Scan a sample of source files for potential secrets
    source_extensions = {".py", ".ts", ".js", ".jsx", ".tsx", ".yaml", ".yml", ".json", ".env"}
    files_scanned = 0
    max_scan = 50  # Limit scan to 50 files

    for ext in source_extensions:
        for f in repo.rglob(f"*{ext}"):
            if files_scanned >= max_scan:
                break
            if "node_modules" in str(f) or ".git" in str(f) or "dist" in str(f):
                continue
            try:
                content = f.read_text(encoding="utf-8", errors="ignore")
                for pattern in _SECRET_PATTERNS:
                    if pattern.search(content):
                        info.potential_secrets += 1
                        break
            except Exception:
                pass
            files_scanned += 1

    return info


# ---------------------------------------------------------------------------
# Architecture analysis
# ---------------------------------------------------------------------------


def _detect_architecture(repo: Path) -> ArchitectureInfo:
    """Analyze repository architecture."""
    info = ArchitectureInfo()

    source_extensions = {".py", ".ts", ".js", ".jsx", ".tsx", ".go", ".rs", ".java", ".rb"}
    line_counts: list[int] = []
    dirs_seen: set[str] = set()

    for ext in source_extensions:
        for f in repo.rglob(f"*{ext}"):
            rel = str(f.relative_to(repo))
            if any(skip in rel for skip in ["node_modules", ".git", "dist", "__pycache__", ".next"]):
                continue

            info.total_files += 1
            dirs_seen.add(str(f.parent.relative_to(repo)))

            try:
                lines = len(f.read_text(encoding="utf-8", errors="ignore").splitlines())
                line_counts.append(lines)
                if lines > 500:
                    info.large_files.append(f"{rel} ({lines} lines)")
            except Exception:
                pass

    info.total_dirs = len(dirs_seen)
    if line_counts:
        info.max_file_lines = max(line_counts)
        info.avg_file_lines = round(sum(line_counts) / len(line_counts), 1)

    # Limit large_files to top 10
    info.large_files = sorted(info.large_files, key=lambda x: int(x.split("(")[1].split()[0]), reverse=True)[:10]

    return info


# ---------------------------------------------------------------------------
# Dependency detection
# ---------------------------------------------------------------------------


def _detect_dependencies(repo: Path) -> DependencyInfo:
    """Detect dependency state."""
    info = DependencyInfo()

    # Python
    req_path = repo / "requirements.txt"
    if req_path.exists() and req_path.is_file():
        info.total_deps += len([l for l in req_path.read_text().splitlines() if l.strip() and not l.startswith("#")])
        info.package_manager = "pip"

    pyproject = repo / "pyproject.toml"
    if pyproject.exists() and pyproject.is_file():
        content = pyproject.read_text(encoding="utf-8", errors="ignore")
        deps = re.findall(r'^\s*"?([a-zA-Z][\w-]*)', content)
        info.package_manager = "pip"

    # Node
    pkg_json = repo / "package.json"
    frontend_pkg = repo / "frontend" / "package.json"
    for pkg in [pkg_json, frontend_pkg]:
        if pkg.exists() and pkg.is_file():
            try:
                data = json.loads(pkg.read_text(encoding="utf-8"))
                info.total_deps += len(data.get("dependencies", {}))
                info.total_deps += len(data.get("devDependencies", {}))
            except Exception:
                pass

    # Lock files
    lock_map = {
        "bun.lockb": "bun",
        "package-lock.json": "npm",
        "yarn.lock": "yarn",
        "pnpm-lock.yaml": "pnpm",
        "poetry.lock": "poetry",
    }
    for lock_file, pm in lock_map.items():
        if (repo / lock_file).exists():
            info.lock_file = lock_file
            if not info.package_manager or pm != "pip":
                info.package_manager = pm
            break

    return info


# ---------------------------------------------------------------------------
# Main auto-discovery
# ---------------------------------------------------------------------------


def auto_discover(repo_path: Path) -> DiscoveryReport:
    """Run full auto-discovery on a repository.

    Returns a DiscoveryReport with all detected signals.
    """
    repo = repo_path.resolve()
    if not repo.is_dir():
        raise ValueError(f"Not a directory: {repo}")

    logger.info("Auto-discovering: %s", repo)

    report = DiscoveryReport(
        repo_path=str(repo),
        stack=_detect_stack(repo),
        tests=_detect_tests(repo),
        docs=_detect_docs(repo),
        security=_detect_security(repo),
        architecture=_detect_architecture(repo),
        dependencies=_detect_dependencies(repo),
    )

    logger.info(
        "Discovery complete: stack=%s/%s, tests=%s, ci=%s, %d files",
        report.stack.backend,
        report.stack.frontend,
        report.tests.frameworks,
        report.tests.ci_system,
        report.architecture.total_files,
    )

    return report
