"""Integration tests for GitHub issue creation with validation."""

import os
import shutil
import sys
import tempfile
from pathlib import Path

import pytest

# Add parent directory to path to import ccpm modules
sys.path.insert(0, str(Path(__file__).parent.parent))
from ccpm.validation import (
    validate_body_file_has_content,
    strip_frontmatter_safe,
    has_placeholder_text,
)


class TestGitHubIssueValidation:
    """Test GitHub issue creation with body validation."""

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

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Use Python function to strip frontmatter
            strip_frontmatter_safe(str(epic_file), output_file)

            # Validate and fix the body file
            result = validate_body_file_has_content(output_file, "epic:test-empty-epic")
            assert result is True

            # Read the processed content
            content = Path(output_file).read_text()
            assert "Epic Implementation" in content
            assert "Objectives" in content
            assert "Technical Approach" in content

            # Verify the file has sufficient content
            assert len(content.replace(" ", "").replace("\n", "")) >= 100
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
            if Path(output_file).exists():
                os.unlink(output_file)

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

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Use Python function to strip frontmatter
            strip_frontmatter_safe(str(task_file), output_file)

            # Validate and fix the body file
            result = validate_body_file_has_content(output_file, "task:Empty Task")
            assert result is True

            # Read the processed content
            content = Path(output_file).read_text()
            assert "Task Details" in content
            assert "Acceptance Criteria" in content

            # Verify content meets minimum requirements
            assert len(content.replace(" ", "").replace("\n", "")) >= 50
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
            if Path(output_file).exists():
                os.unlink(output_file)

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

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Use Python function to strip frontmatter
            strip_frontmatter_safe(str(task_file), output_file)

            # The content should have placeholders initially
            initial_content = Path(output_file).read_text()
            assert has_placeholder_text(initial_content)

            # Validate and fix the body file
            result = validate_body_file_has_content(output_file, "task:Placeholder Task", 50)
            assert result is True

            # Check that placeholders were replaced
            content = Path(output_file).read_text()
            assert "TODO: Add implementation details" not in content
            assert "TBD" not in content
            assert "Task Details" in content
        finally:
            shutil.rmtree(test_dir, ignore_errors=True)
            if Path(output_file).exists():
                os.unlink(output_file)

    def test_progress_update_validation(self):
        """Test progress update comments get validated."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("WIP")  # Very minimal progress update
            temp_path = f.name

        try:
            # Validate and fix the body file
            result = validate_body_file_has_content(temp_path, "progress-update:issue-123")
            assert result is True

            # Read the processed content
            content = Path(temp_path).read_text()
            assert "Progress Update" in content
            assert "Recent Activity" in content
            assert "Next Steps" in content

            # Should meet minimum for comments (30 chars)
            assert len(content.replace(" ", "").replace("\n", "")) >= 30
        finally:
            os.unlink(temp_path)

    def test_completion_comment_validation(self):
        """Test completion comments get appropriate content."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("Done")  # Too minimal
            temp_path = f.name

        try:
            # Validate and fix the body file
            result = validate_body_file_has_content(temp_path, "completion:issue-456", 30)
            assert result is True

            # Read the processed content
            content = Path(temp_path).read_text()
            assert "Task Completed" in content
            assert "Deliverables" in content
            assert "Verification" in content
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
            # Validate the body file
            result = validate_body_file_has_content(temp_path, "refresh:epic-feature-x", 30)
            assert result is True

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
            # Validate and fix the body file
            result = validate_body_file_has_content(temp_path, "edit:issue-789", 30)
            assert result is True

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
            # Check that placeholders are detected
            assert has_placeholder_text(test_content)

            # Validate and fix the body file
            result = validate_body_file_has_content(temp_path, "task:multi-placeholder", 50)
            assert result is True

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

    def test_github_api_validation_simulation(self):
        """Simulate GitHub issue creation with validation (doesn't actually create issue)."""
        # Create a test file that would fail without validation
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("""---
test: true
---""")
            temp_path = f.name

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Strip frontmatter
            strip_frontmatter_safe(temp_path, output_file)

            # Validate and fix
            result = validate_body_file_has_content(output_file, "test-issue", 50)
            assert result is True

            # Verify the body file is now valid for GitHub
            content = Path(output_file).read_text()
            assert len(content) > 0
            assert content.strip() != ""
            assert len(content.replace(" ", "").replace("\n", "")) >= 50
        finally:
            os.unlink(temp_path)
            if Path(output_file).exists():
                os.unlink(output_file)