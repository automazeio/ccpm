"""CCPM installation and setup logic."""

import json
import os
import shutil
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

from ..utils.backup import BackupManager
from ..utils.console import (
    get_emoji,
    print_error,
    print_info,
    print_success,
    print_warning,
    safe_input,
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
                    "GitHub authentication skipped. "
                    "You may need to run 'gh auth login' later."
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

        # 7. Handle existing .claude directory with backup and merge
        backup_dir = self.claude_dir.parent / ".claude.backup"

        if existing_claude:
            safe_print(
                f"\n{get_emoji('💾', '>>>')} Backing up existing .claude directory..."
            )
            # Remove old backup if exists
            if backup_dir.exists():
                shutil.rmtree(backup_dir)
            # Move existing .claude to backup
            shutil.move(str(self.claude_dir), str(backup_dir))

            # Copy new .claude directory
            safe_print("\n📂 Installing new .claude directory...")
            shutil.copytree(claude_template, self.claude_dir)

            # Merge user content from backup
            safe_print(
                f"\n{get_emoji('🔄', '>>>')} Merging user content from backup..."
            )
            self._merge_user_content_from_backup(backup_dir)
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

        # 9. Run init.sh script using cross-platform script runner
        safe_print(f"\n{get_emoji('⚙️', '>>>')} Running initialization script...")
        init_script = self.claude_dir / "scripts" / "pm" / "init.sh"
        if init_script.exists():
            rc, stdout, stderr = run_pm_script("init", cwd=self.target)
            if rc != 0:
                print_warning(f"Init script failed: {stderr}")
                if stdout:
                    print_info(f"Script output: {stdout}")

        # 10. Create tracking file for uninstall
        self._create_tracking_file(existing_claude)

        # 11. Update .gitignore
        self._update_gitignore()

        # 12. Create workspace directory for Claude Code
        workspace_dir = self.claude_dir / "workspace"
        if not workspace_dir.exists():
            workspace_dir.mkdir(parents=True, exist_ok=True)
            safe_print(
                f"\n{get_emoji('📁', '>>>')} Created workspace directory: .claude/workspace"
            )
            # Create a .gitkeep file to ensure the directory is tracked
            gitkeep = workspace_dir / ".gitkeep"
            gitkeep.touch()

        print_success("\nCCPM setup complete!")
        safe_print("\nNext steps:")
        safe_print("  1. Run 'ccpm init' to initialize the PM system")
        safe_print("  2. Run 'ccpm help' to see available commands")
        safe_print(
            "  3. Create your first PRD with Claude Code: /pm:prd-new <feature-name>"
        )

    def update(self) -> None:
        """Update CCPM to latest version with comprehensive error recovery."""
        safe_print(f"\n{get_emoji('🔄', '>>>')} Updating CCPM...")

        if not self.claude_dir.exists():
            print_error("No CCPM installation found. Run 'ccpm setup .' first.")
            raise RuntimeError("CCPM not installed")

        backup_path = None
        try:
            # Backup current state
            backup_path = self.backup.create_backup(self.claude_dir)
            print_success(f"Backed up current version to: {backup_path}")

            # Download latest version
            safe_print("\n📥 Downloading latest CCPM...")
            with tempfile.TemporaryDirectory() as tmpdir:
                tmp_path = Path(tmpdir)

                # Clone the repository
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

                ccpm_claude = tmp_path / "ccpm" / ".claude"
                if not ccpm_claude.exists():
                    raise RuntimeError(
                        "Downloaded CCPM repository does not contain .claude directory"
                    )

                # Critical merge operation with recovery
                safe_print(f"\n{get_emoji('🔄', '>>>')} Merging updates...")
                try:
                    self.merger.merge_directories(
                        ccpm_claude, self.claude_dir, update_mode=True
                    )
                except Exception as merge_exc:
                    print_error("Merge failed, restoring backup...")
                    if backup_path and backup_path.exists():
                        self.backup.restore_backup(backup_path, self.claude_dir)
                        print_info("Previous state restored successfully")
                    raise RuntimeError(
                        "Update failed during merge, previous state restored"
                    ) from merge_exc

            # Update tracking file
            try:
                if self.tracking_file.exists():
                    tracking = self._load_tracking_file()
                    tracking["last_updated"] = datetime.now().isoformat()
                    self._save_tracking_file(tracking)
            except Exception as tracking_exc:
                print_warning(f"Failed to update tracking file: {tracking_exc}")
                # Don't fail the entire update for tracking file issues

            # Ensure workspace directory exists after update
            workspace_dir = self.claude_dir / "workspace"
            if not workspace_dir.exists():
                workspace_dir.mkdir(parents=True, exist_ok=True)
                safe_print(
                    f"\n{get_emoji('📁', '>>>')} Created workspace directory: .claude/workspace"
                )
                # Create a .gitkeep file to ensure the directory is tracked
                gitkeep = workspace_dir / ".gitkeep"
                gitkeep.touch()

            # Migrate settings.local.json from /tmp/ccpm to .claude/workspace
            settings_file = self.claude_dir / "settings.local.json"
            if settings_file.exists():
                try:
                    import json
                    with open(settings_file, 'r') as f:
                        settings = json.load(f)

                    # Check if we need to migrate from /tmp/ccpm
                    if "additionalDirectories" in settings.get("permissions", {}):
                        dirs = settings["permissions"]["additionalDirectories"]
                        if "/tmp/ccpm" in dirs:
                            # Replace /tmp/ccpm with .claude/workspace
                            dirs.remove("/tmp/ccpm")
                            if ".claude/workspace" not in dirs:
                                dirs.append(".claude/workspace")

                            # Write updated settings
                            with open(settings_file, 'w') as f:
                                json.dump(settings, f, indent=2)

                            safe_print(
                                f"\n{get_emoji('🔄', '>>>')} Migrated settings from /tmp/ccpm to .claude/workspace"
                            )
                except Exception as settings_exc:
                    print_warning(f"Failed to migrate settings: {settings_exc}")
                    # Don't fail the update for settings migration issues

            print_success("\nCCPM updated successfully!")

        except Exception as exc:
            print_error("Update failed, attempting to restore backup...")
            if backup_path and backup_path.exists():
                try:
                    self.backup.restore_backup(backup_path, self.claude_dir)
                    print_info("Previous state restored successfully")
                except Exception as restore_exc:
                    print_error(f"Failed to restore backup: {restore_exc}")
                    print_error("Manual recovery may be required")
            raise RuntimeError("CCPM update failed") from exc

    def uninstall(self) -> None:
        """Safely remove CCPM while preserving ALL user content."""
        safe_print(f"\n{get_emoji('🗑️', '>>>')} Uninstalling CCPM...")

        if not self.claude_dir.exists():
            safe_print("No CCPM installation found.")
            return

        # Pre-flight safety check
        user_content = self._detect_user_content()
        if user_content:
            print_info(f"Detected user content: {', '.join(user_content)}")
            print_info("These will be preserved during uninstall")

        # Load tracking with safety validation
        if not self.tracking_file.exists():
            print_warning("No tracking file found - using safe mode")

            response = safe_input(
                "Remove CCPM scaffolding only? [y/N]: ",
                default="N",
                force_value=os.environ.get("CCPM_UNINSTALL_SCAFFOLDING"),
            )

            if response.lower() != "y":
                print_info(
                    "Uninstall cancelled - use --force flag in scripts if needed"
                )
                return

            self._safe_uninstall_without_tracking()
            return

        # Tracked uninstall with user data protection
        tracking = self._load_tracking_file()

        # Use new safe tracking format if available
        if "ccpm_scaffolding_files" in tracking:
            scaffolding_files = tracking["ccpm_scaffolding_files"]
        else:
            # Legacy tracking - be extra cautious
            legacy_files = tracking.get("ccpm_files", [])
            # Filter out user content directories from legacy tracking
            scaffolding_files = [
                f
                for f in legacy_files
                if not any(user_dir in f for user_dir in ["agents", "prds", "epics"])
            ]
            print_warning("Using legacy tracking file - extra safety measures applied")

        # Remove only CCPM scaffolding
        removed_count = 0
        for file_path in scaffolding_files:
            full_path = self.claude_dir / file_path
            # Skip context directory entirely to preserve user content
            if file_path.startswith("context"):
                continue
            if full_path.exists():
                try:
                    if full_path.is_dir():
                        # For scaffolding directories, remove them completely
                        # They're explicitly tracked as safe to remove
                        shutil.rmtree(full_path)
                        removed_count += 1
                    else:
                        full_path.unlink()
                        removed_count += 1
                except Exception as exc:
                    print_warning(f"Could not remove {file_path}: {exc}")

        # For clean installations, remove template-only directories
        if not tracking.get("had_existing_claude", True):
            # Check all remaining directories for template-only content
            # For clean installs, we can also clean context directory of template files
            template_dirs_to_check = [
                "agents",
                "prds",
                "epics",
                "commands",
                "rules",
                "scripts",
                "context",
                "workspace",  # Added workspace directory
            ]
            for dir_name in template_dirs_to_check:
                dir_path = self.claude_dir / dir_name
                if dir_path.exists() and self._is_template_only_directory(dir_path):
                    try:
                        shutil.rmtree(dir_path)
                        removed_count += 1
                    except Exception as exc:
                        print_warning(
                            f"Could not remove template directory {dir_name}: {exc}"
                        )

        # Remove tracking file
        try:
            self.tracking_file.unlink()
        except Exception as exc:
            print_warning(f"Could not remove tracking file: {exc}")

        # If .claude directory is now empty, remove it completely
        if self.claude_dir.exists():
            try:
                # Check if directory is empty
                remaining_items = list(self.claude_dir.iterdir())
                if not remaining_items:
                    # On Windows, sometimes we need to wait a moment for handles
                    # to close
                    import sys
                    import time

                    if sys.platform == "win32":
                        time.sleep(0.1)
                    self.claude_dir.rmdir()
                elif (
                    len(remaining_items) == 1
                    and remaining_items[0].name == "settings.local.json"
                ):
                    # Sometimes settings file is left behind, remove it too
                    try:
                        remaining_items[0].unlink()
                        if sys.platform == "win32":
                            time.sleep(0.1)
                        self.claude_dir.rmdir()
                    except Exception:
                        pass  # Don't fail the uninstall for this
            except Exception as exc:
                print_warning(f"Could not remove empty .claude directory: {exc}")

        # Restore backup if it exists
        backup_dir = self.claude_dir.parent / ".claude.backup"
        if backup_dir.exists():
            safe_print(
                f"\n{get_emoji('🔄', '>>>')} Restoring previous .claude directory..."
            )
            try:
                # Remove current .claude directory if it exists
                if self.claude_dir.exists():
                    shutil.rmtree(self.claude_dir)
                # Restore from backup
                shutil.move(str(backup_dir), str(self.claude_dir))
                print_success("Previous .claude directory restored")
            except Exception as exc:
                print_warning(f"Could not restore backup: {exc}")
                print_info("Backup directory preserved at .claude.backup")

        print_success(f"Removed {removed_count} CCPM files, preserved user content")
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

        # Only track CCPM scaffolding files, never user content
        ccpm_scaffolding_files = [
            "scripts/pm/",  # PM shell scripts
            "scripts/test-and-log.sh",  # Test runner script
            "commands/pm/",  # PM command templates
            "settings.local.json",  # Template settings
            "context/",  # Context templates (if exists)
            "CLAUDE.md",  # Project instructions
        ]

        # NEVER track user content directories:
        # - agents/  (user-created task agents)
        # - prds/    (user product requirements)
        # - epics/   (user project epics)

        user_content_dirs = ["agents", "prds", "epics", "context/custom"]

        tracking_data.update(
            {
                "ccpm_scaffolding_files": ccpm_scaffolding_files,
                "user_content_dirs": user_content_dirs,  # For informational purposes
                "data_safety_version": "1.0",  # Track safety model version
            }
        )

        self._save_tracking_file(tracking_data)

    def _is_template_file(self, file_path: Path) -> bool:
        """Check if a file or directory is a CCPM template that can be safely removed.

        Args:
            file_path: File or directory path to check

        Returns:
            True if it's a safe-to-remove template file/directory
        """
        if not file_path.exists():
            return True

        # Get relative path from .claude directory
        try:
            rel_path = file_path.relative_to(self.claude_dir)
            rel_path_str = str(rel_path).replace("\\", "/")  # Normalize for Windows
        except ValueError:
            return False

        # Known CCPM template files that are safe to remove
        template_files = {
            "settings.local.json",
            "CLAUDE.md",
            "agents/code-analyzer.md",
            "agents/file-analyzer.md",
            "agents/parallel-worker.md",
            "agents/test-runner.md",
            "context/README.md",
            "prds/.gitkeep",
            "epics/.gitkeep",
        }

        # Check if it's a known template file
        if rel_path_str in template_files:
            return True

        # Check if it's a template directory
        if file_path.is_dir():
            return self._is_template_only_directory(file_path)

        return False

    def _detect_user_content(self) -> List[str]:
        """Detect user-created content that must be preserved.

        Returns:
            List of user content descriptions
        """
        user_content = []

        check_dirs = [
            ("prds", "*.md"),
            ("epics", "*/"),
            ("agents", "*.py"),
            ("context/custom", "*"),
        ]

        for dir_name, pattern in check_dirs:
            dir_path = self.claude_dir / dir_name
            if dir_path.exists():
                files = list(dir_path.glob(pattern))
                if files:
                    user_content.append(f"{dir_name} ({len(files)} items)")

        return user_content

    def _is_directory_empty_of_user_content(self, directory: Path) -> bool:
        """Check if directory contains only CCPM scaffolding (no user content).

        Args:
            directory: Directory to check

        Returns:
            True if safe to remove, False if contains user content
        """
        if not directory.exists() or not directory.is_dir():
            return True

        # Check for user content patterns
        user_patterns = [
            "*.md",  # User PRDs, documentation
            "*.py",  # User agents, custom scripts
            "*.json",  # User configuration
            "*.txt",  # User notes
            "*/epic.md",  # User epic files
            "*/task_*.md",  # User task files
        ]

        for pattern in user_patterns:
            if list(directory.rglob(pattern)):
                return False

        return True

    def _is_template_only_directory(self, directory: Path) -> bool:
        """Check if directory contains only CCPM template files.

        Safe to remove in clean installs.

        Args:
            directory: Directory to check

        Returns:
            True if directory only contains CCPM templates, False if it has user content
        """
        if not directory.exists() or not directory.is_dir():
            return True

        # Known CCPM template files that are safe to remove
        template_files = {
            "agents/code-analyzer.md",
            "agents/file-analyzer.md",
            "agents/parallel-worker.md",
            "agents/test-runner.md",
            "context/README.md",
            "prds/.gitkeep",
            "epics/.gitkeep",
            "workspace/.gitkeep",
            "commands/code-rabbit.md",
            "commands/prompt.md",
            "commands/re-init.md",
            "commands/context/create.md",
            "commands/context/update.md",
            "commands/context/prime.md",
            "commands/testing/run.md",
            "commands/testing/prime.md",
            "rules/worktree-operations.md",
            "rules/standard-patterns.md",
            "rules/github-operations.md",
            "rules/frontmatter-operations.md",
            "rules/datetime.md",
            "rules/branch-management.md",
            "rules/iteration-patterns.md",
            "rules/project-structure.md",
            "rules/tracking-operations.md",
            "rules/code-generation.md",
            "rules/coordination-operations.md",
            "rules/agent-coordination.md",
            "rules/branch-operations.md",
            "rules/strip-frontmatter.md",
            "rules/test-execution.md",
            "rules/use-ast-grep.md",
            "scripts/utils.sh",
        }

        # Get all files in directory relative to .claude/
        # claude_relative = directory.relative_to(self.claude_dir)  # Unused
        all_files = set()
        for file_path in directory.rglob("*"):
            if file_path.is_file():
                relative_path = file_path.relative_to(self.claude_dir)
                all_files.add(str(relative_path))

        # Directory is template-only if all files are known templates
        return all_files.issubset(template_files)

    def _safe_uninstall_without_tracking(self) -> None:
        """Safely uninstall without tracking file (conservative approach)."""
        print_info("Using conservative uninstall - removing only known CCPM files")

        # Only remove files we know are definitely CCPM scaffolding
        safe_to_remove = ["scripts/test-and-log.sh", "settings.local.json", "CLAUDE.md"]

        removed_count = 0
        for file_path in safe_to_remove:
            full_path = self.claude_dir / file_path
            if full_path.exists():
                try:
                    if full_path.is_dir():
                        if self._is_directory_empty_of_user_content(full_path):
                            shutil.rmtree(full_path)
                            removed_count += 1
                    else:
                        full_path.unlink()
                        removed_count += 1
                except Exception as exc:
                    print_warning(f"Could not remove {file_path}: {exc}")

        # Carefully handle scripts directory
        scripts_dir = self.claude_dir / "scripts"
        if scripts_dir.exists():
            pm_dir = scripts_dir / "pm"
            if pm_dir.exists() and self._is_directory_empty_of_user_content(pm_dir):
                try:
                    shutil.rmtree(pm_dir)
                    removed_count += 1
                    # Remove scripts dir if it's now empty
                    if not list(scripts_dir.iterdir()):
                        scripts_dir.rmdir()
                except Exception as exc:
                    print_warning(f"Could not remove scripts/pm: {exc}")

        # If .claude directory is now empty or only has template files, remove it
        if self.claude_dir.exists():
            try:
                remaining_items = list(self.claude_dir.iterdir())
                if not remaining_items:
                    # On Windows, sometimes we need to wait a moment for handles
                    # to close
                    import sys
                    import time

                    if sys.platform == "win32":
                        time.sleep(0.1)
                    self.claude_dir.rmdir()
                elif all(self._is_template_file(item) for item in remaining_items):
                    # Remove remaining template files and the directory
                    for item in remaining_items:
                        try:
                            if item.is_dir():
                                shutil.rmtree(item)
                            else:
                                item.unlink()
                        except Exception:
                            pass  # Don't fail uninstall for cleanup issues
                    try:
                        if sys.platform == "win32":
                            time.sleep(0.1)
                        self.claude_dir.rmdir()
                    except Exception:
                        pass
            except Exception as exc:
                print_warning(f"Could not remove .claude directory: {exc}")

        print_success(f"Removed {removed_count} CCPM files using conservative approach")

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

    def _merge_user_content_from_backup(self, backup_dir: Path) -> None:
        """Merge user content from backup directory into new installation.

        Args:
            backup_dir: Path to the .claude.backup directory
        """
        if not backup_dir.exists():
            return

        # User content directories to preserve
        user_dirs = ["agents", "prds", "epics", "context"]

        for user_dir in user_dirs:
            backup_user_dir = backup_dir / user_dir
            target_user_dir = self.claude_dir / user_dir

            if not backup_user_dir.exists():
                continue

            # Create target directory if it doesn't exist
            target_user_dir.mkdir(parents=True, exist_ok=True)

            # Copy all user content, but don't overwrite template files
            for item in backup_user_dir.iterdir():
                target_item = target_user_dir / item.name

                if item.is_dir():
                    # Copy entire user directories
                    if not target_item.exists():
                        shutil.copytree(item, target_item)
                    else:
                        # Merge directory contents
                        self._merge_directory_contents(item, target_item)
                elif item.is_file():
                    # Only copy user files, skip template files like .gitkeep
                    if item.name not in [".gitkeep", "README.md"]:
                        shutil.copy2(item, target_item)

        # Also preserve any custom settings from settings.local.json
        backup_settings = backup_dir / "settings.local.json"
        target_settings = self.claude_dir / "settings.local.json"

        if backup_settings.exists() and target_settings.exists():
            self._merge_settings_files(backup_settings, target_settings)

        # Preserve custom files and directories in root of backup directory
        # These are things that don't belong to the standard CCPM template
        ccpm_template_items = {
            "agents",
            "commands",
            "context",
            "epics",
            "prds",
            "scripts",
            "settings.local.json",
            "CLAUDE.md",
            ".gitkeep",
            "README.md",
        }

        for item in backup_dir.iterdir():
            if item.name in ccpm_template_items:
                continue

            target_item = self.claude_dir / item.name

            if item.is_dir():
                # Copy custom directories that don't exist in template
                if not target_item.exists():
                    shutil.copytree(item, target_item)
                else:
                    # Merge if directory exists in template
                    self._merge_directory_contents(item, target_item)
            elif item.is_file():
                # Copy custom files that don't exist in template
                if not target_item.exists():
                    shutil.copy2(item, target_item)

    def _merge_directory_contents(self, source_dir: Path, target_dir: Path) -> None:
        """Recursively merge directory contents."""
        for item in source_dir.iterdir():
            target_item = target_dir / item.name

            if item.is_dir():
                if not target_item.exists():
                    shutil.copytree(item, target_item)
                else:
                    self._merge_directory_contents(item, target_item)
            elif item.is_file():
                # Only copy if target doesn't exist or if it's clearly user content
                if not target_item.exists() or item.name not in [
                    ".gitkeep",
                    "README.md",
                ]:
                    shutil.copy2(item, target_item)

    def _merge_settings_files(
        self, backup_settings: Path, target_settings: Path
    ) -> None:
        """Merge user settings from backup into new settings file."""
        try:
            import json

            # Load both files
            with open(backup_settings) as f:
                backup_data = json.load(f)
            with open(target_settings) as f:
                target_data = json.load(f)

            # Merge permissions if they exist in backup
            if "permissions" in backup_data:
                if "permissions" not in target_data:
                    target_data["permissions"] = {}

                # Merge allow/deny/ask lists
                for perm_type in ["allow", "deny", "ask"]:
                    if perm_type in backup_data["permissions"]:
                        if perm_type not in target_data["permissions"]:
                            target_data["permissions"][perm_type] = []
                        # Add unique entries from backup
                        for item in backup_data["permissions"][perm_type]:
                            if item not in target_data["permissions"][perm_type]:
                                target_data["permissions"][perm_type].append(item)

                # Merge additionalDirectories
                if "additionalDirectories" in backup_data["permissions"]:
                    if "additionalDirectories" not in target_data["permissions"]:
                        target_data["permissions"]["additionalDirectories"] = []
                    for dir_path in backup_data["permissions"]["additionalDirectories"]:
                        if (
                            dir_path
                            not in target_data["permissions"]["additionalDirectories"]
                        ):
                            target_data["permissions"]["additionalDirectories"].append(
                                dir_path
                            )

            # Save merged settings
            with open(target_settings, "w") as f:
                json.dump(target_data, f, indent=2)

        except Exception as exc:
            print_warning(f"Could not merge settings files: {exc}")
            # If merge fails, just keep the new template settings
