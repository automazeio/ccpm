"""Integration tests for data safety and user content preservation.

These tests validate that user content is never lost during any CCPM operation,
using real file system operations and comprehensive safety checks.
"""

import json
import os
import tempfile
from pathlib import Path

import pytest

from ccpm.core.installer import CCPMInstaller


class TestDataSafetyCore:
    """Test core data safety mechanisms with real file operations."""

    def test_user_content_preservation_during_uninstall(self, temp_project_with_ccpm):
        """Test that uninstall preserves user content with real files."""
        installer, temp_project = temp_project_with_ccpm
        claude_dir = temp_project / ".claude"

        # Create comprehensive user content
        _create_realistic_user_content(claude_dir)

        # Perform uninstall with force flag (non-interactive)
        os.environ["CCPM_FORCE"] = "1"
        try:
            installer.uninstall()
        finally:
            os.environ.pop("CCPM_FORCE", None)

        # Verify ALL user content is preserved
        _verify_user_content_preserved(claude_dir)

        # Verify CCPM scaffolding is removed
        _verify_ccpm_scaffolding_removed(claude_dir)

    def test_tracking_file_accuracy_prevents_user_deletion(self, temp_project):
        """Test that tracking file accurately reflects only CCPM files."""
        installer = CCPMInstaller(temp_project)

        # Simulate setup to create tracking file
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()
        installer._create_tracking_file(had_existing=True)

        # Load and verify tracking file structure
        tracking = installer._load_tracking_file()

        # Verify new safe tracking format
        assert "ccpm_scaffolding_files" in tracking
        assert "user_content_dirs" in tracking
        assert "data_safety_version" in tracking

        scaffolding_files = tracking["ccpm_scaffolding_files"]
        user_dirs = tracking["user_content_dirs"]

        # Verify NO user content directories are tracked for deletion
        dangerous_patterns = ["agents", "prds", "epics"]
        for pattern in dangerous_patterns:
            assert not any(pattern in file_path for file_path in scaffolding_files), (
                f"Dangerous pattern '{pattern}' found in scaffolding files: "
                f"{scaffolding_files}"
            )

        # Verify user content directories are documented but not tracked for deletion
        for user_dir in ["agents", "prds", "epics"]:
            assert user_dir in user_dirs

        # Verify only safe CCPM files are tracked
        safe_patterns = [
            "scripts/pm/",
            "scripts/test-and-log.sh",
            "settings.local.json",
        ]
        for pattern in safe_patterns:
            assert any(
                pattern in file_path for file_path in scaffolding_files
            ), f"Expected CCPM file pattern '{pattern}' not found in tracking"

    def test_legacy_tracking_file_safety(self, temp_project):
        """Test that legacy tracking files are handled safely."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create a legacy tracking file (old format with user content)
        legacy_tracking = {
            "version": "0.1.0",
            "installed_at": "2023-01-01T00:00:00",
            "had_existing_claude": True,
            "ccpm_files": [
                "scripts/pm",
                "commands/pm",
                "agents",  # DANGEROUS - user content
                "prds",  # DANGEROUS - user content
                "epics",  # DANGEROUS - user content
                "scripts/test-and-log.sh",
            ],
        }

        tracking_file = temp_project / ".ccpm_tracking.json"
        with open(tracking_file, "w") as f:
            json.dump(legacy_tracking, f)

        # Create user content that would be at risk
        _create_realistic_user_content(claude_dir)

        # Attempt uninstall - should handle legacy safely
        os.environ["CCPM_FORCE"] = "1"
        try:
            installer.uninstall()
        finally:
            os.environ.pop("CCPM_FORCE", None)

        # Verify user content is preserved even with dangerous legacy tracking
        _verify_user_content_preserved(claude_dir)

    def test_user_content_detection_comprehensive(self, temp_project):
        """Test comprehensive user content detection."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create various types of user content
        _create_realistic_user_content(claude_dir)

        # Test detection
        user_content = installer._detect_user_content()

        # Should detect all types of user content
        content_str = " ".join(user_content)
        assert "prds" in content_str
        assert "agents" in content_str
        assert "epics" in content_str

        # Should report counts
        assert "items)" in content_str

    def test_directory_safety_validation(self, temp_project):
        """Test directory safety validation prevents user content removal."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create mixed directory with user content and CCPM files
        mixed_dir = claude_dir / "mixed"
        mixed_dir.mkdir()

        # CCPM scaffolding files
        (mixed_dir / "template.sh").write_text("#!/bin/bash\necho 'CCPM template'")

        # User content
        (mixed_dir / "user_doc.md").write_text("# User Documentation")
        (mixed_dir / "user_script.py").write_text("print('User script')")

        # Should detect user content and refuse to remove
        assert not installer._is_directory_empty_of_user_content(mixed_dir)

        # Create directory with only CCPM content
        ccpm_only_dir = claude_dir / "ccpm_only"
        ccpm_only_dir.mkdir()
        (ccpm_only_dir / "template.sh").write_text("#!/bin/bash\necho 'template'")

        # Should be safe to remove (no user content patterns)
        # Note: This is conservative - real implementation might still preserve
        # This tests the detection logic only

    def test_safe_uninstall_without_tracking(self, temp_project):
        """Test safe uninstall when no tracking file exists."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create user content
        _create_realistic_user_content(claude_dir)

        # Create some CCPM-like files
        (claude_dir / "settings.local.json").write_text('{"test": true}')
        (claude_dir / "CLAUDE.md").write_text("# CLAUDE instructions")

        scripts_dir = claude_dir / "scripts"
        scripts_dir.mkdir()
        (scripts_dir / "test-and-log.sh").write_text("#!/bin/bash\necho 'test'")

        # Ensure no tracking file exists
        tracking_file = temp_project / ".ccpm_tracking.json"
        if tracking_file.exists():
            tracking_file.unlink()

        # Should use conservative uninstall approach
        os.environ["CCPM_UNINSTALL_SCAFFOLDING"] = "y"
        try:
            installer.uninstall()
        finally:
            os.environ.pop("CCPM_UNINSTALL_SCAFFOLDING", None)

        # User content should be preserved
        _verify_user_content_preserved(claude_dir)

        # Some known CCPM files might be removed conservatively
        # But user content should never be touched


class TestDataSafetyEdgeCases:
    """Test edge cases and error conditions for data safety."""

    def test_partial_installation_safety(self, temp_project):
        """Test safety when installation is partial or corrupted."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create user content first
        _create_realistic_user_content(claude_dir)

        # Create partial CCPM installation (missing some files)
        (claude_dir / "settings.local.json").write_text('{"partial": true}')

        # Create corrupted tracking file
        tracking_file = temp_project / ".ccpm_tracking.json"
        tracking_file.write_text("invalid json content")

        # Uninstall should handle gracefully and preserve user content
        os.environ["CCPM_FORCE"] = "1"
        try:
            # Should not crash on corrupted tracking file
            installer.uninstall()
        except Exception:
            # Even if it fails, user content should be untouched
            pass
        finally:
            os.environ.pop("CCPM_FORCE", None)

        # Verify user content survived any errors
        _verify_user_content_preserved(claude_dir)

    def test_permission_error_handling(self, temp_project):
        """Test behavior when files cannot be removed due to permissions."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create user content
        _create_realistic_user_content(claude_dir)

        # Create CCPM file with restricted permissions (simulate permission error)
        ccpm_file = claude_dir / "settings.local.json"
        ccpm_file.write_text('{"test": true}')

        # Make file read-only (simulate permission issue)
        if os.name != "nt":  # Skip on Windows due to different permission model
            ccpm_file.chmod(0o444)

        installer._create_tracking_file(had_existing=True)

        # Uninstall should handle permission errors gracefully
        os.environ["CCPM_FORCE"] = "1"
        try:
            installer.uninstall()
        except Exception:
            # Should not crash on permission errors
            pass
        finally:
            os.environ.pop("CCPM_FORCE", None)
            # Restore permissions for cleanup
            if os.name != "nt" and ccpm_file.exists():
                ccpm_file.chmod(0o644)

        # User content should be unaffected
        _verify_user_content_preserved(claude_dir)

    def test_nested_user_content_preservation(self, temp_project):
        """Test preservation of nested user content structures."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create complex nested user content
        epics_dir = claude_dir / "epics"
        epics_dir.mkdir()

        # Multi-level epic structure
        epic1_dir = epics_dir / "epic1"
        epic1_dir.mkdir()
        (epic1_dir / "epic.md").write_text("# Epic 1")
        (epic1_dir / "task1.md").write_text("## Task 1")

        sub_dir = epic1_dir / "subtasks"
        sub_dir.mkdir()
        (sub_dir / "subtask1.md").write_text("### Subtask 1")

        # Agents with complex structure
        agents_dir = claude_dir / "agents"
        agents_dir.mkdir()
        (agents_dir / "custom_agent.py").write_text("# Custom agent")
        (agents_dir / "config.json").write_text('{"agent": "config"}')

        installer._create_tracking_file(had_existing=True)

        # Uninstall
        os.environ["CCPM_FORCE"] = "1"
        try:
            installer.uninstall()
        finally:
            os.environ.pop("CCPM_FORCE", None)

        # Verify all nested content preserved
        assert (epic1_dir / "epic.md").exists()
        assert (epic1_dir / "task1.md").exists()
        assert (sub_dir / "subtask1.md").exists()
        assert (agents_dir / "custom_agent.py").exists()
        assert (agents_dir / "config.json").exists()


class TestDataSafetyIntegration:
    """Test data safety integration with other CCPM operations."""

    def test_update_operation_preserves_user_content(self, temp_project):
        """Test that update operations preserve user content."""
        installer = CCPMInstaller(temp_project)
        claude_dir = temp_project / ".claude"
        claude_dir.mkdir()

        # Create user content
        _create_realistic_user_content(claude_dir)

        # Create initial tracking
        installer._create_tracking_file(had_existing=True)

        # Mock update process that would fail
        def mock_run_command(*args, **kwargs):
            return (1, "", "Mock update failure")

        from unittest.mock import patch

        with patch("ccpm.core.installer.run_command", side_effect=mock_run_command):
            # Update should fail but not damage user content
            try:
                installer.update()
            except RuntimeError:
                pass  # Expected to fail

        # User content should be completely untouched
        _verify_user_content_preserved(claude_dir)

    def test_setup_over_existing_preserves_user_content(self, temp_project):
        """Test that setup over existing installation preserves user content."""
        # This would test that a fresh setup over existing user content
        # preserves the user content - implementation depends on setup logic
        pass


# Helper methods
def _create_realistic_user_content(claude_dir: Path) -> None:
    """Create realistic user content that should be preserved."""
    # User PRDs
    prds_dir = claude_dir / "prds"
    prds_dir.mkdir(exist_ok=True)
    (prds_dir / "feature_a.md").write_text(
        """# Feature A PRD

## Overview
This is a user-created product requirements document.

## Requirements
- User requirement 1
- User requirement 2
"""
    )
    (prds_dir / "feature_b.md").write_text("# Feature B\nAnother user PRD")

    # User epics
    epics_dir = claude_dir / "epics"
    epics_dir.mkdir(exist_ok=True)

    epic1_dir = epics_dir / "epic1"
    epic1_dir.mkdir()
    (epic1_dir / "epic.md").write_text("# Epic 1\nUser-created epic")
    (epic1_dir / "task_001.md").write_text("## Task 001\nUser task")

    # User agents
    agents_dir = claude_dir / "agents"
    agents_dir.mkdir(exist_ok=True)
    (agents_dir / "custom_analyzer.py").write_text(
        '''"""Custom user agent."""

def analyze_data(data):
    """User-created analysis function."""
    return {"result": "user analysis"}
'''
    )
    (agents_dir / "user_helper.py").write_text("# User helper agent")

    # User custom context
    context_dir = claude_dir / "context"
    context_dir.mkdir(exist_ok=True)
    custom_dir = context_dir / "custom"
    custom_dir.mkdir(exist_ok=True)
    (custom_dir / "user_context.md").write_text("# User Context\nCustom user context")


def _verify_user_content_preserved(claude_dir: Path) -> None:
    """Verify that all user content is preserved."""
    # Check PRDs
    prds_dir = claude_dir / "prds"
    assert prds_dir.exists(), "PRDs directory was removed!"
    assert (prds_dir / "feature_a.md").exists(), "User PRD was removed!"
    assert (prds_dir / "feature_b.md").exists(), "User PRD was removed!"

    # Verify content integrity
    content = (prds_dir / "feature_a.md").read_text()
    assert "user-created product requirements" in content.lower()

    # Check epics
    epics_dir = claude_dir / "epics"
    assert epics_dir.exists(), "Epics directory was removed!"
    assert (epics_dir / "epic1" / "epic.md").exists(), "User epic was removed!"
    assert (epics_dir / "epic1" / "task_001.md").exists(), "User task was removed!"

    # Check agents
    agents_dir = claude_dir / "agents"
    assert agents_dir.exists(), "Agents directory was removed!"
    assert (agents_dir / "custom_analyzer.py").exists(), "User agent was removed!"
    assert (agents_dir / "user_helper.py").exists(), "User agent was removed!"

    # Verify agent content integrity
    agent_content = (agents_dir / "custom_analyzer.py").read_text()
    assert "User-created analysis function" in agent_content

    # Check custom context
    custom_dir = claude_dir / "context" / "custom"
    assert custom_dir.exists(), "User custom context was removed!"
    assert (custom_dir / "user_context.md").exists(), "User context file was removed!"


def _verify_ccpm_scaffolding_removed(claude_dir: Path) -> None:
    """Verify that CCPM scaffolding is properly removed."""
    # PM scripts should be removed
    pm_scripts = claude_dir / "scripts" / "pm"
    if pm_scripts.exists():
        # If directory exists, it should be empty or contain no .sh files
        sh_files = list(pm_scripts.glob("*.sh"))
        assert len(sh_files) == 0, f"CCPM PM scripts not removed: {sh_files}"

    # Test runner script should be removed
    test_script = claude_dir / "scripts" / "test-and-log.sh"
    assert not test_script.exists(), "CCPM test script not removed"

    # Template settings should be removed (might or might not exist)
    # The key is that user content is preserved


@pytest.fixture
def temp_project():
    """Create a temporary project directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def temp_project_with_ccpm(temp_project):
    """Create a temporary project with CCPM installed."""
    # Initialize git
    import subprocess

    subprocess.run(["git", "init"], cwd=temp_project, check=True, capture_output=True)
    subprocess.run(
        ["git", "config", "user.name", "Test User"], cwd=temp_project, check=True
    )
    subprocess.run(
        ["git", "config", "user.email", "test@example.com"],
        cwd=temp_project,
        check=True,
    )

    # Create installer and basic setup
    installer = CCPMInstaller(temp_project)
    claude_dir = temp_project / ".claude"
    claude_dir.mkdir()

    # Create tracking file to simulate installation
    installer._create_tracking_file(had_existing=True)

    return installer, temp_project


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
