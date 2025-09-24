#!/bin/bash

REPO_URL="https://github.com/automazeio/ccpm.git"
TEMP_DIR="ccpm-temp-$(date +%s)"

echo "Cloning repository from $REPO_URL to temporary directory..."
git clone "$REPO_URL" "$TEMP_DIR"

if [ $? -eq 0 ]; then
    echo "Clone successful. Copying CCPM files to current directory..."
    
    # Copy .claude directory and its contents
    if [ -d "$TEMP_DIR/.claude" ]; then
        cp -r "$TEMP_DIR/.claude" .
        echo "Copied .claude/ directory"
    fi
    
    # Copy other relevant files if they exist
    for file in AGENTS.md COMMANDS.md; do
        if [ -f "$TEMP_DIR/$file" ]; then
            cp "$TEMP_DIR/$file" .
            echo "Copied $file"
        fi
    done
    
    # Clean up temporary directory
    echo "Cleaning up temporary directory..."
    rm -rf "$TEMP_DIR"
    
    echo "CCPM installation complete! Run '/pm:init' to get started."
else
    echo "Error: Failed to clone repository."
    # Clean up on failure too
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
    exit 1
fi
