#!/bin/bash

REPO_URL="https://github.com/automazeio/ccpm.git"
TEMP_DIR=$(mktemp -d)
TARGET_DIR="."

echo "Cloning CCPM repository..."
git clone "$REPO_URL" "$TEMP_DIR"

if [ $? -eq 0 ]; then
    echo "Clone successful. Installing CCPM system..."
    
    # Check if .claude directory already exists
    if [ -d ".claude" ]; then
        echo "⚠️  WARNING: .claude directory already exists!"
        echo "   Please backup your existing .claude directory before continuing."
        echo "   Then remove it and re-run this installer."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Copy ccpm contents to .claude
    if [ -d "$TEMP_DIR/ccpm" ]; then
        cp -r "$TEMP_DIR/ccpm/." ".claude"
        echo "✅ CCPM system installed to .claude/"
    else
        echo "❌ Error: ccpm directory not found in repository."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Clean up temporary directory
    rm -rf "$TEMP_DIR"
    
    echo "🎉 CCPM installation complete!"
    echo "   Run: /pm:init to set up your project"
    
else
    echo "❌ Error: Failed to clone repository."
    rm -rf "$TEMP_DIR"
    exit 1
fi