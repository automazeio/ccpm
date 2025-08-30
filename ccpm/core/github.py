"""GitHub CLI wrapper with automatic installation."""

import os
import platform
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple

from ..utils.console import (
    get_emoji,
    print_error,
    print_info,
    print_success,
    print_warning,
    safe_print,
)


class GitHubCLI:
    """Wrapper around gh CLI with automatic installation."""

    def ensure_gh_installed(self) -> bool:
        """Check and install GitHub CLI if needed."""
        if self.check_installation():
            print_success("GitHub CLI already installed")
            return True

        safe_print(f"{get_emoji('📦', '>>>')} GitHub CLI not found. Installing...")
        return self.install_gh()

    def check_installation(self) -> bool:
        """Verify gh CLI is installed."""
        try:
            result = subprocess.run(
                ["gh", "--version"], capture_output=True, text=True, timeout=5
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False

    def install_gh(self) -> bool:
        """Install GitHub CLI for the current platform."""
        system = platform.system()

        if system == "Darwin":  # macOS
            return self._install_gh_macos()
        elif system == "Linux":
            return self._install_gh_linux()
        elif system == "Windows":
            return self._install_gh_windows()
        else:
            print_error(f"Unsupported platform: {system}")
            print("Please install GitHub CLI manually: https://cli.github.com/")
            return False

    def _install_gh_macos(self) -> bool:
        """Install gh on macOS."""
        # Try Homebrew first
        try:
            brew_check = subprocess.run(
                ["which", "brew"], capture_output=True, timeout=5
            )
            if brew_check.returncode == 0:
                print("Installing via Homebrew...")
                result = subprocess.run(
                    ["brew", "install", "gh"],
                    capture_output=True,
                    text=True,
                    timeout=300,  # 5 minutes timeout
                )
                if result.returncode == 0:
                    print_success("GitHub CLI installed via Homebrew")
                    return True
                else:
                    print_warning(f"Homebrew installation failed: {result.stderr}")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Fallback to downloading binary
        print("Installing GitHub CLI binary...")
        try:
            # Download the latest release
            download_cmd = (
                "curl -sL https://api.github.com/repos/cli/cli/releases/latest | "
                "grep 'browser_download_url.*macOS.*tar.gz' | "
                "cut -d : -f 2,3 | "
                "tr -d '\" ' | "
                "xargs curl -L -o /tmp/gh.tar.gz"
            )

            result = subprocess.run(
                download_cmd, shell=True, capture_output=True, text=True, timeout=120
            )

            if result.returncode != 0:
                print_error(f"Failed to download GitHub CLI: {result.stderr}")
                return False

            # Extract and install
            commands = [
                "cd /tmp && tar -xzf gh.tar.gz",
                "sudo mv /tmp/gh_*/bin/gh /usr/local/bin/",
                "rm -rf /tmp/gh*",
            ]

            for cmd in commands:
                result = subprocess.run(
                    cmd, shell=True, capture_output=True, text=True, timeout=30
                )
                if result.returncode != 0:
                    print_error(f"Installation step failed: {cmd}")
                    print(f"Error: {result.stderr}")
                    return False

            print_success("GitHub CLI installed successfully")
            return True

        except Exception as exc:
            print_error(f"Failed to install GitHub CLI: {exc}")
            return False

    def _install_gh_linux(self) -> bool:
        """Install gh on Linux."""
        # Detect distribution
        if Path("/etc/debian_version").exists():
            # Debian/Ubuntu
            print("Installing via apt...")
            commands = [
                "curl -fsSL https://cli.github.com/packages/"
                "githubcli-archive-keyring.gpg | sudo gpg --dearmor "
                "-o /usr/share/keyrings/githubcli-archive-keyring.gpg",
                'echo "deb [arch=$(dpkg --print-architecture) '
                "signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] "
                'https://cli.github.com/packages stable main" | '
                "sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null",
                "sudo apt update",
                "sudo apt install gh -y",
            ]

            for cmd in commands:
                try:
                    result = subprocess.run(
                        cmd, shell=True, capture_output=True, text=True, timeout=120
                    )
                    if result.returncode != 0:
                        print_warning(f"Command failed: {cmd[:50]}...")
                        print(f"Error: {result.stderr}")
                        # Continue trying other commands
                except subprocess.TimeoutExpired:
                    print_warning(f"Command timed out: {cmd[:50]}...")
                    return False

            # Verify installation
            if self.check_installation():
                print_success("GitHub CLI installed via apt")
                return True

        elif Path("/etc/redhat-release").exists():
            # RHEL/Fedora
            print("Installing via dnf...")
            try:
                result = subprocess.run(
                    ["sudo", "dnf", "install", "-y", "gh"],
                    capture_output=True,
                    text=True,
                    timeout=300,
                )
                if result.returncode == 0:
                    print_success("GitHub CLI installed via dnf")
                    return True
            except subprocess.TimeoutExpired:
                print_warning("Installation timed out")
                return False

        # Generic Linux - download binary
        print("Installing GitHub CLI binary...")
        arch = "amd64" if platform.machine() == "x86_64" else "arm64"

        try:
            # Download the latest release
            download_cmd = (
                f"curl -sL https://api.github.com/repos/cli/cli/releases/latest | "
                f"grep 'browser_download_url.*linux_{arch}.tar.gz' | "
                f"cut -d : -f 2,3 | "
                f"tr -d '\" ' | "
                f"xargs curl -L -o /tmp/gh.tar.gz"
            )

            result = subprocess.run(
                download_cmd, shell=True, capture_output=True, text=True, timeout=120
            )

            if result.returncode != 0:
                print_error(f"Failed to download GitHub CLI: {result.stderr}")
                return False

            # Extract and install
            commands = [
                "cd /tmp && tar -xzf gh.tar.gz",
                "sudo mv /tmp/gh_*/bin/gh /usr/local/bin/",
                "rm -rf /tmp/gh*",
            ]

            for cmd in commands:
                result = subprocess.run(
                    cmd, shell=True, capture_output=True, text=True, timeout=30
                )
                if result.returncode != 0:
                    print_error(f"Installation step failed: {cmd}")
                    return False

            print_success("GitHub CLI installed successfully")
            return True

        except Exception as exc:
            print_error(f"Failed to install GitHub CLI: {exc}")
            return False

    def _install_gh_windows(self) -> bool:
        """Install gh on Windows."""
        # Try winget first
        try:
            result = subprocess.run(
                ["where", "winget"], capture_output=True, shell=True, timeout=5
            )
            if result.returncode == 0:
                print("Installing via winget...")
                result = subprocess.run(
                    ["winget", "install", "--id", "GitHub.cli", "-e"],
                    capture_output=True,
                    text=True,
                    timeout=300,
                )
                if result.returncode == 0:
                    print_success("GitHub CLI installed via winget")
                    return True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Try Chocolatey
        try:
            result = subprocess.run(
                ["where", "choco"], capture_output=True, shell=True, timeout=5
            )
            if result.returncode == 0:
                print("Installing via Chocolatey...")
                result = subprocess.run(
                    ["choco", "install", "gh", "-y"],
                    capture_output=True,
                    text=True,
                    timeout=300,
                )
                if result.returncode == 0:
                    print_success("GitHub CLI installed via Chocolatey")
                    return True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Fallback to manual download
        print_error("Automatic installation not available on Windows")
        print("Please download and install GitHub CLI manually:")
        print("https://github.com/cli/cli/releases/latest")
        print("\nDownload the .msi installer for Windows and run it.")
        return False

    def setup_auth(self) -> bool:
        """Setup GitHub authentication."""
        # Check if already authenticated
        try:
            result = subprocess.run(
                ["gh", "auth", "status"], capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                print_success("GitHub CLI already authenticated")
                return True
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass

        # Skip interactive auth in CI environments
        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            print_warning(
                "Running in CI environment - skipping interactive GitHub authentication"
            )
            print_info("Set GITHUB_TOKEN environment variable for CI authentication")
            return False

        safe_print("\n🔐 Setting up GitHub authentication...")
        print("Please follow the prompts to authenticate with GitHub:")
        print("(You'll need to press Enter to continue, then follow the browser flow)")

        try:
            result = subprocess.run(["gh", "auth", "login"])
            return result.returncode == 0
        except FileNotFoundError:
            print_error("GitHub CLI not found. Please install it first.")
            return False

    def install_extensions(self) -> bool:
        """Install required gh extensions."""
        safe_print(f"\n{get_emoji('📦', '>>>')} Installing gh-sub-issue extension...")

        try:
            # First check if already installed
            list_result = subprocess.run(
                ["gh", "extension", "list"], capture_output=True, text=True, timeout=10
            )

            if "yahsan2/gh-sub-issue" in list_result.stdout:
                print_success("gh-sub-issue extension already installed")
                return True

            # Skip extension installation in CI if not authenticated
            if (
                os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS")
            ) and list_result.returncode != 0:
                print_warning(
                    "Skipping extension installation in CI - "
                    "GitHub CLI not authenticated"
                )
                return True  # Don't fail the setup

            # Install the extension
            result = subprocess.run(
                ["gh", "extension", "install", "yahsan2/gh-sub-issue"],
                capture_output=True,
                text=True,
                timeout=60,
            )

            if result.returncode == 0:
                print_success("gh-sub-issue extension installed successfully")
                return True
            else:
                print_warning(f"Failed to install extension: {result.stderr}")
                return False

        except subprocess.TimeoutExpired:
            print_warning("Extension installation timed out")
            return False
        except FileNotFoundError:
            print_error("GitHub CLI not found")
            return False

    def run_command(
        self, args: List[str], cwd: Optional[Path] = None
    ) -> Tuple[int, str, str]:
        """Run a gh command and return the result.

        Args:
            args: Command arguments (e.g., ["issue", "list"])
            cwd: Working directory for the command

        Returns:
            Tuple of (return_code, stdout, stderr)
        """
        try:
            result = subprocess.run(
                ["gh"] + args, capture_output=True, text=True, cwd=cwd, timeout=30
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return 1, "", "Command timed out"
        except FileNotFoundError:
            return 1, "", "GitHub CLI not found"
