#!/bin/bash

echo "📄 PRD Status Report"
echo "===================="
echo ""

if [ ! -d ".claude/prds" ]; then
  echo "No PRD directory found."
  exit 0
fi

total=$(ls .claude/prds/*.md 2>/dev/null | wc -l)
[ $total -eq 0 ] && echo "No PRDs found." && exit 0

# Count by status
backlog=0
in_progress=0
implemented=0

for file in .claude/prds/*.md; do
  [ -f "$file" ] || continue
  status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//')

  case "$status" in
    backlog|draft|"") ((backlog++)) ;;
    in-progress|active) ((in_progress++)) ;;
    implemented|completed|done) ((implemented++)) ;;
    *) ((backlog++)) ;;
  esac
done

echo "Getting status..."
echo ""
echo ""

# Display chart
echo "📊 Distribution:"
echo "================"

echo ""
echo "  Backlog:     $(printf '%-3d' $backlog) [$(printf '%0.s█' $(seq 1 $((backlog*20/total))))]"
echo "  In Progress: $(printf '%-3d' $in_progress) [$(printf '%0.s█' $(seq 1 $((in_progress*20/total))))]"
echo "  Implemented: $(printf '%-3d' $implemented) [$(printf '%0.s█' $(seq 1 $((implemented*20/total))))]"
echo ""
echo "  Total PRDs: $total"

# Recent activity
echo ""
echo "📅 Recent PRDs (last 5 modified):"
ls -t .claude/prds/*.md 2>/dev/null | head -5 | while read file; do
  name=$(grep "^name:" "$file" | head -1 | sed 's/^name: *//')
  [ -z "$name" ] && name=$(basename "$file" .md)
  echo "  • $name"
done

# Suggestions
echo ""
echo "💡 Next Actions:"
[ $backlog -gt 0 ] && echo "  • Parse backlog PRDs to epics: /pm:prd-parse <name>"
[ $in_progress -gt 0 ] && echo "  • Check progress on active PRDs: /pm:epic-status <name>"
[ $total -eq 0 ] && echo "  • Create your first PRD: /pm:prd-new <name>"

exit 0
