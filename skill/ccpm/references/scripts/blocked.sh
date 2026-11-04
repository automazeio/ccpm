#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "Getting tasks..."
echo ""
echo ""

echo "🚫 Blocked Tasks"
echo "================"
echo ""

found=0

while IFS= read -r task_file; do
  [ -n "$task_file" ] || continue

  status=$(frontmatter_field "$task_file" status)
  if [ "$status" != "open" ] && [ -n "$status" ]; then
    continue
  fi

  open_deps=$(unmet_deps "$task_file")
  [ -z "$open_deps" ] && continue

  task_name=$(frontmatter_field "$task_file" name)
  task_num=$(basename "$task_file" .md)
  epic_name=$(basename "$(dirname "$task_file")")

  echo "⏸️ Task #$task_num - $task_name"
  echo "   Epic: $epic_name"
  echo "   Depends on: [$(frontmatter_list "$task_file" depends_on)]"
  echo "   Waiting for: $(echo "$open_deps" | sed 's/[^ ]*/#&/g')"
  echo ""
  ((found++))
done < <(list_task_files)

if [ $found -eq 0 ]; then
  echo "No blocked tasks found!"
  echo ""
  echo "💡 All tasks with dependencies are either completed or in progress."
else
  echo "📊 Total blocked: $found tasks"
fi

exit 0
