from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Iterable, Mapping, Sequence

from ccpm.orchestrator.config import OrchestratorConfig


MergeOperation = Callable[[str, str], "MergeOperationResult"]
TestOperation = Callable[[str], "TestOperationResult"]
RemediationHandler = Callable[["RemediationRequest"], None]


MERGE_CLASSIFICATION_CONFLICT = "conflict"
MERGE_CLASSIFICATION_TEST_FAILURE = "test_failure"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass(frozen=True)
class MergeQueueEntry:
    branch: str
    task_id: str | None = None
    ready_at: str = field(default_factory=_utc_now)
    metadata: Mapping[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "branch": self.branch,
            "task_id": self.task_id,
            "ready_at": self.ready_at,
            "metadata": dict(self.metadata),
        }

    @classmethod
    def from_payload(cls, payload: Mapping[str, Any]) -> "MergeQueueEntry":
        return cls(
            branch=str(payload.get("branch") or ""),
            task_id=payload.get("task_id"),
            ready_at=str(payload.get("ready_at") or _utc_now()),
            metadata=dict(payload.get("metadata") or {}),
        )


@dataclass(frozen=True)
class MergeQueue:
    entries: tuple[MergeQueueEntry, ...] = ()

    def to_payload(self) -> list[dict[str, Any]]:
        return [entry.to_dict() for entry in self.entries]

    def branches(self) -> set[str]:
        return {entry.branch for entry in self.entries}


@dataclass(frozen=True)
class MergeOperationResult:
    success: bool
    conflict: bool = False
    message: str | None = None


@dataclass(frozen=True)
class TestOperationResult:
    success: bool
    message: str | None = None


@dataclass(frozen=True)
class RemediationRequest:
    classification: str
    action: str
    branch: str | None
    integration_branch: str
    message: str | None
    lane: str | None = None


@dataclass(frozen=True)
class MergeGateOutcome:
    branch: str
    status: str
    details: str | None = None


@dataclass(frozen=True)
class MergeGateResult:
    state: dict[str, Any]
    outcomes: tuple[MergeGateOutcome, ...]
    remediation: tuple[RemediationRequest, ...]
    halted: bool
    reason: str | None = None


def load_merge_queue(state: Mapping[str, Any]) -> MergeQueue:
    raw = state.get("merge_queue") or []
    entries: list[MergeQueueEntry] = []
    if isinstance(raw, Sequence) and not isinstance(raw, (str, bytes)):
        for item in raw:
            if isinstance(item, Mapping):
                entries.append(MergeQueueEntry.from_payload(item))
            else:
                entries.append(MergeQueueEntry(branch=str(item)))
    return MergeQueue(entries=tuple(entries))


def enqueue_ready_branches(
    state: dict[str, Any],
    branches: Iterable[MergeQueueEntry | Mapping[str, Any] | str],
) -> dict[str, Any]:
    queue = load_merge_queue(state)
    existing = queue.branches()
    entries = list(queue.entries)
    for item in branches:
        entry: MergeQueueEntry
        if isinstance(item, MergeQueueEntry):
            entry = item
        elif isinstance(item, Mapping):
            entry = MergeQueueEntry.from_payload(item)
        else:
            entry = MergeQueueEntry(branch=str(item))
        if entry.branch and entry.branch not in existing:
            entries.append(entry)
            existing.add(entry.branch)
    updated = dict(state)
    updated["merge_queue"] = MergeQueue(entries=tuple(entries)).to_payload()
    return updated


def _integration_branch(config: OrchestratorConfig, epic: str) -> str:
    prefix = config.get("git", {}).get("integration_branch_prefix", "integration/")
    return f"{prefix}{epic}"


def _main_branch(config: OrchestratorConfig) -> str:
    return config.get("git", {}).get("main_branch", "main")


def _lane_skill(config: OrchestratorConfig, lane: str, default: str) -> str:
    lanes = config.get("testing", {}).get("lanes", {})
    return lanes.get(lane, {}).get("skill", default)


def _merge_batch(
    merge_operation: MergeOperation,
    integration_branch: str,
    batch: Sequence[MergeQueueEntry],
    outcomes: list[MergeGateOutcome],
) -> tuple[bool, MergeOperationResult | None]:
    for entry in batch:
        result = merge_operation(integration_branch, entry.branch)
        if not result.success:
            outcomes.append(
                MergeGateOutcome(
                    branch=entry.branch,
                    status=MERGE_CLASSIFICATION_CONFLICT,
                    details=result.message,
                )
            )
            return False, result
        outcomes.append(MergeGateOutcome(branch=entry.branch, status="merged"))
    return True, None


def process_merge_queue(
    *,
    state: dict[str, Any],
    epic: str,
    config: OrchestratorConfig,
    merge_operation: MergeOperation,
    test_operation: TestOperation,
    remediation_handler: RemediationHandler | None = None,
    batch_size: int = 1,
) -> MergeGateResult:
    queue = load_merge_queue(state)
    remaining = list(queue.entries)
    outcomes: list[MergeGateOutcome] = []
    remediation: list[RemediationRequest] = []

    integration_branch = _integration_branch(config, epic)
    main_branch = _main_branch(config)
    gate_lane = _lane_skill(config, "gate", "testing:gate")
    full_lane = _lane_skill(config, "full", "testing:full")
    batch_limit = max(batch_size, 1)

    while remaining:
        batch = remaining[:batch_limit]
        batch_success, merge_result = _merge_batch(
            merge_operation, integration_branch, batch, outcomes
        )
        if not batch_success:
            failure = RemediationRequest(
                classification=MERGE_CLASSIFICATION_CONFLICT,
                action="worker",
                branch=batch[0].branch,
                integration_branch=integration_branch,
                message=merge_result.message if merge_result else None,
            )
            remediation.append(failure)
            if remediation_handler:
                remediation_handler(failure)
            updated_state = dict(state)
            updated_state["merge_queue"] = MergeQueue(entries=tuple(remaining)).to_payload()
            return MergeGateResult(
                state=updated_state,
                outcomes=tuple(outcomes),
                remediation=tuple(remediation),
                halted=True,
                reason=MERGE_CLASSIFICATION_CONFLICT,
            )

        gate_result = test_operation(gate_lane)
        if not gate_result.success:
            outcomes.append(
                MergeGateOutcome(
                    branch=integration_branch,
                    status=MERGE_CLASSIFICATION_TEST_FAILURE,
                    details=gate_result.message,
                )
            )
            failure = RemediationRequest(
                classification=MERGE_CLASSIFICATION_TEST_FAILURE,
                action="orchestrator",
                branch=None,
                integration_branch=integration_branch,
                message=gate_result.message,
                lane=gate_lane,
            )
            remediation.append(failure)
            if remediation_handler:
                remediation_handler(failure)
            updated_state = dict(state)
            updated_state["merge_queue"] = MergeQueue(entries=tuple(remaining)).to_payload()
            return MergeGateResult(
                state=updated_state,
                outcomes=tuple(outcomes),
                remediation=tuple(remediation),
                halted=True,
                reason=MERGE_CLASSIFICATION_TEST_FAILURE,
            )

        remaining = remaining[batch_limit:]

    integration_merge = merge_operation(main_branch, integration_branch)
    if not integration_merge.success:
        outcomes.append(
            MergeGateOutcome(
                branch=integration_branch,
                status=MERGE_CLASSIFICATION_CONFLICT,
                details=integration_merge.message,
            )
        )
        failure = RemediationRequest(
            classification=MERGE_CLASSIFICATION_CONFLICT,
            action="worker",
            branch=integration_branch,
            integration_branch=main_branch,
            message=integration_merge.message,
        )
        remediation.append(failure)
        if remediation_handler:
            remediation_handler(failure)
        updated_state = dict(state)
        updated_state["merge_queue"] = []
        return MergeGateResult(
            state=updated_state,
            outcomes=tuple(outcomes),
            remediation=tuple(remediation),
            halted=True,
            reason=MERGE_CLASSIFICATION_CONFLICT,
        )

    full_result = test_operation(full_lane)
    if not full_result.success:
        outcomes.append(
            MergeGateOutcome(
                branch=main_branch,
                status=MERGE_CLASSIFICATION_TEST_FAILURE,
                details=full_result.message,
            )
        )
        failure = RemediationRequest(
            classification=MERGE_CLASSIFICATION_TEST_FAILURE,
            action="orchestrator",
            branch=None,
            integration_branch=main_branch,
            message=full_result.message,
            lane=full_lane,
        )
        remediation.append(failure)
        if remediation_handler:
            remediation_handler(failure)
        updated_state = dict(state)
        updated_state["merge_queue"] = []
        return MergeGateResult(
            state=updated_state,
            outcomes=tuple(outcomes),
            remediation=tuple(remediation),
            halted=True,
            reason=MERGE_CLASSIFICATION_TEST_FAILURE,
        )

    updated_state = dict(state)
    updated_state["merge_queue"] = []
    return MergeGateResult(
        state=updated_state,
        outcomes=tuple(outcomes),
        remediation=tuple(remediation),
        halted=False,
        reason=None,
    )
