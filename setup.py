#!/usr/bin/env python3
"""Setup script for CCPM CLI tool."""

from pathlib import Path

from setuptools import find_packages, setup

# Read the README file
this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text(encoding="utf-8")

setup(
    name="ccpm",
    version="0.1.0",
    author="Jeremy Manning",
    author_email="jeremy@example.com",
    description="Claude Code PM - Project Management System CLI",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/automazeio/ccpm",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.8",
    install_requires=[
        "click>=8.0",
        "gitpython>=3.1",
        "pyyaml>=6.0",
        "requests>=2.28",
    ],
    entry_points={
        "console_scripts": [
            "ccpm=ccpm.cli:cli",
        ],
    },
    include_package_data=True,
    package_data={
        "ccpm": ["claude_template/**/*"],
    },
)
