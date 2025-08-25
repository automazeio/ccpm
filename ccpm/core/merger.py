"""Directory merging logic for CCPM installation."""

import shutil
from pathlib import Path
from typing import Optional, Set


class DirectoryMerger:
    """Handles intelligent merging of directories during installation/update."""

    # Files that should always be overwritten from CCPM
    OVERWRITE_FILES = {"scripts/pm/*.sh", "commands/pm/*.md", "agents/*.md"}

    # Files that should never be overwritten (user customizations)
    PRESERVE_FILES = {"CLAUDE.md", "settings.local.json", "context/*.md", "rules/*.md"}

    def merge_directories(
        self, source: Path, target: Path, update_mode: bool = False
    ) -> None:
        """Merge source directory into target, preserving customizations.

        Args:
            source: Source directory (from CCPM)
            target: Target directory (existing .claude)
            update_mode: Whether this is an update (vs initial install)
        """
        if not source.exists():
            raise ValueError(f"Source directory does not exist: {source}")

        # Create target if it doesn't exist
        target.mkdir(parents=True, exist_ok=True)

        # Get all files from source
        source_files = self._get_all_files(source)

        for rel_path in source_files:
            src_file = source / rel_path
            tgt_file = target / rel_path

            # Decide whether to copy this file
            should_copy = self._should_copy_file(rel_path, tgt_file, update_mode)

            if should_copy:
                # Create parent directory if needed
                tgt_file.parent.mkdir(parents=True, exist_ok=True)

                # Copy the file
                if src_file.is_file():
                    shutil.copy2(src_file, tgt_file)
                    print(
                        f"  {'Updated' if tgt_file.exists() else 'Added'}: {rel_path}"
                    )

    def _get_all_files(self, directory: Path) -> Set[Path]:
        """Get all files in a directory recursively.

        Args:
            directory: Directory to scan

        Returns:
            Set of relative paths
        """
        files = set()
        for item in directory.rglob("*"):
            if item.is_file():
                rel_path = item.relative_to(directory)
                files.add(rel_path)
        return files

    def _should_copy_file(
        self, rel_path: Path, target_file: Path, update_mode: bool
    ) -> bool:
        """Determine if a file should be copied.

        Args:
            rel_path: Relative path of the file
            target_file: Target file path
            update_mode: Whether this is an update

        Returns:
            True if file should be copied
        """
        rel_str = str(rel_path)

        # Check if file matches preserve patterns
        for pattern in self.PRESERVE_FILES:
            if self._matches_pattern(rel_str, pattern):
                if target_file.exists():
                    # Never overwrite preserved files
                    return False
                else:
                    # Copy if it doesn't exist
                    return True

        # Check if file matches overwrite patterns
        for pattern in self.OVERWRITE_FILES:
            if self._matches_pattern(rel_str, pattern):
                # Always copy these files
                return True

        # For other files
        if update_mode:
            # In update mode, only copy if file doesn't exist
            return not target_file.exists()
        else:
            # In initial install, copy everything that doesn't exist
            return not target_file.exists()

    def _matches_pattern(self, path: str, pattern: str) -> bool:
        """Check if a path matches a pattern.

        Args:
            path: Path to check
            pattern: Pattern to match (supports * wildcard)

        Returns:
            True if path matches pattern
        """
        # Convert to forward slashes for consistency
        path = path.replace("\\", "/")
        pattern = pattern.replace("\\", "/")

        if "*" in pattern:
            # Simple wildcard matching
            parts = pattern.split("*")
            if len(parts) == 2:
                # Pattern like "dir/*.ext"
                prefix, suffix = parts
                return path.startswith(prefix) and path.endswith(suffix)
            elif pattern == "*":
                return True
            elif pattern.endswith("/*"):
                # Match all files in directory
                prefix = pattern[:-2]
                return path.startswith(prefix + "/")
        else:
            # Exact match
            return path == pattern
