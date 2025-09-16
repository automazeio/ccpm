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


class TestGitHubIssueCreation:
    """Test GitHub issue creation with real API - NO MOCKS"""

    @classmethod
    def setup_class(cls):
        """Setup test environment"""
        # Get project root directory
        import pathlib
        cls.project_root = pathlib.Path(__file__).parent.parent
        cls.utils_path = cls.project_root / ".claude" / "scripts" / "pm" / "lib" / "utils.sh"

        # Check if utils.sh exists
        if not cls.utils_path.exists():
            pytest.skip(f"Utils script not found at {cls.utils_path}")

        # Ensure we're in a git repo with GitHub remote
        result = subprocess.run(['git', 'remote', 'get-url', 'origin'],
                              capture_output=True, text=True)
        if result.returncode != 0:
            pytest.skip("Not in a git repository with remote")

        # Check if gh CLI is available
        result = subprocess.run(['which', 'gh'], capture_output=True)
        if result.returncode != 0:
            pytest.skip("GitHub CLI (gh) not installed")

        # Get repo info
        result = subprocess.run(['gh', 'repo', 'view', '--json', 'nameWithOwner'],
                              capture_output=True, text=True)
        if result.returncode != 0:
            pytest.skip("Unable to access GitHub repository")

        cls.repo = json.loads(result.stdout)['nameWithOwner']
        cls.test_label = f"test-{uuid.uuid4().hex[:8]}"

        # Create test label for cleanup
        subprocess.run(['gh', 'label', 'create', cls.test_label,
                       '--description', 'Test label for automated tests',
                       '--color', 'FF0000'], capture_output=True)

    @classmethod
    def teardown_class(cls):
        """Cleanup after all tests"""
        # Close all test issues
        result = subprocess.run([
            'gh', 'issue', 'list',
            '--label', cls.test_label,
            '--state', 'open',
            '--json', 'number'
        ], capture_output=True, text=True)

        if result.returncode == 0:
            issues = json.loads(result.stdout)
            for issue in issues:
                subprocess.run(['gh', 'issue', 'close', str(issue['number'])],
                             capture_output=True)

        # Delete test label
        subprocess.run(['gh', 'label', 'delete', cls.test_label, '--yes'],
                      capture_output=True)

    def test_empty_frontmatter_only_file(self):
        """Test that frontmatter-only files create issues with default content"""
        print("\n=== Testing frontmatter-only file ===")

        # Create a task file with only frontmatter
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("---\n")
            f.write("title: Test Task Empty Frontmatter\n")
            f.write("status: pending\n")
            f.write("---\n")
            task_file = f.name

        try:
            # Source utils and use strip_frontmatter_safe
            test_script = f"""
            source "{self.utils_path}"
            strip_frontmatter_safe "{task_file}" /tmp/test-body.md "Task implementation pending."

            # Create issue with the processed body
            issue_url=$(gh issue create \\
                --title "Test: Empty Frontmatter Only" \\
                --body-file /tmp/test-body.md \\
                --label "{self.test_label}")

            # Extract issue number from URL
            issue_num=$(echo "$issue_url" | grep -oE '[0-9]+$')

            # Get the issue body
            gh issue view "$issue_num" --json body -q '.body' > /tmp/issue-body.txt

            echo "ISSUE_NUM:$issue_num"
            echo "BODY_START"
            cat /tmp/issue-body.txt
            echo "BODY_END"
            """

            result = subprocess.run(['bash', '-c', test_script],
                                  capture_output=True, text=True)

            print(f"Command output: {result.stdout}")
            print(f"Command stderr: {result.stderr}")

            assert result.returncode == 0, f"Failed to create issue: {result.stderr}"

            # Parse output
            output_lines = result.stdout.strip().split('\n')
            issue_num = None
            issue_body = ""

            for i, line in enumerate(output_lines):
                if line.startswith('ISSUE_NUM:'):
                    issue_num = line.replace('ISSUE_NUM:', '')
                elif line == 'BODY_START':
                    # Collect everything between BODY_START and BODY_END
                    body_lines = []
                    for j in range(i+1, len(output_lines)):
                        if output_lines[j] == 'BODY_END':
                            break
                        body_lines.append(output_lines[j])
                    issue_body = '\n'.join(body_lines)

            print(f"Created issue #{issue_num}")
            print(f"Issue body: {issue_body}")

            # Verify issue was created with non-empty body
            assert issue_body != "", "Issue body should not be empty"
            assert "pending" in issue_body.lower() or "implementation" in issue_body.lower(), \
                   f"Expected default content, got: {issue_body}"

            # Clean up
            subprocess.run(['gh', 'issue', 'close', issue_num], capture_output=True)

        finally:
            os.unlink(task_file)
            if os.path.exists('/tmp/test-body.md'):
                os.unlink('/tmp/test-body.md')

    def test_malformed_markdown_file(self):
        """Test handling of malformed markdown files"""
        print("\n=== Testing malformed markdown file ===")

        # Create malformed file (missing closing frontmatter)
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("---\n")
            f.write("title: Malformed Test\n")
            # Missing closing ---
            f.write("Some content that should appear\n")
            f.write("Even without proper frontmatter closing\n")
            task_file = f.name

        try:
            test_script = f"""
            source "{self.utils_path}"
            strip_frontmatter_safe "{task_file}" /tmp/test-malformed.md "Malformed content handling."

            # Check what was extracted
            cat /tmp/test-malformed.md
            """

            result = subprocess.run(['bash', '-c', test_script],
                                  capture_output=True, text=True)

            print(f"Extracted content: {result.stdout}")

            # Should handle gracefully - either extract content or use default
            assert result.returncode == 0, "Should handle malformed files gracefully"
            assert len(result.stdout.strip()) > 0, "Should produce some output"

        finally:
            os.unlink(task_file)
            if os.path.exists('/tmp/test-malformed.md'):
                os.unlink('/tmp/test-malformed.md')

    def test_large_content_file(self):
        """Test with large content files to ensure no truncation"""
        print("\n=== Testing large content file ===")

        # Create large content file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write("---\n")
            f.write("title: Large Content Test\n")
            f.write("---\n")
            f.write("# Large Content Test\n\n")

            # Add 10KB of content
            for i in range(1000):
                f.write(f"Line {i}: " + "x" * 100 + "\n")

            task_file = f.name

        try:
            test_script = f"""
            source "{self.utils_path}"
            strip_frontmatter_safe "{task_file}" /tmp/test-large.md "Large content test."

            # Count lines and check last line
            line_count=$(wc -l < /tmp/test-large.md)
            last_line=$(tail -1 /tmp/test-large.md)

            echo "Line count: $line_count"
            echo "Last line: $last_line"

            # Create issue
            gh issue create \\
                --title "Test: Large Content" \\
                --body-file /tmp/test-large.md \\
                --label "{self.test_label}" \\
                --json number -q '.number'
            """

            result = subprocess.run(['bash', '-c', test_script],
                                  capture_output=True, text=True)

            print(f"Output: {result.stdout}")

            lines = result.stdout.strip().split('\n')
            assert "Line count: 1001" in result.stdout, "Should preserve all lines"
            assert "Line 999:" in result.stdout, "Last line should be present"

            # Extract issue number and verify
            issue_num = lines[-1]
            if issue_num.isdigit():
                # Get issue body to verify content preservation
                verify_result = subprocess.run([
                    'gh', 'issue', 'view', issue_num,
                    '--json', 'body', '-q', '.body'
                ], capture_output=True, text=True)

                issue_body = verify_result.stdout
                assert len(issue_body) > 10000, f"Large content should be preserved, got {len(issue_body)} chars"
                assert "Line 999" in issue_body, "Last line should be in issue body"

                # Clean up
                subprocess.run(['gh', 'issue', 'close', issue_num], capture_output=True)

        finally:
            os.unlink(task_file)
            if os.path.exists('/tmp/test-large.md'):
                os.unlink('/tmp/test-large.md')

    def test_special_characters_in_content(self):
        """Test handling of special characters and code blocks"""
        print("\n=== Testing special characters ===")

        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
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

        try:
            test_script = f"""
            source "{self.utils_path}"
            strip_frontmatter_safe "{task_file}" /tmp/test-special.md "Special chars test."

            # Check content preservation
            grep -q '```bash' /tmp/test-special.md && echo "Code block preserved"
            grep -q '\\$HOME' /tmp/test-special.md && echo "Variables preserved"
            grep -q '🚀' /tmp/test-special.md && echo "Emoji preserved"

            # Create issue
            gh issue create \\
                --title "Test: Special Characters" \\
                --body-file /tmp/test-special.md \\
                --label "{self.test_label}" \\
                --json number -q '.number'
            """

            result = subprocess.run(['bash', '-c', test_script],
                                  capture_output=True, text=True)

            print(f"Output: {result.stdout}")

            assert "Code block preserved" in result.stdout
            assert "Variables preserved" in result.stdout
            assert "Emoji preserved" in result.stdout

            # Clean up issue
            lines = result.stdout.strip().split('\n')
            issue_num = lines[-1]
            if issue_num.isdigit():
                subprocess.run(['gh', 'issue', 'close', issue_num], capture_output=True)

        finally:
            os.unlink(task_file)
            if os.path.exists('/tmp/test-special.md'):
                os.unlink('/tmp/test-special.md')

    def test_validate_body_file_function(self):
        """Test the validate_body_file utility function"""
        print("\n=== Testing validate_body_file function ===")

        test_script = f"""
        source "{self.utils_path}"

        # Test 1: Non-existent file
        echo "Test 1: Non-existent file"
        if ! validate_body_file "/tmp/nonexistent.md" 2>/dev/null; then
            echo "✓ Correctly detected non-existent file"
        fi

        # Test 2: Empty file
        echo "Test 2: Empty file"
        touch /tmp/empty.md
        validate_body_file "/tmp/empty.md" "Default content" 2>&1
        content=$(cat /tmp/empty.md)
        if [ "$content" = "Default content" ]; then
            echo "✓ Added default content to empty file"
        fi
        rm /tmp/empty.md

        # Test 3: File with content
        echo "Test 3: File with content"
        echo "Existing content" > /tmp/withcontent.md
        validate_body_file "/tmp/withcontent.md"
        content=$(cat /tmp/withcontent.md)
        if [ "$content" = "Existing content" ]; then
            echo "✓ Preserved existing content"
        fi
        rm /tmp/withcontent.md
        """

        result = subprocess.run(['bash', '-c', test_script],
                              capture_output=True, text=True)

        print(f"Output: {result.stdout}")
        print(f"Stderr: {result.stderr}")

        assert "✓ Correctly detected non-existent file" in result.stdout
        assert "✓ Added default content to empty file" in result.stdout
        assert "✓ Preserved existing content" in result.stdout

    def test_has_content_after_frontmatter_function(self):
        """Test the has_content_after_frontmatter utility function"""
        print("\n=== Testing has_content_after_frontmatter function ===")

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
            test_script = f"""
            source "{self.utils_path}"

            echo "Testing file with only frontmatter:"
            if has_content_after_frontmatter "{only_fm}"; then
                echo "ERROR: Should not detect content"
            else
                echo "✓ Correctly detected no content after frontmatter"
            fi

            echo "Testing file with content:"
            if has_content_after_frontmatter "{with_content}"; then
                echo "✓ Correctly detected content after frontmatter"
            else
                echo "ERROR: Should detect content"
            fi
            """

            result = subprocess.run(['bash', '-c', test_script],
                                  capture_output=True, text=True)

            print(f"Output: {result.stdout}")

            assert "✓ Correctly detected no content after frontmatter" in result.stdout
            assert "✓ Correctly detected content after frontmatter" in result.stdout

        finally:
            os.unlink(only_fm)
            os.unlink(with_content)


if __name__ == "__main__":
    # Run tests with verbose output
    pytest.main([__file__, '-v', '-s'])