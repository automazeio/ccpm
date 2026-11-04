#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

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
  total=0
  for dir in .claude/epics/*/; do
    [ -d "$dir" ] && ! is_archive_dir "$dir" && ((total++))
  done
  echo "  Total: $total"
else
  echo "  No epics found"
fi

echo ""
echo "📝 Tasks:"
if [ -d ".claude/epics" ]; then
  task_list=$(list_task_files)
  total=$(echo "$task_list" | grep -c .)
  open=0
  closed=0
  while IFS= read -r task_file; do
    [ -n "$task_file" ] || continue
    s=$(frontmatter_field "$task_file" status)
    if is_done_status "$s"; then ((closed++)); elif [ "$s" = "open" ]; then ((open++)); fi
  done <<< "$task_list"
  echo "  Open: $open"
  echo "  Closed: $closed"
  echo "  Total: $total"
else
  echo "  No tasks found"
fi

exit 0
