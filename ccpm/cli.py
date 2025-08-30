"""Main CLI interface for CCPM."""

import os
import sys
from pathlib import Path
from typing import Optional

import click

from .commands.maintenance import (
    clean_command,
    help_command,
    search_command,
    validate_command,
)
from .commands.pm import (
    import_command,
    init_command,
    list_command,
    status_command,
    sync_command,
)
from .commands.setup import setup_command, uninstall_command, update_command
from .utils.console import print_error, strip_emojis


def safe_echo(message: str, err: bool = False) -> None:
    """Echo with emoji handling for Windows."""
    if sys.platform == "win32":
        message = strip_emojis(message)
    click.echo(message, err=err)


@click.group()
@click.version_option(version="0.1.0", prog_name="ccpm")
def cli() -> None:
    """Claude Code PM - Project Management System for spec-driven development.

    CCPM transforms PRDs into epics, epics into GitHub issues, and issues into
    production code with full traceability at every step.
    """
    pass


@cli.command("setup")
@click.argument("path", type=click.Path(exists=False))
def setup(path: str) -> None:
    """Set up CCPM in a repository.

    PATH: Target directory for CCPM installation (can be . for current directory)
    """
    try:
        setup_command(Path(path))
    except Exception as exc:
        print_error(f"Setup failed: {exc}")
        sys.exit(1)


@cli.command("update")
def update() -> None:
    """Update CCPM to latest version.

    Pulls latest changes from automazeio/ccpm and updates the .claude folder
    while preserving your customizations.
    """
    try:
        update_command()
    except Exception as exc:
        print_error(f"Update failed: {exc}")
        sys.exit(1)


@cli.command("uninstall")
@click.option("--force", is_flag=True, help="Skip confirmation prompts")
@click.option(
    "--preserve-user-data",
    is_flag=True,
    default=True,
    help="Preserve user content (default: true)",
)
def uninstall(force: bool, preserve_user_data: bool) -> None:
    """Remove CCPM from current directory.

    Preserves any pre-existing .claude content that was present before
    CCPM installation.
    """
    # Set environment for non-interactive behavior
    if force:
        os.environ["CCPM_FORCE"] = "1"
    if not preserve_user_data:
        os.environ["CCPM_UNINSTALL_SCAFFOLDING"] = "y"

    try:
        uninstall_command()
    except Exception as exc:
        print_error(f"Uninstall failed: {exc}")
        sys.exit(1)
    finally:
        # Clean up environment variables
        os.environ.pop("CCPM_FORCE", None)
        os.environ.pop("CCPM_UNINSTALL_SCAFFOLDING", None)


@cli.command("init")
def init() -> None:
    """Initialize PM system (shortcut for /pm:init)."""
    try:
        init_command()
    except Exception as exc:
        safe_echo(f"❌ Init failed: {exc}", err=True)
        sys.exit(1)


@cli.command("list")
def list_prds() -> None:
    """List all PRDs (shortcut for /pm:prd-list)."""
    try:
        list_command()
    except Exception as exc:
        safe_echo(f"❌ List failed: {exc}", err=True)
        sys.exit(1)


@cli.command("status")
def status() -> None:
    """Show project status (shortcut for /pm:prd-status)."""
    try:
        status_command()
    except Exception as exc:
        safe_echo(f"❌ Status failed: {exc}", err=True)
        sys.exit(1)


@cli.command("sync")
def sync() -> None:
    """Sync with GitHub (shortcut for /pm:sync)."""
    try:
        sync_command()
    except Exception as exc:
        safe_echo(f"❌ Sync failed: {exc}", err=True)
        sys.exit(1)


@cli.command("import")
@click.argument("issue_number", type=int, required=False)
def import_issue(issue_number: Optional[int]) -> None:
    """Import GitHub issues (shortcut for /pm:import).

    ISSUE_NUMBER: Optional specific issue number to import
    """
    try:
        import_command(issue_number)
    except Exception as exc:
        safe_echo(f"❌ Import failed: {exc}", err=True)
        sys.exit(1)


@cli.command("validate")
def validate() -> None:
    """Validate system integrity (shortcut for /pm:validate)."""
    try:
        validate_command()
    except Exception as exc:
        safe_echo(f"❌ Validate failed: {exc}", err=True)
        sys.exit(1)


@cli.command("clean")
def clean() -> None:
    """Archive completed work (shortcut for /pm:clean)."""
    try:
        clean_command()
    except Exception as exc:
        safe_echo(f"❌ Clean failed: {exc}", err=True)
        sys.exit(1)


@cli.command("search")
@click.argument("query")
def search(query: str) -> None:
    """Search across all content (shortcut for /pm:search).

    QUERY: Search term to find across PRDs, epics, and tasks
    """
    try:
        search_command(query)
    except Exception as exc:
        safe_echo(f"❌ Search failed: {exc}", err=True)
        sys.exit(1)


@cli.command("help")
def help_cmd() -> None:
    """Display CCPM help and command summary."""
    try:
        help_command()
    except Exception as exc:
        safe_echo(f"❌ Help failed: {exc}", err=True)
        sys.exit(1)


if __name__ == "__main__":
    cli()
