#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "📅 Daily Standup - $(date '+%Y-%m-%d')"
echo "================================"
echo ""

today=$(date '+%Y-%m-%d')

echo "Getting status..."
echo ""
echo ""

echo "📝 Today's Activity:"
echo "===================="
echo ""

# Find files modified today
recent_files=$(find .claude -name "*.md" -mtime -1 2>/dev/null)

if [ -n "$recent_files" ]; then
  # Count by type
  prd_count=$(echo "$recent_files" | grep -c "/prds/" 2>/dev/null | tr -d '[:space:]')
  epic_count=$(echo "$recent_files" | grep -c "/epic.md" 2>/dev/null | tr -d '[:space:]')
  task_count=$(echo "$recent_files" | grep -cE "/epics/[^/]+/[0-9]+\.md$" 2>/dev/null | tr -d '[:space:]')
  update_count=$(echo "$recent_files" | grep -c "/updates/" 2>/dev/null | tr -d '[:space:]')
  prd_count=${prd_count:-0}; epic_count=${epic_count:-0}; task_count=${task_count:-0}; update_count=${update_count:-0}

  [ "$prd_count" -gt 0 ] && echo "  • Modified $prd_count PRD(s)"
  [ "$epic_count" -gt 0 ] && echo "  • Updated $epic_count epic(s)"
  [ "$task_count" -gt 0 ] && echo "  • Worked on $task_count task(s)"
  [ "$update_count" -gt 0 ] && echo "  • Posted $update_count progress update(s)"
else
  echo "  No activity recorded today"
fi

echo ""
echo "🔄 Currently In Progress:"
# Show active work items
for updates_dir in .claude/epics/*/updates/*/; do
  [ -d "$updates_dir" ] || continue
  if [ -f "$updates_dir/progress.md" ]; then
    issue_num=$(basename "$updates_dir")
    epic_name=$(basename $(dirname $(dirname "$updates_dir")))
    completion=$(grep "^completion:" "$updates_dir/progress.md" | head -1 | sed 's/^completion: *//')
    echo "  • Issue #$issue_num ($epic_name) - ${completion:-0%} complete"
  fi
done

echo ""
echo "⏭️ Next Available Tasks:"
# Show top 3 available tasks
count=0
while IFS= read -r task_file; do
  [ -n "$task_file" ] || continue
  status=$(frontmatter_field "$task_file" status)
  if [ "$status" != "open" ] && [ -n "$status" ]; then
    continue
  fi
  [ -n "$(unmet_deps "$task_file")" ] && continue
  [ -n "$(active_conflicts "$task_file")" ] && continue

  task_name=$(frontmatter_field "$task_file" name)
  task_num=$(basename "$task_file" .md)
  echo "  • #$task_num - $task_name"
  ((count++))
  [ $count -ge 3 ] && break
done < <(list_task_files)

echo ""
echo "📊 Quick Stats:"
task_list=$(list_task_files)
total_tasks=$(echo "$task_list" | grep -c .)
open_tasks=0
closed_tasks=0
while IFS= read -r task_file; do
  [ -n "$task_file" ] || continue
  s=$(frontmatter_field "$task_file" status)
  if is_done_status "$s"; then ((closed_tasks++)); elif [ "$s" = "open" ]; then ((open_tasks++)); fi
done <<< "$task_list"
echo "  Tasks: $open_tasks open, $closed_tasks closed, $total_tasks total"

exit 0
