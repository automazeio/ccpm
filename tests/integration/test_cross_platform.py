"""Integration tests for cross-platform compatibility with real system calls.

These tests validate cross-platform shell execution, environment detection,
and proper handling of platform-specific differences.
"""

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

from ccpm.utils.shell import (
    _find_git_bash,
    _find_msys2_bash,
    _find_wsl_bash,
    get_shell_environment,
    run_pm_script,
)


class TestCrossPlatformShellDetection:
    """Test cross-platform shell detection with real system calls."""

    def test_shell_environment_detection_current_platform(self):
        """Test shell environment detection on current platform."""
        env = get_shell_environment()

        # Should always have these keys
        assert "platform" in env
        assert "shell_available" in env
        assert "shell_path" in env
        assert "shell_type" in env

        # Platform should match current system
        assert env["platform"] == sys.platform

        if sys.platform != "win32":
            # On Unix-like systems, bash should be available
            bash_path = shutil.which("bash")
            if bash_path:
                assert env["shell_available"]
                assert env["shell_type"] == "bash"
                assert env["shell_path"] == bash_path
        else:
            # On Windows, shell availability depends on Git/WSL/MSYS2
            if env["shell_available"]:
                assert env["shell_type"] in ["git-bash", "wsl-bash", "msys2-bash"]
                assert env["shell_path"] is not None
                assert Path(env["shell_path"]).exists()

    @pytest.mark.skipif(sys.platform != "win32", reason="Windows-specific test")
    def test_windows_git_bash_detection(self):
        """Test Git Bash detection on Windows with real Git installation."""
        git_bash_path = _find_git_bash()

        if shutil.which("git"):
            # Git is installed, should find bash
            if git_bash_path:
                assert Path(git_bash_path).exists()
                # Should be executable
                assert os.access(git_bash_path, os.X_OK)
        else:
            # No Git installed
            assert git_bash_path is None

    @pytest.mark.skipif(sys.platform != "win32", reason="Windows-specific test")
    def test_windows_wsl_detection(self):
        """Test WSL detection on Windows."""
        wsl_path = _find_wsl_bash()

        if shutil.which("wsl"):
            # WSL might be available
            if wsl_path:
                assert Path(wsl_path).exists()
        else:
            # No WSL available
            assert wsl_path is None

    @pytest.mark.skipif(sys.platform != "win32", reason="Windows-specific test")
    def test_windows_msys2_detection(self):
        """Test MSYS2 detection on Windows."""
        msys2_path = _find_msys2_bash()

        if msys2_path:
            # If found, should exist
            assert Path(msys2_path).exists()
            assert os.access(msys2_path, os.X_OK)

    @pytest.mark.skipif(sys.platform == "win32", reason="Unix-specific test")
    def test_unix_bash_detection(self):
        """Test bash detection on Unix-like systems."""
        env = get_shell_environment()

        bash_path = shutil.which("bash")
        if bash_path:
            assert env["shell_available"]
            assert env["shell_type"] == "bash"
            assert env["shell_path"] == bash_path
        else:
            # Rare case where bash is not available on Unix
            pass


class TestCrossPlatformScriptExecution:
    """Test cross-platform PM script execution."""

    def test_pm_script_execution_current_platform(self, temp_project_with_claude):
        """Test PM script execution on current platform."""
        # Create a simple test script
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        test_script = scripts_dir / "test_platform.sh"
        test_script.write_text(
            """#!/bin/bash
echo "Hello from test script"
echo "Platform detection test"
# Try to detect platform in a cross-platform way
if command -v uname >/dev/null 2>&1; then
    echo "Platform: $(uname -s)"
else
    echo "Platform: Windows"
fi
exit 0
"""
        )
        test_script.chmod(0o755)

        # Execute the script
        rc, stdout, stderr = run_pm_script(
            "test_platform", cwd=temp_project_with_claude
        )

        # Should succeed on any platform with proper shell
        shell_env = get_shell_environment()
        if shell_env["shell_available"]:
            assert rc == 0
            assert "Hello from test script" in stdout
            assert "Platform detection test" in stdout
            # Should have some platform info
            assert "Platform:" in stdout
        else:
            # No shell available - should get appropriate error
            assert rc == 1
            assert "No compatible shell found" in stderr

    def test_pm_script_with_arguments(self, temp_project_with_claude):
        """Test PM script execution with arguments."""
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        args_script = scripts_dir / "test_args.sh"
        args_script.write_text(
            """#!/bin/bash
echo "Arg count: $#"
echo "Arg 1: $1"
echo "Arg 2: $2"
echo "All args: $@"
exit 0
"""
        )
        args_script.chmod(0o755)

        # Execute with arguments
        shell_env = get_shell_environment()
        if shell_env["shell_available"]:
            rc, stdout, stderr = run_pm_script(
                "test_args", args=["hello", "world"], cwd=temp_project_with_claude
            )

            assert rc == 0
            assert "Arg count: 2" in stdout
            assert "Arg 1: hello" in stdout
            assert "Arg 2: world" in stdout
            assert "All args: hello world" in stdout

    def test_pm_script_error_handling_cross_platform(self, temp_project_with_claude):
        """Test error handling works across platforms."""
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        error_script = scripts_dir / "test_error.sh"
        error_script.write_text(
            """#!/bin/bash
echo "This will fail"
echo "Error message" >&2
exit 1
"""
        )
        error_script.chmod(0o755)

        shell_env = get_shell_environment()
        if shell_env["shell_available"]:
            rc, stdout, stderr = run_pm_script(
                "test_error", cwd=temp_project_with_claude
            )

            assert rc == 1
            assert "This will fail" in stdout
            assert "Error message" in stderr

    def test_script_timeout_cross_platform(self, temp_project_with_claude):
        """Test script timeout handling across platforms."""
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        timeout_script = scripts_dir / "test_timeout.sh"
        timeout_script.write_text(
            """#!/bin/bash
echo "Starting long operation..."
sleep 10
echo "This should not appear"
"""
        )
        timeout_script.chmod(0o755)

        shell_env = get_shell_environment()
        if shell_env["shell_available"]:
            # Test with short timeout
            rc, stdout, stderr = run_pm_script(
                "test_timeout", cwd=temp_project_with_claude, timeout=2
            )

            assert rc == 1
            assert "timed out" in stderr.lower()
            assert "test_timeout" in stderr


class TestEnvironmentConfiguration:
    """Test environment-based configuration across platforms."""

    def test_timeout_environment_override(self, temp_project_with_claude):
        """Test that environment variables override default timeouts."""
        from ccpm.utils.shell import get_timeout_for_operation

        # Test default timeout
        default_timeout = get_timeout_for_operation("pm_script", 300)
        assert default_timeout == 300

        # Test environment override
        with patch.dict(os.environ, {"CCPM_TIMEOUT_PM_SCRIPT": "600"}):
            override_timeout = get_timeout_for_operation("pm_script", 300)
            assert override_timeout == 600

        # Test invalid environment value (should use default)
        with patch.dict(os.environ, {"CCPM_TIMEOUT_PM_SCRIPT": "invalid"}):
            invalid_timeout = get_timeout_for_operation("pm_script", 300)
            assert invalid_timeout == 300

    def test_script_specific_timeout_override(self, temp_project_with_claude):
        """Test script-specific timeout environment variables."""
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        quick_script = scripts_dir / "quick_test.sh"
        quick_script.write_text(
            """#!/bin/bash
echo "Quick test"
sleep 1
echo "Done"
"""
        )
        quick_script.chmod(0o755)

        shell_env = get_shell_environment()
        if shell_env["shell_available"]:
            # Test with script-specific timeout
            with patch.dict(os.environ, {"CCPM_TIMEOUT_QUICK_TEST": "5"}):
                rc, stdout, stderr = run_pm_script(
                    "quick_test", cwd=temp_project_with_claude
                )

                # Should complete successfully within 5 seconds
                assert rc == 0
                assert "Quick test" in stdout
                assert "Done" in stdout


class TestCrossPlatformGitIntegration:
    """Test Git integration across platforms."""

    def test_git_operations_cross_platform(self, temp_project_with_git):
        """Test Git operations work across platforms."""
        from ccpm.utils.shell import run_command

        # Test basic git operations
        git_commands = [
            (["git", "status"], "status should work"),
            (["git", "branch"], "branch should work"),
        ]

        for cmd, description in git_commands:
            rc, stdout, stderr = run_command(cmd, cwd=temp_project_with_git)
            assert rc == 0, f"Git command failed: {description} - {stderr}"

    def test_git_timeout_handling(self, temp_project_with_git):
        """Test Git command timeout handling."""
        from ccpm.utils.shell import run_command

        # Test with very short timeout on a command that should complete quickly
        rc, stdout, stderr = run_command(
            ["git", "status", "--porcelain"], cwd=temp_project_with_git, timeout=10
        )

        # Should complete within timeout
        assert rc == 0


class TestPlatformSpecificBehavior:
    """Test platform-specific behavior and edge cases."""

    def test_windows_path_handling(self):
        """Test Windows path handling in shell detection."""
        if sys.platform == "win32":
            # Test Windows-style paths
            env = get_shell_environment()
            if env["shell_available"] and env["shell_path"]:
                # Should handle Windows path format
                assert "\\" in env["shell_path"] or "/" in env["shell_path"]
                assert Path(env["shell_path"]).exists()

    def test_unix_permissions(self):
        """Test Unix permissions handling."""
        if sys.platform != "win32":
            env = get_shell_environment()
            if env["shell_available"]:
                # Should be executable
                assert os.access(env["shell_path"], os.X_OK)

    def test_shell_environment_fallback_behavior(self):
        """Test behavior when no suitable shell is found."""
        # Mock all shell detection functions to return None
        with patch("ccpm.utils.shell._find_git_bash", return_value=None), patch(
            "ccpm.utils.shell._find_wsl_bash", return_value=None
        ), patch("ccpm.utils.shell._find_msys2_bash", return_value=None), patch(
            "shutil.which", return_value=None
        ):

            env = get_shell_environment()

            assert not env["shell_available"]
            assert env["shell_path"] is None
            assert env["shell_type"] is None


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
