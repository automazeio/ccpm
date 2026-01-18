from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Optional

CHECKBOX_RE = re.compile(r"^- \[(?P<checked>[ xX])\]\s+(?P<rest>.+)$")
ISSUE_URL_RE = re.compile(r"https://github.com/[^/]+/[^/]+/issues/(?P<number>\d+)")
ISSUE_REF_RE = re.compile(r"#(?P<number>\d+)")


class RoadmapError(RuntimeError):
    pass


class RoadmapInvariantError(RoadmapError):
    def __init__(self, violations: Iterable[str]) -> None:
        self.violations = list(violations)
        message = "Roadmap invariants violated:\n" + "\n".join(
            f"- {violation}" for violation in self.violations
        )
        super().__init__(message)


@dataclass(frozen=True)
class EpicEntry:
    identifier: str
    summary: str
    checked: bool
    issue_number: Optional[int]
    issue_url: Optional[str]
    raw: str


@dataclass(frozen=True)
class RoadmapIssue:
    number: int
    title: str
    url: str
    body: str


class RoadmapService:
    def __init__(
        self,
        root: Path | str = ".",
        gh_bin: str = "gh",
        repo: Optional[str] = None,
        project_name: Optional[str] = None,
    ) -> None:
        self.root = Path(root)
        self.gh_bin = gh_bin
        self.repo = repo
        self.project_name = project_name

    def sync(self) -> RoadmapIssue:
        issue = self.find_or_create_issue()
        entries = self.parse_checklist(issue.body)
        self.enforce_invariants(entries)
        self.write_local_roadmap(issue.url, entries)
        return issue

    def close_epic(self, epic_identifier: str) -> RoadmapIssue:
        issue = self.find_or_create_issue()
        updated_body = self._mark_epic_checked(issue.body, epic_identifier)
        self._update_issue_body(issue.number, updated_body)
        refreshed = self._fetch_issue(issue.number)
        entries = self.parse_checklist(refreshed.body)
        self.enforce_invariants(entries)
        self.write_local_roadmap(refreshed.url, entries)
        return refreshed

    def find_or_create_issue(self) -> RoadmapIssue:
        self._ensure_repo_info()
        issues = self._list_roadmap_candidates()
        chosen = self._select_roadmap_issue(issues)
        if chosen is not None:
            return self._fetch_issue(chosen["number"])
        title = self._preferred_title()
        body = self._default_body()
        self._create_issue(title, body)
        issues = self._list_roadmap_candidates()
        chosen = self._select_roadmap_issue(issues)
        if chosen is None:
            raise RoadmapError("Failed to locate newly created roadmap issue")
        return self._fetch_issue(chosen["number"])

    def parse_checklist(self, body: str) -> list[EpicEntry]:
        entries: list[EpicEntry] = []
        for line in body.splitlines():
            match = CHECKBOX_RE.match(line.strip())
            if not match:
                continue
            checked = match.group("checked").lower() == "x"
            rest = match.group("rest").strip()
            identifier, summary = self._split_identifier(rest)
            issue_url, issue_number = self._extract_issue_reference(rest)
            entries.append(
                EpicEntry(
                    identifier=identifier,
                    summary=summary,
                    checked=checked,
                    issue_number=issue_number,
                    issue_url=issue_url,
                    raw=line,
                )
            )
        return entries

    def enforce_invariants(self, entries: Iterable[EpicEntry]) -> None:
        entries = list(entries)
        roadmap_ids = {entry.identifier for entry in entries}
        prd_ids = self._collect_prd_ids()
        epic_dirs = self._collect_epic_dirs()
        violations: list[str] = []

        missing_prds = sorted(roadmap_ids - prd_ids)
        missing_epics = sorted(roadmap_ids - epic_dirs)
        if missing_prds:
            violations.append(
                "Missing PRD files for epics: " + ", ".join(missing_prds)
            )
        if missing_epics:
            violations.append(
                "Missing epic directories for epics: " + ", ".join(missing_epics)
            )

        extra_prds = sorted(prd_ids - roadmap_ids)
        extra_epics = sorted(epic_dirs - roadmap_ids)
        if extra_prds:
            violations.append(
                "PRD files exist without roadmap entries: " + ", ".join(extra_prds)
            )
        if extra_epics:
            violations.append(
                "Epic directories exist without roadmap entries: "
                + ", ".join(extra_epics)
            )

        issue_map = self._collect_epic_issue_map(epic_dirs)
        for entry in entries:
            issue_number = issue_map.get(entry.identifier)
            if issue_number is None or entry.issue_number is None:
                continue
            if issue_number != entry.issue_number:
                violations.append(
                    "Epic issue mismatch for "
                    f"{entry.identifier}: roadmap #{entry.issue_number} vs epic #{issue_number}"
                )

        if violations:
            raise RoadmapInvariantError(violations)

    def write_local_roadmap(self, issue_url: str, entries: Iterable[EpicEntry]) -> None:
        target = self.root / ".claude" / "roadmap.md"
        target.parent.mkdir(parents=True, exist_ok=True)
        existing_frontmatter = self._read_frontmatter(target)
        created = existing_frontmatter.get("created") or self._timestamp()
        updated = self._timestamp()
        lines = [
            "---",
            "name: roadmap",
            "status: active",
            f"created: {created}",
            f"updated: {updated}",
            f"github_issue: {issue_url}",
            "---",
            "",
            "# Roadmap",
            "",
            "## Epics",
        ]
        for entry in entries:
            checkbox = "x" if entry.checked else " "
            summary = f" — {entry.summary}" if entry.summary else ""
            issue_ref = ""
            if entry.issue_url:
                issue_ref = f" ({entry.issue_url})"
            elif entry.issue_number:
                issue_ref = f" (#{entry.issue_number})"
            lines.append(f"- [{checkbox}] {entry.identifier}{summary}{issue_ref}")
        lines.append("")
        target.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _mark_epic_checked(self, body: str, epic_identifier: str) -> str:
        updated_lines = []
        found = False
        for line in body.splitlines():
            stripped = line.strip()
            match = CHECKBOX_RE.match(stripped)
            if match:
                rest = match.group("rest").strip()
                identifier, _summary = self._split_identifier(rest)
                if identifier == epic_identifier:
                    updated_lines.append(
                        line.replace(match.group(0), f"- [x] {rest}")
                    )
                    found = True
                    continue
            updated_lines.append(line)
        if not found:
            raise RoadmapError(f"Epic '{epic_identifier}' not found in roadmap")
        return "\n".join(updated_lines)

    def _update_issue_body(self, number: int, body: str) -> None:
        self._run_gh("issue", "edit", str(number), "--body", body)

    def _list_roadmap_candidates(self) -> list[dict[str, object]]:
        output = self._run_gh(
            "issue",
            "list",
            "--state",
            "all",
            "--search",
            "in:title Roadmap",
            "--json",
            "number,title,url",
            "--limit",
            "200",
        )
        return json.loads(output) if output else []

    def _select_roadmap_issue(
        self, issues: Iterable[dict[str, object]]
    ) -> Optional[dict[str, object]]:
        preferred_titles = [
            "Roadmap",
            self._preferred_title(),
        ]
        normalized = [title.lower() for title in preferred_titles if title]
        for issue in issues:
            title = str(issue.get("title", ""))
            if title.lower() in normalized:
                return issue
        for issue in issues:
            title = str(issue.get("title", ""))
            if title.lower().startswith("roadmap"):
                return issue
        return None

    def _preferred_title(self) -> str:
        if self.project_name:
            return f"Roadmap: {self.project_name}"
        return "Roadmap"

    def _default_body(self) -> str:
        return "".join(
            [
                "# Roadmap\n\n",
                "## Epics\n",
                "- [ ] example-epic — short summary\n",
                "\n",
                "(Edit this issue to add or remove epic checklist items.)\n",
            ]
        )

    def _create_issue(self, title: str, body: str) -> None:
        self._run_gh("issue", "create", "--title", title, "--body", body)

    def _fetch_issue(self, number: int) -> RoadmapIssue:
        output = self._run_gh(
            "issue",
            "view",
            str(number),
            "--json",
            "number,title,url,body",
        )
        data = json.loads(output)
        return RoadmapIssue(
            number=int(data["number"]),
            title=str(data["title"]),
            url=str(data["url"]),
            body=str(data.get("body", "")),
        )

    def _run_gh(self, *args: str) -> str:
        cmd = [self.gh_bin, *args]
        completed = subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout.strip()

    def _ensure_repo_info(self) -> None:
        if self.repo and self.project_name:
            return
        output = self._run_gh("repo", "view", "--json", "nameWithOwner,name")
        data = json.loads(output)
        self.repo = data.get("nameWithOwner")
        self.project_name = data.get("name")

    def _split_identifier(self, rest: str) -> tuple[str, str]:
        for separator in (" — ", " – ", " - "):
            if separator in rest:
                identifier, summary = rest.split(separator, 1)
                return identifier.strip(), summary.strip()
        return rest.strip(), ""

    def _extract_issue_reference(self, text: str) -> tuple[Optional[str], Optional[int]]:
        url_match = ISSUE_URL_RE.search(text)
        if url_match:
            number = int(url_match.group("number"))
            return url_match.group(0), number
        ref_match = ISSUE_REF_RE.search(text)
        if ref_match:
            return None, int(ref_match.group("number"))
        return None, None

    def _collect_prd_ids(self) -> set[str]:
        prd_dir = self.root / ".claude" / "prds"
        if not prd_dir.exists():
            return set()
        return {path.stem for path in prd_dir.glob("*.md")}

    def _collect_epic_dirs(self) -> set[str]:
        epic_dir = self.root / ".claude" / "epics"
        if not epic_dir.exists():
            return set()
        return {path.name for path in epic_dir.iterdir() if path.is_dir()}

    def _collect_epic_issue_map(self, epic_ids: Iterable[str]) -> dict[str, int]:
        issue_map: dict[str, int] = {}
        for epic_id in epic_ids:
            epic_path = self.root / ".claude" / "epics" / epic_id / "epic.md"
            frontmatter = self._read_frontmatter(epic_path)
            github_url = frontmatter.get("github")
            if github_url:
                match = ISSUE_URL_RE.search(github_url)
                if match:
                    issue_map[epic_id] = int(match.group("number"))
        return issue_map

    def _read_frontmatter(self, path: Path) -> dict[str, str]:
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

    def _timestamp(self) -> str:
        return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
