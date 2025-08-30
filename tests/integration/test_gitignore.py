"""Integration tests for .gitignore effectiveness with build artifacts.

These tests verify that .gitignore properly excludes build artifacts
from version control using real git operations and file creation.
"""

import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import List

import pytest


class TestGitignoreEffectiveness:
    """Test .gitignore with real git operations and build artifacts."""

    @pytest.fixture
    def git_repo_with_ccpm(self):
        """Create a real git repo with CCPM files for testing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir) / "test_repo"

            # Copy current project to test repo
            project_root = Path(__file__).parent.parent.parent
            shutil.copytree(
                project_root,
                repo_path,
                ignore=shutil.ignore_patterns(
                    "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
                ),
            )

            # Initialize git repo
            subprocess.run(
                ["git", "init"], cwd=repo_path, check=True, capture_output=True
            )
            subprocess.run(
                ["git", "config", "user.email", "test@example.com"],
                cwd=repo_path,
                check=True,
                capture_output=True,
            )
            subprocess.run(
                ["git", "config", "user.name", "Test User"],
                cwd=repo_path,
                check=True,
                capture_output=True,
            )

            # Add and commit initial state
            subprocess.run(
                ["git", "add", "."], cwd=repo_path, check=True, capture_output=True
            )
            subprocess.run(
                ["git", "commit", "-m", "Initial commit"],
                cwd=repo_path,
                check=True,
                capture_output=True,
            )

            yield repo_path

    def _get_git_status_files(self, repo_path: Path) -> List[str]:
        """Get list of untracked/modified files from git status."""
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            raise RuntimeError(f"Git status failed: {result.stderr}")

        # Parse git status output
        files = []
        for line in result.stdout.splitlines():
            if line.strip():
                # Format: "XY filename" where X and Y are status codes
                files.append(line[3:].strip())  # Remove status codes and spaces

        return files

    def test_egg_info_directories_ignored(self, git_repo_with_ccpm):
        """Test that .egg-info directories are properly ignored."""
        repo_path = git_repo_with_ccpm

        # Create various .egg-info directories that could be generated
        egg_info_dirs = [
            "ccpm.egg-info",
            "CCPM.egg-info",
            "ccpm_cli.egg-info",
            "some_package.egg-info",
        ]

        for dir_name in egg_info_dirs:
            egg_dir = repo_path / dir_name
            egg_dir.mkdir(exist_ok=True)

            # Create typical .egg-info contents
            (egg_dir / "PKG-INFO").write_text("Name: test\nVersion: 1.0.0")
            (egg_dir / "SOURCES.txt").write_text("setup.py\nccpm/__init__.py")
            (egg_dir / "dependency_links.txt").write_text("")
            (egg_dir / "requires.txt").write_text("click>=8.0\ngitpython>=3.1")
            (egg_dir / "top_level.txt").write_text("ccpm")

            # Create entry_points.txt
            (egg_dir / "entry_points.txt").write_text(
                """
[console_scripts]
ccpm = ccpm.cli:cli
"""
            )

        # Check git status - should show no new files
        git_status_files = self._get_git_status_files(repo_path)

        # Filter for .egg-info related files
        egg_info_files = [f for f in git_status_files if ".egg-info" in f]

        assert (
            len(egg_info_files) == 0
        ), f"Expected no .egg-info files in git status, but found: {egg_info_files}"

    def test_build_directories_ignored(self, git_repo_with_ccpm):
        """Test that build/ and dist/ directories are ignored."""
        repo_path = git_repo_with_ccpm

        # Create build directory structure
        build_dir = repo_path / "build"
        build_dir.mkdir(exist_ok=True)

        # Create typical build artifacts
        (build_dir / "lib").mkdir(exist_ok=True)
        (build_dir / "lib" / "ccpm").mkdir(exist_ok=True)
        (build_dir / "lib" / "ccpm" / "__init__.py").write_text('__version__ = "0.1.0"')
        (build_dir / "bdist.linux-x86_64").mkdir(exist_ok=True)
        (build_dir / "temp.linux-x86_64-3.12").mkdir(exist_ok=True)

        # Create dist directory
        dist_dir = repo_path / "dist"
        dist_dir.mkdir(exist_ok=True)
        (dist_dir / "ccpm-0.1.0-py3-none-any.whl").write_text("fake wheel content")
        (dist_dir / "ccpm-0.1.0.tar.gz").write_text("fake tarball content")

        # Check git status
        git_status_files = self._get_git_status_files(repo_path)

        # Filter for build-related files
        build_files = [f for f in git_status_files if f.startswith(("build/", "dist/"))]

        assert (
            len(build_files) == 0
        ), f"Expected no build files in git status, but found: {build_files}"

    def test_python_cache_ignored(self, git_repo_with_ccpm):
        """Test that Python cache files are ignored."""
        repo_path = git_repo_with_ccpm

        # Create __pycache__ directories at various levels
        cache_locations = [
            "ccpm/__pycache__",
            "ccpm/commands/__pycache__",
            "ccpm/core/__pycache__",
            "tests/__pycache__",
        ]

        for cache_path in cache_locations:
            cache_dir = repo_path / cache_path
            cache_dir.mkdir(parents=True, exist_ok=True)

            # Create typical .pyc files
            (cache_dir / "__init__.cpython-312.pyc").write_bytes(b"fake pyc content")
            (cache_dir / "cli.cpython-312.pyc").write_bytes(b"fake pyc content")
            (cache_dir / "utils.cpython-312.opt-1.pyc").write_bytes(b"fake pyc content")

        # Create loose .pyc files
        (repo_path / "ccpm" / "test.pyc").write_bytes(b"fake pyc")
        (repo_path / "ccpm" / "other.pyo").write_bytes(b"fake pyo")
        (repo_path / "ccpm" / "binary.pyd").write_bytes(b"fake pyd")

        # Check git status
        git_status_files = self._get_git_status_files(repo_path)

        # Filter for cache files
        cache_files = [
            f
            for f in git_status_files
            if "__pycache__" in f or f.endswith((".pyc", ".pyo", ".pyd"))
        ]

        assert (
            len(cache_files) == 0
        ), f"Expected no cache files in git status, but found: {cache_files}"

    def test_temporary_files_ignored(self, git_repo_with_ccpm):
        """Test that various temporary files are ignored."""
        repo_path = git_repo_with_ccpm

        # Create various temporary/editor files that should be ignored
        temp_files = [
            ".DS_Store",  # macOS
            "Thumbs.db",  # Windows
            ".coverage",
            ".pytest_cache/README.md",
            ".mypy_cache/3.12/ccpm/cli.meta.json",
            "pip-log.txt",
            "pip-delete-this-directory.txt",
        ]

        for temp_file in temp_files:
            file_path = repo_path / temp_file
            file_path.parent.mkdir(parents=True, exist_ok=True)

            if temp_file.endswith("/"):
                file_path.mkdir(parents=True, exist_ok=True)
            else:
                file_path.write_text("temporary content")

        # Check git status
        git_status_files = self._get_git_status_files(repo_path)

        # Filter for temp files (check if any of our temp files appear)
        temp_status_files = []
        for status_file in git_status_files:
            for temp_pattern in temp_files:
                if temp_pattern.rstrip("/") in status_file:
                    temp_status_files.append(status_file)
                    break

        assert (
            len(temp_status_files) == 0
        ), f"Expected no temp files in git status, but found: {temp_status_files}"

    def test_real_pip_install_artifacts_ignored(self, git_repo_with_ccpm):
        """Test that artifacts from real pip install are ignored."""
        repo_path = git_repo_with_ccpm

        # Create common pip install artifacts directly instead of actually installing
        # This avoids corrupting the global ccpm installation during test runs
        artifacts_to_test = [
            "build/lib/ccpm/__init__.py",
            "build/bdist.macosx-10.9-universal2",
            "ccpm.egg-info/PKG-INFO",
            "ccpm.egg-info/dependency_links.txt",
            "dist/ccpm-0.1.0-py3-none-any.whl",
            "dist/ccpm-0.1.0.tar.gz",
            "__pycache__/test.cpython-312.pyc",
            ".pytest_cache/README.md",
        ]

        # Create the artifact directories and files
        for artifact in artifacts_to_test:
            artifact_path = repo_path / artifact
            artifact_path.parent.mkdir(parents=True, exist_ok=True)
            if not artifact.endswith("/"):
                artifact_path.write_text("test content")

        # Check what git sees after creating packaging artifacts
        git_status_files = self._get_git_status_files(repo_path)

        # Filter for packaging artifacts that should be ignored
        packaging_artifacts = [
            f
            for f in git_status_files
            if any(
                pattern in f
                for pattern in [
                    ".egg-info",
                    "build/",
                    "dist/",
                    "__pycache__",
                    ".pytest_cache",
                ]
            )
        ]

        assert len(packaging_artifacts) == 0, (
            f"Created packaging artifacts are not being ignored by git: "
            f"{packaging_artifacts}"
        )

    def test_gitignore_patterns_comprehensive(self, git_repo_with_ccpm):
        """Test comprehensive coverage of .gitignore patterns."""
        repo_path = git_repo_with_ccpm

        # Read .gitignore file
        gitignore_path = repo_path / ".gitignore"
        assert gitignore_path.exists(), ".gitignore file missing"

        gitignore_content = gitignore_path.read_text()

        # Essential patterns that must be present
        required_patterns = [
            "*.egg-info/",
            "__pycache__/",
            "*.pyc",
            "*.pyo",
            "*.pyd",
            "build/",
            "dist/",
            ".coverage",
            ".pytest_cache",
            ".mypy_cache",
            ".DS_Store",
        ]

        missing_patterns = []
        for pattern in required_patterns:
            if pattern not in gitignore_content:
                missing_patterns.append(pattern)

        assert (
            len(missing_patterns) == 0
        ), f"Missing required .gitignore patterns: {missing_patterns}"

    def test_gitignore_does_not_ignore_source_files(self, git_repo_with_ccpm):
        """Test that .gitignore doesn't accidentally ignore legitimate source files."""
        repo_path = git_repo_with_ccpm

        # Create legitimate source files that should NOT be ignored
        source_files = [
            "ccpm/new_module.py",
            "ccpm/commands/new_command.py",
            "tests/test_new_feature.py",
            "docs/new_doc.md",
            "README_new.md",
            "setup_new.py",  # Could be confused with setup artifacts
            "requirements-dev.txt",
        ]

        for source_file in source_files:
            file_path = repo_path / source_file
            file_path.parent.mkdir(parents=True, exist_ok=True)
            file_path.write_text(f"# Content for {source_file}")

        # Add to git to see what happens
        subprocess.run(["git", "add", "."], cwd=repo_path, capture_output=True)

        # Check what files were staged
        result = subprocess.run(
            ["git", "diff", "--name-only", "--cached"],
            cwd=repo_path,
            capture_output=True,
            text=True,
        )

        staged_files = [
            line.strip() for line in result.stdout.splitlines() if line.strip()
        ]

        # All our source files should have been staged
        missing_source_files = []
        for source_file in source_files:
            if source_file not in staged_files:
                missing_source_files.append(source_file)

        assert (
            len(missing_source_files) == 0
        ), f"Source files incorrectly ignored by .gitignore: {missing_source_files}"

    def test_complex_build_scenarios_ignored(self, git_repo_with_ccpm):
        """Test complex build scenarios with multiple tools."""
        repo_path = git_repo_with_ccpm

        # Create artifacts that could be generated by various tools
        complex_artifacts = {
            # setuptools artifacts
            "ccpm.egg-info/PKG-INFO": "Package info",
            "ccpm.egg-info/SOURCES.txt": "Source list",
            "build/lib/ccpm/__init__.py": "Built module",
            "build/bdist.linux-x86_64/egg/ccpm/cli.py": "Built CLI",
            # wheel building
            "build/bdist.linux-x86_64/wheel/ccpm/__init__.py": "Wheel content",
            "dist/ccpm-0.1.0-py3-none-any.whl": "Wheel file",
            "dist/ccpm-0.1.0.tar.gz": "Source dist",
            # pip artifacts
            "pip-wheel-metadata/ccpm.dist-info/METADATA": "Metadata",
            # pytest artifacts
            ".pytest_cache/v/cache/nodeids": "Test cache",
            ".pytest_cache/.gitignore": "Pytest gitignore",
            # mypy artifacts
            ".mypy_cache/3.12/ccpm/__init__.meta.json": "Mypy cache",
            ".mypy_cache/3.12/ccpm/cli.data.json": "Mypy data",
            # coverage artifacts
            ".coverage": "Coverage data",
            "coverage.xml": "Coverage XML",
            "htmlcov/index.html": "Coverage HTML",
            # tox artifacts
            ".tox/py312/lib/python3.12/site-packages/ccpm/__init__.py": "Tox env",
        }

        # Create all the artifacts
        for artifact_path, content in complex_artifacts.items():
            full_path = repo_path / artifact_path
            full_path.parent.mkdir(parents=True, exist_ok=True)
            full_path.write_text(content)

        # Check git status
        git_status_files = self._get_git_status_files(repo_path)

        # None of these artifacts should appear in git status
        appearing_artifacts = []
        for artifact_path in complex_artifacts.keys():
            if artifact_path in git_status_files:
                appearing_artifacts.append(artifact_path)

        assert (
            len(appearing_artifacts) == 0
        ), f"Build artifacts not properly ignored: {appearing_artifacts}"
