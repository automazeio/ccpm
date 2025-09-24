#!/bin/bash

echo "Validating PM System..."
echo ""
echo ""

echo "VALIDATING PM SYSTEM"
echo "======================="
echo ""

errors=0
warnings=0

# Check directory structure
echo "DIRECTORY STRUCTURE:"
[ -d ".claude" ] && echo "  OK .claude directory exists" || { echo "  ERROR .claude directory missing"; ((errors++)); }
[ -d ".claude/prds" ] && echo "  OK PRDs directory exists" || echo "  WARNING PRDs directory missing"
[ -d ".claude/epics" ] && echo "  OK Epics directory exists" || echo "  WARNING Epics directory missing"
[ -d ".claude/rules" ] && echo "  OK Rules directory exists" || echo "  WARNING Rules directory missing"
echo ""

# Check for orphaned files
echo "DATA INTEGRITY:"

# Check epics have epic.md files
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  if [ ! -f "$epic_dir/epic.md" ]; then
    echo "  WARNING Missing epic.md in $(basename "$epic_dir")"
    ((warnings++))
  fi
done

# Check for tasks without epics
orphaned=$(find .claude -name "[0-9]*.md" -not -path ".claude/epics/*/*" 2>/dev/null | wc -l)
[ $orphaned -gt 0 ] && echo "  WARNING Found $orphaned orphaned task files" && ((warnings++))

# Check for broken references
echo ""
echo "REFERENCE CHECK:"

for task_file in .claude/epics/*/[0-9]*.md; do
  [ -f "$task_file" ] || continue

  deps=$(grep "^depends_on:" "$task_file" | head -1 | sed 's/^depends_on: *\[//' | sed 's/\]//' | sed 's/,/ /g')
  if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
    epic_dir=$(dirname "$task_file")
    for dep in $deps; do
      if [ ! -f "$epic_dir/$dep.md" ]; then
        echo "  WARNING Task $(basename "$task_file" .md) references missing task: $dep"
        ((warnings++))
      fi
    done
  fi
done

[ $warnings -eq 0 ] && [ $errors -eq 0 ] && echo "  OK All references valid"

# Check frontmatter
echo ""
echo "FRONTMATTER VALIDATION:"
invalid=0

for file in $(find .claude -name "*.md" -path "*/epics/*" -o -path "*/prds/*" 2>/dev/null); do
  if ! grep -q "^---" "$file"; then
    echo "  WARNING Missing frontmatter: $(basename "$file")"
    ((invalid++))
  fi
done

[ $invalid -eq 0 ] && echo "  OK All files have frontmatter"

# Summary
echo ""
echo "VALIDATION SUMMARY:"
echo "  Errors: $errors"
echo "  Warnings: $warnings"
echo "  Invalid files: $invalid"

if [ $errors -eq 0 ] && [ $warnings -eq 0 ] && [ $invalid -eq 0 ]; then
  echo ""
  echo "OK System is healthy!"
else
  echo ""
  echo "TIP Run /pm:clean to fix some issues automatically"
fi

exit 0
