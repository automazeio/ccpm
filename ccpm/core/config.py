"""Configuration management for CCPM."""

import json
from pathlib import Path
from typing import Any, Dict

from ..utils.console import print_warning


class ConfigManager:
    """Manages CCPM configuration."""

    CONFIG_FILE = ".claude/settings.local.json"

    def __init__(self, project_root: Path):
        """Initialize configuration manager.

        Args:
            project_root: Root directory of the project
        """
        self.project_root = Path(project_root)
        self.config_path = self.project_root / self.CONFIG_FILE

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file.

        Returns:
            Configuration dictionary
        """
        if self.config_path.exists():
            try:
                with open(self.config_path, "r") as f:
                    return json.load(f)
            except json.JSONDecodeError:
                print_warning(f"Invalid config file: {self.config_path}")
                return {}
        return {}

    def save_config(self, config: Dict[str, Any]) -> None:
        """Save configuration to file.

        Args:
            config: Configuration dictionary to save
        """
        # Ensure directory exists
        self.config_path.parent.mkdir(parents=True, exist_ok=True)

        with open(self.config_path, "w") as f:
            json.dump(config, f, indent=2)

    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value.

        Args:
            key: Configuration key
            default: Default value if key not found

        Returns:
            Configuration value or default
        """
        config = self.load_config()
        return config.get(key, default)

    def set(self, key: str, value: Any) -> None:
        """Set configuration value.

        Args:
            key: Configuration key
            value: Value to set
        """
        config = self.load_config()
        config[key] = value
        self.save_config(config)

    def update(self, updates: Dict[str, Any]) -> None:
        """Update multiple configuration values.

        Args:
            updates: Dictionary of updates to apply
        """
        config = self.load_config()
        config.update(updates)
        self.save_config(config)
