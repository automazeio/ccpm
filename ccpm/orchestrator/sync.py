from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping

from ccpm.orchestrator.config import OrchestratorConfig


ISSUE_URL_RE = re.compile(r"https://github.com/[^/]+/[^/]+/issues/(?P<number>\d+)")
ISSUE_REF_RE = re.compile(r"#(?P<number>\d+)")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_issue_number(value: str | None) -> int | None:
    if not value:
        return None
    match = ISSUE_URL_RE.search(value)
    if match:
        return int(match.group("number"))
    match = ISSUE_REF_RE.search(value)
    if match:
        return int(match.group("number"))
    return None


def _read_frontmatter(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    content = path.read_text(encoding="utf-8")
    if not content.startswith("---"):
        return {}
    lines = content.splitlines()
    frontmatter: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        frontmatter[key.strip()] = value.strip()
    return frontmatter


def _remote_repo_slug(base_dir: Path) -> str | None:
    completed = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        check=True,
        capture_output=True,
        text=True,
        cwd=base_dir,
    )
    remote_url = completed.stdout.strip()
    if not remote_url:
        return None
    repo = re.sub(r"^https://github\.com/", "", remote_url)
    repo = re.sub(r"^git@github\.com:", "", repo)
    repo = re.sub(r"^ssh://git@github\.com/", "", repo)
    repo = re.sub(r"^ssh://github\.com/", "", repo)
    repo = re.sub(r"\.git$", "", repo)
    return repo or None


def _guard_template_repo(remote_url: str) -> None:
    if "automazeio/ccpm" in remote_url:
        raise RuntimeError(
            "Refusing to operate on the CCPM template repository (automazeio/ccpm)."
        )


@dataclass(frozen=True)
class GitHubClient:
    base_dir: Path
    gh_bin: str = "gh"

    def _ensure_repo(self) -> str:
        completed = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            check=True,
            capture_output=True,
            text=True,
            cwd=self.base_dir,
        )
        remote_url = completed.stdout.strip()
        _guard_template_repo(remote_url)
        repo = _remote_repo_slug(self.base_dir)
        if not repo:
            raise RuntimeError("Unable to determine GitHub repository from git remote.")
        return repo

    def comment_issue(self, issue_number: int, body: str) -> None:
        repo = self._ensure_repo()
        body_path = self.base_dir / ".claude" / "orchestrator" / "tmp-comment.md"
        body_path.parent.mkdir(parents=True, exist_ok=True)
        body_path.write_text(body, encoding="utf-8")
        subprocess.run(
            [
                self.gh_bin,
                "issue",
                "comment",
                str(issue_number),
                "--repo",
                repo,
                "--body-file",
                str(body_path),
            ],
            check=True,
            capture_output=True,
            text=True,
            cwd=self.base_dir,
        )


@dataclass
class SyncCoordinator:
    config: OrchestratorConfig
    base_dir: Path
    gh: GitHubClient

    @classmethod
    def from_config(
        cls,
        config: OrchestratorConfig,
        base_dir: Path,
    ) -> "SyncCoordinator":
        return cls(config=config, base_dir=base_dir, gh=GitHubClient(base_dir))

    def _sync_mode(self) -> str:
        return str(self.config.get("sync", {}).get("mode", "event_and_periodic"))

    def _post_level(self) -> str:
        return str(self.config.get("sync", {}).get("post_level", "epic_summary"))

    def _periodic_minutes(self) -> int:
        return int(self.config.get("sync", {}).get("periodic_minutes", 30))

    def _issue_number_for_task(
        self, state: Mapping[str, Any], task_id: str | None, metadata: Mapping[str, Any]
    ) -> int | None:
        if task_id:
            mapping = (state.get("issue_map") or {}).get(task_id)
            if isinstance(mapping, Mapping):
                number = _parse_issue_number(str(mapping.get("issue_url") or mapping.get("github") or ""))
                if number is None and mapping.get("issue_number"):
                    return int(mapping["issue_number"])
                if number is not None:
                    return number
            if isinstance(mapping, str):
                number = _parse_issue_number(mapping)
                if number is not None:
                    return number
        if metadata:
            number = _parse_issue_number(str(metadata.get("issue_url") or ""))
            if number is None and metadata.get("issue_number"):
                return int(metadata["issue_number"])
            if number is not None:
                return number
        return None

    def _epic_issue_number(self, epic_id: str | None) -> int | None:
        if not epic_id:
            return None
        epic_path = self.base_dir / ".claude" / "epics" / epic_id / "epic.md"
        frontmatter = _read_frontmatter(epic_path)
        return _parse_issue_number(frontmatter.get("github"))

    def post_issue_transition(
        self,
        *,
        issue_number: int,
        status: str,
        subject: str | None = None,
        details: str | None = None,
    ) -> None:
        lines = [
            "## Orchestrator update",
            f"- Status: **{status}**",
            f"- Timestamp: {_utc_now()}",
        ]
        if subject:
            lines.append(f"- Subject: {subject}")
        if details:
            lines.append(f"- Details: {details}")
        self.gh.comment_issue(issue_number, "\n".join(lines))

    def post_task_transition(
        self,
        *,
        state: Mapping[str, Any],
        task_id: str | None,
        metadata: Mapping[str, Any],
        status: str,
        details: str | None = None,
    ) -> bool:
        issue_number = self._issue_number_for_task(state, task_id, metadata)
        if issue_number is None:
            return False
        self.post_issue_transition(
            issue_number=issue_number,
            status=status,
            subject=task_id,
            details=details,
        )
        return True

    def post_epic_transition(
        self,
        *,
        epic_id: str | None,
        status: str,
        details: str | None = None,
    ) -> bool:
        issue_number = self._epic_issue_number(epic_id)
        if issue_number is None:
            return False
        self.post_issue_transition(
            issue_number=issue_number,
            status=status,
            subject=epic_id,
            details=details,
        )
        return True

    def maybe_post_epic_summary(self, state: dict[str, Any]) -> dict[str, Any]:
        if self._sync_mode() not in {"event_and_periodic", "periodic"}:
            return state
        if self._post_level() != "epic_summary":
            return state
        epic_id = state.get("active_epic")
        issue_number = self._epic_issue_number(epic_id)
        if issue_number is None:
            return state
        sync_state = dict(state.get("sync") or {})
        last_summary = sync_state.get("last_summary_at")
        if last_summary:
            try:
                last_time = datetime.fromisoformat(str(last_summary))
            except ValueError:
                last_time = None
        else:
            last_time = None
        interval = timedelta(minutes=self._periodic_minutes())
        if last_time and datetime.now(timezone.utc) - last_time < interval:
            return state
        summary_lines = [
            "## Epic summary",
            f"- Epic: {epic_id or 'unknown'}",
            f"- Phase: {state.get('phase')}",
            f"- Active issues: {', '.join(state.get('active_issue_ids') or []) or 'none'}",
            f"- Merge queue: {len(state.get('merge_queue') or [])}",
        ]
        last_error = state.get("last_error")
        if last_error:
            summary_lines.append(
                f"- Last error: {last_error.get('classification')} - {last_error.get('message')}"
            )
        summary_lines.append(f"- Timestamp: {_utc_now()}")
        self.gh.comment_issue(issue_number, "\n".join(summary_lines))
        sync_state["last_summary_at"] = _utc_now()
        updated = dict(state)
        updated["sync"] = sync_state
        return updated

    def post_escalation(
        self,
        *,
        state: Mapping[str, Any],
        classification: str,
        step: str,
        remediation: list[Mapping[str, Any]],
    ) -> bool:
        epic_id = state.get("active_epic")
        issue_number = self._epic_issue_number(epic_id)
        if issue_number is None:
            return False
        last_error = state.get("last_error") or {}
        lines = [
            "## Escalation required",
            f"- Epic: {epic_id or 'unknown'}",
            f"- Step: {step}",
            f"- Classification: {classification}",
            f"- Error: {last_error.get('message') or 'unknown'}",
            f"- Timestamp: {_utc_now()}",
            "",
            "### Retry counters",
        ]
        counters = state.get("retry_counters") or {}
        for key, value in counters.items():
            if key == "by_step":
                continue
            lines.append(f"- {key}: {value}")
        lines.append("")
        lines.append("### Remediation attempts")
        if remediation:
            for attempt in remediation:
                detail = ", ".join(
                    f"{key}={value}"
                    for key, value in attempt.items()
                    if value is not None
                )
                lines.append(f"- {detail}")
        else:
            lines.append("- None recorded")
        self.gh.comment_issue(issue_number, "\n".join(lines))
        return True

    def post_help_request(
        self,
        *,
        state: Mapping[str, Any],
        help_path: Path | str,
        reason: str,
        remediation: list[Mapping[str, Any]],
    ) -> bool:
        epic_id = state.get("active_epic")
        issue_number = self._epic_issue_number(epic_id)
        if issue_number is None:
            return False
        help_path_value = Path(help_path)
        try:
            help_display = str(help_path_value.relative_to(self.base_dir))
        except ValueError:
            help_display = str(help_path_value)
        last_error = state.get("last_error") or {}
        lines = [
            "## Orchestrator help request",
            f"- Epic: {epic_id or 'unknown'}",
            f"- Phase: {state.get('phase')}",
            f"- Reason: {reason}",
            f"- Last error: {last_error.get('message') or 'unknown'}",
            f"- Help file: `{help_display}`",
            f"- Timestamp: {_utc_now()}",
            "",
            "### Remediation attempts",
        ]
        if remediation:
            for attempt in remediation:
                detail = ", ".join(
                    f"{key}={value}"
                    for key, value in attempt.items()
                    if value is not None
                )
                lines.append(f"- {detail}")
        else:
            lines.append("- None recorded")
        self.gh.comment_issue(issue_number, "\n".join(lines))
        return True
