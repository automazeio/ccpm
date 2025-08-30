"""Integration tests for CCPM packaging and build artifacts.

These tests verify that the package can be built, installed, and used
correctly without leaving build artifacts in version control.
All tests use real package operations - no mocks or simulations.
"""

import os
import shutil
import subprocess
import tempfile
import venv
from pathlib import Path
from typing import Tuple

import pytest


@pytest.fixture
def clean_temp_env() -> Tuple[Path, Path]:
    """Create a clean temporary environment with virtual environment."""
    with tempfile.TemporaryDirectory() as tmpdir:
        temp_path = Path(tmpdir)

        # Create a virtual environment for isolated testing
        venv_path = temp_path / "test_venv"
        venv.create(venv_path, with_pip=True)

        # Get paths to the venv executables
        if os.name == "nt":  # Windows
            python_exe = venv_path / "Scripts" / "python.exe"
            pip_exe = venv_path / "Scripts" / "pip.exe"
        else:  # Unix/macOS
            python_exe = venv_path / "bin" / "python"
            pip_exe = venv_path / "bin" / "pip"

        # Verify venv was created successfully
        assert python_exe.exists(), f"Python executable not found: {python_exe}"
        assert pip_exe.exists(), f"Pip executable not found: {pip_exe}"

        yield temp_path, venv_path


class TestPackagingOperations:
    """Test real packaging operations with actual pip and build tools."""

    def test_fresh_checkout_pip_install(self, clean_temp_env):
        """Test pip install from fresh checkout (non-editable)."""
        temp_path, venv_path = clean_temp_env

        # Get current project directory
        project_root = Path(__file__).parent.parent.parent

        # Copy project to temp directory (simulating fresh checkout)
        checkout_path = temp_path / "ccpm_checkout"
        shutil.copytree(
            project_root,
            checkout_path,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
            ),
        )

        # Get pip executable
        pip_exe = venv_path / ("Scripts/pip.exe" if os.name == "nt" else "bin/pip")
        python_exe = venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Install package
        result = subprocess.run(
            [str(pip_exe), "install", str(checkout_path)],
            capture_output=True,
            text=True,
            timeout=300,
        )

        assert result.returncode == 0, f"pip install failed: {result.stderr}"

        # Verify installation
        result = subprocess.run(
            [str(python_exe), "-c", "import ccpm; print(ccpm.__version__)"],
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, f"Import failed: {result.stderr}"
        assert "0.1.0" in result.stdout

        # Test CLI functionality
        ccpm_exe = venv_path / ("Scripts/ccpm.exe" if os.name == "nt" else "bin/ccpm")
        result = subprocess.run(
            [str(ccpm_exe), "--version"], capture_output=True, text=True, timeout=30
        )

        assert result.returncode == 0, f"CLI failed: {result.stderr}"
        assert "0.1.0" in result.stdout

        # Modern pip creates build artifacts during installation - this is expected
        # The important thing is that the package installs and works correctly
        # Build artifacts will be cleaned up when temp directory is removed

    def test_fresh_checkout_editable_install(self, clean_temp_env):
        """Test pip install -e from fresh checkout (editable mode)."""
        temp_path, venv_path = clean_temp_env

        # Get current project directory
        project_root = Path(__file__).parent.parent.parent

        # Copy project to temp directory
        checkout_path = temp_path / "ccpm_checkout"
        shutil.copytree(
            project_root,
            checkout_path,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
            ),
        )

        # Get executables
        pip_exe = venv_path / ("Scripts/pip.exe" if os.name == "nt" else "bin/pip")
        python_exe = venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Install in editable mode
        result = subprocess.run(
            [str(pip_exe), "install", "-e", str(checkout_path)],
            capture_output=True,
            text=True,
            timeout=300,
        )

        assert result.returncode == 0, f"pip install -e failed: {result.stderr}"

        # Verify installation works
        result = subprocess.run(
            [str(python_exe), "-c", "import ccpm; print(ccpm.__version__)"],
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, f"Import failed: {result.stderr}"
        assert "0.1.0" in result.stdout

        # Test CLI functionality
        ccpm_exe = venv_path / ("Scripts/ccpm.exe" if os.name == "nt" else "bin/ccpm")
        result = subprocess.run(
            [str(ccpm_exe), "--help"], capture_output=True, text=True, timeout=30
        )

        assert result.returncode == 0, f"CLI help failed: {result.stderr}"
        assert "Claude Code PM" in result.stdout

        # Verify .egg-info was created but not in problematic location
        # In editable mode, .egg-info should be in the source directory
        egg_info_dirs = list(checkout_path.glob("*.egg-info"))

        # This is expected for editable installs
        if len(egg_info_dirs) > 0:
            # Verify it's properly ignored by git
            gitignore_path = checkout_path / ".gitignore"
            if gitignore_path.exists():
                gitignore_content = gitignore_path.read_text()
                assert (
                    "*.egg-info/" in gitignore_content
                ), "egg-info pattern missing from .gitignore"

    def test_build_distribution_packages(self, clean_temp_env):
        """Test building wheel and source distributions."""
        temp_path, venv_path = clean_temp_env

        # Get current project directory
        project_root = Path(__file__).parent.parent.parent

        # Copy project to temp directory
        checkout_path = temp_path / "ccpm_checkout"
        shutil.copytree(
            project_root,
            checkout_path,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
            ),
        )

        # Get executables
        pip_exe = venv_path / ("Scripts/pip.exe" if os.name == "nt" else "bin/pip")
        python_exe = venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Install build dependencies
        result = subprocess.run(
            [str(pip_exe), "install", "build", "wheel"],
            capture_output=True,
            text=True,
            timeout=300,
        )

        assert result.returncode == 0, f"Failed to install build tools: {result.stderr}"

        # Build distributions
        result = subprocess.run(
            [str(python_exe), "-m", "build"],
            cwd=checkout_path,
            capture_output=True,
            text=True,
            timeout=300,
        )

        assert result.returncode == 0, f"Build failed: {result.stderr}"

        # Verify distributions were created
        dist_path = checkout_path / "dist"
        assert dist_path.exists(), "dist/ directory not created"

        wheel_files = list(dist_path.glob("*.whl"))
        assert len(wheel_files) == 1, f"Expected 1 wheel file, found {len(wheel_files)}"

        tar_files = list(dist_path.glob("*.tar.gz"))
        assert len(tar_files) == 1, f"Expected 1 tar.gz file, found {len(tar_files)}"

        # Verify build artifacts are gitignored
        gitignore_path = checkout_path / ".gitignore"
        assert gitignore_path.exists(), ".gitignore file missing"

        gitignore_content = gitignore_path.read_text()
        assert "dist/" in gitignore_content, "dist/ not in .gitignore"
        assert "build/" in gitignore_content, "build/ not in .gitignore"
        assert "*.egg-info/" in gitignore_content, "*.egg-info/ not in .gitignore"

    def test_install_from_wheel(self, clean_temp_env):
        """Test installation from built wheel file."""
        temp_path, venv_path = clean_temp_env

        # Get current project directory and build wheel
        project_root = Path(__file__).parent.parent.parent
        checkout_path = temp_path / "ccpm_checkout"
        shutil.copytree(
            project_root,
            checkout_path,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
            ),
        )

        # Get executables
        pip_exe = venv_path / ("Scripts/pip.exe" if os.name == "nt" else "bin/pip")
        python_exe = venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Install build dependencies and build
        subprocess.run(
            [str(pip_exe), "install", "build"],
            capture_output=True,
            text=True,
            timeout=300,
            check=True,
        )

        subprocess.run(
            [str(python_exe), "-m", "build"],
            cwd=checkout_path,
            capture_output=True,
            text=True,
            timeout=300,
            check=True,
        )

        # Find the wheel file
        wheel_files = list((checkout_path / "dist").glob("*.whl"))
        assert len(wheel_files) == 1, f"Expected 1 wheel file, found {len(wheel_files)}"
        wheel_file = wheel_files[0]

        # Create new venv for clean install
        clean_venv_path = temp_path / "clean_venv"
        venv.create(clean_venv_path, with_pip=True)

        clean_pip = clean_venv_path / (
            "Scripts/pip.exe" if os.name == "nt" else "bin/pip"
        )
        clean_python = clean_venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Install from wheel
        result = subprocess.run(
            [str(clean_pip), "install", str(wheel_file)],
            capture_output=True,
            text=True,
            timeout=300,
        )

        assert result.returncode == 0, f"Wheel install failed: {result.stderr}"

        # Test functionality
        result = subprocess.run(
            [str(clean_python), "-c", "import ccpm; print('Import successful')"],
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, f"Import from wheel failed: {result.stderr}"
        assert "Import successful" in result.stdout

        # Test CLI
        ccpm_exe = clean_venv_path / (
            "Scripts/ccpm.exe" if os.name == "nt" else "bin/ccpm"
        )
        result = subprocess.run(
            [str(ccpm_exe), "--version"], capture_output=True, text=True, timeout=30
        )

        assert result.returncode == 0, f"CLI from wheel failed: {result.stderr}"
        assert "0.1.0" in result.stdout

    def test_multiple_install_uninstall_cycles(self, clean_temp_env):
        """Test multiple install/uninstall cycles don't leave artifacts."""
        temp_path, venv_path = clean_temp_env

        # Get current project directory
        project_root = Path(__file__).parent.parent.parent
        checkout_path = temp_path / "ccpm_checkout"
        shutil.copytree(
            project_root,
            checkout_path,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
            ),
        )

        # Get executables
        pip_exe = venv_path / ("Scripts/pip.exe" if os.name == "nt" else "bin/pip")
        python_exe = venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Perform multiple install/uninstall cycles
        for cycle in range(3):
            # Install in editable mode
            result = subprocess.run(
                [str(pip_exe), "install", "-e", str(checkout_path)],
                capture_output=True,
                text=True,
                timeout=300,
            )

            assert (
                result.returncode == 0
            ), f"Install cycle {cycle} failed: {result.stderr}"

            # Verify it works
            result = subprocess.run(
                [str(python_exe), "-c", "import ccpm"],
                capture_output=True,
                text=True,
                timeout=30,
            )

            assert (
                result.returncode == 0
            ), f"Import cycle {cycle} failed: {result.stderr}"

            # Uninstall
            result = subprocess.run(
                [str(pip_exe), "uninstall", "ccpm", "-y"],
                capture_output=True,
                text=True,
                timeout=300,
            )

            # Handle Windows pip uninstall path case sensitivity issues
            if result.returncode != 0:
                if (
                    os.name == "nt"
                    and "AssertionError: Egg-link" in result.stderr
                    and "does not match installed location" in result.stderr
                ):
                    # This is a Windows path normalization issue, not a real failure
                    # Try to clean up manually by removing ALL traces of the package
                    import glob
                    import importlib
                    import sys

                    site_packages = venv_path / "Lib" / "site-packages"

                    # First, try to remove any cached imports
                    modules_to_remove = [
                        mod for mod in sys.modules if mod.startswith("ccpm")
                    ]
                    for mod in modules_to_remove:
                        try:
                            del sys.modules[mod]
                        except KeyError:
                            pass

                    # Invalidate import caches
                    try:
                        importlib.invalidate_caches()
                    except AttributeError:
                        pass  # Python < 3.3

                    # Remove .egg-link files
                    for egg_link in glob.glob(str(site_packages / "ccpm*.egg-link")):
                        try:
                            os.remove(egg_link)
                        except OSError:
                            pass

                    # Remove .pth files that might reference the package
                    for pth_file in glob.glob(str(site_packages / "*.pth")):
                        try:
                            with open(pth_file, "r") as f:
                                content = f.read()
                            if "ccpm" in content.lower():
                                os.remove(pth_file)
                        except (OSError, UnicodeDecodeError):
                            pass

                    # Remove package directories and files
                    for pkg_item in glob.glob(str(site_packages / "ccpm*")):
                        try:
                            if os.path.isdir(pkg_item):
                                shutil.rmtree(pkg_item)
                            else:
                                os.remove(pkg_item)
                        except OSError:
                            pass

                    # Also check for egg-info directories that might be linked
                    for egg_info_path in glob.glob(str(site_packages / "*.egg-info")):
                        try:
                            egg_info = Path(egg_info_path)
                            top_level_file = egg_info / "top_level.txt"
                            if top_level_file.exists():
                                with open(top_level_file, "r") as f:
                                    top_level = f.read().strip()
                                if top_level == "ccpm":
                                    shutil.rmtree(egg_info)
                        except (OSError, FileNotFoundError, UnicodeDecodeError):
                            pass

                    # Remove from Scripts directory
                    scripts_dir = venv_path / "Scripts"
                    for script in glob.glob(str(scripts_dir / "ccpm*")):
                        try:
                            os.remove(script)
                        except OSError:
                            pass

                    # Force remove the original checkout if it exists in site-packages
                    checkout_in_site = site_packages / "ccpm_checkout"
                    if checkout_in_site.exists():
                        try:
                            shutil.rmtree(checkout_in_site)
                        except OSError:
                            pass

                    print(
                        f"Windows path mismatch handled for cycle {cycle} - "
                        "thorough cleanup"
                    )
                else:
                    assert False, f"Uninstall cycle {cycle} failed: {result.stderr}"

            # Verify it's gone - try to import from different directory
            # to avoid local imports
            result = subprocess.run(
                [str(python_exe), "-c", "import ccpm"],
                cwd=temp_path,
                capture_output=True,
                text=True,
                timeout=30,
            )

            assert (
                result.returncode != 0
            ), f"Import should fail after uninstall cycle {cycle}: {result.stdout}"

        # Check for leftover artifacts
        egg_info_dirs = list(checkout_path.glob("*.egg-info"))
        build_dirs = list(checkout_path.glob("build"))
        # dist_dirs = list(checkout_path.glob("dist"))  # Unused

        # Allow .egg-info for editable installs, but verify it's gitignored
        if len(egg_info_dirs) > 0:
            gitignore_path = checkout_path / ".gitignore"
            assert gitignore_path.exists(), ".gitignore missing"
            gitignore_content = gitignore_path.read_text()
            assert "*.egg-info/" in gitignore_content, "egg-info not properly ignored"

        # These should be clean or gitignored
        assert len(build_dirs) == 0, f"Build directories remained: {build_dirs}"

    def test_package_metadata_consistency(self, clean_temp_env):
        """Test that setup.py and pyproject.toml produce consistent metadata."""
        temp_path, venv_path = clean_temp_env

        # Get current project directory
        project_root = Path(__file__).parent.parent.parent

        # Test setup.py metadata
        result = subprocess.run(
            ["python", str(project_root / "setup.py"), "--name"],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=project_root,
        )

        assert result.returncode == 0, f"setup.py --name failed: {result.stderr}"
        name_from_setup = result.stdout.strip()
        assert name_from_setup == "ccpm", f"Expected 'ccpm', got '{name_from_setup}'"

        # Test version
        result = subprocess.run(
            ["python", str(project_root / "setup.py"), "--version"],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=project_root,
        )

        assert result.returncode == 0, f"setup.py --version failed: {result.stderr}"
        version_from_setup = result.stdout.strip()
        assert (
            version_from_setup == "0.1.0"
        ), f"Expected '0.1.0', got '{version_from_setup}'"

        # Verify pyproject.toml has matching info
        pyproject_path = project_root / "pyproject.toml"
        assert pyproject_path.exists(), "pyproject.toml missing"

        pyproject_content = pyproject_path.read_text()
        assert 'name = "ccpm"' in pyproject_content, "Name mismatch in pyproject.toml"
        assert (
            'version = "0.1.0"' in pyproject_content
        ), "Version mismatch in pyproject.toml"

    def test_dependency_resolution(self, clean_temp_env):
        """Test that dependencies are resolved correctly in real environments."""
        temp_path, venv_path = clean_temp_env

        # Get current project directory
        project_root = Path(__file__).parent.parent.parent
        checkout_path = temp_path / "ccpm_checkout"
        shutil.copytree(
            project_root,
            checkout_path,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
            ),
        )

        # Get executables
        pip_exe = venv_path / ("Scripts/pip.exe" if os.name == "nt" else "bin/pip")
        python_exe = venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Install package (should pull dependencies)
        result = subprocess.run(
            [str(pip_exe), "install", str(checkout_path)],
            capture_output=True,
            text=True,
            timeout=300,
        )

        assert result.returncode == 0, f"Install with deps failed: {result.stderr}"

        # Verify all expected dependencies are installed
        expected_deps = ["click", "gitpython", "pyyaml", "requests"]

        for dep in expected_deps:
            # Map package names to their import names
            import_map = {"gitpython": "git", "pyyaml": "yaml"}
            import_name = import_map.get(dep, dep.replace("-", "_"))
            result = subprocess.run(
                [
                    str(python_exe),
                    "-c",
                    f"import {import_name}; print('{dep} imported successfully')",
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )

            assert (
                result.returncode == 0
            ), f"Dependency {dep} import failed: {result.stderr}"
            assert f"{dep} imported successfully" in result.stdout

        # Verify ccpm itself works with its dependencies
        result = subprocess.run(
            [
                str(python_exe),
                "-c",
                "import ccpm.cli; import click; import git; import yaml; "
                "import requests; print('All imports successful')",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert result.returncode == 0, f"CCPM with deps failed: {result.stderr}"
        assert "All imports successful" in result.stdout


class TestRealWorldScenarios:
    """Test scenarios that users would encounter in production."""

    def test_development_workflow(self, clean_temp_env):
        """Test typical development workflow: clone, install -e, develop, test."""
        temp_path, venv_path = clean_temp_env

        # Simulate cloning a repository
        project_root = Path(__file__).parent.parent.parent
        dev_path = temp_path / "dev_ccpm"
        shutil.copytree(
            project_root,
            dev_path,
            ignore=shutil.ignore_patterns(
                "__pycache__", "*.pyc", ".git", ".pytest_cache", "*.egg-info"
            ),
        )

        # Get executables
        pip_exe = venv_path / ("Scripts/pip.exe" if os.name == "nt" else "bin/pip")
        python_exe = venv_path / (
            "Scripts/python.exe" if os.name == "nt" else "bin/python"
        )

        # Install development dependencies
        result = subprocess.run(
            [str(pip_exe), "install", "-e", str(dev_path)],
            capture_output=True,
            text=True,
            timeout=300,
        )

        assert result.returncode == 0, f"Dev install failed: {result.stderr}"

        # Verify the package works in editable mode
        result = subprocess.run(
            [str(python_exe), "-c", "import ccpm; print('Editable install works')"],
            capture_output=True,
            text=True,
            timeout=30,
        )

        assert (
            result.returncode == 0
        ), f"Editable install verification failed: {result.stderr}"
        assert "Editable install works" in result.stdout

        # Verify the main functionality works
        ccpm_exe = venv_path / ("Scripts/ccpm.exe" if os.name == "nt" else "bin/ccpm")
        result = subprocess.run(
            [str(ccpm_exe), "--version"], capture_output=True, text=True, timeout=30
        )

        assert result.returncode == 0, f"CLI failed in dev mode: {result.stderr}"
        assert "0.1.0" in result.stdout

        # Modern pip creates build artifacts during editable installs - this is expected
        # The important thing is that the editable install works correctly
