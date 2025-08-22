"""PM workflow commands."""

from pathlib import Path
from typing import Optional

from ..utils.console import get_emoji, print_error, print_info, print_success, print_warning, safe_print
from ..utils.shell import run_pm_script


def init_command() -> None:
    """Initialize PM system (shortcut for /pm:init)."""
    returncode, stdout, stderr = run_pm_script("init")

    if stdout:
        safe_print(stdout)
    if stderr and returncode != 0:
        print_error(f"Error: {stderr}")

    if returncode != 0:
        raise RuntimeError("Init command failed")


def list_command() -> None:
    """List all PRDs (shortcut for /pm:prd-list)."""
    # First check if .claude directory exists
    cwd = Path.cwd()
    if not (cwd / ".claude").exists():
        print_error("No CCPM installation found. Run 'ccpm setup .' first.")
        raise RuntimeError("CCPM not installed")

    # Check for PRDs directory
    prds_dir = cwd / ".claude" / "prds"
    if not prds_dir.exists():
        safe_print(f"{get_emoji('📄', '>>>')} No PRDs found")
        return

    # List PRD files
    prd_files = list(prds_dir.glob("*.md"))

    if not prd_files:
        safe_print(f"{get_emoji('📄', '>>>')} No PRDs found")
        return

    safe_print(f"{get_emoji('📄', '>>>')} Product Requirements Documents:")
    safe_print("=" * 40)

    for prd_file in sorted(prd_files):
        name = prd_file.stem
        # Try to read the first line as title
        try:
            with open(prd_file, "r") as f:
                first_line = f.readline().strip()
                if first_line.startswith("#"):
                    title = first_line.lstrip("#").strip()
                else:
                    title = name
        except Exception:
            title = name

        safe_print(f"  • {name}: {title}")

    safe_print(f"\nTotal: {len(prd_files)} PRD(s)")


def status_command() -> None:
    """Show project status (shortcut for /pm:prd-status)."""
    returncode, stdout, stderr = run_pm_script("status")

    if stdout:
        safe_print(stdout)
    if stderr and returncode != 0:
        print_error(f"Error: {stderr}")

    if returncode != 0 and "Script not found" in stderr:
        # Fallback to basic status
        safe_print("📊 Project Status")
        safe_print("=" * 40)

        cwd = Path.cwd()

        # Check PRDs
        prds_dir = cwd / ".claude" / "prds"
        prd_count = len(list(prds_dir.glob("*.md"))) if prds_dir.exists() else 0
        safe_print(f"{get_emoji('📄', '>>>')} PRDs: {prd_count}")

        # Check Epics
        epics_dir = cwd / ".claude" / "epics"
        epic_count = (
            len([d for d in epics_dir.iterdir() if d.is_dir()])
            if epics_dir.exists()
            else 0
        )
        safe_print(f"{get_emoji('📚', '>>>')} Epics: {epic_count}")

        print("\nRun 'ccpm list' to see all PRDs")
        print("Run 'ccpm help' for available commands")


def sync_command() -> None:
    """Sync with GitHub (shortcut for /pm:sync)."""
    returncode, stdout, stderr = run_pm_script("sync")

    if stdout:
        safe_print(stdout)
    if stderr and returncode != 0:
        print_error(f"Error: {stderr}")

    if returncode != 0:
        if "Script not found" in stderr:
            print_warning("Sync script not found. This command requires a GitHub repository.")
            print("Make sure you have:")
            print("  1. Initialized a git repository")
            print("  2. Set up a GitHub remote")
            print("  3. Authenticated with GitHub (gh auth login)")
        raise RuntimeError("Sync command failed")


def import_command(issue_number: Optional[int] = None) -> None:
    """Import GitHub issues (shortcut for /pm:import).

    Args:
        issue_number: Optional specific issue to import
    """
    if issue_number:
        safe_print(f"📥 Importing issue #{issue_number}...")
        # TODO: Implement specific issue import
        print_warning("Specific issue import not yet implemented")
    else:
        safe_print("📥 Importing all open issues...")
        # TODO: Implement bulk import
        print_warning("Bulk issue import not yet implemented")

    safe_print("\nThis feature will be available in a future update.")
