"""Integration tests for shell utility functions."""

import platform
import subprocess
import tempfile
from pathlib import Path
from typing import Generator

import pytest


class TestShellUtilities:
    """Test cross-platform shell utility functions."""

    @pytest.fixture
    def temp_test_files(
        self,
    ) -> Generator[tuple[Path, Path, Path], None, None]:
        """Create temporary test files for shell utility testing.

        Yields:
            Tuple of (utils_script, test_file, backup_dir)
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            temp_path = Path(tmpdir)

            # Copy utils.sh to temp directory
            utils_source = (
                Path(__file__).parent.parent.parent / ".claude" / "scripts" / "utils.sh"
            )
            utils_script = temp_path / "utils.sh"

            if utils_source.exists():
                utils_script.write_text(utils_source.read_text())
            else:
                pytest.skip("utils.sh not found in .claude/scripts/")

            # Create test file
            test_file = temp_path / "test_file.txt"
            test_file.write_text(
                "line1: original content\nline2: more content\n" "line3: final line\n"
            )

            # Create backup directory
            backup_dir = temp_path / "backups"
            backup_dir.mkdir()

            yield utils_script, test_file, backup_dir

    def _run_bash_with_utils(
        self, script_content: str, utils_script: Path, cwd: Path = None
    ) -> subprocess.CompletedProcess:
        """Run bash script that sources utils.sh.

        Args:
            script_content: Bash script content to execute
            utils_script: Path to utils.sh file
            cwd: Working directory for script execution

        Returns:
            CompletedProcess result
        """
        full_script = f"""#!/bin/bash
set -e
source "{utils_script}"
{script_content}
"""

        return subprocess.run(
            ["bash", "-c", full_script],
            cwd=cwd or utils_script.parent,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_cross_platform_sed_basic_replacement(self, temp_test_files):
        """Test basic sed replacement functionality."""
        utils_script, test_file, _ = temp_test_files

        script = f"""
cross_platform_sed 's/original/replaced/' "{test_file}"
cat "{test_file}"
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert result.returncode == 0, f"Script failed: {result.stderr}"
        assert "replaced content" in result.stdout
        assert "original content" not in result.stdout

    def test_cross_platform_sed_multiple_replacements(self, temp_test_files):
        """Test sed with multiple pattern replacements."""
        utils_script, test_file, _ = temp_test_files

        script = f"""
cross_platform_sed 's/line/LINE/g' "{test_file}"
cat "{test_file}"
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert result.returncode == 0, f"Script failed: {result.stderr}"
        assert "LINE1:" in result.stdout
        assert "LINE2:" in result.stdout
        assert "LINE3:" in result.stdout
        assert "line1:" not in result.stdout

    def test_cross_platform_sed_with_special_characters(self, temp_test_files):
        """Test sed with special characters and escaping."""
        utils_script, test_file, _ = temp_test_files

        # Add content with special characters
        test_file.write_text(
            "path/to/file: content\n[bracket]: more\n{brace}: content\n"
        )

        script = f"""
cross_platform_sed 's|path/to/file|new/path|' "{test_file}"
cat "{test_file}"
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert result.returncode == 0, f"Script failed: {result.stderr}"
        assert "new/path: content" in result.stdout
        assert "path/to/file" not in result.stdout

    def test_cross_platform_sed_backup_functionality(self, temp_test_files):
        """Test sed with backup functionality."""
        utils_script, test_file, _ = temp_test_files

        original_content = test_file.read_text()

        script = f"""
cross_platform_sed_backup 's/original/modified/' "{test_file}"
echo "=== MODIFIED ==="
cat "{test_file}"
echo "=== BACKUP ==="
cat "{test_file}.bak"
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert result.returncode == 0, f"Script failed: {result.stderr}"
        assert "modified content" in result.stdout
        # Should be in backup section
        assert original_content in result.stdout

    def test_cross_platform_sed_backup_restore_on_failure(self, temp_test_files):
        """Test sed backup restores original file on failure."""
        utils_script, test_file, _ = temp_test_files

        original_content = test_file.read_text()

        # Use invalid sed expression to trigger failure
        script = f"""
if ! cross_platform_sed_backup 's/[/invalid/' "{test_file}"; then
    echo "EXPECTED_FAILURE"
fi
cat "{test_file}"
"""

        result = self._run_bash_with_utils(script, utils_script)

        # Should fail but restore original content
        assert "EXPECTED_FAILURE" in result.stdout
        # File should be restored to original content
        assert test_file.read_text() == original_content

    def test_cross_platform_sed_error_handling(self, temp_test_files):
        """Test error handling for invalid inputs."""
        utils_script, _, _ = temp_test_files

        # Test missing file
        script = """
if ! cross_platform_sed 's/test/replacement/' "/nonexistent/file"; then
    echo "MISSING_FILE_ERROR"
fi
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert "MISSING_FILE_ERROR" in result.stdout

        # Test missing arguments
        script = """
if ! cross_platform_sed; then
    echo "MISSING_ARGS_ERROR"
fi
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert "MISSING_ARGS_ERROR" in result.stdout

    def test_detect_platform_function(self, temp_test_files):
        """Test platform detection function."""
        utils_script, _, _ = temp_test_files

        script = """
platform=$(detect_platform)
echo "DETECTED_PLATFORM: $platform"
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert result.returncode == 0, f"Script failed: {result.stderr}"
        assert "DETECTED_PLATFORM:" in result.stdout

        # Verify it returns a known platform
        detected = result.stdout.split("DETECTED_PLATFORM:")[1].strip()
        assert detected in ["Linux", "macOS", "Windows", "Unknown"]

        # Verify it matches Python's platform detection roughly
        current_system = platform.system()
        if current_system == "Darwin":
            assert detected == "macOS"
        elif current_system == "Linux":
            assert detected == "Linux"
        elif current_system in ["Windows", "CYGWIN", "MINGW", "MSYS"]:
            assert detected == "Windows"

    def test_command_exists_function(self, temp_test_files):
        """Test command existence checking."""
        utils_script, _, _ = temp_test_files

        script = """
if command_exists "bash"; then
    echo "BASH_EXISTS"
fi

if command_exists "nonexistent_command_xyz"; then
    echo "NONEXISTENT_FOUND"
else
    echo "NONEXISTENT_NOT_FOUND"
fi
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert result.returncode == 0, f"Script failed: {result.stderr}"
        assert "BASH_EXISTS" in result.stdout
        assert "NONEXISTENT_NOT_FOUND" in result.stdout
        assert "NONEXISTENT_FOUND" not in result.stdout

    def test_handle_error_function(self, temp_test_files):
        """Test error handling function."""
        utils_script, _, _ = temp_test_files

        # Test successful command (should not trigger error handler)
        script = """
true
handle_error 10 "test command"
echo "NO_ERROR_TRIGGERED"
"""

        result = self._run_bash_with_utils(script, utils_script)
        assert result.returncode == 0
        assert "NO_ERROR_TRIGGERED" in result.stdout

        # Test failing command (should trigger error handler and exit)
        script = """
false
handle_error 20 "failing command"
echo "SHOULD_NOT_REACH_HERE"
"""

        result = self._run_bash_with_utils(script, utils_script)

        # Should exit on the false command with error handling
        assert result.returncode != 0
        assert "SHOULD_NOT_REACH_HERE" not in result.stdout

    def test_robust_parse_function(self, temp_test_files):
        """Test awk-based parsing function."""
        utils_script, test_file, _ = temp_test_files

        # Create structured test data
        test_file.write_text(
            """name: test-project
version: 1.0.0
status: active
description: A test project
name: another-project
version: 2.0.0
status: inactive
"""
        )

        script = f"""
echo "=== All names ==="
robust_parse '/^name:/ {{print $2}}' "{test_file}"
echo "=== Active projects ==="
robust_parse '/^status: active/ {{found=1}} found && /^name:/ {{print $2; found=0}}' "{test_file}"
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert result.returncode == 0, f"Script failed: {result.stderr}"
        assert "test-project" in result.stdout
        assert "another-project" in result.stdout

    def test_robust_parse_error_handling(self, temp_test_files):
        """Test robust_parse error handling."""
        utils_script, _, _ = temp_test_files

        script = """
if ! robust_parse '/test/' "/nonexistent/file"; then
    echo "FILE_ERROR_HANDLED"
fi

if ! robust_parse; then
    echo "ARGS_ERROR_HANDLED"
fi
"""

        result = self._run_bash_with_utils(script, utils_script)

        assert "FILE_ERROR_HANDLED" in result.stdout
        assert "ARGS_ERROR_HANDLED" in result.stdout


class TestPMScriptIntegration:
    """Test integration of utility functions with PM scripts."""

    @pytest.fixture
    def pm_test_environment(self, tmp_path: Path) -> Path:
        """Set up PM test environment with utils.sh."""
        # Create .claude structure
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()

        scripts_dir = claude_dir / "scripts"
        scripts_dir.mkdir()

        pm_dir = scripts_dir / "pm"
        pm_dir.mkdir()

        # Copy utils.sh
        utils_source = (
            Path(__file__).parent.parent.parent / ".claude" / "scripts" / "utils.sh"
        )
        if utils_source.exists():
            (scripts_dir / "utils.sh").write_text(utils_source.read_text())
        else:
            pytest.skip("utils.sh not found")

        # Copy status.sh
        status_source = (
            Path(__file__).parent.parent.parent
            / ".claude"
            / "scripts"
            / "pm"
            / "status.sh"
        )
        if status_source.exists():
            (pm_dir / "status.sh").write_text(status_source.read_text())
        else:
            pytest.skip("status.sh not found")

        return tmp_path

    def test_status_script_execution(self, pm_test_environment: Path):
        """Test that status.sh script executes without errors."""
        result = subprocess.run(
            ["bash", ".claude/scripts/pm/status.sh"],
            cwd=pm_test_environment,
            capture_output=True,
            text=True,
            timeout=30,
        )

        # Should execute without errors
        assert result.returncode == 0, f"status.sh failed: {result.stderr}"
        assert "Project Status" in result.stdout
        assert "PRDs:" in result.stdout
        assert "Epics:" in result.stdout
        assert "Tasks:" in result.stdout

    def test_status_script_with_content(self, pm_test_environment: Path):
        """Test status.sh with actual PRD and epic content."""
        # Create test content
        prds_dir = pm_test_environment / ".claude" / "prds"
        prds_dir.mkdir()
        (prds_dir / "test-feature.md").write_text("# Test Feature\n\nTest PRD content")
        (prds_dir / "another-feature.md").write_text(
            "# Another Feature\n\nMore content"
        )

        epics_dir = pm_test_environment / ".claude" / "epics"
        epics_dir.mkdir()
        epic_dir = epics_dir / "test-feature"
        epic_dir.mkdir()
        (epic_dir / "epic.md").write_text("# Epic\n\nEpic content")
        (epic_dir / "001.md").write_text("---\nstatus: open\n---\nTask 1")
        (epic_dir / "002.md").write_text("---\nstatus: closed\n---\nTask 2")
        (epic_dir / "003.md").write_text("---\nstatus: open\n---\nTask 3")

        result = subprocess.run(
            ["bash", ".claude/scripts/pm/status.sh"],
            cwd=pm_test_environment,
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, f"status.sh failed: {result.stderr}"
        assert "Total: 2" in result.stdout  # 2 PRDs
        assert "Total: 1" in result.stdout  # 1 epic directory
        assert "Open: 2" in result.stdout  # 2 open tasks
        assert "Closed: 1" in result.stdout  # 1 closed task
        assert "Total: 3" in result.stdout  # 3 total tasks

    def test_utils_sourcing_fallback(self, pm_test_environment: Path):
        """Test that scripts handle missing utils.sh gracefully."""
        # Remove utils.sh to test fallback
        utils_file = pm_test_environment / ".claude" / "scripts" / "utils.sh"
        utils_file.unlink()

        result = subprocess.run(
            ["bash", ".claude/scripts/pm/status.sh"],
            cwd=pm_test_environment,
            capture_output=True,
            text=True,
            timeout=30,
        )

        # Should still execute but with warning
        assert result.returncode == 0, f"status.sh failed: {result.stderr}"
        assert "Warning: Could not load utility functions" in result.stderr
        assert "Project Status" in result.stdout


@pytest.mark.parametrize("shell", ["bash", "zsh"])
class TestShellCompatibility:
    """Test shell utility compatibility across different shells."""

    def test_utils_in_different_shells(self, shell: str, tmp_path: Path):
        """Test utility functions work in different shell environments."""
        # Skip if shell not available
        try:
            subprocess.run(
                [shell, "--version"],
                capture_output=True,
                timeout=5,
                check=True,
            )
        except (subprocess.CalledProcessError, FileNotFoundError):
            pytest.skip(f"{shell} not available")

        # Copy utils.sh
        utils_source = (
            Path(__file__).parent.parent.parent / ".claude" / "scripts" / "utils.sh"
        )
        if not utils_source.exists():
            pytest.skip("utils.sh not found")

        utils_script = tmp_path / "utils.sh"
        utils_script.write_text(utils_source.read_text())

        test_file = tmp_path / "test.txt"
        test_file.write_text("original content\nmore lines\n")

        script = f"""#!/bin/{shell}
source "{utils_script}"
cross_platform_sed 's/original/modified/' "{test_file}"
cat "{test_file}"
"""

        result = subprocess.run(
            [shell, "-c", script],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, f"Failed in {shell}: {result.stderr}"
        assert "modified content" in result.stdout


class TestEdgeCasesAndErrorScenarios:
    """Test edge cases and error scenarios for shell utilities."""

    def test_file_permission_handling(self, tmp_path: Path):
        """Test handling of file permission issues."""
        utils_source = (
            Path(__file__).parent.parent.parent / ".claude" / "scripts" / "utils.sh"
        )
        if not utils_source.exists():
            pytest.skip("utils.sh not found")

        utils_script = tmp_path / "utils.sh"
        utils_script.write_text(utils_source.read_text())

        # Create read-only file (skip on Windows where this behaves different)
        if platform.system() == "Windows":
            pytest.skip("File permission test not reliable on Windows")

        readonly_file = tmp_path / "readonly.txt"
        readonly_file.write_text("readonly content")
        readonly_file.chmod(0o444)  # Read-only

        # Make directory read-only too to ensure write fails
        readonly_file.parent.chmod(0o555)

        script = f"""#!/bin/bash
source "{utils_script}"
if ! cross_platform_sed 's/readonly/modified/' "{readonly_file}" \\
    2>/dev/null; then
    echo "PERMISSION_ERROR_HANDLED"
else
    echo "UNEXPECTED_SUCCESS"
fi
"""

        result = subprocess.run(
            ["bash", "-c", script],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=30,
        )

        # Restore permissions for cleanup
        readonly_file.parent.chmod(0o755)

        # Should handle the permission error gracefully
        assert "PERMISSION_ERROR_HANDLED" in result.stdout or result.returncode != 0

    def test_large_file_handling(self, tmp_path: Path):
        """Test utility functions with larger files."""
        utils_source = (
            Path(__file__).parent.parent.parent / ".claude" / "scripts" / "utils.sh"
        )
        if not utils_source.exists():
            pytest.skip("utils.sh not found")

        utils_script = tmp_path / "utils.sh"
        utils_script.write_text(utils_source.read_text())

        # Create larger test file
        large_file = tmp_path / "large.txt"
        content = "line with pattern\n" * 1000 + "different content\n" * 1000
        large_file.write_text(content)

        script = f"""#!/bin/bash
source "{utils_script}"
cross_platform_sed 's/pattern/REPLACED/g' "{large_file}"
grep -c "REPLACED" "{large_file}"
"""

        result = subprocess.run(
            ["bash", "-c", script],
            cwd=tmp_path,
            capture_output=True,
            text=True,
            timeout=60,  # Longer timeout for large file
        )

        assert result.returncode == 0, f"Large file test failed: {result.stderr}"
        assert "1000" in result.stdout  # Should have replaced 1000 occurrences

    def test_concurrent_access_safety(self, tmp_path: Path):
        """Test utility functions under concurrent access."""
        utils_source = (
            Path(__file__).parent.parent.parent / ".claude" / "scripts" / "utils.sh"
        )
        if not utils_source.exists():
            pytest.skip("utils.sh not found")

        utils_script = tmp_path / "utils.sh"
        utils_script.write_text(utils_source.read_text())

        # Create separate test files to avoid conflicts
        processes = []
        for i in range(3):
            test_file = tmp_path / f"concurrent_{i}.txt"
            test_file.write_text(f"initial content for concurrent test {i}\n")

            script = f"""#!/bin/bash
source "{utils_script}"
cross_platform_sed 's/content/content_{i}/' "{test_file}"
echo "PROCESS_{i}_COMPLETE"
"""
            proc = subprocess.Popen(
                ["bash", "-c", script],
                cwd=tmp_path,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            processes.append((proc, test_file))

        # Wait for all to complete
        results = []
        for proc, test_file in processes:
            stdout, stderr = proc.communicate(timeout=30)
            results.append((proc.returncode, stdout, stderr, test_file))

        # At least one should succeed (they shouldn't conflict now)
        success_count = sum(1 for returncode, _, _, _ in results if returncode == 0)
        assert (
            success_count > 0
        ), f"All concurrent operations failed: {[r[2] for r in results]}"

        # All files should still be valid
        for _, _, _, test_file in results:
            assert test_file.exists()
            assert test_file.stat().st_size > 0
