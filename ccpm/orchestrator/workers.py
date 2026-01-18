from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

from ccpm.orchestrator.config import OrchestratorConfig


REQUIRED_WORKER_OUTPUT_FIELDS = (
    "result",
    "branch",
    "files_touched",
    "fast_tests",
    "ready_to_merge",
    "notes",
)


class WorkerOutputError(ValueError):
    pass


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def workers_dir(base_dir: Path | str | None = None) -> Path:
    base = Path(base_dir) if base_dir is not None else Path.cwd()
    return base / ".claude" / "orchestrator" / "workers"


def worker_status_path(worker_id: str, base_dir: Path | str | None = None) -> Path:
    return workers_dir(base_dir) / f"{worker_id}.json"


@dataclass(frozen=True)
class WorkerStatus:
    worker_id: str
    status: str = "idle"
    task_id: str | None = None
    details: Mapping[str, Any] = field(default_factory=dict)
    updated_at: str = field(default_factory=_utc_now)

    def to_dict(self) -> dict[str, Any]:
        return {
            "worker_id": self.worker_id,
            "status": self.status,
            "task_id": self.task_id,
            "details": dict(self.details),
            "updated_at": self.updated_at,
        }


def write_worker_status(
    status: WorkerStatus,
    base_dir: Path | str | None = None,
) -> Path:
    path = worker_status_path(status.worker_id, base_dir)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(status.to_dict(), handle, indent=2, sort_keys=True)
        handle.write("\n")
    return path


def _existing_worker_ids(base_dir: Path | str | None = None) -> set[str]:
    directory = workers_dir(base_dir)
    if not directory.exists():
        return set()
    return {path.stem for path in directory.glob("*.json")}


def _next_worker_id(existing: set[str], counter: int) -> str:
    return f"worker-{counter}"


def spawn_workers(
    config: OrchestratorConfig,
    base_dir: Path | str | None = None,
    requested: int | None = None,
) -> list[WorkerStatus]:
    max_workers = config.get("parallelism", {}).get("max_workers", 1)
    target = min(requested or max_workers, max_workers)
    existing_ids = _existing_worker_ids(base_dir)
    workers: list[WorkerStatus] = []
    counter = 1
    while len(workers) < target:
        worker_id = _next_worker_id(existing_ids, counter)
        counter += 1
        if worker_id in existing_ids:
            continue
        status = WorkerStatus(worker_id=worker_id)
        write_worker_status(status, base_dir)
        existing_ids.add(worker_id)
        workers.append(status)
    return workers


@dataclass(frozen=True)
class WorkerPromptBundle:
    issue_spec: str
    task_markdown: str
    scope_hints: str
    ownership_boundaries: str
    repo_conventions: str

    def render(self) -> str:
        sections = [
            "# Issue Specification",
            self.issue_spec.strip(),
            "",
            "# Task",
            self.task_markdown.strip(),
            "",
            "# Scope Hints",
            self.scope_hints.strip(),
            "",
            "# File Ownership Boundaries",
            self.ownership_boundaries.strip(),
            "",
            "# Repo Conventions",
            self.repo_conventions.strip(),
            "",
            "# Required Output Format",
            "Return JSON with the following keys:",
            ", ".join(REQUIRED_WORKER_OUTPUT_FIELDS),
            "",
        ]
        return "\n".join(sections).strip() + "\n"


def build_worker_prompt_bundle(
    issue_spec: str,
    task_markdown: str,
    scope_hints: str,
    ownership_boundaries: str,
    repo_conventions: str,
) -> WorkerPromptBundle:
    return WorkerPromptBundle(
        issue_spec=issue_spec,
        task_markdown=task_markdown,
        scope_hints=scope_hints,
        ownership_boundaries=ownership_boundaries,
        repo_conventions=repo_conventions,
    )


def parse_worker_output(payload: str | Mapping[str, Any]) -> dict[str, Any]:
    data: Mapping[str, Any]
    if isinstance(payload, str):
        data = json.loads(payload)
    else:
        data = payload
    if not isinstance(data, Mapping):
        raise WorkerOutputError("Worker output must be a JSON object.")
    missing = [field for field in REQUIRED_WORKER_OUTPUT_FIELDS if field not in data]
    if missing:
        raise WorkerOutputError(f"Missing required worker output fields: {', '.join(missing)}")
    return dict(data)


@dataclass(frozen=True)
class TaskScope:
    files: tuple[str, ...] = ()
    modules: tuple[str, ...] = ()

    def normalized(self) -> tuple[set[str], set[str]]:
        return set(self.files), set(self.modules)


@dataclass(frozen=True)
class TaskSpec:
    task_id: str
    scope: TaskScope = field(default_factory=TaskScope)


@dataclass(frozen=True)
class ScopeConflict:
    task_ids: tuple[str, str]
    overlapping_files: tuple[str, ...]
    overlapping_modules: tuple[str, ...]


@dataclass(frozen=True)
class TaskBatchPlan:
    batches: list[list[TaskSpec]]
    conflicts: list[ScopeConflict]

    @property
    def requires_serialization(self) -> bool:
        return bool(self.conflicts)


def _scope_overlap(left: TaskScope, right: TaskScope) -> tuple[set[str], set[str]]:
    left_files, left_modules = left.normalized()
    right_files, right_modules = right.normalized()
    return left_files & right_files, left_modules & right_modules


def detect_scope_conflicts(tasks: Sequence[TaskSpec]) -> list[ScopeConflict]:
    conflicts: list[ScopeConflict] = []
    for idx, current in enumerate(tasks):
        for other in tasks[idx + 1 :]:
            overlapping_files, overlapping_modules = _scope_overlap(
                current.scope, other.scope
            )
            if overlapping_files or overlapping_modules:
                conflicts.append(
                    ScopeConflict(
                        task_ids=(current.task_id, other.task_id),
                        overlapping_files=tuple(sorted(overlapping_files)),
                        overlapping_modules=tuple(sorted(overlapping_modules)),
                    )
                )
    return conflicts


def plan_task_batches(tasks: Sequence[TaskSpec]) -> TaskBatchPlan:
    batches: list[list[TaskSpec]] = []
    conflicts: list[ScopeConflict] = []

    for task in tasks:
        placed = False
        for batch in batches:
            overlap = False
            for member in batch:
                overlapping_files, overlapping_modules = _scope_overlap(
                    task.scope, member.scope
                )
                if overlapping_files or overlapping_modules:
                    conflicts.append(
                        ScopeConflict(
                            task_ids=(task.task_id, member.task_id),
                            overlapping_files=tuple(sorted(overlapping_files)),
                            overlapping_modules=tuple(sorted(overlapping_modules)),
                        )
                    )
                    overlap = True
                    break
            if not overlap:
                batch.append(task)
                placed = True
                break
        if not placed:
            batches.append([task])

    return TaskBatchPlan(batches=batches, conflicts=conflicts)
