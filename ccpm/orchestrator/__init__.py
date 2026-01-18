"""CCPM orchestrator module."""

from ccpm.orchestrator.config import load_config
from ccpm.orchestrator.merge_gate import (
    MergeGateOutcome,
    MergeGateResult,
    MergeOperationResult,
    MergeQueue,
    MergeQueueEntry,
    RemediationRequest,
    TestOperationResult,
    enqueue_ready_branches,
    load_merge_queue,
    process_merge_queue,
)
from ccpm.orchestrator.reconcile import reconcile_state
from ccpm.orchestrator.runner import run_orchestrator
from ccpm.orchestrator.state import load_state, save_state
from ccpm.orchestrator.workers import (
    TaskBatchPlan,
    TaskScope,
    TaskSpec,
    WorkerPromptBundle,
    WorkerStatus,
    build_worker_prompt_bundle,
    detect_scope_conflicts,
    parse_worker_output,
    plan_task_batches,
    spawn_workers,
    write_worker_status,
)

__all__ = [
    "load_config",
    "load_state",
    "load_merge_queue",
    "reconcile_state",
    "process_merge_queue",
    "run_orchestrator",
    "save_state",
    "enqueue_ready_branches",
    "MergeGateOutcome",
    "MergeGateResult",
    "MergeOperationResult",
    "MergeQueue",
    "MergeQueueEntry",
    "RemediationRequest",
    "TaskBatchPlan",
    "TaskScope",
    "TaskSpec",
    "TestOperationResult",
    "WorkerPromptBundle",
    "WorkerStatus",
    "build_worker_prompt_bundle",
    "detect_scope_conflicts",
    "parse_worker_output",
    "plan_task_batches",
    "spawn_workers",
    "write_worker_status",
]
