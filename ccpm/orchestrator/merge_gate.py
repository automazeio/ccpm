from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping, Sequence, TYPE_CHECKING

from ccpm.orchestrator.config import OrchestratorConfig
from ccpm.orchestrator.help import write_help_request
from ccpm.orchestrator.state import record_error, save_state

if TYPE_CHECKING:
    from ccpm.orchestrator.events import EventLogger
    from ccpm.orchestrator.sync import SyncCoordinator


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
    event_logger: "EventLogger | None" = None,
    syncer: "SyncCoordinator | None" = None,
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
            if event_logger:
                event_logger.log_transition(
                    kind="issue",
                    to_state="ready",
                    subject=entry.task_id or entry.branch,
                    metadata={"branch": entry.branch, "task_id": entry.task_id},
                )
            if syncer:
                syncer.post_task_transition(
                    state=state,
                    task_id=entry.task_id,
                    metadata=entry.metadata,
                    status="ready",
                    details=f"Queued for merge into {entry.branch}",
                )
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
    state: Mapping[str, Any],
    event_logger: "EventLogger | None",
    syncer: "SyncCoordinator | None",
) -> tuple[bool, MergeOperationResult | None]:
    for entry in batch:
        if event_logger:
            event_logger.log_transition(
                kind="issue",
                to_state="started",
                subject=entry.task_id or entry.branch,
                metadata={"branch": entry.branch, "task_id": entry.task_id},
            )
        if syncer:
            syncer.post_task_transition(
                state=state,
                task_id=entry.task_id,
                metadata=entry.metadata,
                status="started",
                details=f"Merge started into {integration_branch}",
            )
        result = merge_operation(integration_branch, entry.branch)
        if not result.success:
            if event_logger:
                event_logger.log_merge(
                    branch=entry.branch,
                    status=MERGE_CLASSIFICATION_CONFLICT,
                    integration_branch=integration_branch,
                    task_id=entry.task_id,
                    details=result.message,
                )
            outcomes.append(
                MergeGateOutcome(
                    branch=entry.branch,
                    status=MERGE_CLASSIFICATION_CONFLICT,
                    details=result.message,
                )
            )
            if event_logger:
                event_logger.log_transition(
                    kind="issue",
                    to_state="blocked",
                    subject=entry.task_id or entry.branch,
                    metadata={"branch": entry.branch, "task_id": entry.task_id},
                )
            if syncer:
                syncer.post_task_transition(
                    state=state,
                    task_id=entry.task_id,
                    metadata=entry.metadata,
                    status="blocked",
                    details=result.message,
                )
            return False, result
        outcomes.append(MergeGateOutcome(branch=entry.branch, status="merged"))
        if event_logger:
            event_logger.log_merge(
                branch=entry.branch,
                status="merged",
                integration_branch=integration_branch,
                task_id=entry.task_id,
                details=result.message,
            )
            event_logger.log_transition(
                kind="issue",
                to_state="merged",
                subject=entry.task_id or entry.branch,
                metadata={"branch": entry.branch, "task_id": entry.task_id},
            )
        if syncer:
            syncer.post_task_transition(
                state=state,
                task_id=entry.task_id,
                metadata=entry.metadata,
                status="merged",
                details=f"Merged into {integration_branch}",
            )
    return True, None


def _retry_limit_exceeded(
    state: Mapping[str, Any],
    classification: str,
    config: OrchestratorConfig,
) -> bool:
    counters = state.get("retry_counters") or {}
    current = int(counters.get(classification, 0))
    limit = int(config.get("retries", {}).get("transient_max", 2))
    return current > limit


def _resolve_base_dir(
    base_dir: Path | str | None, syncer: "SyncCoordinator | None"
) -> Path:
    if base_dir is not None:
        return Path(base_dir)
    if syncer is not None:
        return syncer.base_dir
    return Path.cwd()


def _halt_for_retry_exhaustion(
    *,
    state: dict[str, Any],
    base_dir: Path,
    classification: str,
    remediation: Sequence[RemediationRequest],
    reason: str | None,
    syncer: "SyncCoordinator | None",
) -> dict[str, Any]:
    updated_state = dict(state)
    updated_state["halted"] = True
    updated_state["halt_reason"] = "retry_exhausted"
    help_path, timestamp = write_help_request(
        state=updated_state,
        base_dir=base_dir,
        remediation=[r.__dict__ for r in remediation],
        reason=reason or classification,
    )
    updated_state["help_request"] = {
        "path": str(help_path),
        "timestamp": timestamp,
        "classification": classification,
    }
    save_state(updated_state, base_dir)
    if syncer:
        syncer.post_help_request(
            state=updated_state,
            help_path=help_path,
            reason=reason or classification,
            remediation=[r.__dict__ for r in remediation],
        )
    return updated_state


def process_merge_queue(
    *,
    state: dict[str, Any],
    epic: str,
    config: OrchestratorConfig,
    merge_operation: MergeOperation,
    test_operation: TestOperation,
    remediation_handler: RemediationHandler | None = None,
    batch_size: int = 1,
    event_logger: "EventLogger | None" = None,
    syncer: "SyncCoordinator | None" = None,
    base_dir: Path | str | None = None,
) -> MergeGateResult:
    queue = load_merge_queue(state)
    remaining = list(queue.entries)
    outcomes: list[MergeGateOutcome] = []
    remediation: list[RemediationRequest] = []
    resolved_base_dir = _resolve_base_dir(base_dir, syncer)

    integration_branch = _integration_branch(config, epic)
    main_branch = _main_branch(config)
    gate_lane = _lane_skill(config, "gate", "testing:gate")
    full_lane = _lane_skill(config, "full", "testing:full")
    batch_limit = max(batch_size, 1)

    while remaining:
        batch = remaining[:batch_limit]
        batch_success, merge_result = _merge_batch(
            merge_operation,
            integration_branch,
            batch,
            outcomes,
            state,
            event_logger,
            syncer,
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
            updated_state = record_error(
                updated_state,
                step="merge_gate",
                classification="conflict",
                message=merge_result.message if merge_result else "Merge conflict",
                event_logger=event_logger,
            )
            if event_logger and _retry_limit_exceeded(
                updated_state, "conflict", config
            ):
                event_logger.log_escalation(
                    classification="conflict",
                    step="merge_gate",
                    retry_counters=updated_state.get("retry_counters") or {},
                    remediation=[r.__dict__ for r in remediation],
                    message=merge_result.message if merge_result else None,
                )
            if syncer and _retry_limit_exceeded(updated_state, "conflict", config):
                syncer.post_escalation(
                    state=updated_state,
                    classification="conflict",
                    step="merge_gate",
                    remediation=[r.__dict__ for r in remediation],
                )
            if _retry_limit_exceeded(updated_state, "conflict", config):
                updated_state = _halt_for_retry_exhaustion(
                    state=updated_state,
                    base_dir=resolved_base_dir,
                    classification="conflict",
                    remediation=remediation,
                    reason=merge_result.message if merge_result else None,
                    syncer=syncer,
                )
            updated_state["merge_queue"] = MergeQueue(entries=tuple(remaining)).to_payload()
            return MergeGateResult(
                state=updated_state,
                outcomes=tuple(outcomes),
                remediation=tuple(remediation),
                halted=True,
                reason=MERGE_CLASSIFICATION_CONFLICT,
            )

        gate_result = test_operation(gate_lane)
        if event_logger:
            event_logger.log_test_result(
                lane=gate_lane,
                status="passed" if gate_result.success else "failed",
                branch=integration_branch,
                message=gate_result.message,
            )
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
            updated_state = record_error(
                updated_state,
                step="merge_gate",
                classification="verification",
                message=gate_result.message or "Gate tests failed",
                event_logger=event_logger,
            )
            if event_logger:
                event_logger.log_transition(
                    kind="issue",
                    to_state="tests_failed",
                    subject=integration_branch,
                    metadata={"branch": integration_branch, "lane": gate_lane},
                )
            if syncer:
                syncer.post_epic_transition(
                    epic_id=epic,
                    status="tests failed",
                    details=gate_result.message,
                )
            if event_logger and _retry_limit_exceeded(
                updated_state, "verification", config
            ):
                event_logger.log_escalation(
                    classification="verification",
                    step="merge_gate",
                    retry_counters=updated_state.get("retry_counters") or {},
                    remediation=[r.__dict__ for r in remediation],
                    message=gate_result.message,
                )
            if syncer and _retry_limit_exceeded(updated_state, "verification", config):
                syncer.post_escalation(
                    state=updated_state,
                    classification="verification",
                    step="merge_gate",
                    remediation=[r.__dict__ for r in remediation],
                )
            if _retry_limit_exceeded(updated_state, "verification", config):
                updated_state = _halt_for_retry_exhaustion(
                    state=updated_state,
                    base_dir=resolved_base_dir,
                    classification="verification",
                    remediation=remediation,
                    reason=gate_result.message,
                    syncer=syncer,
                )
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
        if event_logger:
            event_logger.log_merge(
                branch=integration_branch,
                status=MERGE_CLASSIFICATION_CONFLICT,
                integration_branch=main_branch,
                details=integration_merge.message,
            )
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
        updated_state = record_error(
            updated_state,
            step="merge_gate",
            classification="conflict",
            message=integration_merge.message or "Integration merge conflict",
            event_logger=event_logger,
        )
        if event_logger:
            event_logger.log_transition(
                kind="issue",
                to_state="blocked",
                subject=integration_branch,
                metadata={"branch": integration_branch},
            )
        if syncer:
            syncer.post_epic_transition(
                epic_id=epic,
                status="blocked",
                details=integration_merge.message,
            )
        if event_logger and _retry_limit_exceeded(updated_state, "conflict", config):
            event_logger.log_escalation(
                classification="conflict",
                step="merge_gate",
                retry_counters=updated_state.get("retry_counters") or {},
                remediation=[r.__dict__ for r in remediation],
                message=integration_merge.message,
            )
        if syncer and _retry_limit_exceeded(updated_state, "conflict", config):
            syncer.post_escalation(
                state=updated_state,
                classification="conflict",
                step="merge_gate",
                remediation=[r.__dict__ for r in remediation],
            )
        if _retry_limit_exceeded(updated_state, "conflict", config):
            updated_state = _halt_for_retry_exhaustion(
                state=updated_state,
                base_dir=resolved_base_dir,
                classification="conflict",
                remediation=remediation,
                reason=integration_merge.message,
                syncer=syncer,
            )
        updated_state["merge_queue"] = []
        return MergeGateResult(
            state=updated_state,
            outcomes=tuple(outcomes),
            remediation=tuple(remediation),
            halted=True,
            reason=MERGE_CLASSIFICATION_CONFLICT,
        )

    full_result = test_operation(full_lane)
    if event_logger:
        event_logger.log_test_result(
            lane=full_lane,
            status="passed" if full_result.success else "failed",
            branch=main_branch,
            message=full_result.message,
        )
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
        updated_state = record_error(
            updated_state,
            step="merge_gate",
            classification="verification",
            message=full_result.message or "Full tests failed",
            event_logger=event_logger,
        )
        if event_logger:
            event_logger.log_transition(
                kind="issue",
                to_state="tests_failed",
                subject=main_branch,
                metadata={"branch": main_branch, "lane": full_lane},
            )
        if syncer:
            syncer.post_epic_transition(
                epic_id=epic,
                status="tests failed",
                details=full_result.message,
            )
        if event_logger and _retry_limit_exceeded(
            updated_state, "verification", config
        ):
            event_logger.log_escalation(
                classification="verification",
                step="merge_gate",
                retry_counters=updated_state.get("retry_counters") or {},
                remediation=[r.__dict__ for r in remediation],
                message=full_result.message,
            )
        if syncer and _retry_limit_exceeded(updated_state, "verification", config):
            syncer.post_escalation(
                state=updated_state,
                classification="verification",
                step="merge_gate",
                remediation=[r.__dict__ for r in remediation],
            )
        if _retry_limit_exceeded(updated_state, "verification", config):
            updated_state = _halt_for_retry_exhaustion(
                state=updated_state,
                base_dir=resolved_base_dir,
                classification="verification",
                remediation=remediation,
                reason=full_result.message,
                syncer=syncer,
            )
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
