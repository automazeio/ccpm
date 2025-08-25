"""Integration tests for PM workflow commands."""

import subprocess
from pathlib import Path

import pytest

from ccpm.utils.claude import claude_available


class TestPMCommands:
    """Test PM workflow commands with real execution."""

    @pytest.mark.skipif(not claude_available(), reason="Claude Code CLI not available")
    def test_init_command(self, real_git_repo: Path):
        """Test the init command."""
        # Setup CCPM first
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Run init
        result = subprocess.run(
            ["ccpm", "init"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=60,
        )

        # Should complete (may warn about gh auth but shouldn't fail)
        assert result.returncode == 0 or "GitHub not authenticated" in result.stdout

    def test_list_command_empty(self, real_git_repo: Path):
        """Test list command with no PRDs."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Run list
        result = subprocess.run(
            ["ccpm", "list"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        assert result.returncode == 0
        assert "No PRDs found" in result.stdout

    def test_list_command_with_prds(self, real_git_repo: Path):
        """Test list command with existing PRDs."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Create test PRDs
        prds_dir = real_git_repo / ".claude" / "prds"
        prds_dir.mkdir(exist_ok=True)

        (prds_dir / "feature-1.md").write_text("# Feature 1 PRD\n\nDescription")
        (prds_dir / "feature-2.md").write_text("# Feature 2 PRD\n\nDescription")

        # Run list
        result = subprocess.run(
            ["ccpm", "list"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        assert result.returncode == 0
        assert "feature-1" in result.stdout
        assert "feature-2" in result.stdout
        assert "Total: 2 PRD(s)" in result.stdout

    @pytest.mark.skipif(not claude_available(), reason="Claude Code CLI not available")
    def test_status_command(self, real_git_repo: Path):
        """Test status command."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Run status
        result = subprocess.run(
            ["ccpm", "status"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        assert result.returncode == 0
        # Status command should either show project info or handle gracefully
        assert (
            "Project Status" in result.stdout
            or "PRDs:" in result.stdout
            or "No PRDs found" in result.stdout
            or "Claude Code" in result.stderr
            or len(result.stdout.strip()) > 0
        )

    @pytest.mark.skipif(not claude_available(), reason="Claude Code CLI not available")
    def test_help_command(self, real_git_repo: Path):
        """Test help command."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Run help
        result = subprocess.run(
            ["ccpm", "help"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        assert result.returncode == 0
        assert "Claude Code PM" in result.stdout or "CCPM" in result.stdout
        assert "Commands" in result.stdout or "help" in result.stdout.lower()

    @pytest.mark.skipif(not claude_available(), reason="Claude Code CLI not available")
    def test_validate_command(self, real_git_repo: Path):
        """Test validate command."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Run validate
        result = subprocess.run(
            ["ccpm", "validate"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        assert result.returncode == 0
        # Should report valid installation or run validation
        assert "valid" in result.stdout.lower() or "Validating" in result.stdout

    @pytest.mark.skipif(not claude_available(), reason="Claude Code CLI not available")
    def test_search_command(self, real_git_repo: Path):
        """Test search command."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Create content to search
        prds_dir = real_git_repo / ".claude" / "prds"
        prds_dir.mkdir(exist_ok=True)
        (prds_dir / "test.md").write_text(
            "# Test PRD\n\nThis contains searchable content."
        )

        # Run search
        result = subprocess.run(
            ["ccpm", "search", "searchable"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        assert result.returncode == 0
        assert "searchable" in result.stdout or "Found" in result.stdout


class TestMaintenanceCommands:
    """Test maintenance commands."""

    @pytest.mark.skipif(not claude_available(), reason="Claude Code CLI not available")
    def test_clean_command(self, real_git_repo: Path):
        """Test clean command."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Run clean
        result = subprocess.run(
            ["ccpm", "clean"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        # Should complete (may not have anything to clean)
        assert result.returncode == 0 or "Manual cleanup required" in result.stdout

    @pytest.mark.skipif(not claude_available(), reason="Claude Code CLI not available")
    def test_import_command(self, real_git_repo: Path):
        """Test import command (placeholder functionality)."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Run import
        result = subprocess.run(
            ["ccpm", "import"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        # Currently returns placeholder message
        assert result.returncode == 0
        assert (
            "not yet implemented" in result.stdout or "import" in result.stdout.lower()
        )


class TestCLIBasics:
    """Test basic CLI functionality."""

    def test_version_flag(self):
        """Test --version flag."""
        result = subprocess.run(
            ["ccpm", "--version"], capture_output=True, text=True, timeout=10
        )

        assert result.returncode == 0
        assert "0.1.0" in result.stdout

    def test_help_flag(self):
        """Test --help flag."""
        result = subprocess.run(
            ["ccpm", "--help"], capture_output=True, text=True, timeout=10
        )

        assert result.returncode == 0
        assert "Claude Code PM" in result.stdout
        assert "Commands:" in result.stdout
        assert "setup" in result.stdout
        assert "update" in result.stdout
        assert "uninstall" in result.stdout

    def test_command_help(self):
        """Test help for specific commands."""
        commands = ["setup", "update", "uninstall", "init", "list", "status"]

        for cmd in commands:
            result = subprocess.run(
                ["ccpm", cmd, "--help"], capture_output=True, text=True, timeout=10
            )

            assert result.returncode == 0
            assert cmd in result.stdout.lower() or "usage" in result.stdout.lower()

    def test_invalid_command(self):
        """Test invalid command handling."""
        result = subprocess.run(
            ["ccpm", "invalid-command"], capture_output=True, text=True, timeout=10
        )

        assert result.returncode != 0
        assert "invalid-command" in result.stderr or "Error" in result.stderr
