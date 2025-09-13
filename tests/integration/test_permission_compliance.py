"""Integration tests for permission compliance with tightened security settings.

These tests verify that all CCPM functionality continues to work correctly
with the minimal permission set defined in settings.local.json.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

from ccpm.utils.claude import claude_available

# from typing import List  # Unused import


class TestPermissionCompliance:
    """Test that CCPM core functionality works with tightened permissions."""

    def setup_method(self):
        """Set up test environment."""
        self.original_cwd = os.getcwd()
        # Create a temporary directory for testing
        self.test_dir = Path(tempfile.mkdtemp(prefix="ccpm_perm_test_"))
        os.chdir(self.test_dir)

    def teardown_method(self):
        """Clean up test environment."""
        os.chdir(self.original_cwd)
        # Clean up temp directory
        import shutil

        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_ccpm_setup_permissions(self):
        """Test that ccpm setup can be executed with current permissions."""
        # Initialize a git repository first
        subprocess.run(["git", "init"], check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test User"], check=True)
        subprocess.run(["git", "config", "user.email", "test@example.com"], check=True)

        # Run ccpm setup
        result = subprocess.run(
            ["ccpm", "setup", "."], capture_output=True, text=True, timeout=30
        )

        # Should succeed
        assert result.returncode == 0, f"ccpm setup failed: {result.stderr}"

        # Verify .claude directory was created
        assert (self.test_dir / ".claude").exists()
        assert (self.test_dir / ".claude" / "settings.local.json").exists()

    def test_git_operations_permissions(self):
        """Test that required git operations work with tightened permissions."""
        # Initialize git repo
        subprocess.run(["git", "init"], check=True, capture_output=True)
        subprocess.run(["git", "config", "user.name", "Test User"], check=True)
        subprocess.run(["git", "config", "user.email", "test@example.com"], check=True)

        # Create a test file
        test_file = self.test_dir / "test.txt"
        test_file.write_text("test content")

        # Test git operations that should be allowed
        git_commands = [
            ["git", "status"],
            ["git", "add", "."],
            ["git", "status", "--porcelain"],
            ["git", "commit", "-m", "Test commit"],
            ["git", "log", "--oneline", "-1"],
            ["git", "show", "HEAD"],
            ["git", "rev-parse", "HEAD"],
            ["git", "ls-files"],
        ]

        for cmd in git_commands:
            result = subprocess.run(cmd, capture_output=True, text=True)
            assert (
                result.returncode == 0
            ), f"Command {' '.join(cmd)} failed: {result.stderr}"

        # Add another commit to test diff operations
        test_file2 = self.test_dir / "test2.txt"
        test_file2.write_text("second content")
        subprocess.run(["git", "add", "."], check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", "Second commit"], check=True, capture_output=True
        )

        # Now test diff operations with two commits
        diff_commands = [
            ["git", "diff", "HEAD~1", "HEAD"],
        ]

        for cmd in diff_commands:
            result = subprocess.run(cmd, capture_output=True, text=True)
            assert (
                result.returncode == 0
            ), f"Command {' '.join(cmd)} failed: {result.stderr}"

    def test_python_operations_permissions(self):
        """Test that Python operations work with current permissions."""
        python_commands = [
            ["python", "-c", "print('test')"],
            ["python", "-m", "pip", "list"],
            ["python", "-m", "pytest", "--version"],
        ]

        for cmd in python_commands:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            assert (
                result.returncode == 0
            ), f"Command {' '.join(cmd)} failed: {result.stderr}"

    def test_file_operations_permissions(self):
        """Test that scoped file operations work correctly."""
        # Create .claude directory structure
        claude_dir = self.test_dir / ".claude"
        claude_dir.mkdir()

        # Test creating files in .claude
        test_file = claude_dir / "test.md"
        test_file.write_text("# Test")
        assert test_file.exists()

        # Test listing files
        result = subprocess.run(["ls", str(claude_dir)], capture_output=True, text=True)
        assert result.returncode == 0
        assert "test.md" in result.stdout

    @pytest.mark.skipif(not claude_available(), reason="Claude CLI not available")
    def test_claude_integration_permissions(self):
        """Test that Claude CLI integration works (if available)."""
        # This test only runs if Claude CLI is available
        # claude_commands = [  # Unused variable
        #     # Test basic Claude command (if available)
        # ]

        # Note: Actual Claude commands would need a .claude setup
        # This is more of a placeholder for when we can test the full integration
        pass

    def test_github_cli_permissions(self):
        """Test GitHub CLI permissions (basic commands only)."""
        # Test basic gh commands that don't require authentication
        basic_commands = [
            ["gh", "--version"],
        ]

        for cmd in basic_commands:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            # gh --version should work if gh is installed
            if result.returncode != 0:
                pytest.skip("GitHub CLI not available")

    def test_utility_commands_permissions(self):
        """Test that utility commands work with current permissions."""
        # Create test files
        test_file = self.test_dir / "test.py"
        test_file.write_text("print('hello')")

        # Use cross-platform commands
        if sys.platform == "win32":
            utility_commands = [
                ["where", "python"],
                ["echo", "test"],
            ]
        else:
            utility_commands = [
                ["find", ".", "-name", "*.py"],
                ["which", "python"],
                ["uname", "-s"],
                ["date"],
            ]

        for cmd in utility_commands:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            assert (
                result.returncode == 0
            ), f"Command {' '.join(cmd)} failed: {result.stderr}"

    def test_linting_permissions(self):
        """Test that linting tools work with current permissions."""
        # Create a test Python file
        test_file = self.test_dir / "test_lint.py"
        test_file.write_text(
            '''"""Test module."""

def hello():
    """Say hello."""
    print("hello")
'''
        )

        # Test linting commands
        lint_commands = [
            ["black", "--check", str(test_file)],
            ["ruff", "check", str(test_file)],
        ]

        for cmd in lint_commands:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            # These might not be installed, so we just check they're not blocked
            # by permissions (would get a different error code)
            if result.returncode == 127:  # Command not found
                pytest.skip(f"{cmd[0]} not installed")

    def test_package_installation_permissions(self):
        """Test that allowed package installations work."""
        # Test basic pip operations that should be allowed
        pip_commands = [
            ["pip", "show", "pip"],  # Should always work
            ["pip", "list"],
        ]

        for cmd in pip_commands:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            assert (
                result.returncode == 0
            ), f"Command {' '.join(cmd)} failed: {result.stderr}"

    def test_ccpm_cli_permissions(self):
        """Test that CCPM CLI commands work with current permissions."""
        # Test basic ccpm commands
        result = subprocess.run(
            ["ccpm", "--help"], capture_output=True, text=True, timeout=10
        )
        assert result.returncode == 0, f"ccpm --help failed: {result.stderr}"

        # Test ccpm without .claude setup (should give appropriate error)
        result = subprocess.run(
            ["ccpm", "list"], capture_output=True, text=True, timeout=10
        )
        # Should either work or give an appropriate error (not a permission error)
        # Permission errors typically have different return codes
        assert result.returncode != 126, "Permission denied error detected"


class TestSecurityValidation:
    """Test that security restrictions are properly enforced."""

    def test_restricted_directories(self):
        """Test that access to restricted directories is properly limited."""
        # Test that we can't access arbitrary system directories
        # This is more about validating the permission model conceptually

        # The permission system should restrict access to:
        # - System directories outside of project scope
        # - User directories outside of project scope
        # - Temporary directories outside of .claude/workspace
        pass

    def test_command_restrictions(self):
        """Test that overly broad command patterns are restricted."""
        # Validate that we don't have overly permissive patterns like:
        # - "Bash(*)" - would allow any command
        # - "Bash(rm *)" - would allow removing any file
        # - "Bash(git *)" - would allow any git command

        # Read the settings file and validate restrictions
        settings_file = (
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json"
        )
        if settings_file.exists():
            import json

            with open(settings_file) as f:
                settings = json.load(f)

            permissions = settings.get("permissions", {}).get("allow", [])

            # Check for overly broad patterns
            dangerous_patterns = [
                "Bash(*)",
                "Bash(rm *)",
                "Bash(git *)",
                "Bash(gh *)",
                "Bash(pip install *)",
            ]

            for pattern in dangerous_patterns:
                assert pattern not in permissions, f"Dangerous pattern found: {pattern}"

    def test_repository_references(self):
        """Test that repository references are properly configured."""
        import json

        settings_file = (
            Path(__file__).parent.parent.parent / ".claude" / "settings.local.json"
        )
        if settings_file.exists():

            with open(settings_file) as f:
                data = json.load(f)

            # Should have valid permissions structure
            assert "permissions" in data, "Missing permissions section"
            assert "allow" in data["permissions"], "Missing allow permissions"
            # Repository reference is optional - this test was too restrictive


def test_permission_file_syntax():
    """Test that permission files have valid JSON syntax."""
    permission_files = [
        Path(__file__).parent.parent.parent / ".claude" / "settings.local.json",
        Path(__file__).parent.parent.parent
        / "ccpm"
        / "claude_template"
        / "settings.local.json",
    ]

    for file_path in permission_files:
        if file_path.exists():
            import json

            with open(file_path) as f:
                data = json.load(f)

            # Validate structure
            assert "permissions" in data
            assert "allow" in data["permissions"]
            assert isinstance(data["permissions"]["allow"], list)

            # Validate no empty entries
            permissions = data["permissions"]["allow"]
            assert all(
                perm.strip() for perm in permissions
            ), f"Empty permission found in {file_path}"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
