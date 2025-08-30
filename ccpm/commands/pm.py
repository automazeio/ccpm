"""PM workflow commands."""

import subprocess
from pathlib import Path
from typing import Optional

from ..utils.claude import find_claude_cli
from ..utils.console import (
    get_emoji,
    print_error,
    print_info,
    print_warning,
    safe_print,
)


def invoke_claude_command(command: str, description: str = "") -> None:
    """Invoke Claude Code command with progress indication and cancellation support.

    Args:
        command: The command to pass to Claude (e.g., "/pm:sync")
        description: Optional description to show while executing
    """
    # Check if Claude CLI is available
    claude_cli = find_claude_cli()

    if not claude_cli:
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")

    # Check if .claude directory exists
    if not Path(".claude").exists():
        print_error("No CCPM installation found. Run 'ccpm setup .' first.")
        raise RuntimeError("CCPM not installed")

    # Show progress indication with cancellation info
    if description:
        safe_print(f"{get_emoji('⚙️', 'Working...')} {description}")
    else:
        safe_print(
            f"{get_emoji('⚙️', 'Working...')} Executing Claude Code command: {command}"
        )

    safe_print("=" * 60)
    safe_print("Press Ctrl+C to cancel...")

    # Get configurable timeout
    from ..utils.shell import DEFAULT_TIMEOUTS, get_timeout_for_operation

    timeout = get_timeout_for_operation(
        "claude_command", DEFAULT_TIMEOUTS["claude_command"]
    )

    # Invoke Claude with the command
    try:
        # Use -p flag to get direct output without interactive session
        result = subprocess.run(
            [claude_cli, "-p", command],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=Path.cwd(),
        )

        if result.stdout:
            safe_print(result.stdout)
        if result.stderr:
            print_error(f"Claude stderr: {result.stderr}")

        if result.returncode != 0:
            print_error(f"Command completed with exit code {result.returncode}")
            raise RuntimeError(f"Claude command failed: {command}")
        else:
            safe_print("=" * 60)
            safe_print(f"{get_emoji('✅', 'Done!')} Command completed successfully")

    except subprocess.TimeoutExpired as exc:
        print_error(f"Command timed out after {timeout} seconds: {command}")
        print_info("Consider:")
        print_info("  • Breaking the operation into smaller steps")
        print_info(
            f"  • Setting CCPM_TIMEOUT_CLAUDE_COMMAND={timeout * 2} for longer timeout"
        )
        print_info("  • Checking if Claude Code is responsive")
        raise RuntimeError("Claude command timeout - operation too complex") from exc
    except Exception as exc:
        print_error(f"Failed to execute Claude command: {exc}")
        raise RuntimeError(f"Claude command execution failed: {exc}") from exc


def init_command() -> None:
    """Initialize PM system (shortcut for /pm:init)."""
    # Check if Claude is available first
    from ..utils.claude import claude_available

    if not claude_available():
        import os

        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping init command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")
    invoke_claude_command(
        "/pm:init", "Initializing PM system and configuring GitHub integration"
    )


def list_command() -> None:
    """List all PRDs with detailed information."""
    # First check if .claude directory exists
    cwd = Path.cwd()
    if not (cwd / ".claude").exists():
        print_error("No CCPM installation found. Run 'ccpm setup .' first.")
        raise RuntimeError("CCPM not installed")

    safe_print(f"{get_emoji('🔍', 'Searching for PRDs...')}")

    # Check for PRDs directory
    prds_dir = cwd / ".claude" / "prds"
    if not prds_dir.exists():
        safe_print("\n" + "=" * 50)
        safe_print(f"{get_emoji('📄', 'PRDs')} Product Requirements Documents")
        safe_print("=" * 50)
        safe_print(f"  No PRDs directory found at {prds_dir}")
        safe_print("  Create your first PRD using: /pm:prd-new <name> (in Claude Code)")
        safe_print("  Or set up the directory structure with: ccpm init")
        return

    # List PRD files
    prd_files = list(prds_dir.glob("*.md"))

    safe_print("\n" + "=" * 50)
    safe_print(f"{get_emoji('📄', 'PRDs')} Product Requirements Documents")
    safe_print("=" * 50)

    if not prd_files:
        safe_print(f"  No PRD files found in {prds_dir}")
        safe_print("  Create your first PRD using: /pm:prd-new <name> (in Claude Code)")
        safe_print("\nTotal: 0 PRDs")
        return

    for prd_file in sorted(prd_files):
        name = prd_file.stem
        # Try to read the first line as title and get file stats
        try:
            with open(prd_file, "r") as f:
                content = f.read()
                first_line = content.split("\n")[0].strip()
                if first_line.startswith("#"):
                    title = first_line.lstrip("#").strip()
                else:
                    title = name

                # Get basic stats
                lines = len(content.split("\n"))
                words = len(content.split())

        except Exception:
            title = name
            lines = words = 0

        safe_print(f"  {get_emoji('📄', '•')} {name}")
        safe_print(f"    Title: {title}")
        safe_print(f"    Stats: {lines} lines, {words} words")
        safe_print(f"    Path:  {prd_file}")
        safe_print("")

    safe_print(f"Total: {len(prd_files)} PRD(s)")
    safe_print(f"Location: {prds_dir}")

    # Also check for related epics
    epics_dir = cwd / ".claude" / "epics"
    if epics_dir.exists():
        epic_dirs = [d for d in epics_dir.iterdir() if d.is_dir()]
        if epic_dirs:
            safe_print(f"\nRelated: {len(epic_dirs)} epic(s) in {epics_dir}")

    safe_print(
        f"\n{get_emoji('💡', 'Tip:')} Use 'ccpm status' for detailed project dashboard"
    )


def status_command() -> None:
    """Show project status (shortcut for /pm:prd-status)."""
    # Check if Claude is available first
    from ..utils.claude import claude_available

    if not claude_available():
        import os

        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping status command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")
    invoke_claude_command("/pm:status", "Generating project status dashboard")


def sync_command() -> None:
    """Sync with GitHub (shortcut for /pm:sync)."""
    # Check if Claude is available first
    from ..utils.claude import claude_available

    if not claude_available():
        import os

        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping sync command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")
    invoke_claude_command("/pm:sync", "Synchronizing project data with GitHub")


def import_command(issue_number: Optional[int] = None) -> None:
    """Import GitHub issues (shortcut for /pm:import).

    Args:
        issue_number: Optional specific issue to import
    """
    # Check if Claude is available first
    from ..utils.claude import claude_available

    if not claude_available():
        import os

        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping import command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")
    if issue_number:
        invoke_claude_command(
            f"/pm:issue-import {issue_number}",
            f"Importing GitHub issue #{issue_number}",
        )
    else:
        invoke_claude_command("/pm:import", "Importing all GitHub issues")
