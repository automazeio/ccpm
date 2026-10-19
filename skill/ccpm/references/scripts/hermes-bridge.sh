#!/bin/bash
set -euo pipefail

# Bridge CCPM's default .claude layout to a Hermes-native state directory.
# Usage:
#   ./hermes-bridge.sh                    # uses .hermes/ccpm
#   ./hermes-bridge.sh .hermes/my-ccpm    # custom state dir

STATE_DIR="${1:-.hermes/ccpm}"

mkdir -p "$STATE_DIR"/{prds,epics,rules,agents,scripts/pm}

if [ -L ".claude" ]; then
  current_target="$(readlink .claude)"
  if [ "$current_target" = "$STATE_DIR" ]; then
    echo "✅ .claude already points to $STATE_DIR"
  else
    echo "⚠️ .claude is already a symlink to '$current_target'"
    echo "   Update manually if you want it to point to '$STATE_DIR'."
  fi
elif [ -e ".claude" ]; then
  echo "⚠️ .claude exists as a real directory/file. Leaving it unchanged."
  echo "   If you want Hermes bridge mode, move it first, then run again."
else
  ln -s "$STATE_DIR" .claude
  echo "✅ Created symlink: .claude -> $STATE_DIR"
fi

echo ""
echo "Hermes bridge status:"
echo "  State dir: $STATE_DIR"
if [ -L .claude ]; then
  echo "  .claude -> $(readlink .claude)"
else
  echo "  .claude is not a symlink"
fi
