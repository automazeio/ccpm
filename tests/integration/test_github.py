"""Integration tests for GitHub CLI functionality."""

import platform
import subprocess
from pathlib import Path

import pytest

from ccpm.core.github import GitHubCLI


class TestGitHubCLI:
    """Test GitHub CLI wrapper with real operations."""

    def test_check_installation(self):
        """Test checking if GitHub CLI is installed."""
        gh = GitHubCLI()

        # This should return True or False without error
        result = gh.check_installation()
        assert isinstance(result, bool)

        # If gh is installed, verify we can run it
        if result:
            cmd_result = subprocess.run(
                ["gh", "--version"], capture_output=True, timeout=5
            )
            assert cmd_result.returncode == 0

    def test_run_command(self, github_cli_available):
        """Test running gh commands."""
        if not github_cli_available:
            pytest.skip("GitHub CLI not available")

        gh = GitHubCLI()

        # Test a simple command
        returncode, stdout, stderr = gh.run_command(["--version"])

        assert returncode == 0
        assert "gh version" in stdout

    def test_run_command_with_error(self):
        """Test handling command errors."""
        gh = GitHubCLI()

        # Run an invalid command
        returncode, stdout, stderr = gh.run_command(["invalid-command-xyz"])

        assert returncode != 0
        assert stderr != ""

    def test_install_extensions_check(self, github_cli_available):
        """Test checking for gh extensions."""
        if not github_cli_available:
            pytest.skip("GitHub CLI not available")

        gh = GitHubCLI()

        # This should complete without error
        # (may or may not actually install depending on if already present)
        result = gh.install_extensions()
        assert isinstance(result, bool)

    @pytest.mark.skipif(
        platform.system() == "Windows",
        reason="Auto-installation not fully supported on Windows",
    )
    def test_ensure_gh_installed(self):
        """Test the ensure_gh_installed method."""
        gh = GitHubCLI()

        # This should either find existing gh or attempt installation
        # We're not actually installing in tests, just checking the logic works
        result = gh.ensure_gh_installed()
        assert isinstance(result, bool)

        # If gh is already installed, this should be True
        if gh.check_installation():
            assert result is True


class TestGitHubIntegration:
    """Test GitHub integration in CCPM setup."""

    def test_setup_without_gh_continues(self, real_git_repo: Path, monkeypatch):
        """Test that setup continues even if GitHub CLI setup fails."""

        # Save the original subprocess.run
        original_run = subprocess.run

        # Mock gh to not be found
        def mock_run(*args, **kwargs):
            # Check if this is a gh command
            if args and len(args) > 0 and isinstance(args[0], list):
                if args[0][0] == "gh":
                    raise FileNotFoundError()
            # Use the original run for everything else
            return original_run(*args, **kwargs)

        monkeypatch.setattr(subprocess, "run", mock_run)

        # Setup should still work (with warnings)
        result = original_run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            text=True,
            timeout=60,
        )

        # Should not fail completely
        assert (real_git_repo / ".claude").exists()

    def test_sync_requires_github(self, real_git_repo: Path):
        """Test that sync command requires GitHub setup."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Try to sync (will fail without proper GitHub setup)
        result = subprocess.run(
            ["ccpm", "sync"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        # Should handle the error gracefully
        if result.returncode != 0:
            # Error could be either:
            # 1. Claude Code not installed (in CI)
            # 2. GitHub not configured (when Claude is available)
            assert (
                "GitHub" in result.stdout
                or "GitHub" in result.stderr
                or "git" in result.stderr.lower()
                or "Claude Code" in result.stdout
                or "Claude Code" in result.stderr
            )
