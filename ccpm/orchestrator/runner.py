from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping

from ccpm.orchestrator.config import OrchestratorConfig, load_config
from ccpm.orchestrator.events import EventLogger
from ccpm.orchestrator.reconcile import ReconcileResult, reconcile_state
from ccpm.orchestrator.state import OrchestratorState, load_state, save_state
from ccpm.orchestrator.sync import SyncCoordinator


PHASES = (
    "bootstrap",
    "roadmap",
    "prd",
    "epic",
    "tasks",
    "sync",
    "parallel_execution",
    "integration",
    "closeout",
    "complete",
)

PHASE_TRANSITIONS = {
    "bootstrap": "roadmap",
    "roadmap": "prd",
    "prd": "epic",
    "epic": "tasks",
    "tasks": "sync",
    "sync": "parallel_execution",
    "parallel_execution": "integration",
    "integration": "closeout",
    "closeout": "complete",
}


@dataclass(frozen=True)
class RunnerResult:
    state: dict[str, Any]
    halted: bool
    reason: str | None


def _kill_switch_path(config: OrchestratorConfig, base_dir: Path) -> Path:
    kill_switch = config.get("safety", {}).get("kill_switch_file", ".claude/orchestrator/STOP")
    return base_dir / kill_switch


def _should_halt(config: OrchestratorConfig, base_dir: Path) -> bool:
    return _kill_switch_path(config, base_dir).exists()


def _apply_transition(state: dict[str, Any], next_phase: str) -> dict[str, Any]:
    state["phase"] = next_phase
    state.setdefault("transitions", []).append(next_phase)
    return state


def _run_bootstrap(
    base_dir: Path,
    state: dict[str, Any],
) -> ReconcileResult:
    return reconcile_state(base_dir=base_dir, state=state)


def _advance_phase(state: dict[str, Any]) -> str:
    current = state.get("phase") or "bootstrap"
    if current not in PHASE_TRANSITIONS:
        return "complete"
    return PHASE_TRANSITIONS[current]


def run_orchestrator(
    base_dir: Path | str | None = None,
    config: OrchestratorConfig | None = None,
    state: OrchestratorState | None = None,
    on_transition: Callable[[dict[str, Any]], None] | None = None,
) -> RunnerResult:
    base = Path(base_dir) if base_dir is not None else Path.cwd()
    resolved_config = config or load_config(base)
    resolved_state = state or load_state(base)
    state_data = dict(resolved_state.data)
    event_logger = EventLogger(base)
    syncer = SyncCoordinator.from_config(resolved_config, base)

    if _should_halt(resolved_config, base):
        state_data["halted"] = True
        state_data["halt_reason"] = "kill_switch"
        save_state(state_data, base)
        return RunnerResult(state=state_data, halted=True, reason="kill_switch")

    halted = False
    reason: str | None = None

    while state_data.get("phase") != "complete":
        if _should_halt(resolved_config, base):
            halted = True
            reason = "kill_switch"
            state_data["halted"] = True
            state_data["halt_reason"] = reason
            save_state(state_data, base)
            break

        current_phase = state_data.get("phase") or "bootstrap"
        if current_phase == "bootstrap":
            reconcile_result = _run_bootstrap(base, state_data)
            state_data = reconcile_result.state

        next_phase = _advance_phase(state_data)
        state_data = _apply_transition(state_data, next_phase)
        event_logger.log_transition(
            kind="phase",
            from_state=current_phase,
            to_state=next_phase,
            metadata={
                "active_epic": state_data.get("active_epic"),
                "active_issue_ids": state_data.get("active_issue_ids"),
            },
        )
        state_data = syncer.maybe_post_epic_summary(state_data)
        save_state(state_data, base)

        if on_transition:
            on_transition(state_data)

    if state_data.get("phase") == "complete":
        save_state(state_data, base)

    return RunnerResult(state=state_data, halted=halted, reason=reason)
