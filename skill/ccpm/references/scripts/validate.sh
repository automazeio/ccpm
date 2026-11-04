#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "Validating PM System..."
echo ""
echo ""

echo "🔍 Validating PM System"
echo "======================="
echo ""

errors=0
warnings=0

# Check directory structure
echo "📁 Directory Structure:"
if [ -d ".claude" ]; then
  echo "  ✅ .claude directory exists"
else
  echo "  ❌ .claude directory missing"
  ((errors++))
fi
[ -d ".claude/prds" ] && echo "  ✅ PRDs directory exists" || echo "  ⚠️ PRDs directory missing"
[ -d ".claude/epics" ] && echo "  ✅ Epics directory exists" || echo "  ⚠️ Epics directory missing"
[ -d ".claude/rules" ] && echo "  ✅ Rules directory exists" || echo "  ⚠️ Rules directory missing"
echo ""

# Check for orphaned files
echo "🗂️ Data Integrity:"

# Check epics have epic.md files (archive buckets are not epics)
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  is_archive_dir "$epic_dir" && continue
  if [ ! -f "$epic_dir/epic.md" ]; then
    echo "  ⚠️ Missing epic.md in $(basename "$epic_dir")"
    ((warnings++))
  fi
done

# Check for task files outside an epic directory
orphaned=$(find .claude -name "[0-9]*.md" ! -name "*[!0-9]*.md" -not -path ".claude/epics/*/*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$orphaned" -gt 0 ]; then
  echo "  ⚠️ Found $orphaned orphaned task files"
  ((warnings++))
fi

# Check for broken references
echo ""
echo "🔗 Reference Check:"
ref_warnings=0

while IFS= read -r task_file; do
  [ -n "$task_file" ] || continue
  epic_dir=$(dirname "$task_file")
  task_num=$(basename "$task_file" .md)
  for field in depends_on conflicts_with; do
    for ref in $(frontmatter_list "$task_file" "$field"); do
      if [ ! -f "$epic_dir/$ref.md" ]; then
        echo "  ⚠️ Task $task_num ($field) references missing task: $ref"
        ((ref_warnings++))
      fi
    done
  done
done < <(list_task_files)

warnings=$((warnings + ref_warnings))
[ $ref_warnings -eq 0 ] && echo "  ✅ All references valid"

# Check frontmatter on PRDs, epics and tasks.
# Generated files (github-mapping.md, execution-status.md, updates/) are skipped.
echo ""
echo "📝 Frontmatter Validation:"
invalid=0

check_frontmatter() {
  if [ "$(head -1 "$1")" != "---" ]; then
    echo "  ⚠️ Missing frontmatter: $1"
    ((invalid++))
  fi
}

for file in .claude/prds/*.md; do
  [ -f "$file" ] && check_frontmatter "$file"
done
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  is_archive_dir "$epic_dir" && continue
  [ -f "$epic_dir/epic.md" ] && check_frontmatter "$epic_dir/epic.md"
done
while IFS= read -r task_file; do
  [ -n "$task_file" ] && check_frontmatter "$task_file"
done < <(list_task_files)

[ $invalid -eq 0 ] && echo "  ✅ All files have frontmatter"

# Summary
echo ""
echo "📊 Validation Summary:"
echo "  Errors: $errors"
echo "  Warnings: $warnings"
echo "  Invalid files: $invalid"

if [ $errors -eq 0 ] && [ $warnings -eq 0 ] && [ $invalid -eq 0 ]; then
  echo ""
  echo "✅ System is healthy!"
fi

# Exit non-zero on errors or invalid files so callers can rely on it.
# Warnings alone do not fail validation.
[ $errors -gt 0 ] || [ $invalid -gt 0 ] && exit 1
exit 0
