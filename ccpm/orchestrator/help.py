from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping

from ccpm.orchestrator.events import events_path


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _help_timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _read_recent_events(path: Path, limit: int = 10) -> list[Mapping[str, Any]]:
    if not path.exists():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    recent = lines[-limit:] if limit > 0 else lines
    entries: list[Mapping[str, Any]] = []
    for line in recent:
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(payload, Mapping):
            entries.append(payload)
    return entries


def _summarize_remediation(remediation: Iterable[Mapping[str, Any]]) -> list[str]:
    summary = []
    for attempt in remediation:
        detail = ", ".join(
            f"{key}={value}"
            for key, value in attempt.items()
            if value is not None
        )
        if detail:
            summary.append(detail)
    return summary


def _proposed_next_actions(
    classification: str | None,
    remediation: Iterable[Mapping[str, Any]],
) -> list[str]:
    remediation_summary = _summarize_remediation(remediation)
    if classification == "conflict":
        actions = [
            "Resolve merge conflicts on the affected branch(es) and update the integration branch.",
            "Re-run the merge gate after conflicts are resolved.",
        ]
    elif classification == "verification":
        actions = [
            "Inspect failing test logs for the reported lane.",
            "Fix test failures and re-run the gate/full test lanes.",
        ]
    else:
        actions = [
            "Review the latest error message and event log entries.",
            "Apply the fix and retry the orchestration step.",
        ]
    if remediation_summary:
        actions.append("Review remediation attempts: " + "; ".join(remediation_summary) + ".")
    actions.append("Confirm orchestrator state is updated before resuming.")
    return actions


def write_help_request(
    *,
    state: Mapping[str, Any],
    base_dir: Path,
    remediation: Iterable[Mapping[str, Any]] = (),
    reason: str | None = None,
) -> tuple[Path, str]:
    timestamp = _help_timestamp()
    help_dir = base_dir / ".claude" / "orchestrator" / "help"
    help_dir.mkdir(parents=True, exist_ok=True)
    path = help_dir / f"{timestamp}.md"
    last_error = state.get("last_error")
    recent_events = _read_recent_events(events_path(base_dir))
    classification = None
    if isinstance(last_error, Mapping):
        classification = str(last_error.get("classification") or "")
    actions = _proposed_next_actions(classification, remediation)
    lines = [
        "# Orchestrator help request",
        f"- Timestamp: {_utc_now()}",
        f"- Reason: {reason or 'retry_exhausted'}",
        f"- Phase: {state.get('phase')}",
        "",
        "## Current state snapshot",
        "```json",
        json.dumps(state, indent=2, sort_keys=True),
        "```",
        "",
        "## Last error logs",
        "```json",
        json.dumps(
            {"last_error": last_error, "recent_events": recent_events},
            indent=2,
            sort_keys=True,
        ),
        "```",
        "",
        "## Proposed next actions",
    ]
    for action in actions:
        lines.append(f"- {action}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path, timestamp
