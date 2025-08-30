"""Integration tests for exception chain preservation and error recovery.

These tests validate that exception handling properly preserves original context
and that error recovery mechanisms work correctly with real operations.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

from ccpm.core.installer import CCPMInstaller
from ccpm.utils.backup import BackupManager


class TestExceptionChaining:
    """Test exception chain preservation with real execution."""

    def test_timeout_exception_chaining_pm_command(
        self, temp_project_with_git, monkeypatch
    ):
        """Test that timeout exceptions preserve original context in PM commands."""
        from ccpm.commands.pm import invoke_claude_command

        # Enter temporary project directory for hermetic testing
        monkeypatch.chdir(temp_project_with_git)

        # Create a mock Claude CLI that will timeout
        if sys.platform == "win32":
            # On Windows, create a batch file that calls Python
            mock_claude_script = temp_project_with_git / "mock_claude.bat"
            python_script = temp_project_with_git / "mock_claude.py"
            python_script.write_text(
                """import time
import sys
time.sleep(10)  # This will cause timeout
sys.exit(0)
"""
            )
            mock_claude_script.write_text(f'@echo off\npython "{python_script}"\n')
        else:
            # Unix-like systems
            mock_claude_script = temp_project_with_git / "mock_claude.py"
            mock_claude_script.write_text(
                """#!/usr/bin/env python3
import time
import sys
time.sleep(10)  # This will cause timeout
sys.exit(0)
"""
            )
            mock_claude_script.chmod(0o755)

        # Set up .claude directory
        claude_dir = temp_project_with_git / ".claude"
        claude_dir.mkdir(exist_ok=True)

        # Mock find_claude_cli to return our timeout script
        with patch("ccpm.commands.pm.find_claude_cli") as mock_cli:
            mock_cli.return_value = str(mock_claude_script)

            # Set a very short timeout to trigger TimeoutExpired quickly
            with patch.dict(os.environ, {"CCPM_TIMEOUT_CLAUDE_COMMAND": "2"}):
                with pytest.raises(RuntimeError) as exc_info:
                    invoke_claude_command("/pm:test")

                # Verify exception chaining
                assert exc_info.value.__cause__ is not None
                assert isinstance(exc_info.value.__cause__, subprocess.TimeoutExpired)
                assert "timeout" in str(exc_info.value).lower()
                assert "operation too complex" in str(exc_info.value)

    def test_timeout_exception_chaining_maintenance_command(
        self, temp_project_with_git, monkeypatch
    ):
        """Test timeout exceptions preserve original context in maintenance."""
        from ccpm.commands.maintenance import invoke_claude_command

        # Enter temporary project directory for hermetic testing
        monkeypatch.chdir(temp_project_with_git)

        # Create a mock Claude CLI that will timeout
        if sys.platform == "win32":
            # On Windows, create a batch file that calls Python
            mock_claude_script = temp_project_with_git / "mock_claude.bat"
            python_script = temp_project_with_git / "mock_claude.py"
            python_script.write_text(
                """import time
import sys
time.sleep(10)  # This will cause timeout
sys.exit(0)
"""
            )
            mock_claude_script.write_text(f'@echo off\npython "{python_script}"\n')
        else:
            # Unix-like systems
            mock_claude_script = temp_project_with_git / "mock_claude.py"
            mock_claude_script.write_text(
                """#!/usr/bin/env python3
import time
import sys
time.sleep(10)  # This will cause timeout
sys.exit(0)
"""
            )
            mock_claude_script.chmod(0o755)

        # Set up .claude directory
        claude_dir = temp_project_with_git / ".claude"
        claude_dir.mkdir(exist_ok=True)

        # Mock find_claude_cli to return our timeout script
        with patch("ccpm.commands.maintenance.find_claude_cli") as mock_cli:
            mock_cli.return_value = str(mock_claude_script)

            # Set a very short timeout to trigger TimeoutExpired quickly
            with patch.dict(os.environ, {"CCPM_TIMEOUT_CLAUDE_COMMAND": "2"}):
                with pytest.raises(RuntimeError) as exc_info:
                    invoke_claude_command("/pm:validate")

                # Verify exception chaining
                assert exc_info.value.__cause__ is not None
                assert isinstance(exc_info.value.__cause__, subprocess.TimeoutExpired)
                assert "timeout" in str(exc_info.value).lower()

    def test_claude_command_failure_exception_chaining(self, temp_project_with_git):
        """Test that command failures preserve original context."""
        from ccpm.commands.pm import invoke_claude_command

        # Create a mock Claude CLI that will fail
        mock_claude_script = temp_project_with_git / "mock_claude_fail.py"
        mock_claude_script.write_text(
            """#!/usr/bin/env python3
import sys
print("Mock error output", file=sys.stderr)
sys.exit(1)  # Non-zero exit
"""
        )
        mock_claude_script.chmod(0o755)

        # Set up .claude directory
        claude_dir = temp_project_with_git / ".claude"
        claude_dir.mkdir(exist_ok=True)

        # Mock find_claude_cli to return our failing script
        with patch("ccpm.commands.pm.find_claude_cli") as mock_cli:
            mock_cli.return_value = str(mock_claude_script)

            with pytest.raises(RuntimeError) as exc_info:
                invoke_claude_command("/pm:test")

            # Should have proper error message
            assert "Claude command execution failed" in str(exc_info.value)

    def test_backup_restore_on_failure(self, temp_project):
        """Test that backup restoration works on operation failure."""

        # Create initial .claude state
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        original_file = claude_dir / "original.txt"
        original_file.write_text("original content")

        # Create backup
        backup_manager = BackupManager(temp_project)
        backup_path = backup_manager.create_backup(claude_dir)

        # Verify backup was created
        assert backup_path.exists()

        # Modify the directory (simulating partial operation)
        original_file.write_text("modified content")
        new_file = claude_dir / "new.txt"
        new_file.write_text("new content")

        # Restore from backup
        backup_manager.restore_backup(backup_path, claude_dir)

        # Verify restoration
        assert original_file.read_text() == "original content"
        assert not new_file.exists()

    def test_installer_update_error_recovery(self, temp_project):
        """Test that installer update properly recovers from errors."""
        installer = CCPMInstaller(temp_project)

        # Create initial .claude directory
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        original_file = claude_dir / "test.txt"
        original_file.write_text("original")

        # Create tracking file to indicate existing installation
        installer._create_tracking_file(had_existing=True)

        # Mock run_command to fail during clone operation
        def mock_run_command_fail(*args, **kwargs):
            return (1, "", "Mock git clone failure")

        with patch(
            "ccpm.core.installer.run_command", side_effect=mock_run_command_fail
        ):
            with pytest.raises(RuntimeError) as exc_info:
                installer.update()

            # Verify proper error chaining
            assert exc_info.value.__cause__ is not None
            assert "Failed to clone CCPM repository" in str(exc_info.value.__cause__)

            # Verify original file is still there (backup restored)
            assert original_file.exists()
            assert original_file.read_text() == "original"


class TestShellErrorHandling:
    """Test shell command error handling with real execution."""

    def test_pm_script_timeout_handling(self, temp_project_with_claude):
        """Test PM script timeout handling with real execution."""
        from ccpm.utils.shell import run_pm_script

        # Create a script that will timeout
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        timeout_script = scripts_dir / "timeout_test.sh"
        timeout_script.write_text(
            """#!/bin/bash
sleep 10
echo "This should not appear"
"""
        )
        timeout_script.chmod(0o755)

        # Run with very short timeout
        rc, stdout, stderr = run_pm_script(
            "timeout_test", cwd=temp_project_with_claude, timeout=2
        )

        # Should timeout
        assert rc == 1
        assert "timed out" in stderr.lower()
        assert "timeout_test" in stderr

    def test_pm_script_missing_shell_handling(self, temp_project_with_claude):
        """Test PM script handling when no shell is available."""
        from ccpm.utils.shell import run_pm_script

        # Create a test script
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        test_script = scripts_dir / "test.sh"
        test_script.write_text(
            """#!/bin/bash
echo "Hello from test"
"""
        )
        test_script.chmod(0o755)

        # Mock get_shell_environment to return no shell
        with patch("ccpm.utils.shell.get_shell_environment") as mock_env:
            mock_env.return_value = {
                "platform": "test",
                "shell_available": False,
                "shell_path": None,
                "shell_type": None,
            }

            rc, stdout, stderr = run_pm_script("test", cwd=temp_project_with_claude)

            assert rc == 1
            assert "No compatible shell found" in stderr
            assert "install Git for Windows, WSL, or MSYS2" in stderr

    def test_cross_platform_error_messages(self, temp_project_with_claude):
        """Test that cross-platform error messages are informative."""
        from ccpm.utils.shell import run_pm_script

        # Test with non-existent script
        rc, stdout, stderr = run_pm_script("nonexistent", cwd=temp_project_with_claude)

        assert rc == 1
        assert "Script not found" in stderr
        assert "nonexistent.sh" in stderr


@pytest.fixture
def temp_project():
    """Create a temporary project directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def temp_project_with_git(temp_project):
    """Create a temporary project with git initialized."""
    subprocess.run(["git", "init"], cwd=temp_project, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.name", "Test User"], cwd=temp_project, check=True
    )
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=temp_project,
        check=True,
    )
    return temp_project


@pytest.fixture
def temp_project_with_claude(temp_project_with_git):
    """Create a temporary project with .claude directory."""
    claude_dir = temp_project_with_git / ".claude"
    claude_dir.mkdir()
    return temp_project_with_git


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
