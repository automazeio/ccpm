#!/usr/bin/env python3
"""
Test GitHub issue creation with real API - NO MOCKS

This test suite verifies that GitHub issues are never created with empty bodies,
especially when markdown files contain only frontmatter.
"""

import subprocess
import tempfile
import os
import json
import pytest
import uuid
import sys
from pathlib import Path

# Add parent directory to path to import ccpm modules
sys.path.insert(0, str(Path(__file__).parent.parent))
from ccpm.validation import (
    strip_frontmatter_safe,
    has_content_after_frontmatter,
    validate_body_file_has_content,
)


class TestGitHubIssueCreation:
    """Test GitHub issue creation with real API - NO MOCKS"""

    @classmethod
    def setup_class(cls):
        """Setup test environment"""
        # Get project root directory
        cls.project_root = Path(__file__).parent.parent.absolute()

        # Ensure we're in a git repo with GitHub remote
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"], capture_output=True, text=True
        )
        if result.returncode != 0:
            pytest.skip("Not in a git repository with remote")

        # Check if gh CLI is available
        result = subprocess.run(["which", "gh"], capture_output=True)
        if result.returncode != 0:
            pytest.skip("GitHub CLI (gh) not installed")

        # Get repo info
        result = subprocess.run(
            ["gh", "repo", "view", "--json", "nameWithOwner"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            pytest.skip("Unable to access GitHub repository")

        cls.repo = json.loads(result.stdout)["nameWithOwner"]
        cls.test_label = f"test-{uuid.uuid4().hex[:8]}"

        # Create test label for cleanup
        subprocess.run(
            [
                "gh",
                "label",
                "create",
                cls.test_label,
                "--description",
                "Test label for automated tests",
                "--color",
                "FF0000",
            ],
            capture_output=True,
        )

    @classmethod
    def teardown_class(cls):
        """Cleanup after all tests"""
        # Close all test issues
        result = subprocess.run(
            [
                "gh",
                "issue",
                "list",
                "--label",
                cls.test_label,
                "--state",
                "open",
                "--json",
                "number",
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode == 0:
            issues = json.loads(result.stdout)
            for issue in issues:
                subprocess.run(
                    ["gh", "issue", "close", str(issue["number"])], capture_output=True
                )

        # Delete test label
        subprocess.run(
            ["gh", "label", "delete", cls.test_label, "--yes"], capture_output=True
        )

    def test_empty_frontmatter_only_file(self):
        """Test that frontmatter-only files create issues with default content"""
        print("\n=== Testing frontmatter-only file ===")

        # Create a task file with only frontmatter
        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as f:
            f.write("---\n")
            f.write("title: Test Task Empty Frontmatter\n")
            f.write("status: pending\n")
            f.write("---\n")
            task_file = f.name

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Use Python function to strip frontmatter
            strip_frontmatter_safe(
                task_file, output_file, "Task implementation pending."
            )

            # Read the processed content
            with open(output_file, "r") as f:
                processed_content = f.read()

            print(f"Processed content: {processed_content}")

            # Create issue with the processed body
            result = subprocess.run(
                [
                    "gh",
                    "issue",
                    "create",
                    "--title",
                    "Test: Empty Frontmatter Only",
                    "--body-file",
                    output_file,
                    "--label",
                    self.test_label,
                ],
                capture_output=True,
                text=True,
            )

            if result.returncode != 0:
                print(f"Failed to create issue: {result.stderr}")
                pytest.fail(f"Failed to create issue: {result.stderr}")

            # Extract issue number from the URL that gh returns
            # Format: https://github.com/owner/repo/issues/123
            issue_url = result.stdout.strip()
            issue_num = issue_url.split("/")[-1]

            # Get the issue body
            verify_result = subprocess.run(
                ["gh", "issue", "view", issue_num, "--json", "body", "-q", ".body"],
                capture_output=True,
                text=True,
            )

            issue_body = verify_result.stdout.strip()

            print(f"Created issue #{issue_num}")
            print(f"Issue body: {issue_body}")

            # Verify issue was created with non-empty body
            assert issue_body != "", "Issue body should not be empty"
            assert (
                "pending" in issue_body.lower()
                or "implementation" in issue_body.lower()
            ), f"Expected default content, got: {issue_body}"

            # Clean up
            subprocess.run(["gh", "issue", "close", issue_num], capture_output=True)

        finally:
            os.unlink(task_file)
            if os.path.exists(output_file):
                os.unlink(output_file)

    def test_malformed_markdown_file(self):
        """Test handling of malformed markdown files"""
        print("\n=== Testing malformed markdown file ===")

        # Create malformed file (missing closing frontmatter)
        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as f:
            f.write("---\n")
            f.write("title: Malformed Test\n")
            # Missing closing ---
            f.write("Some content that should appear\n")
            f.write("Even without proper frontmatter closing\n")
            task_file = f.name

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Use Python function to handle malformed frontmatter
            strip_frontmatter_safe(
                task_file, output_file, "Malformed content handling."
            )

            # Check what was extracted
            with open(output_file, "r") as f:
                extracted_content = f.read()

            print(f"Extracted content: {extracted_content}")

            # Should handle gracefully - either extract content or use default
            assert len(extracted_content.strip()) > 0, "Should produce some output"
            # Should extract the content after incomplete frontmatter
            assert (
                "Some content" in extracted_content
                or "Malformed content" in extracted_content
            )

        finally:
            os.unlink(task_file)
            if os.path.exists(output_file):
                os.unlink(output_file)

    def test_large_content_file(self):
        """Test with large content files to ensure no truncation"""
        print("\n=== Testing large content file ===")

        # Create large content file
        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as f:
            f.write("---\n")
            f.write("title: Large Content Test\n")
            f.write("---\n")
            f.write("# Large Content Test\n\n")

            # Add 10KB of content
            for i in range(1000):
                f.write(f"Line {i}: " + "x" * 100 + "\n")

            task_file = f.name

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Use Python function to strip frontmatter
            strip_frontmatter_safe(task_file, output_file, "Large content test.")

            # Count lines and check content
            with open(output_file, "r") as f:
                content = f.read()
                lines = content.split("\n")

            line_count = len([l for l in lines if l])  # Count non-empty lines
            print(f"Line count: {line_count}")

            # Should have preserved all content lines
            assert line_count >= 1000, f"Should preserve all lines, got {line_count}"
            assert "Line 999:" in content, "Last line should be present"

            # Create issue
            result = subprocess.run(
                [
                    "gh",
                    "issue",
                    "create",
                    "--title",
                    "Test: Large Content",
                    "--body-file",
                    output_file,
                    "--label",
                    self.test_label,
                ],
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                # Extract issue number from URL
                issue_url = result.stdout.strip()
                issue_num = issue_url.split("/")[-1]

                # Get issue body to verify content preservation
                verify_result = subprocess.run(
                    ["gh", "issue", "view", issue_num, "--json", "body", "-q", ".body"],
                    capture_output=True,
                    text=True,
                )

                issue_body = verify_result.stdout
                assert (
                    len(issue_body) > 10000
                ), f"Large content should be preserved, got {len(issue_body)} chars"
                assert "Line 999" in issue_body, "Last line should be in issue body"

                # Clean up
                subprocess.run(["gh", "issue", "close", issue_num], capture_output=True)

        finally:
            os.unlink(task_file)
            if os.path.exists(output_file):
                os.unlink(output_file)

    def test_special_characters_in_content(self):
        """Test handling of special characters and code blocks"""
        print("\n=== Testing special characters ===")

        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False, encoding="utf-8") as f:
            f.write("---\n")
            f.write("title: Special Chars Test\n")
            f.write("---\n")
            f.write("# Special Characters Test\n\n")
            f.write("```bash\n")
            f.write('echo "$HOME" && echo "test"\n')
            f.write("```\n\n")
            f.write("Special chars: `~!@#$%^&*()_+-=[]{}|;':\",./<>?\n")
            f.write("Unicode: 中文, العربية, עברית, 🚀💻🎨\n")
            task_file = f.name

        output_file = tempfile.mktemp(suffix=".md")

        try:
            # Use Python function to strip frontmatter
            strip_frontmatter_safe(task_file, output_file, "Special chars test.")

            # Check content preservation
            with open(output_file, "r", encoding="utf-8") as f:
                content = f.read()

            assert "```bash" in content, "Code block should be preserved"
            assert "$HOME" in content, "Variables should be preserved"
            assert "🚀" in content, "Emoji should be preserved"

            print("Code block preserved")
            print("Variables preserved")
            print("Emoji preserved")

            # Create issue
            result = subprocess.run(
                [
                    "gh",
                    "issue",
                    "create",
                    "--title",
                    "Test: Special Characters",
                    "--body-file",
                    output_file,
                    "--label",
                    self.test_label,
                ],
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                # Extract issue number from URL
                issue_url = result.stdout.strip()
                issue_num = issue_url.split("/")[-1]
                subprocess.run(["gh", "issue", "close", issue_num], capture_output=True)

        finally:
            os.unlink(task_file)
            if os.path.exists(output_file):
                os.unlink(output_file)

    def test_validate_body_file_function(self):
        """Test the validate_body_file utility function"""
        print("\n=== Testing validate_body_file function ===")

        # Test 1: Non-existent file
        print("Test 1: Non-existent file")
        from io import StringIO

        old_stderr = sys.stderr
        sys.stderr = StringIO()

        result = validate_body_file_has_content("/tmp/nonexistent.md", "test-context")

        stderr_output = sys.stderr.getvalue()
        sys.stderr = old_stderr

        assert result is False, "Should return False for non-existent file"
        assert "does not exist" in stderr_output
        print("✓ Correctly detected non-existent file")

        # Test 2: Empty file
        print("Test 2: Empty file")
        empty_file = tempfile.mktemp(suffix=".md")
        Path(empty_file).write_text("")

        old_stderr = sys.stderr
        sys.stderr = StringIO()

        result = validate_body_file_has_content(empty_file, "task:test")

        sys.stderr = old_stderr

        content = Path(empty_file).read_text()
        assert result is True
        assert len(content) > 0, "Should add default content to empty file"
        assert "Task Details" in content
        print("✓ Added default content to empty file")
        os.unlink(empty_file)

        # Test 3: File with content
        print("Test 3: File with content")
        content_file = tempfile.mktemp(suffix=".md")
        original_content = "This is existing content that should be preserved because it is long enough to meet the minimum character requirements."
        Path(content_file).write_text(original_content)

        old_stderr = sys.stderr
        sys.stderr = StringIO()

        result = validate_body_file_has_content(content_file, "task:test")

        sys.stderr = old_stderr

        content = Path(content_file).read_text()
        assert result is True
        assert content == original_content, "Should preserve existing content"
        print("✓ Preserved existing content")
        os.unlink(content_file)

    def test_has_content_after_frontmatter_function(self):
        """Test the has_content_after_frontmatter utility function"""
        print("\n=== Testing has_content_after_frontmatter function ===")

        # Create test files
        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as f:
            f.write("---\n")
            f.write("title: Only Frontmatter\n")
            f.write("---\n")
            only_fm = f.name

        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as f:
            f.write("---\n")
            f.write("title: With Content\n")
            f.write("---\n")
            f.write("This has content after frontmatter\n")
            with_content = f.name

        try:
            print("Testing file with only frontmatter:")
            result = has_content_after_frontmatter(only_fm)
            assert result is False, "Should not detect content after frontmatter"
            print("✓ Correctly detected no content after frontmatter")

            print("Testing file with content:")
            result = has_content_after_frontmatter(with_content)
            assert result is True, "Should detect content after frontmatter"
            print("✓ Correctly detected content after frontmatter")

        finally:
            os.unlink(only_fm)
            os.unlink(with_content)


if __name__ == "__main__":
    # Run tests with verbose output
    pytest.main([__file__, "-v", "-s"])
