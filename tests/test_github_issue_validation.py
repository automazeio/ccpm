"""Integration tests for GitHub issue creation with validation."""

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest


class TestGitHubIssueValidation:
    """Test GitHub issue creation with body validation."""

    @pytest.fixture(autouse=True)
    def setup(self):
        """Set up test environment."""
        self.utils_path = Path(__file__).parent.parent / "ccpm/claude_template/scripts/utils.sh"
        assert self.utils_path.exists(), f"utils.sh not found at {self.utils_path}"

    def test_epic_sync_with_empty_body(self):
        """Test epic-sync handles empty epic body correctly."""
        # Create test epic with only frontmatter
        test_dir = Path(".claude/epics/test-empty-epic")
        test_dir.mkdir(parents=True, exist_ok=True)

        epic_file = test_dir / "epic.md"
        epic_file.write_text("""---
name: Test Empty Epic
status: backlog
created: 2024-01-01T00:00:00Z
---""")

        try:
            # Simulate the epic-sync body preparation
            result = subprocess.run(
                f'sed "1,/^---$/d; 1,/^---$/d" {epic_file} > /tmp/test-epic-body.md && '
                f'source {self.utils_path} && '
                f'min_length=$(get_min_content_length "epic:test-empty-epic") && '
                f'validate_body_file_has_content "/tmp/test-epic-body.md" "epic:test-empty-epic" "$min_length" && '
                f'cat /tmp/test-epic-body.md',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            assert "Epic Implementation" in result.stdout
            assert "Objectives" in result.stdout
            assert "Technical Approach" in result.stdout

            # Verify the file has sufficient content
            content = Path("/tmp/test-epic-body.md").read_text()
            assert len(content.replace(" ", "").replace("\n", "")) >= 100
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
            if Path("/tmp/test-epic-body.md").exists():
                os.unlink("/tmp/test-epic-body.md")

    def test_task_creation_with_empty_body(self):
        """Test task creation handles empty task body correctly."""
        test_dir = Path(".claude/epics/test-epic")
        test_dir.mkdir(parents=True, exist_ok=True)

        task_file = test_dir / "001.md"
        task_file.write_text("""---
name: Empty Task
parallel: true
depends_on: []
---""")

        try:
            result = subprocess.run(
                f'sed "1,/^---$/d; 1,/^---$/d" {task_file} > /tmp/test-task-body.md && '
                f'source {self.utils_path} && '
                f'min_length=$(get_min_content_length "task:Empty Task") && '
                f'validate_body_file_has_content "/tmp/test-task-body.md" "task:Empty Task" "$min_length" && '
                f'cat /tmp/test-task-body.md',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            assert "Task Details" in result.stdout
            assert "Acceptance Criteria" in result.stdout

            # Verify content meets minimum requirements
            content = Path("/tmp/test-task-body.md").read_text()
            assert len(content.replace(" ", "").replace("\n", "")) >= 50
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
            if Path("/tmp/test-task-body.md").exists():
                os.unlink("/tmp/test-task-body.md")

    def test_task_with_placeholder_content(self):
        """Test task with placeholder text gets proper content."""
        test_dir = Path(".claude/epics/test-epic")
        test_dir.mkdir(parents=True, exist_ok=True)

        task_file = test_dir / "002.md"
        task_file.write_text("""---
name: Placeholder Task
parallel: false
---

# Task

TODO: Add implementation details

## Testing
TBD""")

        try:
            result = subprocess.run(
                f'sed "1,/^---$/d; 1,/^---$/d" {task_file} > /tmp/test-task-body.md && '
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "/tmp/test-task-body.md" "task:Placeholder Task" 50 && '
                f'cat /tmp/test-task-body.md',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0

            # Check that placeholders were replaced
            content = result.stdout
            assert "TODO: Add implementation details" not in content
            assert "TBD" not in content
            assert "Task Details" in content
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
            if Path("/tmp/test-task-body.md").exists():
                os.unlink("/tmp/test-task-body.md")

    def test_progress_update_validation(self):
        """Test progress update comments get validated."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("WIP")  # Very minimal progress update
            temp_path = f.name

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'min_length=$(get_min_content_length "progress-update:issue-123") && '
                f'validate_body_file_has_content "{temp_path}" "progress-update:issue-123" "$min_length" && '
                f'cat "{temp_path}"',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            assert "Progress Update" in result.stdout
            assert "Recent Activity" in result.stdout
            assert "Next Steps" in result.stdout

            # Should meet minimum for comments (30 chars)
            content = Path(temp_path).read_text()
            assert len(content.replace(" ", "").replace("\n", "")) >= 30
        finally:
            os.unlink(temp_path)

    def test_completion_comment_validation(self):
        """Test completion comments get appropriate content."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("Done")  # Too minimal
            temp_path = f.name

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "completion:issue-456" 30 && '
                f'cat "{temp_path}"',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            assert "Task Completed" in result.stdout
            assert "Deliverables" in result.stdout
            assert "Verification" in result.stdout
        finally:
            os.unlink(temp_path)

    def test_epic_refresh_validation(self):
        """Test epic refresh preserves existing content when sufficient."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            content = """# Epic: Feature X

## Overview
This epic implements the new feature X with comprehensive functionality.

## Tasks
- [ ] #123 Task 1
- [ ] #124 Task 2

## Progress
Currently at 50% completion."""
            f.write(content)
            temp_path = f.name

        original_content = content

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "refresh:epic-feature-x" 30 && '
                f'cat "{temp_path}"',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            # Content should be preserved since it's sufficient
            assert Path(temp_path).read_text() == original_content
        finally:
            os.unlink(temp_path)

    def test_edit_validation_with_minimal_content(self):
        """Test issue edit with minimal content gets enhanced."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("x")  # Extremely minimal
            temp_path = f.name

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "edit:issue-789" 30 && '
                f'cat "{temp_path}"',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0

            # For edit context with very minimal content, should add note
            content = Path(temp_path).read_text()
            assert "Updated via CCPM" in content or len(content.replace(" ", "").replace("\n", "")) >= 30
        finally:
            os.unlink(temp_path)

    def test_multiple_placeholder_patterns(self):
        """Test detection of various placeholder patterns."""
        test_content = """# Implementation

## Section 1
Insert details here

## Section 2
To be added later

## Section 3
FIXME: Complete this section

## Section 4
Work in progress

## Section 5
Coming soon"""

        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write(test_content)
            temp_path = f.name

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "task:multi-placeholder" 50',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            assert "Placeholder text detected" in result.stderr

            # All placeholders should be gone
            content = Path(temp_path).read_text()
            assert "Insert details here" not in content
            assert "To be added later" not in content
            assert "FIXME" not in content
            assert "Work in progress" not in content
            assert "Coming soon" not in content

            # Should have proper task content
            assert "Task Details" in content
        finally:
            os.unlink(temp_path)

    @pytest.mark.skipif(
        subprocess.run("gh auth status", shell=True, capture_output=True).returncode != 0,
        reason="GitHub CLI not authenticated"
    )
    def test_github_api_validation_simulation(self):
        """Simulate GitHub issue creation with validation (doesn't actually create issue)."""
        # Create a test file that would fail without validation
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("""---
test: true
---""")
            temp_path = f.name

        try:
            # Strip frontmatter
            subprocess.run(
                f'sed "1,/^---$/d; 1,/^---$/d" {temp_path} > /tmp/test-body.md',
                shell=True,
                executable='/bin/bash'
            )

            # Validate and fix
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "/tmp/test-body.md" "test-issue" 50',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0

            # Verify the body file is now valid for GitHub
            content = Path("/tmp/test-body.md").read_text()
            assert len(content) > 0
            assert content.strip() != ""
            assert len(content.replace(" ", "").replace("\n", "")) >= 50
        finally:
            os.unlink(temp_path)
            if Path("/tmp/test-body.md").exists():
                os.unlink("/tmp/test-body.md")