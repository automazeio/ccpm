"""Console output utilities with cross-platform support."""

import os
import sys
from typing import Optional

from .emoji_map import EMOJI_MAP


def is_interactive_environment() -> bool:
    """Detect if running in interactive environment.

    Returns:
        True if interactive, False if non-interactive/automated
    """
    # Check TTY
    if not sys.stdin.isatty():
        return False

    # Check CI environments
    ci_indicators = [
        "CI",
        "GITHUB_ACTIONS",
        "JENKINS_URL",
        "TRAVIS",
        "CIRCLECI",
        "BUILDBOT_WORKER",
        "GITLAB_CI",
    ]

    if any(os.environ.get(indicator) for indicator in ci_indicators):
        return False

    # Check automation flags
    if os.environ.get("CCPM_FORCE") or os.environ.get("AUTOMATION_MODE"):
        return False

    return True


def safe_input(
    prompt: str, default: str = "N", force_value: Optional[str] = None
) -> str:
    """Safe input with non-interactive fallback.

    Args:
        prompt: Input prompt to display
        default: Default value for non-interactive mode
        force_value: Override value (for testing/automation)

    Returns:
        User input or default value
    """
    # Check for forced value (testing, automation)
    if force_value is not None:
        return force_value

    # Check environment override
    if not is_interactive_environment():
        print_info(f"Non-interactive mode: using default '{default}' for: {prompt}")
        return default

    # Interactive input
    try:
        return input(prompt)
    except (EOFError, KeyboardInterrupt):
        print_info(f"Input interrupted, using default: {default}")
        return default


def strip_emojis(text: str) -> str:
    """Remove all emoji characters from text.

    Args:
        text: Text containing emojis

    Returns:
        Text with emojis replaced by ASCII equivalents
    """
    # Replace known emojis with their ASCII equivalents
    for emoji, ascii_equiv in EMOJI_MAP.items():
        text = text.replace(emoji, ascii_equiv)

    # Remove any remaining Unicode emoji-like characters
    # This catches emojis we might have missed
    if sys.platform == "win32":
        # On Windows, strip out any remaining high Unicode characters
        text = text.encode("ascii", "replace").decode("ascii")

    return text


def get_emoji(emoji: str, fallback: str = "") -> str:
    """Get emoji or fallback for Windows console compatibility.

    Args:
        emoji: The emoji character to use
        fallback: ASCII fallback for Windows (if not in map)

    Returns:
        The emoji on Unix systems, ASCII equivalent on Windows
    """
    if sys.platform == "win32":
        # Try to get from map first
        return EMOJI_MAP.get(emoji, fallback if fallback else "[?]")
    return emoji


def safe_print(message: str, file=None) -> None:
    """Print a message with automatic emoji handling for Windows.

    Args:
        message: The message to print
        file: Optional file object (defaults to stdout)
    """
    if sys.platform == "win32":
        message = strip_emojis(message)

    try:
        print(message, file=file)
    except UnicodeEncodeError:
        # Final fallback - strip all non-ASCII
        safe_message = message.encode("ascii", "replace").decode("ascii")
        print(safe_message, file=file)


def print_error(message: str) -> None:
    """Print an error message with platform-appropriate formatting.

    Args:
        message: The error message to print
    """
    error_prefix = get_emoji("❌", "[ERROR]")
    safe_print(f"{error_prefix} {message}", file=sys.stderr)


def print_success(message: str) -> None:
    """Print a success message with platform-appropriate formatting.

    Args:
        message: The success message to print
    """
    success_prefix = get_emoji("✅", "[OK]")
    safe_print(f"{success_prefix} {message}")


def print_info(message: str) -> None:
    """Print an info message with platform-appropriate formatting.

    Args:
        message: The info message to print
    """
    info_prefix = get_emoji("🔍", "[INFO]")
    safe_print(f"{info_prefix} {message}")


def print_warning(message: str) -> None:
    """Print a warning message with platform-appropriate formatting.

    Args:
        message: The warning message to print
    """
    warning_prefix = get_emoji("⚠️", "[WARN]")
    safe_print(f"{warning_prefix} {message}")
