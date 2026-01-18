from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping

from ccpm.orchestrator.state import default_state


@dataclass(frozen=True)
class ReconcileResult:
    state: dict[str, Any]
    notes: list[str]


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _collect_prds(claude_dir: Path) -> list[str]:
    prd_dir = claude_dir / "prds"
    if not prd_dir.exists():
        return []
    return sorted(path.name for path in prd_dir.glob("*.md"))


def _collect_epics(claude_dir: Path) -> dict[str, Any]:
    epics_dir = claude_dir / "epics"
    if not epics_dir.exists():
        return {}
    epics: dict[str, Any] = {}
    for epic_dir in epics_dir.iterdir():
        if not epic_dir.is_dir():
            continue
        epic_name = epic_dir.name
        tasks = []
        for path in epic_dir.glob("*.md"):
            if path.name == "epic.md":
                continue
            tasks.append(path.name)
        epics[epic_name] = {
            "path": str(epic_dir),
            "tasks": sorted(tasks),
            "has_epic_spec": (epic_dir / "epic.md").exists(),
        }
    return epics


def _normalize_github_issues(github_issues: Iterable[Mapping[str, Any]] | None) -> list[dict[str, Any]]:
    if not github_issues:
        return []
    normalized: list[dict[str, Any]] = []
    for issue in github_issues:
        normalized.append(dict(issue))
    return normalized


def reconcile_state(
    base_dir: Path | str | None = None,
    github_issues: Iterable[Mapping[str, Any]] | None = None,
    state: Mapping[str, Any] | None = None,
) -> ReconcileResult:
    base = Path(base_dir) if base_dir is not None else Path.cwd()
    claude_dir = base / ".claude"
    orchestrator_dir = claude_dir / "orchestrator"

    notes: list[str] = []
    merged_state = dict(default_state())
    if state:
        merged_state.update(state)

    roadmap_path = claude_dir / "roadmap.md"
    prds = _collect_prds(claude_dir)
    epics = _collect_epics(claude_dir)

    if not claude_dir.exists():
        notes.append("Missing .claude directory; nothing to reconcile.")

    merged_state["reconciled_at"] = _utc_now()
    merged_state["artifacts"] = {
        "roadmap": str(roadmap_path) if roadmap_path.exists() else None,
        "prds": prds,
        "epics": epics,
    }
    merged_state["github_issues"] = _normalize_github_issues(github_issues)
    merged_state["orchestrator_dir"] = str(orchestrator_dir)

    return ReconcileResult(state=merged_state, notes=notes)
