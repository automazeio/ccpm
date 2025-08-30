"""Pytest configuration and fixtures for CCPM tests."""

import subprocess
import tempfile
from pathlib import Path
from typing import Generator

import pytest

# Import the claude utility to check for Claude Code
try:
    from ccpm.utils.claude import claude_available
except ImportError:

    def claude_available():
        return False


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "requires_claude: mark test as requiring Claude Code CLI"
    )


def pytest_collection_modifyitems(config, items):
    """Automatically skip tests that require Claude Code in CI environments."""
    # In CI, we want to skip tests that require Claude Code if it's not available
    # The tests already have skipif decorators, but we need to ensure claude_available
    # returns False in CI when Claude is not installed
    pass  # Let the existing skipif decorators handle it


@pytest.fixture
def real_git_repo() -> Generator[Path, None, None]:
    """Create a real git repository for testing.

    Yields:
        Path to the temporary git repository
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir) / "test_repo"
        repo_path.mkdir()

        # Initialize real git repo
        subprocess.run(["git", "init"], cwd=repo_path, check=True)
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"],
            cwd=repo_path,
            check=True,
        )
        subprocess.run(
            ["git", "config", "user.name", "Test User"], cwd=repo_path, check=True
        )

        # Create initial commit
        readme = repo_path / "README.md"
        readme.write_text("# Test Repository\n\nThis is a test repository for CCPM.")

        subprocess.run(["git", "add", "."], cwd=repo_path, check=True)
        subprocess.run(
            ["git", "commit", "-m", "Initial commit"], cwd=repo_path, check=True
        )

        yield repo_path


@pytest.fixture
def repo_with_existing_claude(real_git_repo: Path) -> Path:
    """Create a repository with existing .claude directory.

    Args:
        real_git_repo: Base git repository fixture

    Returns:
        Path to repository with existing .claude content
    """
    claude_dir = real_git_repo / ".claude"
    claude_dir.mkdir()

    # Add some existing content
    custom_file = claude_dir / "custom.md"
    custom_file.write_text("# Custom Content\n\nThis is user-created content.")

    custom_dir = claude_dir / "custom_dir"
    custom_dir.mkdir()
    (custom_dir / "file.txt").write_text("User file")

    # Add to git
    subprocess.run(["git", "add", "."], cwd=real_git_repo, check=True)
    subprocess.run(
        ["git", "commit", "-m", "Add existing .claude content"],
        cwd=real_git_repo,
        check=True,
    )

    return real_git_repo


@pytest.fixture
def ccpm_source() -> Path:
    """Get the CCPM source directory.

    Returns:
        Path to the CCPM source .claude directory
    """
    # Use the actual .claude directory from our project
    source = Path(__file__).parent.parent / ".claude"
    if not source.exists():
        pytest.skip(".claude directory not found in project")
    return source


@pytest.fixture
def github_cli_available() -> bool:
    """Check if GitHub CLI is available.

    Returns:
        True if gh CLI is installed and authenticated
    """
    try:
        # Check if gh is installed
        result = subprocess.run(["gh", "--version"], capture_output=True, timeout=5)
        if result.returncode != 0:
            return False

        # Check if authenticated
        result = subprocess.run(
            ["gh", "auth", "status"], capture_output=True, timeout=5
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


@pytest.fixture
def mock_ccpm_repo(tmp_path: Path) -> Path:
    """Create a mock CCPM repository structure.

    Args:
        tmp_path: Pytest tmp_path fixture

    Returns:
        Path to mock CCPM repo
    """
    repo = tmp_path / "ccpm"
    repo.mkdir()

    # Create .claude directory structure
    claude = repo / ".claude"
    claude.mkdir()

    # Create subdirectories
    for subdir in ["scripts/pm", "commands/pm", "agents", "prds", "epics"]:
        (claude / subdir).mkdir(parents=True)

    # Create some essential files
    (claude / "CLAUDE.md").write_text("# CLAUDE.md\n\nTest instructions")
    (claude / "scripts" / "pm" / "init.sh").write_text(
        "#!/bin/bash\necho 'Initialized'"
    )
    (claude / "scripts" / "pm" / "help.sh").write_text("#!/bin/bash\necho 'Help text'")

    return repo
