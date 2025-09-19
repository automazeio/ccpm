"""Tests for GitHub issue body file validation functionality."""

import os
import sys
import tempfile
from io import StringIO
from pathlib import Path

import pytest

from ccpm.validation import (
    get_min_content_length,
    has_placeholder_text,
    validate_body_file_has_content,
    has_content_after_frontmatter,
    get_default_content
)


class TestValidationFunction:
    """Test the validation functions."""

    def test_validate_empty_file(self):
        """Test validation catches empty files and adds default content."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("")  # Empty file
            temp_path = f.name

        try:
            # Capture stderr
            old_stderr = sys.stderr
            sys.stderr = StringIO()

            # Run validation
            result = validate_body_file_has_content(temp_path, "task:test", 50)

            # Get stderr output
            stderr_output = sys.stderr.getvalue()
            sys.stderr = old_stderr

            # Should succeed
            assert result is True

            # File should now have content
            content = Path(temp_path).read_text()
            assert len(content) > 0, "File is still empty after validation"
            assert "Task Details" in content, "Default task content not added"

            # Check warnings were printed
            assert "insufficient content" in stderr_output
            assert "Content length: 0 chars" in stderr_output
        finally:
            os.unlink(temp_path)

    def test_validate_whitespace_only_file(self):
        """Test validation catches whitespace-only files."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("   \n\t\n   ")  # Only whitespace
            temp_path = f.name

        try:
            old_stderr = sys.stderr
            sys.stderr = StringIO()

            result = validate_body_file_has_content(temp_path, "task:test", 50)

            stderr_output = sys.stderr.getvalue()
            sys.stderr = old_stderr

            assert result is True
            content = Path(temp_path).read_text()
            assert "Task Details" in content

            # Check that whitespace was correctly identified as insufficient
            assert "Content length: 0 chars" in stderr_output
        finally:
            os.unlink(temp_path)

    def test_validate_non_empty_file(self):
        """Test validation passes files with actual content."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("# Task Description\n\nThis is a comprehensive task description with enough content to meet the minimum requirements.")
            temp_path = f.name

        original_content = Path(temp_path).read_text()

        try:
            old_stderr = sys.stderr
            sys.stderr = StringIO()

            result = validate_body_file_has_content(temp_path, "task:test", 50)

            stderr_output = sys.stderr.getvalue()
            sys.stderr = old_stderr

            assert result is True
            # Content should remain unchanged
            assert Path(temp_path).read_text() == original_content
            # No warnings should be printed
            assert "insufficient content" not in stderr_output
        finally:
            os.unlink(temp_path)

    def test_validate_missing_file(self):
        """Test validation handles missing files correctly."""
        old_stderr = sys.stderr
        sys.stderr = StringIO()

        result = validate_body_file_has_content("/nonexistent/file.md", "test-context", 50)

        stderr_output = sys.stderr.getvalue()
        sys.stderr = old_stderr

        # Should fail
        assert result is False
        assert "does not exist" in stderr_output

    def test_placeholder_text_detection(self):
        """Test that common placeholder texts are detected and replaced."""
        placeholders = [
            "Insert description here",
            "TODO: Add content",
            "TBD",
            "Description to be added",
            "FIXME: Write this",
            "XXX",
            "Coming soon",
            "Work in progress",
            "Fill in details here",
            "Update this section"
        ]

        for placeholder in placeholders:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
                f.write(f"# Task\n\n{placeholder}")
                temp_path = f.name

            try:
                old_stderr = sys.stderr
                sys.stderr = StringIO()

                validate_body_file_has_content(temp_path, "task:test", 50)

                stderr_output = sys.stderr.getvalue()
                sys.stderr = old_stderr

                # Should detect and replace placeholder
                assert "Placeholder text detected" in stderr_output, f"Failed to detect placeholder: {placeholder}"

                # Should have substantial content now
                content = Path(temp_path).read_text()
                assert len(content.replace(" ", "").replace("\n", "")) > 50
                assert placeholder not in content, f"Placeholder '{placeholder}' still in content"
                assert "Task Details" in content  # Should have real content
            finally:
                os.unlink(temp_path)

    def test_minimum_content_length(self):
        """Test that files with too little content are caught."""
        test_cases = [
            ("", 50, False),  # Empty - should fail
            ("Hi", 50, False),  # Too short - should fail
            ("This is a task", 50, False),  # Still too short - should fail
            ("This is a proper task description with enough detail to meet the minimum content requirements for a GitHub issue", 50, True),  # Should pass
        ]

        for content, min_chars, should_pass in test_cases:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
                f.write(content)
                temp_path = f.name

            original_content = content

            try:
                old_stderr = sys.stderr
                sys.stderr = StringIO()

                validate_body_file_has_content(temp_path, "task:test", min_chars)

                stderr_output = sys.stderr.getvalue()
                sys.stderr = old_stderr

                new_content = Path(temp_path).read_text()

                if should_pass:
                    # Content should be unchanged
                    assert new_content == original_content
                    assert "insufficient content" not in stderr_output
                else:
                    # Should have added default content
                    assert len(new_content.replace(" ", "").replace("\n", "")) >= min_chars
                    assert "insufficient content" in stderr_output
            finally:
                os.unlink(temp_path)

    def test_context_specific_content(self):
        """Test that different contexts get appropriate detailed content."""
        contexts = [
            ("epic:feature-x", 100, ["Epic Implementation", "Objectives", "Technical Approach"]),
            ("task:implement-y", 50, ["Task Details", "Acceptance Criteria", "Implementation Notes"]),
            ("progress-update:issue-123", 30, ["Progress Update", "Recent Activity", "Next Steps"]),
            ("completion:issue-456", 30, ["Task Completed", "Deliverables", "Verification"]),
        ]

        for context, min_chars, expected_phrases in contexts:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
                f.write("Too short")  # Intentionally insufficient
                temp_path = f.name

            try:
                old_stderr = sys.stderr
                sys.stderr = StringIO()

                validate_body_file_has_content(temp_path, context, min_chars)

                sys.stderr = old_stderr

                content = Path(temp_path).read_text()

                # Check for context-specific content
                for phrase in expected_phrases:
                    assert phrase in content, f"Expected '{phrase}' in content for {context}"

                # Ensure sufficient length
                assert len(content.replace(" ", "").replace("\n", "")) >= min_chars
            finally:
                os.unlink(temp_path)

    def test_whitespace_counted_correctly(self):
        """Test that whitespace doesn't count toward content length."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            # Lots of whitespace but no real content
            f.write("   \n\n\n\t\t\t   \n\n\n   Word   \n\n\n\t\t\t")
            temp_path = f.name

        try:
            old_stderr = sys.stderr
            sys.stderr = StringIO()

            validate_body_file_has_content(temp_path, "task:test", 50)

            stderr_output = sys.stderr.getvalue()
            sys.stderr = old_stderr

            # Should detect insufficient content (only "Word" counts = 4 chars)
            assert "insufficient content" in stderr_output
            assert "Content length: 4 chars" in stderr_output

            # Should have added proper content
            content = Path(temp_path).read_text()
            assert "Task Details" in content
        finally:
            os.unlink(temp_path)

    def test_mixed_placeholder_and_content(self):
        """Test files with some real content mixed with placeholders."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("""# Task Implementation

This task implements the user authentication module.

## Details
TODO: Add more details here

## Testing
Insert test plan here""")
            temp_path = f.name

        try:
            old_stderr = sys.stderr
            sys.stderr = StringIO()

            validate_body_file_has_content(temp_path, "task:auth", 50)

            stderr_output = sys.stderr.getvalue()
            sys.stderr = old_stderr

            # Should detect placeholder text even with some real content
            assert "Placeholder text detected" in stderr_output

            # Should replace with proper content
            content = Path(temp_path).read_text()
            assert "TODO: Add more details" not in content
            assert "Insert test plan here" not in content
        finally:
            os.unlink(temp_path)

    def test_get_min_content_length(self):
        """Test that get_min_content_length returns correct values for different contexts."""
        test_cases = [
            ("epic:test", 100),  # Default epic minimum
            ("task:test", 50),  # Default task minimum
            ("issue:test", 50),  # Issues same as tasks
            ("comment:test", 30),  # Comment minimum
            ("update:test", 30),  # Update minimum
            ("progress-update:test", 30),  # Progress update minimum
            ("unknown:test", 50),  # Default for unknown
        ]

        for context, expected_min in test_cases:
            result = get_min_content_length(context)
            assert result == expected_min, f"Expected {expected_min} for {context}, got {result}"

    def test_configurable_thresholds(self):
        """Test that environment variables control minimum content thresholds."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("Short content")
            temp_path = f.name

        try:
            # Test with custom threshold
            os.environ['CCPM_MIN_TASK_CONTENT'] = '200'

            old_stderr = sys.stderr
            sys.stderr = StringIO()

            min_length = get_min_content_length("task:test")
            assert min_length == 200

            validate_body_file_has_content(temp_path, "task:test")

            stderr_output = sys.stderr.getvalue()
            sys.stderr = old_stderr

            assert "insufficient content" in stderr_output

            # Content should be enhanced to meet custom minimum
            content = Path(temp_path).read_text()
            # The default content should be added
            assert "Task Details" in content
        finally:
            os.unlink(temp_path)
            # Clean up environment
            if 'CCPM_MIN_TASK_CONTENT' in os.environ:
                del os.environ['CCPM_MIN_TASK_CONTENT']

    def test_has_content_after_frontmatter_function(self):
        """Test the has_content_after_frontmatter function."""
        # Create test files
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("---\n")
            f.write("title: Only Frontmatter\n")
            f.write("---\n")
            only_fm = f.name

        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("---\n")
            f.write("title: With Content\n")
            f.write("---\n")
            f.write("This has content after frontmatter\n")
            with_content = f.name

        try:
            # Test file with only frontmatter
            assert not has_content_after_frontmatter(only_fm), "Should not detect content"

            # Test file with content
            assert has_content_after_frontmatter(with_content), "Should detect content"

        finally:
            os.unlink(only_fm)
            os.unlink(with_content)

    def test_placeholder_detection_function(self):
        """Test the has_placeholder_text function directly."""
        # Should detect placeholders
        assert has_placeholder_text("TODO: implement this")
        assert has_placeholder_text("Insert description here")
        assert has_placeholder_text("TBD")
        assert has_placeholder_text("This is a FIXME note")
        assert has_placeholder_text("Work in progress")

        # Should not detect false positives
        assert not has_placeholder_text("This is a complete description")
        assert not has_placeholder_text("The todo list application")  # "todo" as part of word
        assert not has_placeholder_text("Wipe the surface clean")  # "wip" as part of word