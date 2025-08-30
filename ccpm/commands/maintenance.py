"""Maintenance and utility commands."""

import subprocess
from pathlib import Path

from ..utils.claude import find_claude_cli
from ..utils.console import (
    get_emoji,
    print_error,
    print_info,
    print_warning,
    safe_print,
)


def invoke_claude_command(command: str, description: str = "") -> None:
    """Invoke a Claude Code command directly with progress indication.

    Args:
        command: The command to pass to Claude (e.g., "/pm:validate")
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
        safe_print(f"{get_emoji('⚙️', '[Working...]')} {description}")
    else:
        safe_print(
            f"{get_emoji('⚙️', '[Working...]')} "
            f"Executing Claude Code command: {command}"
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
            safe_print(f"{get_emoji('✅', '[Done!]')} Command completed successfully")

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
    invoke_claude_command(
        "/pm:validate", "Validating system integrity and checking for issues"
    )


def clean_command() -> None:
    """Archive completed work (shortcut for /pm:clean)."""
    # Check if Claude is available first
    import os

    from ..utils.claude import claude_available

    if not claude_available():
        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning("Claude Code not available in CI - skipping clean command")
            return
        print_error("Claude Code CLI not found. Please install Claude Code first.")
        print_info("Visit: https://claude.ai/code")
        raise RuntimeError("Claude Code not installed")

    # Check if there's anything to clean before calling Claude
    epics_dir = Path(".claude/epics")
    if not epics_dir.exists():
        safe_print(
            f"{get_emoji('ℹ️', '[Info]')} No epics directory found - nothing to clean"
        )
        return

    # Check if there are any epics (exclude .gitkeep and hidden files)
    epic_dirs = [
        d for d in epics_dir.iterdir() if d.is_dir() and not d.name.startswith(".")
    ]
    epic_files = [f for f in epics_dir.glob("*.md") if not f.name.startswith(".")]

    if not epic_dirs and not epic_files:
        safe_print(
            f"{get_emoji('✨', '[Clean]')} No epics found - system is already clean"
        )
        return

    # Check if any epics are actually completed
    completed_found = False
    for epic_dir in epic_dirs:
        epic_file = epic_dir / "epic.md"
        if epic_file.exists():
            try:
                content = epic_file.read_text()
                if "status: completed" in content:
                    completed_found = True
                    break
            except Exception:
                pass  # Skip unreadable files

    if not completed_found:
        safe_print(
            f"{get_emoji('ℹ️', '[Info]')} No completed epics found - nothing to clean"
        )
        return

    # Only invoke Claude if there's actually something to clean
    invoke_claude_command(
        "/pm:clean", "Archiving completed work and cleaning up old files"
    )


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

    invoke_claude_command(
        f"/pm:search {query}",
        f"Searching for '{query}' across all PRDs, epics, and tasks",
    )


def help_command() -> None:
    """Display CCPM CLI help and command summary."""
    # Always show CLI-focused help instead of PM script help
    safe_print(
        f"""
{get_emoji('📚', '[CCPM]')} CCPM - Claude Code Project Management CLI
=============================================

{get_emoji('🎯', '[Start]')} Quick Start
  ccpm setup <path>    Set up CCPM in a repository
  ccpm init            Initialize PM system
  ccpm help            Show this help message

{get_emoji('📄', '[PM]')} Project Management
  ccpm list            List all PRDs
  ccpm status          Show project status and dashboard

{get_emoji('🔄', '[Sync]')} GitHub Integration
  ccpm sync            Sync with GitHub issues
  ccpm import [num]    Import GitHub issues (all or specific)

{get_emoji('🔧', '[Tools]')} Maintenance & Tools
  ccpm update          Update CCPM to latest version
  ccpm validate        Check system integrity
  ccpm clean           Archive completed work
  ccpm search <term>   Search across all content
  ccpm uninstall       Remove CCPM (preserves existing content)

{get_emoji('💡', '[Advanced]')} Advanced Usage with Claude Code
  Once CCPM is set up, use these commands inside Claude Code for full functionality:
  /pm:prd-new <name>        Create new product requirements
  /pm:prd-parse <name>      Convert PRD to technical epic
  /pm:epic-decompose <name> Break epic into parallel tasks
  /pm:epic-sync <name>      Push epic and tasks to GitHub
  /pm:epic-start <name>     Launch parallel AI agent execution
  /pm:next                  Get next priority task with context

{get_emoji('📄', '[Docs]')} Documentation
  • View README.md for complete setup and workflow documentation
  • Visit https://github.com/jeremymanning/ccpm for examples and updates
"""
    )
