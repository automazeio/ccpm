#!/bin/bash

REPO_URL="https://github.com/automazeio/ccpm.git"
TARGET_DIR="."

echo "Cloning repository from $REPO_URL..."
git clone "$REPO_URL" "$TARGET_DIR"

if [ $? -eq 0 ]; then
    echo "Clone successful. Removing .git directory..."
    rm -rf .git .gitignore install
    echo "Git directory removed. Repository is now untracked."
else
    echo "Error: Failed to clone repository."
    exit 1
fi
