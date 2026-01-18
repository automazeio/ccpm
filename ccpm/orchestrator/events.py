from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def events_path(base_dir: Path | str | None = None) -> Path:
    base = Path(base_dir) if base_dir is not None else Path.cwd()
    return base / ".claude" / "orchestrator" / "events.ndjson"


@dataclass(frozen=True)
class EventLogger:
    base_dir: Path | str | None = None

    def _path(self) -> Path:
        return events_path(self.base_dir)

    def _write(self, payload: Mapping[str, Any]) -> None:
        path = self._path()
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            json.dump(payload, handle, sort_keys=True)
            handle.write("\n")

    def log(self, event: str, payload: Mapping[str, Any]) -> None:
        record = {"event": event, "timestamp": _utc_now()}
        record.update(payload)
        self._write(record)

    def log_transition(
        self,
        *,
        kind: str,
        to_state: str,
        from_state: str | None = None,
        subject: str | None = None,
        metadata: Mapping[str, Any] | None = None,
    ) -> None:
        payload: dict[str, Any] = {
            "kind": kind,
            "to": to_state,
        }
        if from_state:
            payload["from"] = from_state
        if subject:
            payload["subject"] = subject
        if metadata:
            payload["metadata"] = dict(metadata)
        self.log("transition", payload)

    def log_retry(
        self,
        *,
        step: str,
        classification: str,
        counters: Mapping[str, Any],
    ) -> None:
        self.log(
            "retry",
            {
                "step": step,
                "classification": classification,
                "counters": dict(counters),
            },
        )

    def log_merge(
        self,
        *,
        branch: str,
        status: str,
        integration_branch: str | None = None,
        task_id: str | None = None,
        details: str | None = None,
    ) -> None:
        payload: dict[str, Any] = {"branch": branch, "status": status}
        if integration_branch:
            payload["integration_branch"] = integration_branch
        if task_id:
            payload["task_id"] = task_id
        if details:
            payload["details"] = details
        self.log("merge", payload)

    def log_test_result(
        self,
        *,
        lane: str,
        status: str,
        branch: str | None = None,
        message: str | None = None,
    ) -> None:
        payload: dict[str, Any] = {"lane": lane, "status": status}
        if branch:
            payload["branch"] = branch
        if message:
            payload["message"] = message
        self.log("test_result", payload)

    def log_escalation(
        self,
        *,
        classification: str,
        step: str,
        retry_counters: Mapping[str, Any],
        remediation: list[Mapping[str, Any]],
        message: str | None = None,
    ) -> None:
        payload: dict[str, Any] = {
            "classification": classification,
            "step": step,
            "retry_counters": dict(retry_counters),
            "remediation": [dict(item) for item in remediation],
        }
        if message:
            payload["message"] = message
        self.log("escalation", payload)
