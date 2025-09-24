#!/bin/bash
set -euo pipefail

query="${1:-}"

if [ -z "$query" ]; then
  echo "❌ Please provide a search query"
  echo "Usage: /pm:search <query>"
  exit 1
fi

echo "Searching for '$query'..."
echo ""
echo ""

echo "SEARCH RESULTS FOR: '$query'"
echo "================================"
echo ""

# Search in PRDs
if [ -d ".claude/prds" ]; then
  echo "PRDs:"
  results=$(grep -l -i -- "$query" .claude/prds/*.md 2>/dev/null || true)
  if [ -n "$results" ]; then
    for file in $results; do
      name=$(basename "$file" .md)
      matches=$(grep -c -i -- "$query" "$file" 2>/dev/null || echo "0")
      echo "  • $name ($matches matches)"
    done
  else
    echo "  No matches"
  fi
  echo ""
fi

# Search in Epics
if [ -d ".claude/epics" ]; then
  echo "EPICS:"
  results=$(find .claude/epics -name "epic.md" -exec grep -l -i -- "$query" {} \; 2>/dev/null || true)
  if [ -n "$results" ]; then
    for file in $results; do
      epic_name=$(basename "$(dirname "$file")")
      matches=$(grep -c -i -- "$query" "$file" 2>/dev/null || echo "0")
      echo "  • $epic_name ($matches matches)"
    done
  else
    echo "  No matches"
  fi
  echo ""
fi

# Search in Tasks
if [ -d ".claude/epics" ]; then
  echo "TASKS:"
  results=$(find .claude/epics -name "[0-9]*.md" -exec grep -l -i -- "$query" {} \; 2>/dev/null | head -10 || true)
  if [ -n "$results" ]; then
    for file in $results; do
      epic_name=$(basename "$(dirname "$file")")
      task_num=$(basename "$file" .md)
      echo "  • Task #$task_num in $epic_name"
    done
  else
    echo "  No matches"
  fi
fi

# Summary
total=$(find .claude -name "*.md" -exec grep -l -i -- "$query" {} \; 2>/dev/null | wc -l || echo "0")
echo ""
echo "TOTAL FILES WITH MATCHES: $total"

exit 0
