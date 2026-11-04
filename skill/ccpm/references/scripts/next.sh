#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "Getting status..."
echo ""
echo ""

echo "📋 Next Available Tasks"
echo "======================="
echo ""

# A task is ready when it is open, all its dependencies are closed,
# and no task it conflicts with is in progress.
found=0

while IFS= read -r task_file; do
  [ -n "$task_file" ] || continue

  status=$(frontmatter_field "$task_file" status)
  if [ "$status" != "open" ] && [ -n "$status" ]; then
    continue
  fi

  [ -n "$(unmet_deps "$task_file")" ] && continue

  task_name=$(frontmatter_field "$task_file" name)
  task_num=$(basename "$task_file" .md)
  epic_name=$(basename "$(dirname "$task_file")")
  parallel=$(frontmatter_field "$task_file" parallel)
  conflicts=$(active_conflicts "$task_file")

  if [ -n "$conflicts" ]; then
    echo "⚠️ Ready but conflicts with work in progress: #$task_num - $task_name"
    echo "   Epic: $epic_name"
    echo "   Wait for: $(echo "$conflicts" | sed 's/[^ ]*/#&/g')"
    echo ""
    continue
  fi

  echo "✅ Ready: #$task_num - $task_name"
  echo "   Epic: $epic_name"
  [ "$parallel" = "true" ] && echo "   🔄 Can run in parallel"
  all_conflicts=$(frontmatter_list "$task_file" conflicts_with)
  [ -n "$all_conflicts" ] && echo "   ⚠️ Do not run at the same time as: $(echo "$all_conflicts" | sed 's/[^ ]*/#&/g')"
  echo ""
  ((found++))
done < <(list_task_files)

if [ $found -eq 0 ]; then
  echo "No available tasks found."
  echo ""
  echo "💡 Suggestions:"
  echo "  • Check blocked tasks: /pm:blocked"
  echo "  • View all tasks: /pm:epic-list"
fi

echo ""
echo "📊 Summary: $found tasks ready to start"

exit 0
