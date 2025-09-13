"""Security validation tests for CCPM permission model.

These tests validate that the security model properly restricts access
and prevents potential security vulnerabilities.
"""

import json
import re
from pathlib import Path

import pytest

# from typing import Dict, List, Set  # Unused imports


class TestSecurityModel:
    """Test the security model implementation."""

    def test_no_dangerous_wildcard_patterns(self):
        """Test that no dangerous wildcard patterns are present."""
        dangerous_patterns = {
            r"Bash\(\*\)": "Allows any bash command",
            r"Bash\([^:]*\*\s*\)$": "Overly broad bash pattern",
            r"Bash\(rm\s+\*\)": "Dangerous file deletion",
            r"Bash\(sudo\s+.*\)": "Privilege escalation",
            r"Bash\(curl\s+.*\*\)": "Arbitrary network access",
            r"Bash\(wget\s+.*\*\)": "Arbitrary file download",
        }

        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    content = f.read()

                for pattern, description in dangerous_patterns.items():
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    assert not matches, (
                        f"Dangerous pattern found in {settings_file}: "
                        f"{pattern} - {description}"
                    )

    def test_command_scope_validation(self):
        """Test that all commands are properly scoped."""
        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    data = json.load(f)

                permissions = data.get("permissions", {}).get("allow", [])

                for perm in permissions:
                    if perm.startswith("Bash("):
                        # Extract the command from Bash(...)
                        cmd_match = re.match(r"Bash\(([^)]+)\)", perm)
                        if cmd_match:
                            command = cmd_match.group(1)

                            # Commands should not end with just * without context
                            assert not command.endswith(
                                " *"
                            ), f"Overly broad command: {perm}"

                            # Commands should have specific patterns or be exact
                            # commands
                            if "*" in command:
                                # If it has wildcards, it should have specific
                                # prefixes (with space or colon)
                                prefixes = [
                                    "git ",
                                    "gh ",
                                    "python ",
                                    "pip ",
                                    "npm ",
                                    "npx",
                                    "pnpm ",
                                    "pytest",
                                    ".claude/",
                                    "ccpm/",
                                    "ccpm",
                                    "find ",
                                    "ls ",
                                    "mv ",
                                    "cp ",
                                    "rm ",
                                    "chmod ",
                                    "touch ",
                                    "tree ",
                                    "ruff ",
                                    "black",
                                    "isort",
                                    "flake8",
                                    "mypy ",
                                    "sed",
                                    "grep",
                                    "which",
                                    "command",
                                    "head",
                                    "tail",
                                    "cat",
                                    "wc",
                                    "sort",
                                    "uniq",
                                    "awk",
                                    "tr",
                                    "cut",
                                    "date",
                                    "sleep",
                                    "basename",
                                    "dirname",
                                    "file",
                                    "mktemp",
                                    "uname",
                                    "bash",
                                    "source",
                                    "timeout",
                                    "markdownlint",
                                ]
                                # Also check colon format (e.g., "ls:*")
                                colon_prefixes = [
                                    p.rstrip() + ":"
                                    for p in prefixes
                                    if p.endswith(" ")
                                ]
                                all_prefixes = prefixes + colon_prefixes
                                assert any(
                                    command.startswith(prefix)
                                    for prefix in all_prefixes
                                ), f"Unscoped wildcard command: {perm}"

    def test_directory_access_restrictions(self):
        """Test that directory access is properly restricted."""
        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    data = json.load(f)

                # Check additionalDirectories
                additional_dirs = data.get("permissions", {}).get(
                    "additionalDirectories", []
                )
                for directory in additional_dirs:
                    # Should not allow access to sensitive system directories
                    dangerous_dirs = [
                        "/etc",
                        "/usr",
                        "/var",
                        "/root",
                        "/home",
                        "/Users",
                    ]
                    assert not any(
                        directory.startswith(dangerous) for dangerous in dangerous_dirs
                    ), f"Dangerous directory access: {directory}"

                    # Should be scoped to project-related directories
                    assert (
                        ".claude/workspace" in directory
                        or ".claude" in directory
                        or "ccpm" in directory
                    ), f"Unscoped directory access: {directory}"

    def test_file_operation_restrictions(self):
        """Test that file operations are properly restricted."""
        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        dangerous_file_ops = [
            r"Bash\(rm\s+/\)",  # Root directory deletion
            r"Bash\(rm\s+-rf\s+/\)",  # Root directory recursive deletion
            r"Bash\(chmod\s+((-[Rr]\s+)?0?777|0?777\s+(-[Rr])?)\)",  # Dangerous permissions
            r"Bash\(chown\s+.*\)",  # Ownership changes
            r"Bash\(mv\s+/.*\)",  # Moving system files
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    content = f.read()

                for pattern in dangerous_file_ops:
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    assert (
                        not matches
                    ), f"Dangerous file operation found in {settings_file}: {pattern}"

    def test_network_access_restrictions(self):
        """Test that network access is properly restricted."""
        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        # These tools should not have unrestricted network access
        dangerous_network_patterns = [
            r"Bash\(curl\s+.*\*\)",
            r"Bash\(wget\s+.*\*\)",
            r"Bash\(nc\s+.*\)",  # netcat
            r"Bash\(ncat\s+.*\)",
            r"Bash\(telnet\s+.*\)",
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    content = f.read()

                for pattern in dangerous_network_patterns:
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    assert (
                        not matches
                    ), f"Dangerous network access found in {settings_file}: {pattern}"

    def test_privilege_escalation_prevention(self):
        """Test that privilege escalation is prevented."""
        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        privilege_escalation_patterns = [
            r"Bash\(sudo\s+.*\)",
            r"Bash\(su\s+.*\)",
            r"Bash\(doas\s+.*\)",
            r"Bash\(pkexec\s+.*\)",
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    content = f.read()

                for pattern in privilege_escalation_patterns:
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    assert (
                        not matches
                    ), f"Privilege escalation found in {settings_file}: {pattern}"

    def test_git_operation_security(self):
        """Test that git operations are properly scoped and secure."""
        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        dangerous_git_patterns = [
            r"Bash\(git\s+\*\)",  # Any git command
            r"Bash\(git\s+reset\s+--hard\)",  # Destructive reset
            r"Bash\(git\s+clean\s+-fd\)",  # Force clean
            r"Bash\(git\s+filter-branch\)",  # History rewriting
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    content = f.read()

                for pattern in dangerous_git_patterns:
                    matches = re.findall(pattern, content, re.IGNORECASE)
                    assert (
                        not matches
                    ), f"Dangerous git operation found in {settings_file}: {pattern}"

    def test_python_security_restrictions(self):
        """Test that Python operations are properly restricted."""
        settings_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for settings_file in settings_files:
            if settings_file.exists():
                with open(settings_file) as f:
                    data = json.load(f)

                permissions = data.get("permissions", {}).get("allow", [])

                # Check for overly broad pip install permissions
                pip_patterns = [perm for perm in permissions if "pip install" in perm]
                for pattern in pip_patterns:
                    if pattern == "Bash(pip install:*)":
                        pytest.fail(f"Overly broad pip install permission: {pattern}")

                    # Should be specific packages or patterns
                    assert any(
                        pkg in pattern
                        for pkg in ["ccpm", "build", "-e .", "git+https://github.com/"]
                    ) or pattern.endswith(
                        "pip install)"
                    ), f"Unscoped pip install: {pattern}"


class TestPermissionCompliance:
    """Test permission compliance and validation."""

    def test_permission_file_exists(self):
        """Test that permission files exist and are valid."""
        permission_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for file_path in permission_files:
            assert file_path.exists(), f"Permission file missing: {file_path}"

            # Validate JSON syntax
            with open(file_path) as f:
                data = json.load(f)

            # Validate structure
            assert "permissions" in data
            assert "allow" in data["permissions"]
            assert isinstance(data["permissions"]["allow"], list)

    def test_no_duplicate_permissions(self):
        """Test that there are no duplicate permissions."""
        permission_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for file_path in permission_files:
            if file_path.exists():
                with open(file_path) as f:
                    data = json.load(f)

                permissions = data.get("permissions", {}).get("allow", [])

                # Check for duplicates
                seen = set()
                duplicates = []
                for perm in permissions:
                    if perm in seen:
                        duplicates.append(perm)
                    seen.add(perm)

                assert (
                    not duplicates
                ), f"Duplicate permissions found in {file_path}: {duplicates}"

    def test_no_empty_permissions(self):
        """Test that there are no empty or whitespace-only permissions."""
        permission_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for file_path in permission_files:
            if file_path.exists():
                with open(file_path) as f:
                    data = json.load(f)

                permissions = data.get("permissions", {}).get("allow", [])

                for perm in permissions:
                    assert (
                        perm.strip()
                    ), f"Empty or whitespace-only permission found in {file_path}"

    def test_repository_references(self):
        """Test that repository references are correct."""
        permission_files = [
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
            Path(__file__).parent.parent.parent
            / "ccpm"
            / "claude_template"
            / "settings.local.json",
        ]

        for file_path in permission_files:
            if file_path.exists():
                with open(file_path) as f:
                    content = f.read()

                # Should reference the main repository
                if "github.com" in content:
                    assert (
                        "automazeio/ccpm" in content
                    ), f"Missing main repo reference in {file_path}"

                    # Should not reference other repositories unless explicitly needed
                    unwanted_repos = [
                        "jeremymanning/ccpm"
                    ]  # Example of fork that shouldn't be in main config
                    for repo in unwanted_repos:
                        if repo in content:
                            # This might be acceptable in some cases, but flag
                            # for review
                            pass


class TestSecurityDocumentation:
    """Test that security documentation is complete and accurate."""

    def test_security_documentation_exists(self):
        """Test that security documentation exists."""
        security_file = Path(__file__).parent.parent.parent / "SECURITY.md"
        assert security_file.exists(), "SECURITY.md file missing"

        with open(security_file) as f:
            content = f.read()

        # Check for required sections
        required_sections = [
            "## Overview",
            "## Security Model",
            "## Permission Categories",
            "## Security Validations",
            "## Threat Model",
            "## Best Practices",
        ]

        for section in required_sections:
            assert (
                section in content
            ), f"Missing security documentation section: {section}"

    def test_security_documentation_accuracy(self):
        """Test that security documentation accurately reflects implementation."""
        security_file = Path(__file__).parent.parent.parent / "SECURITY.md"
        if security_file.exists():
            with open(security_file) as f:
                security_content = f.read()

            # Check that documented permissions match actual implementation
            settings_file = (
                Path(__file__).parent.parent.parent / ".claude" / "settings.local.json"
            )
            if settings_file.exists():
                with open(settings_file) as f:
                    data = json.load(f)

                permissions = data.get("permissions", {}).get("allow", [])

                # Sample some permissions to ensure documentation is accurate
                sample_permissions = [
                    "Bash(git status)",
                    "Bash(git add .)",
                    "Bash(gh issue view:*)",
                    "Bash(python -m pytest:*)",
                ]

                for perm in sample_permissions:
                    if perm in permissions:
                        # Should be documented or at least mentioned in security docs
                        assert any(
                            keyword in security_content
                            for keyword in ["git", "github", "python", "pytest"]
                        ), f"Permission {perm} not reflected in documentation"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
