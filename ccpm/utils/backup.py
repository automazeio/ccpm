"""Backup and restore utilities."""

import json
import shutil
from datetime import datetime
from pathlib import Path


class BackupManager:
    """Manages backups for CCPM operations."""

    BACKUP_DIR = ".ccpm_backup"

    def __init__(self, project_root: Path):
        """Initialize backup manager.

        Args:
            project_root: Root directory of the project
        """
        self.project_root = Path(project_root)
        self.backup_root = self.project_root / self.BACKUP_DIR

    def create_backup(self, source: Path) -> Path:
        """Create a backup of a directory or file.

        Args:
            source: Path to backup

        Returns:
            Path to the backup
        """
        if not source.exists():
            raise ValueError(f"Source does not exist: {source}")

        # Create backup directory
        self.backup_root.mkdir(parents=True, exist_ok=True)

        # Generate backup name with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"{source.name}_{timestamp}"
        backup_path = self.backup_root / backup_name

        # Create backup
        if source.is_dir():
            shutil.copytree(source, backup_path)
        else:
            shutil.copy2(source, backup_path)

        # Create metadata file
        metadata = {
            "source": str(source),
            "created_at": datetime.now().isoformat(),
            "type": "directory" if source.is_dir() else "file",
        }

        metadata_file = backup_path.parent / f"{backup_name}.json"
        with open(metadata_file, "w") as f:
            json.dump(metadata, f, indent=2)

        return backup_path

    def restore_backup(self, backup_path: Path, target: Path) -> None:
        """Restore a backup to target location.

        Args:
            backup_path: Path to the backup
            target: Where to restore the backup
        """
        if not backup_path.exists():
            raise ValueError(f"Backup does not exist: {backup_path}")

        # Remove target if it exists
        if target.exists():
            if target.is_dir():
                shutil.rmtree(target)
            else:
                target.unlink()

        # Restore backup
        if backup_path.is_dir():
            shutil.copytree(backup_path, target)
        else:
            shutil.copy2(backup_path, target)

    def list_backups(self) -> list:
        """List all available backups.

        Returns:
            List of backup information dictionaries
        """
        if not self.backup_root.exists():
            return []

        backups = []
        for metadata_file in self.backup_root.glob("*.json"):
            try:
                with open(metadata_file, "r") as f:
                    metadata = json.load(f)
                    metadata["backup_path"] = str(metadata_file.with_suffix(""))
                    backups.append(metadata)
            except Exception:
                continue

        # Sort by creation time (newest first)
        backups.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return backups

    def clean_old_backups(self, keep_count: int = 5) -> None:
        """Remove old backups, keeping only the most recent ones.

        Args:
            keep_count: Number of backups to keep
        """
        backups = self.list_backups()

        if len(backups) <= keep_count:
            return

        # Remove old backups
        for backup in backups[keep_count:]:
            backup_path = Path(backup["backup_path"])
            if backup_path.exists():
                if backup_path.is_dir():
                    shutil.rmtree(backup_path)
                else:
                    backup_path.unlink()

            # Remove metadata file
            metadata_file = backup_path.parent / f"{backup_path.name}.json"
            if metadata_file.exists():
                metadata_file.unlink()
