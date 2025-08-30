"""Setup and installation commands."""

from pathlib import Path

from ..core.installer import CCPMInstaller


def setup_command(path: Path) -> None:
    """Set up CCPM in a repository.

    Args:
        path: Target directory for installation
    """
    installer = CCPMInstaller(path)
    installer.setup()


def update_command() -> None:
    """Update CCPM to latest version."""
    # Run in current directory
    cwd = Path.cwd()
    installer = CCPMInstaller(cwd)
    installer.update()


def uninstall_command() -> None:
    """Remove CCPM from current directory."""
    # Run in current directory
    cwd = Path.cwd()
    installer = CCPMInstaller(cwd)
    installer.uninstall()
