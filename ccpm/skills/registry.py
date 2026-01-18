"""Discover command definitions and map them to callable skill wrappers."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping

COMMAND_DIRS = (Path(".claude/commands"), Path("ccpm/commands"))


@dataclass(frozen=True)
class SkillDefinition:
    command_name: str
    command_file: Path
    callable_name: str


PREFERRED_SKILL_GROUPS: dict[str, tuple[str, ...]] = {
    "core_workflow": (
        "pm:init",
        "pm:prd-new",
        "pm:prd-parse",
        "pm:epic-decompose",
        "pm:epic-sync",
        "pm:epic-oneshot",
        "pm:issue-analyze",
        "pm:issue-start",
        "pm:issue-sync",
        "pm:issue-close",
        "pm:epic-close",
        "pm:epic-merge",
        "pm:next",
    ),
    "testing_lanes": (
        "testing:fast",
        "testing:gate",
        "testing:full",
    ),
    "supporting": (
        "context:create",
        "context:update",
        "context:prime",
        "pm:epic-start",
        "pm:epic-start-worktree",
        "pm:epic-refresh",
        "pm:epic-status",
        "pm:issue-status",
        "pm:issue-show",
        "pm:issue-edit",
        "pm:issue-reopen",
        "pm:blocked",
        "pm:in-progress",
        "pm:status",
        "pm:standup",
        "pm:search",
        "pm:sync",
        "pm:validate",
        "pm:import",
        "pm:clean",
        "pm:epic-list",
        "pm:epic-show",
        "pm:epic-edit",
        "pm:prd-list",
        "pm:prd-status",
        "pm:prd-edit",
        "pm:help",
    ),
}


def discover_command_definitions(repo_root: Path | None = None) -> list[Path]:
    """Return command definition files from .claude/commands and ccpm/commands."""

    root = Path(repo_root) if repo_root else Path.cwd()
    command_files: list[Path] = []
    for command_dir in COMMAND_DIRS:
        absolute_dir = root / command_dir
        command_files.extend(_iter_command_files(absolute_dir))
    return sorted(command_files)


def build_registry(repo_root: Path | None = None) -> dict[str, SkillDefinition]:
    """Map command names to skill definitions."""

    registry: dict[str, SkillDefinition] = {}
    root = Path(repo_root) if repo_root else Path.cwd()
    for command_file in discover_command_definitions(root):
        command_root = _command_root(command_file, root)
        if command_root is None:
            continue
        command_name = _command_name_from_path(command_file, command_root)
        registry[command_name] = SkillDefinition(
            command_name=command_name,
            command_file=command_file,
            callable_name=_callable_name_for(command_name),
        )
    return dict(sorted(registry.items()))


def build_preferred_registry(
    registry: Mapping[str, SkillDefinition],
) -> dict[str, dict[str, SkillDefinition]]:
    """Return preferred skill groups, filtered to available registry entries."""

    return {
        group: {
            name: registry[name]
            for name in names
            if name in registry
        }
        for group, names in PREFERRED_SKILL_GROUPS.items()
    }


def _iter_command_files(command_dir: Path) -> Iterable[Path]:
    if not command_dir.exists():
        return []
    return [path for path in command_dir.rglob("*") if path.is_file()]


def _command_root(command_file: Path, repo_root: Path) -> Path | None:
    for command_dir in COMMAND_DIRS:
        root = repo_root / command_dir
        try:
            command_file.relative_to(root)
        except ValueError:
            continue
        return root
    return None


def _command_name_from_path(command_file: Path, command_root: Path) -> str:
    relative = command_file.relative_to(command_root)
    stem = relative.with_suffix("").as_posix()
    parts = stem.split("/")
    if len(parts) == 1:
        return parts[0]
    namespace, remainder = parts[0], "-".join(parts[1:])
    return f"{namespace}:{remainder}"


def _callable_name_for(command_name: str) -> str:
    sanitized = command_name.replace(":", "_").replace("-", "_")
    return f"skills.{sanitized}"
