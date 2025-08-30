"""Utilities for finding and invoking Claude Code CLI."""

import os
import shutil
from pathlib import Path
from typing import Optional


def find_claude_cli() -> Optional[str]:
    """Find the Claude Code CLI executable.

    Checks multiple locations:
    1. System PATH
    2. Common user installation at ~/.claude/local/claude
    3. Common system locations

    Returns:
        Path to claude executable if found, None otherwise
    """
    # Check if claude is in PATH
    claude_path = shutil.which("claude")
    if claude_path:
        return claude_path

    # Check common installation locations
    possible_locations = [
        Path.home() / ".claude" / "local" / "claude",
        Path("/usr/local/bin/claude"),
        Path("/opt/homebrew/bin/claude"),
    ]

    for location in possible_locations:
        if location.exists() and os.access(location, os.X_OK):
            return str(location)

    return None


def claude_available() -> bool:
    """Check if Claude Code CLI is available.

    Returns:
        True if Claude CLI is found, False otherwise
    """
    return find_claude_cli() is not None
