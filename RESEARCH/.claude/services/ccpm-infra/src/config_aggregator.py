#!/usr/bin/env python3
"""
CCPM Config Aggregator

Fetches and aggregates CCPM configurations from multiple GitHub repositories.
"""

import asyncio
import base64
import json
import logging
import re
from typing import Any, Dict, List, Optional

import aiohttp
import yaml

logger = logging.getLogger(__name__)


class CCPMConfigAggregator:
    """
    Aggregates CCPM configurations from multiple GitHub repositories.

    Fetches .claude/ directory contents including:
    - commands/
    - skills/ (from CLAUDE.md or settings)
    - rules/
    - settings.json
    """

    GITHUB_API_BASE = "https://api.github.com"

    def __init__(self, github_token: str):
        """
        Initialize the aggregator.

        Args:
            github_token: GitHub personal access token for API access
        """
        self.github_token = github_token
        self.headers = {
            "Accept": "application/vnd.github.v3+json",
            "Authorization": f"token {github_token}" if github_token else "",
            "X-GitHub-Api-Version": "2022-11-28"
        }

    async def aggregate(self, repos: List[Dict[str, str]]) -> Dict[str, Any]:
        """
        Aggregate configs from all specified repositories.

        Args:
            repos: List of repo configs with 'owner' and 'repo' keys

        Returns:
            Dictionary mapping repo names to their CCPM configs
        """
        configs = {}

        async with aiohttp.ClientSession(headers=self.headers) as session:
            tasks = [
                self._fetch_repo_config(session, repo)
                for repo in repos
            ]
            results = await asyncio.gather(*tasks, return_exceptions=True)

            for repo, result in zip(repos, results):
                repo_name = f"{repo['owner']}/{repo['repo']}"
                if isinstance(result, Exception):
                    logger.error(f"Failed to fetch config from {repo_name}: {result}")
                    configs[repo_name] = {"error": str(result)}
                else:
                    configs[repo_name] = result

        return configs

    async def _fetch_repo_config(
        self,
        session: aiohttp.ClientSession,
        repo: Dict[str, str]
    ) -> Dict[str, Any]:
        """
        Fetch CCPM configuration from a single repository.
        """
        owner = repo["owner"]
        repo_name = repo["repo"]
        branch = repo.get("branch", "main")

        config = {
            "owner": owner,
            "repo": repo_name,
            "branch": branch,
            "commands": [],
            "skills": [],
            "rules": [],
            "settings": {}
        }

        # Fetch commands
        commands = await self._fetch_directory(
            session, owner, repo_name, ".claude/commands", branch
        )
        config["commands"] = await self._parse_commands(session, owner, repo_name, commands, branch)

        # Fetch rules
        rules = await self._fetch_directory(
            session, owner, repo_name, ".claude/rules", branch
        )
        config["rules"] = await self._parse_rules(session, owner, repo_name, rules, branch)

        # Fetch settings
        settings = await self._fetch_file(
            session, owner, repo_name, ".claude/settings.json", branch
        )
        if settings:
            try:
                config["settings"] = json.loads(settings)
            except json.JSONDecodeError:
                logger.warning(f"Invalid settings.json in {owner}/{repo_name}")

        # Extract skills from CLAUDE.md or settings
        config["skills"] = self._extract_skills(config)

        return config

    async def _fetch_directory(
        self,
        session: aiohttp.ClientSession,
        owner: str,
        repo: str,
        path: str,
        branch: str
    ) -> List[Dict[str, Any]]:
        """Fetch directory contents from GitHub API."""
        url = f"{self.GITHUB_API_BASE}/repos/{owner}/{repo}/contents/{path}"
        params = {"ref": branch}

        try:
            async with session.get(url, params=params) as response:
                if response.status == 404:
                    return []
                response.raise_for_status()
                return await response.json()
        except aiohttp.ClientError as e:
            logger.warning(f"Failed to fetch {path} from {owner}/{repo}: {e}")
            return []

    async def _fetch_file(
        self,
        session: aiohttp.ClientSession,
        owner: str,
        repo: str,
        path: str,
        branch: str
    ) -> Optional[str]:
        """Fetch file contents from GitHub API."""
        url = f"{self.GITHUB_API_BASE}/repos/{owner}/{repo}/contents/{path}"
        params = {"ref": branch}

        try:
            async with session.get(url, params=params) as response:
                if response.status == 404:
                    return None
                response.raise_for_status()
                data = await response.json()

                if data.get("encoding") == "base64":
                    return base64.b64decode(data["content"]).decode("utf-8")
                return data.get("content", "")
        except aiohttp.ClientError as e:
            logger.warning(f"Failed to fetch {path} from {owner}/{repo}: {e}")
            return None

    async def _parse_commands(
        self,
        session: aiohttp.ClientSession,
        owner: str,
        repo: str,
        files: List[Dict],
        branch: str
    ) -> List[Dict[str, Any]]:
        """Parse command files and extract metadata."""
        commands = []

        for file_info in files:
            if file_info["type"] == "dir":
                # Recurse into subdirectory
                subdir = await self._fetch_directory(
                    session, owner, repo, file_info["path"], branch
                )
                sub_commands = await self._parse_commands(
                    session, owner, repo, subdir, branch
                )
                commands.extend(sub_commands)
            elif file_info["name"].endswith(".md"):
                content = await self._fetch_file(
                    session, owner, repo, file_info["path"], branch
                )
                if content:
                    cmd = self._parse_command_file(file_info["name"], content)
                    cmd["path"] = file_info["path"]
                    commands.append(cmd)

        return commands

    def _parse_command_file(self, filename: str, content: str) -> Dict[str, Any]:
        """Extract command metadata from markdown file."""
        name = filename.replace(".md", "")

        # Try to extract description from first line or heading
        description = ""
        lines = content.split("\n")
        for line in lines:
            line = line.strip()
            if line.startswith("# "):
                description = line[2:].strip()
                break
            elif line and not line.startswith("#") and not line.startswith("---"):
                description = line[:100]
                break

        # Check for frontmatter
        frontmatter = {}
        if content.startswith("---"):
            try:
                end = content.index("---", 3)
                fm_content = content[3:end]
                frontmatter = yaml.safe_load(fm_content) or {}
            except (ValueError, yaml.YAMLError):
                pass

        return {
            "name": name,
            "description": frontmatter.get("description", description),
            "usage": frontmatter.get("usage", ""),
            "triggers": self._extract_triggers(content)
        }

    def _extract_triggers(self, content: str) -> List[str]:
        """Extract trigger patterns from command content."""
        triggers = []

        # Look for /command patterns
        pattern = r'/([a-zA-Z][a-zA-Z0-9_:-]*)'
        matches = re.findall(pattern, content)
        triggers.extend([f"/{m}" for m in matches[:5]])  # Limit to 5

        return list(set(triggers))

    async def _parse_rules(
        self,
        session: aiohttp.ClientSession,
        owner: str,
        repo: str,
        files: List[Dict],
        branch: str
    ) -> List[Dict[str, Any]]:
        """Parse rule files."""
        rules = []

        for file_info in files:
            if file_info["type"] == "file" and file_info["name"].endswith(".md"):
                rules.append({
                    "name": file_info["name"].replace(".md", ""),
                    "path": file_info["path"]
                })

        return rules

    def _extract_skills(self, config: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Extract skills from commands or settings."""
        skills = []

        # Skills can be inferred from command paths like pm/deploy.md -> pm:deploy
        for cmd in config.get("commands", []):
            path = cmd.get("path", "")
            if "/" in path:
                # Extract skill prefix from path
                parts = path.split("/")
                if len(parts) >= 3:  # .claude/commands/pm/deploy.md
                    skill_prefix = parts[-2]
                    skill_name = f"{skill_prefix}:{cmd['name']}"
                    skills.append({
                        "name": skill_name,
                        "command": cmd["name"]
                    })

        return skills


# Convenience function for standalone usage
async def main():
    """Test the aggregator."""
    import os

    token = os.getenv("GITHUB_TOKEN", "")
    aggregator = CCPMConfigAggregator(token)

    repos = [
        {"owner": "elysenko", "repo": "ccpm"},
    ]

    configs = await aggregator.aggregate(repos)
    print(json.dumps(configs, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
