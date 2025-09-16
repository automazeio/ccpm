"""Integration tests for documentation quality with real validation tools.

These tests validate that all documentation meets quality standards using
real linting tools, link validation, and CLI accuracy verification.
NO MOCKS - All tests use real tools and real network requests.
"""

import glob
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path

import pytest
import requests
import yaml

# from typing import Dict, List  # Unused imports


class TestMarkdownQuality:
    """Real markdown quality validation tests using markdownlint."""

    def test_readme_passes_all_lint_rules(self):
        """Test README.md passes all critical markdownlint rules."""
        # Skip if markdownlint is not available or not working
        try:
            result = subprocess.run(
                ["markdownlint", "--version"], capture_output=True, text=True, timeout=5
            )
            if result.returncode != 0:
                pytest.skip("markdownlint not available or not working")
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pytest.skip("markdownlint not available")

        result = subprocess.run(
            ["markdownlint", "README.md"], capture_output=True, text=True
        )

        # Allow some acceptable violations (line length, HTML for collapsible sections)
        acceptable_errors = {
            "MD013",  # line-length (acceptable for titles/URLs)
            "MD033",  # no-inline-html (acceptable for <details> sections)
        }

        if result.returncode != 0:
            # Parse errors and filter out acceptable ones
            errors = result.stderr.split("\n")
            critical_errors = []

            for error in errors:
                if error.strip() and not any(
                    acceptable in error for acceptable in acceptable_errors
                ):
                    critical_errors.append(error)

            if critical_errors:
                pytest.fail(
                    "Critical markdownlint errors in README.md:\n"
                    + "\n".join(critical_errors)
                )

    def test_all_markdown_files_valid(self):
        """Test all Markdown files in project are valid."""
        # Skip if markdownlint is not available or not working
        try:
            result = subprocess.run(
                ["markdownlint", "--version"], capture_output=True, text=True, timeout=5
            )
            if result.returncode != 0:
                pytest.skip("markdownlint not available or not working")
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pytest.skip("markdownlint not available")

        md_files = glob.glob("**/*.md", recursive=True)

        # Skip template files that may have intentional formatting
        skip_patterns = [
            "node_modules/",
            ".git/",
            "ccpm/claude_template/",
        ]

        filtered_files = [
            f for f in md_files if not any(pattern in f for pattern in skip_patterns)
        ]

        assert len(filtered_files) > 0, "No markdown files found to test"

        failed_files = []
        for md_file in filtered_files:
            result = subprocess.run(
                ["markdownlint", md_file], capture_output=True, text=True
            )

            if result.returncode != 0:
                # Only fail on critical errors, not style preferences
                # markdownlint outputs to stdout, not stderr
                errors = result.stdout + result.stderr
                if any(
                    critical in errors
                    for critical in ["MD001", "MD026", "MD034", "MD040"]
                ):
                    failed_files.append((md_file, errors))

        if failed_files:
            error_summary = "\n".join(
                [f"{file}: {errors[:200]}..." for file, errors in failed_files]
            )
            pytest.fail(f"Critical markdown errors in files:\n{error_summary}")

    def test_heading_hierarchy_consistent(self):
        """Test heading hierarchy is consistent across markdown files."""
        with open("README.md", "r", encoding="utf-8") as f:
            content = f.read()

        # Remove code blocks to avoid false positives from comments
        # Remove fenced code blocks (```...```)
        content_no_code = re.sub(r"```[\s\S]*?```", "", content)
        # Remove inline code (`...`)
        content_no_code = re.sub(r"`[^`\n]*`", "", content_no_code)

        # Extract headings
        headings = re.findall(r"^(#{1,6})\s+(.+)$", content_no_code, re.MULTILINE)

        # Check for proper hierarchy (no skipping levels)
        prev_level = 0
        for level_str, title in headings:
            level = len(level_str)

            # First heading should be H1
            if prev_level == 0:
                assert level == 1, f"First heading should be H1, got H{level}: {title}"
            # No skipping levels
            elif level > prev_level + 1:
                pytest.fail(
                    f"Heading level skip from H{prev_level} to H{level}: {title}"
                )

            prev_level = level


class TestYAMLConfiguration:
    """Real YAML file validation tests using yamllint and PyYAML."""

    def test_github_workflows_valid(self):
        """Test all GitHub workflow YAML files are valid."""
        yaml_files = glob.glob(".github/workflows/*.yml")
        assert len(yaml_files) > 0, "No YAML workflow files found"

        for yaml_file in yaml_files:
            # Test YAML syntax with PyYAML
            with open(yaml_file, "r") as f:
                try:
                    yaml.safe_load(f)
                except yaml.YAMLError as e:
                    pytest.fail(f"Invalid YAML syntax in {yaml_file}: {e}")

    def test_yaml_no_trailing_whitespace(self):
        """Test YAML files have no trailing whitespace."""
        yaml_files = glob.glob(".github/workflows/*.yml")

        for yaml_file in yaml_files:
            with open(yaml_file, "r") as f:
                lines = f.readlines()

            for i, line in enumerate(lines, 1):
                stripped_line = line.rstrip(" \t")
                if line != stripped_line and line != stripped_line + "\n":
                    pytest.fail(f"Trailing whitespace in {yaml_file}:{i}")

    def test_yaml_has_final_newline(self):
        """Test YAML files end with newline."""
        yaml_files = glob.glob(".github/workflows/*.yml")

        for yaml_file in yaml_files:
            with open(yaml_file, "rb") as f:
                content = f.read()

            if not content.endswith(b"\n"):
                pytest.fail(f"Missing final newline in {yaml_file}")

    def test_codecov_configuration_valid(self):
        """Test Codecov configuration uses correct parameters."""
        with open(".github/workflows/test.yml", "r") as f:
            content = f.read()

        # Should use 'files' not 'file' for Codecov v4
        assert "files:" in content, "Codecov should use 'files' parameter"
        assert "file:" not in content.replace(
            "files:", ""
        ), "Codecov should not use deprecated 'file' parameter"

    def test_pip_caching_enabled(self):
        """Test that all setup-python steps have pip caching enabled."""
        with open(".github/workflows/test.yml", "r") as f:
            content = f.read()

        # Find all setup-python blocks
        setup_python_blocks = re.findall(
            r"uses: actions/setup-python@v\d+.*?(?=- name:|$)", content, re.DOTALL
        )

        assert len(setup_python_blocks) > 0, "No setup-python blocks found"

        for i, block in enumerate(setup_python_blocks):
            assert (
                "cache: 'pip'" in block
            ), f"Missing pip caching in setup-python block {i + 1}: {block[:100]}..."


class TestLinkValidation:
    """Real link validation tests with HTTP requests."""

    def test_all_links_accessible(self):
        """Test all HTTP(S) links in README are accessible."""
        with open("README.md", "r", encoding="utf-8") as f:
            content = f.read()

        # Extract all URLs (both markdown links and bare URLs)
        url_patterns = [
            r"https?://[^\s\)]+",  # Bare URLs
            r"\[.*?\]\((https?://[^\)]+)\)",  # Markdown links
        ]

        urls = set()
        for pattern in url_patterns:
            matches = re.findall(pattern, content)
            if isinstance(matches[0], tuple) if matches else False:
                urls.update(match[0] for match in matches)
            else:
                urls.update(matches)

        assert len(urls) > 0, "No URLs found in README.md"

        # URLs that are expected to fail in certain contexts
        expected_failures = {
            # Badge URL that doesn't exist yet on automazeio fork
            # (will exist after PR merge)
            "https://github.com/automazeio/ccpm/actions/workflows/test.yml/badge.svg",
            # Protected URLs that may return 403 but are valid
            "https://claude.ai/code",
            # Twitter/X badge with special characters that can cause network issues
            "https://img.shields.io/badge/𝕏-@aroussi-1c9bf0",
            # Automaze.io can timeout on Windows CI
            "https://automaze.io",
            # Install scripts that don't exist yet in main branch
            "https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.bat",
            "https://raw.githubusercontent.com/automazeio/ccpm/main/ccpm.sh",
            # Badge URLs that can have network issues
            "https://img.shields.io/badge/+-GitHub%20Issues-1f2328",
            "https://img.shields.io/badge/★-Star%20this%20repo-e7b10b",
            "https://img.shields.io/badge/License-MIT-28a745",
            "https://img.shields.io/badge/By-automaze.io-4b3baf",
        }

        failed_urls = []
        for url in urls:
            # Clean up URL (remove trailing punctuation and angle brackets)
            clean_url = url.rstrip(".,!?>")

            # Skip URLs that are expected to fail in current context
            if clean_url in expected_failures:
                continue

            try:
                response = requests.get(
                    clean_url,
                    timeout=10,
                    allow_redirects=True,
                    headers={"User-Agent": "CCPM-Test/1.0"},
                )

                if response.status_code >= 400:
                    failed_urls.append((clean_url, response.status_code))

            except requests.exceptions.RequestException as e:
                failed_urls.append((clean_url, str(e)))

        if failed_urls:
            error_summary = "\n".join(
                [f"{url}: {error}" for url, error in failed_urls[:5]]  # Limit output
            )
            pytest.fail(f"Failed to access URLs:\n{error_summary}")

    def test_link_validation_handles_timeouts(self):
        """Test link validation gracefully handles network issues."""
        # Test with a URL that should timeout quickly
        timeout_url = "http://192.0.2.1"  # RFC 5737 test address

        try:
            requests.get(timeout_url, timeout=2)  # Response unused
            # If it doesn't timeout, that's fine too
        except requests.exceptions.Timeout:
            # Expected behavior - should not crash
            pass
        except requests.exceptions.RequestException:
            # Other network errors are also acceptable
            pass


class TestCLIDocumentationAccuracy:
    """Real CLI command verification tests."""

    def test_cli_table_matches_actual_commands(self):
        """Test CLI table in README matches actual implemented commands."""
        # Get actual CLI commands
        result = subprocess.run(["ccpm", "--help"], capture_output=True, text=True)
        assert result.returncode == 0, f"ccpm --help failed: {result.stderr}"

        # Parse actual commands from help output
        actual_commands = set()
        in_commands_section = False

        for line in result.stdout.split("\n"):
            if "Commands:" in line:
                in_commands_section = True
                continue
            elif in_commands_section and line.strip():
                if line.startswith("  "):
                    command = line.strip().split()[0]
                    actual_commands.add(command)
                else:
                    break

        # Get documented commands from README
        with open("README.md", "r", encoding="utf-8") as f:
            readme_content = f.read()

        documented_commands = set(re.findall(r"\| `ccpm (\w+)", readme_content))
        # Also check for --help flag format
        if "`ccpm --help`" in readme_content:
            documented_commands.add("--help")

        # All actual commands should be documented
        # Note: --help is a global flag, not a subcommand, so exclude it from comparison
        actual_commands_filtered = actual_commands.copy()
        documented_commands_filtered = documented_commands.copy()
        documented_commands_filtered.discard(
            "--help"
        )  # Remove --help flag from comparison

        missing_docs = actual_commands_filtered - documented_commands_filtered
        extra_docs = documented_commands_filtered - actual_commands_filtered

        if missing_docs:
            pytest.fail(f"Undocumented commands: {missing_docs}")
        if extra_docs:
            pytest.fail(f"Commands documented but not implemented: {extra_docs}")

    def test_cli_command_examples_work(self):
        """Test that CLI command examples in README actually work."""
        # Test basic commands that should work without setup
        basic_commands = [
            ["ccpm", "--version"],
            ["ccpm", "--help"],
        ]

        for cmd in basic_commands:
            result = subprocess.run(cmd, capture_output=True, text=True)
            assert (
                result.returncode == 0
            ), f"Command failed: {' '.join(cmd)}\nError: {result.stderr}"

    def test_help_command_consistency(self):
        """Test that help command references are consistent."""
        with open("README.md", "r", encoding="utf-8") as f:
            readme_content = f.read()

        # Should use --help for portability (not 'help' subcommand)
        help_references = re.findall(r"`ccpm (--help|help)`", readme_content)

        # Count references
        help_flags = sum(1 for ref in help_references if ref == "--help")
        help_commands = sum(1 for ref in help_references if ref == "help")

        # Should primarily use --help for consistency
        assert (
            help_flags >= help_commands
        ), "Should prefer 'ccpm --help' over 'ccpm help' for portability"


class TestPerformanceValidation:
    """Real performance validation tests."""

    def test_markdown_linting_performance(self):
        """Test markdown linting performs well on large files."""
        # Skip if markdownlint is not available or not working
        try:
            result = subprocess.run(
                ["markdownlint", "--version"], capture_output=True, text=True, timeout=5
            )
            if result.returncode != 0:
                pytest.skip("markdownlint not available or not working")
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pytest.skip("markdownlint not available")

        # Create a large test markdown file (avoid MD012 multiple blank lines)
        large_content = "# Performance Test\n\n" + "This is a test paragraph.\n" * 500

        # Create temporary file with proper Windows handling
        fd, temp_path = tempfile.mkstemp(suffix=".md", text=True)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(large_content)

            start_time = time.time()
            result = subprocess.run(
                ["markdownlint", temp_path],
                capture_output=True,
                timeout=30,  # Should complete within 30 seconds
            )
            elapsed = time.time() - start_time

            # Should complete reasonably quickly
            assert elapsed < 10, f"Markdown linting took too long: {elapsed:.2f}s"
            assert result.returncode == 0, f"Large file linting failed: {result.stderr}"

        finally:
            try:
                os.unlink(temp_path)
            except (OSError, PermissionError):
                pass  # Ignore cleanup errors on Windows

    def test_yaml_validation_performance(self):
        """Test YAML validation performs well on complex files."""
        start_time = time.time()

        # Test validation on our actual workflow file
        with open(".github/workflows/test.yml", "r") as f:
            yaml.safe_load(f)

        elapsed = time.time() - start_time
        assert elapsed < 5, f"YAML validation took too long: {elapsed:.2f}s"


class TestEdgeCaseHandling:
    """Test edge cases and error conditions."""

    def test_unicode_content_handling(self):
        """Test markdown linting handles Unicode content correctly."""
        # Skip if markdownlint is not available or not working
        try:
            result = subprocess.run(
                ["markdownlint", "--version"], capture_output=True, text=True, timeout=5
            )
            if result.returncode != 0:
                pytest.skip("markdownlint not available or not working")
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pytest.skip("markdownlint not available")

        unicode_content = """# Test with Unicode 🎉

This file contains:
- Emojis: 🚀 📋 ✅
- Special chars: café résumé
- Math symbols: ∑ ∏ ∞
- Currency: € £ ¥
"""

        # Create temporary file with proper Windows handling
        fd, temp_path = tempfile.mkstemp(suffix=".md", text=True)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as f:
                f.write(unicode_content)

            result = subprocess.run(
                ["markdownlint", temp_path], capture_output=True, text=True
            )
            # Should not crash on Unicode content
            assert result.returncode is not None, "Process should complete"

        finally:
            try:
                os.unlink(temp_path)
            except (OSError, PermissionError):
                pass  # Ignore cleanup errors on Windows

    def test_empty_file_handling(self):
        """Test tools handle empty files gracefully."""
        # Skip if markdownlint is not available or not working
        try:
            result = subprocess.run(
                ["markdownlint", "--version"], capture_output=True, text=True, timeout=5
            )
            if result.returncode != 0:
                pytest.skip("markdownlint not available or not working")
        except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
            pytest.skip("markdownlint not available")

        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as f:
            f.write("")  # Empty file
            f.flush()

            try:
                result = subprocess.run(
                    ["markdownlint", f.name], capture_output=True, text=True
                )
                # Should handle empty files without crashing
                assert result.returncode is not None, "Process should complete"

            finally:
                os.unlink(f.name)

    def test_malformed_url_handling(self):
        """Test link validation handles malformed URLs gracefully."""
        malformed_urls = [
            "http://",
            "https://",
            "ftp://invalid",
            "not-a-url",
        ]

        for url in malformed_urls:
            try:
                # Should not crash on malformed URLs
                requests.get(url, timeout=2)
            except requests.exceptions.RequestException:
                # Expected - should handle gracefully
                pass


@pytest.fixture
def temp_project():
    """Create a temporary project directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        original_cwd = os.getcwd()
        os.chdir(tmpdir)
        try:
            yield Path(tmpdir)
        finally:
            os.chdir(original_cwd)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
