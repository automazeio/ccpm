"""Shell command execution utilities."""

import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Default timeout values in seconds
DEFAULT_TIMEOUTS = {
    "pm_script": 300,  # 5 minutes for PM scripts
    "git_command": 60,  # 1 minute for git operations
    "claude_command": 1800,  # 30 minutes for Claude operations
    "github_api": 30,  # 30 seconds for GitHub API
}


def get_timeout_for_operation(operation: str, default: int) -> int:
    """Get timeout for specific operation with environment override.

    Args:
        operation: Operation name (e.g., 'pm_script', 'git_command')
        default: Default timeout value

    Returns:
        Timeout value in seconds
    """
    # Check for environment override
    env_var = f"CCPM_TIMEOUT_{operation.upper()}"
    env_timeout = os.environ.get(env_var)

    if env_timeout:
        try:
            return int(env_timeout)
        except ValueError:
            # Invalid value, use default
            pass

    return default


def get_shell_environment() -> Dict[str, str]:
    """Detect and configure cross-platform shell environment.

    Returns:
        Dictionary with shell environment information
    """
    env_info = {
        "platform": sys.platform,
        "shell_available": False,
        "shell_path": None,
        "shell_type": None,
    }

    if sys.platform == "win32":
        # Try multiple Windows shell options in order of preference
        candidates = [
            ("git-bash", _find_git_bash()),
            ("wsl-bash", _find_wsl_bash()),
            ("msys2-bash", _find_msys2_bash()),
        ]

        for shell_type, shell_path in candidates:
            if shell_path:
                env_info.update(
                    {
                        "shell_available": True,
                        "shell_path": shell_path,
                        "shell_type": shell_type,
                    }
                )
                break
    else:
        # Unix-like systems
        bash_path = shutil.which("bash")
        if bash_path:
            env_info.update(
                {"shell_available": True, "shell_path": bash_path, "shell_type": "bash"}
            )

    return env_info


def _find_git_bash() -> Optional[str]:
    """Find Git Bash on Windows."""
    git_path = shutil.which("git")
    if not git_path:
        return None

    git_dir = Path(git_path).parent.parent
    potential_bash_paths = [
        git_dir / "bin" / "bash.exe",
        git_dir / "usr" / "bin" / "bash.exe",
        git_dir / "git-bash.exe",
    ]

    for bash_path in potential_bash_paths:
        if bash_path.exists():
            return str(bash_path)
    return None


def _find_wsl_bash() -> Optional[str]:
    """Find WSL bash on Windows."""
    wsl_path = shutil.which("wsl")
    if wsl_path:
        # Test if WSL bash is available
        try:
            result = subprocess.run(
                [wsl_path, "which", "bash"],
                capture_output=True,
                timeout=5,
                text=True,
                encoding='utf-8',
                errors='replace'
            )
            if result.returncode == 0:
                return wsl_path
        except (subprocess.TimeoutExpired, FileNotFoundError, UnicodeDecodeError):
            pass
    return None


def _find_msys2_bash() -> Optional[str]:
    """Find MSYS2 bash on Windows."""
    # Common MSYS2 installation paths
    msys2_paths = [
        Path("C:/msys64/usr/bin/bash.exe"),
        Path("C:/msys32/usr/bin/bash.exe"),
        Path(os.path.expanduser("~/msys64/usr/bin/bash.exe")),
        Path(os.path.expanduser("~/msys32/usr/bin/bash.exe")),
    ]

    for bash_path in msys2_paths:
        if bash_path.exists():
            return str(bash_path)
    return None


def run_pm_script(
    script_name: str,
    args: Optional[List[str]] = None,
    cwd: Optional[Path] = None,
    timeout: Optional[int] = None,
) -> Tuple[int, str, str]:
    """Execute PM shell scripts with configurable timeout.

    Args:
        script_name: Name of the script (without .sh extension)
        args: Optional arguments to pass to the script
        cwd: Working directory for script execution
        timeout: Optional timeout in seconds (overrides default)

    Returns:
        Tuple of (return_code, stdout, stderr)
    """
    if cwd is None:
        cwd = Path.cwd()

    script_path = cwd / ".claude" / "scripts" / "pm" / f"{script_name}.sh"

    if not script_path.exists():
        return 1, "", f"Script not found: {script_path}"

    # Use cross-platform shell detection
    shell_env = get_shell_environment()

    if not shell_env["shell_available"]:
        return (
            1,
            "",
            f"No compatible shell found for script '{script_name}'. "
            f"On Windows, install Git for Windows, WSL, or MSYS2.",
        )

    # Build command based on shell type
    if shell_env["shell_type"] == "wsl-bash":
        # For WSL, we need to use wsl bash instead of direct bash
        cmd = [shell_env["shell_path"], "bash", str(script_path)]
    elif shell_env["shell_type"] == "git-bash" and sys.platform == "win32":
        # For Git Bash on Windows, convert Windows path to Git Bash format
        script_path_str = str(script_path).replace("\\", "/")
        if script_path_str[1:3] == ":/":  # C:/ -> /c/
            script_path_str = "/" + script_path_str[0].lower() + script_path_str[2:]
        cmd = [shell_env["shell_path"], script_path_str]
    else:
        # For msys2-bash, or unix bash
        cmd = [shell_env["shell_path"], str(script_path)]

    if args:
        cmd.extend(args)

    # Get configurable timeout
    if timeout is None:
        timeout = get_timeout_for_operation("pm_script", DEFAULT_TIMEOUTS["pm_script"])

        # Check for script-specific timeout override
        script_timeout_env = f"CCPM_TIMEOUT_{script_name.upper()}"
        script_timeout = os.environ.get(script_timeout_env)
        if script_timeout:
            try:
                timeout = int(script_timeout)
            except ValueError:
                pass  # Use default timeout

    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 1, "", f"Script '{script_name}' timed out after {timeout} seconds"
    except Exception as exc:
        return 1, "", f"Error running script '{script_name}': {exc}"


def run_command(
    args: List[str],
    cwd: Optional[Path] = None,
    timeout: Optional[int] = None,
    check: bool = False,
) -> Tuple[int, str, str]:
    """Run a shell command and return the result.

    Args:
        args: Command and arguments as list
        cwd: Working directory for command
        timeout: Command timeout in seconds (None for auto-detection)
        check: Whether to raise exception on non-zero return

    Returns:
        Tuple of (return_code, stdout, stderr)

    Raises:
        subprocess.CalledProcessError: If check=True and command fails
    """
    # Auto-detect timeout based on command type if not specified
    if timeout is None:
        command = args[0] if args else "unknown"
        if command == "git":
            timeout = get_timeout_for_operation(
                "git_command", DEFAULT_TIMEOUTS["git_command"]
            )
        elif command in ["gh", "github"]:
            timeout = get_timeout_for_operation(
                "github_api", DEFAULT_TIMEOUTS["github_api"]
            )
        else:
            timeout = 60  # Default 1 minute timeout

    try:
        result = subprocess.run(
            args, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=check
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 1, "", f"Command timed out after {timeout} seconds"
    except subprocess.CalledProcessError as e:
        if check:
            raise
        return e.returncode, e.stdout, e.stderr
    except FileNotFoundError:
        return 1, "", f"Command not found: {args[0]}"
    except Exception as exc:
        return 1, "", f"Error running command: {exc}"
