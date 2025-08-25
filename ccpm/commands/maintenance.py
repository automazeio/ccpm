"""Maintenance and utility commands."""

import subprocess
from pathlib import Path

from ..utils.claude import find_claude_cli
from ..utils.console import (
    print_error,
    print_info,
    print_warning,
    safe_print,
)
from ..utils.shell import run_pm_script


def invoke_claude_command(command: str) -> None:
    """Invoke a Claude Code command directly.

    Args:
        command: The command to pass to Claude (e.g., "/pm:validate")
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


def validate_command() -> None:
    """Validate system integrity (shortcut for /pm:validate)."""
    # Check if Claude is available first
    from ..utils.claude import claude_available

    if not claude_available():
        import os

        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping validate command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")
    invoke_claude_command("/pm:validate")


def clean_command() -> None:
    """Archive completed work (shortcut for /pm:clean)."""
    # Check if Claude is available first
    from ..utils.claude import claude_available

    if not claude_available():
        import os

        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping clean command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")
    invoke_claude_command("/pm:clean")


def search_command(query: str) -> None:
    """Search across all content (shortcut for /pm:search).

    Args:
        query: Search term
    """
    if not query or not query.strip():
        print_error("Search query is required")
        raise RuntimeError("Empty search query")

    # Check if Claude is available first
    from ..utils.claude import claude_available

    if not claude_available():
        import os

        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping search command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")

    invoke_claude_command(f"/pm:search {query}")


def help_command() -> None:
    """Display CCPM help and command summary."""
    returncode, stdout, stderr = run_pm_script("help")

    if stdout:
        print(stdout)
    elif returncode != 0 or "Script not found" in stderr:
        # Fallback help text
        print(
            """
📚 CCPM - Claude Code Project Management CLI
=============================================

🎯 Quick Start
  ccpm setup <path>    Set up CCPM in a repository
  ccpm init           Initialize PM system
  ccpm help           Show this help message

📄 PRD Commands
  ccpm list           List all PRDs
  ccpm status         Show project status

🔄 Workflow Commands
  ccpm sync           Sync with GitHub
  ccpm import         Import GitHub issues

🔧 Maintenance
  ccpm update         Update CCPM to latest version
  ccpm validate       Check system integrity
  ccpm clean          Archive completed work
  ccpm search <term>  Search across all content
  ccpm uninstall      Remove CCPM (preserves existing content)

💡 Tips
  • Use Claude Code commands for full functionality:
    /pm:prd-new <name>    Create new PRD
    /pm:epic-start <name> Start epic execution
    /pm:next             Get next priority task

  • View README.md for complete documentation
        """
        )

    if stderr and returncode != 0 and "Script not found" not in stderr:
        print_warning(f"\nWarning: {stderr}")
