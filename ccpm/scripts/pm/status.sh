#!/bin/bash

echo "Getting status..."
echo ""
echo ""


echo "📊 Project Status"
echo "================"
echo ""

echo "📄 PRDs:"
if [ -d "ccpm/prds" ]; then
  total=$(ls ccpm/prds/*.md 2>/dev/null | wc -l)
  echo "  Total: $total"
else
  echo "  No PRDs found"
fi

echo ""
echo "📚 Epics:"
if [ -d "ccpm/epics" ]; then
  total=$(ls -d ccpm/epics/*/ 2>/dev/null | wc -l)
  echo "  Total: $total"
else
  echo "  No epics found"
fi

echo ""
echo "📝 Tasks:"
if [ -d "ccpm/epics" ]; then
  total=$(find ccpm/epics -name "[0-9]*.md" 2>/dev/null | wc -l)
  open=$(find ccpm/epics -name "[0-9]*.md" -exec grep -l "^status: *open" {} \; 2>/dev/null | wc -l)
  closed=$(find ccpm/epics -name "[0-9]*.md" -exec grep -l "^status: *closed" {} \; 2>/dev/null | wc -l)
  echo "  Open: $open"
  echo "  Closed: $closed"
  echo "  Total: $total"
else
  echo "  No tasks found"
fi

exit 0
