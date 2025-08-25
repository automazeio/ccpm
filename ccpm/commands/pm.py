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


def invoke_claude_command(command: str) -> None:
    """Invoke a Claude Code command directly.

    Args:
        command: The command to pass to Claude (e.g., "/pm:sync")
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

    # Invoke Claude with the command
    try:
        # Use -p flag to get direct output without interactive session
        result = subprocess.run(
            [claude_cli, "-p", command],
            capture_output=True,
            text=True,
            timeout=1800,  # 30 minute timeout
            cwd=Path.cwd(),
        )

        if result.stdout:
            safe_print(result.stdout)
        if result.stderr:
            print_error(result.stderr)

        if result.returncode != 0:
            raise RuntimeError(f"Claude command failed: {command}")

    except subprocess.TimeoutExpired:
        print_error(f"Command timed out: {command}")
        raise RuntimeError("Command timeout")
    except Exception as e:
        print_error(f"Failed to execute Claude command: {e}")
        raise


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
    invoke_claude_command("/pm:init")


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
    invoke_claude_command("/pm:status")


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
    invoke_claude_command("/pm:sync")


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
        invoke_claude_command(f"/pm:issue-import {issue_number}")
    else:
        invoke_claude_command("/pm:import")
