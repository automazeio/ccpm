#!/bin/bash
set -euo pipefail
echo "Getting tasks..."
echo ""
echo ""

echo "[BLOCKED] Blocked Tasks"
echo "================"
echo ""

found=0

for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  epic_name=$(basename "$epic_dir")

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
      /^depends_on:/ && !deps {
        gsub(/^depends_on: *\[|\]/, "");
        gsub(/, */, " ");
        deps=$0
      }
      END {
        print status
        print name
        print deps
      }
    ' "$task_file")

    [ "$status" != "open" ] && [ -n "$status" ] && continue

    if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
      task_num=$(basename "$task_file" .md)

      echo "[PAUSED] Task #$task_num - $task_name"
      echo "   Epic: $epic_name"
      echo "   Blocked by: [$deps]"

      # Check status of dependencies
      open_deps=""
      for dep in $deps; do
        dep_file="$epic_dir$dep.md"
        if [ -f "$dep_file" ]; then
          dep_status=$(grep "^status:" "$dep_file" | head -1 | sed 's/^status: *//')
          [ "$dep_status" = "open" ] && open_deps="$open_deps #$dep"
        fi
      done

      [ -n "$open_deps" ] && echo "   Waiting for:$open_deps"
      echo ""
      found=$((found + 1))
    fi
  done
done

if [ $found -eq 0 ]; then
  echo "No blocked tasks found!"
  echo ""
  echo "TIP All tasks with dependencies are either completed or in progress."
else
  echo "STATUS Total blocked: $found tasks"
fi

exit 0
