#!/bin/bash

echo "DAILY STANDUP - $(date '+%Y-%m-%d')"
echo "================================"
echo ""

today=$(date '+%Y-%m-%d')

echo "Getting status..."
echo ""
echo ""

echo "TODAY'S ACTIVITY:"
echo "===================="
echo ""

# Find files modified today
recent_files=$(find .claude -name "*.md" -mtime -1 2>/dev/null)

if [ -n "$recent_files" ]; then
  # Count by type
  prd_count=$(echo "$recent_files" | grep -c "/prds/" || echo 0)
  epic_count=$(echo "$recent_files" | grep -c "/epic.md" || echo 0)
  task_count=$(echo "$recent_files" | grep -c "/[0-9]*.md" || echo 0)
  update_count=$(echo "$recent_files" | grep -c "/updates/" || echo 0)

  [ $prd_count -gt 0 ] && echo "  • Modified $prd_count PRD(s)"
  [ $epic_count -gt 0 ] && echo "  • Updated $epic_count epic(s)"
  [ $task_count -gt 0 ] && echo "  • Worked on $task_count task(s)"
  [ $update_count -gt 0 ] && echo "  • Posted $update_count progress update(s)"
else
  echo "  No activity recorded today"
fi

echo ""
echo "CURRENTLY IN PROGRESS:"
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
echo "NEXT AVAILABLE TASKS:"
# Show top 3 available tasks
count=0
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  for task_file in "$epic_dir"[0-9]*.md; do
    [ -f "$task_file" ] || continue

    # Read file once and extract all fields safely without eval
    # Use process substitution to read variables directly
    {
      read -r status
      read -r task_name
      read -r deps
    } < <(awk '
      /^status:/ && !status { status=$2 }
      /^name:/ && !name { gsub(/^name: */, ""); name=$0 }
      /^depends_on:/ && !deps { gsub(/^depends_on: *\[|\]/, ""); gsub(/, */, " "); deps=$0 }
      END {
        print status
        print name
        print deps
      }
    ' "$task_file")

    [ "$status" != "open" ] && [ -n "$status" ] && continue

    if [ -z "$deps" ] || [ "$deps" = "depends_on:" ]; then
      task_num=$(basename "$task_file" .md)
      echo "  • #$task_num - $task_name"
      ((count++))
      [ $count -ge 3 ] && break 2
    fi
  done
done

echo ""
echo "QUICK STATS:"
total_tasks=$(find .claude/epics -name "[0-9]*.md" 2>/dev/null | wc -l)
open_tasks=$(find .claude/epics -name "[0-9]*.md" -exec grep -l "^status: *open" {} \; 2>/dev/null | wc -l)
closed_tasks=$(find .claude/epics -name "[0-9]*.md" -exec grep -l "^status: *closed" {} \; 2>/dev/null | wc -l)
echo "  Tasks: $open_tasks open, $closed_tasks closed, $total_tasks total"

exit 0
