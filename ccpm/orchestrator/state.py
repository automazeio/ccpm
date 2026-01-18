from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping


STATE_VERSION = 1


@dataclass(frozen=True)
class OrchestratorState:
    data: dict[str, Any]

    def get(self, key: str, default: Any | None = None) -> Any:
        return self.data.get(key, default)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _default_retry_counters() -> dict[str, Any]:
    return {
        "transient": 0,
        "invariant": 0,
        "conflict": 0,
        "verification": 0,
        "spec": 0,
        "by_step": {},
    }


def default_state() -> dict[str, Any]:
    return {
        "version": STATE_VERSION,
        "phase": "bootstrap",
        "active_epic": None,
        "active_issue_ids": [],
        "issue_map": {},
        "workers": {},
        "merge_queue": [],
        "retry_counters": _default_retry_counters(),
        "last_error": None,
        "timestamps": {"created_at": _utc_now(), "updated_at": _utc_now()},
        "halted": False,
        "halt_reason": None,
    }


def _merge_state(base: Mapping[str, Any], override: Mapping[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in override.items():
        if isinstance(value, Mapping) and isinstance(merged.get(key), Mapping):
            merged[key] = _merge_state(merged[key], value)
        else:
            merged[key] = value
    return merged


def state_path(base_dir: Path | str | None = None) -> Path:
    base = Path(base_dir) if base_dir is not None else Path.cwd()
    return base / ".claude" / "orchestrator" / "state.json"


def load_state(base_dir: Path | str | None = None) -> OrchestratorState:
    path = state_path(base_dir)
    if not path.exists():
        return OrchestratorState(default_state())
    with path.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)
    merged = _merge_state(default_state(), raw if isinstance(raw, Mapping) else {})
    return OrchestratorState(merged)


def save_state(state: Mapping[str, Any], base_dir: Path | str | None = None) -> Path:
    path = state_path(base_dir)
    path.parent.mkdir(parents=True, exist_ok=True)
    updated = dict(state)
    timestamps = dict(updated.get("timestamps") or {})
    if "created_at" not in timestamps:
        timestamps["created_at"] = _utc_now()
    timestamps["updated_at"] = _utc_now()
    updated["timestamps"] = timestamps
    with path.open("w", encoding="utf-8") as handle:
        json.dump(updated, handle, indent=2, sort_keys=True)
        handle.write("\n")
    return path


def increment_retry(
    state: dict[str, Any], step: str, classification: str
) -> dict[str, Any]:
    counters = dict(state.get("retry_counters") or {})
    if classification not in counters:
        counters[classification] = 0
    counters[classification] = counters.get(classification, 0) + 1
    by_step = dict(counters.get("by_step") or {})
    step_entry = dict(by_step.get(step) or {})
    step_entry[classification] = step_entry.get(classification, 0) + 1
    by_step[step] = step_entry
    counters["by_step"] = by_step
    state["retry_counters"] = counters
    return state


def record_error(
    state: dict[str, Any],
    step: str,
    classification: str,
    message: str,
) -> dict[str, Any]:
    state["last_error"] = {
        "step": step,
        "classification": classification,
        "message": message,
        "timestamp": _utc_now(),
    }
    return increment_retry(state, step, classification)
