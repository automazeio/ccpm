"""CCPM installation and setup logic."""

import json
import os
import shutil
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

from ..utils.backup import BackupManager
from ..utils.console import (
    get_emoji,
    print_error,
    print_info,
    print_success,
    print_warning,
    safe_print,
)
from ..utils.shell import run_command, run_pm_script
from .config import ConfigManager
from .github import GitHubCLI
from .merger import DirectoryMerger


class CCPMInstaller:
    """Handles CCPM installation, updates, and removal."""

    CCPM_REPO = "https://github.com/automazeio/ccpm.git"
    TRACKING_FILE = ".ccpm_tracking.json"

    def __init__(self, target_path: Path):
        """Initialize installer for target directory.

        Args:
            target_path: Directory where CCPM will be installed
        """
        self.target = Path(target_path).resolve()
        self.claude_dir = self.target / ".claude"
        self.tracking_file = self.target / self.TRACKING_FILE
        self.gh_cli = GitHubCLI()
        self.backup = BackupManager(self.target)
        self.config = ConfigManager(self.target)
        self.merger = DirectoryMerger()

    def setup(self) -> None:
        """Main setup flow with automatic GitHub CLI installation."""
        safe_print(f"\n{get_emoji('🚀', '>>>')} Setting up CCPM...")

        # 1. Ensure target directory exists
        self.target.mkdir(parents=True, exist_ok=True)

        # 2. Ensure GitHub CLI is installed
        if not self.gh_cli.ensure_gh_installed():
            raise RuntimeError("Failed to install GitHub CLI")

        # 3. Setup GitHub authentication (optional, don't fail if skipped)
        if not self.gh_cli.setup_auth():
            # In CI, this is expected - don't show warning
            if not (os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS")):
                print_warning(
                    "GitHub authentication skipped. You may need to run 'gh auth login' later."
                )

        # 4. Install required extensions
        self.gh_cli.install_extensions()

        # 5. Check for existing .claude directory
        existing_claude = self.claude_dir.exists()
        if existing_claude:
            safe_print(f"\n{get_emoji('📁', '>>>')} Found existing .claude directory")
            # Backup existing content
            backup_path = self.backup.create_backup(self.claude_dir)
            print_success(f"Backed up to: {backup_path}")

        # 6. Copy bundled .claude template
        safe_print("\n📥 Installing CCPM files...")

        # Get the bundled claude_template from the package
        import ccpm

        package_dir = Path(ccpm.__file__).parent
        claude_template = package_dir / "claude_template"

        if not claude_template.exists():
            # Fallback to cloning from repository if template not found
            safe_print("\n📥 Downloading CCPM from repository...")
            with tempfile.TemporaryDirectory() as tmpdir:
                tmp_path = Path(tmpdir)

                result = run_command(
                    [
                        "git",
                        "clone",
                        "--depth",
                        "1",
                        self.CCPM_REPO,
                        str(tmp_path / "ccpm"),
                    ]
                )

                if result[0] != 0:
                    raise RuntimeError(f"Failed to clone CCPM repository: {result[2]}")

                claude_template = tmp_path / "ccpm" / ".claude"

                if not claude_template.exists():
                    raise RuntimeError(
                        "CCPM repository does not contain .claude directory"
                    )

        # 7. Merge or copy .claude directory
        if existing_claude:
            safe_print(
                f"\n{get_emoji('🔄', '>>>')} Merging with existing .claude directory..."
            )
            self.merger.merge_directories(claude_template, self.claude_dir)
        else:
            safe_print("\n📂 Creating .claude directory...")
            shutil.copytree(claude_template, self.claude_dir)

        # 8. Initialize git repository if needed
        if not (self.target / ".git").exists():
            safe_print("\n📝 Initializing git repository...")
            run_command(["git", "init"], cwd=self.target)
            run_command(["git", "add", "."], cwd=self.target)
            run_command(
                ["git", "commit", "-m", "Initial commit with CCPM"], cwd=self.target
            )

        # 9. Run init.sh script
        safe_print(f"\n{get_emoji('⚙️', '>>>')} Running initialization script...")
        init_script = self.claude_dir / "scripts" / "pm" / "init.sh"
        if init_script.exists():
            result = run_command(["bash", str(init_script)], cwd=self.target)
            if result[0] != 0:
                print_warning(f"Init script failed: {result[2]}")

        # 10. Create tracking file for uninstall
        self._create_tracking_file(existing_claude)

        # 11. Update .gitignore
        self._update_gitignore()

        print_success("\nCCPM setup complete!")
        safe_print("\nNext steps:")
        safe_print("  1. Run 'ccpm init' to initialize the PM system")
        safe_print("  2. Run 'ccpm help' to see available commands")
        safe_print(
            "  3. Create your first PRD with Claude Code: /pm:prd-new <feature-name>"
        )

    def update(self) -> None:
        """Update CCPM to latest version."""
        safe_print(f"\n{get_emoji('🔄', '>>>')} Updating CCPM...")

        if not self.claude_dir.exists():
            print_error("No CCPM installation found. Run 'ccpm setup .' first.")
            raise RuntimeError("CCPM not installed")

        # Backup current state
        backup_path = self.backup.create_backup(self.claude_dir)
        print_success(f"Backed up current version to: {backup_path}")

        # Download latest version
        safe_print("\n📥 Downloading latest CCPM...")
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)

            # Clone the repository
            result = run_command(
                ["git", "clone", "--depth", "1", self.CCPM_REPO, str(tmp_path / "ccpm")]
            )

            if result[0] != 0:
                # Restore backup on failure
                self.backup.restore_backup(backup_path, self.claude_dir)
                raise RuntimeError(f"Failed to clone CCPM repository: {result[2]}")

            ccpm_claude = tmp_path / "ccpm" / ".claude"

            # Merge updates
            safe_print(f"\n{get_emoji('🔄', '>>>')} Merging updates...")
            self.merger.merge_directories(
                ccpm_claude, self.claude_dir, update_mode=True
            )

        # Update tracking file
        if self.tracking_file.exists():
            tracking = self._load_tracking_file()
            tracking["last_updated"] = datetime.now().isoformat()
            self._save_tracking_file(tracking)

        print_success("\nCCPM updated successfully!")

    def uninstall(self) -> None:
        """Remove CCPM while preserving pre-existing content."""
        safe_print(f"\n{get_emoji('🗑️', '>>>')} Uninstalling CCPM...")

        if not self.claude_dir.exists():
            safe_print("No CCPM installation found.")
            return

        # Load tracking file
        if not self.tracking_file.exists():
            print_warning("No tracking file found. Cannot determine what to preserve.")
            response = input("Remove entire .claude directory? [y/N]: ")
            if response.lower() == "y":
                shutil.rmtree(self.claude_dir)
                print_success(".claude directory removed")
            else:
                print_error("Uninstall cancelled")
            return

        tracking = self._load_tracking_file()

        if tracking.get("had_existing_claude"):
            safe_print(
                f"{get_emoji('📁', '>>>')} Preserving pre-existing .claude content..."
            )

            # Get list of CCPM files
            ccpm_files = tracking.get("ccpm_files", [])

            # Remove CCPM files
            for file_path in ccpm_files:
                full_path = self.claude_dir / file_path
                if full_path.exists():
                    if full_path.is_dir():
                        shutil.rmtree(full_path)
                    else:
                        full_path.unlink()

            print_success("CCPM files removed, original content preserved")
        else:
            # No pre-existing content, remove entire directory
            shutil.rmtree(self.claude_dir)
            print_success(".claude directory removed")

        # Remove tracking file
        self.tracking_file.unlink()

        print_success("\nCCPM uninstalled successfully!")

    def _create_tracking_file(self, had_existing: bool) -> None:
        """Create tracking file for uninstall.

        Args:
            had_existing: Whether there was an existing .claude directory
        """
        tracking_data = {
            "version": "0.1.0",
            "installed_at": datetime.now().isoformat(),
            "had_existing_claude": had_existing,
            "ccpm_files": [],
        }

        if had_existing:
            # Track which files are from CCPM
            ccpm_files = [
                "scripts/pm",
                "commands/pm",
                "agents",
                "prds",
                "epics",
                "scripts/test-and-log.sh",
            ]
            tracking_data["ccpm_files"] = ccpm_files

        self._save_tracking_file(tracking_data)

    def _load_tracking_file(self) -> Dict[str, Any]:
        """Load tracking file."""
        if self.tracking_file.exists():
            with open(self.tracking_file, "r") as f:
                return json.load(f)
        return {}

    def _save_tracking_file(self, data: Dict[str, Any]) -> None:
        """Save tracking file."""
        with open(self.tracking_file, "w") as f:
            json.dump(data, f, indent=2)

    def _update_gitignore(self) -> None:
        """Update .gitignore to exclude tracking file."""
        gitignore = self.target / ".gitignore"

        entries_to_add = [
            ".ccpm_tracking.json",
            ".ccpm_backup/",
            ".claude/epics/",
            ".claude/prds/",
        ]

        if gitignore.exists():
            content = gitignore.read_text()
        else:
            content = ""

        lines = content.splitlines() if content else []

        for entry in entries_to_add:
            if entry not in lines:
                lines.append(entry)

        gitignore.write_text("\n".join(lines) + "\n")
