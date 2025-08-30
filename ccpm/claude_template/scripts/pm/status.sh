#!/bin/bash

# Load cross-platform utilities for better error handling
source "$(dirname "$0")/../utils.sh" 2>/dev/null || {
  echo "Warning: Could not load utility functions, proceeding with basic functionality" >&2
}

echo "Getting status..."
echo ""
echo ""


echo "PROJECT STATUS"
echo "================"
echo ""

echo "PRDs:"
if [ -d ".claude/prds" ]; then
  # Use more robust counting that works across platforms
  total=$(find .claude/prds -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "  Total: $total"
else
  echo "  No PRDs found"
fi

echo ""
echo "EPICS:"
if [ -d ".claude/epics" ]; then
  # Use more robust directory counting
  total=$(find .claude/epics -maxdepth 1 -type d ! -path ".claude/epics" 2>/dev/null | wc -l | tr -d ' ')
  echo "  Total: $total"
else
  echo "  No epics found"
fi

echo ""
echo "TASKS:"
if [ -d ".claude/epics" ]; then
  # Use more robust task counting with better cross-platform support
  total=$(find .claude/epics -name "[0-9]*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  open=$(find .claude/epics -name "[0-9]*.md" -type f -exec grep -l "^status: *open" {} \; 2>/dev/null | wc -l | tr -d ' ')
  closed=$(find .claude/epics -name "[0-9]*.md" -type f -exec grep -l "^status: *closed" {} \; 2>/dev/null | wc -l | tr -d ' ')
  echo "  Open: $open"
  echo "  Closed: $closed" 
  echo "  Total: $total"
else
  echo "  No tasks found"
fi

exit 0
