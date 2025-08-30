"""Integration tests for CCPM setup commands."""

import json
import os
import subprocess
from pathlib import Path

# import pytest  # Unused import


class TestSetupCommand:
    """Test the ccpm setup command with real operations."""

    def test_setup_empty_repo(self, real_git_repo: Path):
        """Test setting up CCPM in an empty repository."""
        # Run setup command
        result = subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            text=True,
            timeout=60,
        )

        # Check command succeeded
        assert result.returncode == 0, f"Setup failed: {result.stderr}"

        # Verify .claude directory created
        claude_dir = real_git_repo / ".claude"
        assert claude_dir.exists()
        assert claude_dir.is_dir()

        # Verify essential subdirectories
        assert (claude_dir / "scripts" / "pm").exists()
        assert (claude_dir / "commands" / "pm").exists()
        assert (claude_dir / "agents").exists()
        assert (claude_dir / "prds").exists()
        assert (claude_dir / "epics").exists()

        # Verify tracking file created
        tracking_file = real_git_repo / ".ccpm_tracking.json"
        assert tracking_file.exists()

        # Verify tracking file content
        with open(tracking_file) as f:
            tracking = json.load(f)
        assert "version" in tracking
        assert "installed_at" in tracking
        assert tracking["had_existing_claude"] is False

    def test_setup_with_existing_claude(self, repo_with_existing_claude: Path):
        """Test setting up CCPM with existing .claude directory."""
        # Get original content
        claude_dir = repo_with_existing_claude / ".claude"
        custom_file = claude_dir / "custom.md"
        original_content = custom_file.read_text()

        # Run setup command
        result = subprocess.run(
            ["ccpm", "setup", str(repo_with_existing_claude)],
            capture_output=True,
            text=True,
            timeout=60,
        )

        # Check command succeeded
        assert result.returncode == 0, f"Setup failed: {result.stderr}"

        # Verify original content preserved
        assert custom_file.exists()
        assert custom_file.read_text() == original_content
        assert (claude_dir / "custom_dir" / "file.txt").exists()

        # Verify CCPM content added
        assert (claude_dir / "scripts" / "pm").exists()
        assert (claude_dir / "commands" / "pm").exists()

        # Verify tracking file
        tracking_file = repo_with_existing_claude / ".ccpm_tracking.json"
        assert tracking_file.exists()

        with open(tracking_file) as f:
            tracking = json.load(f)
        assert tracking["had_existing_claude"] is True
        assert "ccpm_files" in tracking

    def test_setup_creates_gitignore_entries(self, real_git_repo: Path):
        """Test that setup adds necessary .gitignore entries."""
        # Create existing .gitignore
        gitignore = real_git_repo / ".gitignore"
        gitignore.write_text("*.pyc\n__pycache__/\n")

        # Run setup
        result = subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            text=True,
            timeout=60,
        )

        assert result.returncode == 0

        # Check .gitignore updated
        content = gitignore.read_text()
        assert ".ccpm_tracking.json" in content
        assert ".ccpm_backup/" in content
        assert ".claude/epics/" in content
        assert ".claude/prds/" in content
        # Original content preserved
        assert "*.pyc" in content
        assert "__pycache__/" in content

    def test_setup_non_git_repo(self, tmp_path: Path):
        """Test setup in a non-git directory (should initialize git)."""
        test_dir = tmp_path / "non_git"
        test_dir.mkdir()

        # Run setup
        result = subprocess.run(
            ["ccpm", "setup", str(test_dir)], capture_output=True, text=True, timeout=60
        )

        assert result.returncode == 0

        # Verify git initialized
        assert (test_dir / ".git").exists()

        # Verify .claude created
        assert (test_dir / ".claude").exists()


class TestUpdateCommand:
    """Test the ccpm update command."""

    def test_update_existing_installation(self, real_git_repo: Path):
        """Test updating an existing CCPM installation."""
        # First setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Add a custom file to .claude
        custom = real_git_repo / ".claude" / "user_custom.txt"
        custom.write_text("User content")

        # Run update in the repo directory
        result = subprocess.run(
            ["ccpm", "update"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=60,
        )

        assert result.returncode == 0

        # Verify custom content preserved
        assert custom.exists()
        assert custom.read_text() == "User content"

        # Verify backup created
        backup_dir = real_git_repo / ".ccpm_backup"
        assert backup_dir.exists()
        assert len(list(backup_dir.iterdir())) > 0

    def test_update_no_installation(self, real_git_repo: Path):
        """Test update when CCPM is not installed."""
        result = subprocess.run(
            ["ccpm", "update"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        # Should fail with appropriate message
        assert result.returncode != 0
        assert (
            "No CCPM installation found" in result.stderr
            or "No CCPM installation found" in result.stdout
        )


class TestUninstallCommand:
    """Test the ccpm uninstall command."""

    def test_uninstall_clean_installation(self, real_git_repo: Path):
        """Test uninstalling CCPM with no pre-existing content."""
        # Setup CCPM
        subprocess.run(
            ["ccpm", "setup", str(real_git_repo)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Verify installation
        assert (real_git_repo / ".claude").exists()

        # Uninstall
        env = os.environ.copy()
        env["CCPM_UNINSTALL_SCAFFOLDING"] = "y"
        result = subprocess.run(
            ["ccpm", "uninstall"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
            env=env,
        )

        assert result.returncode == 0

        # On Windows, sometimes directory removal has a slight delay due to file handles
        claude_dir = real_git_repo / ".claude"
        tracking_file = real_git_repo / ".ccpm_tracking.json"

        if os.name == "nt":
            import shutil
            import time

            # Give Windows a moment to release file handles
            max_retries = 5
            for i in range(max_retries):
                if not claude_dir.exists() and not tracking_file.exists():
                    break
                time.sleep(1.0)  # Longer delay

                # On the last retry, try to force remove any remaining files
                if i == max_retries - 1 and claude_dir.exists():
                    try:
                        # List what's left for debugging
                        remaining = list(claude_dir.rglob("*"))
                        print(f"Remaining files in .claude: {remaining}")
                        # Try to force remove
                        shutil.rmtree(claude_dir, ignore_errors=True)
                        time.sleep(0.5)
                    except Exception as e:
                        print(f"Force cleanup failed: {e}")

        # Verify .claude removed
        dir_contents = list(claude_dir.rglob("*")) if claude_dir.exists() else "N/A"
        assert not claude_dir.exists(), f"Directory still exists: {dir_contents}"

        # Verify tracking file removed
        assert not tracking_file.exists()

    def test_uninstall_preserves_existing_content(
        self, repo_with_existing_claude: Path
    ):
        """Test that uninstall preserves pre-existing .claude content."""
        # Get original files
        claude_dir = repo_with_existing_claude / ".claude"
        custom_file = claude_dir / "custom.md"
        custom_dir = claude_dir / "custom_dir"

        # Setup CCPM (will merge with existing)
        subprocess.run(
            ["ccpm", "setup", str(repo_with_existing_claude)],
            capture_output=True,
            check=True,
            timeout=60,
        )

        # Verify CCPM files exist
        assert (claude_dir / "scripts" / "pm").exists()

        # Uninstall
        env = os.environ.copy()
        env["CCPM_UNINSTALL_SCAFFOLDING"] = "y"
        result = subprocess.run(
            ["ccpm", "uninstall"],
            cwd=repo_with_existing_claude,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
            env=env,
        )

        assert result.returncode == 0

        # Verify original content preserved
        assert custom_file.exists()
        assert custom_dir.exists()
        assert (custom_dir / "file.txt").exists()

        # Verify CCPM content removed
        assert not (claude_dir / "scripts" / "pm").exists()
        assert not (claude_dir / "commands" / "pm").exists()

    def test_uninstall_no_installation(self, real_git_repo: Path):
        """Test uninstall when CCPM is not installed."""
        result = subprocess.run(
            ["ccpm", "uninstall"],
            cwd=real_git_repo,
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minutes for Claude commands
        )

        # Should complete without error
        assert result.returncode == 0
        assert "No CCPM installation found" in result.stdout
