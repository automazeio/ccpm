"""Tests for GitHub issue body file validation functionality."""

import os
import subprocess
import tempfile
from pathlib import Path

import pytest


class TestValidationFunction:
    """Test the validate_body_file_has_content function."""

    @pytest.fixture(autouse=True)
    def setup(self):
        """Set up test environment."""
        # Get the path to utils.sh
        self.utils_path = Path(__file__).parent.parent / "ccpm/claude_template/scripts/utils.sh"
        assert self.utils_path.exists(), f"utils.sh not found at {self.utils_path}"

    def test_validate_empty_file(self):
        """Test validation catches empty files and adds default content."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("")  # Empty file
            temp_path = f.name

        try:
            # Source utils and run validation
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "task:test" 50',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            # Should succeed (return 0)
            assert result.returncode == 0, f"Validation failed: {result.stderr}"

            # File should now have content
            content = Path(temp_path).read_text()
            assert len(content) > 0, "File is still empty after validation"
            assert "Task Details" in content, "Default task content not added"

            # Check warnings were printed
            assert "insufficient content" in result.stderr
            assert "Content length: 0 chars" in result.stderr
        finally:
            os.unlink(temp_path)

    def test_validate_whitespace_only_file(self):
        """Test validation catches whitespace-only files."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("   \n\t\n   ")  # Only whitespace
            temp_path = f.name

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "task:test" 50',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            content = Path(temp_path).read_text()
            assert "Task Details" in content

            # Check that whitespace was correctly identified as insufficient
            assert "Content length: 0 chars" in result.stderr
        finally:
            os.unlink(temp_path)

    def test_validate_non_empty_file(self):
        """Test validation passes files with actual content."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("# Task Description\n\nThis is a comprehensive task description with enough content to meet the minimum requirements.")
            temp_path = f.name

        original_content = Path(temp_path).read_text()

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "task:test" 50',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            # Content should remain unchanged
            assert Path(temp_path).read_text() == original_content
            # No warnings should be printed
            assert "insufficient content" not in result.stderr
        finally:
            os.unlink(temp_path)

    def test_validate_missing_file(self):
        """Test validation handles missing files correctly."""
        result = subprocess.run(
            f'source {self.utils_path} && '
            f'validate_body_file_has_content "/nonexistent/file.md" "test-context" 50',
            shell=True,
            capture_output=True,
            text=True,
            executable='/bin/bash'
        )

        # Should fail (return 1)
        assert result.returncode == 1
        assert "does not exist" in result.stderr

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
                result = subprocess.run(
                    f'source {self.utils_path} && '
                    f'validate_body_file_has_content "{temp_path}" "task:test" 50',
                    shell=True,
                    capture_output=True,
                    text=True,
                    executable='/bin/bash'
                )

                # Should detect and replace placeholder
                assert "Placeholder text detected" in result.stderr, f"Failed to detect placeholder: {placeholder}"

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
                result = subprocess.run(
                    f'source {self.utils_path} && '
                    f'validate_body_file_has_content "{temp_path}" "task:test" {min_chars}',
                    shell=True,
                    capture_output=True,
                    text=True,
                    executable='/bin/bash'
                )

                new_content = Path(temp_path).read_text()

                if should_pass:
                    # Content should be unchanged
                    assert new_content == original_content
                    assert "insufficient content" not in result.stderr
                else:
                    # Should have added default content
                    assert len(new_content.replace(" ", "").replace("\n", "")) >= min_chars
                    assert "insufficient content" in result.stderr
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
                subprocess.run(
                    f'source {self.utils_path} && '
                    f'validate_body_file_has_content "{temp_path}" "{context}" {min_chars}',
                    shell=True,
                    capture_output=True,
                    text=True,
                    executable='/bin/bash'
                )

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
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "task:test" 50',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            # Should detect insufficient content (only "Word" counts = 4 chars)
            assert "insufficient content" in result.stderr
            assert "Content length: 4 chars" in result.stderr

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
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_has_content "{temp_path}" "task:auth" 50',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            # Should detect placeholder text even with some real content
            assert "Placeholder text detected" in result.stderr

            # Should replace with proper content
            content = Path(temp_path).read_text()
            assert "TODO: Add more details" not in content
            assert "Insert test plan here" not in content
        finally:
            os.unlink(temp_path)

    def test_get_min_content_length(self):
        """Test that get_min_content_length returns correct values for different contexts."""
        test_cases = [
            ("epic:test", "100"),  # Default epic minimum
            ("task:test", "50"),  # Default task minimum
            ("issue:test", "50"),  # Issues same as tasks
            ("comment:test", "30"),  # Comment minimum
            ("update:test", "30"),  # Update minimum
            ("progress-update:test", "30"),  # Progress update minimum
            ("unknown:test", "50"),  # Default for unknown
        ]

        for context, expected_min in test_cases:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'get_min_content_length "{context}"',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert result.returncode == 0
            assert result.stdout.strip() == expected_min, f"Expected {expected_min} for {context}, got {result.stdout.strip()}"

    def test_configurable_thresholds(self):
        """Test that environment variables control minimum content thresholds."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("Short content")
            temp_path = f.name

        try:
            # Test with custom threshold
            result = subprocess.run(
                f'export CCPM_MIN_TASK_CONTENT=200 && '
                f'source {self.utils_path} && '
                f'min_length=$(get_min_content_length "task:test") && '
                f'echo "Min length: $min_length" && '
                f'validate_body_file_has_content "{temp_path}" "task:test" "$min_length"',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            assert "Min length: 200" in result.stdout
            assert "insufficient content" in result.stderr

            # Content should be enhanced to meet custom minimum
            content = Path(temp_path).read_text()
            # The default content should be added
            assert "Task Details" in content
        finally:
            os.unlink(temp_path)

    def test_backward_compatibility(self):
        """Test that validate_body_file_not_empty still works for backward compatibility."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("")  # Empty file
            temp_path = f.name

        try:
            result = subprocess.run(
                f'source {self.utils_path} && '
                f'validate_body_file_not_empty "{temp_path}" "task:test"',
                shell=True,
                capture_output=True,
                text=True,
                executable='/bin/bash'
            )

            # Should succeed and add content
            assert result.returncode == 0
            content = Path(temp_path).read_text()
            assert len(content) > 0
        finally:
            os.unlink(temp_path)