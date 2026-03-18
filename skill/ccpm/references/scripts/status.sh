#!/bin/bash

echo "Getting status..."
echo ""
echo ""


echo "📊 Project Status"
echo "================"
echo ""

echo "📄 PRDs:"
if [ -d ".claude/prds" ]; then
  total=$(ls .claude/prds/*.md 2>/dev/null | wc -l)
  echo "  Total: $total"
else
  echo "  No PRDs found"
fi

echo ""
echo "📚 Epics:"
if [ -d ".claude/epics" ]; then
  total=$(ls -d .claude/epics/*/ 2>/dev/null | grep -v '/archived/$' | wc -l)
  echo "  Total: $total"
else
  echo "  No epics found"
fi

echo ""
echo "📝 Tasks:"
if [ -d ".claude/epics" ]; then
  total=$(find .claude/epics -path "*/archived/*" -prune -o -name "[0-9]*.md" -print 2>/dev/null | wc -l)
  open=$(find .claude/epics -path "*/archived/*" -prune -o -name "[0-9]*.md" -print 2>/dev/null | xargs grep -l "^status: *open" 2>/dev/null | wc -l)
  closed=$(find .claude/epics -path "*/archived/*" -prune -o -name "[0-9]*.md" -print 2>/dev/null | xargs grep -l "^status: *closed" 2>/dev/null | wc -l)
  echo "  Open: $open"
  echo "  Closed: $closed"
  echo "  Total: $total"
else
  echo "  No tasks found"
fi

exit 0
