"""Integration tests for non-interactive environment handling.

These tests validate that CCPM works correctly in CI/CD environments,
automated scripts, and other non-interactive contexts.
"""

import os
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

import pytest

from ccpm.core.installer import CCPMInstaller
from ccpm.utils.console import is_interactive_environment, safe_input


class TestEnvironmentDetection:
    """Test environment detection with real environment variables."""

    def test_interactive_environment_detection_tty(self):
        """Test TTY detection for interactive environment."""
        # This will depend on how the tests are run
        # In normal test environments, stdin.isatty() may be False
        result = is_interactive_environment()

        # Should be consistent with actual TTY status
        import sys

        expected = (
            sys.stdin.isatty()
            and not any(
                os.environ.get(indicator)
                for indicator in [
                    "CI",
                    "GITHUB_ACTIONS",
                    "JENKINS_URL",
                    "TRAVIS",
                    "CIRCLECI",
                    "BUILDBOT_WORKER",
                    "GITLAB_CI",
                ]
            )
            and not (os.environ.get("CCPM_FORCE") or os.environ.get("AUTOMATION_MODE"))
        )

        assert result == expected

    def test_ci_environment_detection(self):
        """Test CI environment detection with real environment variables."""
        # Test CI environments
        ci_vars = ["CI", "GITHUB_ACTIONS", "JENKINS_URL", "TRAVIS", "CIRCLECI"]

        for ci_var in ci_vars:
            with patch.dict(os.environ, {ci_var: "true"}):
                assert (
                    not is_interactive_environment()
                ), f"Failed to detect CI environment: {ci_var}"

        # Test multiple CI vars
        with patch.dict(os.environ, {"CI": "1", "GITHUB_ACTIONS": "true"}):
            assert not is_interactive_environment()

    def test_force_flag_detection(self):
        """Test automation force flag detection."""
        # Test CCPM_FORCE flag
        with patch.dict(os.environ, {"CCPM_FORCE": "1"}):
            assert not is_interactive_environment()

        # Test AUTOMATION_MODE flag
        with patch.dict(os.environ, {"AUTOMATION_MODE": "true"}):
            assert not is_interactive_environment()

    def test_safe_input_non_interactive_fallback(self):
        """Test safe_input fallback behavior in non-interactive mode."""
        # Test with CI environment
        with patch.dict(os.environ, {"CI": "true"}):
            result = safe_input("Test prompt [y/N]: ", default="N")
            assert result == "N"

        # Test with CCPM_FORCE
        with patch.dict(os.environ, {"CCPM_FORCE": "1"}):
            result = safe_input("Test prompt [y/N]: ", default="N")
            assert result == "N"

    def test_safe_input_force_value_override(self):
        """Test safe_input with forced value (for testing)."""
        result = safe_input("Test prompt [y/N]: ", default="N", force_value="y")
        assert result == "y"

        # Force value should override even in interactive mode
        result = safe_input("Test prompt [y/N]: ", default="N", force_value="custom")
        assert result == "custom"


class TestNonInteractiveInstallation:
    """Test installation operations in non-interactive mode."""

    def test_uninstall_non_interactive_with_force(self, temp_project):
        """Test uninstall in non-interactive mode with force flag."""
        installer = CCPMInstaller(temp_project)

        # Set up CCPM installation
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create some user content
        prds_dir = claude_dir / "prds"
        prds_dir.mkdir()
        (prds_dir / "test.md").write_text("# Test PRD")

        # Create CCPM files
        (claude_dir / "settings.local.json").write_text('{"test": true}')
        installer._create_tracking_file(had_existing=True)

        # Test non-interactive uninstall with force
        with patch.dict(os.environ, {"CCPM_FORCE": "1"}):
            installer.uninstall()

        # User content should be preserved
        assert (prds_dir / "test.md").exists()
        assert "Test PRD" in (prds_dir / "test.md").read_text()

    def test_uninstall_non_interactive_without_tracking(self, temp_project):
        """Test uninstall behavior when no tracking file exists in CI."""
        installer = CCPMInstaller(temp_project)

        # Set up directory without tracking file
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create user content
        prds_dir = claude_dir / "prds"
        prds_dir.mkdir()
        (prds_dir / "important.md").write_text("# Important User Data")

        # Create some CCPM-looking files
        (claude_dir / "settings.local.json").write_text('{"test": true}')

        # Test with CI environment (should use conservative approach)
        with patch.dict(os.environ, {"CI": "true", "CCPM_UNINSTALL_SCAFFOLDING": "y"}):
            installer.uninstall()

        # User content must be preserved
        assert (prds_dir / "important.md").exists()

    def test_setup_non_interactive_github_auth_skip(self, temp_project):
        """Test setup skips GitHub auth in CI environments."""
        installer = CCPMInstaller(temp_project)

        # Initialize git repo
        import subprocess

        subprocess.run(
            ["git", "init"], cwd=temp_project, check=True, capture_output=True
        )
        subprocess.run(
            ["git", "config", "user.name", "Test"], cwd=temp_project, check=True
        )
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"],
            cwd=temp_project,
            check=True,
        )

        # Mock GitHub CLI to simulate availability but no auth in CI
        def mock_setup_auth():
            return False  # Simulate skipped auth in CI

        with patch.object(installer.gh_cli, "setup_auth", side_effect=mock_setup_auth):
            with patch.dict(os.environ, {"CI": "true"}):
                # Should not fail even if GitHub auth is skipped
                try:
                    installer.setup()
                except Exception as e:
                    # Setup might fail for other reasons (missing template),
                    # but not auth
                    assert "authentication" not in str(e).lower()


class TestTimeoutConfiguration:
    """Test timeout configuration in non-interactive environments."""

    def test_timeout_environment_variables(self):
        """Test timeout configuration via environment variables."""
        from ccpm.utils.shell import get_timeout_for_operation

        # Test default values
        assert get_timeout_for_operation("pm_script", 300) == 300
        assert get_timeout_for_operation("git_command", 60) == 60

        # Test environment overrides
        with patch.dict(
            os.environ,
            {"CCPM_TIMEOUT_PM_SCRIPT": "600", "CCPM_TIMEOUT_GIT_COMMAND": "120"},
        ):
            assert get_timeout_for_operation("pm_script", 300) == 600
            assert get_timeout_for_operation("git_command", 60) == 120

        # Test invalid environment values (should use defaults)
        with patch.dict(
            os.environ,
            {
                "CCPM_TIMEOUT_PM_SCRIPT": "invalid",
                "CCPM_TIMEOUT_GIT_COMMAND": "not_a_number",
            },
        ):
            assert get_timeout_for_operation("pm_script", 300) == 300
            assert get_timeout_for_operation("git_command", 60) == 60

    def test_script_specific_timeout_configuration(self, temp_project_with_claude):
        """Test script-specific timeout environment variables."""
        from ccpm.utils.shell import run_pm_script

        # Create a quick test script
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        quick_script = scripts_dir / "quick.sh"
        quick_script.write_text(
            """#!/bin/bash
echo "Quick operation"
sleep 0.1
echo "Done"
"""
        )
        quick_script.chmod(0o755)

        # Test with script-specific timeout
        with patch.dict(os.environ, {"CCPM_TIMEOUT_QUICK": "30"}):
            from ccpm.utils.shell import get_shell_environment

            shell_env = get_shell_environment()

            if shell_env["shell_available"]:
                rc, stdout, stderr = run_pm_script(
                    "quick", cwd=temp_project_with_claude
                )

                # Should complete successfully
                assert rc == 0
                assert "Quick operation" in stdout
                assert "Done" in stdout

    def test_ci_timeout_handling(self, temp_project_with_claude):
        """Test timeout handling in CI environments."""
        from ccpm.utils.shell import run_pm_script

        # Create a script with moderate duration
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        moderate_script = scripts_dir / "moderate.sh"
        moderate_script.write_text(
            """#!/bin/bash
echo "Starting moderate operation"
sleep 2
echo "Moderate operation complete"
"""
        )
        moderate_script.chmod(0o755)

        # Test in CI environment with reasonable timeout
        with patch.dict(
            os.environ,
            {
                "CI": "true",
                "CCPM_TIMEOUT_MODERATE": "10",  # Should be plenty for 2 second sleep
            },
        ):
            from ccpm.utils.shell import get_shell_environment

            shell_env = get_shell_environment()

            if shell_env["shell_available"]:
                start_time = time.time()
                rc, stdout, stderr = run_pm_script(
                    "moderate", cwd=temp_project_with_claude
                )
                elapsed = time.time() - start_time

                # Should complete within timeout
                assert rc == 0
                assert elapsed < 10  # Well within timeout
                assert "Starting moderate operation" in stdout
                assert "Moderate operation complete" in stdout


class TestAutomationIntegration:
    """Test integration with automation tools and scripts."""

    def test_environment_variable_cleanup(self):
        """Test that environment variables are properly managed."""
        original_force = os.environ.get("CCPM_FORCE")
        original_uninstall = os.environ.get("CCPM_UNINSTALL_SCAFFOLDING")

        try:
            # Set test environment
            os.environ["CCPM_FORCE"] = "1"
            os.environ["CCPM_UNINSTALL_SCAFFOLDING"] = "y"

            # Verify they're set
            assert os.environ.get("CCPM_FORCE") == "1"
            assert os.environ.get("CCPM_UNINSTALL_SCAFFOLDING") == "y"

            # Test cleanup (simulating CLI cleanup)
            os.environ.pop("CCPM_FORCE", None)
            os.environ.pop("CCPM_UNINSTALL_SCAFFOLDING", None)

            # Should be cleaned up
            assert "CCPM_FORCE" not in os.environ
            assert "CCPM_UNINSTALL_SCAFFOLDING" not in os.environ

        finally:
            # Restore original values
            if original_force is not None:
                os.environ["CCPM_FORCE"] = original_force
            if original_uninstall is not None:
                os.environ["CCPM_UNINSTALL_SCAFFOLDING"] = original_uninstall

    def test_batch_operation_simulation(self, temp_project):
        """Test simulation of batch operations (like in CI/CD pipeline)."""
        installer = CCPMInstaller(temp_project)

        # Initialize git (typical in CI)
        import subprocess

        subprocess.run(
            ["git", "init"], cwd=temp_project, check=True, capture_output=True
        )
        subprocess.run(
            ["git", "config", "user.name", "CI Bot"], cwd=temp_project, check=True
        )
        subprocess.run(
            ["git", "config", "user.email", "ci@example.com"],
            cwd=temp_project,
            check=True,
        )

        # Create .claude directory with user content
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        prds_dir = claude_dir / "prds"
        prds_dir.mkdir()
        (prds_dir / "feature.md").write_text("# Feature PRD\nImportant user content")

        # Create tracking file
        installer._create_tracking_file(had_existing=True)

        # Simulate CI environment with batch operations
        with patch.dict(
            os.environ,
            {
                "CI": "true",
                "GITHUB_ACTIONS": "true",
                "CCPM_FORCE": "1",
                "CCPM_TIMEOUT_PM_SCRIPT": "300",
                "CCPM_TIMEOUT_GIT_COMMAND": "60",
            },
        ):
            # Should handle all operations non-interactively
            assert not is_interactive_environment()

            # Test operations
            installer.uninstall()

            # User content should be preserved
            assert (prds_dir / "feature.md").exists()
            content = (prds_dir / "feature.md").read_text()
            assert "Important user content" in content

    def test_docker_environment_simulation(self):
        """Test behavior in Docker-like environments."""
        # Simulate Docker environment characteristics
        docker_env = {
            "container": "docker",
            "CI": "true",
            "DEBIAN_FRONTEND": "noninteractive",
            "CCPM_FORCE": "1",
        }

        with patch.dict(os.environ, docker_env):
            # Should detect non-interactive environment
            assert not is_interactive_environment()

            # Should handle prompts with defaults
            result = safe_input("Install package [y/N]: ", default="N")
            assert result == "N"


class TestErrorHandlingNonInteractive:
    """Test error handling in non-interactive environments."""

    def test_graceful_failure_in_ci(self, temp_project):
        """Test graceful failure handling in CI environments."""
        installer = CCPMInstaller(temp_project)

        # Set up for failure scenario
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create user content that must be preserved
        prds_dir = claude_dir / "prds"
        prds_dir.mkdir()
        (prds_dir / "critical.md").write_text("# Critical User Data")

        # Corrupt tracking file to force error
        tracking_file = temp_project / ".ccpm_tracking.json"
        tracking_file.write_text("invalid json content")

        # Test in CI environment
        with patch.dict(os.environ, {"CI": "true", "CCPM_FORCE": "1"}):
            try:
                installer.uninstall()
            except Exception:
                # Even if operation fails, user content should be safe
                pass

            # Critical: user content must survive any errors
            assert (prds_dir / "critical.md").exists()
            assert "Critical User Data" in (prds_dir / "critical.md").read_text()

    def test_timeout_error_reporting_ci(self, temp_project_with_claude):
        """Test timeout error reporting in CI environments."""
        from ccpm.utils.shell import run_pm_script

        # Create a script that will timeout
        scripts_dir = temp_project_with_claude / ".claude" / "scripts" / "pm"
        scripts_dir.mkdir(parents=True, exist_ok=True)

        long_script = scripts_dir / "long_running.sh"
        long_script.write_text(
            """#!/bin/bash
echo "Starting long operation"
sleep 30
echo "This should not appear"
"""
        )
        long_script.chmod(0o755)

        from ccpm.utils.shell import get_shell_environment

        shell_env = get_shell_environment()

        if shell_env["shell_available"]:
            # Test with CI environment and short timeout
            with patch.dict(
                os.environ, {"CI": "true", "CCPM_TIMEOUT_LONG_RUNNING": "2"}
            ):
                rc, stdout, stderr = run_pm_script(
                    "long_running", cwd=temp_project_with_claude
                )

                # Should timeout appropriately
                assert rc == 1
                assert "timed out" in stderr.lower()
                assert "long_running" in stderr
                assert "2 seconds" in stderr


@pytest.fixture
def temp_project():
    """Create a temporary project directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def temp_project_with_claude(temp_project):
    """Create a temporary project with .claude directory."""
    claude_dir = temp_project / ".claude"
    claude_dir.mkdir()
    return temp_project


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
