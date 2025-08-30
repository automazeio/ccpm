#!/bin/bash
# CCPM CLI Installer Script
# One-line installation: curl -sSL https://raw.githubusercontent.com/automazeio/ccpm/main/installer.sh | bash

set -e

echo "==============================================="
echo "     CCPM - Claude Code PM CLI Installer"
echo "==============================================="
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo "🔍 Detected: $OS ($ARCH)"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to add to PATH
add_to_path() {
    local path_to_add="$1"
    local shell_rc=""
    
    # Detect shell
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi
    
    # Check if already in PATH
    if [[ ":$PATH:" != *":$path_to_add:"* ]]; then
        echo "export PATH=\"$path_to_add:\$PATH\"" >> "$shell_rc"
        export PATH="$path_to_add:$PATH"
        echo "✅ Added to PATH in $shell_rc"
    fi
}

# Check for Python 3
echo "🐍 Checking Python installation..."
if command_exists python3; then
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
elif command_exists python; then
    # Check if it's Python 3
    if python --version 2>&1 | grep -q "Python 3"; then
        PYTHON_CMD="python"
        PIP_CMD="pip"
    else
        echo "❌ Python 3 is required but not found"
        echo "Please install Python 3.8 or higher"
        exit 1
    fi
else
    echo "❌ Python is not installed"
    
    # Offer to install Python
    if [ "$OS" = "Darwin" ]; then
        echo "To install Python on macOS, run:"
        echo "  brew install python3"
    elif [ "$OS" = "Linux" ]; then
        echo "To install Python on Linux, run:"
        echo "  sudo apt-get install python3 python3-pip  # Debian/Ubuntu"
        echo "  sudo yum install python3 python3-pip      # RHEL/CentOS"
    fi
    exit 1
fi

# Get Python version
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
echo "✅ Found Python $PYTHON_VERSION"

# Check for pip
echo ""
echo "📦 Checking pip installation..."
if ! command_exists "$PIP_CMD"; then
    echo "Installing pip..."
    curl -sSL https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD
    
    # Update PIP_CMD to use python -m pip
    PIP_CMD="$PYTHON_CMD -m pip"
fi
echo "✅ pip is available"

# Check for git
echo ""
echo "🔗 Checking git installation..."
if ! command_exists git; then
    echo "❌ git is not installed"
    echo "Please install git first:"
    
    if [ "$OS" = "Darwin" ]; then
        echo "  brew install git"
    elif [ "$OS" = "Linux" ]; then
        echo "  sudo apt-get install git  # Debian/Ubuntu"
        echo "  sudo yum install git      # RHEL/CentOS"
    fi
    exit 1
fi
echo "✅ git is available"

# Install CCPM
echo ""
echo "📥 Installing CCPM CLI..."

# Use --user flag for non-root installation
if [ "$EUID" -ne 0 ]; then
    echo "Installing for current user..."
    $PIP_CMD install --user git+https://github.com/automazeio/ccpm.git
    
    # Get user site directory
    USER_SITE=$($PYTHON_CMD -m site --user-base)
    CCPM_PATH="$USER_SITE/bin"
    
    # Add to PATH if needed
    add_to_path "$CCPM_PATH"
else
    echo "Installing system-wide..."
    $PIP_CMD install git+https://github.com/automazeio/ccpm.git
fi

# Verify installation
echo ""
echo "🔍 Verifying installation..."

# For user installation, we might need to use the full path
if [ "$EUID" -ne 0 ] && [ -n "$CCPM_PATH" ]; then
    if [ -f "$CCPM_PATH/ccpm" ]; then
        echo "✅ CCPM installed successfully at: $CCPM_PATH/ccpm"
        CCPM_CMD="$CCPM_PATH/ccpm"
    else
        echo "⚠️ CCPM binary not found in expected location"
        echo "Try running: python3 -m ccpm --help"
        CCPM_CMD="$PYTHON_CMD -m ccpm"
    fi
else
    if command_exists ccpm; then
        echo "✅ CCPM installed successfully"
        CCPM_CMD="ccpm"
    else
        echo "⚠️ CCPM command not found in PATH"
        echo "Try running: python3 -m ccpm --help"
        CCPM_CMD="$PYTHON_CMD -m ccpm"
    fi
fi

# Show version
echo ""
$CCPM_CMD --version 2>/dev/null || $PYTHON_CMD -m ccpm --version

# Final instructions
echo ""
echo "==============================================="
echo "      ✅ CCPM Installation Complete!"
echo "==============================================="
echo ""
echo "🎯 Quick Start:"
echo "  1. Navigate to your project: cd /path/to/project"
echo "  2. Set up CCPM: ccpm setup ."
echo "  3. Initialize: ccpm init"
echo "  4. Get help: ccpm help"
echo ""

if [ "$EUID" -ne 0 ] && [ -n "$CCPM_PATH" ]; then
    echo "📝 Note: CCPM was installed to: $CCPM_PATH"
    echo "   You may need to restart your shell or run:"
    echo "   source ~/.bashrc  # or ~/.zshrc"
    echo ""
fi

echo "📚 Full documentation: https://github.com/automazeio/ccpm"
echo ""
echo "Happy coding! 🚀"